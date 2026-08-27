# RepoSkills: README output mode and backlog burn-down

Design spec covering all 18 items in `~/.claude/skills/RepoSkills/IMPROVEMENTS.md`, plus the
architectural change that supersedes several of them.

Status: design approved, not yet implemented.
Date: 2026-08-27.

---

## 1. Summary

RepoSkills currently emits `.ai/skills/modules/<name>.md`, one file per module boundary, as a
parallel documentation tree beside the code. This spec removes that tree entirely and replaces it
with per-unit `README.md` files living in the units they describe, on the principle that humans
will maintain a README they already own and will not maintain a parallel tree they do not.

The 18-item backlog is then resolved against that new shape: five items get rewritten in its
vocabulary, two are obviated, one has a working reference implementation to cite, and ten remain
as genuine gaps to fix in place.

### 1.1 Non-goals

- No changes to phases 3, 7, or 8.
- No re-architecture of the 10-phase pipeline. Phases keep their numbers and their contracts.
- No adoption of any convention specific to the PowerX `data` repo. That repo is cited throughout
  as a worked example of correct output, never as a source of mechanisms. See section 4.
- No changes to `templates/skill-drift-ci.yml` beyond what items 7 and 9 require.
- Not a rewrite of `IMPROVEMENTS.md`. It stays as the provenance record.

---

## 2. Prior art and how it was used

The PowerX `data` monorepo (`~/src/github.com/powerxai/data-2`) completed a
modules-to-READMEs migration in June 2026 and has been running the result since. It is the only
place this design has been tested at scale, so it is the reference throughout.

**It is reference only.** Its documents are saturated with repo-specific mechanisms that must not
enter RepoSkills:

| Repo-specific to `data-2`, excluded | The transferable rule underneath |
|---|---|
| `nx show project <name> --json`, pnpm scripts, `@powerx/` scoping | Skeleton selection runs a deterministic query against whatever project system the repo actually uses, discovered in Phase 0 |
| Grafana Explore log links, Kafka topic dashboards, `prod-emea` / `prod-asia` environments | A field deterministically computable from repo config gets computed; one that is not gets verified or placeheld |
| `<env>.tfvars` as the deployability test, AWS SSO profiles | Deployability is a repo-defined predicate, discovered and confirmed once, never inferred per directory |
| `docs/` as the conventions home | The conventions document's location is a repo choice recorded in state, not a fixed path |

The following transfer unchanged, because they carry no tool assumptions:

- Three-legged architecture (section 3).
- The two-step "what to include" test (section 5.2).
- Placeholder discipline: an explicit `_not yet linked_` beats both dropping a row and guessing a
  value, because an empty row flags the document as incomplete while a dropped row hides the gap.
- Precedence when sources disagree: **code > README > conventions document**, stated canonically in
  exactly one place.
- The Overview boundary: on a README that already exists the Overview is human-authored and agents
  must never fill it in, blank being a valid state; on a README authored from nothing the agent
  writes it, grounded in the unit's own code.
- Never invent. Cite `<file:line>` for every correction. Flag what could not be verified for a
  human rather than guessing or deleting it.
- Generate rather than detect, for derived files (section 6.3).

### 2.1 Corrections to the backlog

Item 18 was written mid-migration and three of its statements no longer hold. Verified against
`data-2` on disk, 2026-08-27.

**C1. The five per-type templates are gone.** Item 18 records
`docs/templates/readme/{ts-service,python-service,ingestion-adapter,shared-package,family}.md`.
That directory does not exist. The repo converged on **one template with two skeletons**, selected
by deployability rather than by service type. This is strictly better and the spec adopts the
converged form: type-based selection requires classifying a unit into a taxonomy that varies per
repo, whereas deployability is a single predicate the repo can answer about itself.

**C2. The referenced drift script is gone.** Item 18 cites
`data-2/.ai/skills/scripts/skill-drift.sh`. That path holds only `sync-agent-context.sh`.
A CI workflow `.github/workflows/skills-drift.yml` does exist, so item 7 has a working reference
implementation even though the script item 18 names does not.

