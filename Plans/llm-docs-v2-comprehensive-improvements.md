# Implementation Plan: llm-docs v2 — Comprehensive Coverage Improvements

## Context

A detailed review of the llm-docs skill against 5 critical coverage areas revealed significant gaps. Additionally, a FirstPrinciples decomposition identified 10 more areas an LLM agent needs to work productively, and a deep brainstorm + Council debate identified a structural "domain knowledge" problem where the skill can't capture business context from source code alone.

This plan addresses ALL identified gaps across 7 waves of changes.

### Design Decisions (from user)

1. **Phase D: Domain Interview** — new phase AFTER Phase 0, using letter "D" to avoid renumbering cascade (157 cross-references unchanged)
2. Phase D accepts **text dumps + website URLs** — user can paste company wiki, product docs, etc. Subagents summarise fetched webpages to manage context
3. Phase D auto-resolves interview questions from the dump, asks remaining directly
4. **Reverse Glossary** goes in Phase 8 — after full codebase exploration, present terms the skill couldn't define and ask human to correct
5. Re-runs **skip Phase D** if `docs/llm/domain-context.md` exists and Phase 0 scored it high-confidence
6. `domain-context.md` lives **in the repo** (version controlled), not in MEMORY
7. Additional exploration areas (auth, migrations, etc.) are **conditional** — check if they exist in the codebase, document if found, skip if absent

### Pipeline After Changes

```
Phase 0:  Discover            → find and assess all existing docs (including domain-context.md)
Phase D:  Domain Interview    → capture business context, domain terms, tribal knowledge (NEW)
Phase 1:  Generate            → explore codebase, create docs (ENHANCED — more exploration areas)
Phase 2:  Refine              → assess structure, expand coverage (ENHANCED — new quality bar items)
Phase 3:  Validate            → adversarial fact-check (ENHANCED — new validation checks)
Phase 4:  Clarity Review      → simulate agent tasks (ENHANCED — new scenarios)
Phase 5:  Self-Resolve        → answer own questions from code
Phase 6:  Validate (pass 2)   → re-verify
Phase 7:  Clarity Review 2    → re-simulate
Phase 8:  Ask Human           → present unresolvable questions (ENHANCED — Reverse Glossary)
```

---

## Clash Analysis

| Wave | Files Modified | Clashes With |
|------|---------------|-------------|
| 1 | SKILL.md | None |
| 2 | NEW: phase-D-domain-interview.md | None |
| 3 | phase-0-discover.md | None |
| 4 | phase-1-generate.md | None (only file in wave) |
| 5 | phase-2-refine.md | None |
| 6 | phase-3-validate.md, phase-4-clarity-review.md | None |
| 7 | phase-8-ask-human.md | None |

**No clashes.** Each wave touches non-overlapping files. Waves 1-3 should execute sequentially (Phase D depends on SKILL.md structure; Phase 0 changes inform Phase D). Waves 4-7 can execute in parallel after Wave 3 completes.

---

## Wave 1: SKILL.md Foundation

**File:** `stow/llm-docs/SKILL.md`

### Edit 1.1: Add Phase D to pipeline diagram (line ~166)

After `Phase 0: Discover` line, add:
```
Phase D: Domain Interview    → capture business/domain context from human (skip on re-run if fresh)
```

### Edit 1.2: Add Phase D to phase instruction table (line ~183)

Add row between Phase 0 and Phase 1:
```
| D | `phase-D-domain-interview.md` | `_original_docs.md` + human input | `docs/llm/domain-context.md` |
```

### Edit 1.3: Update state.md template (line ~46)

Add between Phase 0 and Phase 1 entries:
```
- [ ] D: Domain Interview
```

### Edit 1.4: Add domain-context.md to working files table (line ~84)

This is NOT a working file (it lives in the repo), but add a note to the table footer:
```
**Repo output file:** `docs/llm/domain-context.md` — written by Phase D, consumed by all subsequent phases. Lives in the target repo, not MEMORY. Treated as a trusted baseline by Phase 0 on re-runs.
```

### Edit 1.5: Update output structure (line ~339)

Add to the file tree:
```
├── domain-context.md        # Business domain, glossary, regulatory context (human-provided)
```

### Edit 1.6: Update CLAUDE.md template (line ~361)

Add to the "Before modifying code" checklist:
```
6. Understand the domain: `docs/llm/domain-context.md`
```

### Edit 1.7: Update "Adapting to the repo" section — default path (line ~399)

