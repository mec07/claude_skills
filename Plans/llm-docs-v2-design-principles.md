# llm-docs v2 — Design Principles & Architecture

Captured from brainstorming sessions 2026-04-10. These are the foundational decisions that all implementation work must align with.

---

## Core Philosophy: Skills, Not Inventories

Documentation is NOT a copy of the code in markdown form. It is a set of **pre-computed skills** that make an LLM agent competent in a specific area of the codebase.

A "skill" gives the agent:
- **WHY** the module/area exists (purpose, business context)
- **HOW** it connects to the rest of the system (relationships, data flow, communication)
- **WHAT** breaks if you change it (change impact, constraints, gotchas)
- **WHERE** to start (one entry point, not an inventory of every file)

A skill does NOT contain:
- Lists of routes, endpoints, or API methods (greppable)
- Lists of function parameters or method signatures (readable from code)
- Lists of all files in a directory (globbable)
- Copies of schemas, types, or table definitions (code is source of truth)
- Lists of environment variables (greppable from code + .env.example)

### The Test: "Can the agent find this in <5 seconds with grep/glob?"

If yes → it does NOT belong in docs.
If no → it DOES belong in docs.

Source: FirstPrinciples analysis + Dragos's cofounder feedback: "I'd see it as being a place where the idea behind each module is explained, condensed into a couple of paragraphs."

---

## Architecture: Three Layers

```
LAYER 1: Always-Read (fixed skeleton, every repo, every platform)
├── Root context file (CLAUDE.md / AGENTS.md / platform-specific)
│   Contains: project identity, tech stack, USE WHEN routing index
│   Budget: <2k tokens
├── Architecture overview (docs/llm/architecture.md)
│   Contains: system idea, boundaries, cross-cutting patterns, CI/CD
│   Budget: <2k tokens
└── Domain context (docs/llm/domain-context.md)
    Contains: business domain, glossary, regulatory, architecture rationale
    Budget: <2k tokens
    Source: Phase D human interview

LAYER 2: Module Docs (dynamic, mirrors repo boundaries)
├── One doc per real module/service/package boundary
├── Path mirrors repo structure (services/billing/ → docs/llm/services/billing.md)
├── Content: conceptual understanding in 1-2 paragraphs (~1.5k tokens each)
│   - Purpose (WHY it exists)
│   - Relationships (HOW it connects)
│   - Change impact checklist (WHAT breaks)
│   - Extension seams (WHERE new code plugs in)
│   - Entry point (ONE file path to start)
│   - Test pattern (ONE example, not a list)
│   - Gotchas specific to this module
├── Agent loads 2-3 per task, staying under 15% context ceiling
└── Cross-cutting concerns NEVER duplicated — live in Layer 1

LAYER 3: Platform Glue (thin, per-platform entry points)
├── Always: CLAUDE.md, AGENTS.md, .github/copilot-instructions.md
├── Conditional: .cursor/rules/, .claude/rules/, .aiassistant/rules/, etc.
├── Each glue file is a thin pointer/wrapper around canonical docs/llm/ content
└── Detection: generate glue for platforms whose config dirs exist in repo
```

### Token Budgets

| Content | Max Tokens | Rationale |
|---------|-----------|-----------|
| Root context (always-read) | 2k | Loaded every conversation |
| Architecture overview | 2k | Loaded every conversation |
| Domain context | 2k | Loaded every conversation |
| Per-module doc | 1.5k | Agent loads 2-4 per task |
| Total per task | ~10-12k | <15% of 128k context window |

---

## Routing: USE WHEN Patterns

The root context file contains a routing index that tells the agent which module doc to load:

```markdown
## Module Routing

| Area | Doc | USE WHEN |
|------|-----|----------|
| Billing | docs/llm/services/billing.md | payments, invoicing, subscriptions, pricing |
| Auth | docs/llm/services/auth.md | authentication, authorization, sessions, tokens, login |
| Frontend | docs/llm/apps/frontend.md | UI, components, React, client-side |
```

This works on ALL platforms:
- **Routing-capable platforms** (Cursor, Copilot, JetBrains, Claude Code, Cline, Windsurf): enforce mechanically via globs/patterns
- **Non-routing platforms** (Aider, ChatGPT): the LLM reads the index and self-routes

---

## Phase D: Domain Interview

Captures knowledge that CANNOT be derived from source code:
- Business domain, industry, customer context
- Domain-specific terminology (glossary)
- Regulatory/compliance constraints
- Architecture rationale (why things look odd but are intentional)
- Operational tribal knowledge

