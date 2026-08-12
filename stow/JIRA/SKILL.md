---
name: Jira
description: Jira integration via Atlassian MCP + issue link fallback. USE WHEN jira, ticket, issue, DEV-, sprint, board, backlog, create plan, fetch ticket, ticket details, story points, acceptance criteria.
---

# Jira

Jira integration powered by the official Atlassian Rovo MCP Server. Most operations use the MCP's native tools. Issue linking uses a local CLI fallback until the MCP adds support.

## Architecture

| Operation | Method | Tool |
|-----------|--------|------|
| Get issue | MCP | `getJiraIssue` |
| Search (JQL) | MCP | `searchJiraIssuesUsingJql` |
| Create issue | MCP | `createJiraIssue` |
| Edit issue | MCP | `editJiraIssue` |
| Transition | MCP | `transitionJiraIssue` |
| List transitions | MCP | `getTransitionsForJiraIssue` |
| Add comment | MCP | `addCommentToJiraIssue` |
| Add worklog | MCP | `addWorklogToJiraIssue` |
| List projects | MCP | `getVisibleJiraProjects` |
| Issue types | MCP | `getJiraProjectIssueTypesMetadata` |
| User lookup | MCP | `lookupJiraAccountId` |
| Link issues | MCP | `createIssueLink` |
| Link issues (legacy) | CLI fallback | `bun Jira.ts link` |

## MCP Setup

The Atlassian MCP server is registered via `claude mcp add` (user scope) and managed natively by Claude Code. OAuth 2.1 authentication is handled automatically — on first use, Claude Code opens a browser for authorization. No API tokens or `mcp-remote` proxy required.

Registration (handled by `install.sh`):
```bash
claude mcp add --transport http -s user atlassian https://mcp.atlassian.com/v1/mcp
```

### OAuth Authorization

Claude Code manages OAuth tokens internally. When the server needs authentication, Claude Code will prompt automatically.

**Troubleshooting: MCP tools not available**

If `searchJiraIssuesUsingJql`, `getJiraIssue`, etc. are not appearing as available tools:

1. Check the server is registered: `claude mcp get atlassian`
2. Check server health: `claude mcp list` — look for `atlassian` and its status
3. **If it shows "Needs authentication":** type `/mcp` inside Claude Code, select `atlassian` from the list, and complete the OAuth flow in the browser. This is the most reliable fix as of Claude Code 2.1.x — simply restarting Claude Code may not trigger the OAuth flow due to a known bug.
4. If not registered, add it manually:
   ```bash
   claude mcp add --transport http -s user atlassian https://mcp.atlassian.com/v1/mcp
   ```
5. **Restart Claude Code** after any changes

> **Note:** As of Claude Code 2.1.80+, there is a known issue where HTTP OAuth MCP servers show "Needs authentication" but never automatically trigger the browser OAuth flow on startup. The `/mcp` command is the reliable workaround.

**Migrating from mcp-remote:** If you have a legacy `mcpServers.atlassian` entry in `~/.claude/settings.json` using `mcp-remote`, remove it and re-run `install.sh`. The installer handles cleanup automatically.

## Issue Linking (CLI Fallback)

> **DEPRECATION NOTICE:** The Atlassian MCP now supports `createIssueLink` natively. This CLI fallback can be removed. Prefer the MCP tool for new linking operations.
> Original tracking issue: https://community.atlassian.com/forums/Rovo-questions/MCP-Server-create-edit-work-item-links/qaq-p/3109569

### Configuration

Requires API credentials in `~/.claude/.env` (only needed for linking):
- `JIRA_API_TOKEN` — Atlassian API token
- `JIRA_EMAIL` — Account email

### Token Extraction (CRITICAL)

The JIRA_API_TOKEN contains `=` characters. **NEVER use `cut -d=`** — it truncates the token.

**Always use this pattern:**
```bash
JIRA_API_TOKEN=$(sed -n 's/^JIRA_API_TOKEN=//p' ~/.claude/.env)
JIRA_EMAIL=$(sed -n 's/^JIRA_EMAIL=//p' ~/.claude/.env)
```

### Usage

```bash
bun ~/.claude/skills/JIRA/Tools/Jira.ts link <TICKET_A> <RELATIONSHIP> <TICKET_B>
```

**Relationships:**
`blocks | blocked_by | duplicates | duplicated_by | relates_to | tests | tested_by | split_to | split_from`

**Examples:**
```bash
bun ~/.claude/skills/JIRA/Tools/Jira.ts link DEV-5230 blocked_by DEV-6345
bun ~/.claude/skills/JIRA/Tools/Jira.ts link DEV-6345 blocks DEV-5230
```

## Workflow Routing