Add note: "Phase D (Domain Interview) runs only on first invocation or when the user requests it. On subsequent runs, the existing `domain-context.md` is treated as a trusted baseline."

### Edit 1.8: Update "Adapting to the repo" section — full pipeline (line ~408)

Add note: "Phase D captures business context that cannot be derived from source code. For large or domain-heavy repos, encourage the user to provide product documentation, wiki links, or company website URLs during the interview."

### Edit 1.9: Add Phase D to "Between Phases" execution notes (line ~215)

After the Phase 0→1 transition, add:
"**Between Phases 0 and 1:** The orchestrator checks whether Phase D should run. If `docs/llm/domain-context.md` exists AND Phase 0 scored it high-confidence, skip Phase D and proceed to Phase 1. If the user invoked with `--interview` or `--redo-interview`, always run Phase D regardless. Otherwise, run Phase D."

---

## Wave 2: New Phase D File

**File:** `stow/llm-docs/phase-D-domain-interview.md` (NEW)

Create this file with the following structure:

```markdown
# Phase D: Domain Interview — Capture Business and Domain Context

This phase captures knowledge that CANNOT be derived from source code: business domain, customer context, domain-specific terminology, regulatory constraints, historical decisions, and operational tribal knowledge.

**This phase is interactive — it requires human input.** It runs after Phase 0 so it can use the existing documentation assessment to ask informed questions.

---

## Skip Logic

Before starting, check whether this phase should run:

1. Read `~/.claude/MEMORY/llm-docs/<repo-slug>/_original_docs.md`
2. Check if `docs/llm/domain-context.md` was assessed by Phase 0
3. **Skip if:** the file exists AND Phase 0 scored it `high-confidence` AND the user did NOT pass `--interview` or `--redo-interview`
4. **Run if:** the file does not exist, OR Phase 0 scored it below `high-confidence`, OR the user explicitly requested an interview

If skipping, mark Phase D complete in `state.md` with note: "Skipped — existing domain-context.md scored high-confidence by Phase 0." Proceed to Phase 1.

---

## Checklist

- [ ] D.0: Check skip condition
- [ ] D.1: Present the interview prompt to the user
- [ ] D.2: Ingest user-provided material (text dump + URLs)
- [ ] D.3: Summarise ingested material into structured domain knowledge
- [ ] D.4: Identify remaining gaps — questions the material didn't answer
- [ ] D.5: Ask the user remaining questions directly
- [ ] D.6: Write `docs/llm/domain-context.md` to the target repo
- [ ] D.7: Update `state.md` — mark Phase D complete

---

## Inputs and Outputs

| Direction | File | Location | Description |
|---|---|---|---|
| **Input** | `_original_docs.md` | MEMORY | Phase 0's doc assessment (informs skip logic and questions) |
| **Input** | `state.md` | MEMORY | Phase progress |
| **Input** | Human input | Interactive | Text dumps, URLs, direct answers |
| **Output** | `domain-context.md` | Target repo: `docs/llm/` | Structured domain knowledge |

---

## Step 1: Present the Interview Prompt (D.1)

Present the following to the user. This is the FIRST human interaction in the pipeline — make it count.

```
I've completed an initial scan of your repository's existing documentation.

To generate the most accurate documentation possible, I need some context
about your business domain — things I can't figure out from source code alone.

You can help in any combination of these ways:

1. **Paste text** — dump any amount of product docs, wiki pages, onboarding
   guides, pitch decks, or other context. I'll extract what I need.

2. **Provide URLs** — link to your product website, docs site, wiki, or any
   public pages. I'll fetch and read them.

3. **Answer questions** — I'll ask targeted questions about anything the
   above didn't cover.

