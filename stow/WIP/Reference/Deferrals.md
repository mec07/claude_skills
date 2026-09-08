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
    "snooze_count": 4,
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
| `decided` | both | When the decision was last made |
| `snooze_count` | snooze | How many times this PR has been snoozed |
| `note` | both | Free text from the "something else" option |

## What is kept, and what goes

The file exists to suppress asking. An entry earns its place only while the PR
it refers to is still open — once the PR is closed or merged there is nothing
left to ask about, so the entry goes with it.

| Event | What happens |
|-------|--------------|
| The PR is merged or closed | Entry removed. It has nothing left to suppress |
| A snooze's `until` passes | Entry stays, and becomes askable again |
| A waiting PR gets new activity | Entry stays, and becomes askable again |
| The user says to remove it | Removed |

That first row is the only automatic removal, and it is bookkeeping rather than a
decision being thrown away: the PR is gone, so the record of parking it is spent.

**Nothing else is removed on its own, and no pull request is ever closed without
being asked about.** An expired snooze is not a licence to act — it only means
the PR may be raised again. Closing is a separate, explicit answer, confirmed
against a named list of URLs. See `Workflows/Triage.md`.

**Snoozing repeats, and backs off.** A PR can be snoozed as many times as the
user likes — something more important is usually the reason, and that is a
legitimate answer every time.

But a fixed week means being asked every week about work that is being
deliberately ignored, which is the exact thing this file exists to prevent. So
each re-snooze of the same PR lasts longer than the last:

| `snooze_count` | Next snooze |
|---|---|
| 1 | 7 days |
| 2 | 14 days |
| 3 | 30 days |
| 4 | 90 days |
| 5+ | 180 days |

The option is labelled "ignore for a week" the first time and names the actual
interval after that — "ignore for 30 days (snoozed 3 times)". The count is shown
so the pattern is visible, not to make a point of it. A PR being parked
repeatedly is information: it usually means close it, or it is genuinely blocked
and belongs in `waiting` instead. Offer that reading once, at count 3, and then
leave it alone.

## Size

Bounded by the number of PRs currently open, because entries leave when their PRs
do. At roughly 200 bytes an entry, even a hundred parked PRs is 20 KB. Print the
entry count at the end of triage so the number stays in view.

## Failure handling

If the file is missing, treat it as `{}`. If it is unparseable, say so, move it
aside to `deferrals.json.bad`, and continue with `{}` — never let a corrupt
decision file stop a sync.
