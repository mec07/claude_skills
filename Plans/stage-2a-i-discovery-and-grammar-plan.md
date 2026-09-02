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

### Run protocol

Phase 0's pre-check (Step 0.0) skips the whole phase when
`~/.claude/MEMORY/RepoSkills/fixture-repo/_triage.md` already exists, and a phase marked complete in
`state.md` will not run again. Resetting only the fixture therefore produces a run that writes
nothing. Every "run Phase N" instruction in this plan means exactly one of these two, and each task
says which:

**Fresh run** (default for any step that says "run Phase 0" or "run Phase 0 then Phase 2"):

```bash
rm -rf "$FIXTURE" "$HOME/.claude/MEMORY/RepoSkills/fixture-repo"
sh "$REPO/tests/fixtures/make-fixture-repo.sh" "$FIXTURE"
```

Then dispatch one fresh agent per phase, in phase order, with this instruction:

> You are the Phase N agent. Read `$REPO/stow/RepoSkills/orchestration.md`, then
> `$REPO/stow/RepoSkills/phase-<N>-*.md`. Target repo: `$FIXTURE`. MEMORY directory:
> `~/.claude/MEMORY/RepoSkills/fixture-repo/`. Execute Phase N only, updating `state.md` as its
> checklist requires, then stop and report.

For Phase 2 runs, run Phase 0 first, then dispatch Phase 2 directly. **Do not run Phase 1**: it is
an interview and these runs are unattended, so induced patterns stay unconfirmed and the artifacts
must carry placeholders, which is itself behaviour the grammar specifies (a headless run never
hangs and never guesses).

**Phase 2 re-run on existing Phase 0 state** (for a task that changes only Phase 2 behaviour and
must keep the prior discovery): keep the MEMORY directory, then

```bash
rm -rf "$FIXTURE/.ai/skills"
```

and reset every Phase 2 checkbox in `$STATE` to `[ ]` before dispatching the Phase 2 agent.

**Assertion-only steps** (a step that runs `assert-phase0.sh` or `assert-artifacts.sh` and nothing
else) run against the artifacts of the most recent run. Do not reset anything for them: some
baselines deliberately assert against a previous task's output.

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
| `stow/RepoSkills/phase-0-discover.md` | Gains project-system discovery (Step 4a) and the create/update gate (Step 4b), each tracked in the Phase 0 checklist | 2, 3 |
| `stow/RepoSkills/orchestration.md` | `state.md` schema additions; the `:414` amendment; the Phase 9 skip-condition additions | 2, 3, 4, 5 |
| `stow/RepoSkills/phase-9-human-checkpoint.md` | Confirmation venue: two new skip-blocking conditions and the unit-and-pattern confirmation step | 5 |
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

# --- nested package INSIDE a deployable service: the nesting case.
#     NOT under vendor/: that directory is on the never-browse exclusion lists
#     (phase-0:60, orchestration:370), so a fixture there would be invisible
#     to the pipeline by its own rules. ---
mkdir -p services/orders/pricing
cat > services/orders/pricing/package.json <<'EOF'
{ "name": "@fixture/pricing", "version": "1.0.0" }
EOF
printf 'module.exports = {};\n' > services/orders/pricing/index.js

# --- non-deployable library: Strong (manifest), no Dockerfile: slim skeleton ---
mkdir -p packages/utils/src
cat > packages/utils/package.json <<'EOF'
{ "name": "@fixture/utils", "version": "1.0.0" }
EOF
printf 'export const noop = () => {};\n' > packages/utils/src/index.js

# --- Medium-only boundary: Domain (own types imported elsewhere + own tables,
#     one signal TYPE) + Deployment (own CI workflow, a second TYPE).
#     No manifest, no Dockerfile, no entry point: deliberately no barrel index.ts,
#     which an agent could read as a Strong entry-point signal.
#     MUST be gated behind confirmation. ---
mkdir -p src/reporting
printf 'export type Report = { id: string };\n' > src/reporting/types.ts
printf 'CREATE TABLE reports (id text primary key);\n' > src/reporting/schema.sql
printf 'name: reporting\non: push\n' > .github/workflows/reporting.yml
printf 'import type { Report } from "./reporting/types";\nexport const latest: Report = { id: "1" };\n' > src/app.ts

# --- entry-point-only boundary: a Strong Service signal (own entry point with a
#     port binding) but NO manifest and NO Dockerfile. Qualifies as a boundary,
#     but README creation is still gated: an internal library or sub-app inside
#     a single frontend has exactly this shape. ---
mkdir -p src/ingest
printf 'require("http").createServer(() => {}).listen(8081);\n' > src/ingest/main.js
printf 'module.exports.parse = (x) => x;\n' > src/ingest/parse.js

# --- miscased readme: the unit HAS a README and it must be renamed, not duplicated ---
mkdir -p services/notifications/src
cat > services/notifications/package.json <<'EOF'
{ "name": "@fixture/notifications", "version": "1.0.0" }
EOF
printf 'FROM node:20\n' > services/notifications/Dockerfile
printf 'console.log("notify");\n' > services/notifications/src/index.js
printf '# notifications\n\nSends email.\n' > services/notifications/readme.md

# --- looks like a unit but is deliberately excluded from the workspace.
#     It HAS a README, which is the dominant excluded shape in the reference
#     repo (the pnpm-workspace-excluded ingestion adapters all self-document),
#     so the exclusion-beats-README precedence is actually exercised. ---
mkdir -p experiments/spike/src
cat > experiments/spike/package.json <<'EOF'
{ "name": "@fixture/spike", "version": "0.0.0" }
EOF
printf 'console.log("spike");\n' > experiments/spike/src/index.js
printf '# spike\n\nExperimental. Deliberately outside the workspaces globs.\n' > experiments/spike/README.md

