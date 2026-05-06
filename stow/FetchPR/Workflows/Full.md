# FetchPR — Full

Comprehensive PR context fetch. Use when the user wants a complete picture: "brief me on PR 5315", "show me everything about this PR", "what's the state of #N", or any general PR-context request.

## Invocation

```bash
~/.claude/skills/FetchPR/Tools/fetch.sh [args]
```

(or the source path `~/src/github.com/mec07/claude_skills/stow/FetchPR/Tools/fetch.sh`)

### Defaults

- **PR number**: from current branch via `gh pr list --head <branch>`. Pass `--pr N` to override.
- **Repo**: from `git remote.origin.url`. Pass `--repo OWNER/NAME` to override.
- **Comment scope**: unresolved threads only. Pass `--all` to include resolved.
- **Output**: human-readable. Pass `--json` for piping.
- **Verbosity**: full. Pass `--brief` to skip body, files, commits, and issue comments.

## Sections in the output

1. **Header** — title, URL, state, draft flag, branches, author, dates, labels, milestone, linked issues, diff stats, mergeable, mergeStateStatus, reviewDecision.
2. **CI checks** — pass/fail/pending counts, plus name + URL for each failing check.
3. **Reviewer states** — `Requested reviewers:` (still pending) and `Latest reviews:` (one per author with their final state).
4. **Description** — PR body (skipped under `--brief`).
5. **Files changed** — path with `+adds/-deletes` per file (skipped under `--brief`).
6. **Commits** — short SHA + headline (skipped under `--brief`).
7. **Issue-level comments** — general PR chatter (skipped under `--brief`).
8. **Review-level summaries** — full body of each review (CodeRabbit nitpick sections, human reviewer summaries).
9. **Inline thread comments** — line-anchored discussion with `[RESOLVED]` / `[OUTDATED]` flags.

## Closed/merged PRs — early exit

If the PR is not OPEN, the script exits with code 3 after printing the title + URL. Do not chase successor PRs from comment chatter — the convention isn't reliable. **Tell the user the PR is closed and ask for the new PR number.**

## When briefing the user

- Lead with what's actionable: failing checks, unresolved review comments, "REVIEW_REQUIRED" decision.
- Always quote `path:line` from the output verbatim — don't paraphrase locations.
- `[OUTDATED]` on a thread means the diff has moved since the comment was made — open the file at the cited line before recommending action; the comment may reference code that no longer exists.
- `mergeStateStatus: BLOCKED` with `mergeable: MERGEABLE` usually means waiting on reviewers, not a conflict. Look at `reviewDecision` and `Requested reviewers:` to know who.
- For long outputs, consider piping through `--brief` for quick status checks.
