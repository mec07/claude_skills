# FetchPR — Comments

Focused on review feedback. Use when the user asks "what did <reviewer> say", "pull the review comments", "any unresolved threads", "fetch CodeRabbit's nitpicks", etc.

## Why a separate workflow

Three distinct GitHub surfaces hold review feedback, and missing any one leads to wrong answers:

1. **`pulls/{n}/reviews`** — review-level summary bodies. CodeRabbit's "Nitpick comments" sections live here as a single body, NOT as inline threads. Easy to miss.
2. **`reviewThreads` (GraphQL)** — inline line-anchored comments WITH `isResolved` / `isOutdated`. The REST `pulls/{n}/comments` endpoint gives bodies but not thread state.
3. **`issues/{n}/comments`** — general PR chatter (status updates, side discussion). Rarely contains review feedback but worth fetching when scoping author activity.

The script pulls all three.

## Invocation

```bash
# All unresolved threads on the PR for current branch
~/.claude/skills/FetchPR/Tools/fetch.sh

# Filter to one reviewer (recommended for "what did X say")
~/.claude/skills/FetchPR/Tools/fetch.sh --author cfettes

# Include resolved threads (audit pass)
~/.claude/skills/FetchPR/Tools/fetch.sh --all --author cfettes

# JSON for chaining
~/.claude/skills/FetchPR/Tools/fetch.sh --json --author cfettes \
    | jq '.threads[] | {path, line, body}'
```

## Author filter notes

- Bots use different names per surface: `coderabbitai[bot]` (REST) vs `coderabbitai` (GraphQL). The script does literal-match per surface — pass whichever name the user said and accept that one form may match while the other doesn't. If a bot returns 0 hits, retry with the other suffix.
- Filter applies to all three surfaces (issue comments, review summaries, inline threads).

## Resolved / outdated state

- **Default scope is unresolved threads only.** Resolved threads are hidden unless `--all`.
- `[OUTDATED]` flag means the diff line the comment anchored to has shifted. The comment may reference code that no longer exists.
- Review-level summaries don't have a thread state and are always shown.

## When presenting comments to the user