**C3. Items 13 and 14 are solved, and solved better than proposed.** Item 13 asks that every
platform-glue file be self-sufficient; item 14 asks for a script that *detects* divergence between
them. `data-2` instead **generates** the derived files from `AGENTS.md` as single canonical source:
splitting at the first `## Tech Stack` heading so tool-specific preambles are preserved verbatim,
applying a depth-aware `../` prefix per target, and offering a `--check` mode that exits non-zero
when a derived file is stale. Divergence is impossible by construction, so the detector item 14
proposes has nothing to detect. Both items are obviated and replaced by section 6.3.

---

## 3. The architecture

`.ai/skills/modules/` is removed from the pipeline. Output becomes:

| Artifact | Condition |
|---|---|
| `.ai/skills/orientation.md` | always |
| `.ai/skills/domain-context.md` | always |
| `.ai/skills/tasks/<name>.md` | always |
| `<conventions-doc>` | always, at a repo-chosen path recorded in `state.md` |
| `<unit-root>/README.md` | only where Phase 0 finds unit boundaries |
| `.ai/skills/Tools/` and root platform-glue files | always |

**The unit threshold.** A repo has units when the enumeration query of section 4 returns more than
one project. When it returns zero or one, there are no per-unit READMEs at all: that knowledge
folds up into `orientation.md` and `domain-context.md`, and `tasks/` survives at
`.ai/skills/tasks/`. A small repo does not get scattered READMEs, and a single-project repo keeps
whatever root `README.md` it already has, which the pipeline does not own.

Note that the threshold is a property of the project graph, not of repo size tier. A Tier B repo
with four projects crosses it; a Tier C repo that is one large project does not.

### 3.1 Three legs, not one

A per-unit README on its own reproduces the maintenance problem it was meant to solve: every unit
restates the same structural facts, and they drift apart. The working structure is three documents
with a strict division of labour.

1. **Conventions document.** Repo-wide structural facts, written once: what counts as a unit, the
   standard layout, the standard commands, the testing approach, how deployment works. A README
   must not repeat anything this document covers.
2. **Per-unit README.** Only what is true for that one unit, plus its deliberate deviations from
   the conventions.
3. **`navigate-unit` task skill.** The procedure for using the other two: how to inspect a unit,
   how to change one, how to verify the change. It gives commands and steps and does not restate
   structural facts.

Each document's maintenance boundary is stated in the document itself, so a future agent editing
the wrong one is told where the content belongs.

### 3.2 Precedence

Code > README > conventions document. Stated canonically in the conventions document and referenced
from the other two, never restated. A deviation documented in a README is intentional: do not
"fix" a unit to match the conventions document without first checking why it deviates.

---

## 4. Unit boundary detection

Replaces item 1's directory-depth rule and item 18's "union nx roots with on-disk globs".

Both of those are heuristics over directory shape. The stronger rule, proven in `data-2`, is that
the repo's own project system already knows the answer, and the pipeline should ask it rather than
infer.

**Phase 0 discovers the project system** and records in `state.md`:

- The **enumeration query**: the command that lists every project the repo recognises.
- The **detail query**: the command that returns one project's root and available targets.
- The **deployability predicate**: what distinguishes a unit that ships from one that does not.
- Known **exclusions**: directories that look like units but are not wired in.

The authoritative list is whatever the enumeration query returns at generation time. The pipeline
must never hand-maintain a parallel inventory.

**Anti-pattern to encode explicitly.** In `data-2` the plausible-but-wrong test is
`pnpm-workspace.yaml` membership, which silently excludes every Python project. The generalised
rule: when more than one candidate query exists, the pipeline must confirm which one is
authoritative rather than picking the most visible, and must record the counterexamples that
distinguish them. A query that returns a plausible subset is the most dangerous failure mode here,
because nothing looks wrong.

**Excluded directories self-document.** A directory that looks like a unit but is deliberately
outside the project system gets a README saying so. This closes item 18's "scope reality" pitfall
without a whitelist to maintain.

---

## 5. The README grammar

