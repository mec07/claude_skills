# Review Workflow

Analyze a PR and create a pending GitHub review with inline comments on the diff.

## Voice Notification

```bash
curl -s -X POST http://localhost:8888/notify \
  -H "Content-Type: application/json" \
  -d '{"message": "Reviewing pull request"}' \
  > /dev/null 2>&1 &
```

Running the **Review** workflow in the **ReviewPR** skill...

---

## Step 1: Determine PR Number and Repo

**If PR number is provided as argument:** Use it directly.

**If no PR number provided:** Detect from current branch:
```bash
BRANCH=$(git branch --show-current)
gh pr list --head "$BRANCH" --json number,title --jq '.[0]'
```
If no PR exists for the current branch, ask the user.

**Determine the repo:**
```bash
git remote get-url origin
```
Extract `owner/repo` from the remote URL. Handle both SSH (`git@github.com:owner/repo.git`) and HTTPS formats.

## Step 2: Fetch PR Metadata and CLAUDE.md

```bash
gh pr view {PR_NUMBER} --repo {OWNER/REPO} \
  --json title,body,additions,deletions,changedFiles,baseRefName,headRefName,state,commits
```

Note the scale (additions, deletions, file count) to determine review strategy.

**Also read the project's CLAUDE.md files** — both the root CLAUDE.md and any CLAUDE.md files in directories touched by the PR. These contain project-specific conventions and rules that the review must check against.

## Step 3: Fetch Changed Files and Categorise

```bash
gh pr diff {PR_NUMBER} --repo {OWNER/REPO} --name-only
```

Categorise files by type/area. This determines:
- Which specialised review aspects apply
- How to partition work for parallel agents
- Which CLAUDE.md rules are relevant

## Step 4: Launch Review Analysis

### Small PRs (<500 lines): Single-pass

Fetch the entire diff and review in one pass.

### Medium PRs (500-1500 lines): Chunked

Read diff in ~500-line chunks. Analyse sequentially.

### Large PRs (1500+ lines): Parallel Specialist Agents

Launch 2-4 parallel agents, each with a different focus:

| Agent | Focus | What it checks |
|-------|-------|----------------|
| **Bug Hunter** | Correctness | Logic errors, null handling, race conditions, missing edge cases, incomplete implementations, parity gaps (e.g., migration mismatches) |
| **Guidelines Checker** | CLAUDE.md compliance | Project conventions, naming, import patterns, framework rules, testing practices |
| **Security Reviewer** | Security | Injection vulnerabilities, credential exposure, permission/ACL gaps, auth issues, input validation |
| **History Checker** | Git context | `git blame` on modified files, prior PR comments on same files, whether changes align with historical patterns |

### Massive PRs (5000+ lines): Full Parallel

Launch 4-8 agents partitioned by file group AND review aspect.

## Step 5: Confidence Scoring

Rate every potential finding on a 0-100 confidence scale:

| Score | Meaning |
|-------|---------|
| 0-25 | Likely false positive or pre-existing issue |
| 26-50 | Might be real, but could be a nitpick not in CLAUDE.md |
| 51-75 | Valid but low-impact issue |
| 76-89 | Important issue — verified it's real and impactful |
| 90-100 | Critical — confirmed bug, security hole, or explicit CLAUDE.md violation |

**Only report issues with confidence >= 80.** Quality over quantity.

### What is a False Positive (DO NOT flag)

- Pre-existing issues on unmodified lines
- Things a linter, typechecker, or CI would catch (formatting, imports, type errors)
- Pedantic nits a senior engineer wouldn't mention
- General code quality concerns not called out in CLAUDE.md
- Issues silenced by explicit lint-ignore comments
- Functionality changes that are clearly intentional

## Step 6: Read Related Source Files

When the diff alone isn't sufficient:
- Read full source files being modified (not just diff hunks)
- Check callers of modified functions/modules
- Verify interfaces match between producers and consumers
- Compare before/after for refactors
- Check git blame for historical context on tricky areas

## Step 7: Build Inline Comments

For each finding that passes the confidence threshold (>= 80), record:

- **`path`**: File path relative to repo root
- **`line`**: Line number in the NEW version of the file. MUST be a line in the diff (added or context line within a hunk)
- **`side`**: Always `"RIGHT"` (comment on new version)
- **`body`**: The review comment in markdown

### Tone and Voice

Write comments like you're talking to a teammate. Spoken English, not a report. No headings, no bold severity labels, no em dashes. Keep it human and collaborative.

The goal is to never make an enemy. You are on the same team. If something looks wrong, ask a question to understand their reasoning first. If there's an easy win, point it out as a suggestion, not a demand. Assume the author had good reasons for their choices.

Bad: "**CRITICAL**: Missing null check on `user` before accessing `user.id`. Will throw at runtime."
Good: "❓ Curious about what happens here if `user` is null, like from a guest session. Would it be worth adding a guard before accessing `user.id`?"

Bad: "**IMPORTANT**: This should use a prepared statement to prevent SQL injection."
Good: "💭 This caught my eye because the query is built with string interpolation. A prepared statement would close off the injection surface here. What do you think?"

### Emoji Prefixes

