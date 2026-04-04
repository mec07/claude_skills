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
| **Link issues** | **CLI fallback** | `bun Jira.ts link` |

## MCP Setup

The Atlassian MCP server is configured automatically by `install.sh`. It uses OAuth 2.1 — on first use a browser window opens for authorization. No API tokens required for MCP operations.

Configuration in `~/.claude/settings.json`:
```json
{
  "mcpServers": {
    "atlassian": {
      "command": "npx",
      "args": ["-y", "mcp-remote@latest", "https://mcp.atlassian.com/v1/mcp"]
    }
  }
}
```

## Issue Linking (CLI Fallback)

> **DEPRECATION NOTICE:** This fallback exists because the Atlassian MCP does not yet support issue linking.
> Remove `Jira.ts` once the MCP adds a `createIssueLink` or equivalent tool.
> Track: https://community.atlassian.com/forums/Rovo-questions/MCP-Server-create-edit-work-item-links/qaq-p/3109569

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
