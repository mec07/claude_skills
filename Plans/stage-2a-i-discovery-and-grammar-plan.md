# Stage 2a-i: Discovery and Grammar Artifacts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Teach the pipeline to discover a repo's project system, gate its unit list on ownership signals, and emit three repo-specific grammar artifacts, without writing a single README yet.

**Architecture:** Additive changes to instruction files only. Phase 0 gains project-system discovery and records a gated unit list in `state.md`. Phase 2 gains a generation step for `.ai/skills/conventions.md`, `.ai/skills/readme-template.md` and `.ai/skills/tasks/navigate-unit.md`, with the README grammar living in its own instruction file rather than growing `phase-2-map-generate.md`. Nothing in `modules/` is touched, so the pipeline keeps working throughout.

**Tech Stack:** Markdown instruction files (`stow/RepoSkills/*.md`), POSIX `sh` for the test harness, `git` for the fixture repo. No new dependencies.

**Spec:** `/Users/powerx/src/github.com/mec07/claude_skills/Plans/RepoSkills-readme-mode-and-backlog-design.md`, sections 3, 3.1, 4, 5.1, 5.2, 5.3, and stage 2a of section 8.

## Where everything lives

Absolute paths, because each task may be executed by a fresh agent in a fresh session with no
inherited shell state. **Nothing in this plan relies on a variable set by an earlier task.**

| | Path |
|---|---|
| **Repository** | `/Users/powerx/src/github.com/mec07/claude_skills` |
| **Branch** | `reposkills-readme-mode-spec` (already checked out; do not create a new one) |
| **Skill source** | `/Users/powerx/src/github.com/mec07/claude_skills/stow/RepoSkills/` |
| **Fixture repo** | `/Users/powerx/src/github.com/mec07/claude_skills/tests/fixture-repo` |
| **Fixture state file** | `~/.claude/MEMORY/RepoSkills/fixture-repo/state.md` |

### Run this first, in every task

```bash
cd /Users/powerx/src/github.com/mec07/claude_skills
git branch --show-current      # expect: reposkills-readme-mode-spec
export REPO="$PWD"
export FIXTURE="$REPO/tests/fixture-repo"
export STATE="$HOME/.claude/MEMORY/RepoSkills/fixture-repo/state.md"
```

Every path in this plan is either absolute or relative to `$REPO`. The fixture lives at a fixed,
gitignored location rather than a `mktemp` directory precisely so that a task run hours later, by a
different agent, finds the same repo in the same state.

**To reset the fixture** at any point: `rm -rf "$FIXTURE" && sh "$REPO/tests/fixtures/make-fixture-repo.sh" "$FIXTURE"`

## Global Constraints

- **This is stage 2a, the expand half.** Nothing may remove, rename or stop generating `.ai/skills/modules/`. Every repo must stay internally consistent at all times. Removal is 2b's job.
- **Instruction files are prompts, not code.** A "test" here is a scenario run against a fixture repo followed by assertions on the artifacts produced. There is no unit-test framework and none should be introduced.
- **The Iron Law applies to edits of existing skills**, not only to new skills: run the baseline scenario and record what the pipeline does *before* each change. A change whose baseline was never observed is not verified.
- **Gate on the "Signals detected" field, never on Confidence.** Confidence is defined as `medium` for both "one strong" and "two medium" (`phase-0-discover.md:200`), so it cannot express the gate.
- **Deployment is a Medium signal** (`phase-0-discover.md:177`). It never alone qualifies a boundary.
- **Generated tooling targets bash 3.2**, macOS stock. Not bash 4+.
- **No em dashes in any prose added to the repository.**
- **Token budget:** `phase-2-map-generate.md` is already 1199 lines and is the largest file in the skill. Do not grow it by more than the wiring needed to call out to a new file.
- Every task ends with a commit.

---

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `tests/fixtures/make-fixture-repo.sh` | Builds a deterministic repo exercising every boundary shape the gate must distinguish | 1 |
| `tests/assert-phase0.sh` | Asserts on `state.md` after a Phase 0 run | 2, 3 |
| `tests/assert-artifacts.sh` | Asserts on the three generated grammar artifacts | 4, 5, 6 |
| `stow/RepoSkills/phase-0-discover.md` | Gains project-system discovery (Step 4.5) and gate recording | 2, 3 |
| `stow/RepoSkills/orchestration.md` | `state.md` schema additions; the `:414` amendment | 2, 4 |
| `stow/RepoSkills/readme-grammar.md` | **New.** The section grammar, the include test, the induction loop | 5 |
| `stow/RepoSkills/phase-2-map-generate.md` | Wiring only: a step that reads `readme-grammar.md` and emits the three artifacts | 4, 5, 6 |
| `stow/RepoSkills/SKILL.md` | Output table and phase-file table | 7 |

---

### Task 1: A fixture repo that exercises every boundary shape

**Files:**
- Create: `tests/fixtures/make-fixture-repo.sh`
- Create: `tests/fixtures/README.md`

**Interfaces:**
- Consumes: nothing.
- Produces: `make-fixture-repo.sh <target-dir>` creates a git repo and echoes its path. Every later task runs against it. The shapes it contains, and the behaviour each one pins down, are the contract later tasks assert against.

**Why this is first.** Section 9 of the spec names three regression targets and says naming them is a prerequisite. This is the first of them, and it is the only one that can be made deterministic. Testing discovery against a real repo means the assertions drift whenever that repo changes.

- [ ] **Step 1: Write the fixture generator**

Create `tests/fixtures/make-fixture-repo.sh`:

