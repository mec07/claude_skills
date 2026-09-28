# Jira Ticket Templates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the `JIRA` skill a Create capability built on three capped, outcome-first templates, so that tickets are readable by a non-technical product manager and give a developer verifiable acceptance criteria.

**Architecture:** Three markdown templates under `stow/JIRA/Templates/`, two reference files stating the rules and the pre-creation check, one new workflow that renders and checks them, and a replacement for the section of `TechDebt` that currently generates the verbosity. Everything is prose that a person can read and edit; the only executable part is a new POSIX-sh test file that mechanically enforces the rules the templates state about themselves.

**Tech Stack:** Markdown skill files, POSIX `sh` tests in the style of `tests/install.test.sh`, the Atlassian MCP for Jira calls at runtime.

**Spec:** `docs/superpowers/specs/2026-09-28-jira-ticket-templates-design.md`

## Global Constraints

- **R1:** A ticket states the desired outcome and the acceptance criteria, never the solution. Carve-out: a fact the reporter already holds is evidence and stays; a direction to the implementer is instruction and goes. (Spec §2, R1.)
- **R2:** Nothing Jira has a field for appears in the body: priority, severity, labels, components, assignee, sprint, issue links, attachments, parent. (Spec §2, R2.)
- **R3:** No em dashes (`—`) or en dashes (`–`), no emoji prefixes, no bold severity labels, anywhere in a ticket body or in any worked example in these files. Inherited from `stow/JIRA/SKILL.md` Comment Workflow. (Spec §2, R3.)
- **Word caps:** Story 200, Bug 200, Epic 250. Counted over prose and bullet text only; headings, markdown syntax, checkbox markers, step numbers and URLs excluded. (Spec §3.)
- **Section caps:** exactly as tabulated in spec §3.1, §3.2 and §3.3. Copy the numbers; do not re-derive them.
- **Optional sections with nothing real to say are deleted, heading and all.** Never filled. (Spec §3.)
- **Inference and expansion are banned** in the Create workflow. (Spec §4.2.)
- **Installed path prefix** at runtime is `~/.claude/skills/JIRA/...`, because `install.sh` symlinks `stow/<Skill>/` to `$TARGET_DIR/<Skill>/`. Cross-skill references use that path, not `stow/`.
- **Every worked example in every file must pass `RuleCheck.md`.** An example that violates the rule it illustrates is worse than no example. (Spec §10.5.)

## Review Focus

These are behaviours the spec requires that no file's own worked example would otherwise exercise. Each is pinned to the task that owns it, and each is added there as a named worked case rather than a unit test, because the artifacts are prose read by a model at runtime.

1. **A request that matches two templates** — something that used to work *and* is also a request for new behaviour. Spec §4.1 says name the choice in one line and continue, never ask. Untested by any single-template example. → Task 6.
2. **More than seven acceptance criteria genuinely supplied by the user** — spec §3.1 requires a proposed split, shown, never a silent truncation or a merge of two criteria into one longer line. → Task 6.
3. **A project with a mandatory custom field the workflow does not know about** — spec §4.3 requires asking once by display name, inventing nothing, carrying no field id across projects. The failure mode is an error naming a field id and nothing else. → Task 6.
4. **An epic approved but every proposed child rejected** — spec §4.4 says the epic stands alone and this is a normal outcome, not a failure. → Task 6.
5. **Solution-language false positive on evidence** — a tech debt note naming a real file, or a bug naming a real account id. Spec §5 says the check quotes the line and asks rather than deleting silently. This is the single most likely way the rule check makes the skill worse than no skill. → Task 5, with the tech debt instance in Task 7.

---

## Task 1: Test harness and the rules reference

Creates the mechanical enforcement first, so every later task has something that can go red. Also creates `TicketRules.md`, which every template refers to.

**Files:**
- Create: `tests/ticket-templates.test.sh`
- Create: `stow/JIRA/Reference/TicketRules.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the shell functions `assert_file_contains <name> <needle> <file>`, `assert_file_lacks <name> <needle> <file>`, `assert_no_dashes <name> <file>`, `assert_at_most <name> <limit> <actual>`, `assert_at_least <name> <floor> <actual>` and `example_words <file>` (echoes an integer). Tasks 2, 3, 4, 5, 6 and 7 all call these by these exact names. Every needle passed to `assert_file_contains` and `assert_file_lacks` is matched with `grep -F`, so it is literal and case sensitive.

- [ ] **Step 1: Write the failing test**

Create `tests/ticket-templates.test.sh`:

```sh
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

# ---- runner ----

test_ticket_rules_exist

printf "\n%d run, %d failed\n" "$TESTS_RUN" "$TESTS_FAILED"
[ "$TESTS_FAILED" -eq 0 ]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/ticket-templates.test.sh`

Expected: FAIL. Eight failures, each reading `no such file: .../stow/JIRA/Reference/TicketRules.md`. Exit status 1.

- [ ] **Step 3: Write minimal implementation**

Create `stow/JIRA/Reference/TicketRules.md`:

```markdown
# Ticket rules

