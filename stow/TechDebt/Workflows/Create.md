# TechDebt — Create Workflow

Log a tech debt ticket without breaking flow. Checks for duplicates, renders the Story
template, creates the ticket, opens it.

---

## Step 0 — Load config and resolve the site

```
Read ~/.claude/techdebt/config.json  →  PROJECT, BOARD_ID, PARENT_EPIC,
                                        ISSUE_TYPE, PRIORITY
```

If the file does not exist, run the first-run flow in `Reference/Setup.md`: ask
which project, epic and board, then write it. Do not guess a project and do not
fail — a missing config is a normal first use.

`BOARD_ID` and `PARENT_EPIC` are both optional. Without a board, duplicate
detection searches the project by JQL. Without an epic, the `parent` and Epic
Link fields are omitted from creation rather than sent empty.

Then resolve, via the Atlassian MCP:

| Value | Call |
|-------|------|
| `JIRA_SITE`, `cloudId` | `getAccessibleAtlassianResources` |
| Assignee account id | `atlassianUserInfo` |
| Issue type id for `ISSUE_TYPE` | `getJiraProjectIssueTypesMetadata` on `PROJECT` |

Resolving ids per project each run is deliberate. Ids are not portable between
projects, and a stale one fails at creation with an error that does not say why.

---

## Step 1 — Parse Input

Extract the description from the skill arguments.

If no description provided, use AskUserQuestion:
```
"What's the tech debt? A sentence is enough; I will not pad it out."
```

---

## Step 2 — Fetch Open Tech Debt Tickets (Titles Only)

Fetch open issues for duplicate checking. **Titles only** — cheap and
token-efficient.

With a board configured, read the board. Without one, search the project:

```
searchJiraIssuesUsingJql
  jql:    project = {PROJECT} AND statusCategory != Done ORDER BY created DESC
  fields: ["summary", "status"]
```

Page with `nextPageToken` rather than assuming everything fits one response — a
long-lived tech debt project outgrows any single page eventually.
  -o /tmp/td_issues.json

python3 << 'EOF'
import json
with open('/tmp/td_issues.json') as f:
    d = json.load(f)
open_issues = [
    {'key': i['key'], 'summary': i['fields']['summary'], 'status': i['fields']['status']['name']}
    for i in d.get('issues', [])
    if i['fields']['status']['statusCategory']['key'] != 'done'
]
print(json.dumps(open_issues))
EOF
```

---

## Step 3 — Duplicate Detection

Perform a keyword overlap scan against the fetched titles.

**Algorithm (run in Python or inline logic):**
1. Tokenise both the user's description and each ticket title: lowercase, split on spaces/punctuation, remove stop words (`the`, `a`, `an`, `to`, `in`, `of`, `for`, `and`, `or`, `is`, `are`, `with`, `on`, `at`, `from`)
2. Compute overlap: `len(description_tokens ∩ ticket_tokens) / len(description_tokens)`
3. Flag any ticket with overlap **≥ 0.35** as a potential duplicate

**If potential duplicates found (≥ 1 match):**

Show the matches, then use AskUserQuestion:
```
Question: "Found {N} possible duplicate(s) before creating — want to review them?"

Matches shown as:
  {KEY}: {summary} ({status})
  {KEY2}: {summary} ({status})

Options:
  A) Dive in    — fetch full description of top match(es) and show me
  B) Proceed    — they look different enough, create the ticket anyway
  C) Cancel     — I'll update an existing ticket manually
```

**If "Dive in"** → fetch and show the description of the top 1-2 matches:

```
getJiraIssue
  issueIdOrKey:          {KEY}
  fields:                ["summary", "description", "status"]
  responseContentFormat: "markdown"
```

Ask for `markdown` rather than `adf` and Jira does the flattening for you. Then
ask again:
```
"Having seen the detail — still want to create a new ticket, or does {KEY} cover it?"
Options: Create new | Link to existing and cancel
```

**If no duplicates:** Proceed silently.

---

## Step 4 — Render the Story template

Tech debt is a story. Render `~/.claude/skills/JIRA/Templates/Story.md` against the user's
note, then run `~/.claude/skills/JIRA/Reference/RuleCheck.md` against the result.

Do not expand the note. A one-line note becomes a short ticket, and that is the correct
outcome. The old behaviour here was to grow a note into four headings, one of which
proposed the fix; that is what made these tickets unreadable.

**`## What we want` needs the note restated as an end state.**
Tech debt arrives as a complaint, and a complaint is not an outcome.

- As reported: "The UsersTable in the PX portal duplicates logic from the SP portal."
- As the ticket: "The PX portal users table uses the shared component, so a change to it
  takes effect in both portals."

**Named files stay.** A tech debt note almost always names where the problem lives, and
that is evidence the reporter already holds, not an instruction. R1's carve-out covers it.
What goes is the direction about what to do: "should use the shared generic UsersTable
from packages/ui" is an instruction and is dropped, while the fact that the duplication
exists between those two portals is kept.

**`## Acceptance criteria` is required**, as it is for any story. For tech debt the
criteria are usually about behaviour that must not change: the same rows render, the same
permissions apply, the existing tests still pass.

**Where a failed rule check lands here.** `RuleCheck.md` says to run before showing the
draft to the user, and this workflow deliberately never shows one: the whole point is not
to break your flow. So the rule for TechDebt specifically is that a twice-failed item is
reported alongside the created ticket, in the step 8 output, rather than blocking
creation or inventing an interruption.

That is the right trade here and not elsewhere. A tech debt ticket is internal, cheap to
edit, and already opens in the browser at step 6, so you see the flagged line seconds
later. The `JIRA` Create workflow, which can raise customer-visible tickets, keeps the
blocking behaviour.