Start each comment with one emoji to signal intent (based on https://github.com/erikthedeveloper/code-review-emoji-guide):

| Emoji | When to use |
|-------|-------------|
| 👍 😊 💯 | **Praise.** Something is well done and you want the author to know. Use generously. |
| 🔧 | **Change suggestion.** You think this needs to change. Frame it as a suggestion or question, not a command. |
| ❓ | **Question.** You genuinely want to understand something. Provide enough context so they know what you're asking. |
| 💭 | **Thinking out loud.** Walking through a concern, suggesting an alternative, or reasoning about the code. This is the default for most observations. |
| 🌱 | **Seed for the future.** Doesn't need action now but is worth noting for later. |
| 📝 | **Note.** An observation or fun fact. No action needed. |
| ⛏️ | **Nitpick.** Minor style or formatting thing. Acknowledge it's small. |
| ♻️ | **Refactor idea.** A more substantial restructuring suggestion with context on why. |
| 🏕️ | **Leave it cleaner.** Boy scout rule opportunity, typically unrelated to the PR's main changes. |
| 📌 | **Out of scope.** Worth tracking but not for this PR. |

Prefer 💭 and ❓ as your defaults. Use 💡 sparingly (it can read as patronising). When in doubt, go with 💭 or no emoji at all.

### Comment Quality Rules

- Be specific with variable names, line references, and concrete suggestions
- Explain why something matters, not just that it's "wrong"
- Reference CLAUDE.md rules, related code, or git history when relevant
- Use GitHub permalinks with full SHA: `https://github.com/{owner}/{repo}/blob/{full_sha}/{path}#L{start}-L{end}`
- One topic per comment, don't bundle unrelated things
- Frame suggestions as questions or collaborative proposals ("would it make sense to...", "have you considered...", "what do you think about...")

### Finding the Correct Line Number

The `line` field must reference a line that exists in the diff hunk. The line number refers to the line in the NEW file (after changes).

- Added lines (`+` prefix): use the new file line number
- Context lines (no prefix): use the new file line number
- Removed lines (`-` prefix): CANNOT comment on these — use the nearest context or added line instead

## Step 8: Create Pending Review via GitHub API

Get the head commit SHA:
```bash
gh pr view {PR_NUMBER} --repo {OWNER/REPO} --json commits --jq '.commits[-1].oid'
```

Write the comments JSON to `/tmp/pr-review-comments-{PR_NUMBER}.json`:
```json
[
  {
    "path": "src/handlers/auth.ts",
    "line": 42,
    "side": "RIGHT",
    "body": "❓ Curious about what happens here if `user` is null, like from a guest session. Would it be worth adding a guard before accessing `user.id`?"
  }
]
```

Create the pending review:
```bash
gh api repos/{OWNER}/{REPO}/pulls/{PR_NUMBER}/reviews \
  --method POST \
  -f body="Nice work on this. {1-2 sentence overall impression, conversational tone.}

A few things I liked: {specific callouts of what's well done, with file refs.}

Left {N} comments across {files reviewed}/{total files} files, mostly questions and suggestions.

_This is a pending review, only visible to you. Edit or remove comments, then submit when you're happy with it._" \
  -f event="PENDING" \
  -f commit_id="{HEAD_COMMIT_SHA}" \
  --input /tmp/pr-review-comments-{PR_NUMBER}.json
```

### Handling Large Numbers of Comments

GitHub API accepts up to ~50 comments per review. If you have more:
1. Include all Critical and Important findings as inline comments
2. Group related Minor findings into a single comment on the most relevant line
3. Put overflow Minor findings in the review body summary

## Step 9: Present Summary to User

After creating the pending review:

```
PR #{NUMBER} review is up (pending): {PR_URL}

Left {N} comments on the diff. Mostly {brief characterisation, e.g. "questions about the migration logic and a couple of suggestions"}.

Things I liked:
- {specific positive callout}
- {another if warranted}

The review is only visible to you. Have a look, edit or remove anything that doesn't land right, then submit when you're ready.
```

Also write the full review to `/tmp/pr-review-{PR_NUMBER}.md` as a local backup.

**DO NOT paste the full review into the conversation** — inline comments on the diff are the primary output. The conversation summary is a pointer.

## Step 10: Handle Errors

**If GitHub API rejects a comment** (e.g., line number not in diff): skip that comment, note it in the summary, include it in the review body instead.

**If pending review creation fails entirely:** Fall back to writing `/tmp/pr-review-{PR_NUMBER}.md`, paste it into conversation, explain what happened.

## Review Aspects Reference

Use these as a checklist. Not all apply to every PR — select based on what changed.

| Aspect | When | What to check |
|--------|------|---------------|
| **Bug detection** | Always | Logic errors, null handling, race conditions, off-by-one, missing returns |
| **CLAUDE.md compliance** | Always | Project-specific rules, naming, imports, patterns |
| **Security** | Auth/input/API changes | Injection, credential exposure, ACL gaps, input validation |
| **Migration parity** | Config/infra changes | Everything from old system replicated in new |
| **Test coverage** | Test files changed | Tests actually test logic (not mocks), edge cases covered |
| **Error handling** | Error paths changed | Silent failures, catch blocks that swallow, missing error logging |
| **Type safety** | Type definitions changed | Proper validation instead of `as` casting, type guards |
| **Git history** | Complex changes | Prior PR comments on same files, blame context |
| **PR description match** | Always | Does the code actually do what the PR says it does |
