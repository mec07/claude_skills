# Drift Resolution -- Repair Skills Flagged by Drift Detection

You are a **maintenance agent.** Your primary job is to repair skill files that have drifted from the codebase. For existing skills, you surgically patch stale claims with verified current truth. For unmapped directories that represent genuinely new modules, you may create new skill files. In both cases, **accuracy is paramount.** Every claim you write or edit must be verified against actual source code through a multi-stage accuracy pipeline.

**If an existing skill needs full regeneration rather than repair, this is not the right workflow.** Use `--update <module>` instead. Drift resolution repairs existing skills and fills coverage gaps. It does not restructure or regenerate.

---

## Checklist

Copy this checklist into `state.md` under a `## Drift Resolution` entry. Mark each item `[x]` immediately upon completion.

```
- [ ] DR.0: Pre-check — read state.md, verify skills and skill-drift.sh exist
- [ ] DR.1: Run drift detection — execute skill-drift.sh --json, parse output
- [ ] DR.2: Triage — classify each drift signal (confirmed / false-positive)
- [ ] DR.3: Early exit check — if zero confirmed drifts and zero unmapped dirs, report and stop
- [ ] DR.4: Analysis — per confirmed drift, map code changes to stale skill sections
- [ ] DR.5: Patch — surgically edit stale sections with verified current truth
- [ ] DR.6: New skill creation — generate skills for unmapped directories that qualify as modules
- [ ] DR.7: Cross-reference check — propagate relationship changes to related skills
- [ ] DR.8: Routing table update — update routing entries in all platform glue files
- [ ] DR.9: Accuracy verification — three-stage accuracy pipeline on all modified and new skills
- [ ] DR.10: Write _drift_report.md summary, update _manifest.md dispositions
- [ ] DR.11: Update state.md — record drift resolution with timestamp and new commit hash
```

---

## Inputs and Outputs

| Direction | File | Location | Description |
|---|---|---|---|
| **Input** | `state.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Repo path, slug, stored commit hash, tier |
| **Input** | `_boundaries.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Confirmed module boundary map |
| **Input** | `_manifest.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Skill file disposition tracking |
| **Input** | All skill files | Target repo: `.ai/skills/` | Skills to assess and patch |
| **Input** | Platform glue files | Target repo root | `CLAUDE.md`, `AGENTS.md`, `.cursorrules`, `.github/copilot-instructions.md` |
| **Input** | `skill-drift.sh --json` | Target repo (executed) | Drift signals and unmapped directories |
| **Input** | Codebase + git history | Target repo on disk | Source of truth for all verification |
| **Output** | Updated skill files | Target repo: `.ai/skills/` | Surgically patched skills |
| **Output** | Updated platform glue | Target repo root | Updated routing tables (if routing changed) |
| **Output** | `_drift_report.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Audit trail: triage, patches, validation |
| **Output** | `_manifest.md` (updated) | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Dispositions updated for repaired skills |
| **Output** | `state.md` (updated) | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Drift resolution recorded, commit hash advanced |

---

## Updating state

After completing **each numbered step** below, immediately update `state.md`:

1. Mark the step's checkbox `[x]` in the Drift Resolution checklist
2. Update the `updated:` timestamp

Do not batch state updates. If context is lost between steps, the recovery protocol relies on `state.md` being current. A completed step with no state update will be repeated on resume.

---

## Working file: `_drift_report.md`

Create `~/.claude/MEMORY/RepoSkills/<repo-slug>/_drift_report.md` at the start of DR.1. This is your audit trail. Write to it as you go. Do not rely on memory.

This file is **not cleaned up** after drift resolution. It persists as an audit trail and is overwritten on the next drift resolution run.

Format:

```markdown
# Drift Resolution Report

## Run Metadata
- Date: [ISO timestamp]
- Repo: [path]
- Anchor source: skill-drift.sh --json
- Total drift signals: N
- Confirmed drifts: N
- False positives: N
- Unmapped directories: N

## Triage Results

### Confirmed Drifts

#### [skill file path] -- [confidence: high/medium/low]
- **Anchor date:** [date]
- **Commits since anchor:** N
- **Directories with changes:** [dir(count), dir(count)]
- **Classification:** [structural/interface/coverage-gap]
- **Changed files (filtered):**
  - [file] -- [structural: new file | interface: signature change | ...]
- **not_mentioned dirs:** [dirs or "none"]

### False Positives

| Skill | Reason | Changed files (internal/cosmetic only) |
|---|---|---|
| [path] | All changes internal | [brief summary] |

### Unmapped Directories

| Directory | Action |
|---|---|
| [dir] | [flagged for new skill | added to existing routing | deferred] |

## Patches Applied

### [skill file path]

#### Section: [section name]
- **Stale claim:** [what the skill said]
- **Current truth:** [what the code shows]
- **Evidence:** [source file path and line/function]
- **Action:** [replaced | removed | added | updated]

## New Skills Created

### [skill file path]
- **Module:** [name]
- **Directory:** [path]
- **Purpose:** [1-2 sentences]
- **Boundary qualification:** [which signals qualified it]
- **Source files read:** N
- **Claims written:** N

## Cross-Reference Updates

### [skill file path] (updated due to changes in [other skill])
- **Change:** [what was updated and why]
- **Evidence:** [source]

## Routing Table Updates

| Platform file | Change | Reason |
|---|---|---|
| [file] | [Added/updated routing for dir] | [reason] |

## Accuracy Verification

### Stage 1: Claim Verification
| Skill | Claims checked | Verified | Unverifiable | Removed |
|---|---|---|---|---|
| [path] | N | N | N | N |

### Stage 2: Structural Integrity
| Check | Files checked | Issues found | Issues fixed |
|---|---|---|---|
| File paths (Check 1) | N | N | N |
| Architectural claims (Check 3) | N | N | N |
| 5-second grep test (Check 9) | N | N | N |
| Token budgets (Check 11) | N | N | N |
| Cross-skill consistency (Check 10) | N | N | N |

### Stage 3: Relationship Symmetry
| Skill | Relationships checked | Verified | Removed (no evidence) |
|---|---|---|---|
| [path] | N | N | N |

## Summary
- Skills patched: N
- New skills created: N
- Sections updated: N
- Cross-reference fixes: N
- Routing table entries added/updated: N
- Accuracy: claims verified / claims removed
- Relationship claims verified / removed
- False positives filtered: N
```

---

## Step 0: Pre-check (DR.0)

Verify prerequisites before running drift detection:

1. **Read `state.md`** from `~/.claude/MEMORY/RepoSkills/<repo-slug>/`. If it does not exist, abort with: "No prior pipeline run found. Run the full RepoSkills pipeline first."
2. **Verify skill files exist** in the target repo under `.ai/skills/`. If the directory is empty or missing, abort.
3. **Verify `skill-drift.sh` exists** at `.ai/skills/Tools/skill-drift.sh` in the target repo. If missing, abort with: "Drift detection script not found. Run the full RepoSkills pipeline to generate it."
4. **Record the current HEAD commit** for later use: `git rev-parse HEAD`

Update `state.md`: mark step DR.0 complete.

---

## Step 1: Run Drift Detection (DR.1)

Execute the drift detection script in JSON mode:

```bash
cd <repo-root>
bash .ai/skills/Tools/skill-drift.sh --json
```

If the script exits 0 with `{"drifts":[],"unmapped":[]}`, no drift detected. Proceed to DR.3 (early exit).

Parse the JSON output. Create `_drift_report.md` with the Run Metadata section.

**JSON output format:**
```json
{
  "drifts": [
    {
      "skill": ".ai/skills/modules/auth.md",
      "anchor_date": "2026-03-15",
      "commit_count": 12,
      "dirs": "pkg/auth(5), pkg/middleware(3)",
      "not_mentioned": "pkg/middleware",
      "first_file": "pkg/auth/jwt.go"
    }
  ],
  "unmapped": ["pkg/newmodule"]
}
```

Update `state.md`: mark step DR.1 complete.

---

## Step 2: Triage (DR.2)

For each entry in the `drifts` array, determine whether drift is confirmed or a false positive.