```sh
#!/bin/sh
# Builds a deterministic fixture repo for RepoSkills discovery tests.
# Usage: make-fixture-repo.sh <target-dir>   (echoes the created path)
set -eu

[ $# -eq 1 ] || { echo "usage: $0 <target-dir>" >&2; exit 1; }
ROOT="$1"
mkdir -p "$ROOT"
cd "$ROOT"

# --- deployable service: Strong (manifest) + Strong (Dockerfile) + Medium (CI) ---
mkdir -p services/orders/src
cat > services/orders/package.json <<'EOF'
{ "name": "@fixture/orders", "version": "1.0.0", "scripts": { "dev": "node src/index.js" } }
EOF
printf 'FROM node:20\n' > services/orders/Dockerfile
printf 'console.log("orders");\n' > services/orders/src/index.js
mkdir -p .github/workflows
printf 'name: orders\non: push\n' > .github/workflows/orders.yml

# --- deployable service WITH a pre-existing sparse README: the update path ---
mkdir -p services/billing/src
cat > services/billing/package.json <<'EOF'
{ "name": "@fixture/billing", "version": "1.0.0" }
EOF
printf 'FROM node:20\n' > services/billing/Dockerfile
printf 'console.log("billing");\n' > services/billing/src/index.js
cat > services/billing/README.md <<'EOF'
# billing

Handles invoicing. Talks to the payments provider; retries are not idempotent.
EOF

# --- nested package INSIDE a deployable service: the nesting case ---
mkdir -p services/orders/vendor/pricing
cat > services/orders/vendor/pricing/package.json <<'EOF'
{ "name": "@fixture/pricing", "version": "1.0.0" }
EOF
printf 'module.exports = {};\n' > services/orders/vendor/pricing/index.js

# --- non-deployable library: Strong (manifest), no Dockerfile: slim skeleton ---
mkdir -p packages/utils/src
cat > packages/utils/package.json <<'EOF'
{ "name": "@fixture/utils", "version": "1.0.0" }
EOF
printf 'export const noop = () => {};\n' > packages/utils/src/index.js

# --- logical-only boundary: Medium (own types, clear API) + Medium (own tables).
#     No manifest, no Dockerfile. MUST be gated behind confirmation. ---
mkdir -p src/reporting
printf 'export type Report = { id: string };\n' > src/reporting/types.ts
printf 'export const build = () => ({ id: "1" });\n' > src/reporting/index.ts
printf 'CREATE TABLE reports (id text primary key);\n' > src/reporting/schema.sql

# --- miscased readme: the unit HAS a README and it must be renamed, not duplicated ---
mkdir -p services/notifications/src
cat > services/notifications/package.json <<'EOF'
{ "name": "@fixture/notifications", "version": "1.0.0" }
EOF
printf 'FROM node:20\n' > services/notifications/Dockerfile
printf 'console.log("notify");\n' > services/notifications/src/index.js
printf '# notifications\n\nSends email.\n' > services/notifications/readme.md

# --- looks like a unit but is deliberately excluded from the workspace ---
mkdir -p experiments/spike/src
cat > experiments/spike/package.json <<'EOF'
{ "name": "@fixture/spike", "version": "0.0.0" }
EOF
printf 'console.log("spike");\n' > experiments/spike/src/index.js

# --- the workspace definition that excludes it ---
cat > package.json <<'EOF'
{ "name": "fixture-root", "private": true, "workspaces": ["services/*", "packages/*"] }
EOF

# --- a generated dir that must never be a unit ---
mkdir -p node_modules/left-pad
printf '{ "name": "left-pad" }\n' > node_modules/left-pad/package.json

git init -q .
git add -A
git -c user.email=fixture@example.com -c user.name=Fixture commit -q -m "fixture repo"
printf "%s" "$ROOT"
```

- [ ] **Step 2: Gitignore the fixture location**

The fixture is a git repo generated inside this one. It must never be committed, and it must live at
a fixed path so later tasks find it.

Append to `$REPO/.gitignore`:

```
# Generated test fixture repo (tests/fixtures/make-fixture-repo.sh recreates it)
tests/fixture-repo/
```

- [ ] **Step 3: Make it executable and run it**

```bash
chmod +x "$REPO/tests/fixtures/make-fixture-repo.sh"
rm -rf "$FIXTURE"
sh "$REPO/tests/fixtures/make-fixture-repo.sh" "$FIXTURE"
find "$FIXTURE" -name package.json -not -path '*/node_modules/*' | sed "s|$FIXTURE|<FIXTURE>|" | sort
```

Expected, exactly seven manifests:

```
<FIXTURE>/experiments/spike/package.json
<FIXTURE>/package.json
<FIXTURE>/packages/utils/package.json
<FIXTURE>/services/billing/package.json
<FIXTURE>/services/notifications/package.json
<FIXTURE>/services/orders/package.json
<FIXTURE>/services/orders/vendor/pricing/package.json
```

Confirm it is ignored: `git status --short tests/` should print nothing.

- [ ] **Step 4: Document what each shape pins down**

Create `tests/fixtures/README.md`:

```markdown
# Discovery fixture

`make-fixture-repo.sh <dir>` builds a deterministic repo for testing RepoSkills
discovery. Each shape exists to pin down one behaviour. Do not add shapes without
adding the behaviour they test, and do not remove one without removing its assertion.

| Path | Signals | Must be treated as |
|---|---|---|
| `services/orders` | Strong manifest, Strong Dockerfile, Medium CI | Unit. Deployable. Full skeleton. Create README |
| `services/billing` | Strong manifest, Strong Dockerfile | Unit. Deployable. **Has a README**, so update, never create |
| `services/notifications` | Strong manifest, Strong Dockerfile | Unit. **Has `readme.md`, miscased**, so rename and update, never author a second file |
| `services/orders/vendor/pricing` | Strong manifest | Unit, **nested inside `services/orders`**. Both get a README. Parent freshness must subtract this path |
| `packages/utils` | Strong manifest, no Dockerfile | Unit. Non-deployable. **Slim skeleton** |
| `src/reporting` | Medium own types plus Medium own tables | Unit candidate, **Medium-only, so gated**: no README without human confirmation |
| `experiments/spike` | Strong manifest, but excluded from `workspaces` | **Not a unit.** Excluded, and self-documents that it is |
| `node_modules/left-pad` | Manifest | **Never a unit.** Exclusion list |
```

