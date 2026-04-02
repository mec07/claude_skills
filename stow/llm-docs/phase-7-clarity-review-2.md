# Phase 7: Clarity Review (Pass 2)

This is a second clarity review. Phases 5 and 6 resolved issues and re-validated the documentation. Your job is to check whether those fixes actually work from an agent's perspective, and to find any remaining gaps.

**Read `phase-4-clarity-review.md` and follow its full procedure** with these modifications:

## Differences from Phase 4

### 1. Preserve resolved issues in `_review.md`

Do NOT clear or overwrite `docs/llm/_review.md`. Keep all existing entries, including those with status `resolved` — they are the record of what was found and fixed. Add new findings below the existing content.

### 2. Focus on what changed

Phases 5–6 updated documentation and re-validated. Your primary focus is whether those changes:
- Actually resolved the issues they claimed to resolve (check each `resolved` entry — did the fix land correctly?)
- Introduced new gaps, ambiguities, or dead-ends
- Changed the navigation path for simulated scenarios in a way that helps or hurts

### 3. Use different scenarios

If Phase 4 simulated specific tasks, choose **different tasks** this time to exercise different parts of the documentation. The goal is broader coverage — don't re-test the same paths.

### 4. Check for skip condition

After completing your review, check `_review.md`. If **all issues have status `resolved`** (including any new issues you found and were able to fix), report to the orchestrator that Phase 8 can be skipped — no human input is needed.

If open or partial issues remain, report the count and highest-priority gaps.

---

Now read `phase-4-clarity-review.md` and execute the full clarity review procedure with the modifications above.
