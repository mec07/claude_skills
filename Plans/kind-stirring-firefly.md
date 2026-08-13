# Plan: Skill Drift Resolution Subskill for RepoSkills

## Context

RepoSkills has comprehensive drift **detection** (bash script + CI workflow + git hook) but no prescribed **resolution** workflow. When an agent sees "potential skill drift detected," it has no instructions for triaging whether drift actually occurred, surgically updating the affected skill, validating the update, or re-anchoring. This plan designs and implements the resolution companion.

Drift resolution is fundamentally a **scoped validation pass with a patch step**. It reuses Phase 4's validation checks (scoped to changed files only) and Phase 6's surgical fix patterns (scoped to stale claims only). The key differentiator from `--update <module>` is that it repairs rather than regenerates.

## Files to Create

### 1. `stow/RepoSkills/phase-drift-resolve.md` (NEW)

The complete phase instruction file. Follows the exact structural pattern of existing phase files:

**Structure:**
1. Title: "Drift Resolution -- Repair Skills Flagged by Drift Detection"
2. Role: "You are a **maintenance agent, not a generator.** Your job is to repair skill files that have drifted from the codebase, not to regenerate or restructure them."
3. Checklist (DR.0-DR.10) in code block for state.md:
   ```
   DR.0:  Pre-check (state.md exists, skills exist, skill-drift.sh exists)
   DR.1:  Run drift detection (skill-drift.sh --json), parse output
   DR.2:  Triage each drift signal (confirmed / false-positive / cosmetic)
   DR.3:  Early exit check (if zero confirmed drifts and zero unmapped dirs, stop)
   DR.4:  Analysis (per confirmed drift, map code changes to stale skill sections)
   DR.5:  Patch (surgically edit stale sections with verified current truth)
   DR.6:  Cross-reference check (propagate relationship changes to related skills)
   DR.7:  Routing table update (handle unmapped dirs, new routing entries)
   DR.8:  Scoped validation (Phase 4 checks 1, 3, 9, 10, 11 on modified skills only)
   DR.9:  Write _drift_report.md summary, update _manifest.md dispositions
   DR.10: Update state.md with drift resolution record and new commit hash
   ```
4. Inputs/Outputs table (same format as other phases)
5. "Updating state" section (same boilerplate)
6. Working file specification: `_drift_report.md` format with sections for Run Metadata, Triage Results, Patches Applied, Cross-Reference Updates, Routing Table Updates, Scoped Validation Results, Summary
7. Detailed step-by-step instructions for DR.0 through DR.10

**Triage classification logic (DR.2):**
- Extract filtered git diff (`anchor..HEAD` for each drift signal's directories, excluding tests/docs)
- Classify each changed file:
  - STRUCTURAL (new/deleted/renamed files, changed exports) -> CONFIRMED
  - INTERFACE (changed signatures, new/removed public APIs) -> CONFIRMED
  - INTERNAL (implementation-only changes) -> FALSE POSITIVE
  - COSMETIC (formatting, comments) -> FALSE POSITIVE
  - "not_mentioned" directories -> always CONFIRMED (coverage gap)
  - "unmapped" directories -> flagged for routing update, not patching
- Decision matrix table
- Confidence annotation (high/medium/low based on change count)

**Analysis step (DR.4):**
- Read current skill file, parse sections
- Map each code change type to potentially affected skill sections (table provided):
  - New file -> Key files, Extension seams, Change impact
  - Deleted file -> Key files, Relationships, Change impact
  - Changed signature -> Relationships, Change impact, Gotchas
  - New dependency (import) -> Relationships "depends on"
  - not_mentioned dir -> Purpose, Key files, Relationships

**Patch step (DR.5):**
- Read source code for current truth (not just diff)
- Surgically edit only stale sections using Edit tool
- Preservation rule: do not touch non-stale content
- Verify each edit against source code
- Log every patch in _drift_report.md

**Cross-reference protocol (DR.6):**
- After patching, check all other skill files that reference the patched module
- Enforce symmetry: if A depends on B, B lists A as dependent
- Scope limited to direct references only (no recursive propagation)

**Scoped validation (DR.8):**
- Check 1: File path verification (modified skills only)
- Check 3: Architectural claim verification (modified sections only)
- Check 9: 5-second grep test (modified skills only)
- Check 10: Cross-skill consistency (modified skills + direct neighbours)
- Check 11: Token budget enforcement (modified skills only)

**Parallelisation strategy:**
- 1-3 drifted skills: sequential
- 4+ drifted skills: one sonnet subagent per skill for DR.4+DR.5
- Cross-reference check (DR.6), routing update (DR.7), and validation (DR.8) run post-merge by orchestrating agent
- Subagent output: `_drift_patch_<skill-name>.md` (merged, then deleted)
- Failure recovery: re-dispatch once, then sequential fallback

**Rules section:**
- Repair, do not regenerate
- Same evidence standards as Phase 4
- Preserve human refinements
- Do not introduce new content beyond drift scope
- Cross-references mandatory for relationship changes
- 5-second grep test applies to patches
- Token budgets apply to patches
- Anchor advancement is automatic via git commit
- Do not run full simulations
- Log everything to _drift_report.md

## Files to Modify

### 2. `stow/RepoSkills/SKILL.md`

**Invocation section** -- add after the existing `--update` entry:
```
**Drift resolution (repair skills flagged by drift detection):**
> Run RepoSkills --drift
> Run RepoSkills --resolve-drift

**Drift check only (report, no resolution):**
> Run RepoSkills --drift-check
```

**Phase Instruction Files table** -- add row:
```
| DR | `phase-drift-resolve.md` |
```

### 3. `stow/RepoSkills/orchestration.md`

Three additions:

**a) "Working files in MEMORY" table** -- add row:
```
| `_drift_report.md` | DR.1-DR.9 | Drift resolution only | Overwritten on next run (audit trail) | Triage decisions, patches, validation results |
```