# --- a second project system whose visible query is a silent subset: a Python
#     project the npm workspaces globs cannot see, mirroring the real repo where
#     pnpm-workspace.yaml membership silently excludes every Python project.
#     This is the counterexample authoritative-source selection must record. ---
mkdir -p analytics/pipeline/pipeline
cat > analytics/pipeline/pyproject.toml <<'EOF'
[project]
name = "fixture-pipeline"
version = "1.0.0"
EOF
printf 'print("pipeline")\n' > analytics/pipeline/pipeline/__init__.py
printf 'name: pipeline\non: push\n' > .github/workflows/pipeline.yml

# --- the workspace definition. It excludes experiments/spike and cannot
#     express analytics/pipeline at all. The root itself has a Strong manifest
#     and no README: the gate must still never mark the workspace root create. ---
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
find "$FIXTURE" \( -name package.json -o -name pyproject.toml \) -not -path '*/node_modules/*' | sed "s|$FIXTURE|<FIXTURE>|" | sort
```

Expected, exactly seven `package.json` manifests plus one `pyproject.toml`:

```
<FIXTURE>/analytics/pipeline/pyproject.toml
<FIXTURE>/experiments/spike/package.json
<FIXTURE>/package.json
<FIXTURE>/packages/utils/package.json
<FIXTURE>/services/billing/package.json
<FIXTURE>/services/notifications/package.json
<FIXTURE>/services/orders/package.json
<FIXTURE>/services/orders/pricing/package.json
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
| `.` (workspace root) | Strong manifest, no README | **Never a unit.** The workspace root is out of the gate's scope by rule, however strong its signals |
| `services/orders` | Strong manifest, Strong Dockerfile, Medium CI | Unit. Deployable. Full skeleton. Create README |
| `services/billing` | Strong manifest, Strong Dockerfile | Unit. Deployable. **Has a README**, so update, never create |
| `services/notifications` | Strong manifest, Strong Dockerfile | Unit. **Has `readme.md`, miscased**: recorded as `exists-miscased`, `update`. The rename belongs to the writing phase |
| `services/orders/pricing` | Strong manifest | Unit, **nested inside `services/orders`**. Both get a README. Parent freshness must subtract this path |
| `packages/utils` | Strong manifest, no Dockerfile | Unit. Non-deployable. **Slim skeleton** |
| `analytics/pipeline` | Strong manifest (`pyproject.toml`), Medium CI | Unit, invisible to the `workspaces` globs. **The counterexample** that proves the visible query is a subset |
| `src/reporting` | Medium Domain (own imported types, own tables) plus Medium Deployment (own CI workflow): two Medium **types** | Unit candidate, **Medium-only, so gated**: no README without human confirmation |
| `src/ingest` | Strong Service (own entry point, own port binding), no manifest, no Dockerfile | Boundary, but **gated**: an entry point alone never earns ungated creation |
| `experiments/spike` | Strong manifest, but excluded from `workspaces`; has a README | **Not a unit.** Exclusion beats the README; the README is its self-documentation |
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
- Modify: `stow/RepoSkills/phase-0-discover.md` (new Step 4a after Step 4, plus its checklist entry)
- Modify: `stow/RepoSkills/orchestration.md` (`state.md` schema, after the `update-mode` line)
- Create: `tests/assert-phase0.sh`

**Interfaces:**
- Consumes: `tests/fixtures/make-fixture-repo.sh` from Task 1.
- Produces: a `## Project System` section in `state.md` with five keys, `enumeration-query`, `detail-query`, `deployability-predicate`, `exclusions` and `authoritative-source`, read by Tasks 3, 4 and 5.

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
need "authoritative source recorded"        "authoritative-source:"
need "the plausible-subset counterexample is recorded on the authoritative-source line" "authoritative-source:.*analytics/pipeline"
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
```

Do a **fresh run** of Phase 0 per the Run protocol (delete both `$FIXTURE` and the
`fixture-repo` MEMORY directory, recreate the fixture, dispatch the Phase 0 agent), then:

```bash
sh "$REPO/tests/assert-phase0.sh" "$STATE"
```

If `$STATE` does not exist after the run, Phase 0 did not complete. Check
`~/.claude/MEMORY/RepoSkills/` for the slug it actually used: it derives from the repo directory
name, which is `fixture-repo`.

Expected: FAIL on all seven `need` assertions about the Project System section, because no such section exists in the schema. `node_modules` should already pass, since Step 4's exclusion list covers it. Record the actual output in the commit message: that is the baseline.

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

- [ ] **Step 4: Add Step 4a to phase-0-discover.md**

**On numbering:** Step 0.5 (Detect Task Skills Warranted, `phase-0-discover.md:212`), 0.6
(domain-context freshness, `:282`), 0.7 (`:303`) and 0.8 (`:405`) all exist already, so the new
steps take letter-suffixed numbers, `0.4a` here and `0.4b` in Task 3, which keeps them
collision-free and in execution order without renumbering any existing step.

In `stow/RepoSkills/phase-0-discover.md`, after Step 4's closing
`Update state.md: mark step 0.4 complete.` and before the `## Step 5` heading, insert:

```markdown
## Step 4a: Discover the Project System (Step 0.4a)

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

Update `state.md`: mark step 0.4a complete.
```

In the same edit, add the new step to the Phase 0 checklist at `phase-0-discover.md:14-21`, between
the `0.4` and `0.5` lines:

```markdown
- [ ] 0.4a: Discover the project system
```

The checklist is what agents copy into `state.md` and what the recovery protocol resumes from. A
step absent from it is untracked: a context loss after 0.4 would resume at 0.5 and silently skip
this step.

- [ ] **Step 5: Re-run the scenario and the assertions**

Do a **fresh run** of Phase 0 per the Run protocol, then:

```bash
sh "$REPO/tests/assert-phase0.sh" "$STATE"
```

