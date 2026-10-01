# Epic

For a body of work spanning several tickets. Also for anything described as an initiative
or a programme.

Rules that apply to every section: `../Reference/TicketRules.md`.

**Whole epic: 250 words maximum.**

| Section | | Cap |
|---|---|---|
| `## Goal` | required | 1 sentence, an outcome not a deliverable |
| `## Why now` | required | 3 sentences |
| `## In scope` | required | 5 bullets |
| `## Out of scope` | required | 5 bullets |
| `## Done when` | required | 4 bullets, at least one measurable |
| `## Risks and dependencies` | optional | 3 bullets |

## Worked example

```markdown
## Goal

Customers manage their own payment details without contacting support.

## Why now

Card and billing changes are the third largest source of support contacts. Each one takes
an agent around eight minutes and requires them to see data they should not need to see.

## In scope

- Replacing the card on file
- Changing the billing address
- Viewing and downloading past invoices

## Out of scope

- Changing the billing currency
- Anything on the mobile apps
- Invoice disputes, which stay with support

## Done when

- Card and billing support contacts fall below 60 a month, from around 200
- A customer can replace a card and see the change reflected without contacting anyone
- No support agent needs to view full card details to resolve a billing contact
```

## Writing each section

**`## Goal` states an outcome, not a deliverable.** "Customers manage their own payment
details" is an outcome. "Build a payment settings page" is a deliverable, and a deliverable
in the goal has already chosen the solution.

**`## Out of scope` is required here**, where it is optional on a story.
Unbounded scope is the way epics fail, and an epic with nothing excluded is usually one
nobody has bounded yet. If nothing comes to mind, that is the signal to think harder, not
to delete the heading.

**`## Done when` carries at least one measurable bullet.**
Prefer a number that already exists over one invented to satisfy this rule. Where no
number is available, a binary observable statement is accepted: say so plainly rather than
fabricating a target.

**Child stories do not appear in the body.** They are Jira links, per R2. A list here is
wrong as soon as a child is added.
