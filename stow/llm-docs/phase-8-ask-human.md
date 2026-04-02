# Phase 8: Ask Human

The pipeline has completed all automated phases. `docs/llm/_review.md` contains any remaining issues that could not be resolved from source code alone. Your job is to present these to the user, get answers, and make final documentation updates.

---

## Pre-check

Open `docs/llm/_review.md`. Check for issues with status `open` or `partial — needs human input`.

If there are **no open or partial issues**: inform the user that the documentation pipeline is complete with no outstanding questions. Provide the final summary from `_review.md` and `_audit.md`, then delete the working files (`docs/llm/_original_documentation.md`, `docs/llm/_audit.md`, `docs/llm/_review.md`). You're done.

If there **are open or partial issues**: proceed below.

---

## Presenting questions

Read all open and partial issues from `_review.md`. Group them by area of the codebase, not by document.

Present them to the user in this format:

**"The docs [say X / don't cover Y]. I checked [source files] but couldn't determine [Z]. This matters because [an agent trying to do W would get stuck here]. Can you clarify?"**

Prioritise:
1. Issues that would block an agent from doing common tasks
2. Issues about inter-component communication or data flow
3. Issues about data structure relationships
4. Everything else

Be concise. The user's time is valuable. Don't over-explain what you already tried — focus on what you need from them.

---

## After receiving answers

For each answer the user provides:

1. Update the relevant documentation file(s) with the new information
2. Verify that the update is consistent with the rest of the docs
3. Update `_review.md`: change the issue status to `resolved` and record the resolution
4. If the user explicitly defers an issue ("not important", "won't fix", "skip it"), change its status to `deferred` in `_review.md`
5. If the answer reveals something that contradicts existing docs, fix the contradiction

After all answers are incorporated, update the final summary in `_review.md`.

---

## Completion

When all issues are resolved (or explicitly deferred by the user):

1. Present a final summary to the user:
   - Final tally from `_audit.md`
   - Final tally from `_review.md`
   - Any remaining `<!-- TODO: verify -->` markers in the docs and why they couldn't be resolved
   - A brief statement of overall confidence in the documentation accuracy

2. **Clean up working files.** Delete these temporary files — they were used for state passing between phases and are no longer needed:
   - `docs/llm/_original_documentation.md`
   - `docs/llm/_audit.md`
   - `docs/llm/_review.md`
