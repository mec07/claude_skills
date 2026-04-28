# Phase 0: Discover and Triage Repository

Before generating any skills or documentation, you must understand the repository's shape, size, existing AI platform usage, architectural boundaries, and what task-specific skills are warranted. This phase produces a single triage file that all subsequent phases use as their starting point.

**This phase is read-only. Do not modify any existing files in the target repo.** Your only output is `~/.claude/MEMORY/RepoSkills/<repo-slug>/_triage.md`.

---

## Checklist

Copy this checklist into `state.md` under the Phase 0 entry. Mark each item `[x]` immediately upon completion.

```
- [ ] 0.0: Pre-check — verify _triage.md does not already exist
- [ ] 0.1: Classify repository by size
- [ ] 0.2: Detect AI platforms in use
- [ ] 0.3: Find and assess existing documentation
- [ ] 0.4: Identify module boundary candidates
- [ ] 0.5: Detect task skills warranted by the codebase
- [ ] 0.6: Check domain-context.md freshness
- [ ] 0.7: Write _triage.md to MEMORY directory
- [ ] 0.8: Update state.md — mark Phase 0 complete with timestamp
```

---

## Inputs and Outputs

| Direction | File | Location | Description |
|---|---|---|---|
| **Input** | `state.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Repo path, slug, phase progress |
| **Input** | Codebase | Target repo on disk | All source files — read-only |
| **Output** | `_triage.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Complete triage assessment |

This phase reads from the target repo and writes exclusively to the MEMORY directory. No files in the target repo are created or modified.

---

## Updating state

After completing **each numbered step** below, immediately update `state.md`:

1. Mark the step's checkbox `[x]` in the Phase 0 checklist
2. Update the `updated:` timestamp

Do not batch state updates. If context is lost between steps, the recovery protocol relies on `state.md` being current. A completed step with no state update will be repeated on resume.

---

## Pre-check (Step 0.0)

If `~/.claude/MEMORY/RepoSkills/<repo-slug>/_triage.md` already exists, this phase has already been completed in a previous run. **Mark Phase 0 complete in state.md** — check all Phase 0 sub-steps as done and add a completion timestamp. Then report to the orchestrator that Phase 0 can be skipped. Do not overwrite the existing triage.

Update `state.md`: mark step 0.0 complete.

---

## Step 1: Classify Repository by Size (Step 0.1)

Count the number of source files in the repository, excluding dependency/build output directories (`node_modules`, `.git`, `dist`, `build`, `.next`, `__pycache__`, `.turbo`, `.cache`, `vendor`, `target`, `.gradle`, `bin`, `obj`, `.venv`, `venv`, `.tox`).

Assign one of these classifications:

| Classification | File Count | Characteristics |
|---|---|---|
| **Small** | <50 files | Single-purpose, likely one module, one language |
| **Standard** | 50-500 files | Typical project, may have a few internal packages |
| **Large** | 500+ files | Significant codebase, multiple subsystems |
| **Monorepo** | Multi-project | Multiple `package.json` / `go.mod` / `Cargo.toml` at different directory levels, or a `workspaces` field, or a `pnpm-workspace.yaml`, or a `lerna.json` |

**Monorepo detection takes priority.** A repo with 30 files but 3 separate `package.json` / `go.mod` / `Cargo.toml` roots is a Monorepo, not Small.

To detect monorepo structure, check for:
- Multiple `package.json` files at different directory depths (not in `node_modules`)
- `workspaces` field in root `package.json`
- `pnpm-workspace.yaml` or `lerna.json` at the root
- Multiple `go.mod` files at different directory depths
- Multiple `Cargo.toml` with `[workspace]` in root
- Multiple `build.gradle` / `pom.xml` at different directory depths
- `nx.json`, `rush.json`, or `turbo.json` at the root

Record the classification, file count, and primary language(s) detected.

Update `state.md`: mark step 0.1 complete.

---

## Step 2: Detect AI Platforms in Use (Step 0.2)

Check for the presence of these AI platform configuration directories and files at the repository root:

