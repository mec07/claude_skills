# FetchPR — Comments

Focused on review feedback. Use when the user asks "what did <reviewer> say", "pull the review comments", "any unresolved threads", "fetch CodeRabbit's nitpicks", etc.

## Why a separate workflow

Three distinct GitHub surfaces hold review feedback, and missing any one leads to wrong answers:

1. **`pulls/{n}/reviews`** — review-level summary bodies. CodeRabbit's "Nitpick comments" sections live here as a single body, NOT as inline threads. Easy to miss.
2. **`reviewThreads` (GraphQL)** — inline line-anchored comments WITH `isResolved` / `isOutdated`. The REST `pulls/{n}/comments` endpoint gives bodies but not thread state.
3. **`issues/{n}/comments`** — general PR chatter (status updates, side discussion). Rarely contains review feedback but worth fetching when scoping author activity.

The script pulls all three.

## Invocation

```bash
# All unresolved threads on the PR for current branch
~/.claude/skills/FetchPR/Tools/fetch.sh

# Filter to one reviewer (recommended for "what did X say")
~/.claude/skills/FetchPR/Tools/fetch.sh --author cfettes

# Include resolved threads (audit pass)
~/.claude/skills/FetchPR/Tools/fetch.sh --all --author cfettes

# JSON for chaining
~/.claude/skills/FetchPR/Tools/fetch.sh --json --author cfettes \
    | jq '.threads[] | {path, line, body}'
```

## Author filter notes

- Bots use different names per surface: `coderabbitai[bot]` (REST) vs `coderabbitai` (GraphQL). The script does literal-match per surface — pass whichever name the user said and accept that one form may match while the other doesn't. If a bot returns 0 hits, retry with the other suffix.
- Filter applies to all three surfaces (issue comments, review summaries, inline threads).

## Resolved / outdated state

- **Default scope is unresolved threads only.** Resolved threads are hidden unless `--all`.
- `[OUTDATED]` flag means the diff line the comment anchored to has shifted. The comment may reference code that no longer exists.
- Review-level summaries don't have a thread state and are always shown.

## When presenting comments to the user

- Group by surface. Lead with inline threads (most actionable), then review summaries (the long ones).
- Quote `path:line` verbatim. The line numbers are load-bearing for navigation.
- For each comment, give: author, location, severity tier (if the body has one — CodeRabbit uses 🔴/🟠/🟡; humans don't), and your assessment.
- For each comment, write an explicit **action plan** + **justification** before the user reads them. Don't just dump the comment text and ask the user.

## Closed/merged PRs

The script exits 3 with title + URL. Tell the user and ask for the new PR number — don't chase successor PRs from comment chatter.

## Verification before recommending a fix

- Read the cited file at the cited line. Comments age; the code may have changed.
- For `[OUTDATED]` comments, treat them as historical context unless the user says otherwise.
- For comments suggesting "use existing helper X", read X yourself and verify it does what the reviewer claims before recommending the swap.
