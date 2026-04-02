---
name: Jira
description: Jira ticket access via REST API. USE WHEN jira, ticket, issue, DEV-, sprint, board, backlog, create plan, fetch ticket, ticket details, story points, acceptance criteria.
---

# Jira

PowerX Jira integration via REST API v3. Fetches tickets, parses Atlassian Document Format descriptions, and supports plan creation from tickets.

## Configuration

- **API Token:** `~/.claude/.env` -> `JIRA_API_TOKEN`
- **Email:** `~/.claude/.env` -> `JIRA_EMAIL`
- **Base URL:** `~/.claude/.env` -> `JIRA_BASE_URL`
- **Project Key:** `DEV`

## Token Extraction (CRITICAL)

The JIRA_API_TOKEN contains `=` characters. **NEVER use `cut -d=`** — it truncates the token.

**Always use this pattern:**
```bash
JIRA_API_TOKEN=$(sed -n 's/^JIRA_API_TOKEN=//p' ~/.claude/.env)
JIRA_EMAIL=$(sed -n 's/^JIRA_EMAIL=//p' ~/.claude/.env)
JIRA_BASE_URL=$(sed -n 's/^JIRA_BASE_URL=//p' ~/.claude/.env)
```

## Authentication

Basic auth with email:token pair:
```bash
curl -s -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  -H "Content-Type: application/json" \
  "${JIRA_BASE_URL}/rest/api/3/issue/DEV-6156"
```

## ADF Description Parsing

Jira returns descriptions in Atlassian Document Format (JSON). Convert to readable markdown:

```bash
# Fetch ticket and parse description to markdown in one go:
JIRA_API_TOKEN=$(sed -n 's/^JIRA_API_TOKEN=//p' ~/.claude/.env)
JIRA_EMAIL=$(sed -n 's/^JIRA_EMAIL=//p' ~/.claude/.env)
JIRA_BASE_URL=$(sed -n 's/^JIRA_BASE_URL=//p' ~/.claude/.env)

curl -s -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  "${JIRA_BASE_URL}/rest/api/3/issue/ISSUE-KEY" | \
  python3 -c "
import json, sys

def adf_to_md(node, depth=0):
    if not node or not isinstance(node, dict):
        return ''
    t = node.get('type', '')
    content = node.get('content', [])
    text = node.get('text', '')
    marks = node.get('marks', [])
    attrs = node.get('attrs', {})
    result = ''

    # Apply marks
    for mark in marks:
        mt = mark.get('type', '')
        if mt == 'strong': text = f'**{text}**'
        elif mt == 'em': text = f'*{text}*'
        elif mt == 'code': text = f'\`{text}\`'
        elif mt == 'link': text = f'[{text}]({mark.get(\"attrs\", {}).get(\"href\", \"\")})'

    if t == 'text': return text
    elif t == 'hardBreak': return '\n'
    elif t == 'paragraph':
        inner = ''.join(adf_to_md(c, depth) for c in content)
        return inner + '\n\n'
    elif t == 'heading':
        level = attrs.get('level', 1)
        inner = ''.join(adf_to_md(c, depth) for c in content)
        return '#' * level + ' ' + inner + '\n\n'
    elif t == 'bulletList':
        return ''.join(adf_to_md(c, depth) for c in content)
    elif t == 'orderedList':
        return ''.join(adf_to_md(c, depth) for c in content)
    elif t == 'listItem':
        inner = ''.join(adf_to_md(c, depth+1) for c in content).strip()
        return '  ' * depth + '- ' + inner + '\n'
    elif t == 'codeBlock':
        lang = attrs.get('language', '')
        inner = ''.join(adf_to_md(c, depth) for c in content)
        return f'\`\`\`{lang}\n{inner}\`\`\`\n\n'
    elif t == 'blockquote':
        inner = ''.join(adf_to_md(c, depth) for c in content)
        return '> ' + inner.replace('\n', '\n> ') + '\n\n'
    elif t == 'rule': return '---\n\n'
    elif t == 'table':
        rows = [adf_to_md(c, depth) for c in content]
        return ''.join(rows) + '\n'
    elif t == 'tableRow':
        cells = [adf_to_md(c, depth).strip() for c in content]
        return '| ' + ' | '.join(cells) + ' |\n'
    elif t in ('tableCell', 'tableHeader'):
        return ''.join(adf_to_md(c, depth) for c in content)
    elif t == 'mediaSingle' or t == 'media':
        return '[media attachment]\n\n'
    elif t == 'inlineCard':
        url = attrs.get('url', '')
        return f'[{url}]({url})'
    elif t == 'doc':
        return ''.join(adf_to_md(c, depth) for c in content)
    else:
        return ''.join(adf_to_md(c, depth) for c in content)

data = json.load(sys.stdin)
fields = data.get('fields', {})
summary = fields.get('summary', 'No summary')
status = fields.get('status', {}).get('name', 'Unknown')
assignee = (fields.get('assignee') or {}).get('displayName', 'Unassigned')
priority = (fields.get('priority') or {}).get('name', 'None')
issue_type = (fields.get('issuetype') or {}).get('name', 'Unknown')
story_points = fields.get('customfield_10016', 'N/A')
labels = ', '.join(fields.get('labels', [])) or 'None'
desc = fields.get('description')
desc_md = adf_to_md(desc) if desc else 'No description'

# Subtasks
subtasks = fields.get('subtasks', [])
subtask_md = ''
if subtasks:
    subtask_md = '\n## Subtasks\n\n'
    for st in subtasks:
        st_key = st.get('key', '')
        st_summary = st.get('fields', {}).get('summary', '')
        st_status = st.get('fields', {}).get('status', {}).get('name', '')
        subtask_md += f'- [{st_key}] {st_summary} ({st_status})\n'

print(f'# {data.get(\"key\", \"\")} — {summary}')
print(f'\n**Type:** {issue_type} | **Status:** {status} | **Priority:** {priority}')
print(f'**Assignee:** {assignee} | **Story Points:** {story_points} | **Labels:** {labels}')
print(f'\n## Description\n\n{desc_md}')
if subtask_md: print(subtask_md)
"
```