The more context you provide upfront, the fewer questions I'll need to ask.
You can combine all three — paste some text, give me some links, and I'll
ask about the rest.
```

**Update state:** Mark step D.1 complete.

---

## Step 2: Ingest User Material (D.2)

### Text Dump Processing

If the user provides pasted text:

1. Read the full text
2. Extract structured domain knowledge into these categories:
   - **Product/Business:** What the product does, who it serves, business model
   - **Domain Terms:** Any terminology with domain-specific meanings
   - **Regulatory/Compliance:** Any mentioned compliance requirements
   - **Architecture Rationale:** Any "why" explanations for technical decisions
   - **Operational Knowledge:** Any operational procedures, common issues, fixes
   - **User/Customer Context:** Who the users are, their needs, their technical level
3. Log what was extracted and what categories remain unfilled

### URL Processing

If the user provides URLs:

1. For each URL, dispatch a **subagent** (model: `sonnet`) to fetch and summarise. Each subagent:
   - Fetches the page using the WebFetch tool
   - Extracts the same domain knowledge categories listed above
   - Writes a structured summary (max 500 words) to `~/.claude/MEMORY/llm-docs/<repo-slug>/_url_summary_<N>.md`
   - If the fetch fails (network error, auth required, etc.), note the failure and move on

2. **Dispatch all URL subagents in parallel** using `run_in_background: true`

3. When all subagents complete, read their summary files and merge into the domain knowledge categories

4. Delete the `_url_summary_*.md` working files after merging

**Failure handling:** If a URL fetch fails, note it in the interview output and move on. Do not block the pipeline on unreachable URLs. Tell the user which URLs failed so they can paste the content manually if needed.

**Update state:** Mark step D.2 complete.

---

## Step 3: Summarise into Structured Knowledge (D.3)

Merge all ingested material (text dump + URL summaries) into the domain knowledge categories. For each category, note:
- What was learned (with source: "from pasted text" or "from URL: ...")
- Confidence level (clear statement vs. inferred from context)
- What's still missing

**Update state:** Mark step D.3 complete.

---

## Step 4: Identify Remaining Gaps (D.4)

Compare what was learned against this complete questionnaire. Any question NOT answered by the ingested material becomes a direct question for the user.

### Domain Knowledge Questionnaire

**Core (always ask if unanswered):**
1. What does this product do, in one sentence? Who is the primary customer?
2. What industry or vertical does this serve?
3. What are the 2-3 main user types? What is their technical level?
4. Are there compliance/regulatory requirements? (HIPAA, GDPR, PCI, SOX, etc.)
5. List any domain terms that have specific meaning in this product (e.g., "a 'Project' means X, not the generic sense")

**Architecture Rationale (ask if unanswered and relevant):**
6. Are there parts of the codebase that look odd but are intentional? Why?
7. What approaches have been tried and abandoned? Why didn't they work?
8. What is currently being deprecated or planned for replacement?

**Operational (ask if unanswered and relevant):**
9. What breaks most often? What's the typical fix?
10. Are there VPN, network, or access requirements for local development?

**Update state:** Mark step D.4 complete.

---

## Step 5: Ask Remaining Questions (D.5)

Present only the questions that the ingested material didn't answer. Group them by priority:

- **Essential (must answer):** Questions 1-4 — product, industry, users, compliance
- **Helpful (answer if you can):** Questions 5-8 — domain terms, architecture rationale
- **Optional (skip if you like):** Questions 9-10 — operational knowledge

For each question, show what the ingested material DID reveal (if anything) so the user can confirm or correct rather than starting from scratch:

```
Based on [your docs / the URL I read], it looks like this is a [X].
Is that correct? Anything to add or correct?
```

If the user says "skip" or "that's enough", accept what you have and proceed. Partial domain context is better than no domain context.

**Update state:** Mark step D.5 complete.

---

## Step 6: Write domain-context.md (D.6)

Write to `docs/llm/domain-context.md` in the target repo:

```markdown
# Domain Context

> This file captures business and domain knowledge that cannot be derived
> from source code. It was generated from a domain interview and should be
> reviewed and maintained by the team.
>
> Last interview: [ISO timestamp]
> To update: run `llm-docs --redo-interview` or edit this file directly.

## Product

- **What it does:** [1-2 sentences]
- **Industry/Vertical:** [e.g., FinTech, HealthTech, EdTech]
- **Business model:** [e.g., B2B SaaS, marketplace, API platform]
- **Primary customers:** [who pays]

## Users

| User Type | Description | Technical Level |
|-----------|-------------|-----------------|
| [type] | [who they are] | [high/medium/low] |

## Domain Glossary

| Term | Meaning in This Product | NOT the Same As |
|------|------------------------|-----------------|
| [term] | [definition] | [common misconception] |

## Regulatory & Compliance

- [List any compliance requirements, or "None identified"]
- [Note which parts of the codebase are affected]

## Architecture Rationale

### [Decision title]
- **What:** [what looks odd]
- **Why:** [the actual reason]
- **Don't:** [what an agent should NOT do based on this]

## Operational Knowledge

- [Common issues and fixes]
- [VPN/network requirements]
- [Anything else from tribal knowledge]