- [ ] **Step 5: Commit**

```bash
git add tests/fixtures/ .gitignore
git commit -m "add a deterministic discovery fixture repo

Section 9 of the spec names three regression targets and makes naming them a
prerequisite. This is the first and the only one that can be deterministic:
testing discovery against a real repo means assertions drift whenever that repo
does. Each shape in the fixture pins down exactly one behaviour of the gate."
```

---

### Task 2: Phase 0 discovers and records the project system

**Files:**
- Modify: `stow/RepoSkills/phase-0-discover.md` (new Step 4.5 after Step 4)
- Modify: `stow/RepoSkills/orchestration.md` (`state.md` schema, after the `update-mode` line)
- Create: `tests/assert-phase0.sh`

**Interfaces:**
- Consumes: `tests/fixtures/make-fixture-repo.sh` from Task 1.
- Produces: a `## Project System` section in `state.md` with four keys, `enumeration-query`, `detail-query`, `deployability-predicate` and `exclusions`, read by Tasks 3, 4 and 5.

- [ ] **Step 1: Write the assertion script**

Create `tests/assert-phase0.sh`:

```sh
#!/bin/sh
# Asserts on state.md after a Phase 0 run against the fixture.
# Usage: assert-phase0.sh <path-to-state.md>
set -u
STATE="${1:?usage: assert-phase0.sh <state.md>}"
FAILED=0

need() {
    # need <description> <grep-pattern>
    if grep -qi -- "$2" "$STATE"; then
        printf "  ok   %s\n" "$1"
    else
        printf "  FAIL %s\n       no match for [%s]\n" "$1" "$2"
        FAILED=1
    fi
}
absent() {
    if grep -qi -- "$2" "$STATE"; then
        printf "  FAIL %s\n       unexpected match for [%s]\n" "$1" "$2"
        FAILED=1
    else
        printf "  ok   %s\n" "$1"
    fi
}

need "Project System section exists"        "^## Project System"
need "enumeration query recorded"           "enumeration-query:"
need "detail query recorded"                "detail-query:"
need "deployability predicate recorded"     "deployability-predicate:"
need "exclusions recorded"                  "exclusions:"
need "workspace globs identified as the enumeration source" "workspaces"
need "the excluded spike is named as an exclusion" "experiments/spike"
absent "node_modules never appears as a unit" "node_modules/left-pad"

printf "\n%s\n" "$([ "$FAILED" -eq 0 ] && echo PASS || echo FAIL)"
[ "$FAILED" -eq 0 ]
```

- [ ] **Step 2: Run the baseline scenario and record what happens now**

This is the red phase, and per the Global Constraints it is not optional.

```bash
chmod +x "$REPO/tests/assert-phase0.sh"
rm -rf "$FIXTURE" && sh "$REPO/tests/fixtures/make-fixture-repo.sh" "$FIXTURE"
```

Now run Phase 0 against `$FIXTURE`, following
`$REPO/stow/RepoSkills/phase-0-discover.md` as it stands, then:

```bash
sh "$REPO/tests/assert-phase0.sh" "$STATE"
```

If `$STATE` does not exist after the run, Phase 0 did not complete. Check
`~/.claude/MEMORY/RepoSkills/` for the slug it actually used: it derives from the repo directory
name, which is `fixture-repo`.

Expected: FAIL on all five `need` assertions about the Project System section, because no such section exists in the schema. `node_modules` should already pass, since Step 4's exclusion list covers it. Record the actual output in the commit message: that is the baseline.

- [ ] **Step 3: Add the schema to orchestration.md**

In `stow/RepoSkills/orchestration.md`, inside the `state.md` template, immediately after the
`update-mode:` line, add:

```markdown
## Project System

Recorded by Phase 0 Step 4.5. Absent when the repo has no project system, which is
valid: Step 4's signal detection is then the whole answer.

enumeration-query: <command listing every project the repo recognises, or "none">
detail-query: <command returning one project's root and targets, or "none">
deployability-predicate: <what distinguishes a unit that ships, or "none">
exclusions: <paths that look like units but are deliberately outside the project system>
authoritative-source: <which candidate query was confirmed, and the counterexample that ruled the others out>
```

- [ ] **Step 4: Add Step 4.5 to phase-0-discover.md**

In `stow/RepoSkills/phase-0-discover.md`, after the `### Monorepo special handling` block and before
its closing `Update state.md: mark step 0.4 complete.`, insert:

```markdown
## Step 4.5: Discover the Project System (Step 0.5)

Many repos have a tool that already knows what their projects are. Ask it rather than inferring.
Where no such tool exists, Step 4's signals are the whole answer and this step records `none`.

### What to find

| Key | What it is | Examples of where it comes from |
|---|---|---|
| `enumeration-query` | The command that lists every project the repo recognises | An nx or turbo project graph, a workspace glob in the root manifest, a Cargo or Go workspace member list, a Bazel query |
| `detail-query` | The command returning one project's root and available targets | The same tool's per-project inspection command |
| `deployability-predicate` | What distinguishes a unit that ships from one that does not | A real deploy target, a Dockerfile, a per-environment infrastructure file |
| `exclusions` | Directories that look like units but are deliberately outside the system | A manifest present but excluded from the workspace globs |

### The rule that matters most

**When more than one candidate query exists, confirm which is authoritative rather than taking the
most visible, and record the counterexample that rules the others out.** A query returning a
plausible subset is the dangerous failure here, because nothing looks wrong.

Worked example from a real repo: in a mixed TypeScript and Python monorepo,
`pnpm-workspace.yaml` membership looks like the project list and silently excludes every Python
project, because those carry a hand-written project file and no `package.json`. The nx project graph
is authoritative there and the Python projects are the counterexample that proves it.

So: enumerate candidates, run each, and compare their outputs against the boundary candidates Step 4
found independently. A query that misses a Step 4 candidate carrying a Strong signal is not
authoritative. Record which query won and what ruled the others out.

### Recording

Write all five keys into the `## Project System` section of `state.md`. Where the repo genuinely has
no project system, write `none` for the first three and still record `exclusions`, since directory
based exclusions apply regardless.