Three rules govern everything written into a Jira ticket body by this skill. The
templates in `Templates/` state their own sections and caps; these rules apply across all
of them.

## R1: Outcome, not solution

A ticket states what should be true when the work is done, and how you would know. It
never states the solution. Working out how is the job of whoever picks it up.

No file paths as instructions, no function or table names, no proposed approach, no
library choices, no migration plans. This holds for the most technical work in the
backlog: a ticket about a database index is written as the outcome the index would
produce.

**The evidence carve-out.** A fact the reporter already holds belongs in the ticket, even
when it names part of the system. The distinction is evidence against instruction.

- Evidence, and it stays: "This fails for account 44182." "The error is
  `connection reset by peer`." "It happens on the Users settings page."
- Instruction, and it goes: "Fix the account lookup in the billing module." "Add an index
  on the orders table." "Use the shared component instead."

When a line could be read either way, keep it and let the implementer decide. R1 exists to
stop a ticket dictating a solution, not to withhold what the reporter knows.

## R2: Nothing that Jira has a field for

Priority, severity, labels, components, assignee, sprint, issue links, attachments and
parent all have Jira fields. None of them appears in the body.

Restating a field as prose duplicates it, and the prose copy goes stale the first time the
field changes. Severity and priority are two separate axes, technical seriousness against
business urgency, and both are set as fields.

The same reasoning keeps the child-story list out of an epic body. Children are Jira
links, and a list in the body is wrong as soon as one is added.

## R3: Voice

The voice rules in `SKILL.md` under Comment Workflow apply unchanged to ticket bodies. In
short, and read the original for the reasoning: no em dashes or en dashes, no emoji
prefixes, no bold severity labels, minimal structure.

Tickets are frequently visible to people outside the company, and a ticket that reads as
machine-generated costs credibility with them.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/ticket-templates.test.sh`

Expected: PASS. `8 run, 0 failed`. Exit status 0.

- [ ] **Step 5: Verify the existing suite still passes**

Run: `sh tests/install.test.sh`

Expected: `28 run, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add tests/ticket-templates.test.sh stow/JIRA/Reference/TicketRules.md
git commit -m "Add ticket rules reference and its test harness"
```

---

## Task 2: Story template

**Files:**
- Create: `stow/JIRA/Templates/Story.md`
- Modify: `tests/ticket-templates.test.sh`

**Interfaces:**
- Consumes: `assert_file_contains`, `assert_file_lacks`, `assert_no_dashes`, `example_words`, `assert_at_most` from Task 1.
- Produces: the heading set `## What we want`, `## Why it matters`, `## Out of scope`, `## Acceptance criteria`. Task 7 renders this file by path `~/.claude/skills/JIRA/Templates/Story.md`.

- [ ] **Step 1: Write the failing test**

Add to `tests/ticket-templates.test.sh`, above the `# ---- runner ----` line:

```sh
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
    assert_at_most "Story example is within 200 words" 200 "$(example_words "$f")"

    # Acceptance criteria must be the last heading in the worked example.
    last="$(awk '/^```markdown$/ { f = 1; next } /^```$/ { if (f) exit } f && /^## / { h = $0 } END { print h }' "$f")"
    if [ "$last" = "## Acceptance criteria" ]; then
        pass "Story example ends with acceptance criteria"
    else
        fail "Story example ends with acceptance criteria" "last heading was [$last]"
    fi
}
```

Add `test_story_template` to the runner block, after `test_ticket_rules_exist`.

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/ticket-templates.test.sh`

Expected: FAIL. The new assertions report `no such file: .../stow/JIRA/Templates/Story.md`, and the last-heading check reports `last heading was []`.

- [ ] **Step 3: Write minimal implementation**

Create `stow/JIRA/Templates/Story.md`:

````markdown
# Story / Task / Feature

For new behaviour, a change, a chore, or tech debt. Anything that is not a bug and not a
body of work spanning several tickets.

Rules that apply to every section: `../Reference/TicketRules.md`.

**Whole ticket: 200 words maximum.**

| Section | | Cap |
|---|---|---|
| `## What we want` | required | 3 sentences |
| `## Why it matters` | required | 2 sentences |
| `## Out of scope` | optional | 3 bullets |
| `## Acceptance criteria` | required | 7 bullets, one line each |

An optional section with nothing real to say is deleted, heading and all. It is never
filled to make the ticket look complete.

## Worked example

```markdown
## What we want

Customers can change the card on file without contacting support.

## Why it matters

Card changes are the third most common support contact, around 200 a month.

## Acceptance criteria

- [ ] A customer with a saved card can replace it from their account page
- [ ] The old card stops being charged from the moment the new one is saved
- [ ] A card that fails validation leaves the existing card in place
- [ ] The customer is told why a card was rejected, in plain language
```

Note that `## Out of scope` is absent. There was nothing to exclude, so the heading was
deleted rather than filled.

## Writing each section

**`## What we want`** opens with a plain outcome sentence: what is true once this is done.
Not "As a / I want / So that". That form is the textbook one, and it is deliberately not
used here, because a large share of these tickets have no end user and the form then
forces an invented persona. The reasoning is in the design spec, section 7.2.

