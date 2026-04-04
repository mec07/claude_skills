# TechDebt — Create Workflow

Log a tech debt ticket without breaking flow. Checks for duplicates, expands the description, creates the ticket, opens it.

---

## Step 1 — Parse Input

Extract the description from the skill arguments.

If no description provided, use AskUserQuestion:
```
"What's the tech debt? (brief description — I'll expand it into a proper ticket)"
```

---

## Step 2 — Fetch Open Tech Debt Tickets (Titles Only)

Fetch all non-Done issues from the Tech Debt Board for duplicate checking.
**Titles only** — cheap, token-efficient.
Note: board currently has ~375 issues, all fit in one page at `maxResults=500`. If board grows past 500, add `startAt` pagination.

```bash
JIRA_API_TOKEN=$(sed -n 's/^JIRA_API_TOKEN=//p' ~/.claude/.env)
JIRA_EMAIL=$(sed -n 's/^JIRA_EMAIL=//p' ~/.claude/.env)

# Save to temp file — avoids shell escaping != as \!= in python3 -c "..." inline scripts
curl -s -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  "https://powerx.atlassian.net/rest/agile/1.0/board/361/issue?maxResults=500&fields=summary,status" \
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
  DEV-XXXX: {summary} ({status})
  DEV-YYYY: {summary} ({status})

Options:
  A) Dive in    — fetch full description of top match(es) and show me
  B) Proceed    — they look different enough, create the ticket anyway
  C) Cancel     — I'll update an existing ticket manually
```

**If "Dive in"** → fetch and show description of the top 1-2 matches:
```bash
curl -s -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  "https://powerx.atlassian.net/rest/api/3/issue/DEV-XXXX?fields=summary,description,status"
```
Convert ADF description to plain text (extract `text` fields recursively). Then ask again:
```
"Having seen the detail — still want to create a new ticket, or does DEV-XXXX cover it?"
Options: Create new | Link to existing and cancel
```

**If no duplicates:** Proceed silently.

---

## Step 4 — Expand Description with AI

Use inference to turn Fred's quick note into a structured ticket description.

```bash
EXPANDED=$(echo "Turn this brief tech debt note into a well-structured Jira ticket description.

Use this exact structure:
## Problem
[1-3 sentences: what is wrong, where it lives in the codebase]

## Why It Matters
[1-2 sentences: impact on maintainability, reliability, or developer experience]

## Suggested Approach
[2-4 bullet points: concrete steps to address it]

## Context
[Any relevant file paths, components, or patterns involved — or omit if not obvious from the note]

Keep it concise and technical. Do not invent specifics not implied by the note.

Note: ${USER_DESCRIPTION}" | bun ~/.claude/skills/PAI/Tools/Inference.ts standard)
```

---

## Step 5 — Create the Jira Ticket

Build the ADF description payload and create the issue.

```bash
JIRA_API_TOKEN=$(sed -n 's/^JIRA_API_TOKEN=//p' ~/.claude/.env)
JIRA_EMAIL=$(sed -n 's/^JIRA_EMAIL=//p' ~/.claude/.env)

# Build summary: capitalise first letter, truncate at 255 chars
SUMMARY="${USER_DESCRIPTION:0:255}"

# Convert expanded markdown to ADF (use paragraph blocks — sufficient for Jira)
python3 - <<'PYEOF'
import json, sys, os

expanded = os.environ.get('EXPANDED', '')

# Build ADF content: split into paragraphs by blank lines
paragraphs = [p.strip() for p in expanded.split('\n\n') if p.strip()]
content = []
for p in paragraphs:
    content.append({
        "type": "paragraph",
        "content": [{"type": "text", "text": p}]
    })

adf = {"type": "doc", "version": 1, "content": content}

payload = {
    "fields": {
        "project": {"key": "DEV"},
        "issuetype": {"id": "10022"},   # Story
        "summary": os.environ.get('SUMMARY', ''),
        "description": adf,
        "priority": {"id": "5"},        # Lowest
        "assignee": {"id": "712020:4b8d9734-1d88-42e4-a553-37ebedd98c6f"},
        "customfield_10319": {"id": "10993"},  # Type: Non Functional/Tech Debt (required field)
        "parent": {"key": "DEV-5478"},         # Epic: Work Order Management - Tech Debt
        "customfield_10014": "DEV-5478"        # Epic Link (legacy field — both required)
    }
}

print(json.dumps(payload))
PYEOF
```

Then POST:
```bash
RESPONSE=$(curl -s -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  -X POST \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}" \
  "https://powerx.atlassian.net/rest/api/3/issue")

TICKET_KEY=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['key'])" 2>/dev/null)
TICKET_URL="https://powerx.atlassian.net/browse/${TICKET_KEY}"
```

---

## Step 6 — Open Ticket in Browser

```bash
open "${TICKET_URL}"
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

**Score the description against these signals:**

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
If Fred says yes → invoke the Worktree skill: read `~/.claude/skills/Worktree/SKILL.md` and execute the Single workflow for `{TICKET_KEY}`.

---

## Step 8 — Report

Output the report using clickable OSC 8 hyperlinks for the ticket URL and board URL:

```bash
BOARD_URL="https://powerx.atlassian.net/jira/software/c/projects/DEV/boards/361"

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
| Jira API fails | Show raw error response, provide `curl` command Fred can run manually |
| Inference fails | Use Fred's raw description as the ticket description (unformatted) |
| `open` not available | Print URL prominently with a reminder to open manually |
| Duplicate found, Fred cancels | Report the existing ticket key and URL so Fred can add a comment instead |
