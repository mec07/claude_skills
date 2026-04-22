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

**Fetch linked JIRA tickets for context.** Scan the PR title, body, branch name, and commit messages for JIRA ticket references (e.g. `DEV-1234`). For each reference found, use the JIRA skill to fetch the ticket details — summary, description, acceptance criteria, and comments. This gives you the author's intent and the business context behind the changes. Remember: the author has more context than you do about what they are trying to achieve. The JIRA ticket helps close that gap.

## Step 3: Fetch Changed Files and Categorise

```bash
gh pr diff {PR_NUMBER} --repo {OWNER/REPO} --name-only
```

Categorise files by type/area. This determines:
- Which specialised review aspects apply
- How to partition work for parallel agents
- Which CLAUDE.md rules are relevant

## Step 4: Launch Review Analysis

### Phase 1: Analyse Using CodeReview Lenses (Internal Only)

Read the CodeReview skill's analytical framework at `~/.claude/skills/CodeReview/Workflows/Review.md`. Run each of the **5 Lenses** against the diff:

1. Architecture & Responsibility (SRP / DIP)
2. Type Safety & Contracts
3. State Management
4. Testing
5. Pragmatics & Maintainability

For each finding, record it internally with the CodeReview severity tier (🔴🟠🟡🟢), the file:line, and a short description of the issue.

**GATE: Do NOT write any PR comments during Phase 1.** This phase produces raw analytical findings only — working memory, not output. Complete the full 5-lens pass before moving to Phase 2.

### Phase 2: Translate to ReviewPR Voice

Take every raw finding from Phase 1 and translate it into ReviewPR's output format. This means two transformations:

**1. Severity → Confidence score** (determines whether the finding survives the threshold):

| CodeReview Tier | Confidence | Outcome |
|----------------|-----------|---------|
| 🔴 Critical | 90-100 | Becomes an inline comment |
| 🟠 Significant | 80-89 | Becomes an inline comment |
| 🟡 Worth Noting | 60-79 | Dropped — below the >= 80 threshold |
| 🟢 What's Good | N/A | Becomes a positive callout in the review summary body |

**2. Severity emoji → ReviewPR intent emoji.** The CodeReview colour emojis (🔴🟠🟡🟢) must NEVER appear in PR comments. Replace them with the ReviewPR intent emojis from Step 8 (💭 ❓ 🔧 👍 ⛏️ etc.). Choose the intent emoji based on what the comment is doing:

| If the comment is... | Use |
|----------------------|-----|
| Asking about a potential bug or concern | ❓ |
| Confused or uncertain, asking the author to clarify intent | 🤔 |
| Thinking through an alternative approach | 💭 |
| Suggesting a concrete change | 🔧 |
| A minor style/formatting observation | ⛏️ |
| Praising something well done | 👍 😊 💯 |
| A future improvement idea | 🌱 |
| An out-of-scope observation | 📌 |

**3. Rephrase into collaborative voice.** Every finding must be rewritten as spoken English from a teammate — questions, suggestions, and collaborative proposals. No headings, no bold severity labels, no report-style language. See Step 8's Tone and Voice section for the full voice guide and examples.

After Phase 2, proceed to the PR size routing below to determine execution strategy.

---

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

## Step 5: Cross-System Impact Analysis

Launch a research agent to check whether the PR's changes could have unexpected ripple effects elsewhere in the codebase. This is critical — in a large codebase, changing one thing in one place can break something in a completely separate area that the PR hasn't touched.

The agent should:

1. **Identify what changed semantically** — not just which files, but what contracts, formats, or behaviours shifted. For example: message formats, database schemas, API response shapes, event payloads, shared constants, interface definitions.
2. **Search for consumers and dependents** — grep the codebase for anything that reads, parses, or depends on the things that changed. Look beyond the files in the diff.
3. **Flag potential breakage** — where a consumer elsewhere in the codebase assumes the old format, schema, or behaviour and would break silently or loudly after this change.