**`## Why it matters`** carries what the As-a form is genuinely good at: who benefits and
why. It is required for internal work as much as for customer-facing work. A number that
already exists beats an adjective.

**`## Acceptance criteria`** are an observable-outcome checklist. One line per criterion,
each a binary observable fact. Not Given/When/Then, for the reason in the design spec,
section 7.1.

A criterion is well formed when a person who did not write the ticket could look at the
running system and say yes or no without asking anyone.

- Fails the test: "Card validation is robust."
- Passes the test: "A card that fails validation leaves the existing card in place."

**More than 7 criteria is a split signal, not a truncation signal.** Over-specifying
acceptance criteria erodes negotiability and means the story should be split. Propose the
split and show the division. Never drop a criterion, and never merge two into one longer
line to fit the count.
````

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/ticket-templates.test.sh`

Expected: PASS. `21 run, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add stow/JIRA/Templates/Story.md tests/ticket-templates.test.sh
git commit -m "Add the Story ticket template"
```

---

## Task 3: Bug template

**Files:**
- Create: `stow/JIRA/Templates/Bug.md`
- Modify: `tests/ticket-templates.test.sh`

**Interfaces:**
- Consumes: the Task 1 helpers.
- Produces: the heading set `## What happens`, `## What should happen`, `## Steps to reproduce`, `## Where it was seen`, `## Impact`, `## Also true when fixed`.

- [ ] **Step 1: Write the failing test**

Add to `tests/ticket-templates.test.sh`, above `# ---- runner ----`:

```sh
test_bug_template() {
    f="$JIRA/Templates/Bug.md"
    assert_file_contains "Bug has What happens"          "## What happens" "$f"
    assert_file_contains "Bug has What should happen"    "## What should happen" "$f"
    assert_file_contains "Bug has Steps to reproduce"    "## Steps to reproduce" "$f"
    assert_file_contains "Bug has Where it was seen"     "## Where it was seen" "$f"
    assert_file_contains "Bug has Impact"                "## Impact" "$f"
    assert_file_contains "Bug has Also true when fixed"  "## Also true when fixed" "$f"
    assert_file_contains "Bug states its word cap"       "200 words" "$f"
    assert_file_contains "Bug caps repro steps at 6"     "6 numbered steps" "$f"
    assert_file_contains "Bug names the reproducibility bar" "follow-up question" "$f"
    assert_file_contains "Bug says unknown is omitted not guessed" "omitted rather than guessed" "$f"
    assert_file_lacks    "Bug has no acceptance criteria section" "## Acceptance criteria" "$f"
    assert_file_lacks    "Bug keeps severity out of the body" "## Severity" "$f"
    assert_no_dashes     "Bug obeys R3" "$f"
    assert_at_most "Bug example is within 200 words" 200 "$(example_words "$f")"
}
```

Add `test_bug_template` to the runner block.

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/ticket-templates.test.sh`

Expected: FAIL. Fourteen new failures reading `no such file: .../stow/JIRA/Templates/Bug.md`.

- [ ] **Step 3: Write minimal implementation**

Create `stow/JIRA/Templates/Bug.md`:

````markdown
# Bug

For something that used to work, or that behaves differently from what was expected.

Rules that apply to every section: `../Reference/TicketRules.md`.

**Whole ticket: 200 words maximum.** Evidence links do not count toward it.

| Section | | Cap |
|---|---|---|
| `## What happens` | required | 2 sentences |
| `## What should happen` | required | 2 sentences |
| `## Steps to reproduce` | required | 6 numbered steps, from a known start state |
| `## Where it was seen` | required | 3 lines |
| `## Impact` | required | 2 sentences |
| `## Also true when fixed` | optional | 4 bullets |

An optional section with nothing real to say is deleted, heading and all.

## Worked example

```markdown
## What happens

Reordering columns on the users table resets the order on the next page load.

## What should happen

A chosen column order persists for that user until they change it again.

## Steps to reproduce

1. Sign in as a user with the Operations role
2. Open Settings, then Users
3. Drag the Status column to the first position
4. Reload the page

## Where it was seen

PX portal, production, 2026-09-24.
Chrome 141 on macOS, also reproduced in Safari 26.
Account 44182.

## Impact

Operations reset the column order several times a day. Nobody is blocked, but it is a
constant irritation and it was reported three times last month.
```

Note that `## Also true when fixed` is absent. The repro covers everything the fix has to
satisfy, so the heading was deleted.

## Writing each section

**There is no acceptance criteria section, and this is deliberate.** `## What should
happen` combined with `## Steps to reproduce` is the acceptance criterion. The bar is that
a second person can reproduce the bug without asking a follow-up question. An acceptance
criteria section would restate those two in different words.

**`## Steps to reproduce`** start from a known state, name the exact screen, control and
value, and use the fewest steps that still trigger the bug. Trim anything not needed.

