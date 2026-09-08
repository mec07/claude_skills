# WIP Triage Workflow

Decide what to do about pull requests that have gone stale, one multi-choice
question at a time, and act on the answers.

Runs after `Workflows/Sync.md`, which supplies the open-PR list. Triggered by
`/WIP triage`, by "old PRs", or offered at the end of a sync when there is
anything to ask about.

## Step 1 — Load and clean the deferral file

Read `~/.claude/wip/deferrals.json`. Format and failure handling:
`Reference/Deferrals.md`.

Before asking anything, apply both bounding rules:

1. Drop any entry whose URL is not in the current open-PR set.
2. Drop `snooze` entries whose `until` has passed, and `waiting` entries whose PR
   has a newer `updatedAt` than the recorded `seen_activity_at`.

Write the cleaned file back. This is what stops it growing and what makes a
finished wait re-surface on its own.

## Step 2 — Select what to ask about

A PR is asked about when **all** of these hold:

- it is open, on either source
- its last activity is more than **28 days** ago
- it has no surviving deferral entry after step 1

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
title, the PR's own state, and its URL.

```
PR 1/14: acme/api#5903 — "chore: ingestion adapter READMEs" (57d)
         conflicts · review required
         https://github.com/acme/api/pull/5903
```

Options, in this order:

| Option | Meaning |
|---|---|
| **Action today** | It matters now. Goes on today's list, no deferral written |
| **Ignore for a week** | Writes a `snooze` with `until` = today + 7 days |
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

**Close it** — closing is reversible but outward-facing, so say what is about to
be closed and let the answer stand as the confirmation. Do not re-prompt per PR;
the option was the prompt.

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
and surface it in the summary as an action for her.

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

Deferral file: 3 entries, {n} pruned this run
```

Always print the deferral-file line. It is what makes the file's size visible,
and a growing count is the signal that something is wrong.
