# Orchestration Reference

Everything a phase agent needs to know about HOW the RepoSkills pipeline works. This file is the single source of truth for state management, context recovery, pipeline execution, parallelisation, global rules, and repo adaptation.

Phase agents: read your phase instruction file for WHAT to do. Read this file for HOW the pipeline operates around you.

---

## Table of Contents

1. [State Management](#state-management)
2. [Context Recovery Protocol](#context-recovery-protocol)
3. [Pipeline Execution Protocol](#pipeline-execution-protocol)
4. [Parallelisation Guide](#parallelisation-guide)
5. [Global Rules](#global-rules)
6. [Anti-Patterns](#anti-patterns)
7. [Repo Size Adaptation](#repo-size-adaptation)
8. [Update Modes](#update-modes)
9. [Token Budgets](#token-budgets)

---

## State Management

All working files and state live in `~/.claude/MEMORY/RepoSkills/<repo-slug>/`, where `<repo-slug>` is the repository directory name (e.g., `my-project`). This keeps working files out of the target repo and enables context recovery.

### State file: `state.md`

The template below shows Phase 2's sub-steps as an example. **When each phase agent starts, it must expand its phase entry** by copying the checklist from its phase instruction file into `state.md`. This ensures recovery can resume at the exact sub-step.

```markdown
# RepoSkills State

repo: /absolute/path/to/repo
slug: repo-directory-name
commit: <git-commit-hash-at-start>
tier: <A|B|C|D>
started: ISO-timestamp
updated: ISO-timestamp
update-mode: <fresh|targeted|diff|full>

## Detected Platforms
- [ ] Claude Code
- [ ] Cursor
- [ ] Copilot
- [ ] Windsurf
- [ ] JetBrains AI
- [ ] Amazon Q
- [ ] Cline
- [ ] Codex / Zed

## Phases
- [x] 0: Discover & Triage (completed ISO-timestamp)
- [ ] 1: Domain Interview
- [ ] 2: Map & Generate (in progress)
  - [x] 2.1: Confirm boundaries (read _triage.md, verify each boundary candidate)
  - [x] 2.2: Generate orientation skill (.ai/skills/orientation.md)
  - [ ] 2.3: Generate module skills (.ai/skills/modules/<name>.md, parallel for large repos)
  - [ ] 2.4: Generate task skills (.ai/skills/tasks/<name>.md, conditional)
  - [ ] 2.5: Generate platform glue (AGENTS.md, CLAUDE.md, .cursorrules, copilot-instructions.md, per-module routing)
  - [ ] GATE: All skills pass token budget check
  - [ ] 2.6: Self-review checklist
- [ ] 3: Refine
- [ ] 4: Validate
- [ ] 5: Clarity Review
- [ ] 6: Self-Resolve
- [ ] 7: Validate Pass 2
- [ ] 8: Clarity Review 2
- [ ] 9: Human Checkpoint

## Repo Size Tier
- tier: B
- files: 237
- modules: 8
- rationale: "50-500 files, single project"

## Coverage
- Modules: [list]
- Task skills: [list]
- Skipped (5-second grep): [list with rationale]

## Update History
| Date | Mode | Changed | Commit |
|------|------|---------|--------|
| ISO-timestamp | fresh | all | abc1234 |
```

**After Phase 0 completes:** The orchestrator MUST extract the tier classification from `_triage.md` and write it to `state.md` in the `tier:` field and the `## Repo Size Tier` section. All subsequent phases rely on this value.

### Phase numbering

```
Phase 0: Discover & Triage
Phase 1: Domain Interview
Phase 2: Map & Generate
Phase 3: Refine
Phase 4: Validate
Phase 5: Clarity Review
Phase 6: Self-Resolve
Phase 7: Validate Pass 2
Phase 8: Clarity Review 2
Phase 9: Human Checkpoint
```

### Working files in MEMORY

| File | Created by | Used by | Deleted | Purpose |
|---|---|---|---|---|
| `state.md` | Orchestrator | All phases | Never (permanent record) | Phase progress, repo path, tier, platforms |
| `_triage.md` | Phase 0 | Phases 1, 2 | Phase 9 cleanup | Repo classification, existing skill assessment |
| `_boundaries.md` | Phase 2 | Phases 2, 3 | Phase 9 cleanup | Confirmed module boundaries with evidence |
| `_manifest.md` | Phase 2 | Phases 3, 4, 5, 6, 7, 8, 9 | Phase 9 cleanup | File disposition: generated vs preserved vs skipped |
| `_simulation_report.md` | Phase 5 | Phases 6, 8, 9 | Phase 9 cleanup | Simulation results: gaps, failures, missing routing |
| `_unresolved.md` | Phase 6 | Phase 9 | Phase 9 cleanup | Issues that require human judgment |
| `_questions.md` | Phase 2 | Phase 9 | Phase 9 cleanup | Questions flagged during generation for human review |
| `_drift_report.md` | DR.1-DR.10 | Drift resolution only | Overwritten on next drift run (audit trail) | Triage decisions, patches, accuracy results |
| `_drift_patch_<name>.md` | DR subagents | DR merge | End of DR | Per-skill drift patch output |
| `_explore_<area>.md` | Phase 2 subagents | Phase 2 merge | End of Phase 2 | Per-area exploration output |
| `_skill_<name>.md` | Phase 2 subagents | Phase 2 merge | End of Phase 2 | Per-skill draft output |
| `_sim_<scenario>.md` | Phase 5 subagents | Phase 5 merge | End of Phase 5 | Per-scenario simulation output |

**Repo output file:** `.ai/skills/domain-context.md` -- written by Phase 1, consumed by all subsequent phases. Lives in the target repo, not MEMORY. Treated as a trusted baseline by Phase 0 on re-runs. Phase 1 reads `domain-context.md` directly from the repo (there is no separate `_domain.md` working file).

### Manifest format (`_manifest.md`)

All phases that read the manifest expect this exact format:

```markdown
# Skill Manifest

## Core Skills
| File | Disposition | Token Est. | Budget | Notes |
|------|-------------|------------|--------|-------|
| orientation.md | generated | 1.8k | <2k | |
| domain-context.md | preserved | 1.9k | <2k | From Phase 1 |

## Task Skills
| File | Disposition | Token Est. | Budget | Notes |
|------|-------------|------------|--------|-------|
| tasks/running-tests.md | generated | 1.3k | <1.5k | |
| tasks/deployment-ci.md | generated | 1.1k | <1.5k | |
| tasks/database-operations.md | skipped | n/a | n/a | No database detected |

## Module Skills
| File | Disposition | Token Est. | Budget | Notes |
|------|-------------|------------|--------|-------|
| modules/auth.md | generated | 1.4k | <1.5k | |
| modules/billing.md | generated | 1.3k | <1.5k | |
| modules/legacy-api.md | orphaned | n/a | n/a | Module deleted from codebase |

## Platform Glue
| File | Disposition | Notes |
|------|-------------|-------|
| AGENTS.md | generated | Self-sufficient entry point for Codex, Zed, JetBrains |
| CLAUDE.md | generated | Self-sufficient entry point for Claude Code |
| .github/copilot-instructions.md | generated | Self-sufficient entry point for GitHub Copilot |
| .cursorrules | generated | Self-sufficient entry point for Cursor |
| .cursor/rules/auth.mdc | generated | Per-module routing |
| .claude/rules/auth.md | generated | Per-module routing |

## Tools
| File | Disposition | Notes |
|------|-------------|-------|
| .ai/skills/Tools/skill-drift.sh | generated | Drift detection — compares skill freshness against code changes |
| .ai/skills/Tools/skill-drift-hook.sh | generated | Hook manager — install/uninstall drift check as local git hook |
```

**Disposition values:** `generated` (written from scratch), `preserved` (kept from previous run), `orphaned` (module deleted -- flagged for deletion), `skipped` (not warranted for this repo), `updated` (regenerated during targeted/diff update).

### File lifecycle by phase end

- **End of Phase 0:** `state.md` + `_triage.md`
- **End of Phase 1:** `state.md` + `_triage.md` (+ `domain-context.md` in repo)
- **End of Phase 2:** `state.md` + `_triage.md` + `_boundaries.md` + `_manifest.md` + `_questions.md`
- **End of Phase 3:** `state.md` + `_triage.md` + `_boundaries.md` + `_manifest.md` + `_questions.md`
- **End of Phase 4:** `state.md` + `_triage.md` + `_manifest.md` + `_questions.md`
- **End of Phase 5:** `state.md` + `_triage.md` + `_manifest.md` + `_questions.md` + `_simulation_report.md`
- **End of Phase 6:** `state.md` + `_triage.md` + `_manifest.md` + `_questions.md` + `_simulation_report.md` + `_unresolved.md`
- **End of Phase 7:** `state.md` + `_triage.md` + `_manifest.md` + `_questions.md` + `_simulation_report.md` + `_unresolved.md`
- **End of Phase 8:** `state.md` + `_triage.md` + `_manifest.md` + `_questions.md` + `_simulation_report.md` + `_unresolved.md`
- **End of Phase 9:** `state.md` + `_boundaries.md` + `_manifest.md` (all other `_` files deleted after human review)

---

## Context Recovery Protocol

When resuming after a context clear:

1. **List projects.** Read `~/.claude/MEMORY/RepoSkills/` -- list subdirectories to find the active project.
2. **Read state.** Read `state.md` in the project directory.
3. **Validate state.md integrity** before proceeding:
   - All `completed` timestamps are chronological (no phase completed before its predecessor)
   - No phase is marked both complete and in-progress
   - If the current phase has sub-steps, at least one is unchecked (otherwise it should be marked complete)
   - The `commit` hash matches an actual commit in the repo's git history
   - The `tier` value is consistent with the file count
   - If corruption is detected, report to the user and request guidance -- do not guess the correct state
4. **Determine the next unchecked item** in the checklist.
5. **Read the phase instruction file** for the current phase.
6. **Skip to the next unchecked step** and continue from there.
7. **If a phase is marked complete,** proceed to the next unchecked phase.

**Critical:** Always update `state.md` immediately after completing each step. This is what makes recovery work. If you complete a step but don't update state, that work will be repeated on resume.

---

## Pipeline Execution Protocol

The full pipeline has **10 phases** (Phase 0 through Phase 9). **Each phase MUST run in its own context window.** Spawn a new agent for each phase. State passes between phases exclusively via files on disk -- the working files in `~/.claude/MEMORY/RepoSkills/<repo-slug>/` and the skill files in the target repo's `.ai/skills/` directory plus root platform glue files.

```
Phase 0: Discover & Triage       -> classify repo, detect platforms, find boundaries, assess existing skills
Phase 1: Domain Interview         -> capture business context (interactive, skippable)
Phase 2: Map & Generate           -> confirm boundaries, generate all skills + platform glue
Phase 3: Refine                   -> assess structure, restructure, expand coverage
Phase 4: Validate                 -> adversarial fact-check
Phase 5: Clarity Review           -> simulate agent tasks, find gaps
Phase 6: Self-Resolve             -> fix gaps from simulation, resolve what can be resolved
Phase 7: Validate Pass 2          -> re-verify after fixes
Phase 8: Clarity Review 2         -> re-simulate, find remaining gaps
Phase 9: Human Checkpoint         -> Reverse Glossary + unresolvable issues
```

### Phase instructions

Each phase reads its instructions from a dedicated file in this skill directory:

| Phase | Instruction file | Input (on disk) | Output (on disk) |
|---|---|---|---|
| 0 | `phase-0-discover.md` | Codebase, existing skills/docs | `MEMORY: _triage.md` |
| 1 | `phase-1-domain-interview.md` | `_triage.md` + human input | `.ai/skills/domain-context.md` |
| 2 | `phase-2-map-generate.md` | `_triage.md` + `domain-context.md` (from repo) + codebase | `.ai/skills/**`, platform glue, `MEMORY: _boundaries.md`, `_questions.md` |
| 3 | `phase-3-refine.md` | All Phase 2 output + `_triage.md` + `_boundaries.md` + codebase | All skills restructured and expanded |
| 4 | `phase-4-validate.md` | All skills + codebase | Skills with errors fixed, `MEMORY: _audit.md` |
| 5 | `phase-5-clarity-review.md` | All skills + codebase | `MEMORY: _simulation_report.md` |
| 6 | `phase-6-self-resolve.md` | `_simulation_report.md` + all skills + codebase | Skills updated, `MEMORY: _unresolved.md` |
| 7 | `phase-7-validate-2.md` | All skills + `_simulation_report.md` + codebase | `MEMORY: _audit.md` rebuilt |
| 8 | `phase-8-clarity-review-2.md` | All skills + `_simulation_report.md` + codebase | `_simulation_report.md` updated |
| 9 | `phase-9-human-checkpoint.md` | `_unresolved.md` + `_questions.md` + all skills | Final skill updates, MEMORY cleanup |
| DR | `phase-drift-resolve.md` | `state.md`, `_boundaries.md`, `_manifest.md`, drift JSON, codebase | Updated/new skills, `MEMORY: _drift_report.md` |

`MEMORY:` prefix means the file lives in `~/.claude/MEMORY/RepoSkills/<repo-slug>/`.

### Phase execution

When running the full pipeline:

1. **Create the MEMORY directory:** `mkdir -p ~/.claude/MEMORY/RepoSkills/<repo-slug>/`
2. **Record the current git commit hash:** `git rev-parse HEAD` -- store in `state.md` as `commit:`
3. **Write initial `state.md`** with the repo path, commit hash, and all phases unchecked
4. **For each phase:**
   a. **For Tier A repos, check the fast path rules** (see [Tier A Fast Path](#tier-a-small-repos-50-files)) **before dispatching each phase.** Skip or collapse phases as specified.
   b. Spawn a new agent **at maximum effort**
   c. Pass it the phase instruction file AND the global rules section from this file
   d. Tell the agent the MEMORY directory path and target repo path
   e. The agent reads the instruction file and executes thoroughly
   f. The agent updates `state.md` -- marks the phase complete with timestamp
   g. On completion, the agent reports a summary of what was done
5. **After Phase 0 completes:** Extract the tier classification from `_triage.md` and write it to `state.md` in the `tier:` field and the `## Repo Size Tier` section.
6. **Report progress to the user** after each phase: "Phase X complete. [Brief summary -- e.g., '8 skills generated, 3 task skills, 5 modules', '2 gaps found in simulation']. Proceeding to Phase Y." This keeps the user informed during long-running pipelines.
7. **Proceed to the next phase**

**Every phase MUST run at maximum effort.** This is non-negotiable. These are complex, accuracy-critical tasks that require careful reading of source code, thorough verification, and precise skill content. Reduced effort produces hallucinations and useless skills.

### Inter-phase decisions

**Between Phases 0 and 2 -- Phase 1 (Domain Interview) decision:** The orchestrator checks whether Phase 1 should run. If `.ai/skills/domain-context.md` exists AND Phase 0 scored it high-confidence AND its `Last interview` timestamp is within 6 months, skip Phase 1 and proceed to Phase 2. If the user invoked with `--interview` or `--redo-interview`, always run Phase 1 regardless. Otherwise, run Phase 1.

**Between Phases 8 and 9 -- Phase 9 skip condition:** Phase 9 can be skipped if ALL THREE of the following are true:
1. `_unresolved.md` contains zero issues (or does not exist)
2. The Reverse Glossary finds zero new domain terms
3. `_questions.md` contains no unanswered questions (no modules flagged with missing info)

If all three conditions are met, skip Phase 9, proceed directly to cleanup, and inform the user that no human input is needed.

### Cleanup

When the pipeline completes (after Phase 9, or after Phase 8 if Phase 9 is skipped):

1. Delete all `_` prefixed working files from `~/.claude/MEMORY/RepoSkills/<repo-slug>/` **except** `_boundaries.md` and `_manifest.md` -- these are preserved for diff-based re-runs
2. Update `state.md` to mark all phases complete
3. Update `state.md` `commit:` field to the current HEAD (in case commits happened during the run)
4. Report the final summary to the user including: number of skills generated, token budget compliance, platforms configured, and any known limitations

---

## Parallelisation Guide

### When to parallelise

| Phase | Parallelise when... | Pattern |
|---|---|---|
| 0: Discover & Triage | Repo has 50+ files in potential doc/config locations | Parallel discovery subagents |
| 2: Map & Generate (explore) | Repo has 10+ major directories | One subagent per major area |
| 2: Map & Generate (skills) | 5+ skill files to write | One subagent per skill file |
| 2: Map & Generate (platform) | 3+ platform glue files | One subagent per platform |
| 5: Clarity Review | Always (5+ scenarios) | One subagent per scenario |
| Other phases | Generally not worth parallelising | Sequential execution |

**Batching for large repos (Tier C/D):** For repos requiring 30+ parallel subagents (e.g., 40+ module skills to write), dispatch in waves of 10-15 subagents. Wait for each wave to complete before dispatching the next. This keeps coordination overhead manageable and limits the blast radius of failures. Within each wave, apply the standard failure recovery protocol (re-dispatch once, then sequential fallback).

### Subagent dispatch protocol

1. **Define tasks:** List the independent work units (areas to explore, skills to write, scenarios to simulate)
2. **Write task context inline:** Each subagent prompt must include ALL context it needs -- the full task description, relevant file paths, rules to follow, and output file path. Do NOT reference other files the subagent would need to read for instructions (except the codebase itself).
3. **Assign output files:** Each subagent writes to a unique file in the MEMORY directory (e.g., `_explore_backend.md`, `_skill_auth.md`, `_sim_new_feature.md`)
4. **Dispatch in parallel:** Use the Agent tool with `run_in_background: true` for all subagents simultaneously
5. **Collect and merge:** When all subagents complete, read their output files and integrate the results

### Subagent lifecycle and failure handling

**How subagents work:** The Agent tool with `run_in_background: true` spawns an independent agent. You are automatically notified when it completes. The subagent's output file on disk is the contract -- if the file exists and is well-formed, the subagent succeeded.

**Failure detection:** After notification that a subagent completed, check for its output file:
- **File exists and is complete:** Success. Proceed to merge.
- **File exists and is complete but includes a `## Concerns` section:** DONE_WITH_CONCERNS. Merge the output but flag the concerns for the orchestrating agent to review. The subagent completed its task but isn't confident about specific claims. Address concerns during the merge step or flag for later validation.
- **File exists but is incomplete** (truncated, missing sections): Treat as failure.
- **File does not exist:** Subagent failed entirely.

**Failure recovery:** For any failed subagent:
1. **Re-dispatch once** with the same task. Subagent failures are often transient (context limits, temporary errors).
2. **If it fails again:** Fall back to sequential processing -- the orchestrating agent performs that subagent's work itself. **Write the output to the same file the subagent would have written** (e.g., `_explore_<area>.md`, `_skill_<name>.md`, `_sim_<scenario>.md`). This ensures the merge step finds the output regardless of whether a subagent or the orchestrator produced it.
3. **Log the failure** in `state.md` as a note under the current phase: `<!-- Subagent failure: [area/skill/scenario], fell back to sequential -->`
4. **Never block the pipeline** on a failed subagent. The sequential fallback ensures forward progress.

### Model selection for subagents

| Task type | Recommended model | Reasoning |
|---|---|---|
| Explore a single directory/module | `sonnet` | Mechanical reading and summarising |
| Write a single skill file from notes | `sonnet` | Structured writing from clear inputs |
| Generate platform glue from template | `sonnet` | Mechanical transformation |
| Boundary verification | `sonnet` | Mechanical reading and classification |
| Simulate a cross-cutting agent scenario | `opus` | Requires judgment and creative thinking |
| Merge subagent outputs into final skills | `opus` | Requires synthesis and consistency |
| Self-review of generated skills | `opus` | Requires critical thinking |
| Resolve simulation gaps against code | `opus` | Requires judgment about what matters |
| Reverse Glossary generation | `opus` | Requires deep domain understanding |

Use the `model` parameter on the Agent tool to select the model. When in doubt, use the default (inherits parent model).

---

## Global Rules

Every phase instruction file must be read alongside these rules. These are non-negotiable.

### The 5-second grep test

**If an agent can find information via a single grep/glob in under 5 seconds, it does NOT belong in a skill.** Skills contain ONLY:

- **WHY** things exist -- design rationale, historical context, non-obvious constraints
- **HOW** they connect -- cross-module relationships, data flow, side effects, change propagation
- **WHAT breaks** if you change them -- hidden coupling, downstream effects, invariants
- **WHERE to start** -- routing to the right file/module for a given task

Skills do NOT contain:
- File listings that `ls` or `glob` would produce
- Function signatures that LSP or grep would find
- Import graphs that static analysis would generate
- Config values that reading the config file would reveal
- Type definitions that jumping to definition would show
- Package versions that `package.json`/`go.mod`/`requirements.txt` would reveal

**Test every claim before writing it:** Could an agent find this in under 5 seconds with grep/glob/LSP? If yes, delete it. Replace it with the routing hint: "See `path/to/file`" or nothing at all.

### Context window discipline

**Never browse these directories:**
- `node_modules/`, `vendor/`, `.venv/`, `venv/`, `env/`
- `dist/`, `build/`, `.next/`, `out/`, `target/`
- `__pycache__/`, `.turbo/`, `.cache/`, `.parcel-cache/`
- `.git/` (use git commands instead)
- Any other generated/dependency/output directories

**Use LSP tooling** for type definitions in dependencies. Do not read dependency source code -- read import statements and usage in the project's own code.

**Large file strategy:** For files over 500 lines, read the first 50 lines (module docstring, imports, class/function declarations) and the last 20 lines. Use grep to find specific patterns. Do not read the entire file unless the phase instruction specifically requires it.

### Accuracy

- **Do not hallucinate.** Every claim must be verified against actual source code.
- **Do not infer from filenames.** You must read a file before making any claim about its contents.
- **Do not invent** APIs, endpoints, schemas, services, commands, or architectural patterns.
- If you cannot verify something, mark it `<!-- TODO: verify -->` or remove it. Do not fill gaps with plausible guesses.
- **Wrong skills are worse than no skills.** An agent that acts on incorrect routing information will produce worse code than an agent with no routing information.

### Evidence

- Every file path referenced must exist. Verify with `ls` or Glob before writing it into a skill.
- Every command documented must come from `package.json` scripts, `Makefile`, `Taskfile.yml`, CI config, or equivalent for the repo's language. Standard tool commands (`go test`, `cargo build`, `pytest`, `rspec`) are valid if the tool is in the project's dependency config. Do not invent commands.
- Every script documented must exist at the stated path. Verify run commands, arguments, and environment variables against the actual script code.
- Every architectural claim must be traceable to actual imports, calls, or config in source code.
- For every inter-component communication path: find the sender code AND the receiver code. Verify the mechanism and the data contract.

### Writing style

- Short sections, dense content. No filler, no introductions, no marketing prose.
- Concrete over abstract: exact file paths, real commands, actual dependency names.
- "X generates Y from Z" over "X handles generation."
- Bullet points over paragraphs for factual content.
- File paths are better than descriptions.
- **Never copy schemas, types, or table definitions into skills.** Point to the source file instead.
- **Prefer routing over explaining.** "For auth flow, see `src/auth/middleware.ts:validateToken()`" is better than explaining how auth works.
- **Use imperative voice for agent instructions.** "Read `X` before modifying `Y`" not "You should read X before modifying Y."

### Structure

- `.ai/skills/` contains the detailed skill layer (orientation, modules, tasks, domain context). Root platform files (CLAUDE.md, AGENTS.md, .cursorrules, copilot-instructions.md) are each self-sufficient — they contain all 12 required sections and do not redirect to each other. Root files intentionally overlap by design for compaction safety.
- Within the skill layer, every fact lives in exactly one place. Root platform files are exempt from this rule — their overlap is by design.
- Cross-link aggressively between skills. No orphan skills.
- Module skills should map to real, coherent boundaries in the codebase -- not to directories.
- Task skills should map to real workflows agents perform -- not to abstractions.
- Content that would appear in `conventions.md`, `dependency-map.md`, or `workflows.md` as separate files instead lives in `orientation.md` and individual module skills. Do not generate these as standalone output files.

### Exploration

- Always exclude from file exploration: `node_modules`, `.git`, `dist`, `build`, `.next`, `__pycache__`, `.turbo`, `.cache`, `vendor`, `target`, `.venv`, `.tox`, and any other generated/dependency directories.
- Use git-tracked files as the ground truth for what exists: `git ls-files` is authoritative.

### Trusted baseline

- Phase 0 produces `_triage.md` -- a classification of the repo, its boundaries, and any existing skill/doc assessment. All subsequent phases use this file to understand the repo's shape.
- If existing skills are found in `.ai/skills/`:
  - **High-confidence** skills should be preserved and updated incrementally.
  - **Medium-confidence** skills provide useful starting points but their claims should be verified.
  - **Low-confidence** skills should be regenerated from scratch.
- Do not assume any particular file is the most reliable. Let the Phase 0 assessment guide you.

### Scratchpad discipline

- Use the working files in `~/.claude/MEMORY/RepoSkills/<repo-slug>/` as your scratchpad. Log findings as you go. **Do not rely on memory** -- these files are how state passes between context windows.
- **Update `state.md` after every completed step.** This is mandatory. Mark the step `[x]` immediately when done.

---

## Anti-Patterns

Watch for these rationalizations and resist them:

- **"This phase is simple enough to skip"** -- Every phase exists for a reason. Phase 5 catches gaps Phase 2 introduced. Skipping phases degrades quality invisibly.
- **"I remember what the code does"** -- You don't. Read the file. Every time.
- **"This is probably right"** -- Probably is not verified. Check it or mark it `<!-- TODO: verify -->`.
- **"I'll update state.md later"** -- Update it now. If you don't, context recovery fails and work gets repeated.
- **"The subagent will figure it out"** -- Give the subagent complete context inline. Don't assume it can read your mind or navigate to find instructions.
- **"This skill is too small to need simulation"** -- Small skills can have wrong routing just as easily as large ones.
- **"This information is useful, so it belongs in a skill"** -- Apply the 5-second grep test. Useful is not the same as non-discoverable.
- **"I need to explain how this works"** -- Skills route, they don't explain. "See `src/auth/jwt.ts:verify()`" beats a paragraph about JWT verification.
- **"The token budget is too tight"** -- The guideline forces you to prioritize. If you're well over, you're likely including greppable content. But don't truncate — investigate first.
- **"All modules need full skills"** -- Coverage tiering exists for a reason. Tier 3 modules get a one-liner in orientation.md, not their own file.
- **"I should include the type definitions"** -- Never. Point to the file. The agent will read it when it needs to.
- **"Let me browse node_modules/vendor/.venv to understand this dependency"** -- Never. Read the import and usage in project code. Use LSP for type definitions.
- **"This file list is useful context"** -- No. It fails the 5-second grep test. Cut it.
- **"I'll include the full schema for convenience"** -- No. Point to the source file. Schemas change; your copy will go stale.
- **"This module is too complex for 1.5k tokens"** -- Then you are including greppable information. Cut the WHAT, keep the WHY and the GOTCHAS.
- **"This module doesn't need a gotchas section"** -- If you found no gotchas, say "None found." Don't silently omit the section -- the agent needs to know you checked.
- **"The orientation skill covers this, so the module skill can skip it"** -- Module skills must be useful standalone. The agent may read the module skill without the orientation. Include what matters.
- **"I should include this env var for completeness"** -- Does it fail the 5-second grep test? Then don't include it.

---

## Repo Size Adaptation

Phase 0 classifies the repo into a tier. The tier determines skill scope, parallelism requirements, and simulation depth.

| Tier | Size | Criteria | Skills generated | Parallelism | Simulations |
|------|------|----------|-----------------|-------------|-------------|
| A: Small | <50 files | Single-purpose, few directories | orientation.md + maybe 1 module skill + platform glue | None (sequential) | 2 of 6 scenarios |
| B: Standard | 50-500 files | Typical app or library | Full set | Optional | All 5 standard scenarios |
| C: Large | 500+ files | Large application, many modules | Full set with coverage tiering | Required (waves of 10-15) | All 5 standard + 1 custom |
| D: Monorepo | Multi-project | Multiple `package.json`/`go.mod`/`Cargo.toml`/`pyproject.toml`/projects detected | Full set + per-project workflows | Required (waves of 10-15) | All 5 standard + Cross-Project |

### Tier A: Small repos (<50 files)

- Skip task skills unless a non-obvious workflow exists (e.g., complex test setup)
- orientation.md can be the only skill if the repo is simple enough
- Platform glue is still generated (AGENTS.md, CLAUDE.md, etc.)
- Simulation runs only 2 of 6 scenarios (the two most relevant -- typically New Developer Onboarding and Bug Fix in Core Module)
- **Total expected output: 3-5 files, ~5 minutes**
- **Parallelisation:** None

**Tier A Fast Path:**
For repos classified as Tier A (<50 files, <5 directories), the orchestrator MAY collapse the pipeline:
- **Phase 0:** Run normally (quick -- 2-3 minutes)
- **Phase 1:** Run if `domain-context.md` is needed (skip if exists and fresh)
- **Phase 2:** Run normally -- this is where all the real work happens
- **Phase 3:** SKIP -- for repos this small, Phase 2's self-review is sufficient
- **Phase 4:** Run as part of Phase 2's self-review (embed the 14 validation checks inline)
- **Phase 5:** Run 2 simulations (onboarding + bug fix)
- **Phase 6:** Run only if Phase 5 found issues
- **Phase 7:** SKIP -- single validation pass is sufficient
- **Phase 8:** SKIP -- Phase 5's simulations are sufficient
- **Phase 9:** Run only if unresolved issues exist

This brings Tier A from 10 phases to 4-6 phases, ~15 minutes total.

### Tier B: Standard repos (50-500 files)

- Full skill set generated
- Task skills generated for detected workflows (tests, deployment, database, auth, etc.)
- Parallelism is optional -- sequential execution is fine if the agent can handle it in one pass
- **Total expected output: 8-15 files, ~15-25 minutes**
- **Parallelisation:** Optional for module skills

### Tier C: Large repos (500+ files)

- Full skill set required
- Parallel exploration and generation is required to stay within reasonable time
- Module skills batched in waves of 10-15
- Coverage tiering for modules:
  - **Tier 1** (full module skills): the 10 most important/most-connected modules -- determined by dependency count, entry point status, or cross-module import frequency
  - **Tier 2** (summary skills): next 15-20 modules -- entry point, purpose, key files, 1 key relationship
  - **Tier 3** (orientation mention only): remaining modules -- listed in orientation.md with one-line descriptions
- **Total expected output: 15-40 files, ~30-60 minutes**
- **Parallelisation:** Required (waves of 10-15)

### Tier D: Monorepo

- Everything from Tier C, plus:
- Per-project workflows if projects have different build/test/deploy commands
- Cross-project dependency map showing inter-project relationships
- Cross-Project simulation scenario in Phase 5
- Module skills may span projects -- group by domain, not by project boundary
- **Total expected output: 20-60+ files, ~45-90 minutes**
- **Parallelisation:** Required (waves of 10-15)

---

## Update Modes

### Full run (`--fresh` or first time)

Complete pipeline (all phases 0-9). Ignores all existing skills. Regenerates everything from scratch.

### Targeted update (`--update <module-or-task>`)

Fast path for updating a single skill:

1. Read `state.md` to get the stored commit hash and tier
2. Read the existing skill file for the specified module/task
3. Re-explore the relevant codebase area (the module's directory, or the task's relevant files)
4. Regenerate the skill file
5. Update the manifest

#### ⛔ VALIDATION GATE — must pass before finalising

**Do NOT proceed to step 8 until this gate passes.** The full pipeline enforces validation via separate agent phases (4, 5, 7, 8) that cannot be skipped. This gate is the update-path equivalent — it is mandatory, not advisory.

6. **Run 1 targeted simulation:** Dispatch a separate agent (model: sonnet) with the updated skill loaded as context. Give it a realistic task that exercises the skill's routing, key rules, and at least one module-specific workflow. The simulation agent must NOT be the same agent that wrote the skill — self-review is what this gate exists to prevent.
7. **Evaluate and fix:** Read the simulation result. If the agent made errors that correct skill content would have prevented, fix the skill and re-run the simulation. Repeat until the simulation passes cleanly or you have identified issues that require human input (in which case, flag them and do not update the commit hash).

**Gate failure:** If after 2 fix-and-retry cycles the simulation still fails, STOP. Report the failures to the user and ask for guidance. Do not update `state.md` — the update is incomplete.

8. Update `state.md` commit hash — **only after the validation gate passes**

**Expected time: 3-5 minutes.** No domain interview, no full simulation, no human checkpoint.

### Diff-based update (default re-run)

When skills already exist and `--fresh` is not specified:

1. Read `state.md` to get the stored commit hash
2. Run `git diff --name-only <stored-commit>..HEAD` to find changed files
3. Map changed files to modules using `_boundaries.md` (or regenerate boundaries if the file is missing)
4. **Detect new modules:** Check if any changed files are in directories that have NO entry in the stored `_boundaries.md`. If so, run boundary detection (Phase 0 Step 4 signals) on those directories. If they qualify as boundaries, generate new module skills and add routing entries to all platform glue files.
5. **Detect deleted modules:** Check if any stored boundaries in `_boundaries.md` have directories that no longer exist on disk. If so, trigger the Module Deletion Cascade (see below).
6. **Detect renamed modules:** Check if a boundary directory was moved (appears in diff as delete + add in new location). Treat as: delete old module (full deletion cascade) + create new module (full generation). Do not attempt to "rename in place" -- the cascade ensures all references are cleaned up.
7. Determine which existing skills need updating:
   - Module skills: if any file in the module's boundary changed
   - Task skills: if relevant config/scripts changed (e.g., CI config change triggers deployment-ci.md update)
   - Core skills: if project-wide config changed (e.g., `package.json`, `go.mod`, `Cargo.toml`, `pyproject.toml` change triggers orientation.md update)
   - orientation.md: if any module was added or removed
8. For each skill that needs updating, run the targeted update path (steps 1-5 of the targeted update above — do NOT run individual validation gates yet)

#### ⛔ VALIDATION GATE — must pass before finalising

**Do NOT proceed to step 11 until this gate passes.** This is the diff-update equivalent of the full pipeline's validation phases (4, 5, 7, 8). It is mandatory, not advisory.

9. **Run abbreviated simulation:** Dispatch a separate agent (model: sonnet) with ALL updated skills loaded as context. Give it 2-3 realistic tasks that exercise the changed areas — at minimum one task per updated module. The simulation agent must NOT be the same agent that regenerated the skills.
10. **Evaluate and fix:** Read the simulation results. If the agent made errors that correct skill content would have prevented, fix the affected skills and re-run the failing scenarios. Repeat until simulations pass cleanly or you have identified issues that require human input (in which case, flag them and do not update the commit hash).

**Gate failure:** If after 2 fix-and-retry cycles simulations still fail, STOP. Report the failures to the user and ask for guidance. Do not update `state.md` — the update is incomplete.

11. Update manifest and `state.md` commit hash — **only after the validation gate passes**

**Expected time: 5-15 minutes** depending on scope of changes.

### Module Deletion Cascade

When a module is detected as deleted (its boundary directory no longer exists on disk), execute all of the following steps in order:

1. **Delete the module's skill file:** Remove `.ai/skills/modules/<name>.md`
2. **Remove from ALL routing tables:** Remove the module's entry from every root platform file that contains routing (CLAUDE.md, AGENTS.md, copilot-instructions.md, .cursorrules, .windsurfrules, .clinerules -- whichever exist in this repo)
3. **Remove per-module routing files for ALL detected platforms:** Delete `.cursor/rules/<name>.mdc`, `.github/instructions/<name>.instructions.md`, `.claude/rules/<name>.md`, and any other per-module routing files that were generated for this module
4. **Update cross-references in remaining skill files:** Grep ALL remaining skill files for references to the deleted module (check Relationships, Change Impact, Extension Seams, and any other sections that link to other modules). For each reference found, either remove the deleted module from dependency lists or replace with `<!-- REMOVED: <module-name> — verify replacement -->` if the dependency was meaningful
5. **Update `_boundaries.md`:** Remove the deleted module's boundary entry
6. **Update `_manifest.md`:** Change the module's disposition to `deleted`
7. **Update orientation.md:** Remove the deleted module from the Boundaries list and any other references

### Drift resolution (`--drift` or `--resolve-drift`)

Targeted repair of skills flagged by drift detection. Runs in a **single context window** (not a multi-phase pipeline).

1. Read `state.md` to verify a prior pipeline run exists. If no `state.md`, abort: "Run the full pipeline first."
2. Run `skill-drift.sh --json` to get current drift signals
3. Triage each signal (confirmed vs false-positive via git diff analysis of actual code changes)
4. For confirmed drifts: analyze code changes, surgically patch stale sections
5. For unmapped directories: create new skill files if they qualify as module boundaries
6. Cross-reference check: propagate relationship changes to related skills
7. Update routing tables in all platform glue files
8. Three-stage accuracy verification: claim-by-claim source verification, structural integrity checks (Phase 4 checks 1, 3, 9, 10, 11), relationship symmetry audit
9. Commit updated/new skill files (advances anchors automatically)
10. Update `state.md` commit hash and drift resolution history

**Expected time: 3-10 minutes** depending on number of drifted skills and unmapped directories.
**Prerequisite:** At least one completed pipeline run (`state.md` must exist).

For the full instruction set, see `phase-drift-resolve.md`.

### Detecting update mode

The orchestrator determines the update mode at startup:

1. Check if `--fresh` flag is present -> Full run
2. Check if `--update <name>` flag is present -> Targeted update
3. Check if `--drift` or `--resolve-drift` flag is present -> Drift resolution
4. Check if `--drift-check` flag is present -> Drift check (report only, no resolution)
5. Check if `state.md` exists with a `commit:` hash -> Diff-based update
6. Otherwise -> Full run (first time)

---

## Token Budgets

Token budgets are **guidelines, not hard cutoffs.** They target conciseness without risking truncation that could change meaning. If a complex module genuinely needs more tokens to explain its relationships and gotchas, that's fine. But exceeding a budget is a SMELL — it usually means the skill contains greppable information that should be removed. Investigate before accepting the overage.

| Skill file | Budget | Rationale |
|---|---|---|
| `orientation.md` | ~2k tokens | Always-loaded; every wasted token is multiplied by every conversation |
| `domain-context.md` | ~2k tokens | Always-loaded via root file routing |
| `tasks/<name>.md` | ~1.5k tokens each | Loaded on-demand for specific tasks |
| `modules/<name>.md` | ~1.5k tokens each | Loaded on-demand for specific modules |
| `AGENTS.md` | ~4k tokens | Self-sufficient entry point for Codex, Zed, JetBrains, etc. |
| `CLAUDE.md` | ~3-4k tokens | Self-sufficient entry point for Claude Code (all 12 required sections) |
| `.github/copilot-instructions.md` | ~3-4k tokens | Self-sufficient entry point for GitHub Copilot |
| `.cursorrules` | ~3-4k tokens | Self-sufficient entry point for Cursor |

### Budget enforcement

Phase 2 estimates token counts for every generated file. The self-review step at the end of Phase 2 checks all estimates against guidelines. Any file significantly over guideline (>50% above target) should be investigated — check for greppable content, duplicated facts, or scope creep. Files modestly over guideline are acceptable if the extra content is genuinely useful understanding that can't be found via grep.

**Approximate token counting:** 1 token ~= 4 characters in English. Count characters, divide by 4. This is an estimate -- err on the side of being under budget.

### What to do when over budget

1. **Apply the 5-second grep test.** Remove any content an agent could find via grep/glob in under 5 seconds.
2. **Check for duplicated facts.** If the same information appears in multiple skills, keep it in the canonical location and replace it with a routing pointer elsewhere.
3. **Condense, do not remove understanding.** Keep the WHY, HOW, and WHAT-BREAKS content. Cut the WHAT content (file lists, route lists, schema copies).
4. **Split if necessary.** If a module genuinely needs more than 1.5k tokens of non-greppable understanding, consider splitting it into two skills (e.g., `modules/billing-core.md` and `modules/billing-webhooks.md`). This is rare and should be a last resort.

---

## Adversarial Simulation Scenarios (Phase 5)

Phase 5 is the quality gate. It tests whether the generated skills actually help an agent complete real tasks. The simulation agent has access ONLY to the skills in `.ai/skills/` and the platform glue files -- it does NOT read source code directly.

### The 6 standard scenarios

| # | Scenario | Tests |
|---|----------|-------|
| 1 | **New Developer Onboarding** | Setup instructions, architecture understanding, navigation to first task |
| 2 | **Bug Fix in Core Module** | Module skill routing, dependency awareness, change impact coverage |
| 3 | **Cross-Cutting Feature** | Dependency map accuracy, cross-module data flow, change ordering |
| 4 | **Add Tests** | Test framework knowledge, pattern discovery, fixture/helper awareness |
| 5 | **Refactor Across Boundaries** | Dependency graph accuracy, consumer identification, safe refactor ordering |
| 6 | **Cross-Project** (monorepos only) | Monorepo structure, shared package consumers, cross-project build pipeline |

### Tier-specific simulation rules

- **Tier A:** Run scenarios 1 and 2 only (New Developer Onboarding + Bug Fix in Core Module). Skip 3, 4, 5, 6.
- **Tier B:** Run scenarios 1 through 5.
- **Tier C:** Run scenarios 1 through 5 + 1 custom scenario targeting the most complex module.
- **Tier D:** Run scenarios 1 through 5 + scenario 6 (Cross-Project).

### Simulation protocol

For each scenario, the simulation agent:

1. **Starts with the root context file** (CLAUDE.md / AGENTS.md — platform-dependent) which contains the routing tables
2. **Follows the routing** -- reads the skills that the routing table points to
3. **Attempts to complete the task** using only the information in skills
4. **Records every point where it gets stuck:**
   - "I needed to know X but no skill told me"
   - "Skill Y said Z but it was wrong/incomplete"
   - "I followed routing to skill Y but it didn't cover this case"
   - "I couldn't determine which module owns this concern"
5. **Rates the experience:** Could it complete the task? How many skills did it need to load? Was any loaded skill irrelevant (wasted tokens)?

### Simulation output format (`_simulation_report.md`)

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
[Issues that appeared in 2+ simulations -- highest priority gaps]

## Issues by Skill File

### [skill file path]
| # | Issue | Severity | Found in Simulations | Description |
|---|---|---|---|---|
| 1 | [short name] | blocking | 1, 3 | [detail] |

## Issues by Simulation

### Simulation N: [name] -- [sufficient/insufficient]
[Brief narrative: what worked, what didn't, where the agent would have failed]

## Unresolvable from Skills Alone
[Issues where the simulation agent needed information that may not exist in source code either -- potential questions for the human]
```
