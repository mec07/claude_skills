# Phase 2: Map & Generate — Build the Skill Layer

You have full filesystem access to the repository. Your job is to confirm the architectural boundaries identified by Phase 0, then generate a concise skill layer that makes an LLM agent competent in this codebase.

**Philosophy:** Skills contain ONLY what an agent cannot find via grep/glob in 5 seconds. No file inventories. No route lists. No schema copies. No env var tables. Every token must earn its place by providing understanding that the code alone cannot give quickly.

**This phase is exploration and writing. Do not validate your output — that is Phase 4's job (adversarial fact-checking) and Phase 5's job (clarity review simulation).** Focus your full effort on understanding the codebase deeply and writing concise, actionable skills.

---

## Checklist

Copy this checklist into `state.md` under the Phase 2 entry. Mark each item `[x]` immediately upon completion.

```
- [ ] 2.1: Confirm boundaries (read _triage.md, verify each boundary candidate)
- [ ] 2.2: Generate orientation skill (.ai/skills/orientation.md)
- [ ] 2.3: Generate module skills (.ai/skills/modules/<name>.md, parallel for large repos)
- [ ] 2.4: Generate task skills (.ai/skills/tasks/<name>.md, conditional)
- [ ] 2.5: Generate platform glue and maintenance tools (AGENTS.md, CLAUDE.md, .cursorrules, copilot-instructions.md, per-module routing, skill-drift.sh)
- [ ] 2.6: Self-review checklist
```

---

## Inputs and Outputs

**Inputs (read from disk):**
- `~/.claude/MEMORY/RepoSkills/<repo-slug>/_triage.md` — Phase 0's boundary candidates, detected platforms, repo classification, task skill flags
- `~/.claude/MEMORY/RepoSkills/<repo-slug>/state.md` — current progress state
- `.ai/skills/domain-context.md` in the target repo — business domain knowledge (if Phase 1 ran)
- The target repository codebase (full filesystem access)

**Outputs (written to disk):**
- `.ai/skills/orientation.md` in the target repo — always-read orientation skill (Layer 1)
- `.ai/skills/modules/<name>.md` in the target repo — per-boundary module skills (Layer 2)
- `.ai/skills/tasks/<name>.md` in the target repo — conditional task skills (Layer 2)
- `AGENTS.md` in the target repo root — self-sufficient entry point (Layer 3)
- `CLAUDE.md` in the target repo root — self-sufficient entry point (Layer 3)
- `.github/copilot-instructions.md` in the target repo — self-sufficient entry point (Layer 3)
- `.cursorrules` in the target repo root — self-sufficient entry point (Layer 3)
- Per-module routing files for detected platforms (Layer 3, conditional)
- `.ai/skills/Tools/skill-drift.sh` in the target repo — drift detection script (maintenance tool)
- `.ai/skills/Tools/skill-drift-hook.sh` in the target repo — hook management script (maintenance tool)
- `~/.claude/MEMORY/RepoSkills/<repo-slug>/_explore_<area>.md` — per-area exploration notes (working files, consumed during writing)
- `~/.claude/MEMORY/RepoSkills/<repo-slug>/state.md` — updated with progress

---

## CRITICAL RULES — read before doing anything

**DO NOT HALLUCINATE. DO NOT GUESS. DO NOT INFER FROM FILENAMES.**

- You must read a file before making any claim about its contents.
- You must not describe what a file "probably" does based on its name or location.
- You must not invent APIs, endpoints, schemas, services, or architectural patterns.
- If you have not read the source code of a module, you may not write a skill for it.
- If something is unclear after reading the code, mark it `<!-- TODO: verify -->` — do not fill the gap with a plausible guess.
- Every file path you reference must exist. Verify before writing it into a skill.
- Every command you document must come from an actual config file (`package.json` scripts, `Makefile`, `Taskfile.yml`, CI config, etc.) or be a standard tool command (`go test`, `cargo test`, `pytest`, etc.). Do not invent commands.
- Do not write exact counts or numbers (e.g., "247 Go files", "12 targets") — these are greppable, go stale, and you may be guessing. If you find yourself writing a number, you are probably including greppable information.
- Do not make absolute claims when the truth is conditional. If code uses a normalisation library, that does not mean all files are in the normalised format — it means the comparison handles both. Read the code carefully; do not over-simplify what you see.

**Accuracy is the single most important requirement. If you are unsure about something, say so explicitly or leave it out. Wrong skills are actively harmful — worse than no skills.**

### Re-runs and Existing Content

This pipeline may be re-run on a repo that already has skill files from a previous run. Handle this correctly:

- **Root platform files** (CLAUDE.md, AGENTS.md, .cursorrules, copilot-instructions.md) may contain project-specific content that was added by the team outside of this pipeline. **Read before writing. Preserve user-added content.** Update the skill-generated sections with fresh content but do not discard anything the team added.
- **`.ai/skills/` files** (orientation, modules, tasks) are fully generated by this pipeline and may be regenerated from source code on a re-run. However, if the team has added content (e.g., extra gotchas, corrected claims), preserve those additions where they are still accurate.
- **`domain-context.md`** contains human-provided domain knowledge. Phase 1's skip logic handles re-runs — do not overwrite a fresh domain-context.md.

### The 5-Second Grep Test

Before writing ANY piece of information into a skill, ask: "Can the agent find this in <5 seconds with grep/glob?"

- **YES** (file lists, route lists, env vars, schema fields, function signatures, import paths, individual file paths to tests/configs/examples, **exact counts and numbers**) → **DO NOT INCLUDE IT.** Individual file paths are brittle (they break on rename/move/delete) and greppable. Exact counts (e.g., "247 Go files", "12 Makefile targets", "32 test files") are greppable AND high-fabrication-risk — they go stale instantly and are easy to get wrong. Describe the convention or folder structure instead.
- **PARTIALLY** (entry point paths, folder structures) → **OK TO INCLUDE.** Entry points are essential for routing — especially in languages like Python where the entry file could be anything. Folder structures change less frequently than individual files and provide useful navigational context.
- **NO** (why a module exists, how modules relate, what breaks when you change something, non-obvious ordering, hidden coupling, business context, test conventions and patterns) → **INCLUDE IT.** This is what skills are for.

---

## Step 1: Confirm Boundaries

Read `~/.claude/MEMORY/RepoSkills/<repo-slug>/_triage.md` from Phase 0. This contains:
- Boundary candidates with evidence (package boundary, service boundary, domain boundary, deployment boundary, logical boundary)
- Repo classification (small lib / standard app / large app / monorepo)
- Detected platforms (which context file formats to generate)
- Task skill flags (which conditional task skills to generate)
- Tech stack summary

### Boundary Verification

For each boundary candidate from `_triage.md`:

1. **Read its entry point** — the main file that Phase 0 identified. Confirm it exists and is actually an entry point (exports, main function, server startup, etc.).
2. **Read its imports** — what does it depend on? Are dependencies on other boundary candidates, or on cross-cutting utilities?
3. **Read its tests** — does it have its own test files? What framework? What patterns?
4. **Decide: real boundary or merge with parent?**
   - **Real boundary:** Has its own entry point AND (own package config OR own tests OR 10+ source files OR own Dockerfile/deploy config). Keep it.
   - **Merge with parent:** Shares package config with parent, has <10 files, no independent tests, no independent deployment. Merge into the parent boundary's skill.
   - **Cross-cutting concern (not a boundary):** `utils/`, `lib/`, `helpers/`, `config/`, `types/`, `scripts/` — these are NOT boundaries. They belong as notes in module skills that use them, or in the orientation skill.

