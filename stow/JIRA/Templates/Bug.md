# Bug

For something that used to work, or that behaves differently from what was expected.

Rules that apply to every section: `../Reference/TicketRules.md`.

**Whole ticket: 200 words maximum.** Evidence links do not count toward it.

| Section | | Cap |
|---|---|---|
| `## What happens` | required | 2 sentences |
| `## What should happen` | required | 2 sentences |
| `## Steps to reproduce` | required | 6 numbered steps, from a known start state |
| `## Where it was seen` | required | 3 lines |
| `## Impact` | required | 2 sentences |
| `## Also true when fixed` | optional | 4 bullets |

An optional section with nothing real to say is deleted, heading and all.

## Worked example

```markdown
## What happens

Reordering columns on the users table resets the order on the next page load.

## What should happen

A chosen column order persists for that user until they change it again.

## Steps to reproduce

1. Sign in as a user with the Operations role
2. Open Settings, then Users
3. Drag the Status column to the first position
4. Reload the page

## Where it was seen

PX portal, production, 2026-09-24.
Chrome 141 on macOS, also reproduced in Safari 26.
Account 44182.

## Impact

Operations reset the column order several times a day. Nobody is blocked, but it is a
constant irritation and it was reported three times last month.
```

Note that `## Also true when fixed` is absent. The repro covers everything the fix has to
satisfy, so the heading was deleted.

## Writing each section

**There is no acceptance criteria section, and this is deliberate.** `## What should
happen` combined with `## Steps to reproduce` is the acceptance criterion. The bar is that
a second person can reproduce the bug without asking a follow-up question. An acceptance
criteria section would restate those two in different words.

**`## Steps to reproduce`** start from a known state, name the exact screen, control and
value, and use the fewest steps that still trigger the bug. Trim anything not needed.

**`## Where it was seen`** is one line each of environment, version or build, and the
account or record involved, as far as they are known.
Unknown is omitted rather than guessed: three lines of real detail beat six of
speculation.

**`## Impact`** says who is affected and how often, in numbers where numbers exist. It does
not set a priority: priority and severity are Jira fields, per R2, and they are two
separate axes.

**`## Also true when fixed`** exists only for conditions the fix must satisfy that the
repro does not imply. Correcting rows already written wrongly is the common case. If there
is no such condition, delete the section.

**No proposed fix**, per R1. Name what you observed and what you expected. Diagnosis is
the job of whoever picks it up. A log line or a failing record id that you already have is
evidence and belongs here; a theory about the cause is not.
