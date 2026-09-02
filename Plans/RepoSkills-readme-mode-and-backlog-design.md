# RepoSkills: README output mode and backlog burn-down

Design spec covering all 18 items of the improvements backlog, whose surviving reconstruction is at
`stow/RepoSkills/IMPROVEMENTS.md` (see section 12), plus the
architectural change that supersedes several of them.

Status: design approved, not yet implemented.
Date: 2026-08-27.

---

## 1. Summary

RepoSkills currently emits `.ai/skills/modules/<name>.md`, one file per module boundary, as a
parallel documentation tree beside the code. This spec removes that tree entirely and replaces it
with per-unit `README.md` files living in the units they describe, on the principle that humans
will maintain a README they already own and will not maintain a parallel tree they do not.

Every boundary `phase-0` Step 4 detects gets a README, including logical boundaries inside a
single-package repo. There is no threshold, and no repo shape loses per-unit coverage.

The 18-item backlog is then resolved against that new shape: five items get rewritten in its
vocabulary, two are obviated, one has a working reference implementation to cite, and ten remain
as genuine gaps to fix in place.

Section 3.5 inventories every existing contract that references `modules/`, of which there are 143
across 12 files, and names its replacement. Section 11 records the independent review that forced
this revision and what each finding changed.

### 1.1 Non-goals

- No re-architecture of the 10-phase pipeline. Phases keep their numbers, and every phase keeps its
  purpose. Several must change internally: see the contract inventory in section 3.5.
- **Withdrawn non-goal.** An earlier draft claimed no changes to phases 3, 7 or 8. That is
  unachievable: `phase-3-refine.md:83` and `:304` iterate `.ai/skills/modules/` as Phase 3's core
  loop, and phases 5, 7 and 8 inherit `orchestration.md:665`, which forbids simulation agents from
  reading anything outside `.ai/skills/`. Both must change for this design to work at all.
- No adoption of any convention specific to the PowerX `data` repo. That repo is cited throughout
  as a worked example of correct output, never as a source of mechanisms. See section 4.
- No changes to `templates/skill-drift-ci.yml` beyond what items 7 and 9 require.
- Not a rewrite of `IMPROVEMENTS.md`. It stays as the provenance record.
- **Not a replacement for the existing re-run machinery.** Diff-based re-run, `--fresh`, `--update`
  and `phase-drift-resolve` all survive unchanged in purpose. READMEs become another artifact they
  maintain, not an exception to them. See section 3.2.

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
| `docs/` as the conventions home | RepoSkills owns `.ai/skills/` and puts its generated documents there. `docs/` is a `data-2` convention and is not adopted |

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
| `.ai/skills/conventions.md` | always. Requires amending `orchestration.md:414`, see 3.1 |
| `.ai/skills/readme-template.md` | only where at least one unit is confirmed |
| `.ai/skills/tasks/<name>.md` | always. `navigate-unit` specifically, only where at least one unit is confirmed |
| `<unit-root>/README.md` | one per unit boundary, see section 4 |
| `.ai/skills/Tools/` and root platform-glue files | always |

**Which boundaries get a README, and which get one created.** These are different questions, and
an earlier draft asked only the first.

In any repo mature enough to be worth documenting, **most boundaries already have a README.**
`data-2` main carries 197. That matters twice over. An existing README is the strongest ownership
signal available, stronger than anything Step 4 can infer, because it is a decision a human already
made rather than a property the pipeline guessed. And updating one is the safe operation: it is the
human-territory verify-and-patch path of 3.2, which fixes wrong claims and leaves everything it
cannot verify alone.

The only action that can impose an unwanted artifact is **creating** a README where a human never
put one. So that is the only action gated:

| Situation | Action | Confirmation |
|---|---|---|
| A README already exists, in any letter case | Update it | None. The human already decided this directory deserves one |
| No README, and any **Strong** signal: own package manifest, own Dockerfile or entry point | Create it | None. A directory that builds or ships on its own has owners |
| No README, and a **Deployment** signal: own CI workflow, Terraform module, k8s manifest or Helm chart | Create it | None. Same reasoning |
| No README, **Medium signals only**: domain or logical | Create it | **Yes.** Confirm the list first |

`phase-0` Step 4 qualifies a candidate on one Strong signal *or two Medium ones*, so a Medium-only
candidate can be a directory nobody considers a unit. Writing a README into it would reproduce the
very thing this spec removes, an unowned document nobody maintains, relocated from a parallel tree
into the source tree. Phase 0 already records per-candidate confidence (`high`, `medium`, `low`)
under Step 4's "Recording boundary candidates", and the spec previously used that field nowhere. It
is now the gate.

**Case sensitivity decides "exists", and the local filesystem lies about it.** A miscased
`readme.md` means the unit **has** a README: rename it and edit it, never author a second file
beside it. Presence must be tested against the version-control file list rather than the working
tree, because macOS hides the difference while CI does not. This is the same trap item 10 records
for the drift signal, and it applies to the create-or-update decision first.

**Confirmation venue:** the Phase 1 interview when it runs, the Phase 9 checkpoint otherwise, as one
list the human accepts or trims. See 3.6 for why the venue needs both.

**This replaces coverage tiering rather than merely deleting it.** Tier C currently ranks boundaries
by *importance*, giving the top 10 full skills, the next 15-20 summaries and the rest a one-line
mention (`orchestration.md:509-515`). Importance is a judgement the pipeline makes badly and cannot
verify. Whether a boundary builds, ships or deploys is a fact the repo answers, and whether it
already has a README is a fact the git index answers. So ranking by importance is removed and those
two facts take its place. Accept the consequence honestly: a Tier C repo with 40 Strong-signal
boundaries ends up with 40 READMEs, and that is correct, because each of those directories builds or
deploys on its own and already has owners. In practice most of the 40 will already exist, so the run
is mostly updates.

**Unconfirmed Medium boundaries are not silently dropped.** They keep exactly what Tier 3 gave them:
a one-line description in `orientation.md`, plus a place in the confirmation list so a human can
promote any of them later.