## Workflow Routing

| Workflow | Trigger | Description |
|----------|---------|-------------|
| **Fetch** | "fetch ticket", "get DEV-XXXX", "show issue", ticket URL | Fetch and display a single ticket |
| **Plan** | "create plan for DEV-XXXX", "plan from ticket" | Fetch ticket + create implementation plan |
| **Search** | "find tickets", "search jira", "my tickets" | JQL search |
| **Sprint** | "current sprint", "sprint board", "what's in sprint" | Active sprint tickets |

## Fetch Workflow

1. Extract issue key from user input (e.g., `DEV-6156` from URL or text)
2. Run the API call with ADF parsing (see above)
3. Display formatted output

## Plan Workflow

### Plan File Naming Convention (CRITICAL)

**Filename format:** `DEV-{number}-plan.scratch.md`
- Example: `DEV-6156-plan.scratch.md`, `DEV-6158-plan.scratch.md`
- `.scratch.md` extension ensures files are gitignored
- **NEVER** use `PLAN-DEV-` prefix or `.md` without `.scratch`

**Placement rule:** Place the plan in the **parent-most folder in the monorepo** that the ticket refers to.
- If ticket references `data/hasura/metadata` and `data/application-db/migrations` → plan goes in `data/` (the parent-most common folder)
- If ticket references `data/auth-api/src/...` → plan goes in `data/auth-api/`
- **NEVER** place plans in the repo root — always in the relevant sub-project folder
- Monorepo root is `/Users/freddylem/dev/powerx/data/`, sub-projects live under `data/`, `apps/`, `auth-api/`, etc.

### Steps

1. Fetch ticket using Fetch workflow
2. Analyze description, acceptance criteria, subtasks
3. Identify which monorepo folders the ticket references
4. Determine the parent-most relevant folder
5. Create `DEV-{number}-plan.scratch.md` in that folder with:
   - Summary of the ticket
   - Technical approach
   - Step-by-step implementation plan
   - Files likely to be modified
   - Testing considerations
   - `branch: DEV-{number}-{jira-slugified-title}` line at the top
     (Fred can replace with exact Jira branch name from "Copy branch name" in Jira UI)

**Branch line format (always include at top of plan file):**
```markdown
branch: DEV-6182-travel-backend-add-missing-user-fields
```
This is read by `/Worktree DEV-XXXX` to use the correct branch name.
If Fred has copied the exact branch name from Jira → paste it here to override the auto-generated slug.

## Search Workflow

```bash
# Search with JQL
curl -s -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  -G "${JIRA_BASE_URL}/rest/api/3/search" \
  --data-urlencode "jql=project=DEV AND assignee=currentUser() AND status!=Done ORDER BY updated DESC" \
  --data-urlencode "maxResults=20" \
  --data-urlencode "fields=key,summary,status,priority,assignee"
```

## API Quick Reference

**Headers (all requests):**
```bash
JIRA_API_TOKEN=$(sed -n 's/^JIRA_API_TOKEN=//p' ~/.claude/.env)
JIRA_EMAIL=$(sed -n 's/^JIRA_EMAIL=//p' ~/.claude/.env)
JIRA_BASE_URL=$(sed -n 's/^JIRA_BASE_URL=//p' ~/.claude/.env)
# Then: curl -s -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" ...
```

**Get issue:**
```bash
GET /rest/api/3/issue/{issueKey}
```

**Search (JQL):**
```bash
GET /rest/api/3/search?jql={jql}&maxResults=20&fields=key,summary,status,priority
```

**Get comments:**
```bash
GET /rest/api/3/issue/{issueKey}/comment
```

**Get sprint board:**
```bash
GET /rest/agile/1.0/board/{boardId}/sprint?state=active
GET /rest/agile/1.0/sprint/{sprintId}/issue
```