Only flag cross-system impacts where there is concrete evidence of a dependent — a specific file and line that reads the thing that changed. Do not flag hypothetical or generic "this could affect something" concerns.

If cross-system impacts are found, they become high-confidence findings (90+) in Phase 2 and get surfaced as 🤔 or ❓ comments — asking the author whether they've considered the impact on the specific dependent, not telling them to fix it.

## Step 6: Confidence Scoring

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

## Step 7: Read Related Source Files

When the diff alone isn't sufficient:
- Read full source files being modified (not just diff hunks)
- Check callers of modified functions/modules
- Verify interfaces match between producers and consumers
- Compare before/after for refactors
- Check git blame for historical context on tricky areas

## Step 8: Build Inline Comments

For each finding that passes the confidence threshold (>= 80), record:

- **`path`**: File path relative to repo root
- **`line`**: Line number in the NEW version of the file. MUST be a line in the diff (added or context line within a hunk)
- **`side`**: Always `"RIGHT"` (comment on new version)
- **`body`**: The review comment in markdown

### Tone and Voice

**Always assume the author:**
- Knows what they are doing
- Has more knowledge and context than you do about what they are trying to achieve
- Has the knowledge to fix things themselves — present options or raise concerns, never prescribe the solution
- Is intelligent and can think things through
- Is autonomous — you are not managing them or telling them what to do
- Has good intentions
- Had good reasons for their choices

These are not guidelines — they are the foundation every comment is built on. If something looks wrong, it's more likely you're missing context than that the author made a naive mistake.

Write comments like you're talking to a teammate. Spoken English, not a report. No headings, no bold severity labels, no em dashes. Keep it human and collaborative.

The goal is to never make an enemy. You are on the same team. If something looks wrong, ask a question to understand their reasoning first. If there's a concern, raise it — but trust them to work out the right path forward. Never tell the author what to do.

Bad: "**CRITICAL**: Missing null check on `user` before accessing `user.id`. Will throw at runtime."
Good: "❓ Curious about what happens here if `user` is null, like from a guest session?"

Bad: "**IMPORTANT**: This should use a prepared statement to prevent SQL injection."
Good: "💭 This caught my eye because the query is built with string interpolation. A prepared statement would close off the injection surface — worth considering?"

Bad: "You need to add error handling here for the case where the API returns 404."
Good: "🤔 I wasn't sure what the intended behaviour is when the API returns 404 here."

Bad: "This retry logic doesn't have a backoff. Add exponential backoff to avoid hammering the service."
Good: "💭 I think we may need an exponential backoff here to avoid overwhelming the service we're calling and improve reliability of retries. What do you think?"

Bad: "🔴 These `as` casts are unsafe. Use proper typing instead of casting."
Good: "💭 There are two `as` casts in this file (here and line 197 with `as Order_By`). Since `PaginatedWritableMetricsQueryVariables["order"]` is the Hasura generated type, one way around this would be to type `initialOrderBy` directly:
```ts
const initialOrderBy: PaginatedWritableMetricsQueryVariables["order"] = [
  { metric_definition_id: "asc" },
];
```
For the `Order_By` cast on line 197, a similar approach with a typed lookup or a type guard would work. What do you think?"

Bad: "🟠 You should be importing from .generated.ts files, not .gql. Fix this and the other .gql imports in the file."
Good: "🤔 I'm a little confused about this. The project guidelines recommend importing GraphQL documents from the .generated.ts files rather than from .gql directly, since the generated files bundle the document and the TypeScript types together. I know a lot of existing features still use .gql imports, so this isn't a blocker. I wonder if it is worth writing on the frontend-guild slack channel to confirm which approach is the best?"

Bad: "🟡 paginatedMetrics is exported but unused. Remove it."
Good: "❓ paginatedMetrics is exported here but doesn't seem to be called anywhere in the PR — only paginatedWritableMetricsForSite is used. Are you planning on using this later, or could it be removed to keep things simple?"