**No grouping of confirmed boundaries.** One README per confirmed boundary, always.
`orchestration.md` currently permits Tier D runs to group several services into one skill; backlog
item 1 rejects that, and a README living in its own unit's directory makes it impossible.

Distinguish this from **merging**, which stays legitimate: `phase-2-map-generate.md:96-101` allows a
"merge with parent" verdict during boundary confirmation, deciding a candidate is not a boundary at
all. Merging reduces the boundary count; grouping would reduce the document count below it. Only
the latter is forbidden.

**Nested boundaries.** Step 4's exclusion-list exception explicitly admits a nested package inside a
service, so a unit's directory can contain another unit. This never arose in `data-2`, whose project
roots do not nest. Three rules:

1. Both get a README. Nesting disqualifies neither.
2. The parent's README does not describe the child. It names it and points at its README, under
   *Contracts owned* if the child is a published interface, otherwise *Agent Notes*.
3. **The freshness check subtracts nested unit paths.** Otherwise the parent's "last commit touching
   non-test code in its unit" includes every child commit and the parent flags stale permanently. A
   unit's freshness considers only paths beneath it that no nested unit claims.

**A note on `orchestration.md:412`,** which says module skills "should map to real, coherent
boundaries in the codebase -- not to directories." That rule forbids a skill per *arbitrary* folder,
not directory-based detection; Step 4 is already per-directory. The line should be reworded to say
so, because read literally it appears to forbid this design.

### 3.1 Three legs, not one

A per-unit README on its own reproduces the maintenance problem it was meant to solve: every unit
restates the same structural facts, and they drift apart. The working structure is three documents
with a strict division of labour.

1. **Conventions document**, at `.ai/skills/conventions.md`. Repo-wide structural facts, written
   once: what counts as a unit, the standard layout, the standard commands, the testing approach,
   how deployment works. A README must not repeat anything this document covers.
2. **Per-unit README**, at `<unit-root>/README.md`. Only what is true for that one unit, plus its
   deliberate deviations from the conventions.
3. **`navigate-unit` task skill**, at `.ai/skills/tasks/navigate-unit.md`. The procedure for using
   the other two: how to inspect a unit, how to change one, how to verify the change. It gives
   commands and steps and does not restate structural facts.

**This conflicts with an existing global rule and the conflict must be resolved explicitly.**
`orchestration.md:414` currently states:

> Content that would appear in `conventions.md`, `dependency-map.md`, or `workflows.md` as separate
> files instead lives in `orientation.md` and individual module skills. Do not generate these as
> standalone output files.

That rule exists because a conventions file, with module skills present, was redundant with them.
Once module skills are gone the reasoning inverts: the conventions document is what stops 40 READMEs
each restating the same build commands. The rule must be amended to permit `conventions.md`
specifically, while continuing to prohibit `dependency-map.md` and `workflows.md`, whose original
justification is untouched.

**On placement.** Everything RepoSkills owns lives under `.ai/skills/`, including the generated
`readme-template.md` and the `update-readme` task skill that applies it. The per-unit READMEs are
the deliberate exception: they live in the units they describe precisely because that is what makes
a human willing to maintain them, which is the entire premise of this change. RepoSkills does not
adopt a `docs/` directory; that is a `data-2` convention and stays there.

Each document's maintenance boundary is stated in the document itself, so a future agent editing
the wrong one is told where the content belongs.

### 3.2 Ownership, and where caution belongs

Two separate questions, which an earlier draft of this section wrongly collapsed into one:

- **Preservation:** whose content is it, and what happens to something the pipeline cannot verify?
- **Update strategy:** how does a re-run bring a file up to date?

Ownership answers the first. It does **not** answer the second.

#### Update strategy is verify-and-patch everywhere

Every generated artifact, in both territories, is updated by verifying its claims and patching what
is wrong. Full regeneration happens only on `--fresh` or on a first run where there is nothing to
update.

This is not a preservation argument, so it applies just as much to files RepoSkills owns outright:

1. **Cost.** A re-run that regenerates everything pays full pipeline price to reproduce content that
   was already correct. Re-runs must be cheaper than first runs or they will not happen.
2. **Non-determinism.** An LLM rewriting a correct file from scratch can make it worse. Every
   regeneration of a correct file is an uncontrolled opportunity for regression.
3. **Reviewability.** Wholesale rewrites produce diffs nobody can review, so real changes hide
   inside churn.
4. **History.** A file rewritten differently on every run makes its git history noise rather than a
   record of what actually changed.

This is also what the pipeline already does, and the spec must not undo it:

- `SKILL.md` documents diff-based re-run as **the default** for repos with existing skills: detect
  what is there, diff against the stored commit hash, update only what changed.
- `--fresh` already exists as the explicit opt-in to ignore existing skills and regenerate.
- `--update <name>` already exists for regenerating a single named skill.
- `phase-drift-resolve.md` is 710 lines of exactly this: triage into confirmed drifts, false
  positives and unmapped directories; apply patches; then a three-stage accuracy verification.

Self-maintenance is the point of that machinery. Nothing in this spec replaces it.

#### Ownership answers what happens to the unverifiable

The territories differ in how aggressive a fix may be, not in whether the update is a patch.

| Territory | Owner | On a verified-wrong fact | On content that cannot be verified |
|---|---|---|---|
| `.ai/skills/**`, code-derived | RepoSkills | Fix it | **Remove it.** RepoSkills wrote it from code, so unverifiable means stale |
| `.ai/skills/**`, human-taught | The human who taught it | Fix only with evidence | **Keep it.** Flag, never remove |
| `<unit-root>/README.md` | The humans who own that unit | Fix it, citing `<file:line>` | **Flag it, never remove it.** A human may know something the code does not show |
| Root platform-glue files | Generated from a canonical source (6.3) | Regenerate below the split marker | Preamble above the marker is preserved verbatim |

**The human-taught carve-out is essential and an earlier draft omitted it.** `domain-context.md`
lives under `.ai/skills/` and is written from the Phase 1 interview: business domain, terminology,
regulatory context, architecture rationale. It is unverifiable from code **by definition**, which is
why the interview exists. A blanket "unverifiable means stale, remove it" rule pointed at
`.ai/skills/**` would delete the entire domain interview on the first re-run.