**`## Where it was seen`** is one line each of environment, version or build, and the
account or record involved, as far as they are known. Unknown is omitted rather than
guessed. Three lines of real detail beat six of speculation.

**`## Impact`** says who is affected and how often, in numbers where numbers exist. It does
not set a priority: priority and severity are Jira fields, per R2, and they are two
separate axes.

**`## Also true when fixed`** exists only for conditions the fix must satisfy that the
repro does not imply. Correcting rows already written wrongly is the common case. If there
is no such condition, delete the section.

**No proposed fix**, per R1. Name what you observed and what you expected. Diagnosis is
the job of whoever picks it up. A log line or a failing record id that you already have is
evidence and belongs here; a theory about the cause is not.
````

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/ticket-templates.test.sh`

Expected: PASS. `35 run, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add stow/JIRA/Templates/Bug.md tests/ticket-templates.test.sh
git commit -m "Add the Bug ticket template"
```

---

## Task 4: Epic template

**Files:**
- Create: `stow/JIRA/Templates/Epic.md`
- Modify: `tests/ticket-templates.test.sh`

**Interfaces:**
- Consumes: the Task 1 helpers.
- Produces: the heading set `## Goal`, `## Why now`, `## In scope`, `## Out of scope`, `## Done when`, `## Risks and dependencies`.

- [ ] **Step 1: Write the failing test**

Add to `tests/ticket-templates.test.sh`, above `# ---- runner ----`:

```sh
test_epic_template() {
    f="$JIRA/Templates/Epic.md"
    assert_file_contains "Epic has Goal"          "## Goal" "$f"
    assert_file_contains "Epic has Why now"       "## Why now" "$f"
    assert_file_contains "Epic has In scope"      "## In scope" "$f"
    assert_file_contains "Epic has Out of scope"  "## Out of scope" "$f"
    assert_file_contains "Epic has Done when"     "## Done when" "$f"
    assert_file_contains "Epic has Risks and dependencies" "## Risks and dependencies" "$f"
    assert_file_contains "Epic states its word cap" "250 words" "$f"
    assert_file_contains "Epic requires Out of scope" "required here" "$f"
    assert_file_contains "Epic wants an outcome not a deliverable" "not a deliverable" "$f"
    assert_file_contains "Epic requires one measurable bullet" "measurable" "$f"
    assert_file_contains "Epic keeps children out of the body" "Jira links" "$f"
    assert_file_contains "Epic refuses to fabricate a target" "fabricat" "$f"
    assert_no_dashes     "Epic obeys R3" "$f"
    assert_at_most "Epic example is within 250 words" 250 "$(example_words "$f")"
}
```

Add `test_epic_template` to the runner block.

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/ticket-templates.test.sh`

Expected: FAIL. Fourteen new failures reading `no such file: .../stow/JIRA/Templates/Epic.md`.

- [ ] **Step 3: Write minimal implementation**

Create `stow/JIRA/Templates/Epic.md`:

````markdown
# Epic

For a body of work spanning several tickets. Also for anything described as an initiative
or a programme.

Rules that apply to every section: `../Reference/TicketRules.md`.

**Whole epic: 250 words maximum.**

| Section | | Cap |
|---|---|---|
| `## Goal` | required | 1 sentence, an outcome not a deliverable |
| `## Why now` | required | 3 sentences |
| `## In scope` | required | 5 bullets |
| `## Out of scope` | required | 5 bullets |
| `## Done when` | required | 4 bullets, at least one measurable |
| `## Risks and dependencies` | optional | 3 bullets |

## Worked example

```markdown
## Goal

Customers manage their own payment details without contacting support.

## Why now

Card and billing changes are the third largest source of support contacts. Each one takes
an agent around eight minutes and requires them to see data they should not need to see.

## In scope

- Replacing the card on file
- Changing the billing address
- Viewing and downloading past invoices

## Out of scope

- Changing the billing currency
- Anything on the mobile apps
- Invoice disputes, which stay with support

## Done when

- Card and billing support contacts fall below 60 a month, from around 200
- A customer can replace a card and see the change reflected without contacting anyone
- No support agent needs to view full card details to resolve a billing contact
```

## Writing each section

**`## Goal` states an outcome, not a deliverable.** "Customers manage their own payment
details" is an outcome. "Build a payment settings page" is a deliverable, and a deliverable
in the goal has already chosen the solution.

**`## Out of scope` is required here**, where it is optional on a story. Unbounded scope is
the way epics fail, and an epic with nothing excluded is usually one nobody has bounded
yet. If nothing comes to mind, that is the signal to think harder, not to delete the
heading.

**`## Done when` carries at least one measurable bullet.** Prefer a number that already
exists over one invented to satisfy this rule. Where no number is available, a binary
observable statement is accepted: say so plainly rather than fabricating a target.