Bad: "🔴 This loop has no flush batching, no buffer error handling, and no delivery callbacks. Use `write_batch` instead."
Good: "💭 The old path through `DerivedTimeSeriesKafkaWriter.write_dts()` had a few producer safety mechanisms that this loop doesn't:
- Flush every 10,000 messages to stay well under the buffer limit
- Count tracking + success logging (`Successfully sent X/Y derived metrics`)

And `write_batch` (used for the mapped path just above) goes further: `producer.poll(0)` every 1,000 messages for delivery callbacks, `BufferError` catch → flush → retry, and a verified flush that raises if messages are still queued after timeout.

This loop produces in a tight loop with a single `flush()` at the end. It's probably fine for small batches, but if the unmapped set gets large it could hit the producer buffer limit without the safety net.

There are a few options:
1. Use `write_batch` — call `metric_producer.write_batch(producer, unmapped_metrics, key_getter=lambda m: str(m.site_id))`. Gets you all the batch safety for free. The tradeoff is `write_batch` sends everything to one topic, so you'd lose late-metric routing.
2. Update `DerivedTimeSeriesKafkaWriter` so that `derived_output_topic_name` is optional and when not present go to the default topic. Then keep using `write_dts()` here without passing a derived topic. Lionfish1 keeps working as-is, you get all the existing safety plus the late routing.
3. Put all the safety mechanisms within this loop (this is something that we used to do in this file before introducing `write_batch`)."

### Emoji Prefixes

Start each comment with one emoji to signal intent (based on https://github.com/erikthedeveloper/code-review-emoji-guide):

| Emoji | When to use |
|-------|-------------|
| 👍 😊 💯 | **Praise.** Something is well done and you want the author to know. Use generously. |
| 🔧 | **Change suggestion.** You think this needs to change. Frame it as a suggestion or question, not a command. |
| ❓ | **Question.** You genuinely want to understand something. Provide enough context so they know what you're asking. |
| 🤔 | **Confused / uncertain.** Something doesn't quite make sense and you'd like the author to clarify their intent. Not a question you know the answer to — genuine uncertainty. |
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

## Step 9: Verify Comment Accuracy

**GATE: Do NOT post any comments to GitHub until every comment has passed verification.**

The examples in this skill show detailed, well-researched comments that reference specific function names, method signatures, line numbers, and code behaviours. It is critical that every factual claim in a comment is verified against the actual codebase — never assume or fabricate details to match the level of detail shown in the examples. A shorter, accurate comment is always better than a detailed, wrong one.

For each drafted comment, verify:

1. **Named functions, methods, classes exist.** If a comment references `write_batch` or `DerivedTimeSeriesKafkaWriter`, grep the codebase and confirm they exist and behave as described. If you cannot find them, remove the reference or rewrite the comment without it.
2. **Line numbers are correct.** Re-read the file and confirm the line number still matches what the comment describes. Line numbers shift during rebases.
3. **Described behaviour is accurate.** If a comment says "this method flushes every 10,000 messages", read the method and confirm. Do not describe behaviour you haven't verified by reading the code.
4. **Code suggestions compile.** If a comment includes a code snippet as a suggestion, check that the types, imports, and variable names used in the snippet actually exist in the codebase.
5. **Cross-references are real.** If a comment says "the mapped path just above uses `write_batch`", confirm that code path exists in the diff or file.

**If a claim cannot be verified:** Remove it from the comment. Rewrite the comment with only what you can confirm. If removing the unverified claim makes the comment empty or pointless, drop the comment entirely.

**If you are unsure whether something is true:** Do not include it. Uncertainty is not a reason to guess — it is a reason to omit or to phrase it as a genuine question (❓ or 🤔) rather than a factual statement.

## Step 10: Create Pending Review via GitHub API

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

## Step 11: Present Summary to User

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

## Step 12: Handle Errors

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
