---
name: TechDebt
description: Create tech debt tickets in Jira without breaking flow. USE WHEN tech debt, technical debt, /TechDebt, found a code smell, should fix later, out of scope issue, quick ticket, log debt.
---

# TechDebt

Create a well-formed Jira tech debt ticket from a quick description, with duplicate detection, without leaving your flow.

## Configuration

Which project, board and epic tech debt belongs in is a property of your team's
Jira, so it comes from you rather than from this file:

`~/.claude/techdebt/config.json` — shape, defaults and the first-run flow are in
`Reference/Setup.md`. When the file is missing, the skill asks and writes it.

Everything else is derived at runtime — the Jira site, your account, and the
issue-type and priority ids for the configured project. No site URL, account id
or token appears in this skill.

## Auth

Jira is reached through the Atlassian MCP, which owns the credentials. The MCP
resolves the site with `getAccessibleAtlassianResources` and the current user
with `atlassianUserInfo`; this skill never reads a token.

## Trigger

```
/TechDebt <description of the issue>
/TechDebt   ← will prompt for description
```

## Workflow Routing

| Workflow | Trigger | File |
|----------|---------|------|
| **Create** | Any `/TechDebt` invocation | `Workflows/Create.md` |

## Examples

```
/TechDebt the UsersTable in PX portal duplicates logic from SP portal — should use the shared generic UsersTable from packages/ui

/TechDebt work_orders service has no integration tests for the dispatch endpoint — added ad-hoc, needs proper test coverage
```