Expected: `PASS`. In particular `enumeration-query` should name the root manifest's `workspaces`
globs, `experiments/spike` should appear under `exclusions`, because its manifest exists but no
glob matches `experiments/*`, and `authoritative-source` should record that the `workspaces` globs
are a plausible subset covering the TypeScript side only, with `analytics/pipeline`, a Strong-signal
candidate the globs cannot see, as the counterexample. That last is the fixture exercising this
step's central rule rather than merely recording keys.

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
- Modify: `stow/RepoSkills/phase-0-discover.md` (new Step 4b after Step 4a, plus its checklist entry)
- Modify: `stow/RepoSkills/orchestration.md` (`## Unit List` in the `state.md` schema, after the `## Project System` section Task 2 added)
- Modify: `tests/assert-phase0.sh`

**Interfaces:**
- Consumes: the `## Project System` section from Task 2.
- Produces: a `## Unit List` section in `state.md` with one block per candidate carrying `path`, `signals`, `deployable`, `readme` (one of `exists`, `exists-miscased`, `absent`), `action` (one of `update`, `create`, `create-pending-confirmation`, `excluded`) and `nested-under`. Read by Tasks 5 and 6 and by every later plan.

- [ ] **Step 1: Add the assertions**

The Unit List is recorded as multi-line blocks, one per candidate, and `grep` is line-based, so a
single-line pattern like `services/orders.*create` can never match a block whose `path:` and
`action:` sit on different lines. The assertions therefore go through a block-aware awk helper that
scopes each check to one candidate's block.

Append to `tests/assert-phase0.sh`, before the summary `printf`:

```sh
unit_has() {
    # unit_has <description> <unit-path> <line-regex>
    # Passes when the Unit List block whose "- path:" equals <unit-path>
    # contains a line matching <line-regex>. Exact path match, so
    # services/orders never swallows services/orders/pricing.
    if awk -v p="$2" -v pat="$3" '
        /^- path:/ { cur=$0; sub(/^- path:[ \t]*/, "", cur); sub(/[ \t]+$/, "", cur); inblock=(cur==p); next }
        inblock && $0 ~ pat { found=1 }
        END { exit found ? 0 : 1 }
    ' "$STATE"; then
        printf "  ok   %s\n" "$1"
    else
        printf "  FAIL %s\n       unit [%s] has no line matching [%s]\n" "$1" "$2" "$3"
        FAILED=1
    fi
}

need     "Unit List section exists"                       "^## Unit List"
unit_has "the workspace root is excluded, never a create" "."                       "action:[ \t]*excluded"
unit_has "orders is a create, ungated"                    "services/orders"         "action:[ \t]*create[ \t]*$"
unit_has "billing is an update, because it has a README"  "services/billing"        "action:[ \t]*update"
unit_has "notifications is flagged miscased"              "services/notifications"  "readme:[ \t]*exists-miscased"
unit_has "notifications is still an update"               "services/notifications"  "action:[ \t]*update"
unit_has "utils is non-deployable"                        "packages/utils"          "deployable:[ \t]*no"
unit_has "the python project is discovered despite the workspaces globs" "analytics/pipeline" "action:[ \t]*create[ \t]*$"
unit_has "reporting is gated pending confirmation"        "src/reporting"           "action:[ \t]*create-pending-confirmation"
unit_has "an entry point alone never earns ungated creation" "src/ingest"           "action:[ \t]*create-pending-confirmation"
unit_has "pricing records its parent"                     "services/orders/pricing" "nested-under:[ \t]*services/orders"
unit_has "spike is excluded despite its Strong manifest"  "experiments/spike"       "action:[ \t]*excluded"
unit_has "spike's README is recorded, not mistaken for an update" "experiments/spike" "readme:[ \t]*exists"
```

The `create[ \t]*$` anchors matter: without them, `create` also matches
`create-pending-confirmation` and the gate's central distinction is untested. The same line-based
trap is why `assert-artifacts.sh` (Tasks 4 to 6) asserts only on single-line facts inside generated
files, never on multi-line structures.

- [ ] **Step 2: Run to verify the new assertions fail**

This is an assertion-only step per the Run protocol: run against the `state.md` Task 2's run
produced, with no reset, so the Task 2 assertions demonstrably still pass on the same artifact.

```bash
sh "$REPO/tests/assert-phase0.sh" "$STATE"
```

Expected: the thirteen new assertions FAIL (no `## Unit List` section exists), the Task 2 assertions still PASS.

- [ ] **Step 3: Add Step 4b to phase-0-discover.md**

The gate is a **new step, not an edit to Step 4**. Step 4's signal table and its recording block
are what `modules/` generation reads, and this is the expand stage: changing them would change what
`modules/` generates. The gate reads Step 4's output and Step 4a's project-system record, and
answers a different, narrower question.

In `stow/RepoSkills/phase-0-discover.md`, after Step 4a (added in Task 2) and before the `## Step 5`
heading, insert:

