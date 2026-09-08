---
name: Worktree
description: Git worktree manager with Jira integration. Works in any git repository — repo, remote and worktree paths are all derived at runtime. USE WHEN /Worktree, worktree, work in isolation, branch for ticket, ticket execution, parallel ticket work, spin up agent on branch, ai/ branch.
---

# Worktree

Spin up isolated git worktrees for Jira tickets or generic tasks. The agent works in the worktree, pushes a branch, creates a draft PR, and reports back — your main checkout is never touched.

## Context (derived, never configured)

Nothing about a particular repo, user or Jira project is written into this skill.
Every workflow starts by resolving these from wherever it is run:

```bash
REPO=$(git rev-parse --show-toplevel)              # the checkout you are in
REPO_NAME=$(basename "$REPO")                      # e.g. "api"
REPO_SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
WT_BASE="${WORKTREE_BASE:-$HOME/dev/worktrees}/$REPO_NAME"
WT_PATH="$WT_BASE/$BRANCH"
```

| Value | Derived from | Notes |
|-------|--------------|-------|
| `REPO` | `git rev-parse --show-toplevel` | Fails outside a repo — see below |
| `REPO_NAME` | basename of `REPO` | Names the worktree directory |
| `REPO_SLUG` | `gh repo view` | Only needed when running outside the repo |
| `DEFAULT_BRANCH` | `origin/HEAD` | Falls back to `main`, then `master` |
| `WT_BASE` | `$WORKTREE_BASE` or `~/dev/worktrees` | Override to move worktrees anywhere |

**Outside a git repository**, every workflow stops immediately and says so. There
is no default repo to fall back on, and guessing one would be worse than failing.

**`gh` infers the repository** from the remote whenever it runs inside the repo
or a worktree of it, so `--repo` is omitted there. It is passed explicitly only
in the few places a command runs from an unrelated directory.

## Branch naming

- Jira ticket → `{KEY}-slug-from-title`, or the exact name from a scratch file's
  `branch:` line when one exists
- Non-ticket → `ai/short-description`

Ticket keys are matched by shape, `[A-Z][A-Z0-9]+-[0-9]+`, so any Jira project
works. No prefix is hardcoded. Jira itself is reached through the `JIRA` skill,
which owns the site and credentials — this skill never calls a Jira URL directly.

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
| **Single** | `/Worktree {KEY}` or `/Worktree <description>` (one item) | `Workflows/Single.md` |
| **Parallel** | `/Worktree {KEY} {KEY}` (multiple tickets) | `Workflows/Parallel.md` |
| **Cleanup** | `/Worktree cleanup {KEY}` or "cleanup worktree" | `Workflows/Cleanup.md` |
| **Cleanup + Checkout** | `/Worktree cleanup checkout {KEY}` | `Workflows/Cleanup.md` |

## Examples

**Example 1: Single Jira ticket**
```
User: "/Worktree ABC-123"
→ Fetches Jira ticket ABC-123 via the JIRA skill
→ Checks for ABC-123-plan.scratch.md (loads if found)
→ Branch: ABC-123-add-missing-user-fields (from scratch or Jira title)
→ Creates $WT_BASE/ABC-123-add-missing-user-fields/
→ Spawns Engineer agent with full Jira + scratch context
→ Pushes branch, creates draft PR
→ Updates scratch file with branch + PR URL
→ "Branch ABC-123-... pushed. Draft PR: <url>"
```

**Example 2: Parallel tickets**
```
User: "/Worktree ABC-1 ABC-2 ABC-3"
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
User: "/Worktree cleanup ABC-123"
→ Removes $WT_BASE/ABC-123-*/
→ Deletes local branch ABC-123-*
→ Confirms cleanup complete
```

**Example 5: Cleanup + checkout for local testing**
```
User: "/Worktree cleanup checkout ABC-124"
→ Checks main repo for uncommitted changes
→ If dirty: asks to stash, commit, or abort
→ Removes worktree $WT_BASE/ABC-124-*/
→ Checks out ABC-124-... branch in $REPO
→ "Checked out ABC-124-... — ready to test"
```

## Zsh Helpers

For manual worktree operations (available after dotfiles update):

```bash
gwtadd <repo-name> <branch-slug>   # Create worktree + branch
gwtdone <repo-name> <branch-slug>  # Remove worktree + branch after merge
gwtls [<repo-name>]                # List active worktrees
```

## Decision Rule

**Default: the agent works in the current checkout (local, normal)**

Only switch to worktree mode when:
- You explicitly invoke `/Worktree`
- Or explicitly says "work in a worktree / isolated branch"

The agent NEVER creates worktrees unilaterally.