RepoSkills does not ship a README template. It ships a **grammar** and a **generator**; the
concrete template is an artifact generated into the target repo during Phase 2, from what Phases 0
and 1 discovered. `data-2/docs/readme-template.md` is what correct output looks like for one
repo, not something to copy.

### 5.1 Sections

**Universal**, present in every README:

| Section | Contains |
|---|---|
| Title | The unit's canonical name as the project system reports it |
| Conventions info-box | A link to the conventions document and the override rule |
| Overview | One or two sentences on what the unit does and why (see the Overview boundary, section 2) |
| Running and testing locally | The quick loop, plus only what is specific to this unit |
| Agent Notes | Gotchas and the things the code cannot tell you. Always last |

**Conditional**, emitted only where Phase 0 finds the substrate:

| Section | Emitted when |
|---|---|
| Observability | The repo has an observability stack with a confirmed link pattern (section 5.3) |
| Endpoints | The unit exposes an API surface |
| Configuration | The unit has configuration worth pointing at. Pointer only, never values |
| Runbook | The unit has operational failure modes with known responses |
| Contracts owned | The unit publishes something others depend on |
| Deviations | The unit deliberately breaks a documented convention |
| Lifecycle status | The unit is not active. Omitted entirely when it is |

Section order is fixed, and Agent Notes is always last.

**On the three new sections.** *Contracts owned* names what this unit publishes that others consume:
topics, tables, events, public API surface. In `data-2` this is buried inside Agent Notes prose,
and it is the single highest-value section for an agent assessing change impact, so it gets a slot.
*Deviations* makes the precedence rule actionable: without a place to record them, "the README
overrides the conventions" is a claim no reader can check. *Lifecycle status* gives item 18's
"status line only when INACTIVE" rule a defined slot instead of a prose instruction, which matters
because a stale ACTIVE line is worse than no line.

### 5.2 What to include

The core rule, and the one agents most consistently under-apply. Include a unit-specific fact only
if it survives:

1. Could an agent get this right in about 10 seconds from this unit's own code and config?
   If no, keep it.
2. If yes, does it also carry a why, a gotcha, a cross-unit consequence, or quick-start
   orientation? If no, cut it.

Cut anything that is both trivially greppable and none of those: a source directory tree, the DI
framework name, an endpoint list that mirrors the controllers.

**Version numbers are the classic cut.** Manifests and lockfiles are the source of truth, and a
README that repeats a version only goes stale. Name a version only where the unit deliberately pins
something different from the convention, and say what it differs from.

**Link, never list.** Environment variables, configuration values, credentials, profile and role
names: point at the file that declares them, or name the variable, never reproduce the value. A
value copied into a README is wrong for every reader but its author, and is a second source of
truth by definition. If the declaring file is itself wrong, fix that file rather than documenting
the discrepancy.

**Form note.** Item 18 specifies this rule as a list of prohibitions, and records that agents
under-applied it anyway: "they removed tables but still named individual env vars, listed
consumers, dumped dir trees". Per `superpowers:writing-skills`, this is a wrong-output-shape
failure, and prohibition-form guidance measurably backfires on those, testing worse than no
guidance at all, because an agent under a competing incentive negotiates with a prohibition. The
generated template therefore states each section as a **positive contract**: what the section
contains, in order, with the Configuration slot reading "pointer to the declaring file" so there is
no table to negotiate away. Prohibition form is reserved for the genuine discipline failures in
this spec, namely items 2 and 11.

### 5.3 Pattern induction with human confirmation

The mechanism that lets a repo-agnostic generator produce repo-specific content without guessing.

For any field whose shape is repo-specific (observability links, dashboard URLs, the deployability
predicate, the test command shape):

1. **Discover.** Dispatch an agent to find N real examples of the artifact in the repo.
2. **Induce.** Derive a pattern from the examples with the variable parts identified.
3. **Confirm.** Present the examples and the derived pattern to the human in the Phase 1 interview:
   "here are three log links I found and the pattern I derived from them; does this generalise?"
4. **Record.** The confirmed pattern goes into `state.md` as a generation rule.
5. **Apply.** Per-unit field values are computed from the confirmed pattern.

