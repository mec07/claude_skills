# Morning Standup Workflow

## Steps

### 1. Pull Clockify entries (yesterday)

Get yesterday's time entries to see what Fred actually tracked:

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
cd /Users/freddylem/dev/powerx/data
git log --oneline --since="24 hours ago" --author="fred" --all 2>/dev/null || echo "  No commits in last 24h"
```

### 3. Pull GitHub PR activity

```bash
# PRs opened/merged by Fred in last 24h
gh pr list --repo powerxai/data --author @me --state all --json number,title,state,updatedAt,url --limit 10

# Reviews requested from Fred
gh pr list --repo powerxai/data --search "review-requested:@me" --json number,title,url --limit 5
```

### 4. Pull Jira ticket activity

```bash
# Tickets updated by Fred in last 24h
bun ~/.claude/skills/_JIRA/Tools/Jira.ts search "assignee=currentUser() AND updated >= -1d ORDER BY updated DESC" --fields key,summary,status
```

### 5. Identify today's priorities

```bash
# In-progress tickets
bun ~/.claude/skills/_JIRA/Tools/Jira.ts search "assignee=currentUser() AND status='In Development' ORDER BY priority DESC" --fields key,summary,priority

# Sprint tickets not started
bun ~/.claude/skills/_JIRA/Tools/Jira.ts search "assignee=currentUser() AND sprint in openSprints() AND status='New' ORDER BY priority DESC" --fields key,summary,priority
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

If Fred asks, write the standup section to today's Obsidian daily note at:
`{VAULT}/{YYYY-MM-DD}.md`

Append under a `## Standup` heading — don't overwrite existing content.