- Group by surface. Lead with inline threads (most actionable), then review summaries (the long ones).
- Quote `path:line` verbatim. The line numbers are load-bearing for navigation.
- For each comment, give: author, location, severity tier (if the body has one — CodeRabbit uses 🔴/🟠/🟡; humans don't), and your assessment.
- For each comment, write an explicit **action plan** + **justification** before the user reads them. Don't just dump the comment text and ask the user.

## Default behaviour for new+unresolved comments (REQUIRED)

When the principal asks you to fetch PR comments — whether they say it explicitly or just "look at the comments / coderabbit feedback / review feedback" — assume they want the following workflow unless they say otherwise:

1. **Pull JIRA context first.** Scan the PR title, body, branch name, and commit messages for any pattern matching `[A-Z]+-\d+` (e.g. `NFW-313`, `DATA-1234`, `DEV-2`). For each reference, invoke the **JIRA skill** to fetch ticket details — summary, description, acceptance criteria, comments. If the ticket has an epic, fetch that too. Use this to scope what is and isn't relevant before reading the review comments. The principal has more context about scope than you do; the ticket helps close that gap.
2. **Fetch unresolved threads** with the script (default `--all` is OFF, so unresolved-only is the default).
3. **Filter to "new" comments** — threads where the principal (= the PR author) has NOT yet replied. A thread the author has already replied to is considered handled; skip it unless the principal asks for resolved/handled threads. The fetch JSON includes the comment chain per thread; check comment authors to determine whether the principal has already engaged.
4. **For each new+unresolved comment, present in order:**
   - Comment location: `path:line` and reviewer.
   - Severity (if the body has one) and a one-sentence summary of what the reviewer is asking.
   - **Verification**: read the cited file at the cited line yourself and state what the code actually does today. Comments age; do not assume the comment is still accurate. If you cannot verify a claim with grep / file reads / the JIRA ticket / linked docs, say so explicitly and ask the principal — see "OK to fail" below.
   - **Recommendation**: ACTION / NO-ACTION / REPLY-ONLY (see options below).
   - **Reasoning**: 1–3 sentences explaining the recommendation, citing what you saw in the file or in the surrounding context.
5. **Wait for per-comment approval before doing any work.** The principal replies approving/declining each. Do NOT batch-edit code on your initiative. Do NOT mark anything resolved on the principal's behalf.
6. **After the principal has approved a batch**, action each approved item with a precise, minimal edit. Match the principal's preferred surface (`SendMessage` to a teammate, an `Edit` to the file, a thread reply, etc.). Stop and re-confirm if a recommended edit grows beyond what was approved.

This is a **standing preference**, not a per-PR ask. If the principal volunteers extra context (e.g. "ignore the nits", "just the criticals", "approve everything as-is"), follow that for the current PR but do not unset the default.

### Recommendation options

- **ACTION** — code change required. Spell out the precise edit (file:line + the diff/snippet) so the principal can sanity-check before approving. **Reply policy: draft a reply for human reviewers; do NOT draft a reply for bot reviewers when we're taking action — the commit/diff is what the bot learns from, and a "we applied your fix" reply adds noise without teaching the bot anything new.**
- **NO-ACTION** — recommend leaving the code as-is. Always pair this with a draft thread reply (whether the reviewer is human or bot) so the reviewer learns *why* and the resolution is recorded. For bots, see REPLY-BOT voice rules below.
- **REPLY-ONLY** — the right response is a discussion comment, not a code change (e.g. clarifying intent, pointing to existing infrastructure, deferring to a follow-up ticket). Applies to both human and bot reviewers.
- **REPLY-BOT** — voice marker, not a separate recommendation. When you do reply to a bot (i.e. NO-ACTION or REPLY-ONLY against a bot reviewer), address by handle (`@coderabbitai`, `@github-copilot`, …) and be concrete enough for the bot to learn the pattern: "this is incorrect because <xyz>", "deferred to <follow-up>", "out of scope because <reason>". Reply only after the principal approves; the principal may edit before posting.

**Why no bot reply on ACTION?** Humans appreciate the acknowledgement; bots index the conversation but learn far more from the commit itself than from "thanks, fixed". A "we applied your suggestion" reply to a bot is noise both for the bot and for any future reader skimming the thread. The auto-resolve step at the end of the workflow still happens, so the thread closes cleanly.

## Drafting reply text — voice and quality

Replies follow most of the same rules as new review comments (see the ReviewPR skill for the full voice guide), with a few differences specific to replying:

**The foundation:** assume the reviewer (human OR bot) is acting in good faith and is intelligent. They have less context than the principal but more than you. Even when a bot is wrong, the right reply explains *why* it's wrong with evidence, not "you're wrong" — bots learn from corrections, humans appreciate the respect.

### Voice rules (apply to every reply)

- **Spoken English from a teammate, not a report.** No headings, no bold "STATUS" labels, no severity emoji from the original comment.
- **Default to drastically shorter than you think.** One-word and one-line replies are normal between teammates. "Same!", "Thanks! Good point!", "My bad!" are complete replies. If your draft is more than two sentences, ask whether each sentence is doing real work.
- **Skip the explicit subject when the reply is conversational banter.** The "complete sentence with subject" rule applies when you're stating a technical position, not when you're agreeing with a peer. "Same!" beats "I feel the same way." "Good point." beats "That is a good point." But still no bare participles ("Wondering if...", "Curious about...") — those read as AI.
- **No em dashes (`—`).** Use a regular dash (`-`), comma, or rephrase. Em dashes are a strong AI tell.
- **No arrow characters (`→`).** Use `->` if you need an arrow.
- **No attribution/signature lines.** Never end with "- PAI", "Generated by AI", "Reviewed automatically", etc. The reply should read as if the principal wrote it.
- **Never cite guidelines, rules, or documentation by name** ("per the coding guidelines", "CLAUDE.md says..."). If a convention exists, mention it casually as something the codebase does.
- **One topic per reply.** Don't bundle clarifications, fixes, and pushback into one wall of text — split them into separate replies on separate threads if needed.
- **No need to lead with an emoji** (unlike new review comments). Mid-sentence or end-of-sentence emoji is fine and can soften tone (`thanks 🙏`, `nice catch ⚡`). Don't overuse.
- **Don't invent justifications the reviewer didn't ask for.** If the reviewer said "doesn't matter, leaving it in is fine" and the principal agrees, the reply is "yeah, leaving them in" — not a paragraph rationalising the choice with hypothetical future consumers, downstream cost arguments, etc. Adding unrequested reasoning reads as defensive and AI-shaped.

### Per recommendation type

**ACTION (we changed code based on the comment):**
- **Human reviewers: draft a reply.** Acknowledge the point. Default to NOT describing the fix - the commit/diff already shows what changed. Only describe the fix when the change is non-obvious from the diff or when there's a subtle reason worth recording for future readers.
- **Bot reviewers: do NOT draft a reply.** The commit/diff is what the bot indexes; a "thanks, applied" reply is noise for both the bot and human skim-readers. The auto-resolve step closes the thread cleanly.
- Don't paste commit SHAs into the reply. Humans don't do that — GitHub's UI auto-links new commits to the PR, and reviewers see them in the commit list. Pasting a SHA reads as machine-generated.
- **Owning a real mistake is fine, even with enthusiasm.** When the reviewer actually caught a bug, "excellent point! Thanks! Well spotted! My bad!" reads as genuine, not sycophantic. The sycophancy rule applies to gushing over routine suggestions, not to acknowledging real catches. Match the size of the thanks to the size of the catch.
- For routine nits where the principal agreed and applied the change, "Thanks! Good point!" alone is often the entire reply. Resist the urge to add "moved X to Y and reused it in Z" - the diff says that.

  Good (nit applied): ``Thanks! Good point!``
  Good (real bug caught): ``excellent point! Thanks! Well spotted! My bad!``
  Good (subtle fix worth narrating): ``Good point. Added a 30s timeout - without it a hung Cardinal would stall the whole DTS persist.``

  Bad: ``Added the 30s timeout in `a1b2c3d`.`` (SHA is a robot tell)
  Bad: ``**FIXED**: timeout added.``
  Bad: ``Good shout - moved the `MetricMappings` alias to `services/metric_mappings.py` and reused it in both places.`` (restating the diff)
  Bad: ``Thank you so much for this excellent suggestion! 🙌 I have implemented your fix.`` (gushing for a routine ask)

**NO-ACTION (we disagree):**
- Acknowledge the concern (don't dismiss).
- State the actual situation with a concrete pointer (file:line, behaviour, or a quick code snippet).
- For bots, end with a brief explanation that's specific enough they can learn the pattern. For humans, invite further discussion if reasonable.
- Don't be passive-aggressive. Don't say "as I mentioned" or "actually". Just state the facts.

  Good (to bot): ``The original test was actually correct. The pre-existing `GET /metric-mappings` aliases the column as `metricDefinitionId` (see `fetchMetricMappings.ts:48`), and the test passes those values into the new POST. To avoid the same confusion for future readers we've gone further and renamed the new endpoint's field to match the pre-existing one for consistency.``

  Bad: ``This is incorrect.``  Bad: ``Wrong - the test is fine.``

**Never use internal variable names as nouns in a reply.** If your reply leans on names like `path_a`, `path_b`, `df_x`, or any identifier that lives only inside the codebase, the reviewer has to translate them back to concepts before they can read the sentence. State what each path or variable IS, in plain English, the first time you mention it. The principal does not speak in variable names; reviewers should not have to either.

  Good: ``Yes, that's right. I deliberately went down the path of only using `TENANT_ENERGY` when it is available (even when it is sparse). It is a cumulative metric, so even if it is sparse, each new value is always correct at that point in time. It has been done per tenant though, so one tenant may use `TENANT_ENERGY` while another may use the integration over time of the power. Do you think this is the right approach?``

  Bad: ``Right - current logic: a tenant is excluded from path B as soon as path A produces any row for it in the window, even if path A is sparse. The rationale is that real cumulative TENANT_ENERGY is the source of truth where it exists, and mixing path A (cumulative) with path B (interval, integrated from calculated power) on the same tenant in the same window would compose two different semantics. The "all-meters-fresh" gate inside path A already filters out grid points where coverage is partial. If we want to lean on path B when path A is sparse, the cleaner cut would be: per-grid-point fallback rather than per-tenant.``

The bad version reads as a code-walkthrough; the good version reads as an engineer explaining the design choice. The metric names (`TENANT_ENERGY`) are real domain terms and stay; the internal path labels are noise.

**REPLY-ONLY (clarification, no code change):**
- Provide the missing context concisely.
- If the reviewer's concern is real but the right place to handle it is elsewhere (a separate ticket, a follow-up PR), say so explicitly and link the follow-up if it exists.

  Good: ``This is intentional - we want one Kafka message per (site, model) so message size stays bounded. The persistence loop runs after the per-site collection and produces messages with that grouping.``

**REPLY-BOT (bot was wrong, write so it learns):**
- Be more explicit and patient than you would for a human. Bots index the reply for future reviews.
- Spell out the specific mechanism that makes the bot's claim incorrect.
- A short concrete reply is more useful to a bot than a long abstract one.

### Things to avoid (extracted from past noise)

- Sycophantic openers for routine asks: "Great point!" on a style nitpick, "Excellent observation!" on a one-line typo fix. (Fine when tied to a real catch — see ACTION above.)
- Vague closures with no acknowledgment: "Done.", "Fixed.", "Resolved." standalone. "Thanks! Good point!" does the job better.
- Hostile pushback: "I disagree.", "This is wrong." without explanation.
- Overuse of emoji for tone signalling. One per reply at most, and only if it actually helps.
- Restating the original comment back to the reviewer.
- Restating the diff in the reply: "moved X to Y and updated Z" when the diff already shows that.
- Adding hedged justifications the reviewer didn't ask for ("worth keeping for any future consumer", "cheap to include") - reads as defensive.
- Speaking on behalf of the principal as "we" when the principal hasn't reviewed the reply yet — draft in first person ("we" or "I" — pick one and stay consistent), and let the principal edit before posting.

### Don't re-explain the reviewer's own idea back to them

If the reviewer proposed something, you don't need to summarise their proposal in your reply. They wrote it; they know it. Echoing "the X you're describing would mean computing both Y and Z" is patronising, especially when the reviewer is a domain expert (someone who wrote the original code, owns the system, etc.). Engage with the substance directly.

  Bad: ``The per-grid-point fallback you're describing would mean computing both at every 5-min grid point: a cumulative-derived value (X) and a power-derived value (Y), then preferring cumulative and falling back to power-derived per timestamp rather than per tenant per window. Two things make me hesitant to do that in this PR. First, the cumulative reading is "energy since meter inception" while a running power-integrated value is "energy since the start of this run window"...``  (paragraph of restating + two paragraphs of explaining the codebase to the person who wrote it)

  Good: ``I would prefer to not add any extra features in this PR. It is already an extremely complex and large PR and there is a lot of pressure from HoldCo/Justin etc to get this over the line. If you want, we can create a follow up ticket to interpolate across the gaps that can be picked up at a later point. Let me know! / You are quite right that we are likely to get gaps in both metrics at the same time.``  (states the real reason for deferring, offers a concrete next step, briefly acknowledges the reviewer's own observation)

### Lead with the real reason for deferring, not a technical hedge

When the answer is "not in this PR", the honest reason is usually scope, timeline, or business pressure (release deadline, customer ask, large PR getting reviewed). Say that. Technical justifications ("semantic mismatch", "edge case correlations") sound like you're trying to convince the reviewer they're wrong rather than acknowledging their idea is reasonable but mistimed. The two are different conversations.

If the technical concern is genuinely the deciding factor, state it briefly and don't pile on. One sentence per concern, not a paragraph.

### Trust the reader's expertise

Reviewers who wrote the original module, own the system, or have years more context than you do not need codebase explanations. Don't describe `forward_fill_to_grid` semantics to the person who wrote it. Don't explain what cumulative vs interval energy means to the data scientist who designed the metric. Treat them as a peer; if your reply needs that explanation, the reply is targeted at the wrong audience.

### When the GitHub thread won't let you reply inline

GitHub occasionally locks the in-thread reply UI on long discussions. The fallback the principal uses is a top-level PR comment that tags the reviewer with `@handle` and quotes the specific message being replied to:

```
@cfettes In response to:
> <quoted body of the comment you're addressing>

<your reply>
```

This is functionally equivalent to a thread reply, just rendered as a top-level comment. Use the same voice rules.

### Don't sound dismissive when deferring or punting

If the reply defers a concern to a follow-up ticket, a separate PR, or "later", word it as a continuation, not a brush-off. Phrasing like "so it can be triaged on its own merits", "this isn't the right place for it", or "flagging for someone else to handle" can read as dismissive even when the work itself is genuinely follow-up. The reviewer raised a real concern; they want acknowledgment that it landed and is being tracked, not justification for why it's not in this PR.

State the action plainly. Link the ticket. That's enough.

  Good: ``I've created a backlog ticket for this: NFW-337.``

  Good: ``Opened a follow-up ticket so we can size this properly: NFW-337.``

  Bad: ``I've created a backlog ticket to flag this so it can be triaged on its own merits: NFW-337.`` (the "on its own merits" reads as defending the deferral)
  Bad: ``This is out of scope for this PR but I've logged NFW-337 to capture it.`` ("out of scope" is reviewer-as-overstepping)
  Bad: ``Tracked in NFW-337 for future consideration.`` ("future consideration" is corporate dismissal)

The principal does not need to defend their scoping decisions to the reviewer. A short sentence and a link respects both their time and the reviewer's.

## Closing the loop after the principal pushes a fix

When the principal pushes code addressing a comment (or you've staged the fix on their behalf and they've committed):

1. **Draft a reply only for comments where a reply is warranted.**
   - **Human reviewer + ACTION:** draft a short reply (e.g. "thanks, good catch"). Don't paste commit SHAs.
   - **Human reviewer + NO-ACTION / REPLY-ONLY:** draft a reply explaining the reasoning.
   - **Bot reviewer + ACTION:** *no reply*. The commit/diff is what the bot indexes — a "thanks, applied" reply adds noise. Skip straight to step 4 (auto-resolve).
   - **Bot reviewer + NO-ACTION / REPLY-ONLY:** draft a reply addressed by handle so the bot can learn the pattern (see REPLY-BOT voice above).
2. **Surface the drafts to the principal for approval before posting.** They may edit. Never post a reply unilaterally.
3. **After the principal approves a reply, post it** via `gh pr comment` (issue-level) or, for inline threads, via `gh api graphql` adding a `addPullRequestReviewThreadReply` (or `gh api repos/{owner}/{repo}/pulls/{pr}/comments/{id}/replies` for REST inline comments). Skip this step entirely for bot+ACTION (no reply exists).
4. **Auto-resolve bot threads; do NOT auto-resolve human threads.** Bots include `coderabbitai`, `github-copilot`, `github-actions`, etc. — anyone whose handle ends in `[bot]` on GitHub or is one of the recognized review bots. For bot+ACTION, resolve immediately after the fix is pushed (no reply needed). For bot+NO-ACTION / REPLY-ONLY, resolve after the reply lands. Resolve via:

   ```bash
   gh api graphql -f query='mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { isResolved } } }' -f id="<thread-node-id>"
   ```

   The `<thread-node-id>` is the `thread_id` field the fetch script already emits (a `PRRT_…` value) on every thread — in `--json` (key `thread_id`) and in the human-readable output (the `thread: PRRT_…` line under each thread). Use it directly for both `resolveReviewThread` and `addPullRequestReviewThreadReply`; no separate GraphQL query is needed. (Note the JSON key is `thread_id`, not `id`.)

   For human reviewers, leave the thread open and let them resolve when satisfied. Only the human can decide whether their concern was actually addressed.
5. **If the principal asks you to skip a reply** (e.g. "just resolve, don't reply"), still resolve only for bots; for humans, don't resolve and don't reply.

### Output shape (use this layout per comment)

```
### Comment N — <reviewer> on <path>:<line> [severity tag — see Severity tags below]
**Reviewer asks:** <one sentence>
**Verification:** <what the file actually shows now, with file:line refs>
**Recommendation:** ACTION | NO-ACTION | REPLY-ONLY
**Reasoning:** <1–3 sentences>
**Draft edit:** (when ACTION — always)
   <the proposed diff/snippet>
**Draft reply:** (per reply policy below)
   <the proposed reply text>
```

**Draft reply policy:**
- Human reviewer + ACTION → draft reply (short acknowledgement).
- Human reviewer + NO-ACTION / REPLY-ONLY → draft reply (explain reasoning).
- Bot reviewer + ACTION → **no draft reply** (the commit speaks).
- Bot reviewer + NO-ACTION / REPLY-ONLY → draft reply (so the bot can learn the pattern).

After all comments are listed, end with: "Awaiting your approval per comment."

### Severity tags

CodeRabbit emits its own severity in each comment body, typically one of:

| Tag in body | Meaning |
|---|---|
| 🔴 Critical / Blocker | "This will break in production." |
| 🟠 Major | "Real problem worth fixing in this PR." |
| 🟡 Minor / Nitpick | "Style / micro-optimisation / suggestion." |
| ⚡ Quick win | Orthogonal — "small change for clear benefit." (CodeRabbit attaches this freely, often to majors.) |
| ⚠️ Potential issue | Hedged — "this might be wrong." |

**When presenting:** quote whatever tags the body actually carries verbatim — don't invent or default. If a comment carries no severity (humans usually don't), say `[no severity]` rather than guessing. Don't apply your own severity inflation/deflation; the reviewer's original tag is informative even when the recommendation diverges from it.

## OK to fail — ask, don't hallucinate

You are NOT expected to know the codebase, the business domain, or the principal's intent better than the principal. If after grepping the codebase, reading the relevant docs / CLAUDE.md, and pulling the JIRA ticket you still cannot confidently verify a comment, **stop and ask** rather than guessing.

Specifically, ask the principal when:

- A reviewer cites runtime / production behaviour you cannot reproduce locally.
- An assertion depends on the relative rate / scale of two things (sites vs models, requests/sec, etc.) that you have no way to measure.
- A recommendation hinges on a stylistic or strategic preference (`SendMessage` vs file edit, sync vs async, fail-fast vs degrade) that the principal hasn't already stated.
- The fix would touch code or infrastructure outside what you've read.
- You're tempted to write "presumably" / "likely" / "I'd guess" — that's the signal to ask instead.

Asking is preferred over hallucinating. The principal would rather answer one question than unwind a wrong recommendation.

## Closed/merged PRs

The script exits 3 with title + URL. Tell the user and ask for the new PR number — don't chase successor PRs from comment chatter.

## Verification before recommending a fix

- Read the cited file at the cited line. Comments age; the code may have changed.
- For `[OUTDATED]` comments, treat them as historical context unless the user says otherwise.
- For comments suggesting "use existing helper X", read X yourself and verify it does what the reviewer claims before recommending the swap.