### 2a. Extract the filtered diff

For each drift signal, get the anchor commit and the diff:

```bash
# Anchor = last commit that modified the skill file
anchor=$(git log -1 --format=%H -- "<skill-file-path>")

# Diff for the signal's directories, excluding tests and docs
git diff --name-status "$anchor"..HEAD -- <dir1>/ <dir2>/
```

Filter out test files using the same patterns as `skill-drift.sh`: files matching `*_test.go`, `test_*.py`, `*.test.ts`, `*.spec.ts`, etc., and files under `testdata/`, `__tests__/`, `tests/`, `test/` directories. Also filter out `*.md` files.

### 2b. Classify each changed file

For every file remaining after filtering, classify the change by reading the diff and the file:

**STRUCTURAL changes (always CONFIRMED):**
- `A` (added): new source file appeared in the module
- `D` (deleted): source file was removed
- `R` (renamed): file was moved or renamed
- Changed exports/public API surface (new or removed `export`, `pub`, `public`, `func` declarations at module boundaries)

**INTERFACE changes (always CONFIRMED):**
- Changed function/method signatures (parameters, return types)
- New or removed public functions/methods/types
- Changed struct/class field definitions that are exported
- Changed configuration schemas or environment variable usage
- Changed error types or error handling contracts

**INTERNAL changes (FALSE POSITIVE):**
- Implementation changes within function bodies that do not alter the function signature
- Algorithm changes that do not affect callers
- Performance optimizations with no API change
- Private/unexported function changes

**COSMETIC changes (FALSE POSITIVE):**
- Formatting-only changes (whitespace, line wrapping)
- Comment changes (unless they document a public API change)
- Import reordering without adding/removing imports

### 2c. Handle special cases

- **"not_mentioned" directories** from the drift JSON: always **CONFIRMED** regardless of change type. The skill has a coverage gap.
- **"unmapped" directories** from the `unmapped` array: flag for routing table update in DR.7. These do not trigger skill patching.

### 2d. Decision matrix

| Signal | Structural changes? | Interface changes? | not_mentioned? | Verdict |
|---|---|---|---|---|
| Drift entry | Yes (any) | any | any | **CONFIRMED** |
| Drift entry | No | Yes (any) | any | **CONFIRMED** |
| Drift entry | No | No | Yes | **CONFIRMED** (coverage gap) |
| Drift entry | No | No | No | **FALSE POSITIVE** |
| Unmapped dir | n/a | n/a | n/a | **ROUTE** (not drift, coverage gap) |

### 2e. Confidence annotation

For each confirmed drift, assign a confidence level for prioritisation:

- **High**: 5+ structural/interface changes, OR `not_mentioned` directory present
- **Medium**: 2-4 structural/interface changes
- **Low**: 1 structural/interface change

Resolve high-confidence drifts first.

### 2f. Write triage results

Write the Triage Results section of `_drift_report.md` with all confirmed drifts, false positives, and unmapped directories.

Update `state.md`: mark step DR.2 complete.

---

## Step 3: Early Exit Check (DR.3)

If the triage produced:
- Zero confirmed drifts, AND
- Zero unmapped directories

Then report to the orchestrator: "All drift signals are false positives. No skill updates needed." Update `_drift_report.md` summary and exit.

If there are confirmed drifts or unmapped directories, proceed to DR.4.

Update `state.md`: mark step DR.3 complete.

---

## Step 4: Analysis (DR.4)

For each confirmed drift signal, ordered by confidence (high first):

### 4a. Read the current skill file

Read the skill file in full. Identify its sections:
- Purpose / Role description
- Key files / Entry point
- Relationships (depends on, depended on by, communicates with)
- Commands / Testing
- Gotchas
- Change impact checklist
- Extension seams

### 4b. Read the changed files

For each changed file in the confirmed diff, read the file's current state (not just the diff). Understand what actually changed at the semantic level.

### 4c. Map changes to skill sections

Use this mapping to identify which skill sections are potentially stale:

| Code change type | Potentially affected skill sections |
|---|---|
| New file added | Key files, Extension seams, Change impact |
| File deleted | Key files, Relationships, Change impact |
| File renamed | Key files (path references) |
| New public function/type | Extension seams, Purpose (if scope expanded) |
| Removed public function/type | Relationships (dependents may break), Change impact, Gotchas |
| Changed function signature | Relationships (callers affected), Change impact, Gotchas |
| New dependency (import added) | Relationships ("depends on") |
| Removed dependency (import removed) | Relationships ("depends on") |
| New external communication | Relationships ("communicates with") |
| Changed test patterns | Commands/Testing section |
| New config/env usage | Gotchas, Commands |
| not_mentioned directory | Purpose (scope expanded), Key files, Relationships |

### 4d. Identify specific stale claims

For each potentially affected section, compare the skill's current claims against the code's current state. Build a list of:

```
{ section_name, stale_claim, evidence_from_code, proposed_action }
```

If a section's claims are still accurate despite the code changes, mark it as "verified, no update needed."

Write findings to `_drift_report.md` as you go.

Update `state.md`: mark step DR.4 complete.

---

## Step 5: Patch (DR.5)

For each stale claim identified in DR.4:

### 5a. Verify the current truth

Read the source code file that provides the correct information. Do not guess from the diff alone. Open the file, read the relevant functions/types/imports.

### 5b. Surgically edit the skill file

Edit **only** the stale section. Rules:

- If a claim is wrong, replace it with the verified truth
- If a section is missing coverage (not_mentioned directory), add the minimum necessary content
- If a file path is stale, update or remove it
- If a relationship changed, update the current skill's side. Save the related skill's side for DR.6
- **Preserve everything that is not identified as stale.** If a Gotchas section has 5 items and only 1 is stale, edit only that 1 item

### 5c. Verify each edit

After each edit, re-read the modified section and check:
- Does the new claim match what the source code actually shows?
- Is the new claim consistent with the rest of the skill file?
- Does it pass the 5-second grep test? (If the claim can be found via a single grep in under 5 seconds, it should not be in the skill)

### 5d. Log the patch

Write each patch to `_drift_report.md`:

```markdown
#### Section: [section name]
- **Stale claim:** [what the skill said]
- **Current truth:** [what the code shows]
- **Evidence:** [source file path and line/function]
- **Action:** [replaced | removed | added | updated]
```

Update `state.md`: mark step DR.5 complete.

---

## Step 6: New Skill Creation (DR.6)

For each directory in the `unmapped` array from the drift JSON, determine whether it warrants a new skill file.

### 6a. Boundary qualification

Read the unmapped directory's contents. Apply the same boundary detection signals used in Phase 0:

1. Does the directory contain 3+ source files?
2. Does it have a clear entry point (index file, main module, package definition)?
3. Is it imported by other modules? (grep for imports of this directory across the codebase)
4. Does it have distinct responsibilities separate from existing modules?

If the directory does not qualify as a module boundary, log it in `_drift_report.md` as: "Directory does not qualify as module boundary. No new skill needed." Consider whether it should be absorbed into an existing module's routing instead.

### 6b. Explore the module

For directories that qualify:

1. **Read every source file** in the directory (apply the large file strategy from orchestration.md: first 50 lines + last 20 for files over 500 lines)
2. **Identify:** purpose, entry point, key exports, dependencies (imports), dependents (who imports it), communication with external systems
3. **Read `_boundaries.md`** to understand where this module sits relative to existing boundaries

### 6c. Draft the skill file

Write a new skill file at `.ai/skills/modules/<name>.md` following the same structure as existing module skills:

- Purpose (1-2 sentences)
- Key files / Entry point
- Relationships (depends on, depended on by, communicates with)
- Gotchas (or "None found" if none)
- Change impact checklist
- Extension seams

**Every claim must come from source code you just read.** Do not infer from directory names. Do not guess relationships. If you cannot verify something, omit it.

### 6d. Accuracy pre-check (before proceeding)

Before moving to DR.7, perform an immediate self-check on the new skill:

1. Re-read every file path you referenced. Does it exist?
2. Re-read every dependency claim. Can you find the actual import in source code?
3. Is every sentence verifiable? If any sentence is speculative, delete it.

