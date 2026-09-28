# Worked example: DEVT-874 through the Bug template

The primary evidence for the ticket templates, required by the design spec section 10.1.
A real ticket, rewritten, with every removal attributed to the rule that removed it.

Ticket: DEVT-874, a Bug in DEVT, created 2026-09-24.
Chosen because it is recent, real, and written by the current unguided path.

---

## 1. Before

239 words. Reproduced verbatim from the `description` field.

````markdown
`events_insert_args.blobl` in `events-pipeline-infrastructure` formats `started_at` and
`ended_at` with a layout that ends in a literal `Z` but passes no timezone, so Bento
formats them in the **host's** local timezone and labels the result as UTC:

```
(this.started_at / 1000000).ts_unix().ts_format("2006-01-02T15:04:05Z")
```

The two other Bento pipelines that write timestamps both pass the timezone explicitly, so
this one is the outlier:

* `bento-late-model-runs-to-db.tf:233` - ts_format("2006-01-02T15:04:05.000000Z", "UTC")
* `bento-metrics-to-timescale.tf:402` - ts_format("2006-01-02T15:04:05.000000Z", "UTC")

## Impact

Latent, not currently firing. `ghcr.io/warpstreamlabs/bento:1.21.2` runs with `TZ=UTC` and
nothing in the Deployment sets `TZ`, so the digits produced today are correct.

It fails silently the moment that stops being true, a `TZ` env var added to the pod, a node
or base-image change. `events.events.started_at` and `ended_at` are `timestamp` (without
time zone), so Postgres discards the `Z` and stores whatever wall-clock digits arrive.
Every reader treats them as UTC. There is no error and nothing to alert on; the rows are
just wrong by the offset.

## Reproduction

```
$ bento blobl 'root = (1700000000000/1000000).ts_unix().ts_format("2006-01-02T15:04:05Z")'
1970-01-20T17:13:20Z          # host in Europe/London

$ TZ=UTC bento blobl '...same...'
1970-01-20T16:13:20Z
```

## Fix

Pass the timezone at both call sites in
`infrastructure/bento/mappings/events_insert_args.blobl`:

```
ts_format("2006-01-02T15:04:05Z", "UTC")
```

The unit tests stay green: `check.sh` exports `TZ=UTC`, so the expected values do not move.

## Note

`ci/bento-scripts/check.sh` pins `TZ=UTC` so the gate is deterministic wherever it runs.
That makes CI reliable; it does not protect the deployed pod, which is what this ticket is
about.
````

## 2. After

Rendered through `stow/JIRA/Templates/Bug.md`.

````markdown
## What happens

The events pipeline writes event timestamps using the host's local timezone and labels
them UTC. The digits are wrong by the host's offset whenever the host is not on UTC.

## What should happen

Event timestamps are stored as UTC whatever timezone the host is set to.

## Steps to reproduce

1. Put the host on a timezone that is not UTC, such as Europe/London in summer
2. Run `bento blobl 'root = (1700000000000/1000000).ts_unix().ts_format("2006-01-02T15:04:05Z")'`
3. Run the same command again with `TZ=UTC` in front
4. Compare the two results

## Where it was seen

events-pipeline-infrastructure, the events insert mapping, bento 1.21.2.
Not currently firing: the image runs with TZ=UTC and nothing in the Deployment sets TZ.
The two other Bento pipelines that write timestamps pass the timezone explicitly.

## Impact

Nobody is affected today. It starts producing wrong rows silently the moment anything
makes the host non-UTC, such as a TZ variable on the pod or a base image change. The
columns have no time zone, so Postgres keeps whatever digits arrive and every reader
treats them as UTC. There is no error and nothing to alert on, and CI pins TZ=UTC, so the
test gate would not catch it either.
````

## 3. The numbers

Counted two ways, because the template's own counting rule excludes headings and list
markers while a raw count does not.

| | Raw words | By the template's counting rule | Shape |
|---|---|---|---|
| Before | 239 | 229 | 4 headings plus an unheaded opening, 4 code blocks |
| After | 204 | 182 | 5 headings, no code block outside the repro step |
| Change | 15 percent shorter | 20 percent shorter | one screen, no scrolling |

