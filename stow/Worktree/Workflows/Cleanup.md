# Cleanup Worktree Workflow

Remove a worktree and its local branch after the PR has been merged.
Optionally checks out the branch in the main project folder for local testing.

## Voice

```bash
curl -s -X POST http://localhost:8888/notify \
  -H "Content-Type: application/json" \
  -d '{"message": "Cleaning up worktree"}' \
  > /dev/null 2>&1 &
```

Running **Cleanup** workflow in **Worktree** skill...

---

## When This Runs

```
/Worktree cleanup DEV-6182                    ← remove worktree only
/Worktree cleanup DEV-189 DEV-201             ← multiple at once
/Worktree cleanup checkout DEV-6183           ← remove worktree + checkout branch in main repo
```

The `checkout` keyword between `cleanup` and the ticket number activates checkout mode.

---

## Step 1 — Resolve Branch Name

For each ticket, find the branch name:
1. Check scratch file `branch:` line (same lookup as Single workflow)
2. Glob `~/dev/worktrees/powerx/DEV-XXXX*` — match by ticket prefix
3. If worktree already removed, check local branches: `git -C "$REPO" branch | grep DEV-XXXX`
4. If still not found, check remote: `git -C "$REPO" branch -r | grep DEV-XXXX`
5. Ask Fred if ambiguous

---

## Step 2 — Verify PR is Merged (Optional Safety Check)

```bash
gh pr list \
  --repo powerxai/data \
  --head "${BRANCH}" \
  --state merged \
  --json number,title,mergedAt
```

If NOT merged: warn Fred before removing.
```
⚠️  Branch DEV-6182-... has an OPEN PR (not merged yet).
    Remove worktree anyway? (branch stays on remote)
```

---

## Step 3 — [Checkout Mode Only] Handle Uncommitted Changes in Main Repo

**Only runs when `checkout` keyword was present in the invocation.**

Check for uncommitted changes in the main repo:

```bash
git -C "$REPO" status --porcelain
```

If output is **empty** → main repo is clean, proceed directly to Step 4.

If output is **non-empty** → use AskUserQuestion with these options:

```
Question: "~/dev/powerx/data/ has uncommitted changes. What should we do before checking out {BRANCH}?"

Options:
  A) Stash changes    — git stash push -m "WIP before checkout {BRANCH}"
  B) Commit changes   — commit all staged+unstaged with an auto message "WIP: stashing before DEV-XXXX checkout"
  C) Abort checkout   — remove worktree only, skip the checkout step
```

Execute the chosen action:

**Stash:**
```bash
git -C "$REPO" stash push -m "WIP before checkout ${BRANCH}"
```

**Commit (stage all + commit):**
```bash
git -C "$REPO" add -A
git -C "$REPO" commit -m "WIP: before checking out ${BRANCH}"
```

**Abort:** skip Steps 5–6, proceed to confirm with checkout skipped.

---

## Step 4 — Remove Worktree

```bash
REPO="${HOME}/dev/powerx/data"
WT_PATH="${HOME}/dev/worktrees/powerx/${BRANCH}"

git -C "$REPO" worktree remove "$WT_PATH" --force
```

If worktree directory doesn't exist (already removed), skip silently.

---

## Step 5 — Delete Local Branch

**Standard cleanup (no `checkout`):**
```bash
git -C "$REPO" branch -d "${BRANCH}" 2>/dev/null \
  || git -C "$REPO" branch -D "${BRANCH}"
```
(Use `-D` force-delete since branch was already merged on remote.)

**Checkout mode:** Skip this step — branch must survive for checkout in Step 6.

---

## Step 6 — [Checkout Mode Only] Checkout Branch in Main Repo

```bash
# Ensure the local branch exists and is up to date
git -C "$REPO" fetch origin "${BRANCH}" 2>/dev/null || true

# Create local tracking branch if it doesn't exist yet
git -C "$REPO" branch --track "${BRANCH}" "origin/${BRANCH}" 2>/dev/null || true

# Checkout
git -C "$REPO" checkout "${BRANCH}"
```

---

## Step 7 — Confirm

**Standard cleanup:**
```
✓ Worktree removed: ~/dev/worktrees/powerx/{BRANCH}/
✓ Local branch deleted: {BRANCH}
  (Remote branch still exists on origin — GitHub auto-deletes on merge if configured)
```

**Checkout mode:**
```
✓ Worktree removed: ~/dev/worktrees/powerx/{BRANCH}/
✓ Checked out: {BRANCH} in ~/dev/powerx/data/
  Branch is ready — make your changes or run the app to verify.
  When done: /Worktree cleanup DEV-XXXX  (removes local branch after merge)
```

If stash was created, remind Fred:
```
  💡 Your previous changes were stashed. Run `git stash pop` to restore them when finished.
```

---

## Multiple Cleanup

For `/Worktree cleanup DEV-189 DEV-201`:
- Run Steps 1-5 for each ticket sequentially (cleanup is fast, no need for parallelism)
- `checkout` mode only supported for a single ticket (can't checkout two branches at once)
- Report all at end