**An unconfirmed pattern produces a placeholder, never a guess.** This is what ties the placeholder
discipline to the induction loop, and it is why `_not yet linked_` is a first-class output rather
than a failure.

Once confirmed, a field that was non-deterministic becomes deterministic: the pattern is settled
once for the repo, and every per-unit value follows from it. Fields that resist induction, because
they genuinely vary per unit rather than following a pattern, must be resolved and verified per
unit or omitted. They must never be pattern-filled.

---

## 6. Backlog disposition

All 18 items. Target file paths verified to exist; section anchors verified by heading grep.

### 6.1 Rewritten in the new vocabulary

| # | Item | Disposition |
|---|---|---|
| 1 | Every microservice Tier-1 regardless of depth | Superseded by section 4. Depth stops mattering once the project system is authoritative. Lands in `phase-0-discover.md`. |
| 10 | Drift script surfaces collisions, missing skills, stale dirs | Becomes README presence plus freshness. Presence must be checked **case-sensitively** via the version-control file list, because the local filesystem hides a miscased `readme.md` that breaks CI elsewhere. Freshness compares README mtime against later non-test code in its unit. |
| 11 | Dependency lists need source-verification | Becomes the *Contracts owned* section, governed by never-invent and `<file:line>` citation. Folds in item 15. |
| 15 | Dependency omissions follow a consistent pattern | Folded into 11. |
| 18 | Per-service READMEs | Becomes sections 3 through 5 of this spec, corrected per C1. |

### 6.2 Obviated

| # | Item | Disposition |
|---|---|---|
| 13 | Every glue file self-sufficient | Achieved by construction in 6.3. |
| 14 | Detect cross-file routing-table drift | Nothing to detect once files are generated. Replaced by 6.3. |

### 6.3 Generate, do not detect

Replaces items 13 and 14. One file is the canonical source for shared routing tables, key rules,
and the architecture overview. Every other platform-glue file is **generated** from it:

- Split at a defined marker heading. Everything above it is the tool-specific preamble, preserved
  verbatim. Everything from it down is regenerated on each sync.
- Repo-root-relative links get a `../` prefix computed from each target's directory depth.
- A `--check` mode exits non-zero when any derived file is stale, for CI.
- Each derived file carries a do-not-hand-edit banner naming the canonical source.

This satisfies item 13's compaction-survival requirement, since every derived file still contains
the full content, while removing the maintenance burden item 14 was created to manage.

### 6.4 Reference implementation exists

| # | Item | Disposition |
|---|---|---|
| 7 | Wire drift tooling into CI by default | `data-2/.github/workflows/skills-drift.yml` is a working example. Note per C2 that the script item 18 cites is gone, so the workflow must be re-read before being generalised. |

### 6.5 Genuine gaps, fixed in place

| # | Item | Target | Anchor |
|---|---|---|---|
| 2 | Negative results need 3 independent search strategies | `phase-4-validate.md` | Rule applied across Checks 1-9 |
| 3 | Ask about historical context and in-house tools | `phase-1-domain-interview.md` | `Domain Knowledge Questionnaire`, line 175 |
| 4 | Encoding and format claims are a verification category | `phase-4-validate.md` | New Check 10, after `Check 9: The 5-second grep test (Step 4.11)` |
| 5 | Prompt for adjacent repos by relationship type | `phase-0-discover.md` + `phase-1-domain-interview.md` | Boundary detection; Questionnaire |
| 6 | Language servers as a first-class tool | `phase-2-map-generate.md` | Orientation generation |
| 8 | Wire in surfaced tools proactively, do not just log | `phase-1-domain-interview.md` + `phase-9-human-checkpoint.md` | Provenance question; default to act |
| 9 | Drift detection advisory by default | `phase-6-self-resolve.md` + `templates/skill-drift-ci.yml` | Enforcement tooling |
| 12 | Threshold rules verified on both ends | `phase-4-validate.md` | New Check 11 |
| 16 | Glossary terms alphabetical | `phase-1-domain-interview.md` | `Domain Glossary`, line 251 |
| 17 | Canonical task-skill names and boilerplate USE-WHEN | `phase-2-map-generate.md` | Task-skill generation |

