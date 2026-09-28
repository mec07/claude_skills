# Ticket rules

Three rules govern everything written into a Jira ticket body by this skill. The
templates in `Templates/` state their own sections and caps; these rules apply across all
of them.

## R1: Outcome, not solution

A ticket states what should be true when the work is done, and how you would know. It
never states the solution. Working out how is the job of whoever picks it up.

No file paths as instructions, no function or table names, no proposed approach, no
library choices, no migration plans. This holds for the most technical work in the
backlog: a ticket about a database index is written as the outcome the index would
produce.

**The evidence carve-out.** A fact the reporter already holds belongs in the ticket, even
when it names part of the system. The distinction is evidence against instruction.

- Evidence, and it stays: "This fails for account 44182." "The error is
  `connection reset by peer`." "It happens on the Users settings page."
- Instruction, and it goes: "Fix the account lookup in the billing module." "Add an index
  on the orders table." "Use the shared component instead."

When a line could be read either way, keep it and let the implementer decide. R1 exists to
stop a ticket dictating a solution, not to withhold what the reporter knows.

## R2: Nothing that Jira has a field for

Priority, severity, labels, components, assignee, sprint, issue links, attachments and
parent all have Jira fields. None of them appears in the body.

Restating a field as prose duplicates it, and the prose copy goes stale the first time the
field changes. Severity and priority are two separate axes, technical seriousness against
business urgency, and both are set as fields.

The same reasoning keeps the child-story list out of an epic body. Children are Jira
links, and a list in the body is wrong as soon as one is added.

## R3: Voice

The voice rules in `SKILL.md` under Comment Workflow apply unchanged to ticket bodies. In
short, and read the original for the reasoning: no em dashes or en dashes, no emoji
prefixes, no bold severity labels, minimal structure.

Tickets are frequently visible to people outside the company, and a ticket that reads as
machine-generated costs credibility with them.
