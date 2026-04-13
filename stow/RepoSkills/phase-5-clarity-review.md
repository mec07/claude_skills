# Phase 5: Clarity Review

Phases 2-4 generated and validated skill files for the repository. Your job is to test whether those skills actually work by **simulating realistic agent tasks using ONLY the generated skills** — no access to source code. This replaces traditional fact-checking with a practical test: can an agent succeed using these docs alone?

**You are the orchestrator.** You dispatch simulation subagents that act as AI agents dropped into the repo with nothing but the skill files. Every point where they get stuck, confused, or make a wrong assumption is a gap in the documentation.

---

## Checklist

Copy this checklist into `state.md` under the Phase 5 entry. Mark each item `[x]` immediately upon completion.

```
- [ ] 5.0: Read state.md — determine repo tier and skill file locations
- [ ] 5.1: Determine which simulations to run (based on repo tier)
- [ ] 5.2: Prepare simulation briefs — one per simulation
- [ ] 5.3: Dispatch simulation subagents
- [ ] 5.4: Collect simulation outputs — verify all _sim_N.md files exist
- [ ] 5.5: Handle failed simulations (re-dispatch or run sequentially)
- [ ] 5.6: Merge findings — create _simulation_report.md
- [ ] 5.7: Delete per-simulation _sim_N.md files
- [ ] 5.8: Update state.md — mark Phase 5 complete with timestamp
```

---

## Inputs and Outputs

| Direction | File | Location | Description |
|---|---|---|---|
| **Input** | `state.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Repo path, slug, tier, phase progress |
| **Input** | All skill files | Target repo: `.ai/skills/` | The generated documentation to test |
| **Input** | Codebase | Target repo on disk | Source of truth (used ONLY by orchestrator for post-simulation verification, NOT by simulation subagents) |
| **Output** | `_sim_N.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Per-simulation findings (temporary — deleted after merge) |
| **Output** | `_simulation_report.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Merged findings with patterns and gap analysis |

---

## Updating state

After completing **each numbered step** below, immediately update `state.md`:

1. Mark the step's checkbox `[x]` in the Phase 5 checklist
2. Update the `updated:` timestamp

Do not batch state updates. If context is lost between steps, the recovery protocol relies on `state.md` being current. A completed step with no state update will be repeated on resume.

---

## Repo Tier Adaptation (Step 5.1)

Read `state.md` to determine the repo's size tier. Select simulations accordingly:

- **Tier A (small repos):** Run simulations 1 and 2 only
- **Tier B/C (standard+ repos):** Run all 5 simulations
- **Tier D (monorepos):** Run all 5 simulations + simulation 6 (cross-project change)

Update `state.md`: mark step 5.1 complete. Record which simulations will run.

---

## The 6 Standard Simulations

### Simulation 1: New Developer Onboarding
**Task:** You just cloned this repo. Get it running locally, understand its architecture, and identify where you would start working on a bug in the most critical module.

The agent must:
1. Find setup/install instructions
2. Determine prerequisites (runtimes, tools, versions)
3. Run the project locally
4. Understand the high-level architecture
5. Navigate to the right module for a hypothetical first task
6. Identify how to run tests

### Simulation 2: Bug Fix in Core Module
**Task:** A user reports that [core functionality based on repo] is producing incorrect output. Find the relevant module, understand its connections to other modules, plan a safe fix, and determine how to verify it.

The agent must:
1. Identify which module owns the reported behaviour
2. Understand that module's dependencies and dependents
3. Trace the data flow through the module
4. Plan which files to modify
5. Identify what tests to run and what side effects to check

### Simulation 3: Cross-Cutting Feature
**Task:** Add a new capability that touches 3+ modules (e.g., add a new field that propagates through input, processing, and output layers).

The agent must:
1. Identify all modules that need changes
2. Understand the order of changes (which module first?)
3. Trace data flow across module boundaries
4. Identify contracts/interfaces between modules
5. Plan the full change set

### Simulation 4: Add Tests for Untested Code
**Task:** Find a module or function that lacks tests, understand the testing patterns used in this repo, and write a matching test.

The agent must:
1. Understand the test framework and assertion patterns
2. Find test file locations and naming conventions
3. Identify test helpers, fixtures, or factories
4. Understand mocking patterns used in the project
5. Know how to run a single test vs. the full suite

### Simulation 5: Refactor Across Boundaries
**Task:** Rename or restructure a shared utility/type/interface that is consumed by multiple modules. Update all consumers safely.

The agent must:
1. Identify the shared code and all its consumers
2. Understand the dependency graph
3. Plan the refactor order to avoid breaking intermediate states
4. Know how to verify nothing broke (which tests, which checks)

### Simulation 6: Cross-Project Change (Monorepos Only)
**Task:** Make a change in a shared library/package that is consumed by 2+ projects within the monorepo.

The agent must:
1. Understand the monorepo structure (workspaces, packages)
2. Identify the shared package and its consumers
3. Understand the build/publish pipeline between packages
4. Plan the change including version bumps or protocol
5. Know how to test across project boundaries

---

## Subagent Dispatch Protocol (Steps 5.2-5.3)

### Preparing simulation briefs (Step 5.2)

For each simulation to run, prepare a brief that includes:

1. **Task description:** The simulation scenario adapted to this specific repo (replace generic descriptions with actual module names, actual functionality, actual file patterns from the skill files)
2. **Skill files to read:** List every file under `.ai/skills/` plus `CLAUDE.md`, `.github/copilot-instructions.md`, and any local context files
3. **Constraint:** "You have access ONLY to the skill files listed above. You must NOT read any source code files. Plan your task entirely from the documentation. Record every point where you get stuck, confused, or would need to guess."
4. **Output format:** The simulation findings format (see below)
5. **Output location:** `~/.claude/MEMORY/RepoSkills/<repo-slug>/_sim_N.md`

Update `state.md`: mark step 5.2 complete.

### Dispatching subagents (Step 5.3)

Dispatch one subagent per simulation using the `opus` model. Simulation requires judgment, creative scenario planning, and the ability to realistically model agent confusion — this is not mechanical work.

Each subagent:
1. Reads ONLY the skill files (not the codebase)
2. Plans the task step by step: which files to read, which to modify, what to check
3. Records every point where the documentation is insufficient
4. Writes findings to its `_sim_N.md` file

**Subagent prompt structure:**

```
You are an AI coding agent that has just been given a task on a codebase you have never seen.
Your ONLY source of information is the documentation files listed below. You must NOT read
any source code — pretend it does not exist.

