---
name: FetchPR
description: Read-only GitHub PR fetch — metadata, mergeability, CI checks, reviewer states, files, commits, description, issue chatter, review comments (with resolved/outdated state), and full diff content. Resolves PR by current branch when no number is given. Companion to ReviewPR (which writes pending reviews). USE WHEN brief me on pr, fetch pr, pull pr details, get pr feedback, what did <reviewer> say, see pr status, show me pr diff, what changed in pr, pr file diff.
---

# FetchPR

Read-only PR context fetch. `ReviewPR` is the WRITE companion that creates pending reviews.

## Workflow Routing

| Trigger | Workflow |
|---------|----------|
| "brief me on PR", "fetch PR details", "what's the state of PR", "show me everything" | `Workflows/Full.md` |
| "what did <reviewer> say", "pull review comments", "any unresolved threads", "fetch coderabbit comments" | `Workflows/Comments.md` |
| "show me the diff", "what changed in PR", "diff file X", "list changed files" | `Workflows/Diff.md` |