| Workflow | Trigger | Description |
|----------|---------|-------------|
| **Fetch** | "fetch ticket", "get DEV-XXXX", "show issue" | Use MCP `getJiraIssue` |
| **Plan** | "create plan for DEV-XXXX", "plan from ticket" | Fetch via MCP + create plan file |
| **Search** | "find tickets", "search jira", "my tickets" | Use MCP `searchJiraIssuesUsingJql` |
| **Sprint** | "current sprint", "sprint board" | Use MCP search with `sprint in openSprints()` JQL |
| **Link** | "link tickets", "DEV-X blocks DEV-Y" | Use CLI fallback `Jira.ts link` |
| **Comment** | "comment on DEV-XXXX", "reply to the reporter", "update the ticket" | Draft in chat, get approval, then MCP `addCommentToJiraIssue`. See Comment Workflow |

## Comment Workflow

Anything written into Jira (comments, descriptions, ticket bodies) must read as though a
person typed it. Tickets in projects like Software Escalations are frequently visible to
the customer, so a comment that reads as machine-generated costs credibility with someone
outside the company.

### Hard rules

- **No em dashes or en dashes.** Never put `—` or `–` in a Jira comment. Use a comma, a
  full stop, a colon, or rewrite the sentence. This is the single biggest tell that text
  was AI-written. Check for it before calling the tool, not after.
- **No emoji prefixes.** The `💭 ❓ 🔧` convention belongs to `ReviewPR` inline diff
  comments, not to tickets. Do not carry it across.
- **No severity labels.** No bold `CRITICAL` or `IMPORTANT` shouting.
- **Minimal structure.** Prefer flowing paragraphs. A short bulleted list is fine for a
  genuine enumeration such as open questions or options, but do not assemble a comment
  out of headings and horizontal rules the way a report is assembled. `contentFormat:
  "markdown"` on `addCommentToJiraIssue` accepts headings, which does not mean a comment
  should have them.

### Voice

Assume the reader knows their own domain better than you do and had good reasons for what
they asked. Write to them as a colleague, not as a system reporting its output.

- **Lead with the answer.** If the finding is "it is not cumulative on this site", say so
  in the first sentence rather than building up to it.
- **Complete sentences with an explicit subject.** "I checked the model and ..." rather
  than "Checked the model and ...". Bare participle openers ("Looking into this ...",
  "Worth noting ...") read as terse and machine-generated.
- **Quote the reporter's own evidence back** where it supports the finding. It shows you
  read what they sent, and it lets them verify the reasoning for themselves.
- **Numbers, not adjectives.** "24 points per day for the whole week" beats "the data
  confirms the pattern".
- **Ask, do not prescribe.** Where a fix carries a tradeoff the reporter should weigh,
  put the choice to them and state the tradeoff plainly.
- **Match their register.** Escalation tickets are usually plainer and more direct than
  internal engineering chat.

### Before posting

- **Draft in the conversation and get approval first.** A comment is outward-facing and
  cannot be quietly withdrawn once watchers have been notified. This holds even when the
  user has asked for a comment: show them the text, then post.
- **Name the judgement calls the draft makes**, such as quoting estate-wide numbers to a
  customer or raising a problem the reporter did not ask about, so that keeping them is
  the user's decision rather than a default.
- **Check who can see it.** Do not quote internal file paths, line numbers, or service
  code names to a non-engineer. Translate to the behaviour they can observe.

### Related guidance

The same voice rules, in more depth and for their own contexts: `Email` skill (Drafting
Style) for prose that must not look AI-written, and `ReviewPR` skill (Tone and Voice in
`Workflows/Review.md`) for the collaborative-teammate framing and worked before/after
examples.

## Plan Workflow

### Plan File Naming Convention (CRITICAL)

**Filename format:** `DEV-{number}-plan.scratch.md`
- Example: `DEV-6156-plan.scratch.md`, `DEV-6158-plan.scratch.md`
- `.scratch.md` extension ensures files are gitignored
- **NEVER** use `PLAN-DEV-` prefix or `.md` without `.scratch`

**Placement rule:** Place the plan in the **parent-most folder in the monorepo** that the ticket refers to.
- If ticket references `data/hasura/metadata` and `data/application-db/migrations` → plan goes in `data/` (the parent-most common folder)
- If ticket references `data/auth-api/src/...` → plan goes in `data/auth-api/`
- **NEVER** place plans in the repo root — always in the relevant sub-project folder
- Monorepo root is `/Users/freddylem/dev/powerx/data/`, sub-projects live under `data/`, `apps/`, `auth-api/`, etc.

### Steps

1. Fetch ticket using MCP `getJiraIssue`
2. Analyze description, acceptance criteria, subtasks
3. Identify which monorepo folders the ticket references
4. Determine the parent-most relevant folder
5. Create `DEV-{number}-plan.scratch.md` in that folder with:
   - Summary of the ticket
   - Technical approach
   - Step-by-step implementation plan
   - Files likely to be modified
   - Testing considerations
   - `branch: DEV-{number}-{jira-slugified-title}` line at the top
     (Fred can replace with exact Jira branch name from "Copy branch name" in Jira UI)

**Branch line format (always include at top of plan file):**
```markdown
branch: DEV-6182-travel-backend-add-missing-user-fields
```
This is read by `/Worktree DEV-XXXX` to use the correct branch name.
If Fred has copied the exact branch name from Jira → paste it here to override the auto-generated slug.
