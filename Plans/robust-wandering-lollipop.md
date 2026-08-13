# Implementation Plan: Scenario Robustness — Manifest System + Independent Fixes

## Context

Three scenario-based QA walkthroughs (massive monorepo with no docs, massive monorepo with questionable docs, re-run with partial output) identified 12 improvements across 6 themes. First Principles analysis reduced these to **2 architectural changes + 4 independent fixes**.

The unifying insight: **one new file (`_manifest.md`) solves 8 of 12 issues** by persisting Phase 1's disposition decisions for all subsequent phases to consume.

## Clash Analysis

One clash: Fixes 5 and 6 touch the same lines (phase-1-generate.md line 84). **Merged into one edit.**

No other clashes. All fixes touch non-overlapping sections.

## Architecture

### The Manifest (`_manifest.md`)

Written by Phase 1 to `~/.claude/MEMORY/llm-docs/<repo-slug>/_manifest.md`. Format:

```markdown
# File Manifest

## Top-level docs
| File | Disposition | Confidence | Lines | Notes |
|------|-------------|------------|-------|-------|
| overview.md | preserved | high | 152 | |
| architecture.md | preserved | high | 203 | |
| scripts.md | generated | n/a | 0 | New to spec — did not exist |
| glossary.md | skipped | n/a | 0 | Not warranted |

## Module docs
| File | Disposition | Confidence | Lines | Notes |
|------|-------------|------------|-------|-------|
| modules/auth.md | preserved | high | 89 | |
| modules/payments.md | generated | n/a | 0 | New module discovered |
| modules/legacy.md | orphaned | medium | 45 | Module deleted from codebase |

## Tiering (if applicable)
- Tier 1: [list]
- Tier 2: [list]
- Tier 3: [list]
```

## Execution Plan — 3 Waves

### Wave 1: SKILL.md Foundation (2 edits)

**Edit 1: Add `_manifest.md` to working files table (lines 76-86)**
Add row: `| _manifest.md | Phase 1 | Phases 2, 6, 7, 8 | Phase 8 cleanup | File disposition: preserved vs generated vs orphaned |`

**Edit 2: Update file lifecycle section (lines 88-97)**
Add `+ _manifest.md` to every phase end from Phase 1 onwards.

**Edit 3: Add batching guidance to parallelisation section (lines ~193)**
After the "When to parallelise" table, add: "**Batching for large repos:** For repos requiring 30+ parallel subagents, dispatch in waves of 10-15 subagents. Wait for each wave to complete before dispatching the next. This keeps coordination overhead manageable and limits the blast radius of failures. Within each wave, apply the standard failure recovery protocol (re-dispatch once, then sequential fallback)."

### Wave 2: Phase 1 Core Changes (6 edits, sequential — all in one file)

All edits in `phase-1-generate.md`, applied top-to-bottom to avoid offset drift.

**Edit 1 — Fix 3: Add tiering step to checklist (lines 9-26)**
Add `- [ ] 1i: Assign module tiering (Tier 1/2/3 for repos with 20+ modules)` between `1h` and `GATE`.

**Edit 2 — Fix 5+6: Module comparison in manifest section (line 84)**
Replace "They will be added to the manifest after Step 1." with: "They will be added to the manifest after Step 1. **After exploration, compare discovered modules against existing module docs. For each discovered module with no existing doc: mark as `generate` (coverage gap). For each existing module doc whose module no longer exists in the codebase: mark as `orphaned`. Record both gaps and orphans in the manifest for Phase 2.**"

**Edit 3 — Fix 1: Confidence-aware disposition rules (lines 88-93)**
Replace the current disposition rules with:
```
**File disposition rules (unless `--fresh` was specified):**
- **File exists + >20 lines + Phase 0 scored `high-confidence`:** Mark as `preserve`.
- **File exists + >20 lines + Phase 0 scored `medium-confidence`:** Mark as `generate` — the doc has substance but Phase 0 found staleness concerns. Rewrite from scratch using exploration findings.
- **File exists + >20 lines + Phase 0 scored `low-confidence`:** Mark as `generate` — the doc is unreliable.
- **File exists + >20 lines + NOT assessed by Phase 0** (e.g., new to spec, or `docs/llm/` file from a previous llm-docs run that Phase 0 didn't individually assess): Mark as `preserve` — treat previous llm-docs output as trustworthy by default.
- **File missing or stub (<=20 lines):** Mark as `generate`.
- **`--fresh` mode:** Mark ALL files as `generate` regardless.
```

