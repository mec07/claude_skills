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
4. Compare the two results: they differ by the host offset

## Where it was seen

events-pipeline-infrastructure, `events_insert_args.blobl`, bento 1.21.2.
Observed on a Europe/London host: 1970-01-20T17:13:20Z, against 16:13:20Z under TZ=UTC.
The two other Bento pipelines that write timestamps pass the timezone explicitly.

## Impact

Nobody is affected today, because the image happens to run on UTC. The moment anything
changes that, every event row is silently wrong by the host offset, with no error to
alert on and no test gate to catch it, since CI pins TZ=UTC too.
````

## 3. The numbers

Counted two ways, because the template's own counting rule excludes headings and list
markers while a raw count does not.

| | Raw words | By the template's counting rule | Shape |
|---|---|---|---|
| Before | 239 | 229 | 4 headings plus an unheaded opening, 4 code blocks |
| After | 176 | 154 | 5 headings, no code block outside the repro step |
| Change | 26 percent shorter | 33 percent shorter | one screen, no scrolling |

**Every figure above was measured, and the history is worth recording.** The first draft
of this document asserted 27 percent without counting. Measuring gave 20 percent. A review
then found that the `## Impact` section was four sentences against a cap of two and that
the rewrite had dropped evidence it was entitled to keep. Fixing both produced the numbers
above: cutting Impact to its cap saved more than restoring the filename and the two
observed timestamps cost, so the ticket ended up shorter **and** more useful than the
version that had quietly broken its own cap.

That is the argument for hard caps in one paragraph. The padded section was not carrying
information; it was carrying mechanism the reader could infer.

The word reduction is real but it is not the main result. The main result is that the
"after" contains no instruction about what to change, so the person who picks it up is
free to decide whether the fix is a timezone argument, a pinned `TZ` in the Deployment, or
a column type change. The "before" had already chosen.

## 4. What each rule removed

| Removed | Rule |
|---|---|
| The whole `## Fix` section, naming the file and the exact replacement call | R1. It is the solution, and it pre-empts three other valid fixes. |
| `bento-late-model-runs-to-db.tf:233` and `bento-metrics-to-timescale.tf:402`, with their code | R1. The fact that the other pipelines differ is evidence and was kept; the line numbers and the code they contain are a pointer to the edit and were not. |
| The opening code block, as a standalone block asserting the diagnosis | R1. The call itself was **not** removed: it survives inside repro step 2, where it is an instruction to the reader reproducing the bug rather than a claim about the cause. |
| The `## Note` paragraph about `ci/bento-scripts/check.sh` | Cap on `## Impact`. The load-bearing half, that CI would not catch it, survives as one clause. The half arguing about why the gate is pinned was cut. |
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

**The first pass dropped the call site, and that was wrong.** It removed
`events_insert_args.blobl` entirely, on the grounds that the full path
`infrastructure/bento/mappings/events_insert_args.blobl` had appeared under `## Fix`. But
the basename also appeared in the opening line, as a plain statement of where the problem
lives, and R1's carve-out covers exactly that: a filename the reporter already holds is
evidence, not instruction.

Over-applying R1 here would have made this document demonstrate the rule doing the precise
harm `../../../stow/JIRA/Reference/RuleCheck.md` warns about, in the one example meant to
justify adopting the templates. The filename is now back, in `## Where it was seen`, which
is where the Bug template says it belongs.

The near miss is left on the record because the failure mode is instructive: it is easy to
read R1 as "strip anything that names the system" when it says "strip anything that directs
the implementer". The rule check's verdict table exists to keep those apart.

**The standalone `ts_format` block is gone, and this one is a genuine loss.** The before
opened with the offending call quoted on its own, which told a reader who knows Bento what
was wrong in one glance. The after carries the same call inside repro step 2, where it is
a command to run rather than a diagnosis to accept. Someone who knows the codebase now
reads four lines instead of one.

That is the cost of the rule, and it is real. The reason the rule stands: the standalone
block is only useful once you have accepted the reporter's diagnosis, and a ticket that
leads with a diagnosis has pre-empted the judgement of whoever picks it up.

**One judgement call worth flagging.** The after keeps "The two other Bento pipelines that
write timestamps pass the timezone explicitly." That is evidence under R1's carve-out, and
it is also very nearly a hint at the fix. It was kept because it tells the implementer the
inconsistency is real and not a deliberate choice, which is the kind of thing a reporter
knows and an implementer would waste time rediscovering. A reviewer who wanted it gone
would not be wrong. This is exactly the false positive that
`stow/JIRA/Reference/RuleCheck.md` warns about, and the rule it gives is the one applied
here: when unsure, keep it and say so rather than deleting silently.

## 7. Verification

**An earlier version of this section claimed "all ten pass" without checking, and item one
did not pass.** `## Impact` was four sentences against a cap of two. A reviewer caught it.
The claim is restated below as what was actually verified and how.

| Check | Result | How |
|---|---|---|
| Every section within its stated cap | pass | Counted by hand, section by section, against the table in `../../../stow/JIRA/Templates/Bug.md`. `## Impact` is 2 sentences, `## Where it was seen` 3 lines, `## Steps to reproduce` 4 steps. |
| Whole ticket within its word cap | pass | 154 words against 200, measured by script, not estimated. |
| Every required section present and saying something real | pass | All five present. |
| No optional section present with filler | pass | `## Also true when fixed` is absent, correctly: the bug has not fired, so there are no wrong rows to correct. |
| No solution language | pass, with one call recorded | The pipelines-differ line is evidence under R1's carve-out. See section 6. |
| Nothing belonging in a Jira field | pass | Priority and labels stay fields. |
| No em dash or en dash | pass | Checked by `tests/ticket-templates.test.sh`. |
| No emoji prefix, no bold severity label | pass | None present. |
| Acceptance criteria observable and binary | n/a | A Bug has no acceptance criteria section by design. |
| Acceptance criteria last | n/a | Same. |

Eight pass, two do not apply to a Bug. That is the honest count, and it is not ten.

**Regression cover.** `test_worked_example_obeys_the_bug_template` in
`tests/ticket-templates.test.sh` now checks the "after" block automatically: the filename
is present, the two observed timestamps are present, and `## Impact` is within two
sentences. The cap violation this section once hid would now fail the suite.
