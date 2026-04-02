---
name: Worktree
description: Git worktree manager with Jira integration. USE WHEN /Worktree, worktree, work in isolation, branch for ticket, DEV- ticket execution, parallel ticket work, spin up agent on branch, ai/ branch.
---

# Worktree

Spin up isolated git worktrees for Jira tickets or generic tasks. Greg works in the worktree, pushes a branch, creates a draft PR, and reports back — Fred's main checkout is never touched.

## Configuration

```
Worktree base:   ~/dev/worktrees/
PowerX repo:     ~/dev/powerx/data/
PowerX worktrees: ~/dev/worktrees/powerx/<branch>/
```

**Branch naming:**
- Jira ticket  → `DEV-XXX-slug-from-title` (or exact name from scratch file `branch:` line)
- Non-ticket   → `ai/short-description`

**Project map:**

| Project | Repo path | Worktree path |
|---------|-----------|---------------|
| PowerX  | `~/dev/powerx/data/` | `~/dev/worktrees/powerx/` |

## Voice Notification

**When executing a workflow, do BOTH:**

1. **Send voice notification**:
   ```bash
   curl -s -X POST http://localhost:8888/notify \
     -H "Content-Type: application/json" \
     -d '{"message": "Running WORKFLOWNAME in Worktree skill"}' \
     > /dev/null 2>&1 &
   ```

2. **Output text notification**:
   ```
   Running **WorkflowName** in **Worktree** skill...
   ```

## Workflow Routing

| Workflow | Trigger | File |
|----------|---------|------|
| **Single** | `/Worktree DEV-XXX` or `/Worktree <description>` (one item) | `Workflows/Single.md` |
| **Parallel** | `/Worktree DEV-XXX DEV-YYY` (multiple tickets) | `Workflows/Parallel.md` |
| **Cleanup** | `/Worktree cleanup DEV-XXX` or "cleanup worktree" | `Workflows/Cleanup.md` |
| **Cleanup + Checkout** | `/Worktree cleanup checkout DEV-XXX` | `Workflows/Cleanup.md` |

## Examples

**Example 1: Single Jira ticket**
```
User: "/Worktree DEV-6182"
→ Fetches Jira ticket DEV-6182
→ Checks for DEV-6182-plan.scratch.md (loads if found)
→ Branch: DEV-6182-travel-backend-add-missing-user-fields (from scratch or Jira title)
→ Creates ~/dev/worktrees/powerx/DEV-6182-travel-backend-add-missing-user-fields/
→ Spawns Engineer agent with full Jira + scratch context
→ Pushes branch, creates draft PR
→ Updates scratch file with branch + PR URL
→ "Branch DEV-6182-... pushed. Draft PR: <url>"
```

**Example 2: Parallel tickets**
```
User: "/Worktree DEV-189 DEV-201 DEV-234"
→ Fetches all 3 Jira tickets
→ Creates 3 worktrees simultaneously
→ Spawns 3 Engineer agents in background (parallel)
→ Reports as each completes
```

**Example 3: Non-ticket task**
```
User: "/Worktree add dark mode to dashboard"
→ No ticket detected → branch: ai/add-dark-mode-to-dashboard
→ Creates worktree, spawns agent, pushes, draft PR
```

**Example 4: Cleanup after merge**
```
User: "/Worktree cleanup DEV-6182"
→ Removes ~/dev/worktrees/powerx/DEV-6182-*/
→ Deletes local branch DEV-6182-*
→ Confirms cleanup complete
```

**Example 5: Cleanup + checkout for local testing**
```
User: "/Worktree cleanup checkout DEV-6183"
→ Checks main repo for uncommitted changes
→ If dirty: asks to stash, commit, or abort
→ Removes worktree ~/dev/worktrees/powerx/DEV-6183-*/
→ Checks out DEV-6183-... branch in ~/dev/powerx/data/
→ "Checked out DEV-6183-... — ready to test"
```

## Zsh Helpers

For manual worktree operations (available after dotfiles update):

```bash
gwtadd powerx <branch-slug>   # Create worktree + branch
gwtdone powerx <branch-slug>  # Remove worktree + branch after merge
gwtls [powerx]                # List active worktrees
```

## Decision Rule

**Default: Greg works in `~/dev/powerx/data/` (local, normal)**

Only switch to worktree mode when:
- Fred explicitly invokes `/Worktree`
- Or explicitly says "work in a worktree / isolated branch"

Greg NEVER creates worktrees unilaterally.
