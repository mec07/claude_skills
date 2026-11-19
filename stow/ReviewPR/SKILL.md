---
name: ReviewPR
description: Thorough PR/MR review — fetches diff, analyzes changes, creates a pending GitHub review or GitLab draft notes with inline comments on the actual diff lines. User reviews comments in the forge UI, edits as needed, then submits/publishes themselves. Falls back to a structured in-chat comment layout when drafts cannot be opened. USE WHEN review PR, review pull request, review MR, review merge request, PR review, MR review, check PR, analyze PR, look at PR.
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

Comprehensive pull request / merge request review that stages **pending inline comments** on the actual diff lines. The user controls submission:

| Forge | Pending mechanism | User finishes in |
|-------|-------------------|------------------|
| **GitHub** | `PENDING` review via `gh api` (omit `event`) | GitHub PR UI — edit, then submit |
| **GitLab** | Draft Notes via `glab mr note draft create` (or Draft Notes REST via `glab api`) | GitLab MR UI — edit, then publish |
| **Drafts unavailable** | Structured chat layout | [Reference/ConversationFallback.md](Reference/ConversationFallback.md) |

GitLab **does** support pending reviews (Draft Notes). Official GitLab MCP review tools currently **publish** notes — never use them as a substitute for drafts. See [Reference/HostAndAuth.md](Reference/HostAndAuth.md).

"PR" and "MR" are synonyms in triggers and docs.

## How It Works

1. Resolves host + auth (`gh` / `glab` / GitLab MCP) — see HostAndAuth
2. Fetches PR/MR diff and project CLAUDE.md files for context (via FetchPR or MCP)
3. Analyses changes using parallel specialist agents for large changes (bug hunter, guidelines checker, security reviewer, git history checker)
4. Scores every finding on 0-100 confidence scale — only surfaces issues with confidence >= 80
5. Creates a pending/draft review with inline comments on specific diff lines (or conversation fallback)
6. Pending/draft comments are **only visible to the review author** until submitted/published

## Key Design Decisions

- **Collaborative tone** — comments read like spoken English from a teammate, not a report. No headings, no bold severity labels, no em dashes. Questions and suggestions, never demands.
- **Short** — two or three sentences per comment, one is often enough. Investigation is exhaustive; the comment reporting it is not. Long comments are the failure mode this skill guards against hardest.
- **Emoji intent signals** — each comment starts with an emoji (💭 ❓ 👍 🔧 ⛏️ etc.) per the code review emoji guide convention, so the author instantly knows the intent.
- **Confidence scoring** filters noise — no pedantic nits, no false positives, no pre-existing issues
- **CLAUDE.md awareness** — checks changes against project-specific rules, not just generic quality
- **Positive framing** — acknowledges what's well done generously. If something looks wrong, asks questions to understand the author's reasoning first.
- **Forge permalinks** — links use full SHA for permanent references (GitHub or GitLab)
- **Never auto-publish** — drafts only; conversation fallback if drafts cannot be opened

## Companion Skills

ReviewPR is the **write** side of PR/MR work — it produces a pending/draft review. For **read-only** context, use the `FetchPR` skill:

| Need | Skill | Why |
|------|-------|-----|
| Brief me on a PR/MR / pull metadata, CI, reviewer states | `FetchPR` (Full workflow) | Read-only, fast |
| Pull existing review comments / "what did X say" | `FetchPR` (Comments workflow) | Surfaces resolved/outdated state, splits inline threads vs review summaries |
| Fetch the diff (especially large ones) | `FetchPR` (Diff workflow) | `--save` flag avoids dumping huge diffs into context |
| Critique code without posting to the forge | `CodeReview` | Writes findings into the conversation, not the PR/MR |
| Post a pending/draft review with inline comments | `ReviewPR` (this skill) | Creates forge-side pending review or chat fallback |

The Review workflow below uses `FetchPR`'s tools internally for fetching data when the CLI is authed — see Steps 0–3 in `Workflows/Review.md`.

## Workflow Routing

| Workflow | Trigger | File |
|----------|---------|------|
| **Review** | "review PR", "review MR", PR/MR number, "check this PR" | `Workflows/Review.md` |

## Examples

**Example 1: Review a PR/MR by number**
```
User: "/ReviewPR 5001"
-> Detects forge + repo from git remote; probes auth
-> Fetches metadata and diff (FetchPR / glab / MCP)
-> Analyzes all changes (parallel agents for large changes)
-> Creates PENDING review (GitHub) or draft notes (GitLab)
-> Shows summary in conversation
-> User goes to GitHub/GitLab to review, edit, and submit/publish
```

**Example 2: Review current branch's PR/MR**
```
User: "/ReviewPR"
-> Detects current branch, finds associated PR/MR
-> Same analysis and pending/draft flow
```

**Example 3: Review with context**
```
User: "/ReviewPR 42 — this is a database migration"
-> Uses context to focus analysis on migration safety
-> Inline comments prioritize data integrity, rollback, schema issues
```

**Example 4: GitLab without working drafts**
```
User: "/ReviewPR 88" on a GitLab remote where glab drafts fail
-> Completes analysis
-> Cannot stage draft notes
-> Lays out every comment in chat (filename, line, ±2 context, body, separators)
-> Does NOT publish notes via MCP as a workaround
```
