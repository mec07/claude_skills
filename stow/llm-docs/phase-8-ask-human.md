# Phase 8: Ask Human

The pipeline has completed all automated phases. `~/.claude/MEMORY/llm-docs/<repo-slug>/_review.md` contains any remaining issues that could not be resolved from source code alone. Your job is to present these to the user, get answers, and make final documentation updates.

---

## Checklist

Copy this checklist into `state.md` under the Phase 8 entry. Mark each item `[x]` immediately upon completion.

```
- [ ] 8.0: Pre-check — read _review.md, determine if questions exist
- [ ] 8.0b: Reverse Glossary — extract and present undefined domain terms
- [ ] 8.1: Present grouped questions to user (skip if no open/partial issues)
- [ ] 8.2: Incorporate user answers into documentation
- [ ] 8.3: Update _review.md with resolutions
- [ ] 8.4: Present final summary (tallies from _audit.md and _review.md)
- [ ] 8.5: Clean up — delete _ prefixed files from MEMORY directory
- [ ] 8.6: Update state.md — mark all phases complete
```

---

## Inputs and Outputs

| Direction | File | Location | Description |
|---|---|---|---|
| **Input** | `state.md` | `~/.claude/MEMORY/llm-docs/<repo-slug>/` | Repo path, slug, phase progress |
| **Input** | `_review.md` | `~/.claude/MEMORY/llm-docs/<repo-slug>/` | All clarity review findings (Phases 4, 5, 7) |
| **Input** | `_audit.md` | `~/.claude/MEMORY/llm-docs/<repo-slug>/` | Validation findings (Phase 6) |
| **Input** | All `docs/llm/` files | Target repo | Documentation to update with user answers |
| **Output** | Updated `docs/llm/` files | Target repo | Final documentation with user input incorporated |
| **Output** | `state.md` (updated) | `~/.claude/MEMORY/llm-docs/<repo-slug>/` | All phases marked complete — serves as pipeline record |

---

## Updating state

After completing **each numbered step** below, immediately update `state.md`:

1. Mark the step's checkbox `[x]` in the Phase 8 checklist
2. Update the `updated:` timestamp

Do not batch state updates. If context is lost between steps, the recovery protocol relies on `state.md` being current. A completed step with no state update will be repeated on resume.

---

## Pre-check (Step 8.0)

Open `~/.claude/MEMORY/llm-docs/<repo-slug>/_review.md`. Check for issues with status `open` or `partial — needs human input`.

If there are **no open or partial issues** AND the Reverse Glossary (step 8.0b) finds no undefined terms: skip to the Completion section below (step 8.4). Inform the user that the documentation pipeline is complete with no outstanding questions.

If there **are open or partial issues** OR the Reverse Glossary finds terms to define: proceed to step 8.0b, then step 8.1.

Update `state.md`: mark step 8.0 complete.

---

## Reverse Glossary (Step 8.0b)

Before presenting open issues, perform a Reverse Glossary extraction. This surfaces domain terms the pipeline couldn't confidently define.

### Process

1. **Extract candidate terms:** Scan all generated documentation, source code string constants, enum values, database column names, UI labels, and API endpoint names for terms that:
   - Appear frequently (5+ occurrences across the codebase) but have no definition in `docs/llm/domain-context.md` or `docs/llm/glossary.md`
   - Are used in variable/function names but aren't standard programming terms
   - Appear in comments or error messages with domain-specific meaning

2. **Filter out known terms:** Remove any term already defined in `docs/llm/domain-context.md` (if it exists) or `docs/llm/glossary.md` (if it exists). Also remove standard technical vocabulary (e.g., "middleware", "schema", "endpoint", "controller", "service").

3. **Present to the user** as part of the combined question set (see Step 8.1). Interleave domain terms with open issues, all sorted by impact. For each term, show the CODE CONTEXT where it appears so the human can see how it's used:

   ```
   I found these domain-specific terms in the codebase that I'm not confident
   I understand correctly. Can you define any of them?

   - `settlement_window` — appears in src/services/settlement.ts (line 42),
     src/types/transaction.ts (line 15), and 12 other files.
     Based on usage in settlement.ts, this appears to relate to a time period
     for processing transactions — is that correct? What specifically does it mean?

   - `provider_tier` — used in src/models/provider.ts and src/routes/matching.ts.
     I can see it's an enum with values GOLD/SILVER/BRONZE but I don't understand
     the business significance. What determines a provider's tier?

   You can skip any you don't want to define right now.
   ```

