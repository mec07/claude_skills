# Phase 3: Adversarial Validation of Repository LLM Documentation

You are a **reviewer, not the author.** Your sole job is to find errors, fabrications, broken references, missing coverage, and misleading claims in the documentation under `docs/llm/`, `CLAUDE.md`, `.github/copilot-instructions.md`, `docs/README.md`, and any local context files.

**Assume the documentation is wrong until you prove it right.** Every claim must be verified against the actual source code. You are not here to improve prose or restructure — you are here to find things that are incorrect, missing, or misleading, and to fix them.

---

## Working file: `docs/llm/_audit.md`

**Create `docs/llm/_audit.md` at the start of this phase.** This is your validation ledger. Write to it as you go — do not rely on memory. This file is how your findings pass to later phases.

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

---

## Rules

- **Read the doc, then read the code.** For every factual claim, open the referenced file and verify. Do not assume a claim is correct because it sounds reasonable.
- **Fix errors immediately.** When you find something wrong, fix it right now, then continue auditing.
- **Remove rather than guess.** If you cannot verify a claim from source code, remove it or mark it `<!-- TODO: verify -->`. Do not replace one guess with a different guess.
- **Do not add new unverified content.** If you discover a gap, you may fill it — but only with information you verify from source code in the same step.
- **Do not weaken the docs.** If something is correct and useful, leave it alone. You are here to fix problems, not to rewrite things that work.
- **Log everything to `_audit.md`.** Every check, every finding, every fix.

---

## Audit procedure

Work through every documentation file, one at a time. For each file, perform ALL of the following checks.

### Check 1: File path verification

Every file path mentioned in the doc — in inline code, links, or prose — must exist in the repo.

For each path: verify it exists. If it doesn't, either fix the path or remove the reference.

### Check 2: Command verification

Every command documented (in `workflows.md` or elsewhere) must be defined in an actual config file.

For each command: check `package.json` scripts, `Makefile`, CI configs, or `docker-compose` files. If the command isn't defined anywhere, remove it.

### Check 3: Architectural claim verification

Every claim about what a component does, how components communicate, what depends on what, or how data flows must be traceable to actual code.

For each claim:
- Open the file(s) it refers to
- Confirm the described behaviour matches the actual code
- Pay special attention to: communication mechanisms (is it really HTTP? really a queue? really GraphQL?), data flow direction, schema/contract references, and stated dependencies

### Check 4: Data structure reference verification

Every reference to a schema, table, index, type definition, or data structure location must point to the actual definition.

For each reference:
- Open the stated file
- Confirm the data structure exists there
- Confirm any stated relationships between data structures are real (check the mapping/sync code)
- Confirm naming conventions described are actually followed in the codebase

### Check 5: Cross-link verification

Every markdown link `[text](path)` must resolve to a file that exists.

### Check 6: Duplication check

Scan for the same information appearing in multiple files. If found, keep it in the most appropriate location and replace the duplicates with links.

### Check 7: Staleness check

Look for content that may have been true when written but has since drifted from the code. Common signs:
- File paths that exist but contain different code than described
- Components described with responsibilities that don't match their current implementation
- Deprecated features or patterns still documented as current
- Commands that exist but do something different than documented

### Check 8: Coverage check

List all significant directories in the repo (excluding generated/dependency directories). For every significant directory: is it covered by a module doc? If a major area of the codebase has no documentation, note it and write a doc for it now (verified from source code).

### Check 9: Communication path completeness

Read `architecture.md` and every module doc. For every inter-component communication path described:
- Is the sender file path correct and does the file contain the sending code?
- Is the receiver file path correct and does the file contain the handling code?
- Is the mechanism correct?
- Is the contract/schema file correctly referenced?

Then check the inverse: are there communication paths in the code that are NOT documented? Search for patterns like HTTP clients, queue publishers, event emitters, cross-module function calls, etc. Cross-reference against the documented communication paths. Document any missing ones.

### Check 10: Contradiction check

Read `docs/llm/_original_documentation.md` to identify all original docs and their confidence scores.

For each **high-confidence** original doc: compare its claims against the `docs/llm/` files. If there are contradictions, check the source code to determine which is correct, and fix the wrong one.

For each **medium-confidence** original doc: spot-check any contradictions you notice, but prioritise what the source code actually shows over the original doc's claims.

Low-confidence original docs do not warrant a contradiction check — the generated docs should be more reliable.

---

## Completion

When you have audited every documentation file:

1. Update the Summary section of `_audit.md` with final tallies
2. Report a brief summary to the orchestrator: how many errors found/fixed, claims removed, remaining concerns, and overall confidence level