**b) "Update Modes" section** -- add new subsection after "Diff-based update":
```
### Drift resolution (`--drift` or `--resolve-drift`)

Targeted repair of skills flagged by drift detection:

1. Read state.md — verify a prior pipeline run exists
2. Run skill-drift.sh --json to get current drift signals
3. Triage each signal (confirmed vs false-positive via git diff analysis)
4. For confirmed drifts: analyze code changes, surgically patch stale sections
5. Cross-reference check: propagate relationship changes to related skills
6. Update routing tables if new directories appeared
7. Run scoped validation (Phase 4 checks 1, 3, 9, 10, 11 on modified skills only)
8. Commit updated skill files (advances anchors automatically)
9. Update state.md commit hash and drift resolution history

Expected time: 3-10 minutes depending on number of drifted skills.
Prerequisite: At least one completed pipeline run (state.md must exist).
```

**c) "Detecting update mode" sequence** -- insert before item 4:
```
3a. Check if `--drift` or `--resolve-drift` flag is present -> Drift resolution
3b. Check if `--drift-check` flag is present -> Drift check (report only, no resolution)
```

**d) "Phase instructions" table** -- add row:
```
| DR | `phase-drift-resolve.md` | `state.md`, `_boundaries.md`, `_manifest.md`, drift JSON, codebase | Updated skills, `MEMORY: _drift_report.md` |
```

## Verification

After implementation:
1. Read `phase-drift-resolve.md` and verify it follows the same structural pattern as `phase-4-validate.md` and `phase-6-self-resolve.md` (checklist, I/O table, updating state section, detailed steps, rules)
2. Verify `SKILL.md` invocation section includes drift resolution syntax
3. Verify `orchestration.md` has the new update mode subsection, working file entry, detection logic entry, and phase table entry
4. Verify the checklist has exactly 11 items (DR.0 through DR.10) and each ends with "Update state.md"
5. Verify the triage classification includes the decision matrix table
6. Verify the _drift_report.md format specification includes all sections (Run Metadata, Triage Results, Patches Applied, Cross-Reference Updates, Routing Table Updates, Scoped Validation Results, Summary)
7. Verify the parallelisation section specifies threshold (4+), model selection (sonnet), merge protocol, and failure handling
8. Verify the rules section covers: no regeneration, evidence standards, preserve human refinements, cross-references mandatory, 5-second grep test, token budgets, anchor advancement, no full simulations
9. Verify no content in the instruction file fails the 5-second grep test (no file listings, no schema copies)
10. Run `wc -w` on the new file to ensure it's comprehensive but not bloated (target: 4000-7000 words, matching the length of phase-4-validate.md and phase-6-self-resolve.md)
