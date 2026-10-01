# Jira ticket templates: outcome-first, capped, checkable

Design spec for a Create capability in the `JIRA` skill, built around three templates
(Epic, Bug, Story) that are readable by a non-technical product manager and give a
developer verifiable acceptance criteria.

Status: design approved in conversation, spec awaiting review.
Date: 2026-09-28.

---

## 1. Summary

Tickets produced today are too verbose to read. The cause is structural, not stylistic:
`stow/JIRA/SKILL.md` has **no Create workflow**. Its routing table covers Fetch, Plan,
Search, Sprint, Link and Comment. Ticket creation therefore falls through to unguided use
of the MCP `createJiraIssue` tool, and the agent invents a format every time.

The one piece of creation guidance that does exist,
`stow/TechDebt/Workflows/Create.md` Step 4, actively generates the problem. It instructs
the model to expand a one-line note into four headings, one of which is
`## Suggested Approach`.

This spec adds the missing Create workflow and three templates, governed by one rule:

> **A ticket states the desired outcome and the acceptance criteria. It never states the
> solution. Working out how is the job of whoever picks it up.**

That rule is the largest single reduction in ticket size available, because it deletes
whole sections rather than trimming sentences. The templates, the caps and the rule check
are what stop the saved space from being refilled.

### 1.1 Non-goals

- **No rewriting of tickets already in Jira.** Considered and explicitly excluded from
  scope. The backlog of existing unreadable tickets stays as it is.
- **No new skill.** This enriches `JIRA` and amends `TechDebt`. A parallel skill would
  leave the existing create paths untouched, which is the failure this spec exists to fix.
- **No change to the Comment workflow.** Its voice rules already work and this spec
  inherits them rather than restating them.
- **No template tooling.** Templates are markdown files a person can read and edit. A YAML
  plus renderer design was considered and rejected in section 8.

---

## 2. The cross-cutting rules

These apply to all three templates and are stated once, in
`stow/JIRA/Reference/TicketRules.md`, rather than repeated in each.

### R1 — Outcome, not solution

The body says what should be true when the work is done, and how you would know. It does
not say how to get there. No file paths, no function or table names, no proposed approach,
no library choices, no migration plans.

This holds for the most technical work in the backlog. A ticket about a database index is
still written as the outcome the index would produce.

R1 has support in the source material rather than being a house preference. INVEST's
*Negotiable* (Bill Wake, 2003) means a story is written at a level that invites
conversation rather than prescribing the solution, and the epic sources converge on the
same point independently.

**The one carve-out.** Where the reporter already knows a fact the implementer would
otherwise have to rediscover — a specific failing record id, a log line they have in
hand, the exact page a bug appears on — that fact belongs in the ticket. The distinction
is evidence versus instruction. "This fails for account 44182" is evidence. "Fix the
account lookup in `billing/accounts.py`" is instruction.

### R2 — Nothing that Jira has a field for

Priority, severity, labels, components, assignee, sprint, issue links, attachments and
parent all have Jira fields. None of them appear in the body.

Restating a field as prose duplicates it, and the prose copy then goes stale the first
time the field changes. Severity and priority are two distinct axes in the source material
— technical seriousness versus business urgency — and both are set as fields, not written
out.

The same reasoning removes the child-story list from the epic body: children are Jira
links, and a list in the body is wrong as soon as one is added.

### R3 — Inherited from the existing Comment workflow

`stow/JIRA/SKILL.md` already forbids em dashes and en dashes, emoji prefixes and bold
severity labels in anything written into Jira, on the grounds that tickets are frequently
customer-visible. Those rules extend unchanged to ticket bodies. They are not restated in
`TicketRules.md`; it links to them.

---

## 3. The templates

Each template lives in its own file under `stow/JIRA/Templates/`, installed to
`~/.claude/skills/JIRA/Templates/`. Caps are written beside the section they cap, so
editing a template does not mean editing skill prose.

Every section is marked required or optional. **An optional section with nothing real to
say is deleted, heading and all.** It is never filled to make the ticket look complete.

**How the word cap is counted.** Prose and bullet text only. Headings, markdown syntax,
checkbox markers, numbered-step numbers and URLs are excluded. The cap is a readability
ceiling, not an accounting exercise, so a ticket a few words over is not worth a revision
pass; one half again over the cap is.

### 3.1 Story / Task / Feature

Whole ticket: **200 words maximum.**

