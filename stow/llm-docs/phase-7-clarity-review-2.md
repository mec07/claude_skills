# Phase 7: Clarity Review (Pass 2)

This is a second clarity review. Phases 5 and 6 resolved issues and re-validated the documentation. Your job is to check whether those fixes actually work from an agent's perspective, and to find any remaining gaps.

**Read `phase-4-clarity-review.md` and follow its full procedure** with the modifications below.

---

## Checklist

Copy this checklist into `state.md` under the Phase 7 entry. Mark each item `[x]` immediately upon completion.

```
- [ ] 7.0: Read _review.md — preserve existing entries, append new findings below
- [ ] 7.1: Read all documentation files (Step 1 of phase-4-clarity-review.md)
- [ ] 7.2: Verify resolved issues — check each resolved entry landed correctly
- [ ] 7.3: Simulate real tasks using different scenarios than Phase 4 (Step 2)
- [ ] 7.4: Review findings — patterns, priorities, clusters (Step 3)
- [ ] 7.5: Attempt quick fixes for new issues (Step 4)
- [ ] 7.6: Check skip condition — can Phase 8 be skipped?
- [ ] 7.7: Update state.md — mark Phase 7 complete with timestamp
```

---

## Inputs and Outputs

| Direction | File | Location | Description |
|---|---|---|---|
| **Input** | `state.md` | `~/.claude/MEMORY/llm-docs/<repo-slug>/` | Repo path, slug, phase progress |
| **Input** | `_review.md` | `~/.claude/MEMORY/llm-docs/<repo-slug>/` | Clarity review findings from Phases 4-5 (preserve all entries) |
| **Input** | `_audit.md` | `~/.claude/MEMORY/llm-docs/<repo-slug>/` | Phase 6 validation findings |
| **Input** | All `docs/llm/` files | Target repo | Documentation to review |
| **Input** | Codebase | Target repo on disk | For verifying fixes and simulating tasks |
| **Output** | `_review.md` (updated) | `~/.claude/MEMORY/llm-docs/<repo-slug>/` | Existing entries preserved + new findings appended |

---

## Updating state

After completing **each numbered step** below, immediately update `state.md`:

1. Mark the step's checkbox `[x]` in the Phase 7 checklist
2. Update the `updated:` timestamp

Do not batch state updates. If context is lost between steps, the recovery protocol relies on `state.md` being current. A completed step with no state update will be repeated on resume.

---

## Differences from Phase 4

### 1. Preserve resolved issues in `_review.md` (Step 7.0)

Do NOT clear or overwrite `~/.claude/MEMORY/llm-docs/<repo-slug>/_review.md`. Keep all existing entries, including those with status `resolved` — they are the record of what was found and fixed. Add new findings below the existing content under a clearly marked section:

```markdown
## Phase 7 Findings

### [area/module name] — [short description]
- **Phase:** 7
- **Type:** gap | ambiguity | dead-end | contradiction | navigation | missing-connection
- **Found in:** `path/to/doc.md`
- **Detail:** what's wrong or missing
- **Question for maintainer:** specific question to resolve this
- **Status:** open
```

Update `state.md`: mark step 7.0 complete.

### 2. Focus on what changed (Step 7.2)

Phases 5-6 updated documentation and re-validated. Your primary focus is whether those changes:
- **Actually resolved the issues they claimed to resolve** — check each `resolved` entry in `_review.md`. Did the fix land correctly in the documentation? Is the issue genuinely resolved, or was the fix incomplete or incorrect?
- **Introduced new gaps, ambiguities, or dead-ends** — the fix for one issue may have created another
- **Changed the navigation path** for simulated scenarios in a way that helps or hurts

For each resolved issue you re-check:
- If the fix is correct and complete, leave the status as `resolved`
- If the fix is incomplete or incorrect, change the status to `open` with a note explaining why
- Log your re-check in the Phase 7 Findings section regardless of outcome

Update `state.md`: mark step 7.2 complete.

### 3. Use different scenarios (Step 7.3)

If Phase 4 simulated specific tasks, choose **different tasks** this time to exercise different parts of the documentation. The goal is broader coverage — don't re-test the same paths. Refer to `phase-4-clarity-review.md` Step 2 for the scenario list, and pick scenarios that Phase 4 did not use.

If you cannot determine which scenarios Phase 4 used (e.g., the record is unclear), choose scenarios that target different modules and different communication boundaries than the most commonly documented areas.

Update `state.md`: mark step 7.3 complete.

### 4. Check skip condition (Step 7.6)

After completing your review, check `~/.claude/MEMORY/llm-docs/<repo-slug>/_review.md`. Count all issues across both Phase 4 and Phase 7 findings.

**If ALL issues have status `resolved`** (including any new issues you found and were able to fix in Step 7.5):
- Report to the orchestrator that **Phase 8 can be skipped** — no human input is needed
- Update the summary section of `_review.md` to reflect this

**If open or partial issues remain:**
- Report the count and highest-priority gaps to the orchestrator
- These will be presented to the user in Phase 8

Update the summary section of `_review.md`:

```markdown
## Summary (after Phase 7)
- Total issues found (all phases): N
- Resolved: N
- Partial (needs human input): N
- Open (needs human input): N
- New issues found in Phase 7: N
- Phase 8 skip recommended: yes | no
```

Update `state.md`: mark step 7.6 complete.

---

## Execution

Now read `phase-4-clarity-review.md` and execute the full clarity review procedure with the modifications above. The standard procedure steps map to the checklist as follows:

- Phase 4 Step 1 (Read everything) → Step 7.1
- Resolved issue verification → Step 7.2 (new — not in Phase 4)
- Phase 4 Step 2 (Simulate real tasks) → Step 7.3
- Phase 4 Step 3 (Review findings) → Step 7.4
- Phase 4 Step 4 (Attempt quick fixes) → Step 7.5
- Skip condition check → Step 7.6 (new — not in Phase 4)

Update `state.md` after each step completes.

When you have completed the full review:

1. Update `state.md`: mark Phase 7 complete with timestamp (step 7.7)
2. Report to the orchestrator:
   - Total issues found across all phases
   - How many resolved vs. open/partial
   - Whether Phase 8 can be skipped
   - The highest-priority gaps (if any remain)