The same applies to normative content in the conventions document. `data-2`'s equivalent carries
rules like "never name an AWS profile or role", which is policy, not a code-derivable fact. Policy
statements are precisely what a remove-if-unverifiable rule destroys.

So the discriminator is **provenance, not location**: content derived from code may be removed when
it no longer verifies; content taught by a human may not.

`domain-context.md` is human-taught in its entirety, so it needs no internal marking; the file is
listed as human-taught and that is sufficient. `conventions.md` is mixed, carrying normative policy
alongside code-derived facts, so it needs per-section provenance. The marker rides in the existing
`<!-- repo-skills: ... -->` comment convention that generated files already carry, as a
`provenance=taught` attribute on a section comment, with absence meaning code-derived. Two
properties are required of it: drift patching must preserve the marker when it rewrites a section
body, and a human adding a section by hand must default to taught rather than derived, since an
unmarked human addition would otherwise be deletable on the next run. The default therefore inverts
inside `conventions.md`: unmarked means taught, and code-derived sections are the ones marked
explicitly by the generator.

**The per-unit README rules**, which apply only in the humans' territory:

- Start from the existing README. Only fix claims that are wrong.
- Never gut understanding. Stale or wrong information is worse than none, but so is deleting
  something correct that the pipeline merely could not verify.
- The Overview is human-authored on any README that already exists, and blank is a valid state.
- Cite `<file:line>` for every correction. Flag the unverifiable for a human rather than guessing.
- Make the smallest useful change, and make corrections silently. Never leave a meta-note about
  what the old README said, which reads as noise to the owner.

#### Consequence for drift

READMEs replace module skills, so they must inherit the self-maintenance module skills had. That is
two mechanisms at different price points, not one:

- **Cheap signal, every run:** presence and freshness per unit, as item 10 describes. Case-sensitive
  presence, and freshness measured by **last commit touching the README versus last commit touching
  filtered non-test code in its unit**. Not mtime: see item 10 in section 6.1.
- **Expensive repair, on demand:** `phase-drift-resolve` claim-verifies README content and patches
  it, exactly as it does for any other generated artifact.

Item 18's "presence plus freshness, not content-diff" describes the cheap signal only. Reading it as
the whole story would leave READMEs with weaker self-maintenance than the module skills they
replace, which would be a regression.

### 3.3 Precedence

Code > README > conventions document. Stated canonically in the conventions document and referenced
from the other two, never restated. A deviation documented in a README is intentional: do not
"fix" a unit to match the conventions document without first checking why it deviates.

### 3.4 Migration from an existing `modules/` tree

A repo generated by an earlier RepoSkills run carries `.ai/skills/modules/<name>.md`. Those files
may hold knowledge accumulated over several runs plus human edits, and that knowledge should not be
thrown away. But an ambitious harvest is the wrong shape, for three reasons an earlier draft missed:

1. **The mapping is not one-to-one.** `orchestration.md` permits Tier D module skills to span
   several projects, grouped by domain. One-to-many is therefore the common case, not the exception.
2. **The target has no matching structure.** Folding content "into the section it belongs to"
   assumes the destination README already has the grammar's sections. An existing human README will
   not, and restructuring it first contradicts "make the smallest useful change".
3. **There is no test bed.** `data-2` has no `modules/` left, so the harvest cannot be rehearsed
   anywhere before it runs on a repo that matters.

**So the harvest is deliberately narrow.** Take only the content that is genuinely irreplaceable
and has an unambiguous destination:

1. **Extract** gotchas and any human-added prose from each module skill. Everything else is
   code-derived and will be regenerated correctly from source, so it is dropped, not folded.
2. **Append** the extracted text to the target unit's README under `Agent Notes`, the one section
   that exists in every README and has no ordering constraints. Append, never restructure.
3. **Flag** every appended block for human review rather than presenting it as verified. It came
   from a document nobody has fact-checked.
4. **Report** everything not harvested: which module skill it came from, which units it mapped to,
   and why it was dropped.
5. **Delete** `modules/` only after the report is written and the appends are in place.

A module skill that maps to several units gets its gotchas appended to each, flagged, with the
duplication noted in the report. A module skill that maps to no current unit is reported and its
content left in the report for a human, never silently dropped.

**Do not reconcile module skills against the code during migration.** Harvesting and fact-checking
are separate concerns, and the normal validation phases run afterwards. Conflating them makes the
migration unbounded.

The pass is idempotent: once `modules/` is gone there is nothing to harvest and a re-run is a no-op.

### 3.5 Contract inventory: everything that touches `modules/`

The chapter an earlier draft was missing. `grep -ci "modules/\|module skill"` across the skill's
instruction files and templates returns **164 references in 11 contract files** (`orchestration.md`
22, `phase-2` 74, `phase-3` 31, `phase-4` 9, `phase-drift-resolve` 5, `phase-9` 3, `phase-6/7/8` and
`SKILL.md` 1 each, `templates/skill-drift.sh` 1). An earlier draft claimed 143 across 12 files
without stating the command, so the figure was unverifiable and wrong. Section 6.5 routed edits to phase files only and never named `orchestration.md`, which is
the file this change breaks most. Each row below is a contract that must be migrated, not discovered
during implementation.

#### `orchestration.md` (16 references, never previously named as a target)