Update `state.md`: mark step 0.5 complete.
```

- [ ] **Step 5: Re-run the scenario and the assertions**

Re-run Phase 0 against a fresh copy of the fixture, then:

```bash
sh "$REPO/tests/assert-phase0.sh" "$STATE"
```

Expected: `PASS`. In particular `enumeration-query` should name the root manifest's `workspaces`
globs, and `experiments/spike` should appear under `exclusions`, because its manifest exists but no
glob matches `experiments/*`.

- [ ] **Step 6: Commit**

```bash
git add stow/RepoSkills/phase-0-discover.md stow/RepoSkills/orchestration.md tests/assert-phase0.sh
git commit -m "phase 0: discover and record the repo's project system

Spec section 4. Where a repo has a tool that already knows its projects, the
pipeline should ask it rather than infer from directory shape. Step 4's signal
detection is unchanged and stays authoritative where no such tool exists, which
is why there is no threshold: the project system improves detection where
present and is not required where absent.

The recorded authoritative-source field exists because a query returning a
plausible subset is the dangerous failure mode: pnpm-workspace.yaml membership
looks like a project list and silently drops every Python project."
```

---

### Task 3: Gate the unit list on ownership signals

**Files:**
- Modify: `stow/RepoSkills/phase-0-discover.md` (the `### Recording boundary candidates` block, around line 195)
- Modify: `tests/assert-phase0.sh`

**Interfaces:**
- Consumes: the `## Project System` section from Task 2.
- Produces: a `## Unit List` section in `state.md` with one row per candidate carrying `path`, `signals`, `deployable`, `readme` (one of `exists`, `exists-miscased`, `absent`), `action` (one of `update`, `create`, `create-pending-confirmation`, `excluded`) and `nested-under`. Read by Tasks 5 and 6 and by every later plan.

- [ ] **Step 1: Add the assertions**

Append to `tests/assert-phase0.sh`, before the summary `printf`:

```sh
need "Unit List section exists"                      "^## Unit List"
need "orders is a create, ungated"                   "services/orders.*create"
need "billing is an update, because it has a README"  "services/billing.*update"
need "notifications is flagged miscased"             "services/notifications.*miscased"
need "utils is non-deployable"                       "packages/utils.*deployable: no"
need "reporting is gated pending confirmation"       "src/reporting.*pending-confirmation"
need "pricing records its parent"                    "pricing.*nested-under: services/orders"
need "spike is excluded"                             "experiments/spike.*excluded"
```

- [ ] **Step 2: Run to verify the new assertions fail**

```bash
sh "$REPO/tests/assert-phase0.sh" "$STATE"
```

Expected: the eight new assertions FAIL (no `## Unit List` section exists), the Task 2 assertions still PASS.

- [ ] **Step 3: Replace the recording block in phase-0-discover.md**

Replace the `### Recording boundary candidates` block with:

```markdown
### Recording boundary candidates

For each candidate, record:
- **Path:** directory path relative to repo root
- **Signals detected:** which boundary types and their specific indicators
- **Confidence:** `high` (multiple strong signals), `medium` (one strong or two medium), `low` (borderline, needs human confirmation)
- **Suggested unit name:** the name the project system reports, or a concise name if it has none
- **Key entry points:** main files that serve as entry points to the unit

### Deciding what happens to each candidate (Step 0.6)

Two questions, in this order. The first is about the file, the second about the signals.

**1. Does a README already exist?** Test against the version control file list
(`git ls-files`), not the working tree, because the local filesystem hides a miscased
`readme.md` that breaks CI elsewhere.

| Found | `readme` | `action` |
|---|---|---|
| `README.md` | `exists` | `update` |
| Any other casing | `exists-miscased` | `update`, and rename it first. Never author a second file beside it |
| Nothing | `absent` | Continue to question 2 |

An existing README is the strongest ownership signal available, stronger than anything this phase
can infer, because it is a decision a human already made. Updating one is never gated.

**2. What signals does it have?** Only for candidates with no README, since creating a file where a
human never put one is the only action that can impose an unwanted artifact.

| Signals detected | `action` |
|---|---|
| Any **Strong** signal (own package manifest, own Dockerfile or entry point) | `create` |
| **Medium signals only** (any two of domain, deployment, logical) | `create-pending-confirmation` |

**Gate on the Signals detected field, not on Confidence.** Confidence records `medium` for both
"one strong" and "two medium", so the two cases this gate must separate collapse into one value.

**Deployment is a Medium signal.** A deployment-only directory never qualifies as a boundary at all,
since qualifying requires one Strong or two Medium.

### Recording the unit list

Write a `## Unit List` section to `state.md`, one block per candidate:

```markdown
- path: services/orders
  signals: package-manifest(package.json), service(Dockerfile), deployment(.github/workflows/orders.yml)
  deployable: yes
  readme: absent
  action: create
  nested-under: none
```

`deployable` comes from the `deployability-predicate` recorded in Step 4.5. `nested-under` names the
closest enclosing unit, or `none`. A nested unit is still a unit: nesting disqualifies neither it nor
its parent.

Candidates the project system excludes get `action: excluded` and are recorded rather than dropped,
so a later phase can give them a README that says they are deliberately outside the system.

Update `state.md`: mark steps 0.4 and 0.6 complete.
```

- [ ] **Step 4: Re-run and verify**

```bash
sh "$REPO/tests/assert-phase0.sh" "$STATE"
```

Expected: `PASS`, all assertions.

- [ ] **Step 5: Verify the gate on the one case that matters**

Confirm by reading `state.md` that `src/reporting` has `action: create-pending-confirmation` and
that no other candidate does. That directory has two Medium signals and no manifest, so it is the
only one the gate should hold back. If anything with a Strong signal is also held back the gate is
reading the wrong field; if `src/reporting` is not held back it is not reading it at all.

- [ ] **Step 6: Commit**

```bash
git add stow/RepoSkills/phase-0-discover.md tests/assert-phase0.sh
git commit -m "phase 0: decide create, update or confirm per unit

Spec section 3. Most units in a mature repo already have a README, and an
existing one is the strongest ownership signal there is, so updating is never
gated and only creation is. A Medium-only candidate can be a directory nobody
considers a unit, and writing a README into it would reproduce the unowned
artifact this design removes, relocated into the source tree.

Presence is tested against git ls-files rather than the working tree because a
miscased readme.md is invisible locally and breaks CI elsewhere."
```

---

### Task 4: Permit and generate the conventions document

**Files:**
- Modify: `stow/RepoSkills/orchestration.md:414`
- Modify: `stow/RepoSkills/phase-2-map-generate.md` (new generation step)
- Create: `tests/assert-artifacts.sh`

**Interfaces:**
- Consumes: `## Project System` and `## Unit List` from Tasks 2 and 3.
- Produces: `.ai/skills/conventions.md` in the target repo, containing the confirmed unit list, the precedence rule, and any confirmed induced patterns.

- [ ] **Step 1: Write the assertion script**

Create `tests/assert-artifacts.sh`:

```sh
#!/bin/sh
# Asserts on the grammar artifacts generated into a target repo.
# Usage: assert-artifacts.sh <repo-root>
set -u
REPO="${1:?usage: assert-artifacts.sh <repo-root>}"
FAILED=0

file_has() {
    # file_has <description> <file> <grep-pattern>
    if [ -f "$REPO/$2" ] && grep -qi -- "$3" "$REPO/$2"; then
        printf "  ok   %s\n" "$1"
    else
        printf "  FAIL %s\n       %s missing or no match for [%s]\n" "$1" "$2" "$3"
        FAILED=1
    fi
}
exists() {
    if [ -f "$REPO/$2" ]; then printf "  ok   %s\n" "$1"
    else printf "  FAIL %s\n       %s does not exist\n" "$1" "$2"; FAILED=1; fi
}

exists   "conventions.md generated"          ".ai/skills/conventions.md"
file_has "records the precedence rule"       ".ai/skills/conventions.md" "code > README > conventions"
file_has "records the confirmed unit list"   ".ai/skills/conventions.md" "services/orders"
file_has "records declined candidates too"   ".ai/skills/conventions.md" "declined"
file_has "marks generated sections"          ".ai/skills/conventions.md" "provenance=generated"

printf "\n%s\n" "$([ "$FAILED" -eq 0 ] && echo PASS || echo FAIL)"
[ "$FAILED" -eq 0 ]
```

- [ ] **Step 2: Run the baseline**

```bash
chmod +x "$REPO/tests/assert-artifacts.sh"
sh "$REPO/tests/assert-artifacts.sh" "$FIXTURE"
```

Expected: FAIL on every assertion. `.ai/skills/conventions.md` does not exist, and
`orchestration.md:414` currently forbids generating it.

- [ ] **Step 3: Amend the prohibition at orchestration.md:414**

Replace the line:

```markdown
- Content that would appear in `conventions.md`, `dependency-map.md`, or `workflows.md` as separate files instead lives in `orientation.md` and individual module skills. Do not generate these as standalone output files.
```

with:

```markdown
- Content that would appear in `dependency-map.md` or `workflows.md` as separate files instead lives in `orientation.md`. Do not generate those as standalone output files.
- `conventions.md` **is** generated as a standalone file at `.ai/skills/conventions.md`. The original rule forbade it because it was redundant with module skills; once unit READMEs replace those, the conventions document is what stops every README restating the same build commands. It is the single home for repo-wide structural facts.
```

- [ ] **Step 4: Add the generation step to phase-2-map-generate.md**

Add, immediately before the step that generates module skills:

```markdown
### Step 2.2b: Generate `.ai/skills/conventions.md`

The single home for repo-wide structural facts, so no unit README has to restate them. Read
`## Project System` and `## Unit List` from `state.md` first.

Required sections, in this order:

| Section | Contents |
|---|---|
| What counts as a unit | The `enumeration-query`, the `authoritative-source` and its counterexample, and the exclusion list. Not a hand-maintained inventory: name the query |
| Confirmed units | One line per unit from `## Unit List`: path, name, deployable yes or no, nested-under |
| Declined candidates | Candidates a human declined, with the date. A decline recorded only in `state.md` would be re-proposed on every other machine forever |
| Standard layout | Where source, tests and infrastructure live, when the repo is consistent about it |
| Standard commands | Build, test, lint and run, as the repo actually declares them |
| Precedence | Verbatim: `code > README > conventions document`. This is its canonical home; the READMEs and `navigate-unit` link here rather than restating it |
| Confirmed patterns | Induced patterns confirmed by a human, per the grammar file's induction loop |

**Mark generated sections.** Stamp each section this step writes with `provenance=generated` inside
the existing `<!-- repo-skills: ... -->` comment. Anything unmarked is human-taught and a later run
must never remove it for failing to verify. One rule, one direction: mark what is generated.
```

- [ ] **Step 5: Run the scenario and assertions**

Run Phase 2 against the fixture, then:

```bash
sh "$REPO/tests/assert-artifacts.sh" "$FIXTURE"
```

Expected: `PASS` on all five conventions assertions.

- [ ] **Step 6: Commit**

```bash
git add stow/RepoSkills/orchestration.md stow/RepoSkills/phase-2-map-generate.md tests/assert-artifacts.sh
git commit -m "generate conventions.md, and amend the rule that forbade it

Spec 3.1. orchestration.md forbade generating conventions.md as a standalone
file, on the grounds that it was redundant with module skills. Once unit READMEs
replace those the reasoning inverts: the conventions document is what stops 40
READMEs each restating the same build commands. The prohibition on
dependency-map.md and workflows.md is untouched, since its rationale stands.

Declined candidates are recorded in the repo, not just in state.md, or a
boundary the owner declined is re-proposed on every machine forever."
```

---

### Task 5: The README grammar as its own instruction file

**Files:**
- Create: `stow/RepoSkills/readme-grammar.md`
- Modify: `stow/RepoSkills/phase-2-map-generate.md` (wiring only)
- Modify: `tests/assert-artifacts.sh`

**Interfaces:**
- Consumes: `## Unit List` from Task 3, `conventions.md` from Task 4.
- Produces: `.ai/skills/readme-template.md` in the target repo, the repo-specific instantiation of the grammar. Consumed by plan 2a-ii, which writes the READMEs themselves.

**Why a separate file.** Spec section 9: six backlog items already target
`phase-2-map-generate.md`, which is 1199 lines and the largest file in the skill. Growing it risks
the context failure these changes exist to prevent. Phase 2 gets wiring; the grammar lives apart.

- [ ] **Step 1: Add the assertions**

Append to `tests/assert-artifacts.sh` before the summary:

```sh
exists   "readme-template.md generated"       ".ai/skills/readme-template.md"
file_has "has a full skeleton"                ".ai/skills/readme-template.md" "full skeleton"
file_has "has a slim skeleton"                ".ai/skills/readme-template.md" "slim skeleton"
file_has "Agent Notes is last"                ".ai/skills/readme-template.md" "Agent Notes"
file_has "carries the include test"           ".ai/skills/readme-template.md" "10 seconds"
file_has "configuration is a pointer"         ".ai/skills/readme-template.md" "\.env\.example\|declaring file"
file_has "no Contracts owned section yet"     ".ai/skills/conventions.md" "provenance=generated"
```

- [ ] **Step 2: Run to verify they fail**

```bash
sh "$REPO/tests/assert-artifacts.sh" "$FIXTURE"
```

Expected: the six new `readme-template.md` assertions FAIL, the Task 4 assertions still PASS.

- [ ] **Step 3: Write the grammar file**

Create `stow/RepoSkills/readme-grammar.md`:

```markdown
# README Grammar

RepoSkills does not ship a README template. It ships this grammar, and generates a repo-specific
`.ai/skills/readme-template.md` from it during Phase 2. Read `## Project System` and `## Unit List`
from `state.md` before generating.

## Two skeletons, chosen by deployability

A unit is deployable when the repo's `deployability-predicate` says it ships. Otherwise nothing runs
and the sections about running and watching it do not apply.

| Section | Full (deployable) | Slim | Contains |
|---|---|---|---|
| Title | yes | yes | The unit's canonical name as the project system reports it |
| Conventions info-box | yes | yes | A link to `conventions.md` and the override rule |
| Overview | yes | yes | One or two sentences on what the unit does and why |
| Observability | yes | no | Only where a link pattern was confirmed. Unfillable rows stay `_not yet linked_` |
| Running and testing locally | yes | no | The quick loop, plus only what is specific to this unit |
| Agent Notes | yes | yes | Gotchas and what the code cannot tell you. **Always last** |

**Conditional sections**, either skeleton, after Running and testing locally and before Agent Notes,
only where the substrate exists: `Endpoints` (an API surface), `Configuration` (a pointer to the
declaring file, never values), `Runbook` (operational failure modes with known responses), or one
unit-specific topic named for what it is.

Section order is fixed. A slim README on a small library is the correct output, not a failure.

## What to include

A README carries what the code cannot: the why, the gotchas, the cross-unit consequences. Include a
unit-specific fact only if it survives both questions:

1. Could an agent get this right in about **10 seconds** from this unit's own code and config?
   If no, keep it.
2. If yes, does it also carry a why, a gotcha, a cross-unit consequence, or quick-start orientation?
   If no, cut it.

Cut anything both trivially greppable and none of those: a source directory tree, the DI framework
name, an endpoint list mirroring the controllers.

**Version numbers are the classic cut.** Manifests and lockfiles are the source of truth. Name a
version only where the unit deliberately pins something different, and say what it differs from.

**Link, never list.** Environment variables, configuration values, credentials, profile and role
names: point at the declaring file, or name the variable. Never reproduce the value. A value copied
into a README is wrong for every reader but its author, and is a second source of truth by
definition. If the declaring file is itself wrong, fix that file rather than documenting the
discrepancy.

**Every section is a positive contract, never a prohibition list.** State what the section contains,
in order. The `Configuration` slot reads "pointer to the declaring file", so there is no table to
negotiate away. This is deliberate: agents under a competing incentive negotiate with prohibitions,
and prohibition-form guidance measurably backfires on wrong-output-shape failures.

## Pattern induction with human confirmation

For any field whose shape is repo-specific (observability links, dashboard URLs, the deployability
predicate, the test command shape):

1. **Discover.** Find N real examples of the artifact in the repo.
2. **Induce.** Derive a pattern with the variable parts identified.
3. **Confirm.** Present the examples and the derived pattern to the human: "here are three log links
   I found and the pattern I derived; does this generalise?"
4. **Record.** The confirmed pattern goes into `.ai/skills/conventions.md`, in the repo. Never into
   `state.md`: that lives on one machine, so anyone else cloning the repo would get placeholders or
   a repeated interview.
5. **Apply.** Per-unit values are computed from the confirmed pattern.

**An unconfirmed pattern produces a placeholder, never a guess.** `_not yet linked_` is a
first-class output: an empty row flags the document as incomplete, while a dropped row hides the gap
and a guessed one is worse than both.

Once confirmed, a field that was non-deterministic becomes deterministic. Fields that resist
induction because they genuinely vary per unit must be resolved and verified per unit or omitted.
Never pattern-filled.

**Venue.** The Phase 1 interview when it runs, and the Phase 9 checkpoint otherwise, since Phase 1
is skipped when `domain-context.md` is fresh. Unconfirmed patterns block the Phase 9 skip. When no
human answers, the headless case, placeholders stand and the report carries the list forward: a
blocked skip must never become a hung pipeline.

## Token budget

The agent-facing sections of a README carry a ceiling of roughly 1.5k tokens, matching what module
skills carried. The human-authored Overview is excluded from the count, since it is not RepoSkills'
to trim. Overflow goes to a task skill rather than splitting the README, because a unit has exactly
one README.

**Enforcement is generation-time only.** An existing README over budget is flagged in the report,
never truncated. The ceiling binds what RepoSkills writes; it does not license editing down what a
human wrote.

## Generating the repo-specific template

Write `.ai/skills/readme-template.md` containing: both skeletons as fenced markdown blocks with this
repo's real commands and section names substituted in, the include test verbatim, the conditional
section list filtered to those this repo has substrate for, and an authoring-rules banner the
drafting agent honours and then deletes.

Do **not** include `Contracts owned`, `Deviations` or `Lifecycle status`. Those three are absent
from the reference implementation and land in a later stage with their own baseline test. Shipping
them now would flag every pre-existing README in the target repo as incomplete.
```

- [ ] **Step 4: Wire it into phase 2**

Add to `stow/RepoSkills/phase-2-map-generate.md`, immediately after Step 2.2b:

```markdown
### Step 2.2c: Generate `.ai/skills/readme-template.md`

Read [readme-grammar.md](readme-grammar.md) and follow its "Generating the repo-specific template"
section. The grammar lives in that file, not here, so this file stays within its token budget.

Output: `.ai/skills/readme-template.md` in the target repo. This step generates the template only.
Writing the per-unit READMEs themselves is a later stage.
```

- [ ] **Step 5: Run the scenario and assertions**

Run Phase 2 against the fixture, then:

```bash
sh "$REPO/tests/assert-artifacts.sh" "$FIXTURE"
```

Expected: `PASS`. Then confirm by reading `$FIXTURE/.ai/skills/readme-template.md` that it contains a
slim skeleton without Observability or Running-locally sections, and that it does **not** mention
`Contracts owned`.

- [ ] **Step 6: Check the token budget you were warned about**

```bash
wc -l "$REPO/stow/RepoSkills/phase-2-map-generate.md"
```

Expected: no more than about 1215 lines, up from 1199. Steps 2.2b and 2.2c together should add
roughly 40 lines of wiring. If the number is materially higher, grammar content has leaked into
phase 2 and belongs in `readme-grammar.md`.

- [ ] **Step 7: Commit**

```bash
git add stow/RepoSkills/readme-grammar.md stow/RepoSkills/phase-2-map-generate.md tests/assert-artifacts.sh
git commit -m "add the README grammar as its own instruction file

Spec section 5. RepoSkills ships a grammar and a generator; the concrete
template is an artifact generated into the target repo, because the reference
implementation's template is saturated with repo-specific mechanisms that
cannot live in a tool targeting any repo.

The grammar is a separate file rather than an extension of phase 2, per spec
section 9: six backlog items already target phase-2-map-generate.md, which at
1199 lines is the largest file in the skill, and growing it risks the context
failure these changes exist to prevent.

Contracts owned, Deviations and Lifecycle status are deliberately excluded.
They are absent from the reference, so shipping them now would flag every
pre-existing README in a target repo as incomplete."
```

---

### Task 6: The navigate-unit task skill

**Files:**
- Modify: `stow/RepoSkills/phase-2-map-generate.md` (task-skill generation)
- Modify: `tests/assert-artifacts.sh`

**Interfaces:**
- Consumes: `conventions.md` from Task 4, `readme-template.md` from Task 5.
- Produces: `.ai/skills/tasks/navigate-unit.md` in the target repo.

- [ ] **Step 1: Add the assertions**

```sh
exists   "navigate-unit generated"           ".ai/skills/tasks/navigate-unit.md"
file_has "has a USE WHEN line"               ".ai/skills/tasks/navigate-unit.md" "USE WHEN"
file_has "links the conventions doc"         ".ai/skills/tasks/navigate-unit.md" "conventions.md"
file_has "states precedence by reference"    ".ai/skills/tasks/navigate-unit.md" "conventions"
file_has "does not restate the layout"       ".ai/skills/tasks/navigate-unit.md" "procedure"
```

- [ ] **Step 2: Run to verify they fail**

Expected: all five FAIL. No `navigate-unit.md` is generated.

- [ ] **Step 3: Add the generation instruction**

Add to `stow/RepoSkills/phase-2-map-generate.md` in the task-skill generation step:

```markdown
**`navigate-unit` is always generated** where at least one unit is confirmed. It is the third leg of
the architecture: `conventions.md` holds the repo-wide structural facts, a unit's `README.md` holds
what is true for that one unit, and this skill is the **procedure** for using both.

It contains: how to inspect a unit (confirm it is a unit via the enumeration query, read the
conventions doc for the standard shape, read the unit's README for its deviations, read the
infrastructure entry point, find the application entry point, then verify against the code), and how
to change one and verify the change.

It states the precedence rule by **linking** `conventions.md`, never by restating it:
`code > README > conventions document`. A deviation documented in a README is intentional, so do not
"fix" a unit to match the conventions document without first checking why it deviates.

It gives commands and steps. It does **not** restate structural facts: those live in the conventions
document, and duplicating them there and here is how the two drift apart.
```

- [ ] **Step 4: Run and verify**

Expected: `PASS`.

- [ ] **Step 5: Commit**

```bash
git add stow/RepoSkills/phase-2-map-generate.md tests/assert-artifacts.sh
git commit -m "generate the navigate-unit task skill

Spec 3.1, leg three. A per-unit README on its own reproduces the maintenance
problem it was meant to solve, because every unit restates the same structural
facts and they drift apart. The working structure is a conventions document for
repo-wide facts, a README per unit for what is true there, and a procedure skill
for using both.

It links the precedence rule rather than restating it, because duplicating a
canonical statement is how canonical statements stop being canonical."
```

---

### Task 7: Declare the new outputs in SKILL.md

**Files:**
- Modify: `stow/RepoSkills/SKILL.md` (the Output table and the Phase Instruction Files table)

**Interfaces:**
- Consumes: everything above.
- Produces: nothing consumed by later tasks. This is the public contract catching up with reality.

- [ ] **Step 1: Read the current tables**

```bash
sed -n '/^### Skills/,/^### Platform glue/p' "$REPO/stow/RepoSkills/SKILL.md"
grep -n "readme-grammar\|conventions" "$REPO/stow/RepoSkills/SKILL.md"
```

Expected: the Output table lists `orientation.md`, `domain-context.md`, `modules/<name>.md`,
`tasks/<name>.md` and the two drift tools. No mention of `conventions.md`, `readme-template.md` or
`readme-grammar.md`.

- [ ] **Step 2: Add the three new outputs**

In the `### Skills (.ai/skills/)` table, after the `domain-context.md` row, add:

```markdown
| `conventions.md` | Repo-wide structural facts, written once: what counts as a unit, standard layout and commands, the precedence rule, confirmed induced patterns |
| `readme-template.md` | This repo's instantiation of the README grammar, used when authoring or updating a unit README |
```

Leave the `modules/<name>.md` row exactly as it is. This is the expand stage; both shapes coexist.

- [ ] **Step 3: Add the grammar file to the phase-file table**

In the `### Templates` section's preceding table, add:

```markdown
| grammar | `readme-grammar.md` |
```

- [ ] **Step 4: Verify the whole suite still passes**

```bash
sh "$REPO/tests/assert-phase0.sh" "$STATE"
sh "$REPO/tests/assert-artifacts.sh" "$FIXTURE"
```

Expected: `PASS` from both.

- [ ] **Step 5: Verify the expand invariant**

The single most important check in this plan. Confirm module skills are still generated:

```bash
ls "$FIXTURE/.ai/skills/modules/" | head
```

Expected: module skill files present. If `modules/` is empty or absent, this plan has done 2b's job
by accident and the repo is in the broken intermediate state the expand/contract split exists to
prevent.

- [ ] **Step 6: Commit**

```bash
git add stow/RepoSkills/SKILL.md
git commit -m "declare conventions.md, readme-template.md and the grammar file

SKILL.md is the public contract and was silent on three artifacts the pipeline
now emits. The modules/ row is deliberately untouched: this is the expand stage,
both shapes coexist, and removal is 2b's job."
```

---

## Self-Review

**Spec coverage.** Section 3's create/update gate is Task 3. Section 3.1's three legs are Tasks 4, 5
and 6. Section 4's project-system discovery is Task 2. Sections 5.1, 5.2 and 5.3 are Task 5's grammar
file. Section 9's token-budget mitigation is Task 5 Step 6, and its first-run regression target is
Task 1.

Deliberately **not** covered here, and belonging to the named sibling plans: writing or updating the
per-unit READMEs (2a-ii), the harvest (2b), and the drift, routing, simulation-access, state
reconstruction and `--update` changes (2a-iii). Section 3.5's inventory rows are consumed by 2a-iii
and 2b, not by this plan, which adds only new outputs.

**Placeholder scan.** No TBD or TODO. Every step carries the content to be written. The three
assertion scripts are complete and runnable. The only non-literals are `$REPO`, `$FIXTURE` and
`$STATE`, all three defined in the "Run this first" block at the top of this plan and re-exported by
every task, so no task depends on state inherited from another.

**Type consistency.** `state.md`'s `## Project System` keys are defined in Task 2 and read by Tasks
3, 4 and 5. `## Unit List` fields (`path`, `signals`, `deployable`, `readme`, `action`,
`nested-under`) are defined in Task 3 and read by Tasks 4, 5 and 6, and the `action` values used in
Task 3's assertions (`create`, `update`, `create-pending-confirmation`, `excluded`) match the values
its instruction text produces. `readme-grammar.md` is created in Task 5 and referenced by that same
path in Tasks 5 and 7. `assert-phase0.sh` is created in Task 2 and extended in Task 3;
`assert-artifacts.sh` is created in Task 4 and extended in Tasks 5 and 6.

**One risk worth naming.** Every test here runs a pipeline phase by dispatching an agent against the
fixture, so runs are slow and not bit-for-bit deterministic. The assertions are therefore written
against structural facts (does the section exist, does this path carry this action) rather than
against exact wording. Do not tighten them into string equality; that would make the suite flaky
without making it stronger.

---

## Sibling plans

| Plan | Spec sections | Stage | Depends on |
|---|---|---|---|
| **This plan:** discovery and grammar artifacts | 3, 3.1, 4, 5 | 2a-i | `install.sh` plan |
| README create and update | 3.2, 5.1, 5.2 | 2a-ii | This plan |
| Tooling and re-run paths | 3.5, 3.6, 6.3 | 2a-iii | This plan |
| Contract: stop generating module skills, harvest | 3.4, 3.5 | 2b | 2a-i, ii, iii |
| Phase-4 checks and phase-1 questions | 6.5 items 2, 3, 4, 5, 12, 16 | 3 | 2b |
| Remaining items | items 6, 8, 17 | 4 | 2b |
| The three added README sections | 5.1 | 5 | 2b |