**Child stories do not appear in the body.** They are Jira links, per R2. A list here is
wrong as soon as a child is added.
````

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/ticket-templates.test.sh`

Expected: PASS. `49 run, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add stow/JIRA/Templates/Epic.md tests/ticket-templates.test.sh
git commit -m "Add the Epic ticket template"
```

---

## Task 5: The rule check

Owns Review Focus item 5: the false positive where evidence is mistaken for instruction.

**Files:**
- Create: `stow/JIRA/Reference/RuleCheck.md`
- Modify: `tests/ticket-templates.test.sh`

**Interfaces:**
- Consumes: the Task 1 helpers.
- Produces: `RuleCheck.md`, referenced by path `~/.claude/skills/JIRA/Reference/RuleCheck.md` from Task 6 and Task 7.

- [ ] **Step 1: Write the failing test**

Add to `tests/ticket-templates.test.sh`, above `# ---- runner ----`:

```sh
test_rule_check() {
    f="$JIRA/Reference/RuleCheck.md"
    assert_file_contains "RuleCheck checks section caps"    "within its stated cap" "$f"
    assert_file_contains "RuleCheck checks the word cap"    "word cap" "$f"
    assert_file_contains "RuleCheck checks required sections" "required section" "$f"
    assert_file_contains "RuleCheck checks for filler"      "filler" "$f"
    assert_file_contains "RuleCheck checks solution language" "solution language" "$f"
    assert_file_contains "RuleCheck checks R2"              "Jira field" "$f"
    assert_file_contains "RuleCheck checks dashes"          "em dash" "$f"
    assert_file_contains "RuleCheck checks criteria are observable" "observable" "$f"
    assert_file_contains "RuleCheck never creates on failure" "never means create anyway" "$f"
    assert_file_contains "RuleCheck surfaces a twice-failed item" "twice" "$f"
    assert_file_contains "RuleCheck handles the evidence false positive" "false positive" "$f"
    assert_no_dashes "RuleCheck obeys R3" "$f"

    # The checklist itself must have at least ten items.
    n="$(grep -c '^- \[ \] ' "$f" 2>/dev/null || echo 0)"
    assert_at_least "RuleCheck has at least ten checklist items" 10 "$n"
}
```

Add `test_rule_check` to the runner block.

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/ticket-templates.test.sh`

Expected: FAIL. Twelve failures reading `no such file: .../stow/JIRA/Reference/RuleCheck.md`, plus `expected >= 10, got 0`.

- [ ] **Step 3: Write minimal implementation**

Create `stow/JIRA/Reference/RuleCheck.md`:

```markdown
# Rule check

Run this against the rendered ticket body before showing it to the user, every time.

- [ ] Every section is within its stated cap
- [ ] The whole ticket is within its word cap
- [ ] Every required section is present and says something real
- [ ] No optional section is present with filler in it
- [ ] No solution language: a file or function named as a place to change, a proposed
      approach, a named library, an instruction to use or refactor or add something
- [ ] Nothing that belongs in a Jira field appears in the body, per R2
- [ ] No em dash and no en dash anywhere
- [ ] No emoji prefix and no bold severity label
- [ ] Acceptance criteria, where present, are each observable and binary
- [ ] Acceptance criteria, where present, are the last section of the ticket

## What a failure means

A failed check means revise and run the check again. It **never means create anyway**.

An item that fails twice on the same text is surfaced to the user with the offending line
quoted, rather than attempted a third time. Two failures mean the check and the draft
disagree about something a person should settle.

## The solution-language false positive

This is the check most likely to be wrong, and the way it goes wrong makes the skill worse
than no skill: it strips out the evidence that made the ticket actionable.

R1's carve-out governs. A fact the reporter already holds is evidence and stays. A
direction to the implementer is instruction and goes.

| Line | Verdict |
|---|---|
| "This fails for account 44182" | Evidence. Keep. |
| "The error is `connection reset by peer`" | Evidence. Keep. |
| "The users table in the PX portal duplicates the SP portal's" | Evidence. Keep. |
| "Use the shared component from the ui package" | Instruction. Remove. |
| "Add an index on the orders table" | Instruction. Remove. |
| "Refactor the lookup before adding the field" | Instruction. Remove. |

**When unsure, quote the line and ask.** Never delete silently. A reporter who finds their
evidence removed will stop using the skill, and that costs more than one extra question.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/ticket-templates.test.sh`

Expected: PASS. `62 run, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add stow/JIRA/Reference/RuleCheck.md tests/ticket-templates.test.sh
git commit -m "Add the pre-creation rule check"
```

---

## Task 6: The Create workflow

Owns Review Focus items 1, 2, 3 and 4. Each appears as a named worked case in the workflow file, and each has a test asserting the case is present.

**Files:**
- Create: `stow/JIRA/Workflows/Create.md`
- Modify: `stow/JIRA/SKILL.md` (routing table, and a link to `Reference/TicketRules.md`)
- Modify: `tests/ticket-templates.test.sh`

**Interfaces:**
- Consumes: all three templates from Tasks 2 to 4, `RuleCheck.md` from Task 5, `TicketRules.md` from Task 1.
- Produces: `Workflows/Create.md`, cited from the `SKILL.md` routing table.

- [ ] **Step 1: Write the failing test**

Add to `tests/ticket-templates.test.sh`, above `# ---- runner ----`:

```sh
test_create_workflow() {
    f="$JIRA/Workflows/Create.md"
    assert_file_contains "Create routes to the Bug template"   "Templates/Bug.md" "$f"
    assert_file_contains "Create routes to the Epic template"  "Templates/Epic.md" "$f"
    assert_file_contains "Create routes to the Story template" "Templates/Story.md" "$f"
    assert_file_contains "Create runs the rule check"          "RuleCheck.md" "$f"
    assert_file_contains "Create bans inference"               "never infers" "$f"
    assert_file_contains "Create batches missing required sections" "one batched" "$f"
    assert_file_contains "Create gets approval before creating" "before creating" "$f"
    assert_file_contains "Create checks required Jira fields"  "getJiraIssueTypeMetaWithFields" "$f"
    assert_file_contains "Create sends markdown"               "contentFormat" "$f"
    # Review Focus 1
    assert_file_contains "Create handles an ambiguous template choice" "names its choice" "$f"
    # Review Focus 2
    assert_file_contains "Create proposes a split over the cap" "Propose the split" "$f"
    # Review Focus 3
    assert_file_contains "Create invents no custom field value" "invent" "$f"
    # Review Focus 4
    assert_file_contains "Create lets an epic stand alone" "stands alone" "$f"
    assert_no_dashes "Create obeys R3" "$f"

    s="$JIRA/SKILL.md"
    assert_file_contains "SKILL routing has a Create row" "**Create**" "$s"
    assert_file_contains "SKILL links the ticket rules" "TicketRules.md" "$s"
}
```

Add `test_create_workflow` to the runner block.

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/ticket-templates.test.sh`

Expected: FAIL. Fourteen failures reading `no such file: .../stow/JIRA/Workflows/Create.md`, plus two failures on `stow/JIRA/SKILL.md` for the missing routing row and rules link.

- [ ] **Step 3: Write minimal implementation**

Create `stow/JIRA/Workflows/Create.md`:

````markdown
# JIRA Create Workflow

Create a ticket that a non-technical reader can understand and a developer can verify.

Read first: `../Reference/TicketRules.md`. Everything below assumes R1, R2 and R3.

---

## Step 1: Choose the template

| Signal in the request | Template |
|---|---|
| Something used to work, or behaves differently from what was expected | `../Templates/Bug.md` |
| A body of work spanning several tickets, or the words epic, initiative, programme | `../Templates/Epic.md` |
| Anything else: new behaviour, a change, a chore, tech debt | `../Templates/Story.md` |

Where two could apply, the workflow **names its choice in one line and continues**. It does
not ask. A wrong guess costs one correction; a question costs an interruption every time.

**Worked case, an ambiguous request.** "The export used to include archived rows and now it
does not, and while we are there it should also do CSV." That is a regression and a feature
request. Say: "Raising this as a bug about the archived rows. The CSV request needs its own
story, say the word." Then create the bug. Do not create both without being asked, and do
not silently fold the feature into the bug.

---

## Step 2: Fill the template

1. Map what the user actually said onto the template's sections.
2. Delete every optional section with nothing real to say.
3. For required sections with nothing to say, collect **one batched** `AskUserQuestion`
   covering all of them at once.
4. Cut each section to its cap.

**The workflow never infers, expands, or pads a section to make a ticket look complete.**
This is the most important rule in this file. Unguided expansion is what makes tickets
unreadable, and every other measure here is downstream of stopping it.

A one-line note becomes a short ticket. That is the correct outcome, not a deficiency to
be corrected by writing more.

**Worked case, more criteria than the cap.** The user gives nine acceptance criteria for
one story. Do not truncate to seven, and do not merge two into one longer line. **Propose
the split**: show two stories with the criteria divided between them, and say which
criteria went where. The user approves, redraws the line, or says keep it as one. Over-
specifying acceptance criteria erodes negotiability, and nine criteria is usually two
stories that have not been separated yet.

---

## Step 3: Run the rule check

Run `../Reference/RuleCheck.md` against the rendered body. A failure means revise and run
it again. It never means create anyway.

---

## Step 4: Show it and get approval

Show the rendered ticket in the conversation **before creating anything**. A ticket
notifies watchers and cannot be quietly withdrawn, which is the same reason the Comment
workflow requires a draft first.

Name any judgement call the draft makes, so that keeping it is the user's decision rather
than a default.

---

## Step 5: Check the required Jira fields

```
getJiraIssueTypeMetaWithFields
  projectIdOrKey: {PROJECT}
  issueTypeId:    {resolved for this project and issue type}