Item 2 gets prohibition form, being a genuine discipline failure: an agent that knows one grep is
insufficient and stops anyway. Encode as "a negative result from one search is a hypothesis, not a
conclusion", with the audit report required to show which patterns were run and which directories
were covered.

Item 3's questions extend naturally into the section 5.3 induction loop, since both ask the human
for what the code cannot say.

### 6.6 Tally

Obviated 2, rewritten 5, reference implementation 1, fixed in place 10. Total 18.

---

## 7. Housekeeping

Two problems found during design that the backlog does not record.

**H1.** `phase-drift-resolve.md` (710 lines) exists in `stow/RepoSkills/` but has no symlink in
`~/.claude/skills/RepoSkills/`. The stow is incomplete, so that phase is currently invisible to the
running skill even though `SKILL.md` documents its invocation. Needs a verdict: bug or deliberate
hold.

**H2.** `IMPROVEMENTS.md` has never been committed to this repo. It exists only in `~/.claude` and
is one `rm` away from gone. It should be committed as the provenance record before any of it is
acted on.

---

## 8. Sequencing

| Stage | Content | Rationale |
|---|---|---|
| 1 | H1, H2 | Cheap, and H2 protects the input to everything downstream |
| 2 | Sections 3, 4, 5: the architecture | Every later item is expressed in its vocabulary |
| 3 | Items 2, 4, 12 (phase-4 checks), items 3, 5, 16 (phase-1 questions) | Additive, low-risk, independently testable |
| 4 | 6.3 generation, items 7, 9, 10 | Tooling, depends on stage 2's output shape |
| 5 | Items 6, 8, 17 | Independent of the rest |
| 6 | Regression run | Needs everything above |

---

## 9. Verification

`superpowers:writing-skills` states the Iron Law applies to **edits** of existing skills, not only
to new ones: no change without a failing test first. Each change in this spec therefore carries a
baseline scenario, run before the edit, documenting what an agent does without the guidance.

Per that skill's guidance, match the test to the failure type:

- **Discipline changes** (items 2, 11): pressure scenarios with combined pressures. Success is
  compliance under maximum pressure.
- **Output-shape changes** (section 5.2, the README contract): micro-test the wording against a
  no-guidance control, 5 or more reps, every flagged match read manually. Variance is itself a
  metric: five different interpretations across five reps means the wording is not binding.
- **Structural changes** (sections 3, 4, 5.1): application scenarios. Can an agent generate a
  correct README for a unit it has not seen?

**Regression target.** The prior full-pipeline run is `data-2` at commit `858ff1f6`, with
post-PR-#5743 state on branch `repo-skills` and the README migration on branch
`repo-skills-to-readmes`. Preserved state is at `~/.claude/MEMORY/RepoSkills/data-2/state.md`.

**This baseline must be re-confirmed reachable before it is trusted.** It is dated June 2026, and
section 2.1 documents three things that have already changed underneath it since.

**Token budget.** Six items target `phase-2-map-generate.md`, already 1199 lines and the largest
file in the skill. Growing it risks causing the context failure these changes exist to prevent.
The README grammar (section 5) should therefore land as its own instruction file rather than as an
extension of phase 2, with phase 2 referencing it. `phase-6-self-resolve.md` already has a
`Step 5: Check Token Budgets (Step 6.5)` that should be extended to cover the skill's own files,
not only generated output.

---

## 10. Open questions

1. H1: is the missing `phase-drift-resolve.md` symlink a bug or a deliberate hold?
2. Is `data-2@858ff1f6` still reachable, and is it still a meaningful baseline given section 2.1?
3. Should the conventions document (section 3.1, leg 1) be generated by RepoSkills, or is it a
   human-authored input the pipeline reads? `data-2` has a hand-written one. Generating it is more
   complete; reading it respects that structural conventions are a human decision.
4. What is the migration path for repos already carrying a `.ai/skills/modules/` tree from an
   earlier RepoSkills run?
