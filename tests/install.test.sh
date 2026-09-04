#!/bin/sh
# Test suite for install.sh. Dependency-free: POSIX sh only.
# Run: sh tests/install.test.sh
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$REPO_ROOT/install.sh"
TESTS_RUN=0
TESTS_FAILED=0

pass() { TESTS_RUN=$((TESTS_RUN + 1)); printf "  ok   %s\n" "$1"; }
fail() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "  FAIL %s\n" "$1"
    printf "       %s\n" "$2"
}

assert_eq() {
    # assert_eq <name> <expected> <actual>
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected [$2] got [$3]"; fi
}

assert_contains() {
    # assert_contains <name> <needle> <haystack>
    case "$3" in
        *"$2"*) pass "$1" ;;
        *) fail "$1" "expected to contain [$2] in [$3]" ;;
    esac
}

# Creates an isolated fake HOME and echoes the skills dir inside it.
# HOME is sandboxed as well as CLAUDE_SKILLS_DIR, because before Task 1's fix
# lands install.sh ignores CLAUDE_SKILLS_DIR and derives TARGET_DIR from $HOME
# (install.sh:4). Without the HOME sandbox the red phase would operate on the
# real installation, which is the exact failure this whole plan exists to stop.
setup_fixture() {
    d="$(mktemp -d)"
    mkdir -p "$d/.claude/skills"
    printf "%s" "$d/.claude/skills"
}

# Run install.sh fully sandboxed. Never invoke it any other way in these tests.
# </dev/null so the interactive overwrite prompt (install.sh:118) can never block.
run_install() {
    fixture_home="$1"; shift
    HOME="$fixture_home" CLAUDE_SKILLS_DIR="$fixture_home/.claude/skills" \
        sh "$INSTALL" "$@" </dev/null 2>&1
}

# ---- tests ----

# Red-phase behaviour: with HOME sandboxed and CLAUDE_SKILLS_DIR ignored,
# install.sh installs into $fixture/.claude/skills by the HOME path. So this
# test must assert CLAUDE_SKILLS_DIR is honoured on its own, pointed somewhere
# HOME would NOT resolve to. That is what turns it red before the fix.
test_target_dir_is_overridable() {
    home="$(mktemp -d)"
    mkdir -p "$home/.claude/skills"
    elsewhere="$(mktemp -d)/other-skills"
    mkdir -p "$elsewhere"

    HOME="$home" CLAUDE_SKILLS_DIR="$elsewhere" sh "$INSTALL" Sleep </dev/null >/dev/null 2>&1

    if [ -e "$elsewhere/Sleep/SKILL.md" ]; then
        pass "CLAUDE_SKILLS_DIR redirects the install target"
    else
        fail "CLAUDE_SKILLS_DIR redirects the install target" \
             "Sleep did not land in $elsewhere (pre-fix it goes to \$HOME instead)"
    fi
    rm -rf "$home" "$(dirname "$elsewhere")"
}

test_install_lands_under_sandboxed_home() {
    target="$(setup_fixture)"
    home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep >/dev/null
    if [ -e "$target/Sleep/SKILL.md" ]; then
        pass "sandboxed install produces a working skill dir"
    else
        fail "sandboxed install produces a working skill dir" "no Sleep/SKILL.md under $target"
    fi
    rm -rf "$home"
}

test_target_dir_is_overridable
test_install_lands_under_sandboxed_home

# Every test below uses run_install, so HOME and CLAUDE_SKILLS_DIR are both
# sandboxed and stdin is closed. Never call sh "$INSTALL" directly here.

test_refuses_to_destroy_real_files() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep >/dev/null
    printf "precious\n" > "$target/Sleep/NOTES.md"

    out="$(run_install "$home" --force Sleep)" || true

    if [ -f "$target/Sleep/NOTES.md" ]; then
        pass "human file survives --force"
    else
        fail "human file survives --force" "NOTES.md was destroyed"
    fi
    assert_contains "error names the file at risk" "NOTES.md" "$out"
    rm -rf "$home"
}

test_refuses_to_destroy_nested_file() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" RepoSkills >/dev/null
    mkdir -p "$target/RepoSkills/templates"
    printf "nested\n" > "$target/RepoSkills/templates/MINE.md"

    run_install "$home" --force RepoSkills >/dev/null || true

    if [ -f "$target/RepoSkills/templates/MINE.md" ]; then
        pass "nested human file survives --force"
    else
        fail "nested human file survives --force" "templates/MINE.md was destroyed"
    fi
    rm -rf "$home"
}

