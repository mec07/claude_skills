# WIP Triage Workflow

Decide what to do about pull requests that have gone stale, one multi-choice
question at a time, and act on the answers.

Runs after `Workflows/Sync.md`, which supplies the open-PR list. Triggered by
`/WIP triage`, by "old PRs", or offered at the end of a sync when there is
anything to ask about.

## Step 1 — Load the deferral file and re-open due decisions

Read `~/.claude/wip/deferrals.json`. Format and failure handling:
`Reference/Deferrals.md`.

**No decision is discarded here, and no PR is touched.** An expired snooze is
not permission to act on anything — it only means the PR may be raised again:

1. A `snooze` whose `until` has passed becomes askable again. The entry stays,
   carrying its `snooze_count`, which sets how long the next snooze lasts —
   7, 14, 30, 90 then 180 days. The whole point of this file is to stop asking
   about work that is being deliberately ignored, and a fixed week would mean
   asking every week.
2. A `waiting` entry whose PR has a newer `updatedAt` than `seen_activity_at`
   becomes askable again — the thing being waited on has happened.
3. An entry whose URL is not in the current open-PR set is removed — its PR is
   closed or merged, so there is nothing left to suppress. This is the only
   automatic removal.

Write the file back with the updated states.

## Step 2 — Select what to ask about

A PR is asked about when **all** of these hold:

- it is open, on either source
- it is in the **Waiting on someone else** bucket (`Workflows/Sync.md`, step 6)
- its last activity is more than **28 days** ago
- it has no surviving deferral entry after step 1

The bucket condition is what keeps triage honest. A review you owe, a PR with
conflicts, and an approved PR ready to merge are all things to *do*, not things
to park — offering "ignore for a week" on a review somebody is blocked on would
be actively wrong. Only work you cannot act on is triage material.

If the sync found actionable items, say so before asking anything:

```
3 reviews are waiting on you and 2 PRs need work before triage. Handle those
first, or carry on?
```

Sort oldest first. Report the count before starting: "14 PRs older than 28 days,
3 currently snoozed, 1 waiting."

**Group before asking.** Several stale PRs opened within a day of each other, on
the same repo, with a shared prefix in their titles are one decision, not
several. Offer the group as a single question naming the count, and apply the
answer to every PR in it. A batch of README PRs is the archetype: eleven
questions where one will do is how triage stops being run.

## Step 3 — Ask

Use `AskUserQuestion`. It takes **at most four questions per call**, so batch in
fours and send the next call as soon as the previous answers return.

Each question carries what is needed to decide without opening the PR: age, repo,
title, the PR's own state, its URL, and — if it has been parked before — how many
times.

```
PR 1/14: acme/api#5903 — "chore: ingestion adapter READMEs" (57d)
         conflicts · review required · snoozed 3 times
         https://github.com/acme/api/pull/5903
```

Options, in this order:

| Option | Meaning |
|---|---|
| **Action today** | It matters now. Goes on today's list, no deferral written |
| **Ignore for {interval}** | Writes a `snooze`. The interval backs off with `snooze_count`: 7, 14, 30, 90, then 180 days. Label it with the real interval, and the count once it is above one |
| **Waiting for a response** | Writes a `waiting` entry; ask who or what, and record the PR's current `updatedAt` |
| **Close it** | The agent closes the PR — see step 4 |
| *(free text)* | Anything else: "close with a comment explaining why", "reassign to X", "rebase first". Recorded in `note` and acted on |

The free-text option is not a fallback, it is where the useful answers live.
`AskUserQuestion` always offers it, so do not spend one of the four listed
options restating it.

**Research before offering, in proportion to the PR.** A PR whose title says what
it does needs nothing. A 500-day-old PR whose title does not needs its diff stat
and last comment read first. Never offer a decision on a PR you have not looked
at enough to describe.

## Step 4 — Act

**Action today** — collect into a list, presented at the end. Nothing written.

**Ignore for a week / Waiting** — write the deferral entry. Nothing else happens.

**Close it** — never close on the strength of the menu choice alone. Selecting
the option states an intent; closing is an outward-facing action on a shared
repo, so confirm it explicitly first.

List every PR about to be closed, by title and URL, and get a yes. One
confirmation can cover a batch, but the batch must be enumerated — never close a
PR whose URL the user has not just seen. If the answer is anything other than a
clear yes, close nothing.

```bash
# GitHub
gh pr close <url> --comment "<optional message>"

# Azure DevOps
az repos pr update --id <pullRequestId> --status abandoned --detect false
```

Report each close with its URL and outcome. If a close fails, say so and leave
the PR untouched — never write a deferral to paper over a failed close.

**Free text** — do what it says if it is within the skill's reach (close with a
comment, add a comment, mark draft, reassign). If it is not, record it in `note`
and surface it in the summary as an action for the user.

Free text that closes or deletes anything goes through the same explicit
confirmation as the Close option. "Close with a comment" is still a close.

## Step 5 — Report

```
## Triage — {date}

Actioned today (3)
- acme/api#6959 "readers move onto the declared owner" — https://...

Closed (11)
- acme/api#5903 … #5913 — the README batch, closed with a comment

Snoozed to {date} (2)
- acme/web#88 "Add tenant guard" — https://...

Waiting (1)
- acme/api#6919 — on review from the platform team, since {date}

Deferral file: {n} entries ({k} dropped — their PRs are closed)
```

Always print the deferral-file line. The count should track the number of PRs
being deliberately parked; if it climbs past that, something is wrong.