---

## Step 5 — Create the Jira Ticket

Check what the project actually requires before building the payload. Projects
carry mandatory custom fields, and a missing one fails with an error that names a
field id and nothing else:

```
getJiraIssueTypeMetaWithFields
  projectIdOrKey: {PROJECT}
  issueTypeId:    {resolved in step 0}
```

Anything flagged required and not yet known gets asked about once, by its display
name. Never invent a value for a required custom field, and never carry a field
id from another project.

Then create it:

```
createJiraIssue
  projectKey:  {PROJECT}
  issueTypeName: {ISSUE_TYPE}
  summary:     first 255 chars of the description, first letter capitalised
  description: the rendered Story template from step 4
  additional_fields:
    priority: {name: PRIORITY}
    assignee: {id: <account id from atlassianUserInfo>}
    parent:   {key: PARENT_EPIC}      ← omit the key entirely when unset
```

Send `parent` only when an epic is configured. Sending it as null or an empty
string is rejected, and sending a legacy Epic Link field alongside is only needed
on projects that still have one — check the metadata above rather than assuming.

`createJiraIssue` returns the new key. Build the link from it and the site
resolved in step 0:

```bash
TICKET_URL="${JIRA_SITE}/browse/${TICKET_KEY}"
```

---

## Step 6 — Open Ticket in Browser

```bash
open "${TICKET_URL}"        # macOS; xdg-open elsewhere
```

---

## Step 6b — Add Issue Links (when creating phased/related tickets)

When creating a group of tickets that represent phases or sequential work (e.g. "Phase 1, Phase 2, Phase 3..."), add `blocked_by` relationships from the parent/umbrella ticket to each phase ticket using the Jira CLI:

```bash
bun ~/.claude/skills/JIRA/Tools/Jira.ts link <UMBRELLA_TICKET> blocked_by <PHASE_TICKET>
```

This makes the dependency chain visible in Jira. Do this for:
- Phase tickets: umbrella `blocked_by` each phase (umbrella only closes when all phases done)
- Sequential phases: phase N+1 `blocked_by` phase N (enforces order)
- Any ticket explicitly described as "depends on" another

**Relationship enum** (see `Jira.ts link` command — issue linking fallback, pending MCP support):
`blocks | blocked_by | duplicates | duplicated_by | relates_to | tests | tested_by | split_to | split_from`

---

## Step 7 — Fixability Assessment

After creating the ticket, assess whether there's enough context to fix it right now via a Worktree spin-up.

**Score the user's original note against these signals, not the rendered ticket.**
R1 strips file paths and the approach out of the ticket body, so scoring the ticket would
drive almost everything to Design needed and quietly stop the worktree offer firing. The
note still holds what these signals measure.

Signals:

| Signal | Weight |
|--------|--------|
| Specific file path(s) mentioned or inferable | +2 |
| Change is clearly bounded (one component, one file, one pattern) | +2 |
| Approach is unambiguous (one obvious way to fix it) | +2 |
| No design decision or team discussion required | +1 |
| No cross-service dependencies or migrations needed | +1 |
| Low risk of regressions (isolated change) | +1 |
| Unclear location ("somewhere in the codebase") | -2 |
| Multiple valid approaches that need discussion | -2 |
| Requires schema/migration changes | -1 |
| Touches shared packages used across many apps | -1 |

**Rating tiers:**
- **🟢 Fix it now** (score ≥ 5): enough context, bounded change — Worktree prompt
- **🟡 Investigate first** (score 2–4): approach is clear but needs a little exploration before coding
- **🔴 Design needed** (score ≤ 1): ambiguous, architectural, or cross-team — log it and move on

Output the rating inline in the report, with 1-2 sentences of reasoning.

**If 🟢:** use AskUserQuestion:
```
Question: "This looks fixable right now — want me to spin it up?"
Options:
  A) Yes, spin up worktree  — invoke /Worktree {TICKET_KEY} immediately
  B) Not now               — leave the ticket for later
```
If the user says yes → invoke the Worktree skill: read `~/.claude/skills/Worktree/SKILL.md` and execute the Single workflow for `{TICKET_KEY}`.

---

## Step 8 — Report

Output the report using clickable OSC 8 hyperlinks for the ticket URL and board URL:

```bash
BOARD_URL="${JIRA_SITE}/jira/software/c/projects/${PROJECT}/boards/${BOARD_ID}"   # omitted when no board is configured

echo "✓ Created: ${TICKET_KEY}"
printf '  \e]8;;%s\e\\%s\e]8;;\e\\\n' "${TICKET_URL}" "${TICKET_URL}"
echo ""
echo "  \"${SUMMARY}\""
echo ""
echo "  Tech Debt Board:"
printf '  \e]8;;%s\e\\%s\e]8;;\e\\\n' "${BOARD_URL}" "${BOARD_URL}"
echo ""
echo "Opening in browser — review and edit the description if needed."
```

Then output the fixability rating inline:

```
{FIXABILITY_RATING_EMOJI} Fixability: {Fix it now | Investigate first | Design needed}
  {1-2 sentence reasoning}
{If 🟢: "→ Want to fix this now? I can spin up a worktree."}
```

---

## Error Handling

| Situation | Action |
|-----------|--------|
| Jira API fails | Show the raw error response and the equivalent call the user can run manually |
| Rule check fails twice on the same item | Quote the offending line and ask the user |
| `open` not available | Print URL prominently with a reminder to open manually |
| Duplicate found, user cancels | Report the existing ticket key and URL so they can add a comment instead |