| Section | | Cap |
|---|---|---|
| `## What we want` | required | 3 sentences |
| `## Why it matters` | required | 2 sentences |
| `## Out of scope` | optional | 3 bullets |
| `## Acceptance criteria` | required | 7 bullets, one line each |

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

**Opener.** A plain outcome sentence, not "As a / I want / So that". See section 7.2 for
why this departs from the consensus form.

**Acceptance criteria are an observable-outcome checklist**, one line per criterion, each
a binary observable fact. Not Given/When/Then. See section 7.1.

A criterion is well formed when a person who did not write the ticket could look at the
running system and say yes or no without asking anyone. "Card validation is robust" fails
that test. "A card that fails validation leaves the existing card in place" passes it.

**Exceeding 7 criteria is a split signal, not a truncation signal.** The sources agree
that over-specifying acceptance criteria erodes negotiability and indicates the story
should be split. On overflow the workflow proposes a split and shows the proposed
division. It never silently drops a criterion, and it never quietly merges two into one
longer line.

### 3.2 Bug

Whole ticket: **200 words maximum.** Evidence links do not count toward it.

| Section | | Cap |
|---|---|---|
| `## What happens` | required | 2 sentences |
| `## What should happen` | required | 2 sentences |
| `## Steps to reproduce` | required | 6 numbered steps, from a known start state |
| `## Where it was seen` | required | 3 lines |
| `## Impact` | required | 2 sentences |
| `## Also true when fixed` | optional | 4 bullets |

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

**A bug has no separate acceptance criteria section.** "What should happen" combined with
"Steps to reproduce" *is* the acceptance criterion, and the reproducibility bar the
sources set is exactly that: a reader can reproduce the bug without asking a follow-up
question. Adding an AC section would restate those two sections in different words.

`## Also true when fixed` exists only for conditions the fix must satisfy that the repro
does not imply. Correcting data already written wrongly is the common case. If there is no
such condition, the section is deleted.

`## Where it was seen` is one line each of environment, version or build, and the account
or record involved, as far as they are known. Unknown does not mean invented: an unknown
line is omitted rather than guessed.

**No proposed fix.** No source found in the research addresses this directly, so R1
settles it rather than a cited convention. This is recorded as an assumption, not a
finding.

### 3.3 Epic

Whole epic: **250 words maximum.**

| Section | | Cap |
|---|---|---|
| `## Goal` | required | 1 sentence, an outcome not a deliverable |
| `## Why now` | required | 3 sentences |
| `## In scope` | required | 5 bullets |
| `## Out of scope` | required | 5 bullets |
| `## Done when` | required | 4 bullets, at least one measurable |
| `## Risks and dependencies` | optional | 3 bullets |

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

**`## Out of scope` is required on an epic**, where it is optional on a story. Unbounded
scope is the epic failure mode the sources name most often, and an epic with nothing
excluded is usually one nobody has bounded yet.

**`## Goal` states an outcome, not a deliverable.** "Customers manage their own payment
details" is an outcome. "Build a payment settings page" is a deliverable, and a deliverable
in the goal has already chosen the solution.

**`## Done when` carries at least one measurable bullet.** The sources distinguish outcome
metrics from output metrics and are clear that an epic needs the former. A number that
already exists is preferred over one that would have to be invented to satisfy the rule;
where no number is available, a binary observable statement is accepted and the workflow
says so rather than fabricating a target.

Child stories do not appear in the body, per R2.

---

## 4. The Create workflow

New file `stow/JIRA/Workflows/Create.md`. New row in the `SKILL.md` routing table:

| Workflow | Trigger | Description |
|----------|---------|-------------|
| **Create** | "create a ticket", "raise a bug", "new story", "create an epic" | Render a template, check it, create via MCP `createJiraIssue`. See Create Workflow |

### 4.1 Choosing the template

| Signal in the request | Template |
|---|---|
| Something used to work, or behaves differently from what was expected | Bug |
| A body of work spanning several tickets, or the words epic, initiative, programme | Epic |
| Anything else: new behaviour, a change, a chore, tech debt | Story |

Where two could apply, the workflow names its choice in one line and continues. It does
not ask. A wrong guess costs one correction; a question costs an interruption every time.

### 4.2 Filling the template

1. Map what the user actually said onto the template's sections.
2. Delete every optional section with nothing real to say.
3. For required sections with nothing to say, collect **one** batched `AskUserQuestion`
   covering all of them at once.
4. Cut each section to its cap.
5. Run the rule check in section 5.
6. Show the rendered ticket in the conversation and get approval.
7. Create it via MCP `createJiraIssue` with `contentFormat: "markdown"`.