```markdown
## Step 4b: Decide Create, Update or Confirm per Candidate (Step 0.4b)

For each boundary candidate Step 4 recorded, plus each directory Step 4a's project system excludes,
decide what the README phases may later do there. This step only records; no file in the target
repo changes. Four questions, in this order.

**0. Is it the workspace root?** The workspace root is never a unit and its README is out of scope,
however strong its signals: a root README is a repo-wide document with its own shape, not a unit
README, and it must never be created or conformed by this pipeline. Record it as `- path: .` with
`action: excluded` and the reason `workspace-root`.

**1. Does the project system exclude it?** `action: excluded`, and this wins even when a README
exists there: an excluded directory's README is its self-documentation of the exclusion, not an
invitation to conform it. Record `readme: exists` so the writing phase knows the self-documentation
is already present, and record excluded candidates rather than dropping them, so a later phase can
give the ones without a README one that says they are deliberately outside the system.

**2. Does a README already exist?** Test against the version control file list
(`git ls-files`), not the working tree, because the local filesystem hides a miscased
`readme.md` that breaks CI elsewhere.

| Found | `readme` | `action` |
|---|---|---|
| `README.md` | `exists` | `update` |
| Any other casing | `exists-miscased` | `update`. The unit HAS a README; renaming it to `README.md` is the writing phase's first move there, recorded here as intent. This phase is read-only and renames nothing |
| Nothing | `absent` | Continue to question 3 |

An existing README is the strongest ownership signal available, stronger than anything this phase
can infer, because it is a decision a human already made. Updating one is never gated.

**3. What signals does it have?** Only for candidates with no README, since creating a file where a
human never put one is the only action that can impose an unwanted artifact.

| Signals detected | `action` |
|---|---|
| Own **package manifest** or own **Dockerfile** | `create` |
| Anything else that qualified as a boundary (an entry point as the only Strong signal, or two Medium types) | `create-pending-confirmation` |

**This table is deliberately narrower than Step 4's signal table, and the two answer different
questions.** Step 4 decides what qualifies as a boundary, and an own entry point (`main.go`,
`index.ts`, `app.py`) is a Strong signal there; that table is unchanged. This gate decides what
earns README creation with no human in the loop, and an entry point alone does not: a shared
library that deserves a README has its own manifest, because that is exactly what makes it a
workspace member, while an internal library inside a single frontend app has an `index.ts` and no
manifest, and one README per internal library is the unwanted-artifact failure this gate exists to
prevent. The manifest is the discriminator between those two cases. A candidate can therefore
qualify as a boundary on an entry point and still wait at `create-pending-confirmation` for its
README.

**Gate on the Signals detected field, not on Confidence.** Confidence records `medium` for both
"one strong" and "two medium", so the two cases this gate must separate collapse into one value.

**Two Medium signals means two Medium types.** Own data types and own database tables are both
Domain-boundary indicators, one type, not two signals. Deployment is a Medium signal: a
deployment-only directory never qualifies as a boundary at all, since qualifying requires one
Strong or two Medium.

### Recording the unit list

Write a `## Unit List` section to `state.md`, one block per candidate:

```
- path: services/orders
  name: <the name the project system reports, or a concise name if it has none>
  signals: package-manifest(package.json), service(Dockerfile), deployment(.github/workflows/orders.yml)
  deployable: yes
  readme: absent
  action: create
  nested-under: none
```

`deployable` comes from the `deployability-predicate` recorded in Step 4a. `nested-under` names the
closest enclosing unit, or `none`. A nested unit is still a unit: nesting disqualifies neither it nor
its parent.

Update `state.md`: mark step 0.4b complete.
```

In the same edit, add the new step to the Phase 0 checklist at `phase-0-discover.md:14-21`,
immediately after the `0.4a` line Task 2 added:

```markdown
- [ ] 0.4b: Decide create, update or confirm per candidate
```

And in `stow/RepoSkills/orchestration.md`, add the `## Unit List` block format to the `state.md`
schema, immediately after the `## Project System` section Task 2 added, so the schema and the phase
that writes it agree:

```markdown
## Unit List

Recorded by Phase 0 Step 4b: one block per boundary candidate, keys `path`, `name`, `signals`,
`deployable` (yes/no), `readme` (exists | exists-miscased | absent), `action` (update | create |
create-pending-confirmation | excluded) and `nested-under` (closest enclosing unit path, or none).
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
file_has "records a settled unit decision"   ".ai/skills/conventions.md" "src/reporting"
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
| Unit decisions | **Decisions only, never an inventory.** One line per candidate whose disposition a human settled or whose treatment departs from what the query implies: a Medium-only boundary confirmed, a deployability call that contradicts the `deployability-predicate`, an exclusion that needed a ruling. A unit the enumeration query already returns and that nobody argued about gets no line, because the query is its record |
| Declined candidates | Candidates a human declined, with the date. A decline recorded only in `state.md` would be re-proposed on every other machine forever |
| Standard layout | Where source, tests and infrastructure live, when the repo is consistent about it |
| Standard commands | Build, test, lint and run, as the repo actually declares them |
| Precedence | Verbatim: `code > README > conventions document`. This is its canonical home; the READMEs and `navigate-unit` link here rather than restating it |
| Confirmed patterns | Induced patterns confirmed by a human, per the grammar file's induction loop |

**Mark generated sections.** Stamp each section this step writes with `provenance=generated` inside
the existing `<!-- repo-skills: ... -->` comment. Anything unmarked is human-taught and a later run
must never remove it for failing to verify. One rule, one direction: mark what is generated.
```

In the same edit, add the new step to the Phase 2 checklist at `phase-2-map-generate.md:14-21`,
between the `2.2` and `2.3` lines, for the same reason Task 2 amends Phase 0's checklist: the
checklist is what agents copy into `state.md`, and an untracked step is silently skipped after a
context loss.

```markdown
- [ ] 2.2b: Generate conventions.md (.ai/skills/conventions.md)
```

And in the same edit, amend the self-review item at `phase-2-map-generate.md:1083`, the Structural
Integrity checklist's no-duplicate-facts item. During the expand stage, `conventions.md`'s Standard
commands deliberately coexist with orientation's Quick Reference (`phase-2-map-generate.md:226`) and
the full reference in `tasks/scripts.md`, so a diligent Phase 2 agent following that checklist item
would strip one of the copies and undo this step's work. Append directly below the item, as an
indented note:

```markdown
  (Expand-stage exemption: `conventions.md` Standard commands deliberately duplicate
  orientation's Quick Reference and `tasks/scripts.md` while module skills and unit READMEs
  coexist. Do not strip either copy; removing the duplication is stage 2b's job.)
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
- Modify: `stow/RepoSkills/phase-9-human-checkpoint.md` (the confirmation venue)
- Modify: `stow/RepoSkills/orchestration.md` (the Phase 9 skip condition, kept in step with the phase file)
- Modify: `tests/assert-artifacts.sh`

**Interfaces:**
- Consumes: `## Unit List` from Task 3, `conventions.md` from Task 4.
- Produces: `.ai/skills/readme-template.md` in the target repo, the repo-specific instantiation of the grammar, and the Phase 9 confirmation venue the grammar's induction loop names. Consumed by plan 2a-ii, which writes the READMEs themselves.