Log the new skill creation in `_drift_report.md` under a `## New Skills Created` section.

Update `state.md`: mark step DR.6 complete.

---

## Step 7: Cross-Reference Check (DR.7)

After patching all confirmed drifts and creating any new skills, check for ripple effects in related skills.

### 7a. Build the change set

Collect all skill files modified in DR.5, all new skill files from DR.6, and the specific relationship changes made (new dependencies, removed dependencies, changed interfaces).

### 7b. Check related skills

For each modified or new skill A:

1. Grep all files in `.ai/skills/modules/` for A's module name
2. Grep `orientation.md` for A's module name
3. Grep platform glue files for A's module in routing tables

### 7c. Fix asymmetric relationships

For each reference found:

- If A's skill now says it depends on module C (new dependency), does C's skill list A in "depended on by"? If not, add it.
- If A's skill removed a dependency on B, does B's skill still list A in "depended on by"? If so, remove it.
- If A's purpose/scope expanded (not_mentioned directory absorbed), does `orientation.md` still describe A's scope accurately? If not, update it.
- If a new skill was created (DR.6), update `orientation.md` to include the new module in the Boundaries list.

### 7d. Scope limitation

Only fix direct references. Do not recursively follow cross-references. If fixing B reveals that B's relationship with C is also stale, log it in `_drift_report.md` as a finding but do not fix it. Flag it for a future drift resolution run.

### 7e. Log cross-reference updates

Write all cross-reference patches to the `## Cross-Reference Updates` section of `_drift_report.md`.

Update `state.md`: mark step DR.7 complete.

---

## Step 8: Routing Table Update (DR.8)

### 8a. Handle unmapped directories

For each unmapped directory:

1. **If a new skill was created (DR.6),** add it to the CLAUDE.md Module Routing table with the appropriate directory mapping. Add corresponding entries to all other detected platform glue files (AGENTS.md, .cursorrules, copilot-instructions.md).
2. **If the directory was absorbed into an existing module,** add the directory to the existing module's routing entry in all platform glue files.
3. **If the directory did not qualify as a module (DR.6a),** add it to the `CROSS_CUTTING` array in `skill-drift.sh` to suppress future noise, or note it as intentionally unmapped.

### 8b. Handle expanded module scope

If any confirmed drift resulted in a not_mentioned directory being absorbed into an existing skill, update all platform glue routing tables to include the new directory.

### 8c. Consistency across platforms

After all routing changes, verify that every platform glue file has consistent routing. If CLAUDE.md has a new routing entry, AGENTS.md, .cursorrules, and copilot-instructions.md must also have equivalent entries. Per-module routing files (`.cursor/rules/<name>.mdc`, `.claude/rules/<name>.md`) must be created for new modules if those platforms are detected.

### 8d. Log routing changes

Write all routing table updates to the `## Routing Table Updates` section of `_drift_report.md`.

Update `state.md`: mark step DR.8 complete.

---

## Step 9: Accuracy Verification -- Three-Stage Pipeline (DR.9)

**This is the quality gate.** All modified and newly created skills pass through three verification stages before drift resolution is considered complete. No skill file exits this step without passing all three stages.

### Stage 1: Claim-by-claim source verification

For each skill file modified in DR.5 or created in DR.6:

1. Read the skill file in full
2. For **every factual claim** in the file (file paths, function names, dependency relationships, architectural descriptions, command references):
   - Open the referenced source file
   - Verify the claim matches the current code
   - If the claim cannot be verified, mark it `<!-- TODO: verify -->` or remove it
3. Log each verified and unverified claim in `_drift_report.md`

**Threshold:** If more than 20% of claims in a single skill file cannot be verified, flag the skill for full regeneration via `--update <module>` and revert the patches for that skill.

### Stage 2: Structural integrity checks (scoped Phase 4)

Run these Phase 4 validation checks on all modified and new skill files:

**Check 1 -- File path verification:** Every file path referenced in the skill exists on disk. Use Glob or `ls` to confirm. If a path does not exist, fix or remove it.

