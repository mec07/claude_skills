# Single Worktree Workflow

Execute a single ticket or description in an isolated git worktree.

## Voice

```bash
curl -s -X POST http://localhost:8888/notify \
  -H "Content-Type: application/json" \
  -d '{"message": "Spinning up worktree"}' \
  > /dev/null 2>&1 &
```

Running **Single** workflow in **Worktree** skill...

---

## Step 1 — Parse Input

Determine if input is a Jira ticket number or free-form description:

- `DEV-6182` → Jira ticket flow
- `add dark mode to dashboard` → non-ticket flow (branch: `ai/add-dark-mode-to-dashboard`)

**Ticket number regex:** `DEV-\d+`

---

## Step 2 — Fetch Jira Ticket (if DEV-XXX)

```bash
JIRA_API_TOKEN=$(sed -n 's/^JIRA_API_TOKEN=//p' ~/.claude/.env)
JIRA_EMAIL=$(sed -n 's/^JIRA_EMAIL=//p' ~/.claude/.env)
curl -s -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  "https://powerx.atlassian.net/rest/api/3/issue/DEV-XXXX?fields=summary,description,acceptance-criteria,subtasks,status,assignee"
```

Parse the response: extract `summary`, `description` body (ADF → plain text), `subtasks`.

---

## Step 3 — Determine Branch Name

**Priority order:**

1. **Scratch file `branch:` line** (highest priority):
   - Search for `DEV-XXXX*.scratch.md` in:
     - `~/dev/powerx/data/` (all subdirs, 2 levels deep)
     - `~/.claude/`
   - If found, read first line matching `branch: <name>` → use exactly

2. **Slugify Jira title** (if no scratch file or no `branch:` line):
   ```
   "Travel backend: add missing user fields for depot location"
   → DEV-6182-travel-backend-add-missing-user-fields-for-depot-location
   ```
   Rules: lowercase, spaces→hyphens, strip special chars, keep ticket prefix

3. **Fallback** (if no Jira title):
   ```
   DEV-6182-task
   ```

**Non-ticket:** `ai/` + slugified description
```
"add dark mode to dashboard" → ai/add-dark-mode-to-dashboard
```

---

## Step 4 — Find and Load Scratch File

Search for `DEV-XXXX*.scratch.md` in:
- `~/dev/powerx/data/` (recursive, max 2 levels)
- `~/dev/powerx/data/auth-api/`
- `~/dev/powerx/data/apps/`
- `~/.claude/`

If found: read entire file — this is additional context/requirements for the agent.

---

## Step 5 — Create Worktree

⚠️ **CRITICAL: Always branch from `origin/main`, never from the repo's current HEAD.**
The main checkout may be on any branch. Always fetch first, then specify `origin/main` explicitly.

```bash
BRANCH=<determined-in-step-3>
WT_PATH="${HOME}/dev/worktrees/powerx/${BRANCH}"
REPO="${HOME}/dev/powerx/data"

# Always fetch first, then branch explicitly from origin/main
git -C "$REPO" fetch origin main
git -C "$REPO" worktree add "$WT_PATH" -b "$BRANCH" origin/main
```

If branch already exists remotely (e.g. Jira already created it):
```bash
git -C "$REPO" fetch origin "$BRANCH"
git -C "$REPO" worktree add "$WT_PATH" "$BRANCH"
```

---

## Step 5b — Copy .idea from Main Repo

After creating the worktree, copy the WebStorm project config so it doesn't have to re-index from scratch. **Include `workspace.xml`** — without it, WebStorm treats every open as a brand new project and runs full initialization (massive CPU spike every time). Exclude only DB credentials and shelf state which are truly user-specific:

```bash
rsync -a \
  --exclude='dataSources.xml' \
  --exclude='dataSources.local.xml' \
  --exclude='dataSources/' \
  --exclude='shelf/' \
  ~/dev/powerx/data/.idea/ \
  "${WT_PATH}/.idea/"
```

Then add explicit `node_modules` exclusion to the `.iml` so WebStorm never tries to index them:

```bash
python3 << 'PYEOF'
import os

iml_path = f"{WT_PATH}/.idea/data.iml"
if os.path.exists(iml_path):
    with open(iml_path) as f:
        content = f.read()
    # Replace self-closing content tag with one that excludes heavy dirs
    if '<content url="file://$MODULE_DIR$" />' in content:
        content = content.replace(
            '<content url="file://$MODULE_DIR$" />',
            '<content url="file://$MODULE_DIR$">\n'
            '      <excludeFolder url="file://$MODULE_DIR$/node_modules" />\n'
            '      <excludeFolder url="file://$MODULE_DIR$/.nx" />\n'
            '    </content>'
        )
        with open(iml_path, 'w') as f:
            f.write(content)
        print("Updated data.iml with node_modules exclusion")
PYEOF
```

This gives WebStorm the full project model (module definitions, TypeScript settings, recent project state) AND excludes the biggest indexing cost (node_modules) from day one — significantly faster startup on every open.

---

## Step 6 — Spawn Engineer Agent

Spawn an Engineer agent with this prompt:

