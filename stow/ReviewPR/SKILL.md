---
name: ReviewPR
description: Thorough PR review — fetches diff, analyzes changes, creates a PENDING GitHub review with inline comments on the actual diff lines. User reviews comments in GitHub UI, edits as needed, then submits themselves. USE WHEN review PR, review pull request, PR review, check PR, analyze PR, look at PR.
---

## Customization

**Before executing, check for user customizations at:**
`~/.claude/PAI/USER/SKILLCUSTOMIZATIONS/ReviewPR/`

If this directory exists, load and apply any PREFERENCES.md, configurations, or resources found there. These override default behavior. If the directory does not exist, proceed with skill defaults.

## MANDATORY: Voice Notification (REQUIRED BEFORE ANY ACTION)

**You MUST send this notification BEFORE doing anything else when this skill is invoked.**

1. **Send voice notification**:
   ```bash
   curl -s -X POST http://localhost:8888/notify \
     -H "Content-Type: application/json" \
     -d '{"message": "Running the ReviewPR workflow to review pull request"}' \
     > /dev/null 2>&1 &
   ```

2. **Output text notification**:
   ```
   Running the **Review** workflow in the **ReviewPR** skill...
   ```

# ReviewPR

Comprehensive pull request review that creates a **pending GitHub review with inline comments** on the actual diff lines. The user controls submission — this skill creates the review in PENDING state so the user can:

1. Go to the PR in GitHub
2. See inline comments in context on the diff
3. Edit, delete, or add to the comments
4. Submit the review when satisfied

## How It Works

1. Fetches PR diff and project CLAUDE.md files for context
2. Analyses changes using parallel specialist agents for large PRs (bug hunter, guidelines checker, security reviewer, git history checker)
3. Scores every finding on 0-100 confidence scale — only surfaces issues with confidence >= 80
4. Creates a `PENDING` review via GitHub API with inline comments on specific diff lines
5. Pending reviews are **only visible to the review author** until submitted

## Key Design Decisions

- **Collaborative tone** — comments read like spoken English from a teammate, not a report. No headings, no bold severity labels, no em dashes. Questions and suggestions, never demands.
- **Emoji intent signals** — each comment starts with an emoji (💭 ❓ 👍 🔧 ⛏️ etc.) per the code review emoji guide convention, so the author instantly knows the intent.
- **Confidence scoring** filters noise — no pedantic nits, no false positives, no pre-existing issues
- **CLAUDE.md awareness** — checks changes against project-specific rules, not just generic quality
- **Positive framing** — acknowledges what's well done generously. If something looks wrong, asks questions to understand the author's reasoning first.
- **GitHub permalinks** — links use full SHA for permanent references

## Workflow Routing

| Workflow | Trigger | File |
|----------|---------|------|
| **Review** | "review PR", PR number, "check this PR" | `Workflows/Review.md` |

## Examples

**Example 1: Review a PR by number**
```
User: "/ReviewPR 5001"
-> Detects repo from git remote
-> Fetches PR metadata and diff
-> Analyzes all changes (parallel agents for large PRs)
-> Creates PENDING review with inline comments on diff lines
-> Shows summary in conversation
-> User goes to GitHub to review, edit, and submit
```

**Example 2: Review current branch's PR**
```
User: "/ReviewPR"
-> Detects current branch, finds associated PR
-> Same analysis and pending review flow
```

**Example 3: Review with context**
```
User: "/ReviewPR 42 — this is a database migration"
-> Uses context to focus analysis on migration safety
-> Inline comments prioritize data integrity, rollback, schema issues
```
