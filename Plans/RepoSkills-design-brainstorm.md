# RepoSkills --- Design Brainstorm (Final State)

Captured 2026-04-10. Updated to reflect the FINAL implemented state of the skill.

---

## Implementation Summary

**12 files total**, all drafted, consistency review in progress:

| File | Lines | Role |
|------|-------|------|
| SKILL.md | ~111 | Lightweight entry point: identity, trigger, output structure, platform glue spec |
| orchestration.md | ~649 | Heavy orchestration: pipeline state machine, subagent dispatch, failure handling, model routing |
| phase-0-discover.md | -- | Discover & Triage |
| phase-1-domain-interview.md | -- | Domain Interview (skippable) |
| phase-2-map-generate.md | -- | Map & Generate |
| phase-3-refine.md | -- | Refine |
| phase-4-validate.md | -- | Adversarial fact-checking |
| phase-5-clarity-review.md | -- | Agent simulation |
| phase-6-self-resolve.md | -- | Self-Resolve |
| phase-7-validate-2.md | -- | Validate Pass 2 |
| phase-8-clarity-review-2.md | -- | Clarity Review 2 |
| phase-9-human-checkpoint.md | -- | Reverse Glossary + unresolvable issues |

---

## Pipeline: 10 Phases

```
Phase 0: Discover & Triage       -> classify repo, detect platforms, find boundaries
Phase 1: Domain Interview         -> capture business context (interactive, skippable)
Phase 2: Map & Generate           -> confirm boundaries, generate all skills + platform glue
Phase 3: Refine                   -> structural rework, conciseness pass, token budget enforcement
Phase 4: Validate                 -> adversarial fact-checking against source code
Phase 5: Clarity Review           -> agent simulation (can an agent follow these skills?)
Phase 6: Self-Resolve             -> fix gaps found in phases 4-5
Phase 7: Validate Pass 2          -> second adversarial fact-check after fixes
Phase 8: Clarity Review 2         -> second agent simulation after fixes
Phase 9: Human Checkpoint         -> Reverse Glossary + unresolvable issues presented to human
```

### Why 10 (full quality pipeline restored)

The 6-phase compressed pipeline was dropped. The final implementation restores the same depth as llm-docs: double validation and double clarity review. Rationale:

- Single-pass validation missed issues that only surface after self-resolve changes
- Clarity review after self-resolve catches regressions introduced by fixes
- The cost of two extra passes is small vs. shipping broken skills
- This matches the battle-tested llm-docs pipeline that proved its value

---

## Skill Categories

### Category 1: Repo Understanding Skills (structure of the codebase)

| # | Skill | File | Tokens | When Generated |
|---|-------|------|--------|---------------|
| 1 | **Orientation** | docs/llm/orientation.md | ~2k | Always. System understanding ONLY --- shape, boundaries, cross-cutting patterns |
| 2 | **Module Skills** | docs/llm/modules/<name>.md | ~1.5k each | Per real boundary. Includes module-specific overrides for task skills |
| 3 | **Domain Context** | docs/llm/domain-context.md | ~2k | Phase 1 interview |

### Category 2: Task Skills (how to do things in this codebase)

Generated CONDITIONALLY based on what's found. Names and content are pattern-agnostic --- derived from what the repo actually contains, not from a web-app template.

| Skill | Generated IF | Repo-wide + Module Override |
|-------|-------------|---------------------------|
| **Local Dev Setup** | Always | Repo-wide default + per-module overrides where setup differs |
| **Running Tests** | Test files found | Repo-wide default framework/pattern + per-module overrides where frameworks differ |
| **Deployment & CI** | CI workflow files found | Repo-wide pipeline + per-module deploy differences |
| **Database Operations** | Migration dir or ORM config found | Repo-wide migration tool + per-module schema areas |
| **Authentication** | Auth middleware/guards found | Usually repo-wide, may vary per service |
| **Request/Message Handling** | Route handlers OR queue consumers found. Named dynamically: "Request Handling" for REST/GraphQL, "Message Processing" for queues, "Command Handling" for CLIs, "Public API Surface" for libraries | Per-module if multiple API styles |
| **Script Operations** | Script dir or 5+ scripts found | Usually repo-wide |
| **Infrastructure** | IaC files found | Usually repo-wide |
| **Observability** | Logging framework in 3+ files | Repo-wide default + per-module logging overrides |
| **Code Generation** | Codegen config found | Per-module where codegen is used |
| **Secrets Management** | Secret store client or vault config | Usually repo-wide |
| **Feature Flags** | Flag SDK or flag config found | Usually repo-wide |
| **Error Handling** | Custom error classes or error middleware | Repo-wide patterns + per-module error types |

