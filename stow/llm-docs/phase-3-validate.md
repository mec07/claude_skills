# Phase 3: Adversarial Validation of Repository LLM Documentation

You are a **reviewer, not the author.** Your sole job is to find errors, fabrications, broken references, missing coverage, and misleading claims in the documentation under `docs/llm/`, `CLAUDE.md`, `.github/copilot-instructions.md`, `docs/README.md`, and any local context files.

**Assume the documentation is wrong until you prove it right.** Every claim must be verified against the actual source code. You are not here to improve prose or restructure — you are here to find things that are incorrect, missing, or misleading, and to fix them.

---

## Checklist

Use this to track progress. Mark each item `[x]` in `state.md` as you complete it.

- [ ] 3a. Create `_audit.md` in MEMORY directory
- [ ] 3b. List all doc files to validate
- [ ] 3c. Decide parallelisation strategy (5+ doc files → dispatch subagents)
- [ ] 3d. Check 1: File path verification (all doc files)
- [ ] 3e. Check 2: Command verification (all doc files)
- [ ] 3f. Check 2b: Script verification (all doc files)
- [ ] 3g. Check 3: Architectural claim verification (all doc files)
- [ ] 3h. Check 4: Data structure reference verification (all doc files)
- [ ] 3i. Check 5: Cross-link verification (all doc files)
- [ ] 3j. Check 6: Duplication check (all doc files)
- [ ] 3k. Check 7: Staleness check (all doc files)
- [ ] 3l. Check 8: Coverage check (all doc files)
- [ ] 3m. Check 9: Communication path completeness (all doc files)
- [ ] 3n. Check 10: Contradiction check against `_original_docs.md`
- [ ] 3o. Merge subagent outputs (if parallelised)
- [ ] 3p. Update `_audit.md` summary with final tallies
- [ ] 3q. Update `state.md` — mark Phase 3 complete
- [ ] 3r: Check 10b — internal consistency across generated docs
- [ ] 3s: Check 11 — local development setup verification
- [ ] 3t: Check 12 — domain context verification
- [ ] 3u: Check 13 — task router and recipe verification

---

## Inputs and Outputs

**Inputs:**
- All documentation files: `docs/llm/**`, `CLAUDE.md`, `.github/copilot-instructions.md`, `docs/README.md`, local context files
- Original documentation assessment: `~/.claude/MEMORY/llm-docs/<repo-slug>/_original_docs.md`
- The actual codebase (source of truth for all verification)

**Outputs:**
- Documentation files with errors fixed in place
- Working file: `~/.claude/MEMORY/llm-docs/<repo-slug>/_audit.md` — the validation ledger
- Per-doc working files (if parallelised): `~/.claude/MEMORY/llm-docs/<repo-slug>/_validate_<doc>.md`

---

## Working file: `_audit.md`

**Create `~/.claude/MEMORY/llm-docs/<repo-slug>/_audit.md` at the start of this phase.** This is your validation ledger. Write to it as you go — do not rely on memory. This file is how your findings pass to later phases.

Format:

```markdown
# Validation Audit

## Findings

### [doc file path] — [short description]
- **Claim:** [what the doc says]
- **Verdict:** ✅ confirmed | ❌ wrong | ⚠️ unverifiable
- **Evidence:** [source file you checked, what it actually shows]
- **Action taken:** [fixed | removed | marked TODO | no action needed]

## Summary
- Files audited: N
- Claims checked: N
- Errors found and fixed: N
- Claims removed as unverifiable: N
- Remaining <!-- TODO: verify --> markers: N
- Overall confidence: high | medium | low
- Concerns: [anything that still worries you]
```

Update `_audit.md` continuously as you work. Every finding goes in the ledger immediately. Do not batch findings.

**Updating state:** After creating `_audit.md`, mark step 3a complete in `state.md`.

---

## Rules

- **Read the doc, then read the code.** For every factual claim, open the referenced file and verify. Do not assume a claim is correct because it sounds reasonable.
- **Fix errors immediately.** When you find something wrong, fix it right now, then continue auditing.
- **Remove rather than guess.** If you cannot verify a claim from source code, remove it or mark it `<!-- TODO: verify -->`. Do not replace one guess with a different guess.
- **Do not add new unverified content.** If you discover a gap, you may fill it — but only with information you verify from source code in the same step.
- **Do not weaken the docs.** If something is correct and useful, leave it alone. You are here to fix problems, not to rewrite things that work.
- **Log everything to `_audit.md`.** Every check, every finding, every fix.

---

## Parallelisation

**Threshold:** If the repo has 5 or more documentation files to validate, dispatch one validation subagent per doc file. If fewer than 5, execute sequentially.

### Parallel execution protocol

1. **List all doc files** to validate: everything under `docs/llm/`, plus `CLAUDE.md`, `.github/copilot-instructions.md`, `docs/README.md`, and any local context files.

