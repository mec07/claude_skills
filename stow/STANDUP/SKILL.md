---
name: STANDUP
description: Morning standup prep — pulls last 24h from Clockify, Jira, GitHub, and git log. USE WHEN standup, what did I do yesterday, standup notes, morning prep, daily standup, scrum update.
---

# Standup

Retrospective standup prep. Looks backwards ~24h and compiles what happened into a ready-to-use standup format.

## Trigger

- `/standup` — explicit invocation
- "standup notes", "what did I do yesterday", "morning prep"

## Context (derived, never configured)

Nothing about a particular repo, user or vault is written into this skill.

```bash
REPO=$(git rev-parse --show-toplevel 2>/dev/null)   # empty if not in a repo
```

| Value | Resolved from |
|-------|---------------|
| Git activity | `REPO`, or skipped with a note when not in a repo |
| GitHub user | `@me` in search qualifiers |
| GitHub repos | none — `gh search prs` spans every repo you can see |
| Jira user | `currentUser()` in JQL, via the Atlassian MCP |
| Clockify | `Clockify.ts` if present, else the REST API with `CLOCKIFY_API_KEY` |

**Optional Obsidian output.** Set `OBSIDIAN_VAULT` to a vault directory and the
standup is also written to that day's daily note. Unset — the default — the step
is skipped silently and the standup is terminal-only. No vault path is stored
here.

## Workflow Routing

| Workflow | Trigger | File |
|----------|---------|------|
| **Morning** | `/standup`, "standup", "what did I do" | `Workflows/Morning.md` |

## Data Sources

All data is pulled from existing tools — no raw API calls needed:

| Source | Tool | What it provides |
|--------|------|-----------------|
| **Clockify** | `Clockify.ts` or REST API | Yesterday's time entries with descriptions |
| **Jira** | Atlassian MCP `searchJiraIssuesUsingJql` | Tickets with status changes in last 24h |
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

Display in terminal. When `OBSIDIAN_VAULT` is set, also write to that day's daily note.