**Edit 4 — Fix 2: Manifest written to MEMORY (lines 78-95)**
Change step 5 from "Record the manifest in the MEMORY directory as part of your working notes" to: "**Write the manifest to `~/.claude/MEMORY/llm-docs/<repo-slug>/_manifest.md`** using the format specified in SKILL.md. This file is read by Phases 2, 6, 7, and 8 to understand which docs were preserved, generated, or orphaned."

Change the summary emission section (lines ~268-276) to: "**Write the final manifest** to `_manifest.md` in the MEMORY directory (updating the pre-exploration version with module doc dispositions and tier assignments). Then **emit the summary** to the user..."

**Edit 5 — Fix 3b: Add tiering step after 1h (after line ~195)**
Add new section:
```
**1i. Assign module coverage tiers (repos with 20+ modules only)**

If exploration identified 20+ modules warranting documentation, assign coverage tiers:
- **Tier 1** (full module docs — 10 max): Most important or most-connected modules. Criteria: highest dependency count, entry points, or cross-module import frequency.
- **Tier 2** (summary module docs — 15-20): Medium importance. Docs include: purpose, location, key files, dependencies, dependents. No deep flow tracing.
- **Tier 3** (overview mention only): Remaining modules. One-line description and path in `overview.md`. No individual module doc.

Record tier assignments in `state.md` AND in `_manifest.md` so all subsequent phases know the coverage expectations.

For repos with <20 modules, skip tiering — all modules get full docs.

**Update state:** Mark step 1i complete in `state.md`.
```

**Edit 6 — Self-review update (end of file, ~line 680)**
In the "Preserved file verification" section, add: `- [ ] Manifest (`_manifest.md`) written to MEMORY with correct dispositions for all files`

### Wave 3: Downstream Phase Files (7 edits, parallel — one agent per file)

**Agent A: phase-0-discover.md (Fix 8)**
Find the batch assessment section (lines 86-93). After step 4 ("Assign the group confidence"), add: "**Contradiction warning:** During batch assessment, watch for contradictions within groups. If READMEs in the same quality group make conflicting claims about the same module, component, or responsibility, note the conflict explicitly in `_original_docs.md`. Do not assign a single confidence score to a group with internal contradictions — split the conflicting READMEs into separate assessments."

**Agent B: phase-2-refine.md (Fix 9)**
Two edits:
1. In the Inputs section (lines 24-32), add: `- ~/.claude/MEMORY/llm-docs/<repo-slug>/_manifest.md — Phase 1 file disposition (preserved, generated, orphaned)`
2. In Step 1a module boundary assessment (lines 62-77), after "Are there module docs for things too trivial?", add: "- **Check the manifest for orphaned docs.** Read `_manifest.md`. Any module doc marked `orphaned` (module no longer in codebase) should be deleted. Any module marked as a coverage gap should get a new doc in Step 3. Cross-reference tier assignments from the manifest to ensure Tier 1 modules have full docs and Tier 2 have summaries."

**Agent C: phase-3-validate.md (Fix 7)**
After Check 10 (contradiction check against originals, ~line 245), add new section:
```
### Check 10b: Internal consistency across generated docs

Scan the generated documentation set for contradictions BETWEEN docs (not comparing to originals — that was Check 10):
- Does module A's doc claim it communicates with module B via REST, while module B's doc says it receives from A via gRPC?
- Do two docs describe different responsibilities for the same component?
- Are the same file paths described differently in different docs?
- Does `architecture.md` describe a flow that contradicts what a module doc says?

For each internal contradiction: trace the source code, determine which doc is correct, fix the incorrect one. Log each finding to `_audit.md`.
```
Also add `3r: Check 10b — internal consistency across generated docs` to the checklist.

**Agent D: phase-6-validate-2.md (Fix 10)**
After the "Pay special attention to Phase 4-5 changes" section (lines 85-93), add: "**Increased scrutiny for modified preserved docs:** Read `_manifest.md` to identify which docs were `preserved` by Phase 1. For any preserved doc that Phase 5 subsequently modified, validate 80%+ of claims (not the usual spot-check level). The boundary between old preserved content and new Phase 5 additions is where inconsistencies are most likely to hide."