2. **Dispatch one subagent per doc file** (use `sonnet` model — validation is systematic checking, not creative synthesis). Each subagent receives:
   - The full text of the doc file it is responsible for
   - The full audit procedure (all 10 checks below) scoped to that single file
   - The rules section above
   - The MEMORY directory path for output
   - Instruction to write findings to `~/.claude/MEMORY/llm-docs/<repo-slug>/_validate_<doc-name>.md` (e.g., `_validate_architecture.md`, `_validate_overview.md`)
   - The working file format from above

3. **Each subagent** performs all 10 checks on its assigned doc file, fixes errors in the doc as it goes, and writes all findings to its `_validate_<doc>.md` file.

4. **After all subagents complete,** the orchestrating agent:
   - Reads every `_validate_<doc>.md` file
   - Performs Check 6 (duplication check) across all docs — subagents cannot detect cross-file duplication
   - Performs Check 8 (coverage check) across the full repo — subagents only see their own doc
   - Performs Check 10 (contradiction check) across all docs — requires cross-file comparison
   - Merges all findings into a single `_audit.md`
   - Deletes the per-doc `_validate_<doc>.md` files

**If a validation subagent fails** to produce its `_validate_<doc>.md` file: re-dispatch once with the same doc. If it fails again, the orchestrating agent validates that doc sequentially during the merge step. Note the gap in `_audit.md` with: `### [doc] — validation subagent failed, validated sequentially`.

**Updating state:** After deciding the parallelisation strategy, mark step 3c complete in `state.md`.

### Sequential execution

If fewer than 5 doc files, work through every documentation file one at a time, performing all 10 checks on each before moving to the next.

---

## Audit procedure

Work through every documentation file. For each file, perform ALL of the following checks.

### Check 1: File path verification

Every file path mentioned in the doc — in inline code, links, or prose — must exist in the repo.

For each path: verify it exists. If it doesn't, either fix the path or remove the reference.

**Updating state:** After completing Check 1 for all doc files, mark step 3d complete in `state.md`.

### Check 2: Command verification

Every command documented (in `workflows.md` or elsewhere) must be defined in an actual config file.

For each command: check `package.json` scripts, `Makefile`, CI configs, or `docker-compose` files. If the command isn't defined anywhere, remove it.

**Updating state:** After completing Check 2 for all doc files, mark step 3e complete in `state.md`.

### Check 2b: Script verification

Every script documented in `scripts.md` and script directory READMEs must exist and be accurately described.

For each script documented:
- Verify the script file exists at the stated path
- Verify the run command is correct (check `package.json` scripts, shebangs, or ecosystem conventions)
- Verify stated arguments/options match the script's actual argument parser
- Verify environment variables listed are actually used by the script
- Verify shared utilities referenced actually exist at the stated paths

For each script directory README: verify it covers all scripts in that directory (check for undocumented scripts).

For `scripts.md`: verify the decision table scenarios match the actual script distribution, and that the "All Script Locations" table is complete (search for script directories not listed).

**Updating state:** After completing Check 2b for all doc files, mark step 3f complete in `state.md`.

### Check 3: Architectural claim verification

Every claim about what a component does, how components communicate, what depends on what, or how data flows must be traceable to actual code.

For each claim:
- Open the file(s) it refers to
- Confirm the described behaviour matches the actual code
- Pay special attention to: communication mechanisms (is it really HTTP? really a queue? really GraphQL?), data flow direction, schema/contract references, and stated dependencies

**Updating state:** After completing Check 3 for all doc files, mark step 3g complete in `state.md`.

### Check 4: Data structure reference verification

Every reference to a schema, table, index, type definition, or data structure location must point to the actual definition.

For each reference:
- Open the stated file
- Confirm the data structure exists there
- Confirm any stated relationships between data structures are real (check the mapping/sync code)
- Confirm naming conventions described are actually followed in the codebase

**Updating state:** After completing Check 4 for all doc files, mark step 3h complete in `state.md`.

### Check 5: Cross-link verification

Every markdown link `[text](path)` must resolve to a file that exists.

**Updating state:** After completing Check 5 for all doc files, mark step 3i complete in `state.md`.

### Check 6: Duplication check

Scan for the same information appearing in multiple files. If found, keep it in the most appropriate location and replace the duplicates with links.

**Note:** If parallelised, this check must be performed by the orchestrating agent after merging, since subagents cannot detect cross-file duplication.

**Updating state:** After completing Check 6, mark step 3j complete in `state.md`.

### Check 7: Staleness check

Look for content that may have been true when written but has since drifted from the code. Common signs:
- File paths that exist but contain different code than described
- Components described with responsibilities that don't match their current implementation
- Deprecated features or patterns still documented as current
- Commands that exist but do something different than documented

**Updating state:** After completing Check 7 for all doc files, mark step 3k complete in `state.md`.

