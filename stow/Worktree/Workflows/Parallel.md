# Parallel Worktree Workflow

Execute multiple tickets simultaneously — each gets its own worktree and Engineer agent.

## Voice

```bash
curl -s -X POST http://localhost:8888/notify \
  -H "Content-Type: application/json" \
  -d '{"message": "Spinning up parallel worktrees"}' \
  > /dev/null 2>&1 &
```

Running **Parallel** workflow in **Worktree** skill...

---

## When This Runs

Triggered when `/Worktree` receives 2+ ticket numbers:
```
/Worktree DEV-189 DEV-201 DEV-234
```

---

## Step 1 — Parse All Ticket Numbers

Extract all `DEV-\d+` patterns from input.

```
/Worktree DEV-189 DEV-201 DEV-234
→ tickets = [DEV-189, DEV-201, DEV-234]
```

---

## Step 2 — Fetch All Jira Tickets (Parallel)

Fetch all tickets simultaneously using parallel Bash calls:

```bash
# Run concurrently for each ticket
JIRA_API_TOKEN=$(sed -n 's/^JIRA_API_TOKEN=//p' ~/.claude/.env)
JIRA_EMAIL=$(sed -n 's/^JIRA_EMAIL=//p' ~/.claude/.env)

for TICKET in DEV-189 DEV-201 DEV-234; do
  curl -s -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
    "https://powerx.atlassian.net/rest/api/3/issue/${TICKET}?fields=summary,description,status"
done
```

---

## Step 3 — Determine Branch Names (All Tickets)

For each ticket, follow the branch name resolution from `Workflows/Single.md` Step 3:
1. Check for `DEV-XXX*.scratch.md` → `branch:` line
2. Slugify Jira title
3. Fallback

Collect: `[(DEV-189, branch-1), (DEV-201, branch-2), (DEV-234, branch-3)]`

---

## Step 4 — Create All Worktrees

⚠️ **CRITICAL: Always branch from `origin/main`** — fetch first, then specify explicitly.

```bash
REPO="${HOME}/dev/powerx/data"

# Fetch once before creating any worktrees
git -C "$REPO" fetch origin main

for each (TICKET, BRANCH):
  git -C "$REPO" worktree add \
    "${HOME}/dev/worktrees/powerx/${BRANCH}" \
    -b "${BRANCH}" origin/main
```

---

## Step 5 — Spawn All Engineers in Background (True Parallel)

For each ticket, spawn a background Engineer agent using `run_in_background: true`.

Each agent receives:
- Its worktree path
- Its Jira ticket context
- Its scratch file contents (if found)
- Instruction to commit but NOT push (parent handles push)
- Instruction to output a `---PR_BODY_START---` / `---PR_BODY_END---` block (same format as Single workflow Step 6)

**Spawn all agents before waiting on any.** This is true parallelism — do not wait sequentially.

---

## Step 6 — Wait and Collect Results

Wait for all background agents to complete. For each:
- Check if commits were made in the worktree
- Note any failures

---

## Step 7 — Push All Branches and Create Draft PRs

For each completed worktree:
1. Extract PR body from agent output (between `---PR_BODY_START---` and `---PR_BODY_END---`)
2. Append Testing/Screenshots/Deployment/Checklist sections from `.github/PULL_REQUEST_TEMPLATE.md`

```bash
git -C "${HOME}/dev/worktrees/powerx/${BRANCH}" push -u origin "${BRANCH}"

gh pr create \
  --repo powerxai/data \
  --head "${BRANCH}" \
  --base main \
  --title "feat: ${TICKET}: ${SUMMARY}" \
  --draft \
  --body "${PR_BODY}"
```

---

## Step 8 — Update All Scratch Files

For each ticket with a scratch file found:
- Append branch name + PR URL (same format as Single workflow)

---

## Step 9 — Report Summary

```
✓ 3 worktrees completed:

  DEV-189: branch DEV-189-fix-auth → PR: <url>
  DEV-201: branch DEV-201-billing-export → PR: <url>
  DEV-234: branch DEV-234-route-handler → PR: <url>

To review: fetch in WebStorm → checkout each branch
To clean up after merge: /Worktree cleanup DEV-189 DEV-201 DEV-234
```

---

## Failure Handling

If one agent fails, others continue. Report partial success:
```
✓ DEV-189: done → PR <url>
✗ DEV-201: agent failed — worktree at ~/dev/worktrees/powerx/DEV-201-... left intact
✓ DEV-234: done → PR <url>
```
