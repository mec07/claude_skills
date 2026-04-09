# Phase 1: Generate — Build an LLM-Optimised Documentation Layer

You are working with full filesystem access to the repository. Your job is to explore the codebase thoroughly and create a structured, high-signal markdown documentation layer that makes this repo legible to LLM coding agents.

**This phase is exploration and writing only. Do not verify your output — that is Phase 3's job.** Focus your full effort on understanding the codebase deeply and documenting it accurately.

---

## Checklist

Track your progress against this checklist. Update `state.md` after completing each item.

```
- [ ] 0: Read baseline assessment (_original_docs.md)
- [ ] 1a: Map repo structure
- [ ] 1b: Read existing docs
- [ ] 1c: Identify tech stack
- [ ] 1d: Understand each major directory
- [ ] 1e: Trace key flows
- [ ] 1f: Identify real commands
- [ ] 1g: Inventory all scripts
- [ ] 1h: Hunt for gotchas
- [ ] 1i: Assign module coverage tiers (if 20+ modules)
- [ ] GATE: Confirm all exploration complete (answer 7 questions)
- [ ] 2: Write documentation
- [ ] review: Self-review checklist
```

---

## Inputs and Outputs

**Inputs (read from disk):**
- `~/.claude/MEMORY/llm-docs/<repo-slug>/_original_docs.md` — Phase 0's assessment of existing documentation
- `~/.claude/MEMORY/llm-docs/<repo-slug>/state.md` — current progress state
- The target repository codebase (full filesystem access)

**Outputs (written to disk):**
- `docs/llm/**` in the target repo — all documentation files
- `CLAUDE.md` in the target repo root
- `.github/copilot-instructions.md` in the target repo
- `docs/README.md` in the target repo
- Local context files in important subdirectories
- `~/.claude/MEMORY/llm-docs/<repo-slug>/_explore_<area>.md` — per-area exploration notes (working files, consumed during writing phase)
- `~/.claude/MEMORY/llm-docs/<repo-slug>/state.md` — updated with progress

---

## CRITICAL RULES — read before doing anything

**DO NOT HALLUCINATE. DO NOT GUESS. DO NOT INFER FROM FILENAMES.**

- You must read a file before making any claim about its contents.
- You must not describe what a file "probably" does based on its name or location.
- You must not invent APIs, endpoints, schemas, services, or architectural patterns.
- If you have not read the source code of a module, you may not document it.
- If something is unclear after reading the code, mark it `<!-- TODO: verify -->` — do not fill the gap with a plausible guess.
- Every file path you reference must exist. Verify before writing it into a doc.
- Every command you document must come from an actual config file (`package.json` scripts, `Makefile`, CI config, etc.). Do not invent commands.

**Accuracy is the single most important requirement. If you are unsure about something, say so explicitly or leave it out. Wrong documentation is actively harmful — worse than no documentation.**

---

## Step 0: Read the baseline assessment

Read `~/.claude/MEMORY/llm-docs/<repo-slug>/_original_docs.md` (produced by Phase 0). This tells you:
- What documentation already exists and where it lives
- How reliable each doc is (confidence scores from spot-checking claims against code)
- Which docs to trust as starting facts and which to treat with skepticism
- What areas of the codebase have no documentation at all (these need the most thorough exploration)

For every doc rated **high confidence**, read the original doc now and treat its verified claims as starting hypotheses — build on them but verify each specific claim you incorporate against source code. High confidence means the sample looked good, not that every claim is correct. For any claim you carry forward from a baseline doc into your generated docs, confirm it against at least one source file. This prevents anchoring bias where a mostly-correct doc has a few wrong claims that propagate unchecked. For **medium confidence** docs, read them but verify key claims as you explore. For **low confidence** docs, note their existence but do not build on their claims without independent verification from source code.

If `_original_docs.md` reports that no documentation exists at all, proceed to Step 1 with no starting assumptions — rely entirely on source code exploration.

**Structure independence:** Build the `docs/llm/` structure from the codebase's actual architecture, not from the existing documentation's structure. Existing docs may use a taxonomy (e.g., grouped by team, by deployment environment, by historical project phase) that doesn't serve LLM agents well. The `docs/llm/` structure should reflect code boundaries, not doc boundaries.

### Build the expected file manifest

Before proceeding to exploration, build a manifest of every file the skill spec says should exist. Check each against disk:

