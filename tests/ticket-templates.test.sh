#!/bin/sh
# Test suite for the JIRA ticket templates. Dependency-free: POSIX sh only.
# Run: sh tests/ticket-templates.test.sh
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JIRA="$REPO_ROOT/stow/JIRA"
TECHDEBT="$REPO_ROOT/stow/TechDebt"
TESTS_RUN=0
TESTS_FAILED=0

pass() { TESTS_RUN=$((TESTS_RUN + 1)); printf "  ok   %s\n" "$1"; }
fail() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "  FAIL %s\n" "$1"
    printf "       %s\n" "$2"
}

assert_file_contains() {
    # assert_file_contains <name> <needle> <file>
    if [ ! -f "$3" ]; then fail "$1" "no such file: $3"; return; fi
    if grep -qF "$2" "$3"; then pass "$1"; else fail "$1" "[$2] not found in $3"; fi
}

assert_file_lacks() {
    # assert_file_lacks <name> <needle> <file>
    if [ ! -f "$3" ]; then fail "$1" "no such file: $3"; return; fi
    if grep -qF "$2" "$3"; then fail "$1" "[$2] should not appear in $3"; else pass "$1"; fi
}

assert_no_dashes() {
    # assert_no_dashes <name> <file>   (R3: no em dash, no en dash)
    if [ ! -f "$2" ]; then fail "$1" "no such file: $2"; return; fi
    if grep -q -e '—' -e '–' "$2"; then
        fail "$1" "em or en dash found in $2"
    else
        pass "$1"
    fi
}

# Echoes the word count of the first ```markdown fenced block in a file,
# counting prose and bullet text only. Headings, list markers, checkbox
# markers, step numbers and URLs are excluded, per the spec's counting rule.
example_words() {
    awk '/^```markdown$/ { f = 1; next } /^```$/ { if (f) exit } f' "$1" \
        | sed -e 's/^#\{1,6\} .*$//' \
              -e 's/^- \[ \] //' \
              -e 's/^[0-9]\{1,\}\. //' \
              -e 's/^- //' \
              -e 's|https\{0,1\}://[^ ]*||g' \
        | tr -s ' \n' '  ' \
        | wc -w \
        | tr -d ' '
}

assert_at_most() {
    # assert_at_most <name> <limit> <actual>
    if [ "$3" -le "$2" ]; then pass "$1"; else fail "$1" "expected <= $2, got $3"; fi
}

assert_at_least() {
    # assert_at_least <name> <floor> <actual>
    if [ "$3" -ge "$2" ]; then pass "$1"; else fail "$1" "expected >= $2, got $3"; fi
}

# ---- tests ----

test_ticket_rules_exist() {
    f="$JIRA/Reference/TicketRules.md"
    assert_file_contains "TicketRules states R1 by name" "R1" "$f"
    assert_file_contains "TicketRules states R2 by name" "R2" "$f"
    assert_file_contains "TicketRules states R3 by name" "R3" "$f"
    assert_file_contains "R1 forbids stating the solution" "never states the solution" "$f"
    assert_file_contains "R1 carries the evidence carve-out" "evidence" "$f"
    assert_file_contains "R2 names the Jira fields it excludes" "priority" "$f"
    assert_file_contains "R3 points at the existing voice rules" "SKILL.md" "$f"
    assert_no_dashes "TicketRules obeys R3 itself" "$f"
}

test_story_template() {
    f="$JIRA/Templates/Story.md"
    assert_file_contains "Story has What we want"        "## What we want" "$f"
    assert_file_contains "Story has Why it matters"      "## Why it matters" "$f"
    assert_file_contains "Story has Out of scope"        "## Out of scope" "$f"
    assert_file_contains "Story has Acceptance criteria" "## Acceptance criteria" "$f"
    assert_file_contains "Story states its word cap"     "200 words" "$f"
    assert_file_contains "Story caps criteria at 7"      "7 bullets" "$f"
    assert_file_contains "Story marks a section optional" "optional" "$f"
    assert_file_contains "Story calls overflow a split signal" "split signal" "$f"
    assert_file_contains "Story says why it drops the As-a form" "invented persona" "$f"
    assert_file_lacks    "Story has no Suggested Approach" "Suggested Approach" "$f"
    assert_no_dashes     "Story obeys R3" "$f"
    assert_at_least "Story has a worked example at all" 20 "$(example_words "$f")"
    assert_at_most "Story example is within 200 words" 200 "$(example_words "$f")"

    # Acceptance criteria must be the last heading in the worked example.
    last="$(awk '/^```markdown$/ { f = 1; next } /^```$/ { if (f) exit } f && /^## / { h = $0 } END { print h }' "$f")"
    if [ "$last" = "## Acceptance criteria" ]; then
        pass "Story example ends with acceptance criteria"
    else
        fail "Story example ends with acceptance criteria" "last heading was [$last]"
    fi
}

# ---- runner ----

test_ticket_rules_exist
test_story_template

printf "\n%d run, %d failed\n" "$TESTS_RUN" "$TESTS_FAILED"
[ "$TESTS_FAILED" -eq 0 ]
