---
name: WIP
description: Work in progress sync — pulls your open pull requests from GitHub and Azure DevOps and your open tickets from Jira, cross-references them, flags staleness and status mismatches, and triages PRs that have gone stale. USE WHEN wip, work in progress, what am I working on, what's the state of things, check my PRs, open PRs, stale tickets, sync tickets, triage PRs, old PRs.
---

# WIP (Work In Progress)

Answers "what am I actually working on?" from the services that already know:
GitHub, Azure DevOps and Jira.

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

**No accumulating state.** The services track the work; this skill queries live
and renders. The one file it keeps is your triage decisions, which no service
records — pruned against live PR state every run. Format:
`Reference/Deferrals.md`.

## Requirements

`gh`, `az` + the `azure-devops` extension, and the Atlassian MCP. Each source is
probed independently; a missing or unauthenticated tool skips its own section
rather than aborting the run.

## Output

Terminal summary, plus `~/.claude/wip/WIP.md` — overwritten each run, open items
only. Every PR carries its URL.