**Why a separate file.** Spec section 9: six backlog items already target
`phase-2-map-generate.md`, which is 1199 lines and the largest file in the skill. Growing it risks
the context failure these changes exist to prevent. Phase 2 gets wiring; the grammar lives apart.

**Why the grammar adopts before it imposes.** The reference repo
(`/Users/powerx/src/github.com/powerxai/data`, main) already enforces a README convention in CI:
`ci/cli/scripts/check-readme-conformance.py` (updated 2026-09-01, with good and bad test fixtures
including a miscased-filename case) checks every affected project's README against
`docs/readme-template.md` for filename case, H1, info-box text, section order, skeleton membership
by deploy target, Monitoring rows and unfilled placeholders, and `check-nx-project-readmes.sh`
checks presence. A generator imposing its own section names on that repo would emit a second
template beside a checker enforcing the first, every README would satisfy at most one of them, and
stage 6's regression against the reference could never pass. The names prove the point:
`## Monitoring` appears 68 times across that repo's tracked READMEs and `## Observability` zero,
yet an earlier draft of this grammar said `Observability`. The template's conditional sections are
`Endpoints`, `Environment Variables` and `Runbook` (`docs/readme-template.md:136-137`), where the
draft said `Configuration`, a name the reference never uses. `## Build and packaging` recurs in 26
READMEs without a slot in the template's own conditional list, so a generator without a rule for
recurring repo sections meets it with no instruction at all. And real conformant READMEs carry more
than one unit-specific section (`services/monitoring` has both `Dashboards` and `Alert rules`),
where the draft allowed exactly one. The grammar below therefore detects and adopts an existing
convention, and its own names, corrected to the reference's converged names, are the fallback for a
repo that has none.

- [ ] **Step 1: Add the assertions**

Append to `tests/assert-artifacts.sh` before the summary. The `file_lacks` helper is the negative
counterpart of `file_has` and exists for the deferred-sections check: a `file_has` on
`conventions.md` cannot test that `readme-template.md` omits something, and the earlier draft's
version of this assertion did exactly that, passing on any run where Task 4 passed.

```sh
file_lacks() {
    # file_lacks <description> <file> <grep-pattern>
    # Passes when the file exists and nothing in it matches.
    if [ -f "$REPO/$2" ] && ! grep -qi -- "$3" "$REPO/$2"; then
        printf "  ok   %s\n" "$1"
    else
        printf "  FAIL %s\n       %s missing or has a match for [%s]\n" "$1" "$2" "$3"
        FAILED=1
    fi
}

exists     "readme-template.md generated"        ".ai/skills/readme-template.md"
file_has   "has a full skeleton"                 ".ai/skills/readme-template.md" "full skeleton"
file_has   "has a slim skeleton"                 ".ai/skills/readme-template.md" "slim skeleton"
file_has   "Agent Notes is last"                 ".ai/skills/readme-template.md" "Agent Notes"
file_has   "carries the include test"            ".ai/skills/readme-template.md" "10 seconds"
file_has   "environment variables are a pointer" ".ai/skills/readme-template.md" "\.env\.example\|declaring file"
file_has   "fallback section names used, since the fixture has no convention" ".ai/skills/readme-template.md" "## Monitoring"
file_lacks "deferred sections are not shipped"   ".ai/skills/readme-template.md" "Contracts owned"
```

- [ ] **Step 2: Run to verify they fail**

```bash
sh "$REPO/tests/assert-artifacts.sh" "$FIXTURE"
```

Expected: the eight new `readme-template.md` assertions FAIL (`file_lacks` fails too, because the
file does not exist yet), the Task 4 assertions still PASS.

- [ ] **Step 3: Write the grammar file**

Create `stow/RepoSkills/readme-grammar.md`:

```markdown
# README Grammar

RepoSkills does not ship a README template. It ships this grammar, and generates a repo-specific
`.ai/skills/readme-template.md` from it during Phase 2. Read `## Project System` and `## Unit List`
from `state.md` before generating.

## Adopt and align

Where the target repo already has a README convention, adopt it. The section names and section set
in this file are the fallback for a repo with no existing convention, never a standard to impose on
one that does: a generated template that disagrees with a checker the repo already runs creates two
competing conventions, and every README that satisfies one fails the other.

**Detect an existing convention in this order.** The first source found is authoritative; later
ones only fill what it leaves unstated.

1. **CI enforcement.** Search the repo's CI scripts and workflows for a README structure check
   (grep the CI directory for `readme`). What such a checker enforces, the section names, order,
   skeleton membership and any exact required text it tests, is the convention's definition, adopted
   verbatim: it is what merges are gated on.
2. **A README template document**, commonly `docs/readme-template.md` or similar. Adopt its
   skeletons, its section names and its conditional-section list.
3. **A conventions document** that names README sections.
4. **The de facto pattern.** Where none of the above exists but most existing unit READMEs share a
   section set, induce that set and confirm it through the induction loop below before adopting it.

**When the repo's names and this file's names disagree, the repo's names win.** Map by role, never
by string: the repo's post-Overview operational-links section fills the Monitoring slot whatever it
is called, its configuration-pointer section fills the Environment Variables slot, and so on.
Record the mapping in the generated template, so a drafting agent never reintroduces the fallback
names.

**A recurring section this grammar does not name is adopted, not dropped.** A section name that
recurs across the repo's conformant READMEs in the conditional slot is a repo-convention
conditional section: add it to the generated template's conditional list with a one-line contents
note induced from how the repo uses it, and confirm the note through the induction loop.

