# RepoSkills Integration for migration-state

> Run this plan in the `claude_skills` repo AFTER the migration-state tool is built and published to npm.

## Prerequisites

- `migration-state` is published to npm and `bunx migration-state <dir>` works
- The tool supports: Flyway, golang-migrate, goose, dbmate, sql-migrate, Prisma, Drizzle, Atlas, and generic SQL migrations
- PostgreSQL only

## Context

The migration-state tool computes the current database schema state from SQL migration files on disk (no DB connection needed). RepoSkills needs to know about it so that when it generates skills for a repo with PostgreSQL + SQL-file migrations, it includes instructions for agents to use the tool.

Three files need changes:
1. `phase-0-discover.md` - detect migration eligibility during triage
2. `phase-2-map-generate.md` - generate skill content that references the tool
3. `phase-2-map-generate.md` (same file) - add Key Commands guidance for root platform files

## Change 1: Phase 0 — Migration State Tool Eligibility

**File:** `stow/RepoSkills/phase-0-discover.md`
**Location:** Step 5 (Detect Task Skills Warranted), under the **Database Operations** detection

Add the following block after the existing Database Operations detection signals:

```markdown
#### Migration State Tool Eligibility

When Database Operations is warranted AND migration directories are detected:

1. Record the migration directory path(s) found
2. Classify the migration tool from file patterns:
   - `V{N}__*.sql` -> Flyway
   - `*.up.sql` / `*.down.sql` -> golang-migrate
   - Files containing `-- +goose Up` -> goose
   - Files containing `-- migrate:up` -> dbmate
   - Files containing `-- +migrate Up` -> sql-migrate
   - `{timestamp}/migration.sql` pattern -> Prisma or Drizzle
   - Other `.sql` in migration dir -> generic
3. Classify as SQL-file (parseable by migration-state) or code-based (not parseable)
4. Check if the database is PostgreSQL (look for `pg` or `postgres` in dependencies)
5. Record in _triage.md:
   - `migration_dir`: path(s)
   - `migration_tool`: detected tool name
   - `migration_parseable`: yes/no
   - `migration_db`: PostgreSQL/MySQL/SQLite/other
   - `migration_count`: number of migration files
   - `migration_state_eligible`: yes (if SQL-file AND PostgreSQL) / no
```

## Change 2: Phase 2 — Database Operations Task Skill Template

**File:** `stow/RepoSkills/phase-2-map-generate.md`
**Location:** The Database Operations task skill template section (search for where task skills are generated)

Add guidance for conditionally including a Schema State section:

```markdown
#### Schema State Section (conditional)

If `_triage.md` reports `migration_state_eligible: yes`:

Add this section to the Database Operations task skill:

## Schema State

To compute the current database schema from migration files:

    bunx migration-state {migration_dir}

Use this BEFORE:
- Writing new migrations (check current column types, constraints, indices)
- Modifying queries (verify what indices exist, which columns are nullable)
- Code review of migrations (verify the migration produces the expected state)

Tool: {migration_tool} | Migrations: {migration_count} | Database: PostgreSQL

To filter to specific tables:

    bunx migration-state {migration_dir} --tables users,orders

If `_triage.md` reports `migration_state_eligible: no`:

Add a note explaining WHY it's not eligible:
- Code-based migrations: "Migrations use {tool} ({language}). Run `{alternative_command}` to inspect schema."
- Non-PostgreSQL: "Database is {db}. migration-state currently supports PostgreSQL only."
```

## Change 3: Phase 2 — Root Platform File Key Commands

**File:** `stow/RepoSkills/phase-2-map-generate.md`
**Location:** Under the "Required sections in ALL root platform files" area, within the Key Commands section guidance

Add:

```markdown
If migration-state is eligible for this repo, add to the Key Commands section
of ALL root platform files:

| Command | Purpose |
|---------|---------|
| `bunx migration-state {migration_dir}` | Show current DB schema state from migrations |

This goes alongside existing commands like `bun test`, `bun run dev`, etc.
Do NOT add this command if migration-state is not eligible.
```

## Verification

After applying all three changes:

1. Read back `phase-0-discover.md` and confirm the Migration State Tool Eligibility block is in Step 5 under Database Operations
2. Read back `phase-2-map-generate.md` and confirm both the Schema State section guidance and the Key Commands addition are present
3. Run the skill-drift detection script if available to ensure no routing inconsistencies were introduced
4. Verify no existing content in either file was removed or altered (we are only adding, not modifying)
