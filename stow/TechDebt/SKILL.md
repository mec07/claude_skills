---
name: TechDebt
description: Create tech debt tickets in Jira without breaking flow. USE WHEN tech debt, technical debt, /TechDebt, found a code smell, should fix later, out of scope issue, quick ticket, log debt.
---

# TechDebt

Create a well-formed Jira tech debt ticket from a quick description, with duplicate detection, without leaving your flow.

## Configuration

```
Jira project:     DEV
Tech Debt Board:  361  (🤖 Tech Debt Board)
Board URL:        https://powerx.atlassian.net/jira/software/c/projects/DEV/boards/361
Issue type:       Story (ID: 10022)
Priority:         Lowest (ID: 5)
Assignee:         Fred (712020:4b8d9734-1d88-42e4-a553-37ebedd98c6f)
Parent epic:      DEV-5478  (Work Order Management - Tech Debt)
```

## Auth

```bash
JIRA_API_TOKEN=$(sed -n 's/^JIRA_API_TOKEN=//p' ~/.claude/.env)
JIRA_EMAIL=$(sed -n 's/^JIRA_EMAIL=//p' ~/.claude/.env)
```

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