```
CONTEXT:
You are working on a git worktree at: {WT_PATH}
Main repo is at: ~/dev/powerx/data/
Branch: {BRANCH}

JIRA TICKET: {TICKET_NUMBER}
Title: {TICKET_SUMMARY}
Description:
{TICKET_DESCRIPTION}

{IF SCRATCH FILE EXISTS:}
ADDITIONAL CONTEXT (from planning scratch file):
{SCRATCH_FILE_CONTENTS}
{END IF}

TASK:
Implement the work described in the Jira ticket above.
Work entirely within the worktree directory: {WT_PATH}
Do NOT touch ~/dev/powerx/data/ or any other directory.

Read the .aiassistant file in the repo root for code style guidelines.

CRITICAL STEPS:
- NEVER add "Co-Authored-By: Claude" or any Claude/Anthropic attribution to commit messages. This is banned. Commits must contain only the change description.
- If you modify any package.json (add/remove/change dependencies), run `pnpm install` at the worktree root before committing, then commit the updated `pnpm-lock.yaml` in a separate `chore:` commit. CI uses --frozen-lockfile and will fail if the lockfile is out of sync.

When done:
1. Commit changes in GRANULAR commits — one logical unit per commit, not one big commit.
   Good examples:
   - Commit 1: "DEV-XXXX: add DB migration for ..."
   - Commit 2: "DEV-XXXX: update Hasura metadata for ..."
   - Commit 3: "DEV-XXXX: add API endpoint for ..."
   Each commit should be independently understandable and safely revertable.
2. Do NOT push — the Worktree skill will handle push and PR creation

EFFORT LEVEL: Extended (thorough implementation, full test coverage if tests exist)
OUTPUT: At the end of your report, include a PR_BODY block formatted exactly like this:

---PR_BODY_START---
## 📚 Description
**What does this PR do?**
{2-3 sentences summarising what was implemented and why}

## 🔗 Related Issues / Tickets
- Jira: [{TICKET_NUMBER}](https://powerx.atlassian.net/browse/{TICKET_NUMBER})

## 🛠️ Changes / Implementation Details
{Bullet list of key changes — files modified, what each does}

**Are there any breaking changes?**
- [ ] Yes
- [x] No
---PR_BODY_END---
```

Use `Task(subagent_type="Engineer", prompt=<above>)` — foreground (wait for completion).

---

## Step 7 — Push Branch and Create Draft PR

After agent completes:

1. **Extract PR body** from Engineer's output — parse everything between `---PR_BODY_START---` and `---PR_BODY_END---`.

2. **Append remaining template sections** (Testing, Screenshots, Deployment, Checklist) from `.github/PULL_REQUEST_TEMPLATE.md` — read the repo template and append the sections below the agent's content, so Fred can fill them in.

3. **Determine PR type prefix** — must be one of: `feat`, `fix`, `docs`, `test`, `ci`, `refactor`, `perf`, `chore`, `revert`.
   Infer from the ticket summary and work done:
   - New feature or capability → `feat`
   - Bug fix → `fix`
   - Refactoring without behaviour change → `refactor`
   - Tests only → `test`
   - Documentation → `docs`
   - Performance improvement → `perf`
   - CI/CD change → `ci`
   - Dependency updates, cleanup, housekeeping → `chore`
   - Reverting a commit → `revert`

4. **Create PR:**

```bash
# Push branch
git -C "${HOME}/dev/worktrees/powerx/${BRANCH}" push -u origin "${BRANCH}"

# Create draft PR with pre-filled body
# PR_TYPE must be one of: feat, fix, docs, test, ci, refactor, perf, chore, revert
gh pr create \
  --repo powerxai/data \
  --head "${BRANCH}" \
  --base main \
  --title "${PR_TYPE}: ${TICKET_NUMBER}: ${TICKET_SUMMARY}" \
  --draft \
  --body "${PR_BODY}"
```

Where `${PR_BODY}` = Engineer's PR_BODY section + the Testing/Screenshots/Deployment/Checklist sections from the template.

Capture the PR URL from `gh pr create` output.

---

## Step 8 — Update Scratch File

If a scratch file was found in Step 4, append to it:

```markdown

---
## Worktree Execution

- **Branch:** `{BRANCH}`
- **PR:** {PR_URL}
- **Status:** Draft PR created — awaiting review
```

If no scratch file existed, note the branch in your response only.

---

## Step 9 — Report to Fred

```
✓ Worktree: ~/dev/worktrees/powerx/{BRANCH}/
✓ Branch pushed: {BRANCH}
✓ Draft PR: {PR_URL}

{SUMMARY OF WHAT WAS IMPLEMENTED}

To review: fetch in WebStorm → checkout {BRANCH}
To clean up after merge: /Worktree cleanup {TICKET_NUMBER}
```

---

## Error Handling

| Situation | Action |
|-----------|--------|
| Jira API fails | Proceed with branch name from title/fallback, note missing context |
| Branch already exists locally | Append `-2` suffix or ask Fred |
| No `gh` CLI | Push only, provide `gh pr create` command for Fred to run |
| Agent fails | Report failure, leave worktree intact for manual work |
