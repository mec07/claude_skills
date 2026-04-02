---
name: standup
description: Morning standup prep — pulls last 24h from Clockify, Jira, GitHub, and git log. USE WHEN standup, what did I do yesterday, standup notes, morning prep, daily standup, scrum update.
---

# Standup

Retrospective standup prep. Looks backwards ~24h and compiles what happened into a ready-to-use standup format.

## Trigger

- `/standup` — explicit invocation
- "standup notes", "what did I do yesterday", "morning prep"

## Configuration

```
Repo:          /Users/freddylem/dev/powerx/data
GitHub org:    powerxai/data
Jira tool:     ~/.claude/skills/_JIRA/Tools/Jira.ts
Clockify tool: ~/.claude/skills/_CLOCKIFY/Tools/Clockify.ts (if exists) or REST API
Vault base:    /Users/freddylem/Library/CloudStorage/GoogleDrive-fredlemi@gmail.com/My Drive/Obsidian/Obsidian Vault
WIP page:      {VAULT}/PAI/PAI Work In Progress.md
```

## Workflow Routing

| Workflow | Trigger | File |
|----------|---------|------|
| **Morning** | `/standup`, "standup", "what did I do" | `Workflows/Morning.md` |

## Data Sources

All data is pulled from existing tools — no raw API calls needed:

| Source | Tool | What it provides |
|--------|------|-----------------|
| **Clockify** | `Clockify.ts` or REST API | Yesterday's time entries with descriptions |
| **Jira** | `Jira.ts search` | Tickets with status changes in last 24h |
| **GitHub** | `gh` CLI | PRs opened/merged/reviewed, PR review comments |
| **Git** | `git log` | Commits from last 24h |

## Output Format

```markdown
## Standup — {date}

### Yesterday
- {bullet from clockify entries}
- {bullet from merged PRs}
- {bullet from ticket transitions}

### Today
- {carried-over in-progress tickets}
- {sprint priorities from Jira}

### Blockers
- {PRs awaiting review}
- {tickets blocked}
```

## Output Destination

Display in terminal. If Fred asks, also write to today's Obsidian daily note.
