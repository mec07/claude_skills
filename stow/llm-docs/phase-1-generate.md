# Phase 1: Generate — Build an LLM-Optimised Documentation Layer

You are working with full filesystem access to the repository. Your job is to explore the codebase thoroughly and create a structured, high-signal markdown documentation layer that makes this repo legible to LLM coding agents.

**This phase is exploration and writing only. Do not verify your output — that is Phase 3's job.** Focus your full effort on understanding the codebase deeply and documenting it accurately.

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

Read `docs/llm/_original_documentation.md` (produced by Phase 0). This tells you:
- What documentation already exists and where it lives
- How reliable each doc is (confidence scores from spot-checking claims against code)
- Which docs to trust as starting facts and which to treat with skepticism
- What areas of the codebase have no documentation at all (these need the most thorough exploration)

For every doc rated **high confidence**, read the original doc now and treat its verified claims as starting facts — build on them. For **medium confidence** docs, read them but verify key claims as you explore. For **low confidence** docs, note their existence but do not build on their claims without independent verification from source code.

If `_original_documentation.md` reports that no documentation exists at all, proceed to Step 1 with no starting assumptions — rely entirely on source code exploration.

---

## Step 1: Systematic exploration (write NOTHING yet)

You must complete ALL of the following before writing any documentation file. Do not skip ahead.

**1a. Map the repo structure**

List all directories to a reasonable depth, excluding generated/dependency directories (`node_modules`, `.git`, `dist`, `build`, `.next`, `__pycache__`, `.turbo`, `.cache`, vendor directories, etc.).

Record what you find. Identify the top-level organisation pattern.

**1b. Read existing documentation**

`_original_documentation.md` indexes all existing documentation with confidence scores. Use it as your reading guide:
- Read all **high-confidence** docs fully — these are your most reliable sources
- Read all **medium-confidence** docs — useful context but verify key claims as you encounter them
- Skim **low-confidence** docs for structural information only — do not trust their factual claims
- Also search for any markdown files that Phase 0 may have missed (unusual locations, non-standard names, etc.) and read those too

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

**1d. Understand each major directory**

For every top-level directory (and significant nested directories):
1. List its contents
2. Read at least the entry point file, main config file, and one representative source file
3. Read its `package.json` or equivalent if it has one
4. Understand what it actually does — not what its name implies

**A directory named `services/` might contain service definitions, or service workers, or microservice configs, or something else entirely. You do not know until you read the files inside it.**

**1e. Trace key flows**

Read enough source code to understand at least one complete flow through the system. What constitutes a "flow" depends on the repo:
- Web app: user action → frontend → API → backend → data store
- CLI tool: command invocation → argument parsing → execution → output
- Library: public API call → internal processing → result
- Pipeline: input ingestion → transformation → output

This is how you discover real architecture, not by guessing from folder structure.

**1f. Identify real commands**

Find commands from `package.json` scripts, `Makefile` targets, CI config steps, `pyproject.toml` scripts, or equivalent. Only commands found in these files may appear in your documentation.

**1g. Hunt for gotchas**

Search for `HACK`, `FIXME`, `XXX`, `WORKAROUND`, `IMPORTANT`, `NOTE:`, `TODO` comments across source files. Read the flagged files to understand what the warnings are about.

**Step 1 is complete only when you can answer these questions from evidence:**
- What does this repo do?
- What is the tech stack? (cite config files)
- What are the major components? (cite directories and entry files you read)
- How do they connect? (cite import chains or API calls you traced)
- What commands exist? (cite config files where you found them)
- What conventions are used? (cite repeated patterns across files you read)

### Large repos

If the repo has more than ~20 top-level directories or is a monorepo with multiple packages:

- **Prioritise breadth over depth.** Map the full structure and read configs/entry points for every module. Deep-dive the 5–10 most important or most-connected modules. For others, read at minimum the entry point and package config.
- **Use subagents for parallel exploration** if the runtime supports it. Each subagent can explore one major area independently.
- **Document your coverage.** At the end of Step 1, note which modules you explored in depth vs. surveyed. Phase 2 will fill gaps.

---

## Step 2: Write the documentation

### Output structure
```
docs/llm/
├── overview.md
├── architecture.md
├── conventions.md
├── workflows.md
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

### File specifications

#### `docs/llm/overview.md`
The first file any agent should read.

Required content:
- What this repo is (1-2 sentences, sourced from high-confidence existing docs or README)
- Tech stack with evidence: `Technology — found in path/to/config`
- Repo layout: every top-level directory with a one-line description of what it **actually contains** (not what you think it might contain)
- Key entry points: exact file paths to main server file, app entry, CLI entry, etc.
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
```

Do not use `@` file includes — they load full file contents into every conversation, wasting context on documentation irrelevant to the current task.

If a `CLAUDE.md` already exists, read it first. Preserve any existing project-specific content (custom rules, important caveats). Add the documentation pointer section alongside it.

#### `.github/copilot-instructions.md`

**If this file exists:** Do not reduce its quality. You may:
- Add links to the new `docs/llm/` files
- Add a note pointing to the canonical docs for deeper information
- Add any important conventions or gotchas you discovered that it currently lacks

Do NOT rewrite it from scratch. Append/improve only.

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
