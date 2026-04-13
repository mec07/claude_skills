---
name: llm-docs
description: "SUPERSEDED by RepoSkills. Use /RepoSkills instead. This skill generates verbose LLM documentation; RepoSkills generates concise agent skills with cross-platform routing."
---

# llm-docs (SUPERSEDED)

> **This skill has been superseded by [RepoSkills](../RepoSkills/SKILL.md).**
>
> RepoSkills generates concise, routing-oriented agent skills instead of verbose documentation.
> Key improvements: 10-phase pipeline, domain interview, adversarial simulation, cross-platform
> routing (Claude Code, Copilot, Cursor, Windsurf, JetBrains, Cline, Codex), living skills that
> self-improve through usage, and the 5-second grep test (if an agent can find it via grep, it
> doesn't belong in a skill).
>
> **Use `/RepoSkills` instead of `/llm-docs` for new projects.**
>
> This skill is preserved for reference — its orchestration patterns (state management,
> subagent dispatch, failure handling, context recovery) were carried forward into RepoSkills.

---

## Original Description (preserved for reference)

Generate a comprehensive, accurate, LLM-optimised documentation layer for any codebase. The output enables Claude Code, Copilot, Cursor, and other LLM agents to navigate, understand, and modify the codebase effectively.

## Invocation

**Full pipeline (default):**
> Generate LLM documentation for this repo

**Single phase:**
> Run llm-docs phase: discover
> Run llm-docs phase: generate
> Run llm-docs phase: refine
> Run llm-docs phase: validate
> Run llm-docs phase: clarity-review
> Run llm-docs phase: self-resolve
> Run llm-docs phase: validate-2
> Run llm-docs phase: clarity-review-2
> Run llm-docs phase: ask-human

**Resume from last checkpoint:**
> Resume llm-docs

**Resume from a specific phase:**
> Run llm-docs from phase: validate

**Fresh run (ignore existing docs, regenerate everything):**
> Run llm-docs fresh

---

## State management

All working files and state live in `~/.claude/MEMORY/llm-docs/<repo-slug>/`, where `<repo-slug>` is the repository directory name (e.g., `my-project`). This keeps working files out of the target repo and enables context recovery.

### State file: `state.md`

The template below shows Phase 1's sub-steps as an example. **When each phase agent starts, it must expand its phase entry** by copying the checklist from its phase instruction file into `state.md`. For example, when Phase 3 starts, the agent replaces `- [ ] 3: Validate` with the full 18-item checklist from `phase-3-validate.md`. This ensures recovery can resume at the exact sub-step.

```markdown
# llm-docs State

repo: /absolute/path/to/repo
slug: repo-directory-name
started: ISO-timestamp
updated: ISO-timestamp

## Phases
- [x] 0: Discover (completed ISO-timestamp)
- [ ] D: Domain Interview
- [ ] 1: Generate (in progress)
  - [x] 0: Read baseline assessment (_original_docs.md)
  - [x] 1a: Map repo structure
  - [x] 1b: Read existing docs
  - [ ] 1c: Identify tech stack
  - [ ] 1d: Understand directories
  - [ ] 1e: Trace key flows
  - [ ] 1f: Identify commands
  - [ ] 1g: Inventory scripts
  - [ ] 1h: Hunt gotchas
  - [ ] GATE: Confirm all exploration complete (answer 7 questions)
  - [ ] write: Write documentation
  - [ ] review: Self-review
- [ ] 2: Refine
- [ ] 3: Validate
- [ ] 4: Clarity Review
- [ ] 5: Self-Resolve
- [ ] 6: Validate (pass 2)
- [ ] 7: Clarity Review 2
- [ ] 8: Ask Human

## Coverage Tiering (if applicable)
- Tier 1: [list or "not applicable"]
- Tier 2: [list or "not applicable"]
- Tier 3: [list or "not applicable"]
```

### Working files in MEMORY

| File | Created by | Used by | Deleted | Purpose |
|---|---|---|---|---|
| `state.md` | Orchestrator | All phases | Never (permanent record) | Phase progress and repo path |
| `_original_docs.md` | Phase 0 | Phases D, 1, 2, 3, 4 | Phase 8 cleanup | Existing doc assessment |

**Repo output file:** `docs/llm/domain-context.md` — written by Phase D, consumed by all subsequent phases. Lives in the target repo, not MEMORY. Treated as a trusted baseline by Phase 0 on re-runs.
| `_manifest.md` | Phase 1 | Phases 2, 6, 7, 8 | Phase 8 cleanup | File disposition: preserved vs generated vs orphaned, tier assignments |
| `_audit.md` | Phase 3 | Phases 6, 8 | Phase 8 cleanup | Validation findings ledger |
| `_review.md` | Phase 4 | Phases 5, 7, 8 | Phase 8 cleanup | Clarity review findings |
| `_explore_<area>.md` | Phase 1 subagents | Phase 1 merge | End of Phase 1 | Per-area exploration output |
| `_validate_<doc>.md` | Phase 3 subagents | Phase 3 merge | End of Phase 3 | Per-doc validation output |
| `_scenario_<name>.md` | Phase 4 subagents | Phase 4 merge | End of Phase 4 | Per-scenario simulation output |
| `_discover_<dirname>.md` | Phase 0 subagents | Phase 0 merge | End of Phase 0 | Per-directory doc discovery output |

### Manifest format (`_manifest.md`)

All phases that read the manifest expect this exact format:

```markdown
# File Manifest

## Top-level docs
| File | Disposition | Confidence | Lines | Notes |
|------|-------------|------------|-------|-------|
| overview.md | preserved | high | 152 | |
| architecture.md | generated | medium | 0 | Rewritten — medium confidence |
| scripts.md | generated | n/a | 0 | New to spec |
| glossary.md | skipped | n/a | 0 | Not warranted |

## Module docs
| File | Disposition | Confidence | Lines | Notes |
|------|-------------|------------|-------|-------|
| modules/auth.md | preserved | high | 89 | |
| modules/payments.md | generated | n/a | 0 | New module discovered |
| modules/legacy.md | orphaned | medium | 45 | Module deleted from codebase |

## Tiering (if applicable)
- Tier 1: auth, api, frontend
- Tier 2: notifications, billing, admin
- Tier 3: utils, config, scripts
```

**Disposition values:** `preserved` (kept from previous run), `generated` (written from scratch), `orphaned` (module deleted — flagged for Phase 2 deletion), `skipped` (not warranted for this repo), `modified_by_phase_5` (preserved doc updated by Phase 5 to resolve issues).

Phase 5 MUST update a doc's disposition from `preserved` to `modified_by_phase_5` when it edits a preserved doc. This signals Phase 6 to apply increased validation scrutiny.

**File lifecycle by phase end:**
- **End of Phase 0:** `state.md` + `_original_docs.md`
- **End of Phase 1:** `state.md` + `_original_docs.md` + `_manifest.md`
- **End of Phase 2:** `state.md` + `_original_docs.md` + `_manifest.md`
- **End of Phase 3:** `state.md` + `_original_docs.md` + `_manifest.md` + `_audit.md`
- **End of Phase 4:** `state.md` + `_original_docs.md` + `_manifest.md` + `_audit.md` + `_review.md`
- **End of Phase 5:** `state.md` + `_original_docs.md` + `_manifest.md` + `_audit.md` + `_review.md`
- **End of Phase 6:** `state.md` + `_original_docs.md` + `_manifest.md` + `_audit.md` (rebuilt) + `_review.md`
- **End of Phase 7:** `state.md` + `_original_docs.md` + `_manifest.md` + `_audit.md` + `_review.md`
- **End of Phase 8:** `state.md` only (all `_` files deleted)

---

## Context recovery protocol

When resuming after a context clear:

1. Read `~/.claude/MEMORY/llm-docs/` — list subdirectories to find the active project
2. Read `state.md` in the project directory
3. **Validate state.md integrity** before proceeding:
   - All `completed` timestamps are chronological (no phase completed before its predecessor)
   - No phase is marked both complete and in-progress
   - If the current phase has sub-steps, at least one is unchecked (otherwise it should be marked complete)
   - If corruption is detected, report to the user and request guidance — do not guess the correct state
4. Determine the next unchecked item in the checklist
5. Read the phase instruction file for the current phase
6. Skip to the next unchecked step and continue from there
7. If a phase is marked complete, proceed to the next unchecked phase

**Critical:** Always update `state.md` immediately after completing each step. This is what makes recovery work. If you complete a step but don't update state, that work will be repeated on resume.

---

## Pipeline

The full pipeline has 10 phases (Phase 0, Phase D, then Phases 1 through 8). **Each phase MUST run in its own context window.** Spawn a new agent for each phase. State passes between phases exclusively via files on disk — the working files in `~/.claude/MEMORY/llm-docs/<repo-slug>/` and the documentation files in the target repo's `docs/llm/` directory.

```
Phase 0: Discover            → find and assess all existing documentation
Phase D: Domain Interview    → capture business/domain context from human (skip on re-run if fresh)
Phase 1: Generate            → explore codebase, create docs from scratch
Phase 2: Refine              → assess structure, restructure, expand coverage
Phase 3: Validate            → adversarial fact-check, create _audit.md
Phase 4: Clarity Review      → simulate agent tasks, find gaps, create _review.md
Phase 5: Self-Resolve        → answer own questions from source code, update docs
Phase 6: Validate (pass 2)   → rebuild _audit.md from scratch, re-verify after phases 4-5
Phase 7: Clarity Review 2    → re-simulate, find remaining gaps
Phase 8: Ask Human           → present only unresolvable questions to user
```

### Phase instructions

Each phase reads its instructions from a dedicated file in this skill directory:

| Phase | Instruction file | Input (on disk) | Output (on disk) |
|---|---|---|---|
| 0 | `phase-0-discover.md` | Codebase, existing docs | `MEMORY: _original_docs.md` |
| D | `phase-D-domain-interview.md` | `_original_docs.md` + human input | `docs/llm/domain-context.md` |
| 1 | `phase-1-generate.md` | `_original_docs.md` + `domain-context.md` + codebase | `docs/llm/**`, `CLAUDE.md`, `.github/copilot-instructions.md`, `docs/README.md`, local context files |
| 2 | `phase-2-refine.md` | All Phase 1 output + `_original_docs.md` + codebase | All docs restructured and expanded |
| 3 | `phase-3-validate.md` | All docs + codebase | Docs with errors fixed, `MEMORY: _audit.md` |
| 4 | `phase-4-clarity-review.md` | All docs + codebase | `MEMORY: _review.md` |
| 5 | `phase-5-self-resolve.md` | `_review.md` + all docs + codebase | Docs updated, `_review.md` issues resolved |
| 6 | `phase-6-validate-2.md` | All docs + `_review.md`* + codebase | `MEMORY: _audit.md` rebuilt |
| 7 | `phase-7-clarity-review-2.md` | All docs + `_review.md` + codebase | `_review.md` updated |

\* Phase 6 reads `_review.md` only to verify Phase 5's claimed resolutions are correct. It does not produce or modify `_review.md`.
| 8 | `phase-8-ask-human.md` | `_review.md` (open issues only) | Final doc updates, MEMORY cleanup |

`MEMORY:` prefix means the file lives in `~/.claude/MEMORY/llm-docs/<repo-slug>/`.

### Phase execution

When running the full pipeline:

1. **Create the MEMORY directory:** `mkdir -p ~/.claude/MEMORY/llm-docs/<repo-slug>/`
2. **Write initial `state.md`** with the repo path and all phases unchecked
3. **For each phase:**
   a. Spawn a new agent **at maximum effort**
   b. Pass it the phase instruction file AND the global rules section below
   c. Tell the agent the MEMORY directory path and target repo path
   d. The agent reads the instruction file and executes thoroughly
   e. The agent updates `state.md` — marks the phase complete with timestamp
   f. On completion, the agent reports a summary of what was done
4. **Report progress to the user** after each phase: "Phase X complete. [Brief summary — e.g., '12 docs generated', '3 errors fixed', '4 issues found']. Proceeding to Phase Y." This keeps the user informed during long-running pipelines.
5. **Proceed to the next phase**

**Every phase MUST run at maximum effort.** This is non-negotiable. These are complex, accuracy-critical tasks that require careful reading of source code, thorough verification, and precise documentation. Reduced effort produces hallucinations.

**Between Phases 0 and 1 — Phase D decision:** The orchestrator checks whether Phase D should run. If `docs/llm/domain-context.md` exists AND Phase 0 scored it high-confidence AND its `Last interview` timestamp is within 6 months, skip Phase D and proceed to Phase 1. If the user invoked with `--interview` or `--redo-interview`, always run Phase D regardless. Otherwise, run Phase D.

**Between Phases 7 and 8:** The Phase 7 agent must check `_review.md` at the end of its run. If all issues are resolved, it should report that Phase 8 can be skipped. The orchestrator then informs the user that no human input is needed and proceeds to cleanup.

### Cleanup

When the pipeline completes (after Phase 8, or after Phase 7 if Phase 8 is skipped):

1. Delete all `_` prefixed working files from `~/.claude/MEMORY/llm-docs/<repo-slug>/`
2. Update `state.md` to mark all phases complete
3. Report the final summary to the user

---

## Parallelisation guide

### When to parallelise

| Phase | Parallelise when... | Pattern |
|---|---|---|
| 0: Discover | Repo has 50+ potential doc files | Parallel doc-reading subagents |
| 1: Generate (explore) | Repo has 10+ major directories | One subagent per major area |
| 1: Generate (write) | 5+ doc files to write | One subagent per doc file |
| 3: Validate | 5+ doc files to validate | One subagent per doc file |
| 4: Clarity Review | Always (4 scenarios) | One subagent per scenario |
| Other phases | Generally not worth parallelising | Sequential execution |

**Batching for large repos:** For repos requiring 30+ parallel subagents (e.g., 40+ module docs to write or validate), dispatch in waves of 10-15 subagents. Wait for each wave to complete before dispatching the next. This keeps coordination overhead manageable and limits the blast radius of failures. Within each wave, apply the standard failure recovery protocol (re-dispatch once, then sequential fallback).

### Subagent dispatch protocol

1. **Define tasks:** List the independent work units (areas to explore, docs to write, docs to validate, scenarios to simulate)
2. **Write task context inline:** Each subagent prompt must include ALL context it needs — the full task description, relevant file paths, rules to follow, and output file path. Do NOT reference other files the subagent would need to read for instructions (except the codebase itself).
3. **Assign output files:** Each subagent writes to a unique file in the MEMORY directory (e.g., `_explore_backend.md`, `_validate_architecture.md`, `_scenario_cross_cutting.md`)
4. **Dispatch in parallel:** Use the Agent tool with `run_in_background: true` for all subagents simultaneously
5. **Collect and merge:** When all subagents complete, read their output files and integrate the results

### Subagent lifecycle and failure handling

**How subagents work:** The Agent tool with `run_in_background: true` spawns an independent agent. You are automatically notified when it completes. The subagent's output file on disk is the contract — if the file exists and is well-formed, the subagent succeeded.

**Failure detection:** After notification that a subagent completed, check for its output file:
- **File exists and is complete:** Success. Proceed to merge.
- **File exists but is incomplete** (truncated, missing sections): Treat as failure.
- **File does not exist:** Subagent failed entirely.

**Failure recovery:** For any failed subagent:
1. **Re-dispatch once** with the same task. Subagent failures are often transient (context limits, temporary errors).
2. **If it fails again:** Fall back to sequential processing — the orchestrating agent performs that subagent's work itself. **Write the output to the same file the subagent would have written** (e.g., `_explore_<area>.md`, `_validate_<doc>.md`, `_scenario_<name>.md`). This ensures the merge step finds the output regardless of whether a subagent or the orchestrator produced it.
3. **Log the failure** in `state.md` as a note under the current phase: `<!-- Subagent failure: [area/doc/scenario], fell back to sequential -->`
4. **Never block the pipeline** on a failed subagent. The sequential fallback ensures forward progress.

### Model selection for subagents

| Task type | Recommended model | Reasoning |
|---|---|---|
| Explore a single directory/module | `sonnet` | Mechanical reading and summarising |
| Write a single doc file from notes | `sonnet` | Structured writing from clear inputs |
| Validate a single doc against code | `sonnet` | Systematic checking, clear procedure |
| Simulate a cross-cutting scenario | `opus` | Requires judgment and creative thinking |
| Merge subagent outputs into final doc | `opus` | Requires synthesis and consistency |
| Self-review of generated docs | `opus` | Requires critical thinking |

Use the `model` parameter on the Agent tool to select the model. When in doubt, use the default (inherits parent model).

---

## Global rules (apply to ALL phases)

Every phase instruction file must be read alongside these rules. These are non-negotiable.

### Accuracy

- **Do not hallucinate.** Every claim must be verified against actual source code.
- **Do not infer from filenames.** You must read a file before making any claim about its contents.
- **Do not invent** APIs, endpoints, schemas, services, commands, or architectural patterns.
- If you cannot verify something, mark it `<!-- TODO: verify -->` or remove it. Do not fill gaps with plausible guesses.
- **Wrong documentation is worse than no documentation.**

### Evidence

- Every file path referenced must exist. Verify with `ls` or Glob before writing it into a doc.
- Every command documented must come from `package.json` scripts, `Makefile`, CI config, or equivalent. Do not invent commands.
- Every script documented must exist at the stated path. Verify run commands, arguments, and environment variables against the actual script code.
- Every architectural claim must be traceable to actual imports, calls, or config in source code.
- For every inter-component communication path: find the sender code AND the receiver code. Verify the mechanism and the data contract.

### Writing style

- Short sections, dense content. No filler, no introductions, no marketing prose.
- Concrete over abstract: exact file paths, real commands, actual dependency names.
- "X generates Y from Z" over "X handles generation."
- Bullet points over paragraphs for factual content.
- File paths are better than descriptions.
- **Never copy schemas, types, or table definitions into markdown.** Point to the source file instead.

### Structure

- `docs/llm/` is the single source of truth. All other files are pointers.
- Every fact lives in exactly one place. Other files link to it.
- Cross-link aggressively. No orphan docs.
- Module docs should map to real, coherent boundaries in the codebase.

### Exploration

- Always exclude from file exploration: `node_modules`, `.git`, `dist`, `build`, `.next`, `__pycache__`, `.turbo`, `.cache`, vendor directories, and any other generated/dependency directories.

### Trusted baseline

- Phase 0 produces `_original_docs.md` — an index of all existing documentation with reliability assessments. All subsequent phases use this file to understand which existing docs can be trusted.
- **High-confidence** docs should be treated as starting facts. Do not contradict them without evidence from source code.
- **Medium-confidence** docs provide useful context but their claims should be verified before building on them.
- **Low-confidence** docs should not be relied on. Verify all their claims independently against source code.
- Do not assume any particular file is the most reliable. Let the Phase 0 assessment guide you.

### Scratchpad discipline

- Use the working files in `~/.claude/MEMORY/llm-docs/<repo-slug>/` as your scratchpad. Log findings as you go. **Do not rely on memory** — these files are how state passes between context windows.
- **Update `state.md` after every completed step.** This is mandatory. Mark the step `[x]` immediately when done.

---

## Output structure

The pipeline produces (in the TARGET REPO):

```
docs/llm/
├── overview.md              # Start here. What is this repo, how is it shaped?
├── architecture.md          # Components, boundaries, communication, data flow
├── conventions.md           # Evidenced patterns and standards
├── workflows.md             # Exact commands for every common task
├── scripts.md               # Comprehensive inventory of all scripts across the repo
├── gotchas.md               # Traps, surprises, hidden coupling
├── glossary.md              # Repo-specific terms (only if warranted)
├── dependency-map.md        # System-wide module graph and change impact
├── domain-context.md        # Business domain, glossary, regulatory context (human-provided)
├── task-router.md           # Maps common agent tasks to exact doc reading order
├── local-dev.md             # Complete local dev setup guide (only for complex repos)
├── recipes/
│   └── <common-task>.md     # Step-by-step guides with real code patterns
└── modules/
    └── <one per major module>.md

CLAUDE.md                          # Root entry point for Claude Code
.github/copilot-instructions.md   # Entry point for Copilot (updated or created)
docs/README.md                     # Index for humans and tools
+ local context files in important subdirectories
```

### CLAUDE.md template

```markdown
# <Repo Name>

> One-line description of what this repo does.

## Documentation

The canonical LLM documentation lives in `docs/llm/`. Start with `docs/llm/overview.md`.

## Before modifying code

1. Read the relevant module doc: `docs/llm/modules/<module>.md`
2. Check for impacts: `docs/llm/dependency-map.md`
3. Check for traps: `docs/llm/gotchas.md`
4. Follow project patterns: `docs/llm/conventions.md`
5. Before creating/modifying scripts: `docs/llm/scripts.md`
6. Understand the domain: `docs/llm/domain-context.md`
7. Check for a recipe: `docs/llm/task-router.md`
8. Local setup: `docs/llm/local-dev.md` (if it exists)
```

Do not use `@` file includes in CLAUDE.md. This file is loaded into every Claude Code conversation — keeping it minimal avoids wasting context on documentation irrelevant to the current task. The agent should read specific docs as needed.

### Critical documentation priorities

These areas require special attention across all phases, as they are where bugs are most commonly introduced:

**Inter-component communication:** Every point where one part of the system talks to another must be documented with sender file, receiver file, mechanism, data contract location, and downstream effects.

**Data structure discoverability:** Every schema, table definition, index definition, type definition, and contract must be findable in one step. Docs must never copy these structures — they must point precisely to the source-of-truth files and document the relationships between them.

**Script discoverability:** Repos — especially monorepos — accumulate scripts across many locations: `package.json` scripts, shell scripts, `Makefile` targets, CI workflows, Python scripts, `Taskfile` targets, and more. These must be comprehensively inventoried in `docs/llm/scripts.md` so that agents can quickly determine whether a script already exists, whether an existing script can be extended, or whether a new script is needed (and where to put it).

---

## Adapting to the repo

This skill is repo-agnostic. Do not assume any specific tech stack, framework, language, or architecture. Discover everything from the actual codebase.

### Default path (most repos)

For repos with fewer than ~20 top-level directories and straightforward architecture:

- **Phase D (Domain Interview)** runs only on first invocation or when the user requests it with `--interview`. On subsequent runs, the existing `domain-context.md` is treated as a trusted baseline. For simple repos, the interview may take only 2-3 minutes.
- **Phases 0-2 are the core pipeline.** Discover existing docs, generate new docs, refine structure. For many repos, this produces documentation that is accurate and complete.
- **Phases 3-8 are optional validation passes.** Run them when accuracy is critical (production codebases, shared repos, complex architectures) or when the repo is large enough that Phase 1 exploration may have gaps.
- **Not all output files are required.** Skip `dependency-map.md`, `glossary.md`, and individual module docs if the repo is small enough that `overview.md` and `architecture.md` cover everything.
- **Skip parallelisation.** Subagent overhead is not worth it for small repos.
- **Collapsing phases:** If Phase 1 output is obviously correct and complete, the orchestrator may collapse Phases 2-7 into a single quick verification pass — read all docs, spot-check 10 claims against code, fix any errors, and proceed to Phase 8 (or skip it entirely if no issues found).

### Full pipeline (large or complex repos)

For repos with more than ~20 top-level directories, 50+ source files in a single module, or monorepo structures with multiple packages:

- **Run all phases including Phase D.** Large repos benefit from the full discover → domain interview → generate → refine → validate → review → self-resolve → re-validate → re-review → ask-human pipeline. Phase D is especially valuable for large or domain-heavy repos — encourage the user to provide product documentation, wiki links, or company website URLs during the interview.
- **Coverage tiering for large monorepos.** Map the full structure first. Then assign every package/module to a tier:
  - **Tier 1** (full module docs): the 10 most important or most-connected packages — determined by dependency count, entry point status, or cross-package import frequency. These get deep exploration, full flow tracing, and comprehensive module docs.
  - **Tier 2** (summary module docs): the next 15-20 packages — entry point, purpose, key files, dependencies, but no deep flow tracing.
  - **Tier 3** (overview mention only): remaining packages — listed in `overview.md` with one-line descriptions and directory paths. No individual module docs.
  - Document your tier assignments in `state.md` so Phase 2 knows what to fill in.
- **Use subagents for parallel exploration.** Dispatch one subagent per major area. Each writes its findings to `_explore_<area>.md` in the MEMORY directory. The orchestrating agent merges results.
- **Module docs are more important than top-level docs** for large repos. An agent working in a specific area needs the module doc to be thorough. Top-level docs provide navigation and system-wide context.

### Known limitation: preserved doc validation depth

When re-running the skill on a repo with existing docs, high-confidence files are preserved to save tokens. Preserved docs that are never modified by Phase 5 receive only Phase 0 spot-check validation (up to 10 claims) plus Phase 3's standard audit. They do NOT receive the increased 80% validation that modified preserved docs get in Phase 6. Phase 7 alerts the user to any unmodified preserved docs, and Phase 8 gives the user the option to request deeper validation or accept them as-is. For repos where code has changed significantly since the last run, consider using `Run llm-docs fresh` to regenerate everything.

---

## Anti-patterns

Watch for these rationalizations and resist them:

- **"This phase is simple enough to skip"** — Every phase exists for a reason. Phase 3 catches errors Phase 1 introduced. Phase 4 finds gaps Phase 2 missed. Skipping phases degrades quality invisibly.
- **"I remember what the code does"** — You don't. Read the file. Every time.
- **"This is probably right"** — Probably is not verified. Check it or mark it `<!-- TODO: verify -->`.
- **"I'll update state.md later"** — Update it now. If you don't, context recovery fails and work gets repeated.
- **"The subagent will figure it out"** — Give the subagent complete context inline. Don't assume it can read your mind or navigate to find instructions.
- **"This doc is too small to need validation"** — Small docs can have wrong file paths just as easily as large ones.