#### Two-Level Task Skills (key design decision)

Task skills have TWO levels to handle the small-repo vs monorepo spectrum:
- **Repo-wide skill file**: covers the default/shared patterns
- **Module-specific overrides**: in the module skill's relevant section, where a module DIFFERS from the default

Example: "Running Tests" skill says "default: Jest, tests co-located, run `npm test`". Module:billing skill says "OVERRIDE: this module uses pytest, tests in tests/, run `poetry run pytest`".

Small repos: one task skill, no overrides needed.
Monorepos: one task skill + overrides in divergent modules.

#### Asking the Human When Info Is Missing

If a phase finds a module but can't determine how to run it locally, run its tests, or what framework it uses --- this becomes a Phase 9 question: "I found services/reconciliation/ but couldn't determine how to run it locally or test it. Can you help?"

Do NOT guess. Do NOT leave it undocumented. Ask.

### Separate Files Dropped

The following were considered during brainstorming but dropped from the final design. Their content is folded into orientation.md and module skills:

- **conventions.md** --- folded into orientation (repo-wide) and module skills (per-module)
- **dependency-map.md** --- folded into orientation (high-level) and module skills (change impact)
- **workflows.md** --- folded into task skills
- **recipes/** --- DROPPED entirely. Routing teaches the pattern, agent composes its own plan

### What's NOT a Skill (removed from old output)
- scripts.md --- greppable, reference from task skills or module skills
- glossary.md --- folded into domain-context.md
- gotchas.md --- folded into module skills (gotchas in context, not a grab bag)
- architecture.md --- absorbed into orientation.md (high-level shape) + module skills (relationships)
- local-dev.md --- absorbed into Local Dev Setup task skill
- task-router.md --- routing lives in root platform files, not orientation

---

## Routing: Root Platform Files (NOT orientation.md)

**Critical design decision:** Task routing lives in the root platform context files, NOT in orientation.md. orientation.md is for system understanding only.

Routing is generated into these root files:

| File | Content | Covered Platforms |
|------|---------|-------------------|
| CLAUDE.md | Pointer + routing index (~1k) | Claude Code, Zed |
| AGENTS.md | Self-contained master (~4k) | Codex, Zed, JetBrains, Aider |
| .github/copilot-instructions.md | Condensed (~4k) | Copilot, Zed |
| .cursorrules | Copy of AGENTS.md | Cursor legacy, Zed |

The routing table in these files tells agents which module doc to load:

```markdown
## Module Routing

| Area | Doc | USE WHEN |
|------|-----|----------|
| Billing | docs/llm/services/billing.md | payments, invoicing, subscriptions, pricing |
| Auth | docs/llm/services/auth.md | authentication, authorization, sessions, tokens |
```

This works on ALL platforms:
- **Routing-capable platforms** (Cursor, Copilot, JetBrains, Claude Code, Cline, Windsurf): enforce mechanically via globs/patterns
- **Non-routing platforms** (Aider, ChatGPT): the LLM reads the index and self-routes

### Conditional Per-Module Routing (only for detected platforms):

| Condition | Files | Format |
|-----------|-------|--------|
| .cursor/ exists | .cursor/rules/<module>.mdc | globs frontmatter |
| .github/ exists | .github/instructions/<module>.instructions.md | path matching |
| .claude/ exists | .claude/rules/<module>.md | directory-based |
| .aiassistant/ exists | .aiassistant/rules/<module>.md | file pattern type |
| .windsurf/ exists | .windsurf/rules/<module>.md | frontmatter triggers |
| .clinerules/ exists | .clinerules/<module>.md | paths frontmatter |
| .amazonq/ exists | .amazonq/rules/<module>.md | per-session |

---

## File Architecture

### SKILL.md (~111 lines, lightweight)

Contains:
- Skill identity (name, description, trigger)
- Output structure spec (what files get generated, where)
- Platform glue specification
- Pointer to orchestration.md for pipeline execution

Does NOT contain: pipeline logic, phase details, subagent dispatch, state management.

### orchestration.md (~649 lines, heavy)

Contains:
- Full pipeline state machine (10 phases)
- State tracking (state.md with per-step checkboxes)
- Context recovery protocol (7-step resume sequence)
- Subagent dispatch protocol (inline context, parallel dispatch, merge-collect)
- Failure handling (re-dispatch once, then sequential fallback, never block pipeline)
- Model selection (sonnet for mechanical, opus for judgment)
- Anti-hallucination rules
- Evidence rules
- Anti-patterns list (all 6 rationalizations)
- Repo size adaptation tiers

### Phase files (phase-0 through phase-9)

Each phase runs in its own context window. State passed via disk files.

---

## Boundary Detection (replaces linear directory exploration)

A "module" = a real architectural boundary, detected by:
1. **Package boundary:** own package.json / go.mod / Cargo.toml / etc.
2. **Service boundary:** own Dockerfile, own entry point, own port
3. **Domain boundary:** own data types/models imported by others
4. **Deployment boundary:** own CI workflow, own terraform module
5. **Logical boundary:** clear single responsibility from exports/public API

NOT modules: utils/, lib/, helpers/, config/, scripts/, types/ --- these are cross-cutting

---

## Context Window Discipline (in Orientation skill)

```
NEVER read entire generated files, installed dependencies, or vendor directories.
- node_modules/, vendor/, .venv/, __pycache__/, dist/, build/ -> NEVER browse
- Generated files (protobuf output, GraphQL types, Prisma client) -> search for specific types only
- Use language tooling (gopls, pyright, tsserver) for type definitions and function
  signatures rather than reading source files in dependencies
- When you need a type from a dependency: use LSP or grep for the specific name
```

---

## Compaction Survival

- CLAUDE.md (routing) -> NEVER compacted, survives entire conversation
- Skills loaded during conversation -> compacted with history, agent re-reads if needed
- Implication: skills should be ACTIONABLE --- gotchas and warnings should trigger immediate agent behaviour, not require later recall

---

## Validation: Adversarial Simulation (Phases 4-5, repeated in 7-8)

5 standard simulations, each runs on Opus:

| # | Simulation | Tests |
|---|-----------|-------|
| 1 | New developer onboarding | Orientation, domain context, local dev setup |
| 2 | Bug fix in core module | Module skills, change impact |
| 3 | Cross-cutting feature addition | Routing, multiple modules |
| 4 | Add tests for untested code | Module test patterns |
| 5 | Refactor across boundaries | Change impact, module relationships |

Key insight: "Is this true?" vs "If an agent believes this, will it make the right decision?"

Double-pass rationale: Phase 6 self-resolve may introduce regressions. Phases 7-8 catch them.

---

## Repo Size Adaptation

| Tier | Size | Duration | Skills | Parallelism | Simulations |
|------|------|----------|--------|-------------|-------------|
| A: Small lib | <50 files | ~15 min | Orientation only (maybe 1 module) | None | 2 of 5 |
| B: Standard app | 50-500 files | ~30-45 min | Full set minus task-router | Optional | All 5 |
| C: Large app | 500+ files | ~60-90 min | Full set | Required (waves) | All 5 + custom |
| D: Monorepo | Multi-project | ~90-120 min | Full set + per-project workflows | Required | All 5 + cross-project |

---

## Update Model: 3 Modes

1. **Full run** (`--fresh` or first time) --- complete 10-phase pipeline
2. **Targeted** (`--update billing`) --- re-explore + regenerate one module, 3-5 min
3. **Diff-based** (default re-run) --- `git diff --stat` against stored commit hash, update only changed modules

Staleness tracking: frontmatter comment in each skill file with commit hash:
```
<!-- repo-skills: module=billing, generated=2026-04-10, commit=abc123f -->
```

---

## Token Economics

| Content | Tokens | Notes |
|---------|--------|-------|
| Orientation (always loaded) | 2k | System shape, boundaries, cross-cutting patterns |
| Domain context (always loaded) | 2k | Business knowledge |
| Per module skill | 1.5k | Agent loads 2-4 per task |
| Task skills | 3k | Loaded when doing setup/writing code |
| **Loaded per task** | **8-12k** | <15% of 128k context |
| **Total on disk (15 modules)** | **~32k** | Down from 50-80k in old skill |

---

## Carry-Forward from llm-docs (Hard-Won Learnings)

### KEEP VERBATIM:
- Pipeline-as-state-machine: each phase in own context window, state via disk files
- state.md with per-step checkboxes and immediate updates
- Context recovery protocol (7-step resume sequence)
- Subagent dispatch protocol (inline context, parallel dispatch, merge-collect)
- Failure handling (re-dispatch once, then sequential fallback, never block pipeline)
- Anti-hallucination rules (never assert without verification)
- Evidence rules (every claim traceable to source)
- Anti-patterns list (all 6 rationalizations)
- Model selection (sonnet for mechanical, opus for judgment)
- Maximum effort is non-negotiable
- Explore thoroughly before writing (HARD GATE pattern)
- Adversarial stance in validation
- **Full quality pipeline: double validation + double clarity review**

### MODIFY:
- Discovery output: capability map instead of doc assessment
- Tiering: skill priority (by task value) not coverage breadth
- Output specs: skill templates not doc templates
- Coverage assessment: "does every common task have a skill?" not "is every directory documented?"
- Validation checks: competency simulation not path/command verification
- **Routing: lives in root platform files, NOT in orientation.md**

### DROP:
- Manifest system (preserve/generate/orphan) --- skills regenerate fresh
- Script directory READMEs --- overly verbose, greppable
- Local context pointer files --- skills looked up by capability, not directory
- Collapsing phases shortcut --- just make phases fast for small repos
- **conventions.md as separate file** --- folded into orientation + module skills
- **dependency-map.md as separate file** --- folded into orientation + module skills
- **workflows.md as separate file** --- folded into task skills
- **recipes/ directory** --- routing teaches the pattern, agent composes its own plan

### NEW:
- Skill identification step (what skills to generate, between discovery and writing)
- Boundary detection model (replaces linear exploration)
- Skill template schema (standard structure with trigger, prereqs, procedure, verification, gotchas)
- Token budget enforcement (hard caps per file)
- Adversarial simulation validation (5 standard simulations, run twice)
- Platform-aware glue generation (detect + generate for 7 platforms)
- Diff-based incremental updates (commit hash tracking)
- Skill executability check (can an agent follow these steps?)
- Context window budget check (does loading this skill leave room for code?)

---

## Open Design Decisions (Resolved)

1. **Orientation + architecture combined or separate?** --- RESOLVED: Combined in orientation.md. System understanding only, routing lives elsewhere.
2. **Platform glue: content or pointers?** --- RESOLVED: Hybrid. AGENTS.md self-contained, CLAUDE.md pointers, per-module routing files self-contained.
3. **Recipes directory?** --- RESOLVED: DROPPED. Routing in root platform files serves the same purpose without maintenance burden.
4. **Polyrepo support?** --- Out of scope for v1.
5. **Pipeline depth (6 vs 10 phases)?** --- RESOLVED: 10 phases. Full quality pipeline restored, matching llm-docs depth.
6. **Where does routing live?** --- RESOLVED: Root platform files (CLAUDE.md, AGENTS.md, copilot-instructions.md, .cursorrules). NOT orientation.md.
7. **Separate files for conventions/deps/workflows?** --- RESOLVED: DROPPED. Content folded into orientation + module skills.

---

## Implementation Status

- [x] All 12 files drafted (SKILL.md, orchestration.md, phase-0 through phase-9)
- [x] 10-phase pipeline implemented with full quality depth
- [x] SKILL.md lightweight (~111 lines), orchestration.md heavy (~649 lines)
- [x] Routing placed in root platform files, not orientation.md
- [x] Separate files dropped (conventions, dependency-map, workflows, recipes)
- [ ] Consistency review across all 12 files --- IN PROGRESS
