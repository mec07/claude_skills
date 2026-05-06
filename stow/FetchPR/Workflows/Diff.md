# FetchPR — Diff

Fetch the actual diff content of a PR. Use when the user asks "show me the diff", "what changed in PR", "diff just file X", "list the changed files".

## Invocation

```bash
~/.claude/skills/FetchPR/Tools/diff.sh [args]
```

(or the source path `~/src/github.com/mec07/claude_skills/stow/FetchPR/Tools/diff.sh`)

### Common patterns

```bash
# Full unified diff for current branch's PR
diff.sh

# Just the changed file paths
diff.sh --names-only

# Limit to specific files (glob)
diff.sh --files 'lionfish2/lionfish2/derived_time_series/tenant/*'

# Save to a file (avoids dumping a huge diff into context)
diff.sh --save /tmp/pr-5315.patch

# Explicit PR
diff.sh --pr 5315

# Combine
diff.sh --pr 5315 --files '*.py' --save /tmp/py-only.patch
```

### All flags

| Flag | Default | Meaning |
|------|---------|---------|
| `--pr N` | from current branch | Explicit PR number |
| `--repo OWNER/NAME` | from `git remote.origin.url` | Override repo |
| `--names-only` | full diff | Print only changed file paths |
| `--files PATTERN` | all files | Limit diff to files matching glob (uses `filterdiff` if installed, awk fallback otherwise) |
| `--save PATH` | stdout | Write diff to file, print path |

## Closed/merged PRs — early exit

Same behavior as `Tools/fetch.sh`: if state ≠ open, print state + URL, exit 3. Tell the user and ask for the new PR number.

## When to use this workflow vs alternatives

| Task | Tool |
|------|------|
| "What files changed?" | `diff.sh --names-only` (or `Workflows/Full.md` which lists files with stats) |
| "Show me the diff" | `diff.sh` (large PRs: pipe through `--save` first) |
| "What did file X change?" | `diff.sh --files 'X'` |
| "Review this PR with comments" | `ReviewPR` skill (this skill is read-only) |
| "Critique the changes" | Combine — `diff.sh --save /tmp/x.patch` then feed into `CodeReview` |

## Context-management note

Full diffs can be hundreds of KB. **Default to `--save`** when:
- The PR has > ~30 changed files, OR
- The user wants you to analyze the diff (don't dump it; read sections from the saved file).

Use stdout when the user explicitly asks to "see" the diff and you've checked the size is reasonable.

## Combining with the Full workflow

If you've already run `Tools/fetch.sh` (or the Full workflow), the file list with `+adds/-deletes` per file is already in that output. Use that to pick which files to deep-dive on with `--files`. Don't fetch the full diff just to learn what files changed.
