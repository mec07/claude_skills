---
name: WIP
description: Work in progress sync — pulls your open pull requests from GitHub and Azure DevOps and your open tickets from Jira, cross-references them, and flags staleness and status mismatches. USE WHEN wip, work in progress, what am I working on, what's the state of things, check my PRs, open PRs, stale tickets, sync tickets.
---

# WIP (Work In Progress)

Answers "what am I actually working on right now?" by querying every source that
already knows: GitHub, Azure DevOps and Jira. Cross-references pull requests
against tickets, flags anything stale or inconsistent, and writes a short summary
file listing open work only.

## Trigger

- `/WIP` — explicit invocation
- "what am I working on", "what's the state of things"
- "check my PRs", "open PRs", "stale tickets"

## Design

**No stored state.** The three services already track open work. This skill
queries them live and renders the result — it never maintains its own copy, so
there is nothing to fall out of sync and nothing that grows over time. The output
file is overwritten on every run and lists open items only.

**No configuration.** Every identity and scope resolves at runtime from the CLIs
you are already logged into. Nothing about you is written into this skill, so it
works unchanged for anyone who installs it.

| Value | Resolved from |
|-------|---------------|
| GitHub user | `@me` in search qualifiers |
| GitHub repos | none — `gh search prs` spans every repo you can see |
| Azure user | `az account show --query "user.name" -o tsv` |
| Azure org/project | `az devops configure -l` defaults |
| Jira user | `currentUser()` in JQL |
| Jira projects | `getVisibleJiraProjects` at runtime |

## Workflow Routing

| Workflow | Trigger | File |
|----------|---------|------|
| **Sync** | `/WIP`, "what am I working on", "check my PRs" | `Workflows/Sync.md` |

## Sources

### GitHub (`gh`)
- Open PRs you authored, across **all** repositories
- PRs awaiting your review
- PRs merged in the last 14 days
- Per-PR review decision, CI status and mergeability

### Azure DevOps (`az repos`)
- Active PRs you created
- Active PRs where you are a reviewer
- Recently completed PRs

### Jira (Atlassian MCP)
- All tickets assigned to you that are not Done, with status and last-updated

## What It Flags

| Condition | Flag |
|-----------|------|
| PR open, no activity in 3+ days | ⚠️ Stale |
| PR with failing CI | 🔴 CI broken |
| PR with merge conflicts | 🔴 Conflicts |
| Review requested from you, not yet done | ⚠️ Needs review |
| Review requested from others, no response 3+ days | ⚠️ Needs chase |
| Ticket in progress, no open or merged PR | ⚠️ No PR yet |
| Ticket still to do but a PR exists | ⚠️ Status mismatch |
| Ticket in progress but its PR is merged | ⚠️ Status mismatch |
| Ticket done but its PR is still open | ⚠️ Status mismatch |
| Your PR against someone else's ticket | ⚠️ Assignee mismatch |
| PR with no resolvable ticket key | ℹ️ Untracked |

Jira workflow names vary between projects, so match on the ticket's status
*category* (To Do / In Progress / Done) rather than a literal status name, and
report the project's own status text back to the user.

## Ticket Matching

No project prefix is ever written down. Keys are found by shape —
`[A-Z][A-Z0-9]+-[0-9]+` in each PR title, branch name and description — then
validated against the list of Jira projects fetched at runtime. Every project you
can see is covered automatically, including ones you have no open ticket in, and
strings like `UTF-8`, `SHA-256` or `RFC-2119` are rejected because no project
matches them.

## Output

1. **Terminal summary** — the full picture, flags first
2. **`~/.claude/wip/WIP.md`** — overwritten each run, never appended; open items
   only, so it stays short enough to read at a glance

## Requirements

| Tool | Needed for | Without it |
|------|-----------|------------|
| `gh` | GitHub PRs | GitHub section skipped with a note |
| `az` + `azure-devops` extension | Azure DevOps PRs | Azure section skipped with a note |
| Atlassian MCP | Jira tickets | Jira section skipped with a note |

Each source is independent. A missing or unauthenticated tool degrades that one
section — it never aborts the run.
