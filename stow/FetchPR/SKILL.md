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

## Hard rules (apply to every workflow)

1. **Never resolve a human reviewer's thread.** They resolve it themselves, once they
   have seen the fix and judged it answers them. Bot threads (`coderabbitai`,
   `github-copilot`, anything `[bot]`) are the only ones you may resolve.
2. **Never post a reply without the principal's approval of the wording.** Draft it,
   show it, wait. It goes out under their name.
3. **Approval to change code is approval to change code.** It does not extend to
   replying or resolving. Neither does an option label you wrote yourself.
4. **Read the spec and plan before judging a comment.** A reviewer's point can be a bug,
   or it can be a fair case for a different decision than the one already taken. Those
   need different conversations, and you cannot tell them apart from the code alone.
   Reviewers are entitled to change the plan; the plan's job is to make the cost of
   changing course visible, not to win the argument.

Full detail in `Workflows/Comments.md`.