### Check 8: Coverage check

List all significant directories in the repo (excluding generated/dependency directories). For every significant directory: is it covered by a module doc? If a major area of the codebase has no documentation, note it and write a doc for it now (verified from source code).

**Note:** If parallelised, this check must be performed by the orchestrating agent after merging, since it requires a repo-wide view.

**Updating state:** After completing Check 8, mark step 3l complete in `state.md`.

### Check 9: Communication path completeness

Read `architecture.md` and every module doc. For every inter-component communication path described:
- Is the sender file path correct and does the file contain the sending code?
- Is the receiver file path correct and does the file contain the handling code?
- Is the mechanism correct?
- Is the contract/schema file correctly referenced?

Then check the inverse: are there communication paths in the code that are NOT documented? Search for patterns like HTTP clients, queue publishers, event emitters, cross-module function calls, etc. Cross-reference against the documented communication paths. Document any missing ones.

**Updating state:** After completing Check 9 for all doc files, mark step 3m complete in `state.md`.

### Check 10: Contradiction check

Read `~/.claude/MEMORY/llm-docs/<repo-slug>/_original_docs.md` to identify all original docs and their confidence scores.

For each **high-confidence** original doc: compare its claims against the `docs/llm/` files. If there are contradictions, check the source code to determine which is correct, and fix the wrong one.

**Sampling for large doc sets:** If the total claims to check across all high-confidence original docs exceeds 50, sample up to 20 claims prioritised by: (1) claims about architecture or inter-component communication paths, (2) claims about file paths or commands, (3) all other claims. Log the sampling rate and selection criteria in `_audit.md`. For medium-confidence originals, spot-check only the claims most relevant to the generated docs — do not attempt exhaustive comparison.

For each **medium-confidence** original doc: spot-check any contradictions you notice, but prioritise what the source code actually shows over the original doc's claims.

Low-confidence original docs do not warrant a contradiction check — the generated docs should be more reliable.

**Note:** If parallelised, this check must be performed by the orchestrating agent after merging, since it requires cross-file comparison against the original docs.

**Updating state:** After completing Check 10, mark step 3n complete in `state.md`.

### Check 10b: Internal consistency across generated docs

Scan the generated documentation set for contradictions BETWEEN generated docs (not comparing to originals — that was Check 10):
- Does module A's doc claim it communicates with module B via REST, while module B's doc says it receives from A via gRPC?
- Do two docs describe different responsibilities for the same component?
- Are the same file paths described differently in different docs?
- Does `architecture.md` describe a flow that contradicts what a module doc says?

For each internal contradiction: trace the source code, determine which doc is correct, fix the incorrect one. Log each finding to `_audit.md`.

**Update state:** Mark step 3r complete in `state.md`.

### Check 11: Local development setup verification

If `workflows.md` includes a Prerequisites section or `local-dev.md` exists:
- Verify runtime version claims match version files (`.nvmrc`, `.python-version`, `.tool-versions`, etc.)
- Verify package manager identification matches the lockfile that actually exists in the repo
- Verify environment variables listed match what `.env.example` (or equivalent) contains
- Verify database setup commands match actual migration tool configuration
- Verify Docker service descriptions match `docker-compose.yml` contents
- For monorepos: verify per-project setup sections match actual project configs

**Updating state:** After completing Check 11, mark step 3s complete in `state.md`.

### Check 12: Domain context verification

If `docs/llm/domain-context.md` exists:
- Do NOT fact-check business claims (product description, industry, users, regulatory requirements) — these are human-provided and authoritative
- DO verify any file paths, commands, or technical claims within the domain context against the codebase
- DO check that glossary terms defined in the Domain Glossary actually appear in the codebase (if a term is defined but never appears in code, flag it as potentially stale)
- DO verify that "Architecture Rationale" entries reference real code/files that exist

**Updating state:** After completing Check 12, mark step 3t complete in `state.md`.

### Check 13: Task router and recipe verification

If `task-router.md` exists:
- Verify every doc path and section anchor in the "Read (in order)" column resolves to a real file and section
- Verify the task list covers the most common operations for this repo

If `docs/llm/recipes/` exists:
- Verify every file path in each recipe exists
- Verify code patterns cited match the actual source files
- Verify the verify commands are correct

**Updating state:** After completing Check 13, mark step 3u complete in `state.md`.

---

## Completion

When you have audited every documentation file:

1. If parallelised: merge all `_validate_<doc>.md` findings into `_audit.md` and delete the per-doc files. Mark step 3o complete in `state.md`.
2. Update the Summary section of `_audit.md` with final tallies. Mark step 3p complete in `state.md`.
3. Report a brief summary to the orchestrator: how many errors found/fixed, claims removed, remaining concerns, and overall confidence level.
4. Mark Phase 3 complete in `state.md` (step 3q).
