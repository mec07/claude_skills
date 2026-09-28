# Story / Task / Feature

For new behaviour, a change, a chore, or tech debt. Anything that is not a bug and not a
body of work spanning several tickets.

Rules that apply to every section: `../Reference/TicketRules.md`.

**Whole ticket: 200 words maximum.**

| Section | | Cap |
|---|---|---|
| `## What we want` | required | 3 sentences |
| `## Why it matters` | required | 2 sentences |
| `## Out of scope` | optional | 3 bullets |
| `## Acceptance criteria` | required | 7 bullets, one line each |

An optional section with nothing real to say is deleted, heading and all. It is never
filled to make the ticket look complete.

## Worked example

```markdown
## What we want

Customers can change the card on file without contacting support.

## Why it matters

Card changes are the third most common support contact, around 200 a month.

## Acceptance criteria

- [ ] A customer with a saved card can replace it from their account page
- [ ] The old card stops being charged from the moment the new one is saved
- [ ] A card that fails validation leaves the existing card in place
- [ ] The customer is told why a card was rejected, in plain language
```

Note that `## Out of scope` is absent. There was nothing to exclude, so the heading was
deleted rather than filled.

## Writing each section

**`## What we want`** opens with a plain outcome sentence: what is true once this is done.
Not "As a / I want / So that". That form is the textbook one, and it is deliberately not
used here, because a large share of these tickets have no end user and the form then
forces an invented persona. The reasoning is in the design spec, section 7.2.

**`## Why it matters`** carries what the As-a form is genuinely good at: who benefits and
why. It is required for internal work as much as for customer-facing work. A number that
already exists beats an adjective.

**`## Acceptance criteria`** are an observable-outcome checklist. One line per criterion,
each a binary observable fact. Not Given/When/Then, for the reason in the design spec,
section 7.1.

A criterion is well formed when a person who did not write the ticket could look at the
running system and say yes or no without asking anyone.

- Fails the test: "Card validation is robust."
- Passes the test: "A card that fails validation leaves the existing card in place."

**More than 7 criteria is a split signal, not a truncation signal.** Over-specifying
acceptance criteria erodes negotiability and means the story should be split. Propose the
split and show the division. Never drop a criterion, and never merge two into one longer
line to fit the count.