test_uninstall_also_refuses() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep >/dev/null
    printf "precious\n" > "$target/Sleep/NOTES.md"

    run_install "$home" --uninstall Sleep >/dev/null || true

    if [ -f "$target/Sleep/NOTES.md" ]; then
        pass "human file survives --uninstall"
    else
        fail "human file survives --uninstall" "NOTES.md was destroyed by uninstall"
    fi
    rm -rf "$home"
}

test_one_protected_skill_does_not_abort_the_run() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep RepoSkills >/dev/null
    printf "precious\n" > "$target/Sleep/NOTES.md"
    rm -f "$target/RepoSkills/SKILL.md"

    run_install "$home" --force Sleep RepoSkills >/dev/null || true

    if [ -e "$target/RepoSkills/SKILL.md" ]; then
        pass "a protected skill does not abort later skills"
    else
        fail "a protected skill does not abort later skills" \
             "RepoSkills was never reinstalled, so the loop exited early"
    fi
    rm -rf "$home"
}

test_allow_destroy_sets_aside_rather_than_deleting() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep >/dev/null
    printf "disposable\n" > "$target/Sleep/NOTES.md"

    out="$(run_install "$home" --force --allow-destroy Sleep)"

    if [ -f "$target/Sleep/NOTES.md" ]; then
        fail "--allow-destroy clears the install dir" "NOTES.md still in place"
    else
        pass "--allow-destroy clears the install dir"
    fi
    assert_contains "--allow-destroy reports where files went" "set aside" "$out"

    backup="$(printf "%s" "$out" | sed -n 's/.*set aside human files in \(.*\)$/\1/p' | head -1)"
    if [ -n "$backup" ] && [ -f "$backup/NOTES.md" ]; then
        pass "--allow-destroy preserves the file contents"
    else
        fail "--allow-destroy preserves the file contents" "not found under [$backup]"
    fi
    rm -rf "$home" "$backup"
}

test_force_still_works_on_symlinks_only() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep >/dev/null
    out="$(run_install "$home" --force Sleep)"
    assert_contains "clean --force still reports installed" "installed" "$out"
    rm -rf "$home"
}

test_refuses_to_destroy_real_files
test_refuses_to_destroy_nested_file
test_uninstall_also_refuses
test_one_protected_skill_does_not_abort_the_run
test_allow_destroy_sets_aside_rather_than_deleting
test_force_still_works_on_symlinks_only

test_check_passes_on_clean_install() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep >/dev/null
    if run_install "$home" --check Sleep >/dev/null; then
        pass "--check exits 0 on a clean install"
    else
        fail "--check exits 0 on a clean install" "non-zero exit"
    fi
    rm -rf "$home"
}

test_check_detects_missing_file() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep >/dev/null
    # Simulate the April failure: a file exists in stow but was never linked.
    victim="$(cd "$target/Sleep" && find . -type l | sed 's|^\./||' | head -1)"
    rm -f "$target/Sleep/$victim"

    out="$(run_install "$home" --check Sleep)" && rc=0 || rc=1

    assert_eq "--check exits 1 when a file is missing" "1" "$rc"
    assert_contains "--check names the missing file" "$victim" "$out"
    rm -rf "$home"
}

test_check_reports_not_installed() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    out="$(run_install "$home" --check Sleep)" && rc=0 || rc=1
    assert_eq "--check exits 1 when the skill is absent" "1" "$rc"
    assert_contains "--check says not installed" "not installed" "$out"
    rm -rf "$home"
}

test_check_detects_orphaned_symlink() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep >/dev/null
    # Simulate a file renamed in stow/: the target keeps a link to nothing.
    ln -sf "$REPO_ROOT/stow/Sleep/GONE.md" "$target/Sleep/GONE.md"

    out="$(run_install "$home" --check Sleep)" && rc=0 || rc=1

    assert_eq "--check exits 1 on a dangling symlink" "1" "$rc"
    assert_contains "--check reports it as ORPHANED" "ORPHANED" "$out"
    rm -rf "$home"
}

test_check_does_not_create_the_target_dir() {
    home="$(mktemp -d)"
    # No setup_fixture here: the point is that no skills directory exists.
    # --check is read-only by contract, so it must not manufacture the
    # directory it is inspecting the way an install does.
    run_install "$home" --check Sleep >/dev/null || true
    if [ -d "$home/.claude/skills" ]; then
        fail "--check leaves a missing target dir missing" \
             "it created $home/.claude/skills"
    else
        pass "--check leaves a missing target dir missing"
    fi
    rm -rf "$home"
}