**Agent E: phase-7-clarity-review-2.md (Fix 11)**
In the skip condition section (lines 92-116), before "If ALL issues have status `resolved`", add: "**Preserved doc check:** Before declaring Phase 8 skippable, read `_manifest.md`. If any doc was marked `preserved` AND was never modified by Phase 5 (i.e., it appears in no `resolved` issue as the fixed file), add a note: 'N preserved docs were never re-validated in Phases 4-5. These may contain stale content from a previous run.' If N > 0, **Phase 8 cannot be skipped** — the user should be informed which preserved docs were untouched and asked whether they want a spot-check or accept them as-is."

**Agent F: phase-8-ask-human.md (Fix 12)**
In the structured question format (lines 68-75), add `- **Doc origin:** preserved | generated | hybrid (preserved, modified by Phase 5)` as a field after `**Found in:**`. This tells the user whether the question stems from a previous run's doc that was kept, a freshly written doc, or a preserved doc that Phase 5 partially updated.

**Agent G: SKILL.md state.md template update**
In the state.md template (lines 48-70), add tiering section placeholder:
```
## Coverage Tiering (if applicable)
- Tier 1: [list or "not applicable"]
- Tier 2: [list or "not applicable"]  
- Tier 3: [list or "not applicable"]
```

## Execution Summary

```
Wave 1 (SKILL.md — 3 edits, sequential):
  Edit 1: Add _manifest.md to working files table
  Edit 2: Update file lifecycle with _manifest.md
  Edit 3: Add batching guidance

Wave 2 (phase-1-generate.md — 6 edits, sequential top-to-bottom):
  Edit 1: Add 1i to checklist
  Edit 2: Module comparison in manifest (Fix 5+6 merged)
  Edit 3: Confidence-aware disposition rules (Fix 1)
  Edit 4: Manifest written to MEMORY (Fix 2)
  Edit 5: Tiering step after 1h (Fix 3b)
  Edit 6: Self-review manifest check

Wave 3 (7 files — parallel agents):
  Agent A: phase-0-discover.md    (Fix 8 — batch contradiction warning)
  Agent B: phase-2-refine.md      (Fix 9 — manifest input + orphan check)
  Agent C: phase-3-validate.md    (Fix 7 — internal contradiction check)
  Agent D: phase-6-validate-2.md  (Fix 10 — increased sampling for preserved)
  Agent E: phase-7-clarity-review-2.md (Fix 11 — skip condition + preserved check)
  Agent F: phase-8-ask-human.md   (Fix 12 — doc origin in questions)
  Agent G: SKILL.md               (tiering in state.md template)
```

## Verification

After all waves:
1. **Grep `_manifest.md`** across all files — should appear in: SKILL.md (table + lifecycle), phase-1 (build + write), phase-2 (input + check), phase-6 (read), phase-7 (read), phase-8 (read for origin)
2. **Grep `orphaned`** in phase-1 — should appear in manifest section
3. **Grep `high-confidence`** in phase-1 disposition rules — should be part of preserve criteria
4. **Grep `Check 10b`** in phase-3 — should appear as internal contradiction check
5. **Grep `Tier 1`** in phase-1 — should appear in tiering step
6. **Grep `batch`** in SKILL.md — should appear in parallelisation section
7. **Grep `contradiction warning`** in phase-0 — should appear in batch assessment
8. **Grep `Doc origin`** in phase-8 — should appear in question format

## Files Modified

| File | Fixes Applied | Wave |
|------|---------------|------|
| `SKILL.md` | Manifest table + lifecycle, batching, state.md tiering template | 1 + 3G |
| `phase-0-discover.md` | Batch contradiction warning | 3A |
| `phase-1-generate.md` | Tiering checklist + step, manifest system, confidence disposition, orphan detection | 2 |
| `phase-2-refine.md` | Manifest input, orphan check in Step 1a | 3B |
| `phase-3-validate.md` | Check 10b internal contradictions | 3C |
| `phase-6-validate-2.md` | Increased sampling for modified preserved docs | 3D |
| `phase-7-clarity-review-2.md` | Skip condition + preserved doc check | 3E |
| `phase-8-ask-human.md` | Doc origin in question format | 3F |
| `phase-4-clarity-review.md` | (no changes) | — |
| `phase-5-self-resolve.md` | (no changes) | — |
