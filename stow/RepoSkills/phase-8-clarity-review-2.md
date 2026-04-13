# Phase 8: Clarity Review (Pass 2)

This is a second clarity review. Phases 6 and 7 resolved issues and re-validated the skills. Your job is to check whether those fixes actually work from an agent's perspective, and to find any remaining gaps.

**Read `phase-5-clarity-review.md` and follow its full procedure** with the modifications below.

---

## Checklist

Copy this checklist into `state.md` under the Phase 8 entry. Mark each item `[x]` immediately upon completion.

```
- [ ] 8.0: Read _simulation_report.md — preserve existing entries, append new findings below
- [ ] 8.1: Read all skill files
- [ ] 8.2: Verify resolved issues — check each resolved entry from Phase 6 landed correctly
- [ ] 8.3: Simulate real tasks using DIFFERENT scenarios than Phase 5
- [ ] 8.4: Review findings — patterns, priorities, clusters
- [ ] 8.5: Attempt quick fixes for new issues
- [ ] 8.6: Check skip condition — can Phase 9 be skipped?
- [ ] 8.7: Update state.md — mark Phase 8 complete with timestamp
```

---

## Inputs and Outputs

| Direction | File | Location | Description |
|---|---|---|---|
| **Input** | `state.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Repo path, slug, phase progress |
| **Input** | `_simulation_report.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Phase 5 findings + Phase 6 resolutions (preserve all entries) |
| **Input** | `_audit.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Phase 7 validation findings |
| **Input** | All skill files | Target repo: `.ai/skills/` | Skills to review |
| **Input** | Platform glue files | Target repo root | `AGENTS.md`, `CLAUDE.md`, etc. |
| **Input** | Codebase | Target repo on disk | For verifying fixes and simulating tasks |
| **Output** | `_simulation_report.md` (updated) | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Existing entries preserved + new findings appended |

---

## Updating state

After completing **each numbered step** below, immediately update `state.md`:

1. Mark the step's checkbox `[x]` in the Phase 8 checklist
2. Update the `updated:` timestamp

Do not batch state updates. If context is lost between steps, the recovery protocol relies on `state.md` being current. A completed step with no state update will be repeated on resume.

---

## Differences from Phase 5

### 1. Preserve resolved issues in `_simulation_report.md` (Step 8.0)

Do NOT clear or overwrite `~/.claude/MEMORY/RepoSkills/<repo-slug>/_simulation_report.md`. Keep all existing entries, including the Phase 6 Resolution Summary — they are the record of what was found and fixed. Add new findings below the existing content under a clearly marked section:

```markdown
## Phase 8 Clarity Review Findings

### Simulation N: [name]

#### Task
[Full task description]

#### Steps Attempted
1. **[Action]** — Read [skill file]. Found [what]. [Sufficient / Insufficient — why]
[... continue ...]

#### Issues Found
- **[skill file path]** — [gap/confusion/wrong assumption]. Severity: [blocking / degrading / minor]

#### Verdict
[sufficient / insufficient] — [summary]
```

Update `state.md`: mark step 8.0 complete.

### 2. Verify resolved issues first (Step 8.2)

Phases 6-7 updated skills and re-validated. Your primary focus is whether those changes:
- **Actually resolved the issues they claimed to resolve** — check each `resolved` entry in `_simulation_report.md`. Did the fix land correctly in the skill? Is the issue genuinely resolved, or was the fix incomplete or incorrect?
- **Introduced new gaps, ambiguities, or dead-ends** — the fix for one issue may have created another
- **Changed the navigation path** for simulated scenarios in a way that helps or hurts

For each resolved issue you re-check:
- If the fix is correct and complete, leave the status as `resolved`
- If the fix is incomplete or incorrect, add a new finding in the Phase 8 section with a note explaining why the original resolution was insufficient
- Log your re-check in the Phase 8 Findings section regardless of outcome

Update `state.md`: mark step 8.2 complete.

### 3. Use DIFFERENT scenarios (Step 8.3)

Choose **different simulation scenarios** than Phase 5 used. The goal is broader coverage — don't re-test the same paths. If Phase 5 ran simulations 1-5 from the standard set in `phase-5-clarity-review.md`, choose scenarios that target:
- Different modules than the ones Phase 5 focused on
- Different communication boundaries
- Different task types (if Phase 5 tested bug fixes and onboarding, test cross-cutting features and refactoring)

If you cannot determine which scenarios Phase 5 used (e.g., the record is unclear), choose scenarios that target different modules and different communication boundaries than the most commonly documented areas.

Follow the same subagent dispatch protocol as Phase 5: dispatch one `opus` subagent per scenario, collect findings, merge into `_simulation_report.md`.

Update `state.md`: mark step 8.3 complete.

### 4. Attempt quick fixes (Step 8.5)

Before passing issues to Phase 9, resolve any that you can answer immediately from the skills or obvious code inspection:
- A cross-link points to the wrong file but the correct file is obvious — fix it
- A navigation gap exists but the information is actually in another skill — add the link
- A module skill is missing a relationship that is obvious from the code — add it

For each issue you fix, note the resolution in the Phase 8 section of `_simulation_report.md`.

Do not spend significant time on this. Issues that require reading source code in depth should remain open for Phase 9.

Update `state.md`: mark step 8.5 complete.

### 5. Check skip condition — can Phase 9 be skipped? (Step 8.6)

After completing your review, check `_simulation_report.md` and `_unresolved.md` (if it exists from Phase 6).

**Phase 9 can be skipped if ALL of the following are true:**
1. All issues from Phase 5 have status `resolved` and the resolutions verified as correct
2. All new issues found in Phase 8 were resolved in Step 8.5
3. `_unresolved.md` contains zero issues (or doesn't exist)
4. No simulation verdict is `insufficient`

**If Phase 9 can be skipped:**
- Report to the orchestrator that **Phase 9 can be skipped** — no human input is needed
- Update `_simulation_report.md` with a summary noting the skip recommendation

**If open or unresolvable issues remain:**
- Report the count and highest-priority gaps to the orchestrator
- These will be presented to the user in Phase 9

Update the summary section of `_simulation_report.md`:

```markdown
## Summary (after Phase 8)
- Total issues found (all phases): N
- Resolved: N
- Unresolvable (needs human input): N
- Open (needs human input): N
- New issues found in Phase 8: N
- Phase 9 skip recommended: yes | no
```

Update `state.md`: mark step 8.6 complete.

---

## Execution

Now read `phase-5-clarity-review.md` and execute the full clarity review procedure with the modifications above. The standard procedure steps map to the checklist as follows:

- Phase 5 Step 5.0 (Read state.md) → already done in Step 8.0
- Phase 5 Step 5.1 (Determine simulations) → Step 8.3 (use different scenarios)
- Resolved issue verification → Step 8.2 (new — not in Phase 5)
- Phase 5 Steps 5.2-5.6 (Prepare briefs, dispatch, collect, merge) → Step 8.3
- Review findings → Step 8.4
- Attempt quick fixes → Step 8.5
- Skip condition check → Step 8.6 (new — not in Phase 5)

Update `state.md` after each step completes.

When you have completed the full review:

1. Update `state.md`: mark Phase 8 complete with timestamp (step 8.7)
2. Report to the orchestrator:
   - Total issues found across all phases
   - How many resolved vs. open/unresolvable
   - Whether Phase 9 can be skipped
   - The highest-priority gaps (if any remain)