| Contract | Line | Replacement |
|---|---|---|
| Phase 2 checklist step 2.3, "Generate module skills" | 58 | Generate unit READMEs |
| `_manifest.md` format, `## Module Skills` section, which phases 3 to 9 "expect this exact format" | 126, 147-149 | `## Unit READMEs`, rows keyed by unit root path |
| Per-module routing file row in the manifest example | 158 | Keyed by unit |
| Boundaries "not to directories" | 412 | Reword: not *arbitrary* directories. See section 3 |
| `conventions.md` prohibited as a standalone file | 414 | Amend to permit `conventions.md`. See 3.1 |
| Module Deletion Cascade, step 1 deletes the skill file | 592-594 | Unit deletion cascade. See below |
| Token budget, `modules/<name>.md` at ~1.5k each | 642 | README budget. See below |
| Split-a-large-module guidance | 659 | A README cannot be split. Overflow goes to a task skill |
| Simulation agents read ONLY `.ai/skills/` and glue, never source | 665 | Must widen to include unit READMEs. See below |
| Tier C coverage tiering by importance: 10 full, 15-20 summary, rest orientation-mention | 509-515 | Replaced by the signal gate in section 3, not simply deleted |
| Tier D grouping of services into one skill | ~528 | Removed. One README per confirmed boundary |
| Update Modes: targeted update "regenerate the skill file"; diff-update maps changes via `_boundaries.md` | 539-575 | Semantics change, not a rename. See 3.6 |
| Phase 5 scenario table: "Bug Fix in Core Module" tests "Module skill routing" | 673+ | Retarget to unit README routing |
| Parallelisation and model-selection rows keyed on module skills | various | Retarget to unit READMEs |

#### Other files

| Contract | Location | Replacement |
|---|---|---|
| Phase 3's core loop, "For each module skill in `.ai/skills/modules/`" | `phase-3-refine.md:83` | Iterate unit READMEs |
| "Re-read every module skill... confirm it answers all 14 questions" | `phase-3-refine.md:304` | Re-express the 14-question quality bar against the README grammar |
| Module Routing table in all four root files | `phase-2:587, 721, 877` | Rows point at `<unit-root>/README.md` |
| Per-module platform routing files embed module skill content verbatim | `phase-2:282, 920` | **Must stop embedding.** See below |
| Per-module routing file paths per platform | `phase-2:912-915` | Unchanged in shape, keyed on unit |
| Drift script skill-path regex | `templates/skill-drift.sh:132` | Extend to unit README paths |
| Drift script builds directory-to-skill map from the routing tables | `phase-2:960-965` | Mechanism unchanged, targets change |
| Remaining mechanical references | `phase-4` ×8, `phase-9` ×3, `phase-drift-resolve` ×3, `phase-6/7/8` ×1 each, `SKILL.md` ×1 | Retarget |

#### Three contracts that need a real decision, not a rename

**Per-module platform routing files must stop embedding content.** `phase-2:282` currently
instructs that a per-module routing file "include the content of BOTH coupled module skills so the
agent has everything when it enters either directory". Under README mode the source is
human-owned. Generating `.cursor/rules/<unit>.mdc` with a verbatim copy of a human-maintained README
creates a derived copy of human content that drifts the moment the README is edited, which is
exactly the failure section 6.3 exists to eliminate. These files must become **pointers**: a short
frontmatter-scoped stub naming the unit and linking its README. This costs the agent one file read
and removes an entire drift surface.

**One surface degrades and the tradeoff is accepted deliberately.** `phase-2:920`'s stated rationale
is to avoid cross-file references the platform cannot resolve. That still holds for GitHub Copilot
*completions*, which inject the instructions file without any ability to follow a link; a pointer is
inert there. Every agentic surface (Claude Code, Cursor, Codex, Copilot chat) resolves a pointer
fine. Embedding human-owned prose into generated files to serve one non-agentic surface would
reintroduce the drift this spec exists to remove, so the pointer wins and Copilot completions lose
per-unit depth while keeping the routing table in the root instructions file.

**Simulation access must widen.** `orchestration.md:665` restricts Phase 5 simulation agents to
`.ai/skills/` and the platform glue, explicitly excluding source code. READMEs live in the source
tree, so under the current contract phases 5, 7 and 8 can never see the primary output of this
design, and every simulation would report the knowledge as missing. The rule must be widened to
`.ai/skills/`, the glue files, and `<unit-root>/README.md` files, while still excluding general
source reading. That last part matters: the simulation is only meaningful if the agent is denied the
code, so the widening must be to READMEs specifically, not to the tree.

**READMEs need a token budget.** Module skills carried a ~1.5k budget enforced in three places
(`orchestration.md:642`, `phase-4` Check 11, `phase-6` Step 6.5). READMEs inherit the routing that
loads them on demand, so an unbounded README is a context cost the pipeline used to control and
would stop controlling. Proposal: the same ~1.5k ceiling applied to the agent-facing sections, with
the human-authored Overview excluded from the count, since it is not RepoSkills' to trim. Overflow
goes to a task skill rather than splitting the README, because a unit has exactly one README.

**Enforcement is generation-time only.** The pipeline cannot trim a human-owned README it is
forbidden to gut, so an existing README over budget is **flagged in the report, never truncated**.
The ceiling binds what RepoSkills writes; it does not license editing down what a human wrote.

#### The unit deletion cascade

`orchestration.md:592-594` deletes a module's skill file, its routing rows and its per-module
platform files when the module disappears. Under README mode one part gets easier and the rest does
not: **the README dies with its directory automatically**, so step 1 becomes a no-op. Routing rows,
per-module platform stubs, cross-references from other READMEs, and the manifest entry all still
need explicit removal. The cascade must be rewritten to reflect that asymmetry, not deleted.

---

### 3.6 The re-run surface: what each path may do, and on whose machine

Three problems that look separate and are one theme: what every re-run path is allowed to do in
human territory, and whether it works for anyone other than the person who ran it first. Together
they decide whether this is a tool one person operates or a tool a team shares.

#### MEMORY is a per-machine cache. The repo is the record.

`state.md` lives at `~/.claude/MEMORY/RepoSkills/<repo-slug>/state.md`, outside the repo, and today
it gates everything:

- Update-mode detection selects diff-based update only when it exists.
- `phase-drift-resolve.md:171` **aborts** without it: "No prior pipeline run found. Run the full
  RepoSkills pipeline first."
- `--update <name>` inherits the same precondition.

So anyone who clones a fully documented repo can run neither drift resolution nor a targeted update,
and a plain re-run treats the repo as a first run and regenerates from scratch. For a skill intended
to be shared this is a defect, not an inconvenience: the documentation travels with the repo while
the ability to maintain it does not.