**When the sources disagree with each other**, a template internally inconsistent, or out of step
with the checker or with the READMEs: whatever CI enforces wins, because it is what merges are
gated on. Where no check settles the conflict, follow the majority of existing conformant READMEs,
record the inconsistency in the run report, and put the question to a human through the induction
loop's venue. Never silently pick a side, and never emit a template the repo's own checker would
fail.

How far a run may restructure an existing README to align it with the adopted convention (the
bounded write territory) is pending spec section 3.2 and lands in a follow-up; this file governs
only what the generated template says.

## Two skeletons, chosen by deployability

A unit is deployable when the repo's `deployability-predicate` says it ships. Otherwise nothing runs
and the sections about running and watching it do not apply. The names below are the fallback set,
following the reference implementation's converged names, and are used verbatim only where Adopt and
align found no existing convention.

| Section | Full (deployable) | Slim | Contains |
|---|---|---|---|
| Title | yes | yes | The unit's canonical name as the project system reports it |
| Conventions info-box | yes | yes | A link to `conventions.md` and the override rule |
| Overview | yes | yes | One or two sentences on what the unit does and why |
| Monitoring | yes | no | Only where a link pattern was confirmed. Unfillable rows stay `_not yet linked_` |
| Running and testing locally | yes | no | The quick loop, plus only what is specific to this unit |
| Agent Notes | yes | yes | Gotchas and what the code cannot tell you. **Always last** |

**Conditional sections**, either skeleton, after Running and testing locally and before Agent Notes,
only where the substrate exists: `Endpoints` (an API surface), `Environment Variables` (a pointer to
the declaring file, never values), `Runbook` (operational failure modes with known responses), one
or more unit-specific topics named for what they are, and any recurring repo-convention section
Adopt and align found. A unit may legitimately carry several: a monitoring service can have both a
dashboards section and an alert-rules section.

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
in order. The `Environment Variables` slot reads "pointer to the declaring file", so there is no
table to negotiate away. This is deliberate: agents under a competing incentive negotiate with
prohibitions, and prohibition-form guidance measurably backfires on wrong-output-shape failures.

**Agent Notes bullets cite their sources.** A bullet asserting a repo fact ends with the path or
paths it derives from, so the next agent can verify the claim before acting on it and a drift check
can test whether it still holds. A bullet that cannot name its source is a guess, and guesses do
not belong in Agent Notes.

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

Run Adopt and align first. Then write `.ai/skills/readme-template.md` containing: both skeletons as
fenced markdown blocks with this repo's real commands and the adopted section names substituted in,
the name mapping wherever the repo's names differ from this file's fallbacks, the include test
verbatim, the Agent Notes citation rule, the conditional section list filtered to those this repo
has substrate for plus the recurring sections Adopt and align found, and an authoring-rules banner
the drafting agent honours and then deletes.

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

In the same edit, add the step to the Phase 2 checklist at `phase-2-map-generate.md:14-21`,
immediately after the `2.2b` line Task 4 added:

```markdown
- [ ] 2.2c: Generate readme-template.md (.ai/skills/readme-template.md)
```

- [ ] **Step 4a: Add the confirmation venue**

The File Structure table routes the confirmation venue here, and two artifacts already depend on it:
the conventions document's Declined candidates and Confirmed patterns sections (Task 4) can only
ever fill if some phase actually asks, and the grammar's induction loop names Phase 9 as the venue
whenever Phase 1 is skipped. This step lives in this task rather than Task 4 because the
phase-9 addition links `readme-grammar.md`, which exists from Step 3 of this task.

In `stow/RepoSkills/phase-9-human-checkpoint.md`, the Skip Condition lists three conditions at
`:14-16`. Append two more, and change "all three conditions" at `:18` to "all five conditions", so
the skip is blocked while confirmations are pending:

```markdown
4. `state.md`'s `## Unit List` contains no `action: create-pending-confirmation` entry
5. No induced pattern awaits confirmation (no generated artifact carries a `_not yet linked_` row
   whose pattern was never presented to a human)
```

Mirror the same two conditions in `stow/RepoSkills/orchestration.md`'s Phase 9 skip condition
(items at `:270-272`), changing "ALL THREE" at `:269` and "all three conditions" at `:274` to five,
so the orchestrator and the phase file cannot disagree about when Phase 9 may be skipped.

Then, in `phase-9-human-checkpoint.md`, after Step 3 (Present Missing Info Questions, `:178`) and
before Step 4 (`:202`), insert a lettered step, plus its checklist entry
(`- [ ] 9.3a: Confirm gated units and induced patterns`) immediately after the `9.3` line (`:33`)
of the Phase 9 checklist:

```markdown
## Step 3a: Confirm Gated Units and Induced Patterns (Step 9.3a)

Read `## Unit List` from `state.md`. For each entry with `action: create-pending-confirmation`,
present the path and its signals and ask whether it should get a README. Record the outcome in
`.ai/skills/conventions.md`: a yes moves the unit into Confirmed units, and its `action` in
`state.md` becomes `create`; a no adds it to Declined candidates with the date. Never record an
outcome only in `state.md`: that file lives on one machine, and a decline recorded nowhere else is
re-proposed on every other machine forever.

For each induced pattern awaiting confirmation, follow the induction loop in
[readme-grammar.md](readme-grammar.md): present the examples and the derived pattern, and record a
confirmed pattern in `conventions.md` under Confirmed patterns.

When no human answers (a headless run), leave every pending item pending, keep the placeholders,
and carry the full list forward in the final report: a blocked skip must never become a hung
pipeline.

