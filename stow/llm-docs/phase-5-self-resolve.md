# Phase 5: Self-Resolve

The clarity review (Phase 4) produced `_review.md` containing issues, gaps, ambiguities, and questions. Your job is to resolve as many of these as possible **from the source code alone**, without asking the user.

---

## Checklist

Use this to track progress. Mark each item `[x]` in `state.md` as you complete it.

- [ ] 5a. Read all open issues from `_review.md`
- [ ] 5b. Attempt to resolve each issue from source code
- [ ] 5c. Update docs for each resolved issue
- [ ] 5d. Look for new issues revealed by resolutions
- [ ] 5e. Update `_review.md` summary with final tallies
- [ ] 5f. Update `state.md` — mark Phase 5 complete

---

## Inputs and Outputs

**Inputs:**
- Working file: `~/.claude/MEMORY/llm-docs/<repo-slug>/_review.md` (produced by Phase 4)
- All documentation files: `docs/llm/**`, `CLAUDE.md`, `.github/copilot-instructions.md`, `docs/README.md`, local context files
- The actual codebase (source of truth for resolving issues)

**Outputs:**
- Updated documentation files with resolved issues fixed in place
- Updated `~/.claude/MEMORY/llm-docs/<repo-slug>/_review.md` with resolution statuses, evidence, and final summary

---

## Working file: `_review.md`

Use `~/.claude/MEMORY/llm-docs/<repo-slug>/_review.md` as your ledger. Update it as you work. Do not create a new file — this is the same file Phase 4 produced, and you are updating it in place.

### Resolution statuses

- **resolved** — issue fully answered from source code, documentation updated
- **partial — needs human input** — partially answered, remaining uncertainty marked with `<!-- TODO: verify -->` in the docs
- **open** — cannot be answered from source code, will go to the user in Phase 8

---

## Process

### Step 1: Read all open issues

Open `~/.claude/MEMORY/llm-docs/<repo-slug>/_review.md`. Read every issue with status `open`.

**Updating state:** After reading all open issues, mark step 5a complete in `state.md`.

### Step 2: Attempt to resolve each issue from source code

For each open issue, ask: **"Can I answer this question by reading the actual code?"**

- If **yes**: read the relevant source files, find the answer, update the documentation, and change the issue status to `resolved`. Record what you found and what you changed.
- If **partially**: update the docs with what you can verify, mark the remaining uncertainty with `<!-- TODO: verify -->`, change the status to `partial — needs human input`, and note what specifically you still need answered.
- If **no**: leave the status as `open`. These will go to the user in Phase 8.

**Updating state:** After attempting to resolve all issues, mark step 5b complete in `state.md`.

### Step 3: For each resolved issue, update the docs

When you resolve an issue:
1. Fix the documentation file(s) involved
2. Verify your fix follows the same rules as all other phases — no hallucination, evidence only
3. Update `_review.md` with:
   - Status: `resolved`
   - Resolution: what you found and what you changed
   - Evidence: which source file(s) you read

**Updating state:** After updating docs for all resolved issues, mark step 5c complete in `state.md`.

### Step 4: Look for new issues

Resolving one issue sometimes reveals another. If fixing a gap exposes a new ambiguity or missing connection, log it as a new issue in `_review.md`. Then attempt to resolve it in the same pass.

**Updating state:** After checking for and addressing new issues, mark step 5d complete in `state.md`.

### Step 5: Update the summary

Update the summary section of `_review.md`:

```markdown
## Summary (after self-resolve)
- Total issues: N
- Resolved by self-resolve: N
- Partial (needs human input): N
- Open (needs human input): N
- New issues found during self-resolve: N
```

Report to the orchestrator: how many issues resolved, how many remain open or partial, and the highest-priority unresolved items.

**Updating state:** After updating the summary, mark step 5e complete in `state.md`. Then mark Phase 5 complete (step 5f).

---

## Rules

- **Same evidence standards as all other phases.** Do not resolve an issue by guessing. If you can't find the answer in the source code, leave it open.
- **Do not remove open issues.** They are the input for the human Q&A in Phase 8.
- **Do not mark an issue resolved unless you actually updated the docs.** Resolving means: the documentation now correctly covers what was previously missing or wrong.
- **Update `_review.md` as you go.** Do not rely on memory.
