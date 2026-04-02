# Phase 5: Self-Resolve

The clarity review (phase 4) produced `docs/llm/_review.md` containing issues, gaps, ambiguities, and questions. Your job is to resolve as many of these as possible **from the source code alone**, without asking the user.

---

## Working file

Use `docs/llm/_review.md` as your ledger. Update it as you work.

---

## Process

### Step 1: Read all open issues

Open `docs/llm/_review.md`. Read every issue with status `open`.

### Step 2: Attempt to resolve each issue from source code

For each open issue, ask: **"Can I answer this question by reading the actual code?"**

- If **yes**: read the relevant source files, find the answer, update the documentation, and change the issue status to `resolved`. Record what you found and what you changed.
- If **partially**: update the docs with what you can verify, mark the remaining uncertainty with `<!-- TODO: verify -->`, change the status to `partial — needs human input`, and note what specifically you still need answered.
- If **no**: leave the status as `open`. These will go to the user in phase 8.

### Step 3: For each resolved issue, update the docs

When you resolve an issue:
1. Fix the documentation file(s) involved
2. Verify your fix follows the same rules as all other phases — no hallucination, evidence only
3. Update `_review.md` with:
   - Status: `resolved`
   - Resolution: what you found and what you changed
   - Evidence: which source file(s) you read

### Step 4: Look for new issues

Resolving one issue sometimes reveals another. If fixing a gap exposes a new ambiguity or missing connection, log it as a new issue in `_review.md`. Then attempt to resolve it in the same pass.

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

---

## Rules

- **Same evidence standards as all other phases.** Do not resolve an issue by guessing. If you can't find the answer in the source code, leave it open.
- **Do not remove open issues.** They are the input for the human Q&A in phase 8.
- **Do not mark an issue resolved unless you actually updated the docs.** Resolving means: the documentation now correctly covers what was previously missing or wrong.
- **Update `_review.md` as you go.** Do not rely on memory.