```

Projects carry mandatory custom fields, and a missing one fails with an error that names a
field id and nothing else.

Anything flagged required and not already known is asked about once, by its display name.
**Never invent a value for a required custom field**, and never carry a field id from
another project: ids are not portable, and a stale one fails without saying why.

---

## Step 6: Create it

```
createJiraIssue
  projectKey:    {PROJECT}
  issueTypeName: {Bug | Epic | Story, or the project's equivalent}
  summary:       one line, sentence case, no trailing full stop
  description:   the rendered body
  contentFormat: "markdown"
  additional_fields:
    priority, labels, components, assignee, parent as applicable
```

Everything in `additional_fields` is a field, per R2, and none of it is repeated in the
body.

---

## Step 7: Epic with child stories

Triggered by an epic request that also describes the work beneath it.

1. Render and create the epic, per steps 1 to 6.
2. Propose child stories **in the conversation only**, as a title plus a one-line outcome
   each. Create nothing at this point.
3. The user cuts, edits and approves the list.
4. Render each approved story in full, per steps 2 to 5, and show them.
5. Create only the approved stories, each with `parent` set to the epic key.

**No child is ever created that the user has not seen.** Proposing children is where an
agent is most tempted to invent scope to fill a list, so the proposal stage is deliberately
cheap: a title and one line. That makes cutting easy and makes an invented child obvious.

**Worked case, every child rejected.** The user approves the epic and cuts all six proposed
stories. The epic **stands alone**. That is a normal outcome, not a failure, and it usually
means the epic was worth capturing before its breakdown was understood. Do not propose a
replacement set unless asked.

---

## Error handling

| Situation | Action |
|-----------|--------|
| Rule check fails twice on the same item | Quote the offending line and ask the user |
| Required custom field unknown | Ask once by display name; never invent a value |
| `createJiraIssue` fails | Show the raw error and the equivalent call to run manually |
| User rejects the draft | Revise from their words; do not start over from the brief |
````

Then modify `stow/JIRA/SKILL.md`. Add this row to the Workflow Routing table, directly above the `**Comment**` row:

```markdown
| **Create** | "create a ticket", "raise a bug", "new story", "create an epic" | Render a template, run the rule check, then MCP `createJiraIssue`. See Create Workflow |
```

And add this paragraph directly under the `## Workflow Routing` table, before `## Comment Workflow`:

```markdown
Everything written into a ticket body follows `Reference/TicketRules.md`: state the
outcome and the acceptance criteria, never the solution; keep out anything Jira has a
field for; and keep the voice rules below. The templates are in `Templates/`.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/ticket-templates.test.sh`

Expected: PASS. `78 run, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add stow/JIRA/Workflows/Create.md stow/JIRA/SKILL.md tests/ticket-templates.test.sh
git commit -m "Add the JIRA Create workflow and route to it"
```

---

## Task 7: Replace TechDebt Step 4

Owns the tech debt instance of Review Focus item 5.

**Files:**
- Modify: `stow/TechDebt/Workflows/Create.md` (Step 4, currently the `## Problem` / `## Why It Matters` / `## Suggested Approach` / `## Context` expansion prompt)
- Modify: `tests/ticket-templates.test.sh`

**Interfaces:**
- Consumes: `~/.claude/skills/JIRA/Templates/Story.md` and `~/.claude/skills/JIRA/Reference/RuleCheck.md`, by installed path rather than by `stow/` path, because TechDebt reads them at runtime.
- Produces: nothing other tasks consume.

- [ ] **Step 1: Write the failing test**

Add to `tests/ticket-templates.test.sh`, above `# ---- runner ----`:

```sh
test_techdebt_uses_story_template() {
    f="$TECHDEBT/Workflows/Create.md"
    assert_file_lacks    "TechDebt no longer prescribes an approach" "Suggested Approach" "$f"
    assert_file_lacks    "TechDebt no longer uses its own headings"  "## Why It Matters" "$f"
    assert_file_contains "TechDebt renders the Story template" "skills/JIRA/Templates/Story.md" "$f"
    assert_file_contains "TechDebt runs the rule check" "skills/JIRA/Reference/RuleCheck.md" "$f"
    assert_file_contains "TechDebt restates a complaint as an outcome" "not an outcome" "$f"
    assert_file_contains "TechDebt keeps named files as evidence" "evidence" "$f"
}
```

Add `test_techdebt_uses_story_template` to the runner block.

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/ticket-templates.test.sh`

Expected: FAIL. Six failures. The first two report the strings that should be gone but are still present; the last four report strings not found.

- [ ] **Step 3: Write minimal implementation**

In `stow/TechDebt/Workflows/Create.md`, replace the whole of Step 4, from the `## Step 4 — Expand Description with AI` heading up to but not including the `## Step 5 — Create the Jira Ticket` heading, with:

````markdown
## Step 4 — Render the Story template

Tech debt is a story. Render `~/.claude/skills/JIRA/Templates/Story.md` against the user's
note, then run `~/.claude/skills/JIRA/Reference/RuleCheck.md` against the result.

Do not expand the note. A one-line note becomes a short ticket, and that is the correct
outcome. The old behaviour here was to grow a note into four headings, one of which
proposed the fix; that is what made these tickets unreadable.

**`## What we want` needs the note restated as an end state.** Tech debt arrives as a
complaint, and a complaint is not an outcome.

- As reported: "The UsersTable in the PX portal duplicates logic from the SP portal."
- As the ticket: "The PX portal users table uses the shared component, so a change to it
  takes effect in both portals."

**Named files stay.** A tech debt note almost always names where the problem lives, and
that is evidence the reporter already holds, not an instruction. R1's carve-out covers it.
What goes is the direction about what to do: "should use the shared generic UsersTable
from packages/ui" is an instruction and is dropped, while the fact that the duplication
exists between those two portals is kept.

**`## Acceptance criteria` is required**, as it is for any story. For tech debt the
criteria are usually about behaviour that must not change: the same rows render, the same
permissions apply, the existing tests still pass.
````

Leave every other step in the file unchanged. Duplicate detection, the required-fields
check, the fixability assessment and the worktree offer all still work.

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/ticket-templates.test.sh`

Expected: PASS. `84 run, 0 failed`.

- [ ] **Step 5: Verify nothing else in TechDebt broke**

Run: `grep -n "Step 5\|Step 6\|Step 7\|Step 8" stow/TechDebt/Workflows/Create.md`

Expected: Steps 5, 6, 6b, 7 and 8 are all still present and in order.

- [ ] **Step 6: Commit**

```bash
git add stow/TechDebt/Workflows/Create.md tests/ticket-templates.test.sh
git commit -m "Point TechDebt at the Story template instead of expanding notes"
```

---

## Task 8: The worked before and after

Spec §10.1 names this as the primary evidence that the feature works, and as a deliverable of this plan.

**Files:**
- Create: `docs/superpowers/specs/2026-09-28-jira-ticket-templates-worked-example.md`

**Interfaces:**
- Consumes: all three templates and `RuleCheck.md`.
- Produces: nothing other tasks consume.

- [ ] **Step 1: Find a real verbose ticket**

Ask the user for one real ticket key that exemplifies the problem, then fetch it:

```
getJiraIssue
  issueIdOrKey:          {KEY}
  fields:                ["summary", "description", "issuetype"]
  responseContentFormat: "markdown"
```

If the user would rather not name a real ticket, ask them to paste the body with identifying detail removed. Do not invent a "before" ticket: a fabricated one would be built to lose, which proves nothing.

- [ ] **Step 2: Write the document**

Create `docs/superpowers/specs/2026-09-28-jira-ticket-templates-worked-example.md` with, in this order:

1. The ticket key or a note that it is anonymised, and its word count.
2. The full original body, quoted verbatim in a fenced block.
3. The rewritten body, rendered through the matching template, in a fenced block.
4. The new word count and the reduction as a percentage.
5. A short table: for each section or paragraph removed, which rule removed it (R1, R2, a cap, or the delete-empty-optional rule).
6. Anything the rewrite lost that a reader might actually want, stated plainly. If the answer is nothing, say so. If the rewrite lost something real, that is a finding about the templates and belongs in this document, not hidden.

- [ ] **Step 3: Verify the rewrite against its own rules**

Run `stow/JIRA/Reference/RuleCheck.md` by hand against the "after" body. Every item passes, or the rewrite is revised until they do.

Then confirm the word count against the template's cap: 200 for a story or a bug, 250 for an epic.

- [ ] **Step 4: Run the full suite**

Run: `sh tests/ticket-templates.test.sh && sh tests/install.test.sh`

Expected: `84 run, 0 failed` then `28 run, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-09-28-jira-ticket-templates-worked-example.md
git commit -m "Add the worked before and after for the ticket templates"
```

---

## Task 9: Final verification

**Files:**
- Modify: none expected.

- [ ] **Step 1: Run both suites**

Run: `sh tests/ticket-templates.test.sh && sh tests/install.test.sh`

Expected: `84 run, 0 failed` then `28 run, 0 failed`.

- [ ] **Step 2: Verify the skill installs with the new directories**

Run:

```bash
tmp="$(mktemp -d)"
mkdir -p "$tmp/.claude/skills"
HOME="$tmp" CLAUDE_SKILLS_DIR="$tmp/.claude/skills" sh install.sh JIRA TechDebt
ls -l "$tmp/.claude/skills/JIRA/Templates/" "$tmp/.claude/skills/JIRA/Reference/"
```

Expected: `Story.md`, `Bug.md`, `Epic.md` in `Templates/`, and `TicketRules.md`, `RuleCheck.md` in `Reference/`, each a symlink back into `stow/`. `install_symlinks` (`install.sh:124`) recurses, so no change to `install.sh` is needed; this step confirms that rather than assuming it.

- [ ] **Step 3: Check drift**

Run: `sh install.sh --check JIRA TechDebt`

Expected: exit 0, no drift reported, assuming the skills are installed locally. If they are not installed, this reports "not installed" and exits 1, which is not a failure of this plan.

- [ ] **Step 4: Read every new file once, end to end**

The non-technical reader test, the developer test and the reproducibility test from spec §10 are judgement calls that no assertion covers. Read each template as if you did not know this codebase and confirm:

- No section requires knowing the codebase to understand.
- A developer reading only the acceptance criteria knows what to build and when to stop.
- The bug worked example could be reproduced by someone else without a follow-up question.

- [ ] **Step 5: Commit any fixes**

```bash
git add -A
git commit -m "Fix findings from the final read-through"
```
