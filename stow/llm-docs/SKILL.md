# Skill: llm-docs

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

**Resume from a specific phase:**
> Run llm-docs from phase: validate

---

## Pipeline

The full pipeline has 9 phases (Phase 0 through Phase 8). **Each phase MUST run in its own context window.** Spawn a new agent or session for each phase. State passes between phases exclusively via files on disk — the docs themselves, `docs/llm/_original_documentation.md`, `docs/llm/_audit.md`, and `docs/llm/_review.md`. No phase may assume access to another phase's memory or conversation context.

```
Phase 0: Discover            → find and assess all existing documentation
Phase 1: Generate            → explore codebase, create docs from scratch
Phase 2: Refine              → assess structure, restructure, expand coverage
Phase 3: Validate            → adversarial fact-check, create _audit.md
Phase 4: Clarity Review      → simulate agent tasks, find gaps, create _review.md
Phase 5: Self-Resolve        → answer own questions from source code, update docs
Phase 6: Validate (pass 2)   → re-verify after fixes from phases 4–5
Phase 7: Clarity Review 2    → re-simulate, find remaining gaps
Phase 8: Ask Human           → present only unresolvable questions to user
```

### Phase instructions

Each phase reads its instructions from a dedicated file in this skill directory:

| Phase | Instruction file | Input (on disk) | Output (on disk) |
|---|---|---|---|
| 0 | `phase-0-discover.md` | Codebase, existing docs | `docs/llm/_original_documentation.md` |
| 1 | `phase-1-generate.md` | `_original_documentation.md` + codebase | `docs/llm/**`, `CLAUDE.md`, `.github/copilot-instructions.md`, `docs/README.md`, local context files |
| 2 | `phase-2-refine.md` | All phase 1 output + `_original_documentation.md` + codebase | All docs restructured and expanded |
| 3 | `phase-3-validate.md` | All docs + codebase | Docs with errors fixed, `docs/llm/_audit.md` created |
| 4 | `phase-4-clarity-review.md` | All docs + codebase | `docs/llm/_review.md` created |
| 5 | `phase-5-self-resolve.md` | `_review.md` + all docs + codebase | Docs updated, `_review.md` issues resolved |
| 6 | `phase-6-validate-2.md` | All docs + codebase | `_audit.md` rebuilt from scratch |
| 7 | `phase-7-clarity-review-2.md` | All docs + `_review.md` + codebase | `_review.md` updated (resolved preserved, new findings added) |
| 8 | `phase-8-ask-human.md` | `_review.md` (open issues only) | Final doc updates after human answers |

### Phase execution

When running the full pipeline, execute each phase as follows:

1. Spawn a new agent or session **at maximum effort**
2. Pass it the instruction file for that phase AND the global rules section below
3. The agent reads the instruction file and executes the phase thoroughly
4. On completion, the agent reports a brief summary of what was done
5. Spawn the next agent/session for the next phase

**Every phase MUST run at maximum effort.** This is non-negotiable. These are complex, accuracy-critical tasks that require careful reading of source code, thorough verification, and precise documentation. Reduced effort produces hallucinations.

**Between Phases 7 and 8:** The Phase 7 agent must check `_review.md` at the end of its run. If all issues are resolved, it should report that Phase 8 can be skipped. The orchestrator then informs the user that no human input is needed and **deletes the working files**: `docs/llm/_original_documentation.md`, `docs/llm/_audit.md`, `docs/llm/_review.md`. (If Phase 8 runs, it handles this cleanup itself.)

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

- Phase 0 produces `docs/llm/_original_documentation.md` — an index of all existing documentation with reliability assessments. All subsequent phases use this file to understand which existing docs can be trusted.
- **High-confidence** docs should be treated as starting facts. Do not contradict them without evidence from source code.
- **Medium-confidence** docs provide useful context but their claims should be verified before building on them.
- **Low-confidence** docs should not be relied on. Verify all their claims independently against source code.
- Do not assume any particular file is the most reliable. Let the Phase 0 assessment guide you.

### Scratchpad discipline

- Use `docs/llm/_audit.md` and `docs/llm/_review.md` as working files. Log findings as you go. **Do not rely on memory** — these files are how state passes between context windows.

---

## Output structure

The pipeline produces:

```
docs/llm/
├── overview.md              # Start here. What is this repo, how is it shaped?
├── architecture.md          # Components, boundaries, communication, data flow
├── conventions.md           # Evidenced patterns and standards
├── workflows.md             # Exact commands for every common task
├── gotchas.md               # Traps, surprises, hidden coupling
├── glossary.md              # Repo-specific terms (only if warranted)
├── dependency-map.md        # System-wide module graph and change impact
├── _original_documentation.md  # Existing doc assessment (working file, deleted at completion)
├── _audit.md                # Validation ledger (working file, deleted at completion)
├── _review.md               # Clarity review findings (working file, deleted at completion)
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
```

Do not use `@` file includes in CLAUDE.md. This file is loaded into every Claude Code conversation — keeping it minimal avoids wasting context on documentation irrelevant to the current task. The agent should read specific docs as needed.

### Critical documentation priorities

These areas require special attention across all phases, as they are where bugs are most commonly introduced:

**Inter-component communication:** Every point where one part of the system talks to another must be documented with sender file, receiver file, mechanism, data contract location, and downstream effects.

**Data structure discoverability:** Every schema, table definition, index definition, type definition, and contract must be findable in one step. Docs must never copy these structures — they must point precisely to the source-of-truth files and document the relationships between them.

---

## Adapting to the repo

This skill is repo-agnostic. Do not assume any specific tech stack, framework, language, or architecture. Discover everything from the actual codebase.

### Large repositories

For repos with more than ~20 top-level directories, 50+ source files in a single module, or monorepo structures with multiple packages:

- **Prioritise breadth over depth in Phase 1.** Map the full structure first. Read configs and entry points for every module. Deep-dive the 5–10 most important or most-connected modules. Document what you covered in depth vs. what you surveyed. Phase 2 fills coverage gaps.
- **Use subagents for parallel exploration** where the runtime supports it. Each subagent can explore one major area and produce its module doc draft independently.
- **Module docs are more important than top-level docs** for large repos. An agent working in a specific area needs the module doc to be thorough. Top-level docs provide navigation and system-wide context.

### Small repositories

For repos with fewer than ~10 source files and no inter-component communication:

- **Phase 1 may produce all docs that are needed.** If the repo is simple enough that the generated docs are obviously correct and complete, the orchestrator may collapse Phases 2–7 into a single verification pass.
- **Not all output files are required.** Skip `dependency-map.md`, `glossary.md`, and individual module docs if the repo is small enough that `overview.md` and `architecture.md` cover everything.