1. List the expected top-level docs: `overview.md`, `architecture.md`, `conventions.md`, `workflows.md`, `scripts.md`, `gotchas.md`, `dependency-map.md` (plus `glossary.md` if warranted).
2. List the expected entry points: `CLAUDE.md`, `.github/copilot-instructions.md`, `docs/README.md`.
3. Module docs (`docs/llm/modules/<name>.md`) cannot be listed yet — they depend on exploration results. They will be added to the manifest after Step 1. **After exploration, compare discovered modules against existing module docs. For each discovered module with no existing doc: mark as `generate` (coverage gap). For each existing module doc whose module no longer exists in the codebase: mark as `orphaned`. Record both gaps and orphans in the manifest for Phase 2.**
4. For each file, check if it exists in the target repo and count its lines.
5. **Write the manifest to `~/.claude/MEMORY/llm-docs/<repo-slug>/_manifest.md`** using the format specified in SKILL.md (section "Manifest format"). **You must read that section before writing the manifest** — it defines the exact markdown table format with columns: File, Disposition, Confidence, Lines, Notes. Disposition values are: `preserved`, `generated`, `orphaned`, `skipped`, `modified_by_phase_5`. This file is read by Phases 2, 6, 7, and 8.

**File disposition rules (unless `--fresh` was specified):**
- **File exists + >20 lines + Phase 0 scored `high-confidence`:** Mark as `preserve` — do not rewrite this file in Step 2.
- **File exists + >20 lines + Phase 0 scored `medium-confidence`:** Mark as `generate` — the doc has substance but Phase 0 found staleness concerns. Rewrite from scratch using exploration findings.
- **File exists + >20 lines + Phase 0 scored `low-confidence`:** Mark as `generate` — the doc is unreliable. Rewrite from scratch.
- **File exists + >20 lines + NOT assessed by Phase 0** (e.g., `docs/llm/` file from a previous llm-docs run that Phase 0 didn't individually assess): Mark as `preserve` — treat previous llm-docs output as trustworthy by default.
- **File missing or stub (<=20 lines):** Mark as `generate` — write this file from scratch in Step 2.
- **`--fresh` mode:** If the user invoked with "Run llm-docs fresh", mark ALL files as `generate` regardless of what exists. Skip the existence and confidence checks entirely.

After exploration (Step 1) identifies modules, update the manifest with module doc entries following the same rules.

**Update state:** Mark step 0 complete in `state.md`.

---

## Step 1: Systematic exploration (write NOTHING yet)

**HARD GATE: Do NOT write any documentation until ALL exploration steps (1a through 1h) are complete and the completion criteria are satisfied.** Premature writing produces docs that reflect partial understanding. Complete all exploration first, then write from comprehensive knowledge.

You must complete ALL of the following before writing any documentation file. Do not skip ahead.

**1a. Map the repo structure**

List all directories to a reasonable depth, excluding generated/dependency directories (`node_modules`, `.git`, `dist`, `build`, `.next`, `__pycache__`, `.turbo`, `.cache`, vendor directories, etc.).

Record what you find. Identify the top-level organisation pattern.

**Update state:** Mark step 1a complete in `state.md`.

**1b. Read existing documentation**

`_original_docs.md` indexes all existing documentation with confidence scores. Use it as your reading guide:
- Read all **high-confidence** docs fully — these are your most reliable sources
- Read all **medium-confidence** docs — useful context but verify key claims as you encounter them
- Skim **low-confidence** docs for structural information only — do not trust their factual claims
- Also search for any markdown files that Phase 0 may have missed (unusual locations, non-standard names, etc.) and read those too

**Re-investigation for medium/low-confidence areas:** Areas covered by medium- or low-confidence existing docs need *more* exploration, not less. Stale documentation creates a false sense of understanding — the agent (and human) may assume an area is well-understood when it isn't. For areas where existing docs scored medium or low, explore with the same thoroughness as undocumented areas. Do not assume the existing doc's claims are even directionally correct.

**Update state:** Mark step 1b complete in `state.md`.

**1c. Identify the tech stack from actual config files**

Read these files where they exist — do not guess from folder names:
- `package.json` (and workspace/monorepo config if present)
- Language config: `tsconfig.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `build.gradle`, `pom.xml`, etc.
- Build config: `next.config.*`, `vite.config.*`, `webpack.config.*`, `CMakeLists.txt`, etc.
- Infrastructure: `Dockerfile`, `docker-compose*`
- CI: `.github/workflows/*.yml`, `.gitlab-ci.yml`, `Jenkinsfile`, etc.
- Environment: `.env.example`, `.env.local.example`
- Database/ORM config files
- Any other config files at the repo root

For every technology you list in the docs, you must be able to point to the config file or dependency declaration where you found it.

**Update state:** Mark step 1c complete in `state.md`.

**1d. Understand each major directory**

For every top-level directory (and significant nested directories):
1. List its contents
2. Read at least the entry point file, main config file, and one representative source file
3. Read its `package.json` or equivalent if it has one
4. Understand what it actually does — not what its name implies

**A directory named `services/` might contain service definitions, or service workers, or microservice configs, or something else entirely. You do not know until you read the files inside it.**

**Update state:** Mark step 1d complete in `state.md`.

**1e. Trace key flows**

Read enough source code to understand at least one complete flow through the system. What constitutes a "flow" depends on the repo:
- Web app: user action → frontend → API → backend → data store
- CLI tool: command invocation → argument parsing → execution → output
- Library: public API call → internal processing → result
- Pipeline: input ingestion → transformation → output

This is how you discover real architecture, not by guessing from folder structure.

**Update state:** Mark step 1e complete in `state.md`.

**1f. Identify real commands**

Find commands from `package.json` scripts, `Makefile` targets, CI config steps, `pyproject.toml` scripts, or equivalent. Only commands found in these files may appear in your documentation.

**Update state:** Mark step 1f complete in `state.md`.

**1g. Inventory all scripts**

Systematically locate every script across the repository. Scripts can live in many places — this step must be thorough:
- `package.json` `scripts` blocks (root and every nested package in monorepos)
- Shell scripts (`.sh`, `.bash`, `.zsh`) — search all directories, not just `scripts/` or `bin/`
- `Makefile` / `Justfile` / `Taskfile.yml` targets (root and nested)
- Python scripts used as tools (`.py` files in `scripts/`, `tools/`, `bin/`, or similar)
- CI workflow steps that invoke custom scripts (`.github/workflows/`, `.gitlab-ci.yml`, etc.)
- Docker entrypoint scripts
- Any other executable files or task-runner configurations

For each script, record: its location, what it does (read it — do not guess from the filename), when it's used (build, dev, CI, deploy, ad-hoc), and any arguments it accepts.

Additionally, for each script ecosystem you find:
- **Shared utilities:** Identify reusable modules available to scripts (DB connectors, API clients, message queue helpers, common utilities). These are critical — agents writing new scripts need to know what already exists.
- **Credentials and environment variables:** Note which env vars scripts need and how credentials are obtained (e.g., AWS Secrets Manager, env files, service tokens). These often differ from the main application's credential patterns.
- **Auth patterns:** If scripts interact with authenticated APIs or services, document which auth methods work for scripts and which don't. This is a common source of wasted time.
- **Scaffolding pattern:** How are new scripts structured? (e.g., own directory with `package.json`, or single file in a scripts folder). Identify the canonical example to follow.

In monorepos, pay particular attention to which package or project each script belongs to, and whether scripts at different levels share patterns or conventions.

**Update state:** Mark step 1g complete in `state.md`.

**1h. Hunt for gotchas**

Search for `HACK`, `FIXME`, `XXX`, `WORKAROUND`, `IMPORTANT`, `NOTE:`, `TODO` comments across source files. Read the flagged files to understand what the warnings are about.

**Update state:** Mark step 1h complete in `state.md`.

**1i. Assign module coverage tiers (repos with 20+ modules only)**

If exploration identified 20+ modules warranting documentation, assign coverage tiers:
- **Tier 1** (full module docs — 10 max): Most important or most-connected modules. Criteria: highest dependency count, entry points, or cross-module import frequency.
- **Tier 2** (summary module docs — 15-20): Medium importance. Docs include: purpose, location, key files, dependencies, dependents. No deep flow tracing.
- **Tier 3** (overview mention only): Remaining modules. One-line description and path in `overview.md`. No individual module doc.

Record tier assignments in `state.md` AND in `_manifest.md` so all subsequent phases know the coverage expectations.

For repos with <20 modules, skip tiering — all modules get full docs.

**Update state:** Mark step 1i complete in `state.md`.

---

### Exploration completion gate

**Step 1 is complete only when you can answer these questions from evidence:**
- What does this repo do?
- What is the tech stack? (cite config files)
- What are the major components? (cite directories and entry files you read)
- How do they connect? (cite import chains or API calls you traced)
- What commands exist? (cite config files where you found them)
- What scripts exist and where do they live? (cite every location you found them)
- What conventions are used? (cite repeated patterns across files you read)

**If you cannot answer all seven questions with cited evidence, go back and explore more before proceeding.**

**Update state:** Mark the GATE step complete in `state.md`.

---

### Parallelisation: Exploration phase

If the repo has **10+ major directories**, parallelise exploration using subagents. If the repo is smaller, run exploration sequentially — subagent overhead is not worth it.

**Protocol:**

1. Complete steps 1a-1c yourself (structure mapping, doc reading, tech stack identification). These provide the shared context subagents need.
2. Identify major areas for parallel exploration (one per top-level directory or logical grouping).
3. Dispatch one subagent per area. Each subagent handles steps 1d and 1e for its assigned area, plus 1g and 1h within that area.
4. Each subagent writes its findings to `~/.claude/MEMORY/llm-docs/<repo-slug>/_explore_<area>.md`.
5. When all subagents complete, read all `_explore_*.md` files and synthesise the results. Fill any gaps. Complete steps 1f and 1g at the repo-wide level (commands and scripts may span areas).

**Subagent prompt template for exploration:**

Each subagent must receive ALL of the following inline — do not reference external instruction files:
- The area to explore (directory path, scope)
- The CRITICAL RULES section (do not hallucinate, do not guess, etc.)
- Instructions for steps 1d, 1e, 1g, 1h scoped to their area
- The tech stack summary from step 1c (so they understand the ecosystem)
- The output file path: `~/.claude/MEMORY/llm-docs/<repo-slug>/_explore_<area>.md`
- Instructions to structure output as: Purpose, Key Files, Internal Structure, Flows Traced, Scripts Found, Gotchas Found, Dependencies (internal and external), Communication Patterns

**Model selection:** Use `sonnet` for exploration subagents. This is mechanical reading and summarising work.

**If a subagent fails** to produce its `_explore_<area>.md` file: re-dispatch once. If it fails again, the orchestrating agent explores that area sequentially. Note the gap in `state.md`.

---

### Large repos

If the repo has more than ~20 top-level directories or is a monorepo with multiple packages:

- **Prioritise breadth over depth.** Map the full structure and read configs/entry points for every module. Deep-dive the 5–10 most important or most-connected modules. For others, read at minimum the entry point and package config.
- **Use subagents for parallel exploration** as described above. Each subagent can explore one major area independently.
- **Document your coverage.** At the end of Step 1, note which modules you explored in depth vs. surveyed. Phase 2 will fill gaps.

---

## Step 2: Write the documentation

**HARD GATE: Confirm that ALL exploration steps (1a through 1h) are complete and the completion criteria are satisfied before proceeding.** If any exploration step is unchecked in `state.md`, go back and complete it.

### Per-file skip logic

Before writing any file, consult the manifest built in Step 0. For each file:

- **Disposition `preserve`:** This file already exists with substantial content from a previous run. **Do not overwrite it.** Move on to the next file. Phase 2 will assess whether it needs structural updates.
- **Disposition `generate`:** This file is missing or a stub. Write it from scratch following the specs below.

After completing all writing, **update `_manifest.md`** in the MEMORY directory with final module doc dispositions and tier assignments (the pre-exploration manifest only had top-level docs). Then **emit the file disposition summary** to the user:

```
Phase 1 file disposition:
- PRESERVED (N): [list of files kept from previous run]
- GENERATED (N): [list of files written from scratch]
- SKIPPED (N): [list of files not warranted for this repo, e.g., glossary.md]
```

This summary is mandatory. It tells the user exactly what changed and enables informed use of the `--fresh` flag if they want a full regeneration next time.

### Output structure
```
docs/llm/
├── overview.md
├── architecture.md
├── conventions.md
├── workflows.md
├── scripts.md
├── gotchas.md
├── glossary.md              (only if warranted — see spec below)
├── dependency-map.md
└── modules/
    └── <one-file-per-major-module>.md

CLAUDE.md                          (repo root)
.github/copilot-instructions.md    (update if exists, create if not)
docs/README.md
+ local context files in important subdirectories
```

### Writing rules (apply to every file)

- **Cite your sources.** When you say "X uses Y", include the file path where you found that.
- **Use exact paths.** `src/server/api/routers/project.ts`, not "the project router".
- **Use exact commands.** `pnpm run dev`, not "run the dev server".
- **Short sections, dense content.** No introductory paragraphs, no filler, no marketing prose.
- **Bullet lists over paragraphs** for factual content.
- **Cross-link aggressively.** Every module doc should link to related docs. Every top-level doc should link to relevant module docs.
- **Never copy schemas, types, or table definitions into markdown.** Point to the source file.
- **When in doubt, leave it out.** A gap is better than a fabrication.
- **Every fact in one place.** If information belongs in a module doc, put it there and link from top-level docs. Do not restate the same fact in multiple files.

---

### Parallelisation: Writing phase

If you need to write **5+ documentation files**, parallelise writing using subagents. If fewer, write sequentially.

**Protocol:**

1. Plan all doc files to write. For each, determine what exploration data it needs.
2. Dispatch one subagent per doc file. Each subagent writes exactly one file.
3. Each subagent receives inline:
   - The file specification from the relevant section below
   - All exploration notes relevant to that file (from `_explore_*.md` files and your synthesised notes)
   - The CRITICAL RULES and Writing Rules sections
   - The target file path in the repo
   - The cross-link targets (list of other docs being created, so links can be correct)
4. When all subagents complete, review the full set for consistency, cross-link correctness, and coverage gaps. Fix any issues.

**HARD CONSTRAINT:** Do NOT dispatch parallel doc-writing subagents until `overview.md` and `architecture.md` are COMPLETE. These two files establish structural decisions that all other docs depend on. Write them first (sequentially or as a pair), verify they exist on disk, then dispatch all remaining doc-writing subagents in parallel. During the merge step, the orchestrating agent must review all cross-references across docs and fix any that don't resolve. **Duplication scan:** After fixing cross-references, scan all generated docs for the same fact appearing in multiple files. For each duplicate: keep the fact in its canonical location (module-specific details in the module doc, cross-cutting information in the top-level doc) and replace the other occurrence with a link. Log any duplicates found and resolved.

**If a writing subagent fails** to produce its doc file: the orchestrating agent writes that doc itself during the merge step using the exploration notes. Note the fallback in `state.md`.

**Model selection:**
- Use `sonnet` for writing individual doc files from clear exploration notes.
- Use `opus` for the merge/review step — it requires synthesis, consistency checking, and judgment.

**Subagent prompt template for writing:**

Each subagent must receive ALL of the following inline:
- The exact file specification (copied from the relevant section below)
- The exploration notes relevant to this file
- The full Writing Rules section
- The CRITICAL RULES section
- A list of all other doc files being created (for cross-linking)
- The target output file path

---

### File specifications

#### `docs/llm/overview.md`
The first file any agent should read.

Required content:
- What this repo is (1-2 sentences, sourced from high-confidence existing docs or README)
- Tech stack with evidence: `Technology — found in path/to/config`
- Repo layout: every top-level directory with a one-line description of what it **actually contains** (not what you think it might contain)
- Key entry points: exact file paths to main server file, app entry, CLI entry, etc.
- Script locations: brief summary of where scripts live, linking to `docs/llm/scripts.md` for the full inventory
- Links to every other `docs/llm/` file
- Index of all module docs with one-line descriptions

#### `docs/llm/architecture.md`
How the system actually works.

Required content:
- Component list: name, responsibility, primary directory, key entry file
- Communication map: for every inter-component boundary, document sender file, receiver file, mechanism (HTTP, gRPC, queue, event, direct import, etc.), and data contract location
- Data flow: trace at least one real request/event through the system with file paths at each step
- Data structure index: for every kind of data structure the project uses (DB schemas, API types, search indices, message formats, config schemas, etc.), document where definitions live, where the access/query layer lives, naming conventions, and relationships between structures
- External dependencies: databases, APIs, queues, caches — with the config file where each is configured
- Operational scripts: brief summary of what scripts exist for operations, maintenance, data repair, backfills, etc. — link to `docs/llm/scripts.md` for the full inventory. Do not duplicate the scripts inventory here; just note that scripts are part of the system's operational surface and where to find them.
- Infrastructure shape (only if deployment config exists in repo)

Format flows like:
```
Request → src/app/api/[route]/route.ts
       → src/server/services/[name].ts
       → src/db/queries/[name].ts
       → PostgreSQL (configured in src/db/index.ts)
```
Adjust to match the ACTUAL architecture you found. Do not use this example if it doesn't match.

#### `docs/llm/conventions.md`
Only patterns you observed across multiple files.

For each convention:
- State the pattern
- Cite 2-3 example files that demonstrate it
- Note any exceptions you found

Categories (include only those with evidence):
- File/directory naming
- Component/module structure
- Import patterns
- Testing (file location, naming, framework, patterns)
- Type/schema management
- Error handling
- Logging
- Environment variables
- State management
- API design patterns

#### `docs/llm/workflows.md`
Every command must come from `package.json` scripts, `Makefile`, CI config, or existing README.

Format:
```bash
# Prerequisites
<what must be installed/configured first>

# Install
<exact command>

# Dev
<exact command>

# Build
<exact command>

# Test
<exact command>

# Lint
<exact command>

# Type check
<exact command>
```

Only include sections for commands that actually exist. If a workflow requires environment variables, list exactly which ones (from `.env.example` or equivalent). If steps must happen in order, number them and explain why.

#### `docs/llm/scripts.md`
Comprehensive inventory of every script in the repository. This is the go-to file when an agent needs to create, extend, or find a script.

**Purpose:** Enable agents to quickly answer: "Does a script for X already exist?", "Can an existing script be extended to do Y?", "Where should a new script live, and what patterns should it follow?"

**Top-level sections (in order):**

**1. All Script Locations** — summary table of every directory that contains scripts:

```markdown
| Location | Language | Purpose | Docs |
|----------|----------|---------|------|
| `path/to/scripts/` | Python | Data pipelines, batch operations | [README](link) |
| `other/scripts/` | Shell | Deployment, delivery | — |
```

**2. Decision: Where to Put a New Script** — scenario-based routing table. This is the most important section for agents creating new scripts:

```markdown
| Scenario | Location | Why |
|----------|----------|-----|
| Data pipeline / batch processing | `path/to/scripts/` | Python ecosystem, shared utilities available |
| Reuse existing service logic | `app/scripts/` | Direct imports, no auth overhead |
| One-off DB operation | Depends on which codebase has the logic | |
```

Base the scenarios on actual patterns observed in the repo. Include "Why" to help agents make judgement calls for scenarios not explicitly listed.

**3. Per-ecosystem sections** — group scripts by language/runtime, not just by directory. Each ecosystem section should include:

- **Run pattern:** A single line showing how to run any script in this group (e.g., `poetry run python scripts/<script>.py [OPTIONS]`)
- **Shared utilities:** Table of reusable modules available to scripts in this ecosystem (DB connectors, API clients, message queue wrappers, etc.) with module path and purpose. Agents writing new scripts must know these exist.
- **Environment variables / credentials:** Table of env vars needed to run scripts, with purpose. Scripts often need different credentials than the main application.
- **Key patterns:** Important patterns with code examples (e.g., "direct function import bypasses HTTP and auth entirely"). Show a real snippet from the codebase.
- **Existing scripts inventory:** Table listing each script with purpose and link to per-script README where one exists:

```markdown
| Script | Purpose | Docs |
|--------|---------|------|
| `scriptName/` | What it does | [README](link) or — |
```

**4. Auth patterns for scripts** (if the repo has authentication) — table showing which auth methods work for scripts and how to use them:

```markdown
| Method | Works On | How |
|--------|----------|-----|
| Service token | Service-auth endpoints | `get_token(secret)` |
| Direct import | Any logic — bypasses auth | Import function, pass DB instance |
```

Include gotchas about auth inline (e.g., "Service tokens do NOT work on user-auth endpoints"). These traps belong here, not in gotchas.md, because agents need them when writing scripts.

**5. Script-specific gotchas** — any traps, ordering requirements, or non-obvious constraints specific to running or writing scripts. Keep these next to the scripts rather than in the general gotchas.md.

**General rules:**
- Every script directory gets a README — created by this phase if one doesn't exist (see "Script directory READMEs" under Local context files). Link to these from the "Docs" column of the All Script Locations table.
- Where per-script READMEs exist, link to them rather than duplicating their content. `scripts.md` is an index and decision guide, not a copy of every script's docs.
- In monorepos, add a cross-reference table showing which scripts exist in which packages, making it easy to spot gaps and shared patterns.
- Document the scaffolding pattern for new scripts (e.g., "each TypeScript script is its own directory with `package.json`, `tsconfig.json`, and `src/index.ts` — follow the example at `path/to/example/`").

#### `docs/llm/gotchas.md`
The most valuable file. Things that waste time or cause subtle bugs.

Each entry:
```markdown
### <Short description of the trap>
**What happens:** <the bad outcome>
**Why:** <root cause>
**Avoid by:** <concrete action>
**Found in:** <file path or evidence>
```

Include gotchas from:
- Comments you found in code (HACK, FIXME, etc.)
- Non-obvious ordering requirements
- Codegen outputs that must not be hand-edited
- Hidden coupling between modules
- Environment/config assumptions
- Anything that contradicts what you'd expect from the folder structure

#### `docs/llm/glossary.md`
Terms that have repo-specific meanings. **Only create this file if the repo uses domain-specific jargon that would genuinely confuse an LLM agent.** For repos with standard technical terminology only, skip this file.

Format:
```markdown
**Term** — Definition. Found in `path/to/relevant/file`.
```

Only include terms that actually appear in the codebase and have non-obvious, repo-specific meanings.

#### `docs/llm/dependency-map.md`
System-wide view of how modules relate to each other. This complements the per-module dependency sections in module docs by showing the full graph and cross-cutting impact analysis.

For each major module/package:
- Internal dependencies (other modules it imports)
- Key external dependencies
- Dependents (what imports it)
- Shared contracts (types, schemas, APIs that cross this boundary)
- **Change impact:** if you modify this module, what else might break?

Verify dependencies by checking actual import statements, not by guessing from folder proximity.

#### `docs/llm/modules/<name>.md`
One file per major module/package/domain.

**A module warrants its own doc if:** it has its own directory AND (its own package.json/config OR its own test files OR 10+ source files).

Each module doc must include:

| Section | Content |
|---|---|
| **Purpose** | What it does (1-2 sentences, from reading the code) |
| **Location** | Exact directory path |
| **Key files** | Entry point, config, main source files (with paths) |
| **Public interface** | What it exports/exposes to other modules |
| **Data models** | Point to type/schema/table definition files — do not copy them |
| **Dependencies** | What it imports (internal + key external) — verified from import statements |
| **Dependents** | What imports it — verified by grepping |
| **Communication** | How this module talks to and receives from other parts of the system: mechanism, sender/receiver files, contract location |
| **How to test** | Exact command, test file locations |
| **How to modify safely** | What to check, what might break, what to regenerate |
| **Related docs** | Links to relevant `docs/llm/` files |

---

### Entry point files

#### `CLAUDE.md` (repo root)
Short pointer into the canonical docs. Keep this minimal — it loads into every Claude Code conversation.

```markdown
# <Repo Name>

> One-line description.

## Documentation

The canonical LLM documentation lives in `docs/llm/`. Start with `docs/llm/overview.md`.

## Before modifying code

1. Read the relevant module doc: `docs/llm/modules/<module>.md`
2. Check for impacts: `docs/llm/dependency-map.md`
3. Check for traps: `docs/llm/gotchas.md`
4. Follow project patterns: `docs/llm/conventions.md`
5. Before creating/modifying scripts: `docs/llm/scripts.md`
```

Do not use `@` file includes — they load full file contents into every conversation, wasting context on documentation irrelevant to the current task.

If a `CLAUDE.md` already exists, read it first. Preserve any existing project-specific content (custom rules, important caveats). Add the documentation pointer section alongside it.

#### `.github/copilot-instructions.md`

**If this file exists:** Do not reduce its quality. You may:
- Add links to the new `docs/llm/` files
- Add a note pointing to the canonical docs for deeper information
- Add any important conventions or gotchas you discovered that it currently lacks

Do NOT rewrite it from scratch. Append/improve only.

**Exception:** If Phase 0 scored `.github/copilot-instructions.md` as **low confidence** (many claims wrong or stale), the preservation rule does not apply. Rewrite the file from scratch using verified information from your exploration. Note in `state.md` that the original was replaced due to low confidence score.

**If this file does not exist:** Create `.github/` directory if needed, then create the file containing:
- One-line repo description
- Tech stack summary
- Link to `docs/llm/overview.md` for full documentation
- Top 3–5 most important conventions or gotchas

#### `docs/README.md`
Simple index pointing to `docs/llm/`. List all files with one-line descriptions.

#### Local context files
In directories that have a module doc, add a short `README.md` (or `CLAUDE.md` if the repo already uses that pattern) containing:
- One line: what this directory is
- One line: `See docs/llm/modules/<name>.md for full documentation.`
- Max 2-3 lines of critical local info (e.g., "run codegen before editing types here")

Do not duplicate the module doc. These are pointers only.

#### Script directory READMEs
For every directory that contains scripts (identified in Step 1g), create a `README.md` if one does not already exist. If one exists, do not overwrite it — link to it from `scripts.md` and move on.

**Top section — overview and orientation:**
- What this directory is and what kind of scripts live here
- **Scripts overview table** with columns: Script | Purpose | When to Use. The "When to Use" column describes the symptoms or situations that indicate reaching for this script, not just what it does. If one script is the primary tool for a common task, label it (e.g., "**Primary tool** for X").
- How to run scripts in this directory (the ecosystem run pattern)
- Prerequisites (dependencies, env vars, credentials)
- Link to `docs/llm/scripts.md` for the full inventory and decision guide
- How to add a new script here (scaffolding pattern, naming conventions)

**Per-script sections** — for each non-trivial script, include a dedicated section:
- **When to use:** Bullet list of specific scenarios — the symptoms or situations where this script is the right tool
- **How it works:** Numbered steps explaining the internal mechanics. Include just enough domain context for a reader unfamiliar with the system to understand what the script does and its side effects (e.g., a brief diagram of the data flow the script operates on)
- **Safety features:** Backups, dry-run modes, recovery procedures — if the script modifies data, document what protections exist
- **Recommended workflow:** If the script has multiple modes (scan, dry-run, fix), document the safe order of operations. Users should never be left guessing whether to start with `--fix` or `--scan`
- **Usage examples:** Multiple real command lines with inline comments showing different scenarios (basic use, filtered use, dry-run, production run). Use the actual command prefix for the ecosystem (e.g., `poetry run python scripts/...`)
- **Options:** Complete list of all arguments with defaults, types, and explanations. Call out dangerous options with warnings and explain the consequences of misuse
- **Environment variables:** Required env vars listed per-script, with purpose
- **Performance characteristics:** Expected throughput, message counts, time estimates for representative workloads — helps users plan and monitor
- **Troubleshooting:** Common error messages with their causes and solutions. This saves enormous amounts of debugging time

For simple/trivial scripts (one-liners, straightforward utilities), a brief entry in the overview table is sufficient — not every script needs a full section.

Keep these practical and self-contained — a developer navigating to the directory should be able to understand, run, and create scripts without leaving.

**Update state:** Mark step 2 (write) complete in `state.md`.

---

## Self-review checklist

After writing all documentation, run through this checklist before declaring the phase complete. Do not skip this step.

### Path verification
- [ ] Every file path referenced in any doc exists in the repo (spot-check at least 20 paths across all docs)
- [ ] Every `docs/llm/modules/<name>.md` corresponds to a real directory in the codebase
- [ ] Every local context file points to a module doc that exists

### Command verification
- [ ] Every command in `workflows.md` traces to a `package.json` script, `Makefile` target, CI config, or equivalent
- [ ] Every run pattern in `scripts.md` matches the actual way scripts are invoked

### Content verification
- [ ] No documentation claims "X probably does Y" or "X likely does Y" — either verified or marked `<!-- TODO: verify -->`
- [ ] No schemas, types, or table definitions have been copied into markdown (all point to source files)
- [ ] No content has been invented that is not traceable to a source file

### Cross-link verification
- [ ] Every `[text](path)` link in every doc resolves to a file that exists
- [ ] `overview.md` links to every other `docs/llm/` file
- [ ] `overview.md` indexes all module docs
- [ ] Every module doc has a "Related docs" section with links

### Structural verification
- [ ] `CLAUDE.md` is minimal — pointer only, no `@` includes, no duplicated content
- [ ] `docs/README.md` lists all `docs/llm/` files
- [ ] No fact is stated in more than one file (facts live in one place, other files link)

### Preserved file verification (re-run only)
- [ ] Every `preserved` file's referenced paths still exist (modules may have been renamed/deleted since last run)
- [ ] Every `generated` file meets the same quality standards as a fresh run — no shortcuts because other files were preserved
- [ ] Cross-links between `preserved` and `generated` files resolve in both directions
- [ ] `_manifest.md` written to MEMORY with correct dispositions for all files (including module docs and tier assignments if applicable)

Fix any issues found. Then mark the review step complete in `state.md`.

**Update state:** Mark step `review` complete in `state.md`. Update the phase to complete with timestamp.

---

## Priority order

1. **Accuracy** — wrong docs are worse than no docs
2. **Evidence** — every claim must trace to a file
3. **Dependency clarity** — what breaks when X changes
4. **Discoverability** — can an agent find the right doc fast
5. **Actionability** — concrete paths and commands
6. **Cross-linking** — no orphan docs
7. **Completeness** — cover all major areas
8. **Brevity** — dense over verbose