The reconstruction is already latent in the design. Every generated file embeds `commit=HASH` in its
`<!-- repo-skills: ... -->` header, and diff-update already declares `_boundaries.md` regenerable
when missing.

**Rule.** When `state.md` is absent but `.ai/skills/` is present, reconstruct state rather than
aborting or restarting:

| State | Reconstructed from |
|---|---|
| Commit anchor | The newest `commit=HASH` across generated file headers |
| Boundaries | The routing tables plus `_manifest.md`, else re-run Phase 0 Step 4 |
| Tier and platforms | Phase 0's classification, which is cheap and deterministic |

Abort only when `.ai/skills/` is also absent, which genuinely is a first run.

Two consequences to write in alongside it: `_manifest.md` needs the same reconstruction fallback
`_boundaries.md` already has, and the 3.4 harvest report must be written into the repo rather than
only into MEMORY, because it is the record of what was dropped and it is worthless on one machine.

#### `--update` in human territory means verify-and-patch, never regenerate

The targeted-update path says "regenerate the skill file", and diff-update maps changed files to
module skills through `_boundaries.md`. For a README, "regenerate" is not the same operation under a
new name: it would overwrite a human-owned file, which 3.2 forbids.

**Rule.** Every re-run path, `--update` included, verifies and patches a README that exists. Only
`--fresh`, or a unit that has no README at all, produces one whole. `SKILL.md`'s documented
`--update <name>` contract must say so, since it currently promises regeneration.

#### RepoSkills never commits into unit directories

`phase-drift-resolve` step 9 commits what it patches. Correct for `.ai/skills/**`, wrong for a
README in someone else's directory, and it interacts badly with the freshness anchor this spec
adopted in item 10. Git-log freshness advances on commit, so a README that is patched but not
committed flags stale forever, while one that is auto-committed pushes unreviewed edits into a unit
its owners maintain. In a shared repo that is a social incident the first time it happens.

**Rule.** Drift resolution splits its output by territory:

- `.ai/skills/**` patches are committed, as today.
- README patches are left staged, or on a branch, and listed in the drift report as "patched,
  awaiting human commit".
- The freshness check treats a README with uncommitted local modifications as **repair-pending**
  rather than stale, which closes the loop without the tool taking commit authority in human
  territory.

This is also how the reference implementation works in practice: `update-readme` edits one project,
reports what it changed, and a human opens the pull request.

---

## 4. Unit boundary detection

Replaces item 1's directory-depth rule and item 18's "union nx roots with on-disk globs".

`phase-0-discover.md` Step 4 already does this well: per candidate directory, five signal types
(package, service, domain, deployment, logical), qualifying on one Strong or two Medium signals,
recorded with a confidence level. **That mechanism stays.** This section adds one input and one
warning; it does not replace Step 4.

**The addition: where a project system exists, ask it.** Phase 0 discovers and records in `state.md`:

- The **enumeration query**: the command that lists every project the repo recognises.
- The **detail query**: the command returning one project's root and available targets.
- The **deployability predicate**: what distinguishes a unit that ships from one that does not.
- Known **exclusions**: directories that look like units but are not wired in.

Where those exist, the enumeration query's output seeds boundary candidates at high confidence and
its answer is authoritative for package and service boundaries, replacing inference about manifests.
Where they do not exist, Step 4's signals are the whole answer and the repo still gets full
per-unit coverage. This is why there is no threshold: the project system improves detection where
present and is not required where absent.

**The warning: a query returning a plausible subset is the dangerous failure.** In `data-2` the
plausible-but-wrong test is `pnpm-workspace.yaml` membership, which silently excludes every Python
project. Generalised: when more than one candidate query exists, confirm which is authoritative
rather than taking the most visible, and record the counterexamples that distinguish them. Nothing
looks wrong when a subset is returned, which is what makes it worth an explicit rule.

**Excluded directories self-document.** A directory that looks like a unit but is deliberately
outside the project system gets a README saying so. This closes item 18's "scope reality" pitfall
without a whitelist to maintain.

---

## 5. The README grammar

RepoSkills does not ship a README template. It ships a **grammar** and a **generator**; the
concrete template is an artifact generated into the target repo during Phase 2, from what Phases 0
and 1 discovered. `data-2/docs/readme-template.md` is what correct output looks like for one
repo, not something to copy. Its companion conventions document is `docs/project-conventions.md`.

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

**These three sections are not in the reference implementation and must land separately.**
`data-2/docs/readme-template.md` contains none of them, and `data-2` main carries 197 READMEs written
without them. If the grammar ships with all three as expected sections, the stage-6 regression will
either flag every one of those 197 files as incomplete or try to add sections to human-maintained
documents at scale. So: **land the grammar matching the reference implementation first**, prove it,
then add these three as a later stage with its own baseline test. They are specified here because the
design calls for them, not because they belong in the first landing.

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
4. **Record.** The confirmed pattern goes into `.ai/skills/conventions.md`, **in the repo**.
5. **Apply.** Per-unit field values are computed from the confirmed pattern.

**Patterns are repo facts and must live in the repo, not in `state.md`.** An earlier draft stored
them in `state.md`, which lives under `~/.claude/MEMORY/` on a single machine. Anyone else cloning
the repo and re-running the pipeline, including anyone this skill is shared with, would get no
patterns and therefore either placeholders or a repeated interview. The conventions document is the
natural home: it is already the place repo-wide facts live, it is version-controlled, and it travels
with the repo.

**Confirmation needs a venue that actually runs.** Phase 1 is skipped when `domain-context.md` is
fresh, which is most re-runs. An earlier draft sent confirmation to the Phase 9 checkpoint instead,
claiming Phase 9 "runs on every pass". It does not: Phase 9 is itself skippable when
`_unresolved.md` is empty, the Reverse Glossary finds nothing and `_questions.md` has no open
questions. Worse, the drift-resolution and diff-update paths never reach Phase 9 at all, yet drift
resolution can create a new unit whose induced fields need confirming.

Three changes, so the venue exists on every path:

1. "Unconfirmed patterns exist" becomes a fourth condition that **blocks** the Phase 9 skip.
2. The drift-resolution and diff-update reports list unconfirmed patterns explicitly, so a path that
   never reaches Phase 9 still surfaces them.
3. Phase 1 stays the preferred venue when it runs, because a human is already answering questions.

The same three apply to the unit-confirmation list of section 3, which needs a venue for exactly the
same reason.

**An unconfirmed pattern produces a placeholder, never a guess.** This is what ties the placeholder
discipline to the induction loop, and it is why `_not yet linked_` is a first-class output rather
than a failure.

Once confirmed, a field that was non-deterministic becomes deterministic: the pattern is settled
once for the repo, and every per-unit value follows from it. Fields that resist induction, because
they genuinely vary per unit rather than following a pattern, must be resolved and verified per
unit or omitted. They must never be pattern-filled.

---

## 6. Backlog disposition

All 18 items. Target file paths verified to exist, and section anchors re-verified in full on
2026-09-02 after an earlier pass truncated its `grep` output and mis-numbered two Phase 4 checks.

### 6.1 Rewritten in the new vocabulary

| # | Item | Disposition |
|---|---|---|
| 1 | Every microservice Tier-1 regardless of depth | Resolved structurally by section 3's no-grouping rule: one README per confirmed boundary means depth and nesting cannot demote a service. Section 4 keeps `phase-0` Step 4 authoritative, with the project system as a high-confidence seed rather than the definition. |
| 10 | Drift script surfaces collisions, missing skills, stale dirs | Becomes README presence plus freshness, which is the **cheap signal only**, not the whole self-maintenance story (see 3.2, Consequence for drift). Presence must be checked **case-sensitively** via the version-control file list, because the local filesystem hides a miscased `readme.md` that breaks CI elsewhere. Freshness compares **the last commit touching the README against the last commit touching filtered non-test code in its unit**, never mtime: a fresh clone stamps every file at checkout time so everything reads fresh, and a rebase re-stamps everything stale. The filter also matters, or the signal fires on every commit to an active unit and stays permanently red. Content accuracy stays with `phase-drift-resolve`. |
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
| 4 | Encoding and format claims are a verification category | `phase-4-validate.md` | **New Check 13.** Checks 1 to 12 already exist; `Check 12: Domain context verification` is at line 296 |
| 5 | Prompt for adjacent repos by relationship type | `phase-0-discover.md` + `phase-1-domain-interview.md` | Boundary detection; Questionnaire |
| 6 | Language servers as a first-class tool | `phase-2-map-generate.md` | Orientation generation |
| 8 | Wire in surfaced tools proactively, do not just log | `phase-1-domain-interview.md` + `phase-9-human-checkpoint.md` | Provenance question; default to act |
| 9 | Drift detection advisory by default | `phase-9-human-checkpoint.md:36, :241` + `phase-2-map-generate.md` | CI and hook integration lives in phase 9; tool generation in phase 2. Not phase 6 |
| 12 | Threshold rules verified on both ends | `phase-4-validate.md` | **New Check 14** |
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

**H1. The installed RepoSkills is missing four files, including every template.** `install.sh`
symlinks per-file into `~/.claude/skills/`, and has not been re-run since 10 April 2026. Files
added after that date were never linked:

```
RepoSkills/phase-drift-resolve.md        added 2026-04-17 in a1aa12f
RepoSkills/templates/skill-drift.sh
RepoSkills/templates/skill-drift-hook.sh
RepoSkills/templates/skill-drift-ci.yml
```

This is not a deliberate hold. The consequence is material: `SKILL.md` documents all three
templates as inputs to generation and `phase-drift-resolve.md` as phase DR, so **items 7, 9 and 10,
the entire drift-tooling group, cannot work as documented** when the skill runs from
`~/.claude/skills/`. Any Phase 2 run that reaches template customisation fails on a missing file.

Two other packages drifted the same way: `CodeReview/Workflows/PlanAlignment.md` and
`llm-docs/phase-D-domain-interview.md`.

Fix is `./install.sh --force`. The deeper point belongs in the spec rather than the fix: RepoSkills
ships drift detection for the repos it documents while having no drift detection for its own
installation. A `--check` mode on `install.sh`, comparing `stow/` against `~/.claude/skills/`, is
the same generate-and-verify pattern this spec applies to platform-glue files in 6.3. Worth
adopting for consistency, and it would have caught this in April.

**H2.** `IMPROVEMENTS.md` was never committed to this repo and existed only in `~/.claude`. It was
destroyed on 2026-08-27 (see section 11). A partial reconstruction now sits at
`stow/RepoSkills/IMPROVEMENTS.md`, **deliberately untracked** at Electra's instruction pending a
decision on where it should live. It is therefore still unversioned, and still the single copy.

---

## 8. Sequencing

| Stage | Content | Rationale |
|---|---|---|
| 0 | ~~H1~~, **H2 gates everything** | H1 done. H2 open: the single surviving copy of `IMPROVEMENTS.md` is still untracked, and stage 1 modifies the very installer that destroyed the original. Get it committed somewhere first |
| 1 | `install.sh` hardening: `--check`, refuse to delete untracked files | Cheap, independent, prevents a recurrence. Plan already written |
| 2a | **Expand.** Generate unit READMEs *alongside* `modules/`. Retool drift, routing and the re-run paths (3.6) to recognise both shapes: the drift regex accepts either, routing rows may point at either | Every repo stays internally consistent at all times. Also manufactures the harvest test bed 3.4 says does not exist |
| 2b | **Contract.** Stop generating module skills, run the 3.4 harvest, remove the `modules/` contracts from 3.5 | The cutover, still atomic, but now half the review surface |
| 3 | Items 2, 4, 12 (phase-4 Checks 13 and 14), items 3, 5, 16 (phase-1 questions) | Additive. Checks 13 and 14 append after the existing 12, so nothing renumbers and no other file is touched |
| 4 | Items 6, 8, 17 | Independent of everything else |
| 5 | The three added README sections from 5.1, with their own baseline test | Deliberately after the grammar is proven |
| 6 | Regression run: first-run generation, then update-path against current `data-2` main | Needs everything above |