**Inference and expansion are banned.** The workflow never infers, expands, or pads a
section to make a ticket look complete. This is the single most important behavioural
change in the spec: unguided expansion is what produces today's unreadable tickets, and
every other measure here is downstream of stopping it.

Step 6 is a hard gate, consistent with the existing Comment workflow, which requires a
draft and approval before anything is written into Jira. A ticket notifies watchers and
cannot be quietly withdrawn.

### 4.3 Required Jira fields

Before building the payload, call `getJiraIssueTypeMetaWithFields` for the project and
issue type. Projects carry mandatory custom fields, and a missing one fails with an error
naming a field id and nothing else. Anything flagged required and not already known is
asked about once, by its display name. No value is invented for a required custom field,
and no field id is carried over from another project.

This mirrors what `TechDebt/Workflows/Create.md` already does and is stated here so the
JIRA workflow does not have to depend on TechDebt being read first.

### 4.4 Epic with child stories

Triggered by an epic request that also describes the work beneath it.

1. Render and create the epic, per 4.2.
2. Propose child stories **in the conversation only**, as titles plus a one-line outcome
   each. No story is created at this point.
3. The user cuts, edits and approves the list.
4. Render each approved story in full, per 4.2, and show them.
5. Create only the approved stories, each with `parent` set to the epic key.

**No child is ever created that the user has not seen.** Proposing children is where an
agent is most tempted to invent scope to fill out a list, so the proposal stage is
deliberately cheap — a title and one line — which makes cutting easy and makes invented
children obvious.

If the user approves the epic but not the children, the epic stands alone. That is a
normal outcome, not a failure.

---

## 5. The rule check

New file `stow/JIRA/Reference/RuleCheck.md`: a checklist the workflow runs against its own
draft before step 6 of 4.2. It is written as an inspectable markdown checklist rather than
code, matching how the rest of this repo states its contracts.

Run against the rendered body:

- [ ] Every section is within its stated cap
- [ ] The whole ticket is within its word cap
- [ ] Every required section is present and says something real
- [ ] No optional section is present with filler in it
- [ ] No solution language: file paths, function or table names, a proposed approach, a
      named library, an instruction to use or refactor or add something
- [ ] Nothing that belongs in a Jira field appears in the body (R2)
- [ ] No em dash or en dash anywhere
- [ ] No emoji prefix and no bold severity label
- [ ] Acceptance criteria, where present, are each observable and binary
- [ ] Acceptance criteria are at the bottom of the ticket

**A failed check means revise and re-check. It never means create anyway.** A check that
fails twice on the same item is surfaced to the user with the offending text quoted,
rather than attempted a third time.

The solution-language check is the one most likely to produce false positives, because
evidence and instruction can look alike. The carve-out in R1 governs: a fact the reporter
already holds is evidence and stays; a direction to the implementer is instruction and
goes. Where the check is unsure, it quotes the line and asks rather than deleting silently.

---

## 6. The TechDebt change

`stow/TechDebt/Workflows/Create.md` Step 4 currently reads, in part:

```
Use this exact structure:
## Problem
## Why It Matters
## Suggested Approach
## Context
```

This is the verbosity generator, and `## Suggested Approach` prescribes the solution
directly. Left in place it would contradict R1 from a skill sitting next to the one that
states it.

Step 4 is replaced by: render `~/.claude/skills/JIRA/Templates/Story.md`, then run
`~/.claude/skills/JIRA/Reference/RuleCheck.md`.

The mapping is close to lossless:

| Old heading | Becomes |
|---|---|
| `## Problem` | `## What we want`, restated as the desired end state |
| `## Why It Matters` | `## Why it matters` |
| `## Suggested Approach` | **deleted** |
| `## Context` | evidence only, under R1's carve-out, or deleted |

`## What we want` needs the restatement because tech debt is naturally described as a
complaint, and a complaint is not an outcome. "The UsersTable duplicates logic from the SP
portal" becomes "The PX portal users table uses the shared component, so a change to it
takes effect in both portals."

Tech debt notes routinely name files, and R1's carve-out covers them: a named file the
reporter already knows about is evidence of where the problem lives. What goes is the
instruction about what to do with it.

Everything else in TechDebt is unchanged. Duplicate detection, the required-fields check,
the fixability assessment and the worktree offer all still work and are not touched.

---

## 7. Where this departs from the sources

Both departures are deliberate and recorded here so they are not mistaken for oversights.

### 7.1 Acceptance criteria are a checklist, not Given/When/Then

