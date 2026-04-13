---
name: RepoSkills
description: Generate agent-native skills for any codebase. USE WHEN RepoSkills, generate skills, repo skills, agent skills, agent documentation, skill generation, onboard agents.
---

# RepoSkills

Generate a complete set of agent-native skills for any codebase. Skills are concise, routing-oriented knowledge files that tell an LLM agent WHY things exist, HOW they connect, WHAT breaks if you change them, and WHERE to start. The output enables Claude Code, Copilot, Cursor, Windsurf, Codex, JetBrains AI, Amazon Q, and other LLM agents to navigate, understand, and modify the codebase effectively.

**Skills are NOT documentation.** Documentation explains things to humans. Skills route agents to the right context at the right time with the minimum token cost.

## Invocation

**Full pipeline (default):**
> Generate skills for this repo
> Run RepoSkills

**Single phase:**
> Run RepoSkills phase: discover
> Run RepoSkills phase: domain
> Run RepoSkills phase: generate
> Run RepoSkills phase: refine
> Run RepoSkills phase: validate
> Run RepoSkills phase: simulate
> Run RepoSkills phase: resolve
> Run RepoSkills phase: checkpoint

**Resume from last checkpoint:**
> Resume RepoSkills

**Resume from a specific phase:**
> Run RepoSkills from phase: simulate

**Fresh run (ignore existing skills, regenerate everything):**
> Run RepoSkills --fresh

**Targeted update (regenerate a single module or task skill):**
> Run RepoSkills --update billing
> Run RepoSkills --update running-tests

**Diff-based re-run (default for repos with existing skills):**
> Run RepoSkills
(Automatically detects existing skills, computes git diff against stored commit hash, updates only changed modules.)

---

## Pipeline Overview

The full pipeline has 10 phases (0-9). Each phase runs in its own context window. State passes between phases exclusively via files on disk.

```
Phase 0: Discover & Triage     → classify repo, detect platforms, find module boundaries
Phase 1: Domain Interview      → capture business context from human (skippable on re-runs)
Phase 2: Map & Generate        → confirm boundaries, generate all skills + platform glue
Phase 3: Refine                → structural assessment, coverage gaps, module boundary review
Phase 4: Validate              → adversarial fact-checking against source code
Phase 5: Clarity Review        → simulate agent tasks using only the skills
Phase 6: Self-Resolve          → fix gaps found by validation and simulation
Phase 7: Validate Pass 2       → re-verify after Phase 5-6 changes
Phase 8: Clarity Review 2      → re-simulate with different scenarios
Phase 9: Human Checkpoint      → Reverse Glossary + unresolvable questions
```

---

## Output

### Skills (`.ai/skills/`)

| File | Purpose |
|------|---------|
| `orientation.md` | System understanding — repo shape, tech stack, boundary map (NO routing — routing lives in root files) |
| `domain-context.md` | Business domain, terminology, regulatory, architecture rationale |
| `modules/<name>.md` | One per module — purpose, relationships, change impact, seams, gotchas, testing |
| `tasks/<name>.md` | One per detected capability — how to do X in this specific repo |

### Platform glue (repo root)

| File | Platform |
|------|----------|
| `AGENTS.md` | Codex, Zed, JetBrains AI, generic agents |
| `CLAUDE.md` | Claude Code |
| `.github/copilot-instructions.md` | GitHub Copilot |
| `.cursorrules` | Cursor |

Each root file is **self-sufficient** — it contains all 12 required sections (routing, rules, commands, etc.) and does not redirect to other root files. Any single file must be enough for an agent to navigate the codebase after context compaction.

Conditional per-module routing files (e.g., `.cursor/rules/<module>.mdc`, `.claude/rules/<module>.md`) are generated when those platforms are detected.

---

## Phase Instruction Files

Each phase reads its instructions from a dedicated file in this skill directory:

| Phase | File |
|-------|------|
| 0 | `phase-0-discover.md` |
| 1 | `phase-1-domain-interview.md` |
| 2 | `phase-2-map-generate.md` |
| 3 | `phase-3-refine.md` |
| 4 | `phase-4-validate.md` |
| 5 | `phase-5-clarity-review.md` |
| 6 | `phase-6-self-resolve.md` |
| 7 | `phase-7-validate-2.md` |
| 8 | `phase-8-clarity-review-2.md` |
| 9 | `phase-9-human-checkpoint.md` |

---

## Orchestration

For pipeline execution protocol, state management, global rules, and subagent dispatch, see [orchestration.md](orchestration.md).