4. **For each term the user defines:** Add it to `docs/llm/domain-context.md` in the Domain Glossary table (create the file with just the Glossary section if it doesn't exist). If `glossary.md` also exists, add it there too.

5. **For skipped terms:** Leave them out. Do not guess.

### Rules
- Show the code context where each term appears, not just the term. The human needs to see HOW it's used to give a precise definition.
- If the usage pattern strongly suggests a specific meaning, state it as a hypothesis clearly marked: "Based on usage in [file], this appears to mean [X] — is that correct?" The human's response is authoritative — if they correct your hypothesis, replace it entirely.
- Do NOT present terms that are standard technical vocabulary
- Maximum 10 terms. If more candidates exist, prioritise by frequency and cross-module usage.
- If `domain-context.md` doesn't exist (Phase D was skipped on a previous run), create it now with just the Glossary section.

Update `state.md`: mark step 8.0b complete.

---

## Presenting questions (Step 8.1)

Read all open and partial issues from `_review.md`. Present questions grouped by priority tier:

**Tier 1 — Blocking** (agents cannot work in this area without an answer):
**Tier 2 — Communication/Data Flow** (affects understanding of how components interact):
**Tier 3 — Data Structures** (affects understanding of data relationships):
**Tier 4 — Other** (improves docs but not blocking):

For each question, use this structured format:

```
**Q[N]: [Specific question]**
- **Doc origin:** preserved | generated | hybrid (preserved, modified by Phase 5)
- **Why it matters:** [What an agent trying to do X would get stuck on]
- **What I checked:** [Source files examined, what they showed]
- **Can defer?** Yes / No — [If yes: docs work without this but have a gap. If no: this blocks agent work in the area.]
```

To determine the origin for each question's associated doc file, read `_manifest.md` from `~/.claude/MEMORY/llm-docs/<repo-slug>/`. Cross-reference each question's target doc against the manifest entries:
- **preserved** — the doc existed in a previous run and was kept as-is
- **generated** — the doc was freshly written in this run
- **hybrid** — the doc was preserved from a previous run but Phase 5 partially updated it

**Deferred answers:** If the user says 'defer' or 'skip' for a question, mark it `deferred` in `_review.md` (not `open`). Deferred issues are documented as known gaps in the final docs with `<!-- DEFERRED: [question] -->` markers. These are not failures — they are acknowledged limitations.

**Partial answers:** If the user gives a partial answer, incorporate what you can, update the issue to `partial`, and ask a focused follow-up scoped to the remaining gap.

Update `state.md`: mark step 8.1 complete.

---

## After receiving answers (Steps 8.2 and 8.3)

For each answer the user provides:

1. Update the relevant documentation file(s) with the new information
2. Verify that the update is consistent with the rest of the docs
3. If the answer reveals something that contradicts existing docs, fix the contradiction
4. Update `~/.claude/MEMORY/llm-docs/<repo-slug>/_review.md`:
   - Change the issue status to `resolved` and record the resolution
   - If the user explicitly defers an issue ("not important", "won't fix", "skip it"), change its status to `deferred`

After all answers are incorporated, update the final summary in `_review.md`.

Update `state.md`: mark steps 8.2 and 8.3 complete.

---

## Completion (Steps 8.4 through 8.6)

### Step 8.4: Final summary

Present a final summary to the user:

- Final tally from `~/.claude/MEMORY/llm-docs/<repo-slug>/_audit.md`:
  - Files audited, claims checked, errors found and fixed, claims removed
- Final tally from `~/.claude/MEMORY/llm-docs/<repo-slug>/_review.md`:
  - Total issues found, resolved, deferred, remaining
- Any remaining `<!-- TODO: verify -->` markers in the docs and why they couldn't be resolved
- A brief statement of overall confidence in the documentation accuracy

Update `state.md`: mark step 8.4 complete.

### Step 8.5: Clean up working files

Delete all `_` prefixed files from `~/.claude/MEMORY/llm-docs/<repo-slug>/`. These are working files that were used for state passing between phases and are no longer needed:

- `_original_docs.md`
- `_audit.md`
- `_review.md`
- Any `_explore_*.md`, `_validate_*.md`, `_scenario_*.md` files from subagent output

**Do NOT delete `state.md`.** It serves as a permanent record that the documentation pipeline was run, when it completed, and what repo it targeted.

**Do NOT delete `docs/llm/domain-context.md`** — this lives in the target repo, not MEMORY. It is a permanent output file that persists across runs.

Report to the user: "Working files cleaned from MEMORY. Documentation pipeline complete. State preserved in state.md."

Update `state.md`: mark step 8.5 complete.

### Step 8.6: Mark pipeline complete

Update `state.md`:
- Mark step 8.6 complete
- Mark Phase 8 complete with timestamp
- Mark all phases as `[x]` complete
- Update the `updated:` timestamp to the final completion time

The `state.md` file at `~/.claude/MEMORY/llm-docs/<repo-slug>/state.md` now serves as the permanent record that this repo's documentation has been generated and validated.
