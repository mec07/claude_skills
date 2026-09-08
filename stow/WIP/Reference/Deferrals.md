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
    "pr_state": "open",
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
| `pr_state` | both | `open`, or `closed` once the PR is no longer open |
| `note` | both | Free text from the "something else" option |

## Nothing is ever deleted automatically

Entries are not removed as a side effect of time passing, of a PR closing, or of
anything else the skill notices on its own. A decision is a record of something
the user said, and the skill does not get to throw those away. Expiry changes an
entry's *state*, never its existence.

| Event | What happens |
|-------|--------------|
| A snooze's `until` passes | Entry stays. It becomes askable again |
| A waiting PR gets new activity | Entry stays. It becomes askable again, with the wait's outcome noted |
| The PR is merged or closed | Entry stays, marked `pr_state: closed`. Never removed |
| The user says to remove it | Removed |

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

The option is still labelled "ignore for a week" the first time and names the
actual interval after that — "ignore for 30 days (snoozed 3 times)". The count is
shown so the pattern is visible, not to make a point of it. A PR being parked
repeatedly is information: it usually means close it, or it is genuinely blocked
and belongs in `waiting` instead. Offer that reading once, at count 3, and then
leave it alone.

## Keeping it small without deleting anything

The file grows only when the user triages a PR they have not triaged before, so
it grows at the speed of their own decisions — slow. At roughly 200 bytes an
entry, a thousand triaged PRs is about 200 KB.

To stop it drifting upward forever, **report, do not act**. When entries
reference PRs that are no longer open, say so at the end of triage and offer to
remove them:

```
31 entries, 14 of them for PRs that are now closed or merged. Remove those 14?
```

If the user says yes, remove exactly those. If they say nothing, the entries
stay. The count in the report is what keeps the file's size in view; the user's
answer is the only thing that shrinks it.

## Failure handling

If the file is missing, treat it as `{}`. If it is unparseable, say so, move it
aside to `deferrals.json.bad`, and continue with `{}` — never let a corrupt
decision file stop a sync.