## Planned Changes

- [What's being deprecated]
- [What's being replaced and with what]

## Unanswered Questions

<!-- These will be revisited in Phase 8's Reverse Glossary step -->
- [Any questions the user skipped or couldn't answer]
```

**Rules:**
- Only include sections that have content. Do not write empty sections.
- Mark any uncertain claims with `<!-- TODO: verify with team -->`
- The "NOT the Same As" column in the glossary is critical — it prevents the most common misunderstanding for each term
- Do NOT hallucinate domain knowledge. If the user didn't provide it and the code doesn't show it, leave it out.

**Update state:** Mark step D.6 complete. Mark Phase D complete (D.7).
```

---

## Wave 3: Phase 0 Changes — Detect Domain Context

**File:** `stow/llm-docs/phase-0-discover.md`

### Edit 3.1: Add domain-context.md to discovery targets (Step 1, line ~57)

In the list of files to search for, add a new bullet:

```
- **Domain context:** `docs/llm/domain-context.md` — if this exists from a previous llm-docs run, assess its reliability alongside other docs. This file is consumed by Phase D to determine whether the domain interview can be skipped.
```

### Edit 3.2: Add domain context to the output format (Step 4, line ~152)

In the `_original_docs.md` template, add to the Summary section:

```
- Domain context file: exists | missing
- Domain context confidence: high | medium | low | n/a (if missing)
```

And add to the Baseline Recommendations section:

```
- **Domain interview:** [needed — no domain-context.md exists | skip — domain-context.md exists and is high-confidence | recommended — domain-context.md exists but is stale or low-confidence]
```

---

## Wave 4: Phase 1 Changes — Enhanced Exploration and Output Specs

**File:** `stow/llm-docs/phase-1-generate.md`

This is the largest wave. All edits are in one file, applied top-to-bottom to avoid offset drift.

### Edit 4.1: Add domain-context.md to Step 0 inputs (line ~67)

After the paragraph about reading `_original_docs.md`, add:

```
**Read domain context:** If `docs/llm/domain-context.md` exists (written by Phase D or from a previous run), read it now. This file provides business domain knowledge, glossary terms, regulatory constraints, and architecture rationale that cannot be derived from source code. Use it to:
- Understand domain-specific terminology when reading code
- Know which areas have regulatory constraints (affects how you document them)
- Avoid contradicting intentional architecture decisions
- Use correct domain terms in your documentation (not generic guesses)
```

### Edit 4.2: Expand Step 1c — Add IaC and version management files (line ~132)

Add to the list of config files to read:

```
- Version management: `.nvmrc`, `.node-version`, `.python-version`, `.ruby-version`, `.tool-versions`, `.java-version`, `rust-toolchain.toml`
- Infrastructure-as-Code: `*.tf` (Terraform), `helm/` or `charts/` directories, `k8s/` or `kubernetes/` directories, `cloudformation/`, `cdk.json`, `pulumi.*`, `ansible/`, `docker-compose*.yml`
- Package manager indicators: `pnpm-lock.yaml` (pnpm), `yarn.lock` (yarn), `package-lock.json` (npm), `bun.lockb` (bun), `Pipfile.lock` (pipenv), `poetry.lock` (poetry), `uv.lock` (uv), `Gemfile.lock` (bundler), `go.sum` (Go modules)
```

### Edit 4.3: Add new conditional exploration steps after Step 1h (line ~200)

Add a new section after Step 1h and before Step 1i:

```markdown
**1j. Conditional exploration — document if found, skip if absent**

The following areas are explored ONLY if the codebase shows evidence of them. Check for their presence; if found, document them. If not found, skip and move on.

**Authentication model** — Search for auth middleware, guards, JWT handling, session management, OAuth config. If found, note: auth mechanism, where middleware lives, token/session storage, how to add a new authenticated endpoint.

**Database migrations** — Search for migration directories, migration tools (Alembic, Knex, Prisma Migrate, TypeORM migrations, Django migrations, Flyway, Liquibase, goose, dbmate). If found, note: migration tool, migration directory, how to create a new migration, how to run migrations locally.

**Feature flags** — Search for LaunchDarkly, Unleash, Flagsmith, custom feature flag implementations, environment-based feature gating. If found, note: flag system, where flags are defined, how to add a new flag, how to check flag state in code.

**Observability** — Search for logging frameworks (Winston, Pino, structlog, Zap, Log4j), metrics (Prometheus, StatsD, Datadog), tracing (OpenTelemetry, Jaeger, Zipkin). If found, note: logging framework, structured logging patterns, how to add logging to new code, where metrics are defined.

**Code generation** — Search for codegen config (protobuf, GraphQL codegen, OpenAPI generators, Prisma, sqlc). If found, note: what's generated, what tool generates it, which files must NOT be hand-edited, how to re-run codegen.

**Secrets management** — Search for secret store references (AWS Secrets Manager, HashiCorp Vault, Google Secret Manager, Azure Key Vault, Doppler, .env patterns). If found, note: secret store, how secrets are accessed in code, how to add a new secret for local dev vs production.

**API contracts** — Search for OpenAPI/Swagger specs, GraphQL schemas, protobuf definitions, AsyncAPI specs. If found, note: where contracts are defined, versioning strategy, how breaking changes are handled.

**Error handling patterns** — Search for custom error classes, error middleware, error boundaries. Note: error taxonomy, how errors propagate, error handling conventions.

For each area found, log your findings to your exploration notes. These will feed into the appropriate output docs.

**Update state:** Mark step 1j complete in `state.md`.
```

### Edit 4.4: Add Step 1j to the checklist (line ~9)

Add between `1i` and `GATE`:
```
- [ ] 1j: Conditional exploration (auth, migrations, feature flags, observability, codegen, secrets, API contracts, error handling)
```

### Edit 4.5: Add Step 1j to the exploration completion gate (line ~222)

Add an 8th question:
```
- What conditional areas are present? (cite evidence for each: auth middleware path, migration directory, etc.)
```

### Edit 4.6: Expand workflows.md spec — Add Deploy and Prerequisites (line ~422)

Replace the existing workflows.md format block with:

```markdown
#### `docs/llm/workflows.md`
Every command must come from `package.json` scripts, `Makefile`, CI config, or existing README.

Format:
\`\`\`bash
# Prerequisites
## Required tools
<exact tool name and version — cite .nvmrc, .python-version, etc.>
<package manager — cite lockfile that identifies it>
<any system tools — Make, protobuf compiler, etc.>

## Required services (for local development)
<databases, message queues, caches — how to install and start each>
<Docker services — if docker-compose exists, document `docker-compose up` and what it starts>

## Environment setup
<virtual environment setup if applicable — e.g., `python -m venv .venv && source .venv/bin/activate`>
<environment variables — list each with purpose and example local value>
<cite .env.example or equivalent>

## Network requirements
<VPN requirements if known from domain-context.md>
<internal registry access if applicable>

# Install
<exact command — cite source>

# Dev
<exact command — cite source>
<hot reload behavior if known>

# Build
<exact command — cite source>

# Test
<exact command — cite source>
<test categories if applicable: unit, integration, e2e — and how to run each separately>

# Lint
<exact command — cite source>

# Type check
<exact command — cite source>

# Deploy (if commands exist in the repo)
<exact command — cite source>
<deployment target environments if known>
<any required permissions or approval steps>

# Database (if migrations exist)
<migration command — cite source>
<seed command if available — cite source>
\`\`\`

Only include sections for commands and tools that actually exist. Mark sections sourced from `domain-context.md` (like VPN requirements) with their source.

**For monorepos:** If different packages/services have different setup procedures, create per-project subsections:

\`\`\`
## Project: <name> (`path/to/project/`)
# Prerequisites
...
# Install
...
# Dev
...
\`\`\`

Each project section follows the same template. Common prerequisites shared across projects go in a top-level "Shared Prerequisites" section.
```

### Edit 4.7: Expand conventions.md spec — Add testing and error patterns (line ~401)

Add to the categories list:

```
- Testing patterns (test file placement relative to source: co-located or separate directory, naming convention, test helpers/fixtures available, mocking patterns, test categories: unit/integration/e2e)
- Error handling (custom error classes, error propagation pattern, error middleware)
```

### Edit 4.8: Expand architecture.md spec — Add infrastructure, CI/CD, auth (line ~381)

Add to the required content list:

```
- CI/CD pipeline: for each CI workflow file, document what it does, what triggers it, what stages/jobs it contains, and how to reproduce its checks locally. Link to the workflow file.
- Authentication model (if present): auth mechanism, middleware location, token/session management, how to add a new authenticated endpoint. Only if auth infrastructure exists in the codebase.
- Infrastructure (if IaC exists in repo): cloud provider, IaC tool, what resources are defined, environment differences (dev/staging/prod), link to IaC directory. Do not document infrastructure that isn't defined in this repo.
```

### Edit 4.9: Expand module doc spec — Add local running and testing (line ~556)

Add to the module doc table:

```
| **How to run locally** | If this module can run independently: exact command, required env vars, required services, port it listens on. If it requires other modules: list them and how to start them. If it cannot run independently: say so and explain why. |
| **Testing** | Test framework, test file location relative to source files (co-located or separate directory), how to run tests for this module only, test helpers/fixtures available in this area, mocking patterns used |
| **Local dependencies** | Any module-specific setup beyond the repo-wide prerequisites (additional env vars, additional services, additional tools) |
```

### Edit 4.10: Add domain-context.md to expected file manifest (line ~83)

Add to the list of expected top-level docs:

```
Also check for `domain-context.md` (produced by Phase D — if it exists, include it in the manifest as `preserved`).
```

### Edit 4.11: Add new output file spec — docs/llm/local-dev.md (after scripts.md spec, line ~510)

Add a new file specification:

```markdown
#### `docs/llm/local-dev.md` (only for repos with complex local setup)

Create this file if the repo has 3+ of: database setup, Docker services, VPN requirements, multiple runtimes, virtual environments, or per-project setup in a monorepo. For simpler repos, the Prerequisites section of `workflows.md` is sufficient.

**Purpose:** A complete guide to getting the development environment running from zero. This is the file an agent reads when it needs to set up or troubleshoot the local dev environment.

Required content:
- **System requirements:** OS-specific notes if any, required runtimes with versions (cite version files), required system tools
- **Package manager:** Which one and why (cite lockfile), common commands
- **Environment setup:** Virtual environments, shell configuration, PATH requirements
- **Database setup:** Engine, installation, local connection config, seeding, migration commands
- **Docker services:** What `docker-compose up` starts, port mapping, volume mounts, which services are required vs optional
- **Environment variables:** Complete table with: variable name, purpose, example local value, where it's used. Cite `.env.example` or equivalent.
- **Network/VPN:** Requirements sourced from `domain-context.md` — mark these clearly as human-provided, not code-verified
- **Per-project setup (monorepos):** If different projects need different setup, document each
- **Troubleshooting:** Common setup issues and fixes (sourced from gotchas, domain-context, or code comments)

**Rules:**
- Every command must come from an actual config file or script
- Environment variable values must come from `.env.example` or equivalent — do not invent values
- VPN/network requirements must come from `domain-context.md` — do not guess
- If something cannot be determined from code or domain context, mark it `<!-- TODO: verify with team -->`
```

---

## Wave 5: Phase 2 Changes — Enhanced Quality Bar

**File:** `stow/llm-docs/phase-2-refine.md`

### Edit 5.1: Expand module doc quality bar (line ~178)

Add questions 10-12:

```
> 10. How to run this module locally (or why it can't run independently)
> 11. Where tests are, what framework they use, and how to run them for this module
> 12. What local dependencies are needed beyond the repo-wide prerequisites
```

### Edit 5.2: Expand coverage assessment Step 1c (line ~96)

Add new coverage check areas:

```
**Local development setup:** Does `workflows.md` (and `local-dev.md` if it exists) cover everything needed to get the project running locally? Check: runtime versions documented (cite version files), package manager identified (cite lockfile), environment variables listed with example values, database setup if applicable, Docker setup if applicable. For monorepos: does each project have its own setup section?

**Testing coverage:** Does `conventions.md` document test file placement relative to source files? Can an agent determine where to put a new test? Are test helpers, fixtures, and mocking patterns documented?

**CI/CD pipeline:** Does `architecture.md` document the CI pipeline stages? Can an agent reproduce CI checks locally?

**Infrastructure:** If IaC exists in the repo, is it documented in `architecture.md`?

**Conditional areas:** For each conditional area found by Phase 1 (auth, migrations, feature flags, observability, codegen, secrets, API contracts, error handling), is there adequate documentation? Check module docs and architecture.md.
```

---

## Wave 6: Phase 3 + Phase 4 Changes — Enhanced Validation and Scenarios

**File:** `stow/llm-docs/phase-3-validate.md`

### Edit 6.1: Add validation checks for new areas (after Check 10b, line ~257)

Add:

```markdown
### Check 11: Local development setup verification

If `workflows.md` includes a Prerequisites section or `local-dev.md` exists:
- Verify runtime version claims match version files (`.nvmrc`, `.python-version`, etc.)
- Verify package manager identification matches the lockfile that exists
- Verify environment variables listed match what `.env.example` contains
- Verify database setup commands match actual migration tool configuration
- Verify Docker service descriptions match `docker-compose.yml` contents
- For monorepos: verify per-project setup sections match actual project configs

**Updating state:** After completing Check 11, mark the corresponding step complete in `state.md`.

### Check 12: Domain context verification

If `docs/llm/domain-context.md` exists:
- Do NOT fact-check business claims (product description, industry, users) — these are human-provided and authoritative
- DO verify any file paths, commands, or technical claims within the domain context against the codebase
- DO check that glossary terms appear in the actual codebase (if a term is defined but never appears in code, flag it)
- DO verify that "Architecture Rationale" entries reference real code/files

**Updating state:** After completing Check 12, mark the corresponding step complete in `state.md`.
```

### Edit 6.2: Add Check 11 and 12 to checklist (line ~13)

Add:
```
- [ ] 3s: Check 11 — Local development setup verification
- [ ] 3t: Check 12 — Domain context verification
```

**File:** `stow/llm-docs/phase-4-clarity-review.md`

### Edit 6.3: Enhance Scenario D (Onboarding) (line ~130)

Replace the existing Scenario D with:

```markdown
### Scenario D: Onboarding — from zero to running locally
You've just cloned this repo. You need to:
1. Install all prerequisites (runtimes, tools, package manager)
2. Set up your local environment (env vars, database, Docker services)
3. Get the project running locally
4. Run the tests
5. Understand the architecture well enough to find where to make your first change

Trace this entire path through the documentation. At each step: does the doc tell you the EXACT command? Does it tell you what version of what tool? Does it tell you what env vars to set and what values to use? Where do you get stuck?
```

### Edit 6.4: Enhance Scenario E (Adding a test) (line ~133)

Replace the existing Scenario E with:

```markdown
### Scenario E: Adding a test for an existing feature
Pick a module. You need to write a new test for an existing function.
1. Where do test files live relative to the source file? (same directory? `__tests__/`? `tests/`?)
2. What naming convention do test files follow?
3. What test framework is used? What assertion library?
4. Are there test helpers, fixtures, or factories you should use?
5. What mocking patterns does the project use?
6. How do you run just your new test vs the full suite?
7. Are there different test categories (unit/integration/e2e) with different patterns?

Can you answer all 7 from the docs alone?
```

---

## Wave 7: Phase 8 Changes — Reverse Glossary

**File:** `stow/llm-docs/phase-8-ask-human.md`

### Edit 7.1: Add Reverse Glossary step (after Step 8.0, before presenting questions, line ~48)

Add a new step:

```markdown
## Reverse Glossary (Step 8.0b)

Before presenting open issues, perform a Reverse Glossary extraction. This surfaces domain terms the pipeline couldn't confidently define.

### Process

1. **Extract candidate terms:** Scan all generated documentation, source code string constants, enum values, database column names, UI labels, and API endpoint names for terms that:
   - Appear frequently (5+ occurrences) but have no definition in `domain-context.md`
   - Are used in variable/function names but aren't standard programming terms
   - Appear in comments or error messages with domain-specific meaning

2. **Filter out known terms:** Remove any term already defined in `docs/llm/domain-context.md` (if it exists) or `docs/llm/glossary.md` (if it exists).

3. **Present to the user:** Show the remaining terms grouped by frequency/importance:

   ```
   I found these domain-specific terms in the codebase that I'm not confident
   I understand correctly. Can you define any of them?

   HIGH FREQUENCY (appear 20+ times):
   - `settlement_window` — I see this in [files]. Is this [my best guess]?
   - `provider_tier` — Used in [context]. What does this mean?

   MEDIUM FREQUENCY (appear 5-19 times):
   - [terms...]

   You can skip any you don't want to define right now.
   ```

4. **For each term the user defines:** Add it to `docs/llm/domain-context.md` in the Domain Glossary table. If `glossary.md` exists, add it there too.

5. **For skipped terms:** Leave them out. Do not guess.

### Rules
- Present your BEST GUESS for each term (from code context) so the user can confirm or correct rather than defining from scratch — confirmation is cheaper than generation
- Do NOT present terms that are standard technical vocabulary (e.g., "middleware", "schema", "endpoint")
- Maximum 15 terms. If more candidates exist, prioritise by frequency and cross-module usage.
- If `domain-context.md` doesn't exist (Phase D was skipped on a previous run), create it now with just the Glossary section.

Update `state.md`: mark step 8.0b complete.
```

### Edit 7.2: Add step 8.0b to checklist (line ~12)

Add after step 8.0:
```
- [ ] 8.0b: Reverse Glossary — extract and present undefined domain terms
```

### Edit 7.3: Update Phase 8 cleanup to preserve domain-context.md (line ~125)

Add note to the cleanup step:
```
**Do NOT delete `docs/llm/domain-context.md`** — this lives in the target repo, not MEMORY. It is a permanent output file.
```

---

## Execution Order

```
Wave 1: SKILL.md foundation          ← do first (establishes Phase D in the pipeline)
Wave 2: phase-D-domain-interview.md  ← do second (the new phase file)
Wave 3: phase-0-discover.md          ← do third (enables Phase D skip detection)
                                       ↓
              ┌────────────────────────┼─────────────────────────┐
              ↓                        ↓                         ↓
Wave 4: phase-1-generate.md    Wave 5: phase-2-refine.md    Wave 6: phase-3 + phase-4
(largest — 11 edits)           (2 edits)                    (4 edits)
              ↓                        ↓                         ↓
              └────────────────────────┼─────────────────────────┘
                                       ↓
                              Wave 7: phase-8-ask-human.md
                              (3 edits — Reverse Glossary)
```

Waves 4, 5, and 6 can execute in parallel after Wave 3 completes.
Wave 7 executes last (depends on the domain-context.md format established in Wave 2).

---

## Summary

| Wave | File(s) | Edits | What Changes |
|------|---------|-------|-------------|
| 1 | SKILL.md | 9 | Pipeline diagram, phase table, state template, output structure |
| 2 | phase-D-domain-interview.md (NEW) | 1 | Entire new phase: interview, text dump, URL fetch, domain-context.md |
| 3 | phase-0-discover.md | 2 | Detect domain-context.md, add to assessment output |
| 4 | phase-1-generate.md | 11 | IaC files, version files, conditional exploration, expanded workflows/conventions/architecture/module specs, new local-dev.md |
| 5 | phase-2-refine.md | 2 | Expanded quality bar (3 new questions), expanded coverage assessment |
| 6 | phase-3-validate.md + phase-4-clarity-review.md | 4 | New validation checks (local dev, domain context), enhanced scenarios |
| 7 | phase-8-ask-human.md | 3 | Reverse Glossary extraction + presentation |
| **Total** | **8 files (1 new, 7 modified)** | **32 edits** | |

---

## Addendum: Red Team Fixes + Brainstorm Additions

Applied during execution based on post-plan review.

### Red Team Fixes Incorporated

1. **Phase D URL warning** — Added guidance to warn about internal/authenticated URLs before fetching, suggest paste fallback on first failure from same domain
2. **Phase D interaction cap** — Hard cap of 5 direct questions, 10 minute target
3. **Step 1j subagent guidance** — For large repos, split conditional exploration across subagents
4. **Step 1j evidence thresholds** — Defined minimum evidence for each conditional area
5. **local-dev.md cross-references** — Added to SKILL.md output structure, CLAUDE.md template, Phase 4 reading list, Phase 3 scope
6. **Reverse Glossary reframed** — Shows code context + hypothesis, not "best guess"
7. **Graceful degradation** — Added notes for simple repos to skip inapplicable sections
8. **local-dev.md trigger** — Made concrete with enumerable indicators
9. **Skip logic staleness** — Added timestamp-based freshness check for domain-context.md
10. **domain-context.md git noise** — Only write when content changes, not just timestamp
11. **Monorepo workflows** — 5+ projects get per-project workflow files instead of one massive file
12. **Step 1j completion gate** — Expanded to require evidence for each found area
13. **Language diversity** — Added more language-specific patterns and version files

### Brainstorm Must-Haves Added

1. **Task Router Index** (`docs/llm/task-router.md`) — Maps common agent tasks to exact doc reading order
2. **Workflow Recipes** (`docs/llm/recipes/`) — Step-by-step guides with real code patterns for common multi-file changes
3. **Change Impact Checklists** — Per-module "if you modified this, check:" lists in dependency-map.md
4. **Decision Trees** — Structured routing for "where should I put this code?" and "which test pattern?" in conventions.md
5. **Module Seams** — Extension points documented in each module doc: where new code plugs in
