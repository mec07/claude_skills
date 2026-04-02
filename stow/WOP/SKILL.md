---
name: WOP
description: Work in Progress sync — updates ticket statuses, PR states, and the WIP Obsidian page from live Jira/GitHub data. USE WHEN wop, work in progress, update wip, sync tickets, what's the state of things, check my PRs, stale tickets.
---

# WOP (Work in Progress)

Status sync skill. Answers "what's the current state of things?" by pulling live data from Jira and GitHub, identifying staleness and mismatches, and updating the Work In Progress Obsidian page.

## Trigger

- `/wop` — explicit invocation
- "update wip", "sync my tickets", "what's the state of things"
- "check my PRs", "stale tickets"

## Configuration

```
Repo:          $HOME/dev/powerx/data
GitHub org:    powerxai/data
Jira tool:     ~/.claude/skills/JIRA/Tools/Jira.ts
WIP page:      {VAULT}/PAI/PAI Work In Progress.md
Open Loops:    ~/.claude/skills/PAI/USER/OPEN_LOOPS.md
Vault base:    $HOME/Library/CloudStorage/GoogleDrive-fredlemi@gmail.com/My Drive/Obsidian/Obsidian Vault
```

## Workflow Routing

| Workflow | Trigger | File |
|----------|---------|------|
| **Sync** | `/wop`, "update wip", "sync tickets" | `Workflows/Sync.md` |

## What It Checks

### Jira
- All assigned tickets: current status, sprint, last updated
- **Staleness detection:** ticket "In Development" but no commits/PR activity in 3+ days
- **Status mismatches:** Jira says "New" but PR already exists (should be "Code Review")
- **Sprint alignment:** tickets assigned but not in active sprint

### GitHub
- Open PRs: review status (approved/changes requested/pending), CI status, merge conflicts
- Draft PRs: should any be promoted to ready?
- PRs with no activity in 3+ days
- Reviews requested from Fred that haven't been done

### Open Loops (work-related only)
- Scan OPEN_LOOPS.md for work-related items that might be stale

## Output

1. **Terminal display:** Summary of state with flags for anything needing attention
2. **WIP page update:** Rewrites the relevant sections of `PAI Work In Progress.md` with current data
3. **Suggested actions:** "These 3 tickets need status updates in Jira", "This PR has been waiting for review 5 days"

## Staleness Rules

| Condition | Flag |
|-----------|------|
| Ticket "In Development" + no commits in 3 days | ⚠️ Stale |
| PR open + no review activity in 3 days | ⚠️ Needs chase |
| PR with failing CI | 🔴 CI broken |
| PR with merge conflicts | 🔴 Conflicts |
| Ticket "New" but PR exists | ⚠️ Status mismatch |
| Ticket in sprint but no activity all sprint | ⚠️ Sprint risk |
