# Rule check

Run this against the rendered ticket body before showing it to the user, every time.

- [ ] Every section is within its stated cap
- [ ] The whole ticket is within its word cap
- [ ] Every required section is present and says something real
- [ ] No optional section is present with filler in it
- [ ] No solution language: a file or function named as a place to change, a proposed
      approach, a named library, an instruction to use or refactor or add something
- [ ] Nothing that belongs in a Jira field appears in the body, per R2
- [ ] No em dash and no en dash anywhere
- [ ] No emoji prefix and no bold severity label
- [ ] Acceptance criteria, where present, are each observable and binary
- [ ] Acceptance criteria, where present, are the last section of the ticket

## What a failure means

A failed check means revise and run the check again. It **never means create anyway**.

An item that fails twice on the same text is surfaced to the user with the offending line
quoted, rather than attempted a third time. Two failures mean the check and the draft
disagree about something a person should settle.

## The solution-language false positive

This is the check most likely to be wrong, and the way it goes wrong makes the skill worse
than no skill: it strips out the evidence that made the ticket actionable.

R1's carve-out governs. A fact the reporter already holds is evidence and stays. A
direction to the implementer is instruction and goes.

| Line | Verdict |
|---|---|
| "This fails for account 44182" | Evidence. Keep. |
| "The error is `connection reset by peer`" | Evidence. Keep. |
| "The users table in the PX portal duplicates the SP portal's" | Evidence. Keep. |
| "Use the shared component from the ui package" | Instruction. Remove. |
| "Add an index on the orders table" | Instruction. Remove. |
| "Refactor the lookup before adding the field" | Instruction. Remove. |

**When unsure, quote the line and ask.** Never delete silently. A reporter who finds their
evidence removed will stop using the skill, and that costs more than one extra question.
