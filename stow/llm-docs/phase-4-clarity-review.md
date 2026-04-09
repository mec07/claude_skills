# Phase 4: Evaluate LLM Documentation from an Agent's Perspective

You are a senior developer who has **never seen this codebase before.** You have just been dropped into this repo and asked to start working on it. Your only guide is the documentation under `docs/llm/`, `CLAUDE.md`, `.github/copilot-instructions.md`, and any local context files.

Read every documentation file. Then evaluate it honestly from the perspective of someone who needs to use these docs to do real work.

---

## Working file

**Create `docs/llm/_review.md` at the start of this phase.** This is your scratchpad. Write to it as you go — do not rely on memory.

Every time you find an issue, log it to `_review.md` immediately in this format:

```markdown
## Issues

### [area/module name] — [short description]
- **Type:** gap | ambiguity | dead-end | contradiction | navigation | missing-connection
- **Found in:** `path/to/doc.md`
- **Detail:** what's wrong or missing
- **Question for maintainer:** specific question to resolve this
- **Status:** open
```

Update the status to `resolved` as issues are addressed. This file is your source of truth for what you've found — not your memory.

At the end, also add a summary section to `_review.md`:

```markdown
## Summary
- Total issues found: N
- Open: N
- Resolved: N
- Questions for maintainer: N
```

---

## Step 1: Read everything

Read all of the following files **that exist**, in this order:
1. `CLAUDE.md`
2. `docs/llm/overview.md`
3. `docs/llm/architecture.md`
4. Every file in `docs/llm/modules/`
5. `docs/llm/dependency-map.md`
6. `docs/llm/conventions.md`
7. `docs/llm/workflows.md`
8. `docs/llm/scripts.md`
9. `docs/llm/gotchas.md`
10. `docs/llm/glossary.md`
11. `.github/copilot-instructions.md`
12. `docs/README.md`
13. Any local context files (`README.md` or `CLAUDE.md` in subdirectories, including script directory READMEs)

If a file in this list does not exist, log it as a gap in `_review.md` (type: `gap`, detail: "expected file missing").

**Log issues to `_review.md` as you encounter them.** Do not wait until you've finished reading to start recording.

---

## Step 2: Simulate real tasks

After reading all the docs, simulate realistic scenarios that match this repo's actual architecture. The goal is to test whether the documentation gives you an unbroken path through cross-component work.

**Choose 4 scenarios from or inspired by the list below. Adapt them to the repo's actual architecture** — a CLI tool, a library, an infrastructure repo, and a web app all have different "cross-cutting" work. The principle is always the same: test whether the docs guide you across component boundaries.

**Scenario A: Cross-cutting change**
You've been asked to add a new data field, configuration option, or capability that must propagate through multiple layers of the system. Trace the path: where do you add it at the source? How does it propagate through intermediate layers? Where does it surface to consumers? Do the docs give you a clear, unbroken path? Where do they leave you guessing?

**Scenario B: Debugging a boundary**
Something is broken at the boundary between two components — data is written correctly in one place but read incorrectly in another, or a message is sent but not handled as expected. Do the docs tell you where to look? Can you identify all the communication paths and data contracts involved? Where do the docs leave you uncertain about how the components interact?

**Scenario C: Modifying a single module**
Pick the module doc that seems most complex. After reading it, do you know: what files to edit, what other modules might be affected, what data structures are involved, how to test your change, and what gotchas to watch for? What's missing?

**Scenario D: Onboarding**
You need to get the project running locally, understand the overall architecture, and orient yourself. Do the docs give you a clear path from zero to productive? Where do you get lost?

**Scenario E: Adding a test**
You need to write a test for an existing feature. Can you find where tests live, what framework is used, what patterns to follow, and how to run tests? Do the conventions docs help?

**Scenario F: Understanding a failure**
A CI build or deployment failed. Can you find the CI/CD configuration, understand the pipeline, and trace the failure to a specific step? Do the workflows and architecture docs cover this path?

**Scenario G: Writing or running a script**
You need to perform a one-off operation (data backfill, batch update, repair). Can you find whether a script for this already exists? If one exists, can you determine how to run it (credentials, env vars, arguments)? If you need a new script, can you determine where to put it, what patterns to follow, and what shared utilities are available? Does the decision table in `scripts.md` guide you to the right location? Do the script directory READMEs give you enough to get started?

For each scenario, trace your path through the documentation and **log every point where you get stuck or uncertain** to `_review.md`.

---

## Step 3: Review your findings

Open `_review.md` and read through everything you logged. Look for:
- **Patterns** — are multiple issues pointing to the same underlying problem?
- **Priorities** — which issues would block an agent most severely?
- **Clusters** — are certain areas of the codebase consistently under-documented?

Add a section to `_review.md`:

```markdown
## Patterns
- [any recurring themes across issues]

## Highest priority gaps
1. [the issues that would most severely block an agent trying to work in this repo]
2. ...
3. ...
```

---

## Step 4: Attempt quick fixes

Before passing issues to Phase 5, resolve any that you can answer immediately from the docs or obvious code inspection. For example:
- A cross-link points to the wrong file but the correct file is obvious → fix it
- A navigation gap exists but the information is actually in another doc → add the link

For each issue you fix, update its status in `_review.md` to `resolved` and note what you did.

Do not spend significant time on this. Issues that require reading source code in depth should remain `open` for Phase 5.

---

## Step 5: Present summary

Report to the orchestrator:
- Total issues found
- How many you resolved in Step 4
- How many remain open
- The highest priority gaps (the ones that would block agents most)