**Check 3 -- Architectural claim verification:** Claims in modified/new sections are accurate. Read the referenced source code. Confirm described behaviour matches actual code. Flag any numbers or absolute claims.

**Check 9 -- 5-second grep test:** No content added during patching or creation is greppable (file listings, route lists, type definitions, config values). Replace with routing hints.

**Check 10 -- Cross-skill consistency:** For each modified/new skill and its direct neighbours, check for contradictions. If skill A says it depends on B but B does not list A, that is a failure.

**Check 11 -- Token budget enforcement:** Estimate token count (characters / 4). Module skills: ~1.5k tokens. Orientation: ~2k tokens. If a skill grew beyond budget, investigate for greppable content. If genuinely needed, note as accepted overage.

### Stage 3: Relationship symmetry audit

Specifically for relationship claims (the highest-risk category for accuracy):

1. For every "depends on X" claim in a modified/new skill, grep for the actual import statement. Does it exist?
2. For every "depended on by Y" claim, grep Y's code for an import of this module. Does it exist?
3. For every "communicates with Z" claim, find the actual HTTP client, queue publisher, or RPC call in code. Does it exist?

**Any relationship claim that cannot be traced to an actual import, call, or config in source code must be removed.** Do not leave speculative relationships in skills.

### Log results

Write all accuracy verification findings to the `## Accuracy Verification` section of `_drift_report.md`:

```markdown
## Accuracy Verification

### Stage 1: Claim Verification
| Skill | Claims checked | Verified | Unverifiable | Removed |
|---|---|---|---|---|
| [path] | N | N | N | N |

### Stage 2: Structural Integrity
| Check | Files checked | Issues found | Issues fixed |
|---|---|---|---|
| File paths (Check 1) | N | N | N |
| Architectural claims (Check 3) | N | N | N |
| 5-second grep test (Check 9) | N | N | N |
| Token budgets (Check 11) | N | N | N |
| Cross-skill consistency (Check 10) | N | N | N |

### Stage 3: Relationship Symmetry
| Skill | Relationships checked | Verified | Removed (no evidence) |
|---|---|---|---|
| [path] | N | N | N |
```

Update `state.md`: mark step DR.9 complete.

---

## Step 10: Write Summary (DR.10)

### 10a. Complete `_drift_report.md`

Fill in the `## Summary` section with final tallies:
- Skills patched
- New skills created
- Sections updated
- Cross-reference fixes
- Routing table entries added/updated
- Accuracy: claims verified / claims removed
- Relationship claims verified / removed
- False positives filtered

### 10b. Update `_manifest.md`

- For each skill file that was patched, update its disposition to `updated` with a note: `Drift resolution [ISO date]`
- For each new skill file, add it with disposition `generated` and note: `Drift resolution [ISO date]`

Update `state.md`: mark step DR.10 complete.

---

## Step 11: Completion (DR.11)

1. **Update `state.md`:**
   - Update the `commit:` field to the current HEAD
   - Add an entry to the `## Drift Resolution History` section:
     ```
     | Date | Drifts found | Confirmed | Patched | New skills | False positives | Accuracy rate | New commit |
     |------|-------------|-----------|---------|------------|-----------------|---------------|------------|
     | [ISO date] | N | N | N | N | N | N% | [short hash] |
     ```
   - Mark step DR.11 complete

2. **Report to the orchestrator:**
   - How many drift signals were found and how many were confirmed
   - How many skills were patched and what changed
   - How many new skills were created and for which modules
   - Accuracy verification results (claims verified vs removed)
   - Whether any skills failed the 20% verification threshold and were flagged for `--update`
   - Whether any deep structural issues were found (recommend full pipeline re-run if so)

---

## Parallelisation

### Threshold

- **1-3 confirmed drifts:** Sequential execution. One agent handles all skills in order.
- **4+ confirmed drifts:** Parallel execution for DR.4 + DR.5. New skill creation (DR.6), cross-reference check (DR.7), routing update (DR.8), and accuracy verification (DR.9) are performed sequentially by the orchestrating agent after all subagents complete.

### Parallel dispatch protocol