5. **Detect tight coupling** between confirmed boundaries:
   - **Bidirectional imports:** A imports from B AND B imports from A → tightly coupled
   - **Shared data contracts:** both import from the same types/schema file → coupled
   - **Co-change pattern:** check `git log --name-only` for recent commits — if A and B files change in the same commits frequently → coupled
   
   When tight coupling is detected, record it. These modules should be grouped in routing and cross-referenced in skills with an "ALSO LOAD" directive.

6. **Record the decision** in your exploration notes.

### Produce Confirmed Boundary Map

After verifying all candidates, write the confirmed boundary map to `~/.claude/MEMORY/RepoSkills/<repo-slug>/_boundaries.md`:

```markdown
# Confirmed Boundaries

## Repo Classification
[small-lib | standard-app | large-app | monorepo]

## Boundaries (Tier 1 — full module skills)
| Boundary | Type | Entry Point | Evidence |
|----------|------|-------------|----------|
| billing | package + domain | src/billing/index.ts | own package.json, own test dir, 28 source files |

(Adapt entry points and evidence to the repo's actual language — e.g., `main.go`, `lib.rs`, `__init__.py`, `Application.kt`.)

## Boundaries (Tier 2 — summary module skills, large repos only)
| Boundary | Type | Entry Point | Evidence |
|----------|------|-------------|----------|

## Merged (folded into parent)
| Candidate | Merged Into | Reason |
|-----------|-------------|--------|

## Tightly Coupled Pairs
| Module A | Module B | Evidence | Routing Implication |
|----------|----------|----------|-------------------|
| orchestration | data-science | bidirectional imports + co-change | Always load both skills together |

## Cross-Cutting (not boundaries)
| Directory | Referenced In |
|-----------|---------------|
| utils/ | orientation.md |

## Task Skills to Generate
[list from _triage.md, confirmed or adjusted based on verification]

## Detected Platforms
[list from _triage.md]
```

### Parallelisation: Boundary Verification

If `_triage.md` lists **10+ boundary candidates**, parallelise verification using subagents. Each subagent verifies 3-5 boundaries and writes findings to `~/.claude/MEMORY/RepoSkills/<repo-slug>/_explore_boundaries_<batch>.md`.

**Subagent prompt template for boundary verification:**

Each subagent must receive ALL of the following inline:
- The list of boundary candidates to verify (from `_triage.md`)
- The CRITICAL RULES section
- The boundary verification procedure (steps 1-5 above)
- The repo classification and tech stack from `_triage.md`
- The output file path

**Model selection:** Use `sonnet` for boundary verification — mechanical reading and classification.

**Update state:** Mark step 2.1 complete in `state.md`.

---

## Step 2: Generate Orientation Skill (Layer 1, always-read)

Write `.ai/skills/orientation.md` in the target repo. This is the FIRST file any agent reads — it is loaded into every conversation. Budget: **~2k tokens.** Every word must count.

### HARD GATE: Explore Before Writing