**Twenty percent is a modest number and it is the honest one.** An earlier draft of this
document claimed 27 percent against an unverified count; the figures above were measured.
The word reduction is real but it is not the main result. The main result is that the
"after" contains no instruction about what to change, so the person who picks it up is
free to decide whether the fix is a timezone argument, a pinned `TZ` in the Deployment, or
a column type change. The "before" had already chosen.

## 4. What each rule removed

| Removed | Rule |
|---|---|
| The whole `## Fix` section, naming the file and the exact replacement call | R1. It is the solution, and it pre-empts three other valid fixes. |
| `bento-late-model-runs-to-db.tf:233` and `bento-metrics-to-timescale.tf:402`, with their code | R1. The fact that the other pipelines differ is evidence and was kept; the line numbers and the code they contain are a pointer to the edit and were not. |
| The opening code block showing the offending call | R1. Kept as prose: the mapping formats with no timezone. |
| The `## Note` paragraph about `ci/bento-scripts/check.sh` | Cap on `## Impact`. The load-bearing half, that CI would not catch it, was folded into Impact in one clause. The half arguing about why the gate is pinned was cut. |
| The unit-tests-stay-green sentence | R1. It is a claim about the proposed fix, which no longer exists in the ticket. |
| Priority `Lowest` and label `bug` | R2. Both are Jira fields and were already set. Neither was in the body, so this rule cost nothing here. |
| No acceptance criteria section was added | Bug template. "What should happen" plus the repro is the criterion. |

## 5. Things the rewrite changed rather than removed

- The title stays as it is. `bento-events-to-db formats event timestamps in the host timezone`
  is already an outcome-shaped summary and needs nothing.
- `## Reproduction` became `## Steps to reproduce` as numbered steps from a known start
  state. The original showed a shell transcript, which demonstrates the bug but does not
  tell a second person what to do. The step form is the template's, and it is the change
  that most improves reproducibility.
- `## Impact` kept its substance almost intact. It was already the best-written section of
  the original, because it describes consequences rather than mechanism.

## 6. What was lost, honestly

**The exact call site is gone.** The before opened with the basename
`events_insert_args.blobl` and gave the full path,
`infrastructure/bento/mappings/events_insert_args.blobl`, inside `## Fix`. The after says
"the events insert mapping" and gives neither. A developer now spends a minute finding it.

This is the weakest call in the rewrite. R1's carve-out permits keeping a filename the
reporter already holds, and the basename in the opening line was evidence, not
instruction: dropping it was stricter than the rule requires. Keeping
`events_insert_args.blobl` and dropping only the full path from `## Fix` would have been
defensible and arguably better. It is recorded here rather than quietly fixed, because the
point of this document is to show where the templates bite.

**The `ts_format` snippet is gone.** Someone who does not know Bento now has to look up
what the mapping does. This is the cost of the rule and it is real. The counter-argument,
which is why the rule stands: the snippet is only useful if you have already accepted the
ticket's diagnosis, and the ticket's job is to state the symptom.

**One judgement call worth flagging.** The after keeps "The two other Bento pipelines that
write timestamps pass the timezone explicitly." That is evidence under R1's carve-out, and
it is also very nearly a hint at the fix. It was kept because it tells the implementer the
inconsistency is real and not a deliberate choice, which is the kind of thing a reporter
knows and an implementer would waste time rediscovering. A reviewer who wanted it gone
would not be wrong. This is exactly the false positive that
`stow/JIRA/Reference/RuleCheck.md` warns about, and the rule it gives is the one applied
here: when unsure, keep it and say so rather than deleting silently.

## 7. Verification

- The "after" body was checked by hand against every item of
  `stow/JIRA/Reference/RuleCheck.md`. All ten pass.
- 182 words against the Bug template's cap of 200, measured by the template's counting
  rule. That is close to the ceiling, and it is close because step 2 of the repro carries a
  long command. Worth noting for the templates: a repro step containing a full command line
  spends a disproportionate share of the cap.
- Every required Bug section is present. `## Also true when fixed` is absent, correctly:
  the bug has not fired, so there are no wrong rows to correct.