Given/When/Then is the most common form in every source consulted. This spec uses a plain
observable checklist instead.

Given/When/Then spends three lines on what the checklist says in one, and its precondition
clause is redundant for the majority of criteria, where there is no meaningful
precondition. Since unreadable length is the problem this spec exists to solve, and since
the same information survives the compression, the checklist wins.

What is genuinely lost: where behaviour really does depend on a precondition, the
checklist has to fold it into the sentence ("A customer **with a saved card** can..."),
which is less rigorous than naming it separately. That is an accepted cost.

### 7.2 The story opener is a plain sentence, not "As a / I want / So that"

Every source consulted still teaches the As-a form, and none of them describes it as
dated.

It is dropped because a large share of the tickets this skill will produce have no end
user: tech debt, infrastructure, internal tooling. The As-a form forces an invented
persona onto that work ("As a developer, I want..."), and an invented persona is exactly
the kind of filler this spec is trying to remove.

What the As-a form is genuinely good at is forcing the author to say *who* benefits and
*why*. `## Why it matters` is required precisely to keep that, and it applies to
user-facing and internal work alike.

---

## 8. Alternatives considered

**Templates as YAML plus a renderer.** Would make the caps machine-checkable and give the
rule check real enforcement instead of instructions. Rejected because it adds a parse and
render step to a repo that is otherwise plain-markdown skills, and because the template
stops being readable at a glance by the person who most needs to edit it.

**All three templates inside one `Workflows/Create.md`.** Fewest files. Rejected because
TechDebt would have to cite a section heading rather than a file path, and because the
rule check would have no single artifact to point at.

**A workflow to tighten tickets already in Jira.** Genuinely useful against the existing
backlog. Excluded from scope to keep this spec to one implementation plan. It is the
natural follow-on, and the templates and rule check are the prerequisites for it.

**Asking about every missing section.** Most thorough, and rejected: it turns a one-line
bug capture into a five-question interview, which means it gets abandoned mid-flow and the
skill goes unused.

---

## 9. Files

| File | Change |
|---|---|
| `stow/JIRA/SKILL.md` | Add the Create row to the routing table; link `Reference/TicketRules.md` |
| `stow/JIRA/Reference/TicketRules.md` | New: R1, R2, and the link to the existing voice rules |
| `stow/JIRA/Templates/Story.md` | New |
| `stow/JIRA/Templates/Bug.md` | New |
| `stow/JIRA/Templates/Epic.md` | New |
| `stow/JIRA/Workflows/Create.md` | New: template choice, fill, required fields, epic with children |
| `stow/JIRA/Reference/RuleCheck.md` | New: the pre-creation checklist |
| `stow/TechDebt/Workflows/Create.md` | Replace Step 4 with a call to the Story template and rule check |
| `tests/install.test.sh` | Extend if the new directories need install coverage |

---

## 10. How this is verified

The templates are prose, so verification is by worked example rather than by test suite.

1. **A verbose ticket, rewritten.** Take one real unreadable ticket, render it through the
   Story template, and put the before and after side by side. This is the spec's primary
   evidence and belongs in the implementation plan as a deliverable.
2. **The non-technical reader test.** Every section of every template is readable by
   someone who does not know the codebase. A section that cannot pass this without naming
   a file or a function has failed R1, not the reader.
3. **The developer test.** A developer reading only the acceptance criteria knows what to
   build and knows when to stop.
4. **The reproducibility test.** A bug ticket lets a second person reproduce the bug
   without asking a follow-up question.
5. **The rule check runs against its own examples.** Every worked example in every
   template file passes `RuleCheck.md`. An example that violates the rules it illustrates
   is worse than no example.
6. **`bash tests/install.test.sh` passes**, currently 28 tests.

---

## 11. Sources

**Epic**
- https://www.atlassian.com/agile/tutorials/epics
- https://www.aha.io/roadmapping/guide/agile/agile-epics-explained
- https://www.bridging-the-gap.com/epic-in-agile/

**Bug**
- https://www.atlassian.com/software/jira/templates/bug-report
- https://www.browserstack.com/guide/how-to-write-a-bug-report
- https://www.qawolf.com/blog/what-makes-a-great-bug-report

**Story and acceptance criteria**
- https://www.atlassian.com/agile/project-management/user-stories
- https://platinumedge.com/the-invest-criteria-creating-powerful-user-stories

Research was deliberately bounded to one pass per template. URLs came from search results
and were not independently fetched, so they are cited for their consensus position rather
than for exact wording.