test_check_passes_on_clean_install
test_check_detects_missing_file
test_check_reports_not_installed
test_check_detects_orphaned_symlink
test_check_does_not_create_the_target_dir

test_plain_install_tops_up_missing_files() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" RepoSkills >/dev/null
    victim="$(cd "$target/RepoSkills" && find . -type l ! -name 'SKILL.md' | sed 's|^\./||' | head -1)"
    rm -f "$target/RepoSkills/$victim"

    run_install "$home" RepoSkills >/dev/null

    if [ -e "$target/RepoSkills/$victim" ]; then
        pass "plain install restores a missing link"
    else
        fail "plain install restores a missing link" "$victim still absent after reinstall"
    fi
    rm -rf "$home"
}

test_plain_install_never_overwrites_a_user_file() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep >/dev/null
    # A user detaches one link to keep an edited copy of their own. SKILL.md
    # stays linked, so is_current_install still passes and the top-up runs.
    victim="$(cd "$target/Sleep" && find . -type l ! -name 'SKILL.md' | sed 's|^\./||' | head -1)"
    rm -f "$target/Sleep/$victim"
    printf "my precious edits\n" > "$target/Sleep/$victim"

    run_install "$home" Sleep >/dev/null || true

    if [ ! -L "$target/Sleep/$victim" ] && \
       [ "$(cat "$target/Sleep/$victim")" = "my precious edits" ]; then
        pass "flagless install leaves a detached user copy intact"
    else
        fail "flagless install leaves a detached user copy intact" \
             "$victim was linked over by the top-up"
    fi
    rm -rf "$home"
}

test_topup_collision_does_not_abort_the_run() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep RepoSkills >/dev/null
    # A user file where stow/Sleep has the Tools directory. Unguarded, the
    # top-up's mkdir -p fails on it and set -e kills the whole run mid-loop,
    # abandoning RepoSkills, whose missing link must still be restored.
    rm -rf "$target/Sleep/Tools"
    printf "user file\n" > "$target/Sleep/Tools"
    victim="$(cd "$target/RepoSkills" && find . -type l ! -name 'SKILL.md' | sed 's|^\./||' | head -1)"
    rm -f "$target/RepoSkills/$victim"

    run_install "$home" Sleep RepoSkills >/dev/null || true

    if [ -e "$target/RepoSkills/$victim" ]; then
        pass "a top-up collision does not abort later skills"
    else
        fail "a top-up collision does not abort later skills" \
             "RepoSkills was never topped up, so the run died on Sleep"
    fi
    if [ -f "$target/Sleep/Tools" ] && [ ! -L "$target/Sleep/Tools" ]; then
        pass "the colliding user file survives"
    else
        fail "the colliding user file survives" "Sleep/Tools was replaced"
    fi
    rm -rf "$home"
}

test_plain_install_tops_up_missing_files
test_plain_install_never_overwrites_a_user_file
test_topup_collision_does_not_abort_the_run

test_force_exits_nonzero_when_protected() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep >/dev/null
    printf "precious\n" > "$target/Sleep/NOTES.md"

    run_install "$home" --force Sleep >/dev/null && rc=0 || rc=1

    assert_eq "--force exits 1 when a skill is protected" "1" "$rc"
    rm -rf "$home"
}

test_declined_prompt_does_not_abort_the_run() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    # A foreign directory at Sleep, so the overwrite prompt is reached. run_install
    # closes stdin, so read hits EOF; unguarded that returns non-zero and set -e
    # kills the run before RepoSkills is ever reached.
    mkdir -p "$target/Sleep"
    printf "not ours\n" > "$target/Sleep/foreign.md"

    out="$(run_install "$home" Sleep RepoSkills)" || true

    if [ -e "$target/RepoSkills/SKILL.md" ]; then
        pass "a declined prompt does not abort later skills"
    else
        fail "a declined prompt does not abort later skills" \
             "RepoSkills was never installed, so read at EOF killed the loop"
    fi
    assert_contains "EOF on the prompt counts as a decline" "user declined" "$out"
    if [ -f "$target/Sleep/foreign.md" ]; then
        pass "declining leaves the foreign directory alone"
    else
        fail "declining leaves the foreign directory alone" "foreign.md was removed"
    fi
    rm -rf "$home"
}

test_force_exits_nonzero_when_protected
test_declined_prompt_does_not_abort_the_run

printf "\n%s run, %s failed\n" "$TESTS_RUN" "$TESTS_FAILED"
[ "$TESTS_FAILED" -eq 0 ]