1. **Define work units.** Each confirmed drift is one work unit. A subagent handles Analysis (DR.4) + Patch (DR.5) for one skill file.

2. **Subagent prompt includes:**
   - The full text of the skill file to patch
   - The filtered git diff for the skill's domain directories
   - The triage classification from DR.2 (which changes are structural/interface)
   - The section-to-change mapping table from DR.4
   - The patch rules from DR.5 (surgical edit, preserve non-stale content, evidence standards)
   - The output file path: `~/.claude/MEMORY/RepoSkills/<repo-slug>/_drift_patch_<skill-name>.md`

3. **Model selection:** Use `sonnet` for Analysis + Patch subagents. This is systematic reading-and-comparison work, not creative synthesis.

4. **Subagent output format:**
   ```markdown
   # Drift Patch: [skill file]

   ## Changes Applied
   [list of patches with evidence, same format as _drift_report.md Patches section]

   ## Cross-Reference Signals
   [relationship changes that need propagation to other skills]

   ## Concerns
   [anything the subagent is unsure about]
   ```

5. **Post-merge (orchestrating agent):**
   - Read all `_drift_patch_<name>.md` files
   - Perform DR.6 (new skill creation for unmapped directories)
   - Perform DR.7 (cross-reference check) using the "Cross-Reference Signals" from all subagents
   - Perform DR.8 (routing table update)
   - Perform DR.9 (accuracy verification on all modified and new skills)
   - Merge all findings into `_drift_report.md`
   - Delete all `_drift_patch_<name>.md` working files

6. **Failure handling:** Re-dispatch once. If it fails again, the orchestrating agent performs that skill's analysis and patching sequentially. Log the failure in `state.md`: `<!-- Subagent failure: [skill], fell back to sequential -->`

---

## Rules

- **Accuracy is paramount.** Every claim in a patched or new skill must be verified against actual source code through the three-stage accuracy pipeline (DR.9). No claim survives on plausibility alone. If you cannot verify it, remove it. Wrong skills are worse than no skills.

- **Repair existing skills, do not regenerate.** Drift resolution surgically patches stale sections of existing skills. It does not rewrite them from scratch. If an existing skill needs fundamental restructuring, use `--update <module>` instead.

- **New skills are permitted for genuinely new modules.** Unmapped directories that qualify as module boundaries (DR.6) get new skill files. These new skills go through the same accuracy pipeline as patches.

- **Same evidence standards as Phase 4.** Every patch and every new claim must be verified against actual source code. Do not guess what the code does from the diff alone. Read the actual file.

- **Preserve human refinements.** Content added by humans outside the pipeline (extra gotchas, corrected claims, added context) must be preserved unless it is factually wrong. If in doubt, preserve it and add a `<!-- TODO: verify after drift resolution -->` marker.

- **Do not expand scope beyond the drift.** When resolving drift in module A, do not document unrelated subsystems. When creating a new skill for an unmapped directory, document only that directory. Log discoveries in `_drift_report.md` for future action.

- **Cross-references are mandatory for relationship changes.** If module A's dependencies changed, the corresponding "depended on by" sections in related skills must be updated in the same run. Asymmetric relationships are an accuracy verification failure.

- **The 5-second grep test applies to all content.** Do not add greppable content to fill a gap, whether patching or creating. Route to the file instead.

- **Token budgets apply.** After patching or creating, check the skill's token count. Module skills: ~1.5k tokens. Adding 200 tokens of relationship context is fine. Adding 500 tokens of file listings is not.

- **Anchor advancement is automatic.** When the updated/new skill files are committed, the commit becomes the new anchor. No separate anchor tracking is needed.

- **Do not run full simulations.** Drift resolution is a maintenance operation. The three-stage accuracy pipeline is the quality gate. If accuracy verification reveals deep structural problems, recommend a full pipeline re-run.

- **The 20% threshold is a hard gate.** If more than 20% of claims in a single skill cannot be verified in Stage 1 of accuracy verification, that skill is flagged for full regeneration. Do not leave an unverifiable skill in place.

- **Log everything to `_drift_report.md`.** Every triage decision, every patch, every new skill, every accuracy check result. This file is the audit trail.
