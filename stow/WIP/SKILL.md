---
name: WIP
description: Work in progress sync — pulls the PRs you authored and the ones waiting on your review from GitHub and Azure DevOps, plus your open Jira tickets, then groups everything by whose turn it is and triages what has gone stale. USE WHEN wip, work in progress, what am I working on, what's the state of things, check my PRs, open PRs, what do I need to review, reviews waiting on me, stale tickets, sync tickets, triage PRs, old PRs.
---

# WIP (Work In Progress)

Answers "what am I actually working on?" from the services that already know:
GitHub, Azure DevOps and Jira.

Reviewing other people's changes counts as work, so PRs waiting on your review
are fetched alongside your own and listed first — they are the ones where someone
else is blocked. Everything open is grouped by whose turn it is: reviews you owe,
work needing you, approved and ready to merge, and waiting on someone else.

## Workflow Routing

| Workflow | Trigger | File |
|----------|---------|------|
| **Sync** | `/WIP`, "what am I working on", "check my PRs" | `Workflows/Sync.md` |
| **Triage** | `/WIP triage`, "old PRs", or offered at the end of a Sync | `Workflows/Triage.md` |

Run Sync first — Triage needs the PR list it produces.

## Two rules that shape everything

**No configuration.** Every identity and scope resolves at runtime from the CLIs
you are logged into, so nothing about you is written into this skill and it works
unchanged for anyone. Resolution table: `Reference/Resolution.md`.

**Decisions are kept, nothing is deleted.** The services track the work; this
skill queries live and renders. The one file it keeps is your triage decisions,
so it stops asking about PRs you have chosen to ignore. Entries are never removed
automatically — only when you say so. Format: `Reference/Deferrals.md`.

## Requirements

`gh`, `az` + the `azure-devops` extension, and the Atlassian MCP. Each source is
probed independently; a missing or unauthenticated tool skips its own section
rather than aborting the run.

## Output

Terminal summary, plus `~/.claude/wip/WIP.md` — overwritten each run, open items
only. Every PR carries its URL.
