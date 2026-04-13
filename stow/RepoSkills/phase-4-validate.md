# Phase 4: Validate — Adversarial Fact-Checking Against Source Code

You are a **reviewer, not the author.** Your sole job is to find errors, fabrications, broken references, missing coverage, and misleading claims in the skill files under `.ai/skills/` and the platform glue files (`AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `.github/copilot-instructions.md`).

**Assume the skills are wrong until you prove them right.** Every claim must be verified against the actual source code. You are not here to improve prose or restructure — you are here to find things that are incorrect, missing, or misleading, and to fix them.

---

## Checklist

Copy this checklist into `state.md` under the Phase 4 entry. Mark each item `[x]` immediately upon completion.

```
- [ ] 4.0: Create _audit.md in MEMORY directory
- [ ] 4.1: List all skill files to validate
- [ ] 4.2: Decide parallelisation strategy (5+ skill files -> dispatch subagents)
- [ ] 4.3: Check 1 — File path verification (all skill files)
- [ ] 4.4: Check 2 — Command verification (all skill files)
- [ ] 4.5: Check 3 — Architectural claim verification (all skill files)
- [ ] 4.6: Check 4 — Relationship verification (all module skills)
- [ ] 4.7: Check 5 — Cross-link verification (all skill files)
- [ ] 4.8: Check 6 — Duplication check (all skill files)
- [ ] 4.9: Check 7 — Staleness check (all skill files)
- [ ] 4.10: Check 8 — Coverage check (all skill files)
- [ ] 4.11: Check 9 — The 5-second grep test (all skill files)
- [ ] 4.12: Check 10 — Cross-skill consistency (no contradictions between skills)
- [ ] 4.13: Check 11 — Token budget enforcement
- [ ] 4.14: Check 12 — Domain context verification (if domain-context.md exists)
- [ ] 4.15: Merge subagent outputs (if parallelised)
- [ ] 4.16: Update _audit.md summary with final tallies
- [ ] 4.17: Update state.md — mark Phase 4 complete with timestamp
```

---

## Inputs and Outputs

| Direction | File | Location | Description |
|---|---|---|---|
| **Input** | `state.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Repo path, slug, phase progress |
| **Input** | All skill files | Target repo: `.ai/skills/` | Skills to validate |
| **Input** | Platform glue files | Target repo root | `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `.github/copilot-instructions.md` |
| **Input** | Codebase | Target repo on disk | Source of truth for all verification |
| **Output** | Skill files with errors fixed | Target repo: `.ai/skills/` | Corrected skills |
| **Output** | `_audit.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Validation ledger with all findings |
| **Output** | Per-skill working files (if parallelised) | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | `_validate_<skill>.md` (temporary) |

---

## Updating state

After completing **each numbered step** below, immediately update `state.md`:

1. Mark the step's checkbox `[x]` in the Phase 4 checklist
2. Update the `updated:` timestamp

Do not batch state updates. If context is lost between steps, the recovery protocol relies on `state.md` being current. A completed step with no state update will be repeated on resume.

---

## Working file: `_audit.md`

**Create `~/.claude/MEMORY/RepoSkills/<repo-slug>/_audit.md` at the start of this phase.** This is your validation ledger. Write to it as you go — do not rely on memory. This file is how your findings pass to later phases.

Format:

```markdown
# Validation Audit

## Findings

### [skill file path] — [short description]
- **Claim:** [what the skill says]
- **Verdict:** confirmed | wrong | unverifiable
- **Evidence:** [source file you checked, what it actually shows]
- **Action taken:** [fixed | removed | marked TODO | no action needed]

## Summary
- Files audited: N
- Claims checked: N
- Errors found and fixed: N
- Claims removed as unverifiable: N
- Remaining <!-- TODO: verify --> markers: N
- Token budget violations: N
- 5-second grep test failures flagged and removed: N
- Overall confidence: high | medium | low
- Concerns: [anything that still worries you]
```

Update `_audit.md` continuously as you work. Every finding goes in the ledger immediately. Do not batch findings.

Update `state.md`: mark step 4.0 complete.

---

## Rules

- **Read the skill, then read the code.** For every factual claim, open the referenced file and verify. Do not assume a claim is correct because it sounds reasonable.
- **Fix errors immediately.** When you find something wrong, fix it right now, then continue auditing.
- **Remove rather than guess.** If you cannot verify a claim from source code, remove it or mark it `<!-- TODO: verify -->`. Do not replace one guess with a different guess.
- **Do not add new unverified content.** If you discover a gap, you may fill it — but only with information you verify from source code in the same step.
- **Do not weaken the skills.** If something is correct and useful, leave it alone. You are here to fix problems, not rewrite things that work.
- **Log everything to `_audit.md`.** Every check, every finding, every fix.

---

## Parallelisation

**Threshold:** If the repo has 5 or more skill files to validate, dispatch one validation subagent per skill file. If fewer than 5, execute sequentially.

### Parallel execution protocol

1. **List all skill files** to validate: everything under `.ai/skills/`, plus `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `.github/copilot-instructions.md`, and any per-module routing files.

2. **Dispatch one subagent per skill file** (use `sonnet` model — validation is systematic checking, not creative synthesis). Each subagent receives:
   - The full text of the skill file it is responsible for
   - The full audit procedure (all checks below) scoped to that single file
   - The rules section above
   - The MEMORY directory path for output
   - Instruction to write findings to `~/.claude/MEMORY/RepoSkills/<repo-slug>/_validate_<skill-name>.md`

3. **Each subagent** performs all applicable checks on its assigned file, fixes errors as it goes, and writes all findings to its `_validate_<skill>.md` file.

4. **After all subagents complete,** the orchestrating agent:
   - Reads every `_validate_<skill>.md` file
   - Performs Check 6 (duplication check) across all skills — subagents cannot detect cross-file duplication
   - Performs Check 8 (coverage check) across the full repo — subagents only see their own skill
   - Performs Check 10 (cross-skill consistency) — requires cross-file comparison
   - Merges all findings into a single `_audit.md`
   - Deletes the per-skill `_validate_<skill>.md` files

**If a validation subagent fails:** Re-dispatch once. If it fails again, the orchestrating agent validates that skill sequentially during the merge step.

Update `state.md`: mark step 4.2 complete.

---

## Audit Procedure

Work through every skill file. For each file, perform ALL of the following checks.

### Check 1: File path verification (Step 4.3)

Skills should not contain individual file paths to tests, configs, or examples. The acceptable references are:
- **Module entry points** (full path, one per module skill — essential for routing, especially in languages like Python where the entry file could be anything)
- **Folder structures** (e.g., "`pkg/templates/`", "`tests/integration/`") — these change less frequently than individual files and provide useful navigational context
- **Config file names** referenced in commands (e.g., "configured in `jest.config.ts`")

For each file path found: (1) verify it exists, (2) check whether it should be there at all — if it's an individual test file, example file, or source file that the agent could find via grep/glob, **remove it** and replace with a description of the convention or folder structure. Individual file paths are brittle (they break on rename/move/delete) and greppable (they fail the 5-second test).

Update `state.md`: mark step 4.3 complete.

### Check 2: Command verification (Step 4.4)

Every command documented (in task skills, orientation Quick Reference, module skills, root platform files) must be defined in an actual config file.

**Accuracy check:** For each command: check `package.json` scripts, `Makefile`, `Taskfile.yml`, `Cargo.toml`, `build.gradle`, CI configs, `docker-compose` files, or equivalent for the repo's language. Standard tool commands (`go test`, `pytest`, `cargo build`, `rspec`) are valid if the tool is a project dependency. If the command isn't defined anywhere, remove it.

**Completeness check (task skills only):** The scripts/commands task skill must have the COMPLETE command reference — every command in the actual config files should be listed. Open the config files and compare. Root platform files and orientation.md are quick references (daily commands only) and point to the task skill for the full list.

**Consistency check:** The Key Commands quick reference must be **identical** across all four root platform files. If any root file has commands that the others don't, flag and fix. Module-specific commands belong in module skill Overrides sections, not in root files.

Update `state.md`: mark step 4.4 complete.

### Check 3: Architectural claim verification (Step 4.5)

Every claim about what a component does, how components communicate, what depends on what, or how data flows must be traceable to actual code.

For each claim:
- Open the file(s) it refers to
- Confirm the described behaviour matches the actual code
- Pay special attention to: communication mechanisms, data flow direction, schema/contract references, and stated dependencies
- **Flag any exact numbers or counts** (e.g., "247 Go files", "12 Makefile targets", "32 test files"). These are high-fabrication-risk — the generating agent may have guessed rather than counted. Verify each number by actually running the count, then **remove the number from the skill** (it fails the 5-second grep test and goes stale). If you find numbers that were not verified, this is a finding.
- **Flag absolute claims that may be conditional.** Watch for statements like "files ARE X" or "always does Y" when the code shows the truth is more nuanced (e.g., "a normalisation package is used during comparison" ≠ "files are always in that format"). Read the actual code — don't trust the generating agent's interpretation of what a library or function does.

Update `state.md`: mark step 4.5 complete.

### Check 4: Relationship verification (Step 4.6)

For each module skill, verify the Relationships section:
- **Depends on:** grep for actual import statements from this module. Do they match?
- **Depended on by:** grep for imports OF this module from other modules. Do they match?
- **Communicates with:** verify each external boundary claim against actual code (HTTP clients, queue publishers, etc.)
- **Symmetry check:** if module A says it depends on B, does module B list A as a dependent?

Update `state.md`: mark step 4.6 complete.

### Check 5: Cross-link verification (Step 4.7)

Every file path referenced in a skill must resolve to a file that exists on disk.

Update `state.md`: mark step 4.7 complete.

### Check 6: Duplication check (Step 4.8)

Scan for the same information appearing in multiple **skill files** (`.ai/skills/`). If found, keep it in the most appropriate location and replace the duplicates with links or remove them.

**Root platform files are exempt from this check.** CLAUDE.md, AGENTS.md, .cursorrules, and copilot-instructions.md intentionally contain the same required sections because each must be self-sufficient. This overlap is by design — do not remove it.

Also verify that root platform files have preserved any project-specific content that existed before the skill pipeline ran. If a root file was rewritten and user-added content was lost, flag this as a finding.

**Note:** If parallelised, this check must be performed by the orchestrating agent after merging.

Update `state.md`: mark step 4.8 complete.

### Check 7: Staleness check (Step 4.9)

Look for content that may have been true when written but has since drifted from the code:
- File paths that exist but contain different code than described
- Components described with responsibilities that don't match their current implementation
- Deprecated features or patterns still documented as current
- Commands that exist but do something different than documented

Update `state.md`: mark step 4.9 complete.

### Check 8: Coverage check (Step 4.10)

List all significant directories in the repo (excluding generated/dependency directories). For every significant directory: is it covered by a module skill or mentioned in the orientation skill? If a major area of the codebase has no skill coverage, note it and write a skill for it now (verified from source code).

**Note:** If parallelised, this check must be performed by the orchestrating agent after merging.

Update `state.md`: mark step 4.10 complete.

### Check 9: The 5-second grep test (Step 4.11)

Scan every skill file for content that fails the 5-second grep test:
- Lists of files in a directory
- Lists of routes/endpoints
- Copies of type definitions or schemas
- Lists of environment variables
- Function signatures or method lists
- **Exact counts or numbers** (e.g., "247 Go files", "12 Makefile targets", "32 test files") — these are greppable, go stale instantly, and are high-fabrication-risk. The generating agent may have guessed rather than counted. Remove them.
- **Individual file paths to tests, configs, or examples** (e.g., `pkg/billing/billing_test.go`, `src/utils/helpers.ts`) — these are greppable and brittle. Replace with a description of the convention or folder structure (e.g., "co-located `_test.go` files", "shared helpers in `testutils/`"). Entry point paths and folder structures are acceptable.
- Any content an agent could find faster by running `grep` or `glob` than by reading the skill

**Flag and remove** every instance. Replace with a description of the convention or pattern, not a pointer to a specific file.

Update `state.md`: mark step 4.11 complete.

### Check 10: Cross-skill consistency and routing verification (Step 4.12)

**Required sections verification (CRITICAL):**

Every root platform file (CLAUDE.md, AGENTS.md, .cursorrules, .github/copilot-instructions.md) must be self-sufficient and MUST contain ALL of these sections. Check each file against this list:
- [ ] Tech Stack
- [ ] Architecture
- [ ] Key Commands
- [ ] Key Rules
- [ ] Module Routing (table with USE WHEN keywords)
- [ ] Task Routing (table mapping intents to skill combinations)
- [ ] Context Window Discipline
- [ ] Before Modifying Code
- [ ] Skill & Routing Maintenance
- [ ] Documentation (pointers to skill layer)
- [ ] Coding Standards
- [ ] New to This Repo?
- [ ] No root file redirects to another root file — each stands alone

**If any root file is missing any of these sections, this is a blocking finding.** Each root file may be the only context an agent has after compaction — they must all be independently complete.

**Routing table content verification:**
- Does every module skill have a corresponding row in the Module Routing tables?
- Does every task skill have a corresponding entry in the Task Routing tables?
- Are the routing table rows IDENTICAL across all four root platform files?

**Cross-skill contradiction scan:**
- Does module A's skill claim it communicates with module B via REST, while module B's skill says it receives from A via gRPC?
- Do two skills describe different responsibilities for the same component?
- Are the same folder structures described differently in different skills?
- Does the orientation skill describe something that contradicts a module skill?
- Does `AGENTS.md` contain information that contradicts `orientation.md`?

For each contradiction: trace the source code, determine which skill is correct, fix the incorrect one. Log each finding to `_audit.md`.

**Note:** If parallelised, this check must be performed by the orchestrating agent after merging.

Update `state.md`: mark step 4.12 complete.

### Check 11: Token budget enforcement (Step 4.13)

Check each skill file against its token budget:
- Orientation skill: ~2k tokens
- Module skills: ~1.5k tokens each
- Task skills: ~1.5k tokens each
- `AGENTS.md`: ~4k tokens (32KB hard limit)
- `CLAUDE.md`: ~3-4k tokens (self-sufficient — must NOT redirect to other root files)

For any file over budget:
- Look for 5-second grep test failures to remove (most common cause of bloat)
- Look for duplication to eliminate
- Look for verbose prose that can be condensed
- Flag the file in `_audit.md` with current size and budget

Update `state.md`: mark step 4.13 complete.

### Check 12: Domain context verification (Step 4.14)

If `.ai/skills/domain-context.md` exists:
- Do NOT fact-check business claims (product description, industry, users, regulatory requirements) — these are human-provided and authoritative
- DO verify any file paths, commands, or technical claims within the domain context against the codebase
- DO check that glossary terms defined in the Domain Glossary actually appear in the codebase
- DO verify that "Architecture Rationale" entries reference real code/files that exist

Update `state.md`: mark step 4.14 complete.

---

## Completion

When you have audited every skill file:

1. If parallelised: merge all `_validate_<skill>.md` findings into `_audit.md` and delete the per-skill files. Mark step 4.15 complete.
2. Update the Summary section of `_audit.md` with final tallies. Mark step 4.16 complete.
3. Report a brief summary to the orchestrator: how many errors found/fixed, claims removed, remaining concerns, and overall confidence level.
4. Mark Phase 4 complete in `state.md` with timestamp (step 4.17).
