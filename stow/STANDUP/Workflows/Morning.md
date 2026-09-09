# Morning Standup Workflow

## Steps

### 1. Pull Clockify entries (yesterday)

Get yesterday's time entries to see what was actually tracked:

```bash
# Get yesterday's date
YESTERDAY=$(date -v-1d +%Y-%m-%d)
TODAY=$(date +%Y-%m-%d)

# Fetch time entries via Clockify API
CLOCKIFY_API_KEY=$(sed -n 's/^CLOCKIFY_API_KEY=//p' ~/.claude/.env)
curl -s -H "X-Api-Key: ${CLOCKIFY_API_KEY}" \
  "https://api.clockify.me/api/v1/workspaces/5f4e87abd310252eb1fa49ec/user/5ef8d235f833d7257bf41744/time-entries?start=${YESTERDAY}T00:00:00Z&end=${TODAY}T00:00:00Z" \
  | python3 -c "
import json, sys
entries = json.load(sys.stdin)
for e in entries:
    desc = e.get('description', 'No description')
    start = e['timeInterval']['start'][11:16]
    end = (e['timeInterval'].get('end') or 'running')[11:16] if e['timeInterval'].get('end') else 'running'
    print(f'  {start}-{end}: {desc}')
"
```

### 2. Pull Git commits (last 24h)

```bash
cd "$(git rev-parse --show-toplevel)" || echo "Not in a git repository — skipping git activity."
git log --oneline --since="24 hours ago" --author="$(git config user.email)" --all 2>/dev/null \
  || echo "  No commits in last 24h"
```

### 3. Pull GitHub PR activity

```bash
# Your PRs updated in the last 24h, across every repo you can see
SINCE=$(date -u -d '1 day ago' +%F 2>/dev/null || date -u -v-1d +%F)
gh search prs --author=@me --updated=">=$SINCE" --limit 20 \
  --json number,title,repository,url,state,updatedAt

# Reviews waiting on you, across every repo
gh search prs --review-requested=@me --state=open --limit 10 \
  --json number,title,repository,url
```

### 4. Pull Jira ticket activity

Use the Atlassian MCP tool `searchJiraIssuesUsingJql` with JQL:
```
assignee=currentUser() AND updated >= -1d ORDER BY updated DESC
```

### 5. Identify today's priorities

Use the Atlassian MCP tool `searchJiraIssuesUsingJql` for each query:

In-progress tickets:
```
assignee=currentUser() AND status='In Development' ORDER BY priority DESC
```

Sprint tickets not started:
```
assignee=currentUser() AND sprint in openSprints() AND status='New' ORDER BY priority DESC
```

### 6. Read Work In Progress for context

Read the WIP page for broader context on active work streams:
```
Read: {VAULT}/PAI/PAI Work In Progress.md
```

### 7. Compile and present

Format everything into the standup template:

```markdown
## Standup — {today's date}

### Yesterday
- {deduplicated bullets from Clockify + git + PRs + Jira}

### Today
- {in-progress tickets}
- {sprint priorities}
- {PRs needing attention}

### Blockers
- {PRs awaiting review > 2 days}
- {tickets in blocked status}
```

### 8. Optional: Write to Obsidian

Only when `OBSIDIAN_VAULT` is set. If it is unset, skip this step without
mentioning it — a terminal standup is the normal case.

```bash
[ -n "$OBSIDIAN_VAULT" ] || exit 0
```

Write the standup section to that day's daily note under `$OBSIDIAN_VAULT`:
`{VAULT}/{YYYY-MM-DD}.md`

Append under a `## Standup` heading — don't overwrite existing content.
