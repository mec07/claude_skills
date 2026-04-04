# WOP Sync Workflow

## Steps

### 1. Pull all assigned Jira tickets

Use the Atlassian MCP tool `searchJiraIssuesUsingJql` with JQL:
```
assignee=currentUser() AND status!=Done ORDER BY status ASC, updated DESC
```

### 2. Pull open PRs from GitHub

```bash
# All open PRs by Fred
gh pr list --repo powerxai/data --author @me --state open --json number,title,state,isDraft,updatedAt,url,reviewDecision,statusCheckRollup,mergeable

# Reviews requested from Fred
gh pr list --repo powerxai/data --search "review-requested:@me" --json number,title,url
```

### 3. Pull recently merged PRs (last 14 days)

```bash
gh pr list --repo powerxai/data --author @me --state merged --json number,title,mergedAt,url --limit 20
```

### 4. Cross-reference: detect mismatches

For each assigned ticket:
- Check if a PR exists for it (match `DEV-XXXX` in PR title/branch)
- Compare Jira status vs PR state:
  - Jira "New" + PR exists → flag: should be "In Development" or "Code Review"
  - Jira "In Development" + PR merged → flag: should be "Done" or "QA"
  - Jira "Code Review" + no open PR → flag: PR missing or already merged?

### 5. Detect staleness

For each open PR:
- Last updated > 3 days ago → flag stale
- CI checks failing → flag broken
- Merge conflicts → flag conflicts
- Review requested but no review yet → flag needs chase

For each "In Development" ticket:
- No commits in branch in 3+ days → flag stale

### 6. Read current WIP page

```
Read: {VAULT}/PAI/PAI Work In Progress.md
```

### 7. Update WIP page

Rewrite the following sections with fresh data:
- **⚠️ Jira Tickets Needing Status Update** — any mismatches found
- **🔍 My Open PRs — Awaiting Review** — current open non-draft PRs
- **📝 My Draft PRs** — current draft PRs
- **🎫 Other Active Jira Tickets** — assigned tickets not in a work stream
- **✅ Recently Merged** — last 14 days

Preserve manually-curated sections:
- **🏗️ Active Work Streams** — only update status/PR columns, don't restructure
- **📋 Backlog / Remaining Tech Debt** — leave as-is unless tickets are now Done

Add timestamp: `> **Greg maintains this file.** You just read it. Last updated: {date}`

### 8. Scan Open Loops for work items

```
Read: ~/.claude/skills/PAI/USER/OPEN_LOOPS.md
```

Flag any work-related open loops that look stale (no update in 2+ weeks).

### 9. Present summary

Display a terminal summary:
```
## WOP Sync — {date}

### 🔴 Needs Attention
- {CI failures, merge conflicts, stale PRs}

### ⚠️ Status Mismatches
- {tickets where Jira doesn't match reality}

### 📊 Overview
- Open PRs: {N} ({M} awaiting review, {K} draft)
- Active tickets: {N} ({M} in dev, {K} in review)
- Recently merged: {N} in last 14 days

### ✅ WIP page updated
```
