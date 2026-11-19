# ReviewPR — Design Decisions

Load when writing or editing review comments. The entrypoint `SKILL.md` only summarises these.

## How it works (pipeline)

1. Resolves host + auth (`gh` / `glab` / GitLab MCP) — see [HostAndAuth.md](HostAndAuth.md)
2. Fetches PR/MR diff and project CLAUDE.md files for context (via FetchPR or MCP)
3. Analyses changes using parallel specialist agents for large changes (bug hunter, guidelines checker, security reviewer, git history checker)
4. Scores every finding on a 0–100 confidence scale — only surfaces issues with confidence >= 80
5. Creates a pending/draft review with inline comments on specific diff lines (or conversation fallback)
6. Pending/draft comments are **only visible to the review author** until submitted/published

## Principles

- **Collaborative tone** — comments read like spoken English from a teammate, not a report. No headings, no bold severity labels, no em dashes. Questions and suggestions, never demands.
- **Short** — two or three sentences per comment, one is often enough. Investigation is exhaustive; the comment reporting it is not. Long comments are the failure mode this skill guards against hardest.
- **Emoji intent signals** — each comment starts with an emoji (💭 ❓ 👍 🔧 ⛏️ etc.) per the code review emoji guide convention, so the author instantly knows the intent.
- **Confidence scoring** filters noise — no pedantic nits, no false positives, no pre-existing issues
- **CLAUDE.md awareness** — checks changes against project-specific rules, not just generic quality
- **Positive framing** — acknowledges what's well done generously. If something looks wrong, asks questions to understand the author's reasoning first.
- **Forge permalinks** — links use full SHA for permanent references (GitHub or GitLab)
- **Never auto-publish** — drafts only; conversation fallback if drafts cannot be opened ([ConversationFallback.md](ConversationFallback.md))
- **Inline only on the forge** — no overarching PR/MR summary comment (empty GitHub review `body`; no GitLab draft without `--file`/`--line`). Chat gets the short pointer summary.

Tone, emoji, and comment-shape detail for inline bodies lives in `Workflows/Review.md` (Step 8).
