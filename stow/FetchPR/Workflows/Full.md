# FetchPR — Full

Comprehensive PR/MR context fetch for GitHub and GitLab. Use when the user wants a complete picture: "brief me on PR 5315", "show me everything about this MR", "what's the state of #N", or any general PR/MR-context request.

**First:** follow [Reference/HostAndAuth.md](../Reference/HostAndAuth.md). If only GitLab MCP is authed, fetch the same sections via MCP instead of this script.

## Invocation

```bash
~/.claude/skills/FetchPR/Tools/fetch.sh [args]
```

(or the source path under `stow/FetchPR/Tools/fetch.sh`)

### Defaults

- **Forge**: detected from `git remote.origin.url` (GitHub → `gh`, GitLab → `glab`).
- **PR/MR number**: from current branch (`gh pr list` or GitLab MRs by `source_branch`). Pass `--pr N` to override (GitLab IID).
- **Repo**: from remote. Pass `--repo OWNER/NAME` or `group/subgroup/project` to override.
- **Comment scope**: unresolved threads only. Pass `--all` to include resolved.
- **Output**: human-readable. Pass `--json` for piping. JSON includes `pr.forge` (`github`|`gitlab`); GitLab also includes `pr.diff_refs` and `pr.iid`.
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

## Closed/merged PRs/MRs — early exit

If the PR/MR is not OPEN, the script exits with code 3 after printing the title + URL. Do not chase successors from comment chatter — the convention isn't reliable. **Tell the user it is closed/merged and ask for the new number/IID.**

## When briefing the user

- Lead with what's actionable: failing checks, unresolved review comments, "REVIEW_REQUIRED" decision.
- Always quote `path:line` from the output verbatim — don't paraphrase locations.
- `[OUTDATED]` on a thread means the diff has moved since the comment was made — open the file at the cited line before recommending action; the comment may reference code that no longer exists.
- `mergeStateStatus: BLOCKED` with `mergeable: MERGEABLE` usually means waiting on reviewers, not a conflict. Look at `reviewDecision` and `Requested reviewers:` to know who.
- For long outputs, consider piping through `--brief` for quick status checks.