### Key Design Decisions
- Runs AFTER Phase 0 (uses existing doc assessment to ask smarter questions)
- Accepts text dumps + URLs (MCPs checked first for wikis, then WebFetch, then paste fallback)
- Hard cap: 10 direct questions, 10 min target
- Reverse Glossary in Phase 8: mine code for undefined terms, present to human with code context
- Skip on re-runs if domain-context.md exists, is high-confidence, and <6 months old
- Stored in repo at docs/llm/domain-context.md (version controlled, persists across runs)

---

## Platform Context File Research (April 2026)

### Platforms with conditional/glob routing (6):
| Platform | Mechanism | File Format |
|----------|-----------|-------------|
| Cursor | `.cursor/rules/*.mdc` with `globs` frontmatter | MDC |
| GitHub Copilot | `.github/instructions/*.instructions.md` with path matching | Markdown |
| JetBrains AI | `.aiassistant/rules/*.md` with file pattern type | Markdown |
| Claude Code | `.claude/rules/*.md` hierarchical loading | Markdown |
| Cline | `.clinerules/` with `paths` in YAML frontmatter | Markdown |
| Windsurf | `.windsurf/rules/*.md` with frontmatter triggers | Markdown |

### Platforms with always-load only (no routing):
| Platform | File | Notes |
|----------|------|-------|
| OpenAI Codex CLI | `AGENTS.md` (+ `AGENTS.override.md`) | 32KB limit |
| Aider | `CONVENTIONS.md` (manual load via config) | 1MB limit |
| Amazon Q | `.amazonq/rules/*.md` | Per-session toggle |

### Cross-platform file readers:
| Platform | Reads These Files (in priority) |
|----------|-------------------------------|
| Zed | `.rules`, `.cursorrules`, `.windsurfrules`, `.clinerules`, `copilot-instructions.md`, `AGENT.md`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` |

### Emerging standard: AGENTS.md
- Donated to Linux Foundation's Agentic AI Foundation (Dec 2025)
- 20,000+ GitHub repos
- Supported by: Codex, Zed, JetBrains, Factory, partial Cursor/Copilot
- Research: human-written +4% success, LLM-generated -3% success
- 32KB typical limit

### Size limits:
| Platform | Limit |
|----------|-------|
| Claude Code CLAUDE.md | 200 lines / 25KB |
| Windsurf global | 6KB |
| Windsurf workspace | 12KB per file |
| OpenAI Codex AGENTS.md | 32KB combined |
| Aider | 1MB |

---

## Brainstorm Additions (Must-Haves)

### 1. Task Router (docs/llm/task-router.md)
Maps common agent tasks to exact doc reading order. Eliminates O(n) navigation.

### 2. Workflow Recipes (docs/llm/recipes/)
Step-by-step guides with real code patterns from the repo for common multi-file changes.

### 3. Change Impact Checklists (in dependency-map.md + module docs)
Per-module "if you modified this, check:" lists built from actual import graph.

### 4. Extension Seams (in module docs)
Where new code plugs in: registries, plugin points, event handlers, with real examples.

### 5. Conditional Exploration (Phase 1 Step 1j)
8 areas documented IF found: auth, migrations, feature flags, observability, codegen, secrets, API contracts, error handling.

---

## Red Team Fixes Applied

Key issues identified and fixed during implementation:
1. URL fetching: MCP escalation (Atlassian/Notion/M365/Slack MCPs checked first)
2. Phase D: 10 question hard cap, 10 min target
3. Skip logic: staleness check (6-month timestamp)
4. Reverse Glossary: shows code context + hypothesis, not "best guess"
5. Step 1j: evidence thresholds per conditional area, subagent guidance for large repos
6. local-dev.md: concrete trigger criteria (3+ of 5 indicators)
7. Graceful degradation: simple repos get simple docs
8. Monorepo workflows: 5+ projects get per-project files
9. domain-context.md: only rewrite when content changes (git noise prevention)

---

## Implementation Status

- [x] Phase D file created (phase-D-domain-interview.md)
- [x] SKILL.md updated (pipeline, state template, output structure, routing)
- [x] Phase 0 updated (domain-context.md detection)
- [x] Phase 1 updated (IaC, versions, conditional exploration, expanded specs)
- [x] Phase 2 updated (14-question quality bar, expanded coverage assessment)
- [x] Phase 3 updated (local dev, domain context, task router validation)
- [x] Phase 4 updated (enhanced scenarios D, E, H)
- [x] Phase 8 updated (Reverse Glossary)
- [ ] Doc philosophy shift (concise skills, not verbose inventories) — IN PROGRESS
- [ ] Dynamic module structure (mirror repo boundaries) — IN PROGRESS
- [ ] Platform glue generation (multi-platform context files) — IN PROGRESS
- [ ] Minimum file coverage calculation — NEXT