TASK: [adapted task description]

DOCUMENTATION FILES: [list all skill file paths]

Read the documentation files now, then plan how you would complete the task. For each step
of your plan, record:
- What you would do
- Which doc told you to do it
- Whether the doc gave you enough information, or whether you had to guess

Write your complete findings to: [output path]
```

Update `state.md`: mark step 5.3 complete.

---

## Simulation Output Format

Each simulation subagent writes its findings to `~/.claude/MEMORY/RepoSkills/<repo-slug>/_sim_N.md`:

```markdown
## Simulation N: [name]

### Task
[Full task description as given to the agent]

### Steps Attempted
1. **[Action]** — Read [doc file]. Found [what]. [Sufficient / Insufficient — why]
2. **[Action]** — Looked for [info] in [doc file]. [Found it / Not found / Ambiguous]
3. [continue for all steps...]

### Issues Found
- **[skill file path]** — [gap/confusion/wrong assumption]. Severity: [blocking / degrading / minor]
  - Blocking: agent cannot proceed without this information
  - Degrading: agent can proceed but may make mistakes
  - Minor: agent can work around it but experience is suboptimal

### Missing Information
- [Specific information that should exist in the docs but doesn't]
- [Information that exists but is in the wrong place / hard to find]

### Wrong Assumptions
- [Places where the docs led the agent to an incorrect conclusion]
- [What the agent assumed vs. what would actually be true]

### Verdict
[sufficient / insufficient] — [1-2 sentence summary of whether the agent would succeed at this task using only these docs]
```

---

## Failure Handling (Step 5.5)

If a simulation subagent fails to produce its `_sim_N.md` file:

1. **Re-dispatch once** with the same brief. Some failures are transient.
2. **If it fails again:** the orchestrating agent runs that simulation sequentially — read only the skill files (not source code), trace through the task, and produce the `_sim_N.md` yourself.
3. **Log the failure** in `state.md` under Phase 5: `Simulation N: subagent failed twice, ran sequentially by orchestrator.`

Update `state.md`: mark step 5.5 complete (even if no failures occurred — mark it as "no failures").

---

## Collecting and Verifying Outputs (Step 5.4)

After all subagents complete:

1. Verify each expected `_sim_N.md` file exists
2. Verify each file contains the required sections (Steps Attempted, Issues Found, Verdict)
3. If any file is missing or malformed, trigger the failure handling protocol (Step 5.5)

Update `state.md`: mark step 5.4 complete.

---

## Merging Findings (Step 5.6)

After all simulations complete (including any failure recovery), create the merged report.

### Process

1. Read every `_sim_N.md` file
2. Extract all issues, grouping by the skill file they affect
3. Identify patterns: issues that appear across multiple simulations are higher priority
4. Deduplicate: if simulations 1 and 3 both found the same gap in `orientation.md`, merge them into one finding with both simulation numbers noted
5. Rank findings by severity and frequency

### Output: `_simulation_report.md`

Write to `~/.claude/MEMORY/RepoSkills/<repo-slug>/_simulation_report.md`:

```markdown
# Simulation Report

## Summary
- Simulations run: N
- Simulations passed (verdict: sufficient): N
- Simulations failed (verdict: insufficient): N
- Total unique issues found: N
- Blocking issues: N
- Degrading issues: N
- Minor issues: N

## Cross-Simulation Patterns
[Issues that appeared in 2+ simulations — these are the highest priority gaps]

- **[Pattern name]** — Found in simulations [N, N, N]. Affects [skill files]. [Description]

## Issues by Skill File

### [skill file path]
| # | Issue | Severity | Found in Simulations | Description |
|---|---|---|---|---|
| 1 | [short name] | blocking | 1, 3 | [detail] |
| 2 | [short name] | degrading | 2 | [detail] |

[repeat for each affected skill file]

## Issues by Simulation

### Simulation N: [name] — [sufficient/insufficient]
[Brief narrative: what worked, what didn't, where the agent would have failed]

## Unresolvable from Docs Alone
[Issues where the simulation agent needed information that may not exist in source code either — potential questions for the human]
```

Update `state.md`: mark step 5.6 complete.

---

## Cleanup (Step 5.7)

Delete all per-simulation working files:
- `_sim_1.md` through `_sim_6.md` (whichever were created)

Keep `_simulation_report.md` — it is the input for Phase 6.

Update `state.md`: mark step 5.7 complete.

---

## Completion

1. Verify `_simulation_report.md` exists and contains all required sections
2. Report to the orchestrator:
   - How many simulations passed vs. failed
   - Total issues found, broken down by severity
   - The top 3 highest-priority gaps (cross-simulation patterns first)
   - Whether any simulations found the docs entirely insufficient
3. Update `state.md`: mark Phase 5 complete with timestamp (step 5.8)

---

## Rules

- **Subagents must NOT access source code.** The entire point of this phase is to test whether the skill files alone are sufficient. If a subagent reads source code, its findings are invalid.
- **The orchestrator CAN access source code** — but only during the merge step, to verify whether an issue identified by a simulation is a real gap or a false positive caused by the simulation agent missing information that IS in the docs.
- **Do not fix issues in this phase.** This phase identifies problems. Phase 6 fixes them.
- **Log everything to working files.** Do not rely on memory. Every finding goes in `_sim_N.md` or `_simulation_report.md`.
- **Adapt simulations to the repo.** Do not run generic simulations. Replace placeholder descriptions with actual module names, actual functionality, and actual file patterns from the skill files. A simulation about "the core module" in a web app should reference the actual core module by name.
