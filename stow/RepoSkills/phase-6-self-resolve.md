# Phase 6: Self-Resolve & Refine

Phase 5 produced `_simulation_report.md` containing every gap, confusion point, and wrong assumption found by the clarity review simulation. Your job is to resolve as many of these as possible **from the source code**, update the affected skill files, and verify your fixes work.

**You are a fixer, not a reviewer.** Read the report, trace each issue to the source code, fix the documentation, and confirm the fix addresses the simulation failure.

---

## Checklist

Copy this checklist into `state.md` under the Phase 6 entry. Mark each item `[x]` immediately upon completion.

```
- [ ] 6.0: Read _simulation_report.md — tally issues by severity
- [ ] 6.1: Resolve blocking issues from source code
- [ ] 6.2: Resolve degrading issues from source code
- [ ] 6.3: Resolve minor issues from source code (time permitting)
- [ ] 6.4: Mark unresolvable issues for Phase 9
- [ ] 6.5: Check token budgets — verify skill files haven't grown beyond limits
- [ ] 6.6: Re-run targeted simulation to verify fixes
- [ ] 6.7: Update _simulation_report.md with resolution statuses
- [ ] 6.8: Update state.md — mark Phase 6 complete with timestamp
```

---

## Inputs and Outputs

| Direction | File | Location | Description |
|---|---|---|---|
| **Input** | `state.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Repo path, slug, phase progress |
| **Input** | `_simulation_report.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | All simulation findings from Phase 5 |
| **Input** | All skill files | Target repo: `.ai/skills/` | Documentation to update |
| **Input** | Codebase | Target repo on disk | Source of truth for resolving issues |
| **Output** | Updated skill files | Target repo: `.ai/skills/` | Documentation with gaps filled and errors corrected |
| **Output** | `_simulation_report.md` (updated) | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Issues annotated with resolution status |
| **Output** | `_unresolved.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Issues that require human input (input for Phase 9) |

---

## Updating state

After completing **each numbered step** below, immediately update `state.md`:

1. Mark the step's checkbox `[x]` in the Phase 6 checklist
2. Update the `updated:` timestamp

Do not batch state updates. If context is lost between steps, the recovery protocol relies on `state.md` being current. A completed step with no state update will be repeated on resume.

---

## Step 0: Read the Simulation Report (Step 6.0)

Open `~/.claude/MEMORY/RepoSkills/<repo-slug>/_simulation_report.md`. Read every issue. Tally:

- Total issues
- Blocking issues
- Degrading issues
- Minor issues
- Cross-simulation patterns (issues found in 2+ simulations)

Record these tallies in `state.md` under Phase 6 for reference during resolution.

Update `state.md`: mark step 6.0 complete.

---

## Step 1: Resolve Blocking Issues (Step 6.1)

Work through every issue with severity `blocking`, starting with cross-simulation patterns (highest priority — these affect the most agent tasks).

For each blocking issue:

1. **Read the relevant source code.** Open the files the simulation agent needed information about. Find the actual answer.
2. **If resolvable:** Update the affected skill file(s) with the correct information. Record what you found and what you changed.
3. **If NOT resolvable from code:** Mark as unresolvable. Record what specific question the human needs to answer and why the source code doesn't provide the answer.

### Resolution format

Update `_simulation_report.md` inline for each issue:

```markdown
| # | Issue | Severity | Found in Simulations | Description | **Resolution** |
|---|---|---|---|---|---|
| 1 | [short name] | blocking | 1, 3 | [detail] | **resolved** — [what was found, what was changed in which file] |
| 2 | [short name] | blocking | 2 | [detail] | **unresolvable** — [what was checked, why code doesn't answer it, specific question for human] |
```

### Evidence standards

- **Do not guess.** If the source code does not clearly answer the question, mark the issue as unresolvable. A wrong fix is worse than a known gap.
- **Read the actual code.** Do not resolve an issue based on file names, directory structure, or what seems likely. Open the file, read the implementation, find the answer.
- **Verify your fix is consistent.** After updating a skill file, check that your addition doesn't contradict other content in the same file or in other skill files.

Update `state.md`: mark step 6.1 complete.

---

## Step 2: Resolve Degrading Issues (Step 6.2)

Same process as Step 1, applied to all `degrading` severity issues. Prioritise cross-simulation patterns first.

Update `state.md`: mark step 6.2 complete.

---

## Step 3: Resolve Minor Issues (Step 6.3)

Same process as Step 1, applied to `minor` severity issues. These are lowest priority. If time or context budget is running low, it is acceptable to mark minor issues as deferred rather than unresolvable — note `deferred — minor severity, not blocking agent work` in the resolution column.

Update `state.md`: mark step 6.3 complete.

---

## Step 4: Compile Unresolvable Issues (Step 6.4)

Create `~/.claude/MEMORY/RepoSkills/<repo-slug>/_unresolved.md` listing every issue that could not be resolved from source code:

```markdown
# Unresolved Issues for Human Review

## Summary
- Total unresolvable issues: N
- Blocking: N
- Degrading: N
- Minor (deferred): N

## Issues

### Issue [N]: [short name]
- **Severity:** blocking | degrading | minor
- **Found in simulations:** [N, N]
- **Affects skill file:** [path]
- **What the simulation agent needed:** [specific information]
- **What was checked in source code:** [files read, what they showed]
- **Why it's unresolvable:** [specific reason — e.g., "business logic not documented in code", "configuration is environment-specific", "historical decision with no code comments"]
- **Specific question for human:** [the exact question that needs answering]
```

Update `state.md`: mark step 6.4 complete.

---

## Step 5: Check Token Budgets (Step 6.5)

Fixing gaps often means adding content. Skill files that grow too large become less useful — an agent that must read 10,000 tokens of documentation before starting work is slower and more likely to miss key details.

For each skill file that was modified in this phase:

1. Check the file's current size (approximate token count)
2. Compare against the budget established in Phase 2 (if recorded in `state.md` or the skill file itself)
3. If a file has grown significantly (>20% over budget):
   - Look for content that can be condensed without losing information
   - Look for details that can be moved to a more specific file (e.g., detailed API docs moved from `orientation.md` to a module-specific file)
   - Do NOT remove information that simulations showed agents need — instead, restructure for density

Log any budget concerns in `state.md` under Phase 6.

Update `state.md`: mark step 6.5 complete.

---

## Step 6: Re-run Targeted Simulation (Step 6.6)

After all resolutions are complete, verify your fixes work by re-running **one** targeted simulation — the simulation that found the most issues (highest count of blocking + degrading findings).

### Process

1. Identify which simulation had the most issues (check `_simulation_report.md`)
2. Dispatch a single `opus` subagent with the same simulation brief from Phase 5, but using the UPDATED skill files
3. The subagent follows the same protocol: read only skill files, plan the task, record every point of confusion
4. Compare the new simulation output against the original findings for that simulation

### Expected outcomes

- **Issues marked resolved should no longer appear.** If a resolved issue reappears, the fix was insufficient — note this for Phase 9.
- **New issues may appear.** If your fixes introduced new gaps or confusion, log them. Attempt to resolve them from source code. If unresolvable, add to `_unresolved.md`.
- **The verdict should improve.** If the simulation was `insufficient` before and is still `insufficient` after fixes, note the remaining gaps prominently.

### Output

Write the re-simulation findings to `~/.claude/MEMORY/RepoSkills/<repo-slug>/_sim_verify.md`. After analysis, delete this file.

Update `_simulation_report.md` with a verification section:

```markdown
## Verification Simulation
- Re-ran simulation: [N] ([name])
- Original verdict: [sufficient/insufficient]
- New verdict: [sufficient/insufficient]
- Previously reported issues resolved: N/N
- New issues found: N
- Regressions (resolved issues that reappeared): N
- Outstanding concerns: [list any remaining problems]
```

If the re-simulation still shows `insufficient` AND finds regressions or new blocking issues, note these in `_unresolved.md` for Phase 9.

Update `state.md`: mark step 6.6 complete.

---

## Step 7: Update the Report (Step 6.7)

Finalize `_simulation_report.md` with a resolution summary appended at the end:

```markdown
## Resolution Summary (Phase 6)
- Total issues from Phase 5: N
- Resolved from source code: N
- Unresolvable (needs human): N
- Deferred (minor): N
- Verification simulation verdict: [sufficient/insufficient]
- Regressions found during verification: N
- Net improvement: [brief assessment — e.g., "3 of 5 simulations would now pass"]
```

Update `state.md`: mark step 6.7 complete.

---

## Completion

1. Verify `_unresolved.md` exists (even if empty — write an empty summary if all issues were resolved)
2. Verify `_simulation_report.md` contains the Resolution Summary section
3. Report to the orchestrator:
   - How many issues resolved vs. unresolvable
   - Verification simulation result
   - Whether Phase 9 is needed (any unresolvable issues or regressions?)
   - If all issues resolved and verification passed: recommend skipping Phase 9
4. Update `state.md`: mark Phase 6 complete with timestamp (step 6.8)

---

## Rules

- **Same evidence standards — do not guess.** If you cannot find the answer in source code, mark it unresolvable. A fabricated fix is worse than a documented gap.
- **Fix the docs, not the report.** The simulation report describes problems. Your job is to fix the actual skill files so agents can use them. Update the report to track your progress, but the real output is better documentation.
- **Do not remove content that simulations showed agents need.** If a simulation found a gap, the answer is to add information, not to remove the question.
- **Check consistency after every fix.** A fix to `orientation.md` may contradict what `modules/auth.md` says. Read the surrounding context before and after your edit.
- **Update working files as you go.** Do not rely on memory. Every resolution, every unresolvable issue, every verification finding goes in a file immediately.
- **Prioritise by severity and frequency.** Blocking issues first, then degrading, then minor. Within each severity, cross-simulation patterns first.