| Platform | Indicators |
|---|---|
| **Claude** | `.claude/` directory, `CLAUDE.md`, `.claude/settings.json`, `.claude/commands/` |
| **Cursor** | `.cursor/` directory, `.cursorrules`, `.cursor/rules/*.md` |
| **GitHub Copilot** | `.github/copilot-instructions.md`, `.github/copilot-*.md` |
| **Windsurf** | `.windsurf/` directory, `.windsurfrules` |
| **Cline** | `.clinerules/`, `.clinerules` file |
| **AI Assistant (JetBrains)** | `.aiassistant/` directory |
| **Amazon Q** | `.amazonq/` directory |

For each platform detected, record:
- Whether it has custom instructions/rules configured
- A brief note on what the instructions cover (e.g., "coding style rules", "architecture context", "test instructions")

This informs which platform-specific skill files may need to be generated in later phases.

Update `state.md`: mark step 0.2 complete.

---

## Step 3: Find and Assess Existing Documentation (Step 0.3)

Search the repository for every file that serves as documentation. This is the same discovery process as the llm-docs skill, carried forward here because the triage needs documentation reliability data.

### Find documentation files

Cast a wide net — documentation lives in many places:

- **Root-level docs:** `README.md`, `CONTRIBUTING.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `SECURITY.md`, or similar
- **LLM agent instructions:** `CLAUDE.md`, `.github/copilot-instructions.md`, `.cursorrules`, `.cursor/rules/*.md`, or similar
- **Documentation directories:** `docs/`, `wiki/`, `documentation/`, `guides/`, or similar
- **Module-level READMEs:** `README.md` files in subdirectories (list them, but batch-assess — see below)
- **Architecture Decision Records:** `adr/`, `decisions/`, or similar
- **API documentation:** OpenAPI/Swagger specs, GraphQL schema docs, `api-docs/`, or similar
- **Environment documentation:** `.env.example`, `.env.template`, `.env.local.example`
- **Inline config documentation:** Significant comment blocks in CI/CD configs, Docker configs, or build configs

Exclude generated documentation output (TypeDoc output, Javadoc output, auto-generated API reference). Check `.gitignore` and look for generation scripts if unsure.

Exclude files in `node_modules`, `.git`, `dist`, `build`, `.next`, `__pycache__`, `.turbo`, `.cache`, `vendor`, `target`, `.venv`, `.tox`, and other dependency/build output directories.

### Assess reliability

For each documentation file found, read it and spot-check up to 10 verifiable claims against the actual codebase:

1. **File paths mentioned** — do they exist?
2. **Commands mentioned** — are they in `package.json` scripts, `Makefile`, `Taskfile.yml`, CI config, or equivalent for the repo's language?
3. **Tech stack claims** — do they match actual dependencies?
4. **Architecture claims** — do they match actual directory structure and imports?
5. **Environment variable names** — do they match actual usage?
6. **API endpoints or routes** — do they match actual route definitions?

Assign confidence:
- **high:** >80% of claims verified, actively maintained, aligns with codebase
- **medium:** 50-80% verified, partially stale, core facts correct but details drifted
- **low:** <50% verified, unmaintained, significant disconnect from codebase
- **unscored:** Few verifiable claims (conceptual overview, changelog, ADR)

**Toxic docs warning:** Any document scored `low-confidence` should be flagged with an additional `TOXIC` marker in `_triage.md`. Toxic docs are not just unreliable -- they may be actively misleading. Phase 2 agents must treat toxic docs with the same suspicion as having NO docs: verify every claim independently from source code. Do not let toxic docs anchor your understanding of the codebase architecture.

### Module-level READMEs at scale

If the repo has more than 10 module-level READMEs, batch-assess: read them all, group by quality pattern, deeply assess 2-3 representatives per group. Watch for contradictions within groups — do not assign a single confidence score to a group with internal contradictions.

### Parallelisation for large repos

If the repo contains **50 or more documentation files**, dispatch parallel subagents (model: `sonnet`) to read and categorise files concurrently. Split by directory tree. Each subagent writes to `~/.claude/MEMORY/RepoSkills/<repo-slug>/_discover_<dirname>.md`. Merge when complete, delete working files. If a subagent fails, re-dispatch once, then fall back to sequential.

Update `state.md`: mark step 0.3 complete.

---

## Step 4: Identify Module Boundary Candidates (Step 0.4)

Scan the repository for **architectural boundaries** — parts of the codebase that are self-contained enough to warrant their own dedicated skills or documentation modules. These are the building blocks for module-specific skills in later phases.

### Boundary signal detection

For each candidate directory, check which boundary signals it exhibits:

| Signal Type | Indicators | Weight |
|---|---|---|
| **Package boundary** | Own `package.json`, `go.mod`, `Cargo.toml`, `pyproject.toml`, `setup.py`, `build.gradle`, `pom.xml`, `*.csproj` | Strong |
| **Service boundary** | Own `Dockerfile`, own entry point (`main.go`, `index.ts`, `app.py`, etc.), own port binding, own health check endpoint | Strong |
| **Domain boundary** | Own data types/models that are imported by other modules, own database tables/collections, own API contract | Medium |
| **Deployment boundary** | Own CI workflow (`.github/workflows/<name>.yml`), own Terraform module, own Kubernetes manifest, own Helm chart | Medium |
| **Logical boundary** | Distinct responsibility with its own data types, clear API surface to the rest of the codebase, cohesive internal structure even without its own package config | Medium |

A candidate must exhibit **at least one Strong signal OR two Medium signals** to qualify as a module boundary.

### Exclusions — cross-cutting concerns

The following are explicitly NOT module boundaries, even if they are directories with many files:

- `utils/`, `shared/`, `common/`, `helpers/` — cross-cutting utilities
- `config/`, `configuration/` — shared configuration
- `scripts/`, `tools/`, `bin/` — operational scripts
- `types/`, `interfaces/`, `models/` (when used as shared type definitions) — cross-cutting types
- `lib/` (when it contains shared library code, not a self-contained library)
- `test/`, `tests/`, `__tests__/`, `spec/` — test infrastructure (unless a separate test harness project)

**Exception:** If a directory on the exclusion list exhibits a Strong boundary signal (e.g., `lib/` has its own `package.json` and is published as a package, or its own `go.mod`), it DOES qualify as a module boundary. The exclusion is for directories that are merely organizational groupings.

### Recording boundary candidates

For each candidate, record:
- **Path:** directory path relative to repo root
- **Signals detected:** which boundary types and their specific indicators
- **Confidence:** `high` (multiple strong signals), `medium` (one strong or two medium), `low` (borderline, needs human confirmation)
- **Suggested module name:** a concise name for the module (e.g., `auth-service`, `payment-api`, `shared-ui-components`)
- **Key entry points:** main files that serve as entry points to the module

### Monorepo special handling

For Monorepo-classified repos, every workspace/project root is automatically a module boundary candidate with high confidence. Focus additional detection effort on sub-boundaries within the largest workspaces.

Update `state.md`: mark step 0.4 complete.

---

## Step 5: Detect Task Skills Warranted (Step 0.5)

Scan the repository for patterns that indicate specific operational task skills should be generated. Each detection is independent — a repo may warrant any combination.

### Task skill detection matrix

| Task Skill | Detection Signals | Naming |
|---|---|---|
| **Running Tests** | Test files (`*.test.*`, `*.spec.*`, `*_test.*`, `test_*.*`), test config (`jest.config.*`, `vitest.config.*`, `pytest.ini`, `.mocharc.*`, `phpunit.xml`, `*_test.go`), test directories (`__tests__/`, `tests/`, `spec/`, `test/`) | Fixed: "Running Tests" |
| **Deployment & CI** | CI workflows (`.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/`, `bitbucket-pipelines.yml`), deployment config (`deploy/`, `k8s/`, `.helm/`, `Procfile`, `app.yaml`, `fly.toml`, `render.yaml`, `vercel.json`, `netlify.toml`) | Fixed: "Deployment & CI" |
| **Database Operations** | Migration directories (`migrations/`, `db/migrate/`, `alembic/`), ORM config (`prisma/`, `typeorm`, `sequelize`, `drizzle.config.*`, `knexfile.*`, `ormconfig.*`, `database.yml`), schema files (`schema.prisma`, `*.sql` in structured dirs) | Fixed: "Database Operations" |
| **Authentication** | Auth middleware (`auth/`, `middleware/auth.*`, `guards/`), auth config (`passport`, `next-auth`, `auth0`, `firebase-auth`, `jwt` in dependencies), session/token management files | Fixed: "Authentication" |
| **Request/Message Handling** | Route handlers (`routes/`, `controllers/`, `handlers/`, `api/`), queue consumers (`consumers/`, `workers/`, `subscribers/`), event handlers, gRPC service definitions (`*.proto`), GraphQL resolvers | Dynamic: name based on what's found (e.g., "HTTP Request Handling", "Queue Consumer Operations", "gRPC Service Operations") |
| **Script Operations** | Script directories (`scripts/`, `bin/`, `tools/`), `Makefile` with significant targets, `package.json` with 5+ custom scripts, `Rakefile`, `Taskfile.yml` | Fixed: "Script Operations" |
| **Infrastructure** | IaC files (`*.tf`, `*.tfvars`, `pulumi/`, `cdk/`, `cloudformation/`, `serverless.yml`, `sam-template.yml`), Docker Compose for infrastructure (`docker-compose.yml` with non-app services) | Fixed: "Infrastructure" |
| **Observability** | Logging framework imported in 3+ files (e.g., `winston`, `pino`, `bunyan`, `logrus`, `zap`, `slog`, `log4j`, `serilog`), metrics/tracing setup (`datadog`, `newrelic`, `opentelemetry`, `prometheus`), structured logging patterns | Fixed: "Observability" |
| **Code Generation** | Codegen config (`graphql-codegen.yml`, `openapi-generator`, `protoc`, `buf.gen.yaml`, `swagger-codegen`, `sqlc.yaml`, `mockgen`, `go generate` directives), generated file markers (`// Code generated`, `# Generated by`) | Fixed: "Code Generation" |
| **Secrets Management** | Secret store client in dependencies (`aws-secretsmanager`, `vault`, `doppler`, `1password-connect`, `google-cloud/secret-manager`), secret fetching patterns in startup code, `.env` loading with external references | Fixed: "Secrets Management" |
| **Feature Flags** | Feature flag SDK in dependencies (`launchdarkly`, `flagsmith`, `unleash`, `split`, `statsig`, `growthbook`, `flipt`), feature flag evaluation patterns in code | Fixed: "Feature Flags" |
| **Error Handling** | Custom error classes (`errors/`, `exceptions/`), error boundary components, global error handlers, error middleware, structured error codes | Fixed: "Error Handling" |

### Detection rules

1. **Threshold:** A task skill is warranted only if there is **clear evidence** — at minimum, a relevant config file OR relevant files in 3+ locations. A single test file does not warrant a "Running Tests" skill; a test directory with a config does.
2. **Dynamic naming:** For Request/Message Handling, examine what kind of handlers exist and name the skill accordingly. If the repo has both HTTP routes and queue consumers, generate two separate skills (e.g., "HTTP Request Handling" and "Queue Consumer Operations").
3. **Overlap resolution:** If a detection overlaps with a module boundary candidate (e.g., an `auth-service` module that also triggers the Authentication task skill), note the overlap. The module boundary takes precedence for module-level skills; the task skill covers the cross-cutting operational pattern.

### Recording task skill decisions

For each detected task skill, record:
- **Skill name:** the name that will be used for the generated skill
- **Detection evidence:** specific files/directories/dependencies that triggered detection
- **Scope:** `repo-wide` (applies everywhere) or `module-specific` (applies to specific modules)
- **Priority:** `high` (daily developer workflow), `medium` (regular but not daily), `low` (occasional use)

For each skill that was checked but NOT warranted, record:
- **Skill name:** the name
- **Reason skipped:** why detection did not trigger (e.g., "No test files or test config found")

#### Migration State Tool Eligibility

When Database Operations is warranted AND migration directories are detected:

1. Record the migration directory path(s) found. Multiple directories may represent:
   - Different databases (e.g., `db/users/migrations/` and `db/analytics/migrations/`)
   - Different schemas within one database (e.g., `migrations/public/` and `migrations/reporting/`)
   - A combination of both
   Record which case applies based on connection config and directory naming.
2. Classify the migration tool from file patterns:
   - `V{N}__*.sql` -> Flyway
   - `*.up.sql` / `*.down.sql` -> golang-migrate
   - Files containing `-- +goose Up` -> goose
   - Files containing `-- migrate:up` -> dbmate
   - Files containing `-- +migrate Up` -> sql-migrate
   - `{timestamp}/migration.sql` pattern -> Prisma or Drizzle
   - `.sql` files alongside `atlas.hcl` -> Atlas
   - Other `.sql` in migration dir -> generic
3. Classify as SQL-file (parseable by migration-state) or code-based (not parseable)
4. Check if the database is PostgreSQL (look for `pg` or `postgres` in dependencies)
5. Record in _triage.md:
   - `migration_dir`: path(s)
   - `migration_tool`: detected tool name
   - `migration_parseable`: yes/no
   - `migration_db`: PostgreSQL/MySQL/SQLite/other
   - `migration_state_eligible`: yes (if SQL-file AND PostgreSQL) / no

Update `state.md`: mark step 0.5 complete.

---

## Step 6: Check domain-context.md Freshness (Step 0.6)

Check whether `.ai/skills/domain-context.md` exists in the target repo.

If it exists:
1. Read the file
2. Extract the `Last interview` timestamp
3. Determine freshness:
   - **Fresh:** timestamp within 6 months AND Phase 0 doc assessment scored it `high-confidence`
   - **Stale:** timestamp older than 6 months OR Phase 0 doc assessment scored it below `high-confidence`
   - **Missing timestamp:** treat as stale

If it does not exist:
- Record as `missing`

This informs whether Phase 1 (Domain Interview) should run.

Update `state.md`: mark step 0.6 complete.

---

## Step 7: Write `_triage.md` (Step 0.7)

Write the triage assessment to `~/.claude/MEMORY/RepoSkills/<repo-slug>/_triage.md`:

```markdown
# Repository Triage

## Classification
- **Repo slug:** [slug]
- **Repo path:** [absolute path]
- **Classification:** Small | Standard | Large | Monorepo
- **File count:** [N] source files (excluding dependencies/build output)
- **Primary languages:** [list]
- **Triage date:** [ISO timestamp]

## AI Platforms Detected

| Platform | Present | Custom Instructions | Notes |
|----------|---------|-------------------|-------|
| Claude | yes/no | yes/no | [brief note] |
| Cursor | yes/no | yes/no | [brief note] |
| GitHub Copilot | yes/no | yes/no | [brief note] |
| Windsurf | yes/no | yes/no | [brief note] |
| Cline | yes/no | yes/no | [brief note] |
| AI Assistant | yes/no | yes/no | [brief note] |
| Amazon Q | yes/no | yes/no | [brief note] |

## Module Boundary Candidates

### `[path/to/module]` — [Suggested Name]
- **Signals:** [list of boundary signals detected]
- **Confidence:** high | medium | low
- **Key entry points:** [list]

[repeat for each candidate]

### Summary
- Total candidates: [N]
- High confidence: [N]
- Medium confidence: [N]
- Low confidence: [N]

## Task Skills Warranted

### Warranted

| Skill Name | Evidence | Scope | Priority |
|------------|----------|-------|----------|
| [name] | [brief evidence] | repo-wide / module-specific | high / medium / low |

### Not Warranted (checked but skipped)

| Skill Name | Reason Skipped |
|------------|----------------|
| [name] | [reason] |

### Migration State Tool Eligibility
- **migration_dir:** [path(s) to migration directories]
- **migration_tool:** [Flyway | golang-migrate | goose | dbmate | sql-migrate | Prisma | Drizzle | Atlas | generic]
- **migration_parseable:** [yes | no]
- **migration_db:** [PostgreSQL | MySQL | SQLite | other]
- **migration_state_eligible:** [yes (SQL-file AND PostgreSQL) | no]
<!-- Omit this section if Database Operations is not warranted or no migration directories detected -->

## Existing Documentation Assessment

### Summary
- Documentation files found: [N]
- High confidence: [N]
- Medium confidence: [N]
- Low confidence: [N]
- Unscored: [N]
- Well-documented areas: [list]
- Undocumented areas: [list]

### Baseline Recommendations
- **Trust as starting facts:** [list high-confidence files and topics]
- **Use with caution:** [list medium-confidence files]
- **Do not build on:** [list low-confidence files]
- **Explore from scratch:** [list undocumented areas]

### File Assessments

#### `path/to/file.md`
- **Confidence:** high | medium | low | unscored
- **Type:** [type]
- **Scope:** [scope]
- **Topics covered:** [brief list]
- **Last updated:** [date from git log]
- **Claims checked:** N verified / N checked
- **Issues found:** [specific issues, or "none found"]

[repeat for each file or group]

## Domain Context Status
- **File exists:** yes | no
- **Last interview:** [ISO date or n/a]
- **Freshness:** fresh | stale | missing
- **Phase 1 recommendation:** needed | skip | recommended
  - [reason for recommendation]
```

Update `state.md`: mark step 0.7 complete. Write the repo tier (A/B/C/D based on file count classification) to `state.md` under a `## Repo Tier` section so subsequent phases can read it without re-opening `_triage.md`. Then mark Phase 0 complete with timestamp (step 0.8).

---

## Edge cases

**No documentation exists at all:** This is a valid outcome. Write `_triage.md` with zero docs listed, note all areas are undocumented, and set baseline recommendation to "explore everything from scratch."

**Hundreds of markdown files:** Prioritise assessment of: (1) root-level docs, (2) LLM instruction files, (3) main docs/ directory, (4) top-level module READMEs. Use batch-assessment for the rest. Use parallel subagents for reading and categorisation if there are 50+ files.

**Shallow git clone (no history):** If `git log` fails, note "unable to determine last update date" and rely on content-based assessment only.

**Tiny repo with no boundaries:** A Small repo may have zero module boundary candidates. This is expected — the skill generation phases will produce repo-wide skills only.

**Monorepo with 20+ workspaces:** Focus boundary detection effort on the largest workspaces. For small workspaces (<10 files each), record them as boundaries but flag them as `low` priority for individual skill generation — they may be better served by a group skill.

**No task skills warranted:** A repo may legitimately warrant zero task skills (e.g., a pure library with no tests, no CI, no scripts). Record all checked skills as "not warranted" with reasons. The skill generation phases will focus on module-level and architecture skills instead.

---

## Rules

- **Read every doc you find.** Do not skip files because of their name or location.
- **Check claims against actual code.** Do not assess reliability based on how professional the doc looks — verify against the codebase.
- **Be honest about confidence.** A polished doc that references files that no longer exist is low confidence. A rough README that accurately describes current code is high confidence.
- **Note what's missing.** Gaps in documentation and missing boundaries are as important as what exists — they tell later phases where to focus.
- **Do not modify any existing files in the target repo.** This phase is discovery and assessment only.
- **Boundary detection is architectural, not organizational.** A directory is a module boundary because of structural signals (own build config, own entry point), not because it has many files or a tidy name.
- **Task skill detection must have clear evidence.** Do not infer a skill from vague signals. A `utils/logger.ts` file does not warrant an Observability skill; a logging framework imported across the codebase with structured logging patterns does.