**Why 2a and 2b rather than one block, and why not four stages.** An earlier draft had the retooling
land two stages *after* the deletion, which left a window where a repo had module skills gone,
READMEs present, `skill-drift.sh` blind to them by regex, Phase 3 iterating an empty directory,
`phase-drift-resolve` still expecting `modules/`, the deletion cascade removing files that no longer
exist, and routing tables pointing at nothing. Correcting that produced a single atomic stage
covering most of a 5,400-line skill, which is right as a *release* boundary and unreviewable as a
unit of work.

Expand-then-contract keeps both properties. 2a adds the new shape without removing the old one, so
no repo is ever in a broken intermediate state and the change is releasable at the end of 2a. 2b
removes the old shape once the new one is proven. The cutover stays atomic; the review surface
halves. The side benefit is real: running 2a against a repo that still carries `modules/` gives 2b's
harvest the rehearsal bed section 3.4 correctly says is missing.

Stages 3 and 4 are genuinely independent of each other and can run in parallel once 2b lands.

**One gap the staging creates and must close in 2b.** The grammar landing in stage 2 matches the
reference implementation, which has no *Contracts owned* section, while module skills, which carried
the dependency and change-impact content, are deleted in 2b. *Contracts owned*, which section 6.1
says items 11 and 15 "become", does not arrive until stage 5. Between 2b and stage 5 the pipeline
would stop emitting its highest-value content with nowhere to put it. So 2b must state that
change-impact and dependency content goes into *Agent Notes* until *Contracts owned* lands, which is
where the reference implementation keeps it anyway. Without that line the stage-6 regression will
report a regression this spec caused.

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

**Regression target: current `data-2` main, not the June baseline.** Checked 2026-08-27.

`858ff1f6` is still reachable but is dated 2026-06-11 and sits **918 commits behind main**. The
branches the backlog names are similarly stale: `repo-skills` (2026-06-24, 788 behind) and
`repo-skills-to-readmes` (2026-06-25, 795 behind).

**Define the counting query before comparing counts.** `git ls-files | grep -c 'README.md$'` on main
returned 145 on 2026-08-27 and **197 on 2026-09-02**. The number moves weekly and counts every
README in the repo, including ones no unit owns. The meaningful count is READMEs at the roots of
confirmed units as section 3 defines them, which is not the same set. Any comparison against the
migration branches must use that query on both sides or it is measuring noise.

More usefully, **the migration is already merged into main by some route other than those branches**
(`repo-skills-to-readmes` is not an ancestor of HEAD, yet main carries 145 READMEs and has no
`.ai/skills/modules/`). Main is therefore the live, merged, still-maintained expression of this
design, and the branches are historical snapshots of how it got there.

Use current main as the reference and the regression target. Preserved pipeline state remains at
`~/.claude/MEMORY/RepoSkills/data-2/state.md`, but note it describes the June run, not main.

The gap between main and `repo-skills-to-readmes` is worth a look before the regression run, using
the query defined above: it may be the deliberate scope decision item 18 records under "scope
reality", or it may be READMEs that were dropped on the way to main.

**The regression needs a first-run target, not only an update target.** Regressing against
already-migrated `data-2` main exercises the update path exclusively. It never tests generating
READMEs from scratch, never tests a repo with no project system, and never tests the migration
harvest, because `data-2` has no `modules/` left. Three targets are needed: a repo with no existing
skills (first-run generation), a single-project repo with logical boundaries only (the case section 3
was getting wrong), and a repo still carrying a `modules/` tree (the harvest). None is named yet, and
naming them is a prerequisite for stage 6 rather than part of it.

**Token budget.** Six items target `phase-2-map-generate.md`, already 1199 lines and the largest
file in the skill. Growing it risks causing the context failure these changes exist to prevent.
The README grammar (section 5) should therefore land as its own instruction file rather than as an
extension of phase 2, with phase 2 referencing it. `phase-6-self-resolve.md` already has a
`Step 5: Check Token Budgets (Step 6.5)` that should be extended to cover the skill's own files,
not only generated output.

---

## 10. Open questions

All four resolved on 2026-08-27. Kept here as a record of what was decided and why.

1. ~~H1: is the missing `phase-drift-resolve.md` symlink a bug or a deliberate hold?~~
   **Stale install**, not a hold. `install.sh` had not been re-run since 10 April and four files
   added after that date were never linked, including all three templates. Fixed and verified.
   See section 7.

2. ~~Is `data-2@858ff1f6` still reachable and still a meaningful baseline?~~
   **Reachable but 918 commits stale.** The migration is already merged into main by a route other
   than the named branches, so current main is the live expression of this design and the
   regression target. See section 9.

3. ~~Should the conventions document be generated or human-authored?~~
   **Generated by RepoSkills**, at `.ai/skills/conventions.md`, which requires amending
   `orchestration.md:414` (see 3.1). Two later corrections narrow this answer: ownership does not
   license wholesale regeneration, because re-runs verify and patch in both territories; and
   "owned by RepoSkills" does not mean "contains no human knowledge". The conventions document is
   mixed, carrying normative policy a human wrote alongside code-derived facts, so its human-taught
   sections are marked and never removed. See 3.2.

4. ~~What is the migration path for repos already carrying a `modules/` tree?~~
   **Harvest into READMEs, then delete.** See section 3.4.

---

## 11. Review history

**Independent review, 2026-09-02 (Fable).** The spec was reviewed against the skill source and the
reference repo by an independent agent with a brief to find problems. Verdict: do not execute as
written, restructure first. Every finding below was verified against the files before being acted on.

Acted on in this revision:

| Finding | Resolution |
|---|---|
| Single-project repos lost per-unit knowledge entirely: no READMEs above a threshold, no module skills below it | Threshold removed. Grammar applies to every `phase-0` Step 4 boundary, including logical ones. Sections 3 and 4 |
| `orchestration.md`, the most-broken file, was never named as a target | Section 3.5, the contract inventory |
| `orchestration.md:414` prohibits generating `conventions.md`, which leg 1 requires | Named in 3.1 as an amendment the change depends on |
| Non-goal "no changes to phases 3, 7, 8" is unachievable | Withdrawn in 1.1, with the reasons |
| Phase 4 already has Checks 1 to 12; the spec added colliding "Check 10" and "Check 11" | Renumbered to 13 and 14. The original anchor claim was false and is now corrected |
| Simulation agents are forbidden from reading outside `.ai/skills/`, so could never see a README | Named in 3.5 as a contract that must widen, to READMEs specifically and not to the source tree |
| Per-module platform routing files embed skill content verbatim, which would copy human-owned prose into generated files | 3.5: they become pointers, removing a drift surface |
| `.ai/skills/**` "remove if unverifiable" would delete `domain-context.md`, which is unverifiable by design | 3.2: the discriminator is provenance, not location. Human-taught content is never removed |
| READMEs had no token budget where module skills had one enforced in three places | 3.5: ~1.5k on agent-facing sections, Overview excluded |
| Item 10 specified mtime freshness | Corrected to git-log freshness with a filter |
| Item 9 was routed to phase 6, where the anchor does not exist | Corrected to phase 9 plus phase 2 |
| Pattern storage in `state.md` is single-machine, so anyone the skill is shared with gets nothing | 5.3: patterns live in `conventions.md`, in the repo |
| Pattern confirmation had no venue on re-runs, when Phase 1 is skipped | 5.3: Phase 9 checkpoint as the always-available venue |
| The migration harvest assumed one-to-one mapping, a structured target, and had no test bed | 3.4 narrowed to gotchas appended to Agent Notes, flagged, with everything else reported |
| Stages were claimed independently stoppable; deleting `modules/` two stages before retooling drift leaves the tool broken | Section 8: stage 2 is one atomic block |
| Three invented sections would flag all 197 existing `data-2` READMEs as incomplete | 5.1: deferred to their own stage with a baseline test |
| README counts stale and the counting query undefined | Section 9: query defined, both figures recorded |
| No first-run, no-project-system, or harvest test target | Section 9: three targets named as a stage 6 prerequisite |

**Second pass, 2026-09-02.** Same reviewer, re-reading the restructured spec with a brief to audit
the fixes and find what the restructure broke. Verdict moved from "do not execute" to **execute with
named changes**, with 16 of the 18 first-pass findings confirmed genuinely fixed in the text. Its new
findings, all verified before being acted on:

| Finding | Resolution |
|---|---|
| "Every unit gets a README, always" collides with Tier C coverage tiering, and a Medium-only boundary may be a directory nobody owns, so a README there recreates the unowned artifact this spec removes | Section 3 now gates on signal strength and on whether a README already exists. Owner's decision |
| Existing READMEs are the common case, which the gate ignored | Section 3: an existing README is the strongest ownership signal there is, so updating is ungated and only *creating* a new file is gated. Owner's observation |
| Nested units unhandled: ambiguous ownership, and the parent's freshness signal fires on every child commit | Section 3: three rules, including subtracting nested unit paths from freshness |
| "No grouping, always" reads as forbidding phase-2's legitimate merge-with-parent verdict | Section 3 distinguishes merging from grouping |
| `state.md` lives outside the repo and `phase-drift-resolve.md:171` aborts without it, so nobody who clones the repo can run drift resolution or `--update` | Section 3.6: MEMORY is a per-machine cache, the repo is the record. State reconstructs from file headers, routing tables and the manifest |
| `--update` promises to "regenerate the skill file", which would overwrite human-owned content | Section 3.6: every re-run path verifies and patches. Only `--fresh` or an absent README generates whole |
| Drift resolution's commit step: committing pushes unreviewed edits into human directories, not committing leaves the git-log freshness anchor stuck stale forever | Section 3.6: output splits by territory, README patches left staged and reported, freshness treats locally-modified as repair-pending |
| Atomic stage 2 was right as a release boundary and unreviewable as a unit of work | Section 8 split into 2a expand and 2b contract, which also manufactures the harvest test bed |
| Change-impact content homeless between 2b and stage 5 | Section 8: 2b routes it to Agent Notes until *Contracts owned* lands |
| Phase 9 is not a reliable confirmation venue: it is skippable, and drift and diff-update never reach it | Section 5.3: unconfirmed patterns block the Phase 9 skip, and the drift and diff reports surface them |
| Update Modes, the Phase 5 scenario table and the parallelisation rows were missing from the inventory | Added to 3.5 |
| Reference count of 143 was wrong and the command unstated | 3.5 states the grep and the real figure, 164 across 11 files |
| `orchestration.md:497-520` cited for Tier D grouping; that range is Tier C tiering | Corrected to 509-515 and ~528, as separate rows |
| README token budget had no defined action for an over-budget human README | 3.5: flagged, never truncated. Generation-time enforcement only |
| Per-section provenance marking for `conventions.md` was a new mechanism with no format | 3.2: marker format, and the default inverts to taught inside that file |
| Routing pointers silently reverse `phase-2:920`'s rationale, degrading Copilot completions | 3.5: tradeoff stated and accepted |
| Fossils: item 1's disposition, "stage-7", stage 3's renumbering note, the counting query, the destroyed `~/.claude` path, unconditional template and `navigate-unit` rows | All swept |

Remaining first-pass item, now closed: the drift-resolution commit question is answered in 3.6
rather than left as a note.

---

## 12. Provenance note

`IMPROVEMENTS.md`, the source of the 18 items, was destroyed on 2026-08-27 by
`install.sh --force`, which does `rm -rf` on the skill directory with no backup. It had never been
committed. A partial reconstruction sits at `stow/RepoSkills/IMPROVEMENTS.md`, deliberately left
untracked pending Electra's decision on where it belongs: the
introduction, items 1 to 4, all 18 headings, the full implementer notes and item 18 survive; the
bodies of items 5 to 17 do not.

This spec was written from the complete file and is therefore the most complete surviving statement
of what the backlog asked for.

The incident is itself an argument for section 7's recommendation: an installer that ships drift
detection for other repos while having none for its own installation, and that will `rm -rf`
untracked files without warning, is a tool that has not taken its own advice.
