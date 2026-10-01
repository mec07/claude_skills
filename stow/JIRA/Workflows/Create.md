# JIRA Create Workflow

Create a ticket that a non-technical reader can understand and a developer can verify.

Read first: `../Reference/TicketRules.md`. Everything below assumes R1, R2 and R3.

---

## Step 1: Choose the template

| Signal in the request | Template |
|---|---|
| Something used to work, or behaves differently from what was expected | `../Templates/Bug.md` |
| A body of work spanning several tickets, or the words epic, initiative, programme | `../Templates/Epic.md` |
| Anything else: new behaviour, a change, a chore, tech debt | `../Templates/Story.md` |

Where two could apply, the workflow **names its choice in one line and continues**. It does
not ask. A wrong guess costs one correction; a question costs an interruption every time.

**When both signals fire on the same single ask, choose Bug.** "Search used to be fast and
now it times out, we should paginate" is one request that reads as a regression and as new
work, with nothing to separate. Bug is the narrower claim and the cheaper commitment to
undo: if it turns out nothing regressed, the ticket becomes a story with its repro intact,
whereas a story raised for a regression has already discarded the repro.

**Worked case, an ambiguous request.** "The export used to include archived rows and now it
does not, and while we are there it should also do CSV." That is a regression and a feature
request. Say: "Raising this as a bug about the archived rows. The CSV request needs its own
story, say the word." Then create the bug. Do not create both without being asked, and do
not silently fold the feature into the bug.

---

## Step 2: Fill the template

1. Map what the user actually said onto the template's sections.
2. Delete every optional section with nothing real to say.
3. For required sections with nothing to say, collect **one batched** `AskUserQuestion`
   covering all of them at once.
4. Cut each section to its cap.

**The workflow never infers, expands, or pads a section to make a ticket look complete.**
This is the most important rule in this file. Unguided expansion is what makes tickets
unreadable, and every other measure here is downstream of stopping it.

A one-line note becomes a short ticket. That is the correct outcome, not a deficiency to
be corrected by writing more.

**Worked case, more criteria than the cap.** The user gives nine acceptance criteria for
one story. Do not truncate to seven, and do not merge two into one longer line.
**Propose the split**: show two stories with the criteria divided between them, and say
which criteria went where. The user approves, redraws the line, or says keep it as one.
Over-specifying acceptance criteria erodes negotiability, and nine criteria is usually two
stories that have not been separated yet.

If the user says keep it as one, that settles it. The rule check does not then fail the
ticket on the cap, per the explicit-keep clause in `../Reference/RuleCheck.md`. Name it as
a judgement call at step 4 and create the ticket.

---

## Step 3: Run the rule check

Run `../Reference/RuleCheck.md` against the rendered body. A failure means revise and run
it again. It never means create anyway.

---

## Step 4: Show it and get approval

Show the rendered ticket in the conversation **before creating anything**. A ticket
notifies watchers and cannot be quietly withdrawn, which is the same reason the Comment
workflow requires a draft first.

Name any judgement call the draft makes, so that keeping it is the user's decision rather
than a default.

---

## Step 5: Check the required Jira fields

```
getJiraIssueTypeMetaWithFields
  projectIdOrKey: {PROJECT}
  issueTypeId:    {resolved for this project and issue type}
```

Projects carry mandatory custom fields, and a missing one fails with an error that names a
field id and nothing else.

Anything flagged required and not already known is asked about once, by its display name.
**Never invent a value for a required custom field**, and never carry a field id from
another project: ids are not portable, and a stale one fails without saying why.

---

## Step 6: Create it

```
createJiraIssue
  projectKey:    {PROJECT}
  issueTypeName: {Bug | Epic | Story, or the project's equivalent}
  summary:       one line, sentence case, no trailing full stop
  description:   the rendered body
  contentFormat: "markdown"
  additional_fields:
    priority, labels, components, assignee, parent as applicable
```

Everything in `additional_fields` is a field, per R2, and none of it is repeated in the
body.

---

## Step 7: Epic with child stories

Triggered by an epic request that also describes the work beneath it.

1. Render and create the epic, per steps 1 to 6.
2. Propose child stories **in the conversation only**, as a title plus a one-line outcome
   each. Create nothing at this point.
3. The user cuts, edits and approves the list.
4. Render each approved story in full, per steps 2 to 5, and show them.
5. Create only the approved stories, each with `parent` set to the epic key.

**No child is ever created that the user has not seen.** Proposing children is where an
agent is most tempted to invent scope to fill a list, so the proposal stage is deliberately
cheap: a title and one line. That makes cutting easy and makes an invented child obvious.

**Worked case, every child rejected.** The user approves the epic and cuts all six proposed
stories. The epic **stands alone**. That is a normal outcome, not a failure, and it usually
means the epic was worth capturing before its breakdown was understood. Do not propose a
replacement set unless asked.

---

## Error handling

| Situation | Action |
|-----------|--------|
| Rule check fails twice on the same item | Quote the offending line and ask the user |
| Required custom field unknown | Ask once by display name; never invent a value |
| `createJiraIssue` fails | Show the raw error and the equivalent call to run manually |
| User rejects the draft | Revise from their words; do not start over from the brief |