Update `state.md`: mark step 9.3a complete.
```

The scenario runs in this plan dispatch Phases 0 and 2 only (see the Run protocol), so no assertion
covers this step. Verify it by reading the two amended skip conditions side by side and confirming
they list the same five conditions.

- [ ] **Step 5: Run the scenario and assertions**

Run Phase 2 against the fixture, then:

```bash
sh "$REPO/tests/assert-artifacts.sh" "$FIXTURE"
```

Expected: `PASS`. Then confirm by reading `$FIXTURE/.ai/skills/readme-template.md` that it contains a
slim skeleton without Monitoring or Running-locally sections, and that it does **not** mention
`Contracts owned`.

- [ ] **Step 6: Check the token budget you were warned about**

```bash
wc -l "$REPO/stow/RepoSkills/phase-2-map-generate.md"
```

Expected: about 1237 lines, up from 1199. The additions are Task 4's Step 2.2b (about 22 lines), its
expand-stage exemption note (about 4 lines), this task's Step 2.2c (about 10 lines) and one
checklist line for each new step. If the count is materially above about 1245, grammar content has
leaked into phase 2 and belongs in `readme-grammar.md`. This is not the final ceiling: Task 6 grows
the same file once more and carries its own check.

- [ ] **Step 7: Commit**

```bash
git add stow/RepoSkills/readme-grammar.md stow/RepoSkills/phase-2-map-generate.md stow/RepoSkills/phase-9-human-checkpoint.md stow/RepoSkills/orchestration.md tests/assert-artifacts.sh
git commit -m "add the README grammar as its own instruction file

Spec section 5. RepoSkills ships a grammar and a generator; the concrete
template is an artifact generated into the target repo, because the reference
implementation's template is saturated with repo-specific mechanisms that
cannot live in a tool targeting any repo.

The grammar adopts an existing convention before imposing its own names: the
reference repo enforces its template in CI, and a second template beside a
checker enforcing the first is two conventions where there was one. The
fallback names follow the reference's converged names (Monitoring, Environment
Variables), and Phase 9 gains the confirmation venue the induction loop and the
create gate both depend on.

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

Expected: `PASS`. Then check the final ceiling for `phase-2-map-generate.md`, since this is the last
task in this plan that grows it:

```bash
wc -l "$REPO/stow/RepoSkills/phase-2-map-generate.md"
```

Expected: about 1254 lines. This task's generation instruction is about 17 lines on top of Task 5's
count of about 1237. Anything materially above about 1260 means content that belongs in
`readme-grammar.md` or `conventions.md` has leaked into phase 2.

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
file, with 5.3's confirmation venue wired into Phase 9 by Task 5 Step 4a. Section 9's token-budget
mitigation is Task 5 Step 6 plus the final ceiling in Task 6 Step 4, and its first-run regression
target is Task 1.

Deliberately **not** covered here, and belonging to the named sibling plans: writing or updating the
per-unit READMEs (2a-ii), the harvest (2b), and the drift, routing, simulation-access, state
reconstruction and `--update` changes (2a-iii). Section 3.5's inventory rows are consumed by 2a-iii
and 2b, not by this plan, which adds only new outputs.

**Placeholder scan.** No TBD or TODO. Every step carries the content to be written. The fixture
generator and both assertion scripts are complete and runnable. The only non-literals are `$REPO`,
`$FIXTURE` and `$STATE`, all three defined in the "Run this first" block at the top of this plan and
re-exported by every task, so no task depends on state inherited from another.

**Type consistency.** `state.md`'s `## Project System` keys are defined in Task 2 and read by Tasks
3, 4 and 5. `## Unit List` fields (`path`, `name`, `signals`, `deployable`, `readme`, `action`,
`nested-under`) are defined in Task 3 and read by Tasks 4, 5 and 6, and the `action` values used in
Task 3's assertions (`create`, `update`, `create-pending-confirmation`, `excluded`) match the values
its instruction text produces, with `create-pending-confirmation` resolved to `create` or a recorded
decline only by Phase 9 Step 9.3a (Task 5 Step 4a). `readme-grammar.md` is created in Task 5 and
referenced by that same path within Task 5 (the phase 2 wiring and the Phase 9 venue) and in Task 7.
The grammar's fallback section names (`Monitoring`, `Environment Variables`) match the names the
Task 5 assertions test for and the names Task 5 Step 5 reads for, and the fixture repo carries no
README template, no conventions document and no CI README check (its workflows never mention
`readme`), so a fixture run always exercises the fallback branch of Adopt and align.
`assert-phase0.sh` is created in Task 2 and extended in Task 3; `assert-artifacts.sh` is created in
Task 4 and extended in Tasks 5 and 6.

**One risk worth naming.** Every test here runs a pipeline phase by dispatching an agent against the
fixture, so runs are slow and not bit-for-bit deterministic. The assertions are therefore written
against structural facts (does the section exist, does this path carry this action) rather than
against exact wording. Do not tighten them into string equality; that would make the suite flaky
without making it stronger.

---

## Review amendments

**Independent review, 2026-09-02 (Fable).** The plan was reviewed against the skill source, the
fixture design and the reference repo by an independent agent briefed to find problems. Verdict: do
not execute as written. The findings were applied in two passes: the five blockers and most majors
in commit `f82d966`, the remainder in this amendment. Every finding was verified against the files
before being acted on.

Applied in commit `f82d966`:

| Finding | Resolution |
|---|---|
| Every Task 3 assertion was a single-line grep against the multi-line block format the same task defines, so the suite was permanently red, or the Phase 0 agent would flatten `state.md` to satisfy it | Block-aware `awk` helper (`unit_has`) with exact path matching, so `services/orders` cannot swallow `services/orders/pricing`, and `create` anchored so it cannot match `create-pending-confirmation` |
| The gate did not hold `src/reporting` back: `phase-0-discover.md:175` lists `index.ts` as a Strong signal and the fixture gave it one | The fixture drops the barrel `index.ts` and gains an unambiguous second Medium type, and a new `src/ingest` shape pins the rule that an entry point alone never earns ungated creation |
| The nested-unit fixture sat under `vendor/`, which is on the never-browse exclusion lists, so Phase 0 could reach it only by disobeying its own rules | Moved to `services/orders/pricing` |
| Tasks 2 and 3 added steps numbered 0.5 and 0.6, both already taken by existing Phase 0 steps | Renumbered to 0.4a and 0.4b, and the Phase 0 checklist agents copy into `state.md` is amended in the same task |
| Phase 0 skips entirely when `_triage.md` exists, so every "re-run Phase 0" step would have written nothing | The explicit per-task Run protocol at the top of this plan |
| The workspace root fell through the gate; a Strong root manifest would earn the repo root a create | Question 0 in Step 4b: the root is excluded by rule, and the fixture root pins it |
| Exclusion and an existing README were unordered; an excluded directory with a README read as `update` | Question 1 states exclusion beats the README, and `experiments/spike` gained a README so the precedence is exercised |
| Authoritative-source selection could never fire: the fixture had one project system, so no counterexample existed | A second project system, `analytics/pipeline`, invisible to the `workspaces` globs |

Applied in this amendment:

| Finding | Resolution |
|---|---|
| The grammar imposed its own section names on repos that already have a convention, and the reference repo now enforces its template in CI, so a run against it would emit a second, disagreeing template and stage 6's regression could never pass | The Adopt and align section: detection order (CI checker, template document, conventions document, de facto pattern), repo names win by role mapping, recurring unnamed sections adopted, CI wins internal inconsistencies, and never emit a template the repo's checker would fail. Owner's decision |
| The fallback names contradicted the reference: `Observability` appears zero times across the reference's READMEs and `Monitoring` 68; `Configuration` is not in the reference template, whose conditional sections are `Endpoints`, `Environment Variables` and `Runbook` (`docs/readme-template.md:136-137`) | Fallback names corrected to the reference's converged names, as a consequence of Adopt and align rather than instead of it |
| `## Build and packaging` recurs in 26 reference READMEs with no slot in any skeleton or conditional list, so a generating agent meeting one had no instruction | The recurring-section rule in Adopt and align, plus the conditional list carrying recurring repo-convention sections |
| The grammar allowed exactly one unit-specific section where real conformant READMEs carry several (`services/monitoring` has both `Dashboards` and `Alert rules`) | One or more |
| The Agent Notes citation discipline (a bullet asserting a repo fact ends with the paths it derives from, `docs/readme-template.md:90`) was in the reference and the spec's transfer-unchanged list, but not in the grammar | Added as a grammar rule and carried into the generated template |
| Finding 16: `phase-2-map-generate.md:1083`'s no-duplicate-facts self-review item would make a diligent Phase 2 agent strip either `conventions.md`'s Standard commands or orientation's Quick Reference during the expand stage | Task 4 adds an expand-stage exemption note directly below that item |
| Finding 12: spec 6.4's "no README-drift reference implementation exists" is stale input for 2a-iii | The note under the sibling-plans table below; the spec agent is correcting 6.4 itself |
| Finding 18: Task 5 Step 6 expected at most about 1215 lines while its own arithmetic produced 1239, so the checkpoint read as a failure on a correct implementation, and Task 6 then grew the file again with no revised ceiling | Recounted against the file as it stands: about 1237 after Task 5, and Task 6 Step 4 carries the final ceiling of about 1260 |
| The File Structure table routed the confirmation venue to Task 4, but no task step edited `phase-9-human-checkpoint.md` or the two skip conditions, so the venue the grammar and the conventions doc depend on was never built | Task 5 Step 4a: two skip-blocking conditions in both files that state them, and Step 9.3a confirming gated units and induced patterns, recording outcomes in `conventions.md` |
| `f82d966`'s message also claimed the conventions doc had stopped specifying a hand-maintained unit inventory. Its diff never touched that row either: the Task 4 table still read "One line per unit from `## Unit List`", and its assertion grepped for `services/orders`, so the suite asserted the very inventory `data/docs/project-conventions.md:46` forbids. An audit had matched the warning text in the row above and mistaken it for the fix | The row becomes Unit decisions, recording only a candidate a human settled or one whose treatment departs from the query. The assertion now looks for `src/reporting`, the gated candidate, which is recorded either way once confirmed or declined |
| `f82d966`'s message claimed the deferred-sections assertion was no longer a no-op, but its diff never touched it: the assertion grepped `conventions.md` for `provenance=generated`, which passes whenever Task 4 passes | The `file_lacks` helper, asserting `readme-template.md` exists and omits `Contracts owned` |
| Steps 2.2b and 2.2c were added to Phase 2 but not to the Phase 2 checklist agents copy into `state.md`, the same untracked-step failure Task 2 fixes for Phase 0 | Both tasks add their checklist line in the same edit |
| The Self-Review enumerated six `## Unit List` fields where Task 3 defines seven (`name` was missing), counted "three assertion scripts" where there are two plus the fixture generator, and mapped the token-budget check to Task 5 alone | All three corrected |

Deliberately left alone: the bounded-write-territory semantics ("how much of an existing README a
run may rewrite"). Spec section 3.2 is being settled this pass, and the grammar implements it in a
follow-up once the spec is authoritative; the grammar carries a one-line pending note where the
question arises.

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

**A stale spec input 2a-iii must not trust.** Spec 6.4 records that no README-drift reference
implementation exists and that the work is greenfield. That was true of `data-2` in August and is
not true of `data` main, which now carries `ci/cli/scripts/check-readme-conformance.py` (structure
conformance against `docs/readme-template.md`, updated 2026-09-01, with good and bad test fixtures
including a miscased-filename case), its CI wrapper `check-readme-conformance.sh`, and
`check-nx-project-readmes.sh` (presence). 2a-iii ports that implementation rather than building
one. The spec agent is correcting 6.4 itself; this note exists so 2a-iii is told even if it reads
this plan first.
