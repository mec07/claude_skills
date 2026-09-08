# Deferrals

`~/.claude/wip/deferrals.json` — the only file this skill keeps between runs.

Triage asks what to do about a stale PR. Two of the answers — ignore for a week,
and waiting for a response — mean "do not ask me again yet", and no service
records that. This file does.

## Shape

Keyed by PR URL, so it works across GitHub and Azure without a separate id
scheme.

```json
{
  "https://github.com/acme/api/pull/412": {
    "decision": "snooze",
    "until": "2026-09-15",
    "decided": "2026-09-08",
    "note": ""
  },
  "https://dev.azure.com/acme/web/_git/site/pullrequest/88": {
    "decision": "waiting",
    "for": "review from the platform team",
    "since": "2026-09-08",
    "seen_activity_at": "2026-09-06T17:43:38Z"
  }
}
```

| Field | Applies to | Meaning |
|-------|-----------|---------|
| `decision` | both | `snooze` or `waiting` |
| `until` | snooze | Date the PR becomes askable again |
| `for` | waiting | Free text: who or what is being waited on |
| `since` | waiting | When the wait started |
| `seen_activity_at` | waiting | PR's `updatedAt` when the decision was made |
| `decided` | both | When the decision was made |
| `note` | both | Free text from the "something else" option |

## Bounds

The file is capped by the number of PRs you have open, not by time. Two rules
keep it that way, and both run before triage asks anything:

1. **Prune closed work.** Delete any key whose URL is not in the current open-PR
   set. A merged or closed PR takes its entry with it.
2. **Expire decisions.** Delete a `snooze` whose `until` has passed. Delete a
   `waiting` once the PR's `updatedAt` is newer than `seen_activity_at` — the
   thing being waited on has happened, so the wait is over and the PR should be
   asked about again.

Nothing is appended, no history is kept, and there is no archive. A decision is
either live or gone.

## Failure handling

If the file is missing, treat it as `{}`. If it is unparseable, say so, move it
aside to `deferrals.json.bad`, and continue with `{}` — never let a corrupt
decision file stop a sync.