Before writing the orientation skill, you must be able to answer these questions from evidence:
- What does this repo do? (cite README or main entry point)
- What is the tech stack? (cite config files — NOT versions, but where versions are pinned)
- What is the system shape? (monolith / microservices / monorepo / library / CLI — cite evidence)
- What are all the confirmed boundaries? (from Step 1)
- What commands exist for dev, build, test, lint? (cite `package.json` scripts, `Makefile`, `Taskfile.yml`, `Cargo.toml`, or equivalent for the repo's language)

**If you cannot answer all five questions with cited evidence, go back and explore more before proceeding.**

### Orientation Skill Template

```markdown
<!-- repo-skills: type=orientation, generated=YYYY-MM-DD, commit=HASH -->

# [Repo Name]

> [1 paragraph: what this product IS and WHY it exists. Business context, not technical description.
> Source: domain-context.md if exists, else README, else inferred from code structure.]

## Tech Stack
[Technology — version pinning source (NOT the version itself)]

Examples (adapt to the repo's actual stack):
- TypeScript — pinned in `.nvmrc` (node) + `tsconfig.json` (TS target)
- Go — version in `go.mod`, toolchain in `go.toolchain`
- Rust — edition in `Cargo.toml`, toolchain in `rust-toolchain.toml`
- Python — version in `pyproject.toml` or `.python-version`
- PostgreSQL — configured in `src/db/config.ts`, version in `docker-compose.yml`

## System Shape
[monolith | microservices | monorepo | library | CLI] — [1-sentence evidence]

Boundaries:
- `path/to/module/` — [4-word purpose]
- `path/to/other/` — [4-word purpose]
[... one line per confirmed boundary]

## Boundaries

- `path/to/module/` — [4-word purpose]
- `path/to/other/` — [4-word purpose]
[... one line per confirmed boundary — this is the structural map, NOT the routing table]

**Note:** The USE WHEN routing tables (Module Routing and Task Routing) do NOT live in this file. They live in the top-level platform files (CLAUDE.md, AGENTS.md, copilot-instructions.md, .cursorrules) so that routing survives context compaction. See Step 5 (Platform Glue) for the routing table templates.

## Quick Reference

| Task | Command | Source |
|------|---------|--------|
| Dev | `[exact command]` | `[source file]` |
| Test | `[exact command]` | `[source file]` |
| Build | `[exact command]` | `[source file]` |
| Lint | `[exact command]` | `[source file]` |
[... the commands a developer runs daily. For the full command reference,
see the scripts/commands task skill.]

(Use the actual commands for the repo's language — e.g., `go test ./...`, `cargo build`, `pytest`, `make dev`, `npm run dev`, and equivalent.)

## New to This Repo?

1. Read this file for the system overview
2. Read `.ai/skills/domain-context.md` for business domain context (if it exists)
3. Read the Local Dev Setup task skill to get set up
4. Pick the module you'll work in and read its skill (see routing in CLAUDE.md/AGENTS.md)
5. Read the Testing task skill before your first PR
```

### Writing Rules for Orientation

- **Product identity paragraph:** Source from `domain-context.md` first. If it does not exist, use README. If README is thin, derive from code structure — but mark as `<!-- TODO: verify with domain interview -->`.
- **Tech stack:** Point to VERSION PINNING SOURCES, not versions. Versions change; the files that pin them do not. An agent that needs the current version reads `.nvmrc`, `go.mod`, `rust-toolchain.toml`, `pyproject.toml`, or equivalent — it does not need us to write "Node 20.11" or "Go 1.22" which will go stale.
- **Boundaries list:** One line per confirmed module boundary with a 4-word purpose. This is the structural map, NOT the routing table. Routing lives in top-level platform files.
- **No routing tables in orientation.md.** The USE WHEN routing tables live in CLAUDE.md, AGENTS.md, copilot-instructions.md, and .cursorrules — files that survive context compaction. orientation.md provides the structural understanding; root files provide the routing.
- **Quick reference:** The most common daily commands from actual config files. Cite the source. The full command reference lives in the scripts/commands task skill — orientation just needs the quick-access commands.

**Update state:** Mark step 2.2 complete in `state.md`.

---

## Step 3: Generate Module Skills (Layer 2)

For each confirmed Tier 1 boundary from Step 1, write `.ai/skills/modules/<name>.md`. **Guideline: keep module skills concise — target ~1.5k tokens.** If a complex module genuinely needs more to explain its relationships, gotchas, and change impact, that's fine. But if a skill exceeds the guideline, check whether it contains greppable information that should be removed. Verbosity is a smell — investigate it, don't truncate.

### HARD GATE: Explore Before Writing Each Module

Before writing a module skill, you must have:
1. Read the module's entry point file
2. Read at least one representative source file beyond the entry point
3. Grepped for imports FROM this module (to find dependents)
4. Read the module's imports (to find dependencies)
5. Located and read at least one test file for this module
6. Identified the module's communication boundaries (how it talks to other modules/external services)

If any of these are missing, explore before writing.

### Tight Coupling Handling

Check `_boundaries.md` for tightly coupled pairs. For each tightly coupled module:
- Include "**Tightly coupled with:** X — ALSO LOAD `.ai/skills/modules/X.md`" in the Relationships section
- Both modules in the pair get this directive (it's bidirectional)
- In the routing tables (CLAUDE.md, AGENTS.md, etc.), group them into a SINGLE routing entry: "orchestration, pipelines | load BOTH orchestration.md + data-science.md | tightly coupled"
- In per-module platform routing files (e.g., `.cursor/rules/orchestration.mdc`), include the content of BOTH coupled module skills so the agent has everything when it enters either directory

### Module Skill Template

```markdown
<!-- repo-skills: module=<name>, generated=YYYY-MM-DD, commit=HASH -->

# <Module Name>

> [1-2 sentence purpose — WHY this exists, business context.
> Not "handles billing" but "Processes recurring subscription charges, manages payment state,
> and enforces idempotency for Stripe webhooks."]

## Relationships
- **Depends on:** [modules this imports from — verified from actual import statements]
- **Depended on by:** [modules that import from this — verified by grepping for imports of this module]
- **Tightly coupled with:** [if detected — ALSO LOAD `.ai/skills/modules/<coupled-module>.md` when working in this module. These modules share data contracts / have bidirectional dependencies / typically change together.]
- **Communicates with:** [external boundaries — mechanism + what the contract looks like]
  - Example: `Stripe API via a dedicated client wrapper — webhook payloads validated against typed schemas in the billing module`

## Entry Point
Start here: `<path/to/main/file>`

## Change Impact
If you modify this module:
- [ ] Check: [describe what downstream area will break and why — e.g., "template changes will fail golden file comparisons" not "check testdata/TestTemplates/"]
- [ ] Check: [describe which consumers are affected — e.g., "both Link and Consumer use these packages"]
- [ ] Run: `<exact test command for this module only>`
- [ ] CI: [describe which CI stage validates this — e.g., "race detection in GitHub Actions"]

## Extension Seams
[Where new code plugs in — registry, plugin point, event handler, middleware chain.
ONE real example per seam, describing the pattern and what interface to implement.
Mention directory names for navigation but do NOT list individual file paths — describe the pattern so the agent can find the right file via grep.]

Example:
- New payment method: add to the payment methods registry, implement the `PaymentMethod` interface. Follow the pattern of existing implementations in the same directory.

## Gotchas
[Module-specific traps. Hidden coupling, implicit ordering, things that look wrong but are intentional.
Each gotcha: what happens, why, how to avoid.]

## Testing
- Convention: [describe the test structure — e.g., "co-located `_test.go` files next to production code", "mirrored `__tests__/` directories", "separate `tests/` directory at module root"]
- Framework: [name] (configured in `<config-file>`)
- Run: `<exact command for this module only>`
- Pattern: [describe the mocking/assertion style in words — e.g., "table-driven tests with testify/assert and mock clients", "jest with dependency injection via factory functions"]

## Local Running
[How to run this module independently. Exact command, required services, port it listens on.
If a library with no standalone runtime: "Library — no standalone runtime. Test with: `<command>`"]
[If different from repo-wide: note the override and why]

## Local Dependencies
[Module-specific setup beyond repo-wide prerequisites.
Extra env vars, extra services, extra tools.
If none: "None — uses repo-wide defaults."]
```

### What Does NOT Belong in Module Skills

These fail the 5-second grep test and MUST NOT be included:
- List of all files in the module (use `glob`)
- List of routes/endpoints (use `grep`)
- List of exported functions (use LSP or `grep`)
- Copies of type definitions (read the source file)
- List of environment variables (grep `.env.example` or the code)
- List of database tables (read the schema file)
- Import statements (read the code)
- **Exact counts or numbers** (e.g., "247 Go files", "12 Makefile targets", "32 test files") — these are greppable, go stale instantly, and are high-fabrication-risk. If you catch yourself writing a specific number, ask: did I actually count, or am I guessing? Either way, the number doesn't belong in a skill.
- **Individual file paths for tests, configs, or examples** — describe the CONVENTION or folder structure instead (e.g., "co-located `_test.go` files" not `pkg/billing/billing_test.go`). Individual file paths are brittle — they break when files are renamed, moved, or deleted, and an agent can find them instantly via glob/grep. Entry point paths and folder structures ARE acceptable — they change less frequently and provide essential navigational context.

### Module Skill Overrides for Task Skills

If a module DIFFERS from the repo-wide default for a task skill (different test framework, different deploy pipeline, different local setup), add a short override section at the bottom of the module skill:

```markdown
## Overrides
- **Testing:** This module uses pytest instead of Jest. Tests are in a `tests/` subdirectory within the module. Run: `poetry run pytest services/billing/`
- **Local Dev:** Requires Redis in addition to repo-wide PostgreSQL. Start with: `docker-compose up redis`
```

Only include overrides where the module DIFFERS. If it follows the repo-wide default, do not add an overrides section.

### Tier 2 Module Skills (Large Repos Only)

For Tier 2 boundaries (repos with 20+ modules), write abbreviated skills containing ONLY:
- Purpose (1 sentence)
- Entry point
- Depends on / Depended on by
- Test command
Budget: ~500 tokens each.

### Parallelisation: Module Skill Writing

If writing **5+ module skills**, parallelise using subagents. Each subagent writes 1-3 module skills.

**Protocol:**

1. Complete Steps 1 and 2 first (boundary confirmation and orientation skill). These establish the shared context all module skills reference.
2. Dispatch subagents. Each subagent receives inline:
   - The module skill template
   - The CRITICAL RULES and 5-Second Grep Test sections
   - The confirmed boundary map from Step 1
   - The specific boundary/boundaries to write skills for
   - The repo classification and tech stack from `_triage.md`
   - All exploration notes relevant to those boundaries
   - The target file paths
   - The list of ALL module skills being written (for cross-referencing in Relationships)
3. When all subagents complete, review for consistency: do the Relationships sections agree? (If module A says it depends on B, does module B list A as a dependent?)

**Batching for large repos:** If 30+ module skills, dispatch in waves of 10-15. Wait for each wave before dispatching the next.

**Model selection:** Use `sonnet` for writing individual module skills from exploration notes.

**If a subagent fails:** Re-dispatch once. If it fails again, write that module skill yourself. Log the fallback in `state.md`.

**Update state:** Mark step 2.3 complete in `state.md`.

---

## Step 4: Generate Task Skills (Layer 2, conditional)

For each task skill that Phase 0 flagged for generation in `_triage.md`, write `.ai/skills/tasks/<name>.md`. Budget: **~1.5k tokens per task skill.** These are generated CONDITIONALLY — only when Phase 0 found evidence of the capability.

### Task Skill Design: Two Levels

Task skills solve the small-repo vs monorepo spectrum:
- **The task skill file** covers the repo-wide default pattern
- **Module skills** contain OVERRIDE sections where a module differs from the default

This means an agent working in a specific module reads the task skill for the general approach, then checks the module skill for overrides. No duplication.

### Task Skill Template

```markdown
<!-- repo-skills: type=task, name=<name>, generated=YYYY-MM-DD, commit=HASH -->

# <Skill Name>

> USE WHEN: [trigger keywords — what task/question/intent triggers loading this skill]

## How It Works in This Repo
[2-3 paragraphs: the repo-wide default approach. WHY it works this way, not just WHAT.
Include the mental model an agent needs to make correct decisions.]

[For example, a testing skill would explain: "Tests are co-located with source files.
Integration tests hit a real Postgres via docker-compose test service. The test DB is
reset between suites via migrations, not truncation — so migration order matters."]

## Key Commands
| Command | Source | What it does |
|---------|--------|-------------|
| `[exact command]` | `[source file]` | [description] |

This is the COMPLETE command reference for this task area. Root platform files
(CLAUDE.md, AGENTS.md, etc.) contain a quick reference of the most common daily
commands and point here for the full list.

(Use the repo's actual commands. Examples by ecosystem:
JS/TS: `npm test` from `package.json` · Go: `go test ./...` · Python: `pytest` from `pyproject.toml`
Rust: `cargo test` · Java: `./gradlew test` from `build.gradle` · Ruby: `bundle exec rspec`)

List every command from the relevant config files — cite the source file and key.
Module-specific commands go in the module skill's Overrides section, not here.

## Gotchas
[Task-specific traps that waste time. Each entry:]
- **[Trap name]:** [What happens] — [Why] — [How to avoid]

## Where to Look
[Describe where to find things by convention, not by specific path.
The agent should be able to locate the right files via grep/glob from this description.]
- Test convention: [e.g., "co-located `_test.go` files", "`__tests__/` directories mirroring source", "single `tests/` directory at root"]
- Test config: [name the config file type — e.g., "jest.config.ts at repo root", "pytest.ini"]
- Shared helpers: [describe where they live by pattern — e.g., "test utilities in a `testutils/` package", "shared fixtures in `tests/fixtures/`"]

## Module Overrides
Check the module skill for the area you're working in. If it has an Overrides section
for this task, follow the module-specific instructions instead of the defaults above.
```

### Conditional Task Skills — Generation Triggers

Only generate a task skill if Phase 0 flagged it. The standard set and their triggers:

| Task Skill | File | Generate IF |
|------------|------|-------------|
| Local Dev Setup | `tasks/local-dev.md` | Always |
| Running Tests | `tasks/testing.md` | Test files found |
| Deployment & CI | `tasks/deployment.md` | CI workflow files found |
| Database Operations | `tasks/database.md` | Migration dir or ORM config found |
| Authentication | `tasks/auth.md` | Auth middleware/guards found |
| Request/Message Handling | `tasks/<dynamic-name>.md` | Route handlers OR queue consumers found |
| Script Operations | `tasks/scripts.md` | Script dir or 5+ scripts found |
| Infrastructure | `tasks/infrastructure.md` | IaC files found |
| Observability | `tasks/observability.md` | Logging framework in 3+ files |
| Code Generation | `tasks/codegen.md` | Codegen config found |
| Secrets Management | `tasks/secrets.md` | Secret store client or vault config |
| Feature Flags | `tasks/feature-flags.md` | Flag SDK or flag config found |
| Error Handling | `tasks/error-handling.md` | Custom error classes or error middleware |

### Testing task skill: test style and conventions

The `tasks/testing.md` skill must include a **Test Style & Conventions** section that describes how tests are written in this repo. Derive this from reading the actual test files — look at patterns across multiple test files to identify the conventions.

Cover:
- **Test philosophy:** What level do tests operate at? (unit, integration, end-to-end, or a mix?) What do they verify — behaviour/outputs or internal implementation?
- **Patterns in use:** Table-driven tests, golden file comparison, mocking style, fixture patterns, assertion library
- **What makes a good test here:** Based on the existing tests, what conventions should new tests follow?

**If the repo has very few or no tests:** Fall back to general best-practice guidance as a starting point for the team. Recommend testing observable behaviour over implementation details — verify outputs, side effects, and contracts rather than internal function returns or const values. The litmus test: if you can refactor the internals without breaking the test, the test is at the right level. Mark this section as `<!-- derived from best practices, not existing tests -->` so future runs can replace it with observed conventions once more tests exist.

**If the repo has substantial tests:** Derive conventions entirely from what's there. Do not impose external style preferences — describe what the repo actually does.

**Dynamic naming:** Request/Message Handling is named based on what the repo actually does:
- REST/GraphQL handlers → `tasks/request-handling.md`
- Queue consumers → `tasks/message-processing.md`
- CLI commands → `tasks/command-handling.md`
- Library public API → `tasks/public-api.md`

### What Does NOT Belong in Task Skills

- Per-module specifics (those go in module skill override sections)
- Environment variable lists (greppable from `.env.example`)
- Complete configuration file contents (point to the file)
- Step-by-step recipes for specific changes (the agent composes its own plan from the skill)
- Exact counts or numbers — greppable and high-fabrication-risk
- Individual file paths to tests, configs, or source files — describe the convention or folder structure instead. Individual file paths are brittle and greppable. Entry point paths and folder structures are OK.

### Asking the Human When Info Is Missing

If you find a module or capability but cannot determine how it works from the code alone (e.g., no tests, no config, unclear entry point):
- Mark it `<!-- TODO: ask human — could not determine [specific thing] from source code -->`
- Log the question in `~/.claude/MEMORY/RepoSkills/<repo-slug>/_questions.md` for Phase 9 (Human Checkpoint)
- Do NOT guess. Do NOT leave it undocumented. Flag it.

**Update state:** Mark step 2.4 complete in `state.md`.

---

## Step 5: Generate Platform Glue (Layer 3)

Platform glue files are the entry points that different AI coding tools read. They route agents into the canonical skill layer at `.ai/skills/`.

### Always Generate (4 root files)

#### `AGENTS.md` (self-sufficient, ~4k tokens)

Self-sufficient entry point for Codex, Zed, JetBrains, Aider, Factory, and other platforms. Like all root files, an agent reading only this file must be able to navigate the codebase. Do NOT redirect to other root files. MUST include ALL required sections (see table below).

```markdown
# [Repo Name]

> [1-sentence description]

## Tech Stack
[Same as orientation.md tech stack section]

## Architecture
[System shape + boundary list from orientation.md]

## Module Routing

Read the relevant module skill BEFORE making changes:

| I need to work on... | Load this skill | USE WHEN |
|----------------------|-----------------|----------|
| [billing, payments, invoicing] | `.ai/skills/modules/billing.md` | working in `src/billing/`, payment logic |
| [auth, login, sessions, tokens] | `.ai/skills/modules/auth.md` | authentication, authorization |
[... one row per module skill — SAME routing table as CLAUDE.md]

## Task Routing

| I need to... | Load these skills |
|--------------|-------------------|
| Fix a bug in [module] | Module skill + dependency module skills |
| Set up locally | `.ai/skills/tasks/local-dev.md` |
| Run or add tests | `.ai/skills/tasks/testing.md` + relevant module skill |
[... same 8-10 sampler entries as CLAUDE.md]

## Key Rules
[Top 5-7 critical rules — things that will cause real problems if violated.
NOT generic advice. Repo-specific guardrails.]

## Key Commands
| Command | Purpose | Source |
|---------|---------|--------|
| `[exact command]` | [purpose] | `[source file]` |
[... quick reference — the commands a developer runs daily.
Full command reference: `.ai/skills/tasks/scripts.md`
Module-specific commands: check the relevant module skill's Overrides section.]

## Context Window Discipline
- `node_modules/`, `vendor/`, `.venv/`, `__pycache__/`, `target/`, `dist/`, `build/` — NEVER browse
- Generated files — search for specific types/functions only
- Use LSP tooling (tsserver, gopls, pyright, rust-analyzer, etc.) for dependency type definitions

## Documentation
Full skill layer: `.ai/skills/orientation.md` (system overview)
Module skills: `.ai/skills/modules/<name>.md`
Task skills: `.ai/skills/tasks/<name>.md`
Domain context: `.ai/skills/domain-context.md`

## Before Modifying Code
1. Read the relevant module skill from the routing table above
2. Check the Change Impact checklist in the module skill
3. Read `.ai/skills/orientation.md` for system-wide context if needed

## Skill & Routing Maintenance
These skills are LIVING — they evolve with the codebase. When a skill is wrong, fix it.
When routing doesn't direct you right, add or fix the entry. When you hit a gotcha a skill
should have warned about, add it to the module skill. When the user teaches you a practice
or principle about this project, add it to the relevant skill — it's repo-wide knowledge,
not a personal correction. When you learn about a new area that has no skill, create one.
When refactoring changes folder structures or file locations, update the skills that
describe those conventions. **Every skill change must be verified against source code** —
read the relevant code before writing. Skill quality must trend upwards, never downwards.
An update that introduces inaccurate claims is worse than no update. Skills improve
through use.

### Drift Detection

Check if skills have drifted from code changes:
- `.ai/skills/Tools/skill-drift.sh` — full drift report
- `.ai/skills/Tools/skill-drift.sh --quiet` — exit code only (CI/hooks)
- `.ai/skills/Tools/skill-drift.sh --json` — JSON output (for CI/PR comments)

Hook management (local — only benefits the installing developer):
- `.ai/skills/Tools/skill-drift-hook.sh install` — install as post-commit hook
- `.ai/skills/Tools/skill-drift-hook.sh uninstall` — remove hook
- `.ai/skills/Tools/skill-drift-hook.sh status` — check installation

For team-wide coverage, CI integration is recommended over local hooks.

**Maintaining the drift tools:**
- Routing table changes (new/renamed/deleted modules) are picked up automatically — the script reads CLAUDE.md at runtime
- If you add new top-level directories where modules live, update `SCAN_DIRS` in `skill-drift.sh`
- If you add/remove shared utility directories, update `CROSS_CUTTING` in `skill-drift.sh` (if populated)

## Coding Standards
- Keep code DRY — search for existing implementations before writing new code
- Follow existing patterns — read 2-3 examples of similar code first
- Maintain quality — tests, types, complete implementations, no stubs

## New to This Repo?

1. Read this file for the big picture and routing
2. Read `.ai/skills/orientation.md` for system understanding
3. Read `.ai/skills/domain-context.md` for business domain (if it exists)
4. Read `.ai/skills/tasks/local-dev.md` to get set up
5. Pick the module you'll work in and read its skill from the routing table
6. Read `.ai/skills/tasks/testing.md` before your first PR
```

**Size limit:** 32KB (Codex limit). Target ~4k tokens.

**If `AGENTS.md` already exists:** Read it first. Preserve any project-specific content (custom rules, conventions, team norms) that was added outside of the skill pipeline. On a re-run, update the skill-generated sections with fresh content but do not discard user-added content that sits alongside them.

#### `CLAUDE.md` (self-sufficient, ~3-4k tokens)

This loads into EVERY Claude Code conversation and survives context compaction. It must be **fully self-sufficient** — an agent reading only this file must have everything it needs to be effective. Do NOT redirect to other root files. Do NOT strip sections in later phases in the name of "deduplication" — every section serves a specific behavioural purpose.

```markdown
# [Repo Name]

> [1-sentence description]

## Tech Stack
[Technology — version pinning source (NOT the version itself)]
[Same content as orientation.md tech stack — survives compaction here]

## Architecture
[System shape — monolith / microservices / monorepo / library / CLI]

Boundaries:
- `path/to/module/` — [4-word purpose]
- `path/to/other/` — [4-word purpose]
[... one line per confirmed boundary]

## Key Commands
| Command | Purpose | Source |
|---------|---------|--------|
| `[exact command]` | [purpose] | `[source file]` |
[... quick reference — the commands a developer runs daily.
Full command reference: `.ai/skills/tasks/scripts.md`
Module-specific commands: check the relevant module skill's Overrides section.]

## Key Rules
[Top 5-7 critical rules — things that will cause real problems if violated.
NOT generic advice. Repo-specific guardrails.]

## Module Routing

Read the relevant module skill BEFORE making changes in that area:

| I need to work on... | Load these skills | USE WHEN |
|----------------------|-------------------|----------|
| [billing, payments, invoicing] | `.ai/skills/modules/billing.md` | working in `src/billing/`, payment logic |
| [auth, login, sessions, tokens] | `.ai/skills/modules/auth.md` | authentication, authorization |
| [orchestration, pipelines] | `.ai/skills/modules/orchestration.md` + `.ai/skills/modules/data-science.md` | tightly coupled — always load both |
[... one row per module skill. Group tightly coupled modules into single routing entries.]

## Task Routing

| I need to... | Load these skills |
|--------------|-------------------|
| Fix a bug in [module] | Module skill + dependency module skills |
| Add a new handler/endpoint | Relevant task skill + module skill + test with conventions |
| Set up locally | `.ai/skills/tasks/local-dev.md` |
| Run or add tests | `.ai/skills/tasks/testing.md` + relevant module skill |
| Deploy or understand CI | `.ai/skills/tasks/deployment.md` |
| Change the data model | `.ai/skills/tasks/database.md` + data layer module skill |
| Understand the domain | `.ai/skills/domain-context.md` |
[... 8-10 sampler entries]

## Context Window Discipline

- `node_modules/`, `vendor/`, `.venv/`, `__pycache__/`, `target/`, `dist/`, `build/` — NEVER browse
- Generated files — search for specific types/functions only, never read whole files
- Use LSP tooling (gopls, pyright, tsserver, rust-analyzer, etc.) for dependency type definitions

## Before Modifying Code
1. Read the relevant module skill from the routing table above
2. Check the Change Impact checklist in that skill
3. Read `.ai/skills/orientation.md` for system-wide context if needed

## Skill & Routing Maintenance

These skills are LIVING — they evolve with the codebase.

**When you encounter a problem a skill should have warned you about:**
→ Add the gotcha to the relevant module skill's Gotchas section.

**When you find a skill is wrong or outdated:**
→ Fix the specific claim with evidence from current source code.

**When the routing table didn't direct you to the right skill:**
→ Add or fix the routing entry so the next agent finds it.

**When a module has been renamed, moved, or deleted:**
→ Update or remove its skill file and routing entry.

**When refactoring changes folder structures or file locations:**
→ Update any skills that describe those conventions — entry points,
directory layouts, test conventions, and module boundaries. Skills
describe structural conventions, not individual file paths, but those
conventions must still match the actual codebase.

**When the user teaches you a practice, principle, or convention about this project:**
→ Add it to the relevant module or task skill so the next agent inherits it.
This is repo-wide knowledge, not a personal correction — it belongs in the
skill files, not just in your conversation memory.

**When you learn something new about an area with no skill:**
→ Create a new skill file in `.ai/skills/modules/` or `.ai/skills/tasks/`.
→ Add a routing entry in this file. You don't need to be asked — if you
learned it the hard way, save the next agent the trouble.

**Accuracy rule for ALL skill changes:** Every change to a skill file —
whether adding a gotcha, recording a user-taught principle, fixing a
stale claim, or expanding a section — must be verified against the actual
source code. Read the relevant code before writing. The quality of these
skills must trend upwards over time, never downwards. A skill update
that introduces inaccurate claims is worse than no update at all.

Skills and routing improve through use. Every agent interaction is an
opportunity to make the next agent's job easier.

### Drift Detection

Check if skills have drifted from code changes:
- `.ai/skills/Tools/skill-drift.sh` — full drift report
- `.ai/skills/Tools/skill-drift.sh --quiet` — exit code only (CI/hooks)
- `.ai/skills/Tools/skill-drift.sh --json` — JSON output (for CI/PR comments)

Hook management (local — only benefits the installing developer):
- `.ai/skills/Tools/skill-drift-hook.sh install` — install as post-commit hook
- `.ai/skills/Tools/skill-drift-hook.sh uninstall` — remove hook
- `.ai/skills/Tools/skill-drift-hook.sh status` — check installation

For team-wide coverage, CI integration is recommended over local hooks.

**Maintaining the drift tools:**
- Routing table changes (new/renamed/deleted modules) are picked up automatically — the script reads CLAUDE.md at runtime
- If you add new top-level directories where modules live, update `SCAN_DIRS` in `skill-drift.sh`
- If you add/remove shared utility directories, update `CROSS_CUTTING` in `skill-drift.sh` (if populated)

## Coding Standards

- Keep code DRY — before writing new code, search for existing
  implementations. Do not duplicate logic that already exists.
- Follow existing patterns — read 2-3 examples of similar code in the
  codebase before writing new code.
- Maintain quality — do not take shortcuts that create technical debt.
  If the codebase has tests, write tests. If it has types, use types.
- Do not be lazy — write complete implementations, not stubs or TODOs.

## Documentation

Full skill layer: `.ai/skills/orientation.md` (system overview)
Module skills: `.ai/skills/modules/<name>.md`
Task skills: `.ai/skills/tasks/<name>.md`
Domain context: `.ai/skills/domain-context.md`

## New to This Repo?

1. Read this file for the big picture and routing
2. Read `.ai/skills/orientation.md` for system understanding
3. Read `.ai/skills/domain-context.md` for business domain (if it exists)
4. Read `.ai/skills/tasks/local-dev.md` to get set up
5. Pick the module you'll work in and read its skill from the routing table
6. Read `.ai/skills/tasks/testing.md` before your first PR
```

Do NOT use `@` file includes — they load full file contents into every conversation.

**Critical:** CLAUDE.md must be fully self-sufficient — an agent that has lost all other context must still be able to navigate the codebase from this file alone. It contains ALL required sections listed in the table below. It does NOT redirect to any other root file.

**If `CLAUDE.md` already exists:** Read it first. Preserve any project-specific content (custom rules, caveats, team norms) that was added outside of the skill pipeline. On a re-run, update the skill-generated sections with fresh content but do not discard user-added content that sits alongside them.

#### `.github/copilot-instructions.md` (self-sufficient, ~3-4k tokens)

Self-sufficient entry point for GitHub Copilot. Like all root files, this must stand alone — an agent reading only this file must be able to navigate the codebase. **MUST include ALL required sections** (see table below). The prose within each section can be condensed, but no section may be omitted. Do NOT redirect to AGENTS.md or other root files.

**If this file already exists:** Read it first. Preserve any project-specific content that was added outside of the skill pipeline. On a re-run, update the skill-generated sections with fresh content but do not discard user-added content. Check for missing required sections and add them.
**If this file does not exist:** Create it with all required sections.

#### `.cursorrules` (self-sufficient, ~3-4k tokens)

Self-sufficient entry point for Cursor. Write the same content as AGENTS.md — both must be independently complete. Cursor's legacy format reads this file.

**If `.cursorrules` already exists:** Read it first. Preserve any project-specific content that was added outside of the skill pipeline. On a re-run, update the skill-generated sections with fresh content but do not discard user-added content. Ensure all required sections are present.

#### Required sections in ALL root platform files

Every root file (CLAUDE.md, AGENTS.md, .cursorrules, copilot-instructions.md) MUST contain ALL of the sections below. The content within each section may be condensed for smaller files, but no section may be omitted:

| Section | Purpose |
|---------|---------|
| **Tech Stack** | Language, framework, version pinning sources |
| **Architecture** | System shape + boundary list |
| **Key Commands** | Quick reference of daily commands + pointer to scripts task skill for full reference |
| **Key Rules** | Repo-specific critical rules (things that cause real problems if violated) |
| **Module Routing** | Table mapping work areas to module skills — the primary discovery mechanism |
| **Task Routing** | Table mapping agent intents to skill combinations |
| **Context Window Discipline** | Directories to never browse, generated file guidance |
| **Before Modifying Code** | Read module skill → check Change Impact → read orientation |
| **Skill & Routing Maintenance** | Living docs guidance — when and how to update skills during use |
| **Documentation** | Pointers to the full skill layer (orientation, modules, tasks, domain context) |
| **Coding Standards** | DRY, follow patterns, maintain quality, no stubs |
| **New to This Repo?** | Numbered onboarding steps for agents encountering the repo for the first time |

**Every root file must be self-sufficient.** Each platform has its own compaction behaviour — CLAUDE.md survives in Claude Code, but copilot-instructions.md may be the only thing Copilot retains, and .cursorrules may be the only thing Cursor keeps. An agent reading ANY single root file must be able to navigate the codebase without needing the others. No root file should redirect to another root file — each one stands alone.

### Conditionally Generate (per-module routing files)

Per-module routing files allow platforms with glob/path-based routing to automatically load the right module skill when an agent is working in that module's directory.

**Only generate for platforms whose config directories exist in the repo.** Check `_triage.md` for the detected platforms list.

For each detected platform AND each confirmed Tier 1 boundary, generate a routing file containing the MODULE SKILL CONTENT (self-contained — do not use cross-file references that the platform cannot resolve) with platform-specific frontmatter:

| Platform | Condition | File Pattern | Frontmatter |
|----------|-----------|-------------- |-------------|
| Cursor | `.cursor/` exists | `.cursor/rules/<module>.mdc` | `globs: ["<source-path>/**"]` |
| GitHub Copilot | `.github/` exists | `.github/instructions/<module>.instructions.md` | Path matching in filename conventions |
| JetBrains AI | `.aiassistant/` exists | `.aiassistant/rules/<module>.md` | File pattern type metadata |
| Claude Code | `.claude/` exists | `.claude/rules/<module>.md` | Directory-based (no frontmatter needed) |
| Cline | `.clinerules/` exists | `.clinerules/<module>.md` | `paths: ["<source-path>/**"]` in YAML frontmatter |
| Windsurf | `.windsurf/` exists | `.windsurf/rules/<module>.md` | Frontmatter trigger metadata |
| Amazon Q | `.amazonq/` exists | `.amazonq/rules/<module>.md` | Standard markdown (per-session) |

### Per-Module Routing File Content

Each routing file is SELF-CONTAINED. It contains the full module skill content (from Step 3) plus platform-specific frontmatter. The agent using this file should not need to read any other file to understand the module.

**Template (Cursor example):**

```markdown
---
globs: ["src/billing/**"]
---

# Billing Module

> [Full module skill content from .ai/skills/modules/billing.md]

[... entire module skill, verbatim ...]
```

### Parallelisation: Platform Glue

If generating per-module routing for **3+ platforms** with **5+ modules**, parallelise by platform. Each subagent generates all routing files for one platform.

**Model selection:** Use `sonnet` — mechanical file generation with clear templates.

### Generate Skill Drift Detection Tools

Write three files to `.ai/skills/Tools/` in the target repo:

#### 1. `skill-drift.sh` — the drift detection script

Read the template from the RepoSkills skill directory (`templates/skill-drift.sh`) and customise it:

1. Populate the `CROSS_CUTTING` array from `_boundaries.md` (optional) — use the directories listed under "Cross-Cutting (not boundaries)". This array ONLY affects the unmapped directory report, not the core drift detection. If the repo has few cross-cutting directories (under ~5), leave the array empty — the unmapped report will be manageable without it. Populate it for repos with many shared packages (like a Go repo with 20+ utility packages in `pkg/`) where the unmapped report would otherwise be too noisy to act on.
2. Populate the `SCAN_DIRS` array based on the repo's module structure — use the top-level directory patterns where modules live (e.g., `'src/*/'`, `'pkg/*/'`, `'cmd/*/'`). Derive these from the confirmed boundaries: look at the common parent directories of the boundary entry points.
3. Write to `.ai/skills/Tools/skill-drift.sh` and make executable (`chmod +x`)
4. Verify it runs in the target repo

**The script requires bash 4+.** On macOS, the default bash is 3.2. The script includes a version check and suggests `brew install bash`. Do not change the script to accommodate bash 3.2 — associative arrays are fundamental to the design.

**How it works:**
- Parses CLAUDE.md's Module Routing table to build a directory-to-skill map
- For each mapped directory, compares the skill's last-modified git commit against code changes (excluding test files and markdown)
- Reports skills that have drifted and directories with no skill coverage
- Three output modes: human-readable (default), `--quiet` (exit code only), `--json` (structured output for CI/PR comments)

**Routing completeness is critical.** The drift script maps directories to skills using the Module Routing table's USE WHEN column. If a module owns directories that aren't listed in its USE WHEN entry, drift in those directories won't be detected. Ensure every directory a module covers is listed with a backtick-wrapped trailing-slash path (e.g., `` `pkg/sync/` ``) in the USE WHEN column.

#### 2. `skill-drift-hook.sh` — hook management script

Copy the template from `templates/skill-drift-hook.sh` to `.ai/skills/Tools/skill-drift-hook.sh` and make executable. This script requires no repo-specific customisation.

Provides `install`, `uninstall`, and `status` commands for managing the drift check as a local git hook. Supports both pre-commit and post-commit hooks. Appends to existing hooks rather than overwriting them.

**Important limitation:** Git hooks are local to each developer's clone. Installing this hook only benefits the developer who runs `install` — other team members won't see drift warnings unless they also install it. For team-wide coverage, CI integration is recommended (see Phase 9).

#### 3. CI workflow template (Phase 9 decision)

The CI workflow (`templates/skill-drift-ci.yml`) is NOT written during Phase 2. It is offered to the human during Phase 9 as an opt-in. If accepted, the workflow is written to the repo's CI directory (e.g., `.github/workflows/skill-drift.yml` for GitHub Actions) and adapted for the repo's CI platform if needed.

**Update state:** Mark step 2.5 complete in `state.md`.

---

## Step 6: Self-Review

Run through this checklist before marking Phase 2 complete. Do not skip this step. Every item must pass.

### Boundary Integrity
- [ ] Every module skill's Relationships section references only modules that have skill files
- [ ] Every module skill's "Depends on" entries are verified from actual import statements
- [ ] Every module skill's "Depended on by" entries are verified by grepping
- [ ] Relationship sections are SYMMETRIC: if A depends on B, B lists A as a dependent

### Routing Integrity (CRITICAL)
- [ ] ALL FOUR root platform files (CLAUDE.md, AGENTS.md, copilot-instructions.md, .cursorrules) contain BOTH a Module Routing table AND a Task Routing table
- [ ] Every module skill has a corresponding row in the Module Routing tables
- [ ] Every task skill has a corresponding entry in the Task Routing tables
- [ ] Every routing entry points to a skill file that exists on disk
- [ ] Routing tables are IDENTICAL across all four root platform files
- [ ] USE WHEN keywords in the routing table are task-oriented, not technical jargon
- [ ] Module Routing USE WHEN column lists ALL directory paths each module covers (backtick-wrapped with trailing slash) — drift detection parses these to map code changes to skills

### Path Verification
- [ ] Every entry point file path in every module skill exists in the repo
- [ ] Every config file referenced for version pinning exists
- [ ] Every folder structure described in skills matches the actual codebase
- [ ] Skills describe test CONVENTIONS (co-located, mirrored, etc.) rather than listing individual test file paths
- [ ] No skill contains individual file paths that could be found via glob/grep — entry points and folder structures are OK

### Command Verification
- [ ] Every command in orientation.md Quick Reference traces to a `package.json` script, `Makefile` target, `Cargo.toml`, CI config, or equivalent for the repo's language
- [ ] Every command in task skills traces to an actual config file
- [ ] Every test command in module skills traces to an actual config file or test runner
- [ ] The scripts/commands task skill has the COMPLETE command reference — every command in the actual config files is listed
- [ ] Key Commands quick reference is IDENTICAL across all four root platform files
- [ ] Root file Key Commands sections point to the scripts task skill for the full reference

### Token Budget Compliance
- [ ] Orientation skill is under ~2k tokens
- [ ] Every module skill is under ~1.5k tokens
- [ ] Every task skill is under ~1.5k tokens
- [ ] AGENTS.md is under ~4k tokens (32KB hard limit)
- [ ] CLAUDE.md is under ~3-4k tokens (self-sufficient — must NOT redirect to other root files)

### 5-Second Grep Test
- [ ] No skill contains a list of files in a directory
- [ ] No skill contains a list of routes/endpoints
- [ ] No skill contains copies of type definitions or schemas
- [ ] No skill contains a list of environment variables
- [ ] No skill contains function signatures or method lists
- [ ] No skill contains individual file paths to tests, configs, or examples (describe conventions/folder structures instead)
- [ ] No skill contains exact counts or numbers (e.g., "247 Go files", "12 targets") — these are greppable and high-fabrication-risk
- [ ] Information in skills provides UNDERSTANDING, not LOOKUP DATA

### Content Quality
- [ ] No skill claims "X probably does Y" or "X likely does Y" — either verified or marked `<!-- TODO: verify -->`
- [ ] No content invented that is not traceable to a source file
- [ ] No exact numbers or counts appear unless they were actually verified by running a command
- [ ] Every module skill's purpose explains WHY (business context), not just WHAT (technical function)
- [ ] Gotchas are specific and actionable — "what happens, why, how to avoid"

### Platform Glue Consistency
- [ ] AGENTS.md tech stack matches orientation.md tech stack
- [ ] AGENTS.md module index matches orientation.md boundary list
- [ ] Per-module routing files contain the same content as their canonical module skill
- [ ] .cursorrules content matches AGENTS.md
- [ ] Per-module routing files exist only for platforms detected in `_triage.md`

### Maintenance Tools
- [ ] `.ai/skills/Tools/skill-drift.sh` exists and is executable
- [ ] `.ai/skills/Tools/skill-drift-hook.sh` exists and is executable
- [ ] CROSS_CUTTING array is either empty or matches the cross-cutting directories from `_boundaries.md`
- [ ] SCAN_DIRS array covers the directory patterns where modules live
- [ ] Both scripts run without errors in the target repo (`skill-drift.sh` and `skill-drift-hook.sh status`)
- [ ] All four root platform files reference the drift detection tools in the Skill & Routing Maintenance section

### Required Sections in Root Platform Files
All four root files (CLAUDE.md, AGENTS.md, .cursorrules, copilot-instructions.md) must be self-sufficient and MUST each contain ALL of these sections:
- [ ] Tech Stack (language, framework, version pinning sources)
- [ ] Architecture (system shape + boundary list)
- [ ] Key Commands (build, test, lint, dev commands with sources)
- [ ] Key Rules (repo-specific critical rules — things that break if violated)
- [ ] Module Routing (table with USE WHEN keywords)
- [ ] Task Routing (table mapping intents to skill combinations)
- [ ] Context Window Discipline (directories to never browse, generated file guidance)
- [ ] Before Modifying Code (read module skill, check Change Impact, read orientation)
- [ ] Skill & Routing Maintenance (living docs guidance, refactoring updates)
- [ ] Documentation (pointers to skill layer: orientation, modules, tasks, domain context)
- [ ] Coding Standards (DRY, follow patterns, maintain quality)
- [ ] New to This Repo? (numbered onboarding steps)
- [ ] No root file redirects to another root file — each stands alone

### Coverage
- [ ] Module skills cover ALL Tier 1 boundaries from the confirmed boundary map
- [ ] Tier 2 boundaries (if any) have abbreviated skills
- [ ] All task skills flagged by Phase 0 have been generated
- [ ] If `tasks/testing.md` exists, it includes a Test Style & Conventions section derived from actual test files (or marked as best-practice fallback if repo has minimal tests)
- [ ] Every `<!-- TODO: verify -->` and `<!-- TODO: ask human -->` is logged in `_questions.md`

### Structural Integrity
- [ ] `.ai/skills/` directory structure is clean: `orientation.md`, `modules/`, `tasks/`, `domain-context.md` (if exists)
- [ ] No orphan files — every skill file is referenced from the routing tables in CLAUDE.md / AGENTS.md
- [ ] No duplicate facts — each fact lives in exactly one canonical location
- [ ] Module skill overrides reference task skills that exist

Fix any issues found. Then:

**Update state:** Mark step 2.6 (review) complete in `state.md`. Update Phase 2 to complete with timestamp.

---

## Parallelisation Guide

### When to parallelise

| Step | Parallelise when... | Pattern |
|------|---------------------|---------|
| 1: Confirm boundaries | 10+ boundary candidates | Batch verification subagents |
| 3: Module skills | 5+ module skills to write | One subagent per 1-3 modules |
| 5: Platform glue (per-module) | 3+ platforms AND 5+ modules | One subagent per platform |
| Steps 2, 4, 6 | Never | Sequential — these require judgment |

### Subagent dispatch protocol

1. **Define tasks:** List the independent work units
2. **Write task context inline:** Each subagent prompt must include ALL context it needs — the full task description, relevant file paths, rules to follow, and output file path. Do NOT reference other files the subagent would need to read for instructions (except the codebase itself).
3. **Assign output files:** Each subagent writes to a unique file in the MEMORY directory
4. **Dispatch in parallel:** Use the Agent tool with `run_in_background: true`
5. **Collect and merge:** When all subagents complete, read their output files and integrate

### Subagent failure handling

1. **Re-dispatch once** with the same task (failures are often transient)
2. **If it fails again:** Fall back to sequential — write the output yourself to the same file path
3. **Log the failure** in `state.md`: `<!-- Subagent failure: [task], fell back to sequential -->`
4. **Never block the pipeline** on a failed subagent

### Model selection for subagents

| Task type | Model | Reasoning |
|-----------|-------|-----------|
| Boundary verification | `sonnet` | Mechanical reading and classification |
| Write module skill from notes | `sonnet` | Structured writing from clear template |
| Write task skill | `sonnet` | Structured writing from clear template |
| Generate platform glue files | `sonnet` | Mechanical template application |
| Merge and consistency review | `opus` | Requires synthesis and judgment |
| Self-review checklist | `opus` | Requires critical thinking |

---

## Repo Size Adaptation

### Tier A: Small Library (<50 files)

- **Step 1:** Quick verification — likely 1-3 boundaries
- **Step 2:** Orientation skill only — may be all that's needed
- **Step 3:** 0-2 module skills (skip if orientation covers everything)
- **Step 4:** Local Dev Setup only (always), maybe Testing
- **Step 5:** Root files only — skip per-module routing
- **Step 6:** Abbreviated review
- **Duration:** ~15 minutes
- **Parallelisation:** None

### Tier B: Standard App (50-500 files)

- **Steps 1-6:** Full procedure
- **Step 3:** Full module skills for all confirmed boundaries
- **Step 4:** All flagged task skills
- **Step 5:** Root files + per-module routing for detected platforms
- **Duration:** ~30-45 minutes
- **Parallelisation:** Optional for module skills

### Tier C: Large App (500+ files)

- **Steps 1-6:** Full procedure with parallelisation required
- **Step 1:** Parallel boundary verification
- **Step 3:** Parallel module skill writing in waves of 10-15
- **Step 4:** All flagged task skills
- **Step 5:** Parallel per-module routing by platform
- **Duration:** ~60-90 minutes

### Tier D: Monorepo (multi-project)

- **Steps 1-6:** Full procedure with heavy parallelisation
- **Step 1:** Parallel boundary verification — expect 20-40+ candidates
- **Step 3:** Tier 1 (full skills, max 10) + Tier 2 (abbreviated, 15-20) + Tier 3 (orientation mention only)
- **Step 4:** All flagged task skills — pay special attention to per-module overrides
- **Step 5:** Per-module routing is HIGH VALUE here — many platforms, many modules
- **Duration:** ~90-120 minutes

---

## Priority Order

1. **Accuracy** — wrong skills are worse than no skills
2. **Understanding** — every skill must explain WHY, not just WHAT
3. **Conciseness** — 1.5k tokens means every sentence must earn its place
4. **Routability** — can an agent find the right skill in one lookup?
5. **Impact clarity** — what breaks when X changes?
6. **Actionability** — concrete paths, real commands, real examples
7. **Evidence** — every claim traceable to a source file
8. **Completeness** — all boundaries covered, all task skills generated

---

## Anti-Patterns

Watch for these rationalizations and resist them:

- **"This file list is useful context"** — No. It fails the 5-second grep test. Cut it.
- **"I'll include the full schema for convenience"** — No. Point to the source file. Schemas change; your copy will go stale.
- **"This module is too complex for 1.5k tokens"** — Then you are including greppable information. Cut the WHAT, keep the WHY and the GOTCHAS.
- **"I remember what the code does"** — You don't. Read the file. Every time.
- **"This is probably right"** — Probably is not verified. Check it or mark it `<!-- TODO: verify -->`.
- **"I'll update state.md later"** — Update it now. If you don't, context recovery fails and work gets repeated.
- **"The subagent will figure it out"** — Give the subagent complete context inline. Don't assume it can read your mind.
- **"This module doesn't need a gotchas section"** — If you found no gotchas, say "None found." Don't silently omit the section — the agent needs to know you checked.
- **"The orientation skill covers this, so the module skill can skip it"** — Module skills must be useful standalone. The agent may read the module skill without the orientation. Include what matters.
- **"I should include this env var for completeness"** — Does it fail the 5-second grep test? Then don't include it.
