# PRMinder — Design Spec

**Date:** 2026-05-07
**Status:** Draft (pending user review)
**Repo (new):** `pr_minder` (to be created by user)
**Skill name:** `PRMinder`

## 1. Goals

Babysit the user's open GitHub PRs:

1. **Detect** failing CI checks across the user's open PRs every 10 minutes.
2. **Classify** the failure category deterministically enough that a small model can reliably tag it (`lint`, `unit_test`, `integration_test`, `build`, `terraform`, `docker`, `other`).
3. **Act** based on a deterministic decision table:
   - Reruns for flake-prone categories (capped at 2 per head SHA).
   - Spawn a full-fledged Claude Code session to fix lint failures and small bugs (gated by per-repo flags and a clean working tree).
   - Notify on anything that isn't auto-fixable.
4. **Notify** on new comments from non-self authors on open PRs.
5. **Surface state** to the user via a brief file written each cycle and read at Claude Code session start.

The split is **80% deterministic code, 20% LLM** — the small model only categorises; a full-fledged Claude only attempts a surgical fix and self-bails on complex cases. All gating, dedup, and lifecycle decisions are code-side.

## 2. Non-goals

- Web dashboard, period consolidation, multi-account auth (pai_email's needs).
- Webhook-based reactivity. Polling is fine; the user accepted ~10-minute latency.
- Running PRMinder inside CI. The "cd into the directory" model requires running on the user's machine with the user's `gh` auth.
- Auto-merging. PRMinder commits/pushes; merging is always the user's call.
- Editing PRs the user did not author.

## 3. Repo layout

```
pr_minder/
├── stow/
│   └── skills/PRMinder/
│       ├── SKILL.md
│       └── Workflows/
│           ├── Fix.md
│           ├── Status.md
│           ├── Configure.md
│           └── Triage.md
├── src/
│   ├── pipeline/
│   │   ├── pr-minder-process.ts
│   │   ├── fetch-prs.ts
│   │   ├── fetch-checks.ts
│   │   ├── fetch-comments.ts
│   │   ├── classify.ts
│   │   ├── dispatch-fix.ts
│   │   ├── dispatch-rerun.ts
│   │   └── notify.ts
│   ├── lib/
│   │   ├── config.ts
│   │   ├── db.ts
│   │   ├── git.ts
│   │   ├── repo-resolver.ts
│   │   ├── github/
│   │   │   ├── prs.ts
│   │   │   ├── checks.ts
│   │   │   └── comments.ts
│   │   └── brief.ts
│   └── types.ts
├── migrations/
│   ├── 001_init.up.sql
│   └── 001_init.down.sql
├── scripts/
│   ├── install.ts
│   ├── install-scheduler.ts
│   └── migrate.ts
├── tests/
│   ├── pipeline/
│   ├── lib/
│   └── fixtures/
├── config.example.json
├── package.json
├── bunfig.toml
├── tsconfig.json
├── vitest.config.ts
└── README.md
```

GitHub fetch logic is a TypeScript port of patterns from `claude_skills/stow/FetchPR/Tools/fetch.sh`. The PRMinder repo carries no skill-level dependency on FetchPR.

## 4. Configuration

`~/.config/pr-minder/config.json`:

```json
{
  "repos": [
    {
      "service": "github.com",
      "owner": "foo",
      "repo": "bar",
      "path": "/Users/powerx/src/github.com/foo/bar",
      "auto_fix_linting": true,
      "auto_fix_bugs": true,
      "auto_push": true
    }
  ],
  "defaults": {
    "auto_fix_linting": true,
    "auto_fix_bugs": false,
    "auto_push": false,
    "notify_on_new_comments": true
  },
  "poll_interval_min": 10,
  "classifier_model": "haiku",
  "search_roots": ["~"],
  "search_excludes": ["Library", "node_modules", ".cache", ".bun", ".cargo", ".npm", "Applications"]
}
```

- **`repos[]`** is an explicit allow-list (overrides). Empty or omitted → fall back to `gh search prs --author @me --state open` and resolve clone paths via `repo-resolver` (Section 6).
- **Per-repo flags** override `defaults`.
- `auto_fix_linting` / `auto_fix_bugs` / `auto_push` are deterministic gates the orchestrator enforces; they are never sent to a model.
- `auto_fix_bugs` covers the spawn-fix path for `unit_test`, `integration_test` (after rerun), `build`, `terraform`, `docker`. Per-category flags are a v2 consideration if granularity is needed.

## 5. Database schema

Postgres. `lib/db.ts` exposes typed query functions; tests stub them. No tests hit a real database.

`migrations/001_init.up.sql`:

```sql
CREATE TABLE pr_runs (
    id              BIGSERIAL PRIMARY KEY,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at     TIMESTAMPTZ,
    prs_checked     INTEGER NOT NULL DEFAULT 0,
    actions_taken   INTEGER NOT NULL DEFAULT 0,
    errors          JSONB
);

CREATE TABLE pr_attempts (
    id                 BIGSERIAL PRIMARY KEY,
    run_id             BIGINT REFERENCES pr_runs(id) ON DELETE SET NULL,
    repo               TEXT NOT NULL,
    pr_number          INTEGER NOT NULL,
    head_sha           TEXT NOT NULL,
    failing_checks     JSONB NOT NULL,
    category           TEXT NOT NULL,
    classifier_reason  TEXT,
    action             TEXT NOT NULL,
    outcome            TEXT,
    fix_commit_sha     TEXT,
    fix_pushed         BOOLEAN NOT NULL DEFAULT FALSE,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX pr_attempts_dedup_idx  ON pr_attempts (repo, pr_number, head_sha);
CREATE INDEX pr_attempts_recent_idx ON pr_attempts (created_at DESC);

CREATE TABLE pr_comments_seen (
    id              BIGSERIAL PRIMARY KEY,
    repo            TEXT NOT NULL,
    pr_number       INTEGER NOT NULL,
    comment_id      TEXT NOT NULL,
    comment_type    TEXT NOT NULL,
    author          TEXT NOT NULL,
    created_at_gh   TIMESTAMPTZ NOT NULL,
    seen_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    notified_at     TIMESTAMPTZ,
    UNIQUE (repo, pr_number, comment_id, comment_type)
);
CREATE INDEX pr_comments_seen_pr_idx ON pr_comments_seen (repo, pr_number);

CREATE TABLE local_repos (
    id              BIGSERIAL PRIMARY KEY,
    service         TEXT NOT NULL,
    owner           TEXT NOT NULL,
    repo            TEXT NOT NULL,
    local_path      TEXT,
    discovered_via  TEXT NOT NULL,
    last_verified   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (service, owner, repo)
);
```

**Allowed values:**

- `pr_attempts.category` ∈ `{ lint, unit_test, integration_test, build, terraform, docker, other }`
- `pr_attempts.action`   ∈ `{ rerun, fix-attempted, notified, skipped_dirty, skipped_dedup, skipped_no_local_path, skipped_disabled }`
- `pr_attempts.outcome`  ∈ `{ success, failed, complex_bailout, NULL }` (NULL = pending or rerun-style non-terminal)
- `local_repos.discovered_via` ∈ `{ convention, search, manual_config, not_found }`

## 6. Repo path resolution (`lib/repo-resolver.ts`)

For a `(service, owner, repo)`:

1. **Cache hit.** Look up `local_repos`. If `local_path` set and `git -C <path> remote get-url origin` matches `<service>/<owner>/<repo>`, return path.
2. **Convention guesses (in order):**
   - `~/src/<service>/<owner>/<repo>`
   - `~/code/<service>/<owner>/<repo>`
   - `~/dev/<service>/<owner>/<repo>`
   - `~/src/<owner>/<repo>`
   - `~/code/<owner>/<repo>`
   - `~/dev/<owner>/<repo>`

   For each, verify it's a git directory and `origin` URL matches. First hit persists with `discovered_via='convention'`.
3. **Disk search.** Walk `search_roots` (default `~`) up to depth 6, skipping `search_excludes`. For each `.git/config` found, parse `[remote "origin"] url`. First match for the target repo persists with `discovered_via='search'`. Implementation can prefer `fd` if available, else a native walker.
4. **Not found.** Persist `local_path=NULL, discovered_via='not_found'`. The PR is routed to notify-only with reason "no local clone." Don't re-search every cycle; re-attempt only when `last_verified > 24h` or on user-triggered refresh.

## 7. Pipeline (`pipeline/pr-minder-process.ts`)

Runs every 10 minutes via launchd (macOS) or systemd user timer (Linux). One step's failure does not abort the cycle — errors are appended to `pr_runs.errors`.

```
0. INSERT pr_runs (started_at)
1. fetch-prs            → list of {repo, pr#, head_sha, branch}
2. resolve-paths        → attach local_path or NULL
For each PR:
  3a. fetch-checks      → failing checks. If none → continue (no row written)
  3b. dedup check       → terminal row at (head_sha, failing_checks) → skipped_dedup
  3c. fetch failure log → log excerpt for classifier
  3d. classify          → { category, reason }
  3e. orchestrator gate → see decision table (Section 8). Determines action.
  3f. dispatch          → rerun | fix | notify. Insert pr_attempts.
  4.  fetch-comments    → diff vs pr_comments_seen, notify net-new (batched per PR).
5. brief-write          → ~/.claude/skills/PRMinder/brief.md
6. UPDATE pr_runs (finished_at, prs_checked, actions_taken)
```

PRs are processed sequentially in v1; the loop is structured so a future change to parallelize per-PR work is local.

## 8. Decision table (orchestrator gate)

After the classifier returns `category`, the orchestrator selects an action deterministically. `dirty = git -C <path> diff HEAD --quiet returns non-zero` (tracked-file edits, staged or unstaged; untracked files ignored). `gates` = `dirty || !localPath || flag-off`.

| `category`         | First attempt at this head_sha               | If a prior `rerun` has hit the cap (2) and checks still failing |
|--------------------|----------------------------------------------|------------------------------------------------------------------|
| `lint`             | spawn-fix (gate: `auto_fix_linting`)         | n/a                                                              |
| `unit_test`        | spawn-fix (gate: `auto_fix_bugs`)            | n/a                                                              |
| `integration_test` | rerun                                         | spawn-fix (gate: `auto_fix_bugs`)                                |
| `build`            | rerun                                         | spawn-fix (gate: `auto_fix_bugs`)                                |
| `terraform`        | rerun                                         | spawn-fix (gate: `auto_fix_bugs`)                                |
| `docker`           | rerun                                         | spawn-fix (gate: `auto_fix_bugs`)                                |
| `other`            | notify                                        | n/a                                                              |

If a `spawn-fix` gate fails, no Claude is spawned. The `pr_attempts.action` column records the specific reason — `skipped_disabled` (flag off), `skipped_dirty` (working tree has tracked-file edits), or `skipped_no_local_path` (couldn't resolve a clone). A notification is fired alongside, mentioning the reason. These rows are terminal for dedup at this `(head_sha, failing_checks)`, so the user is notified once per failure-set, not every cycle.

## 9. Dedup rules

- **Terminal** rows (block re-action at the same `(head_sha, failing_checks)`):
  - `action='fix-attempted'` with non-null `outcome`
  - `action='notified'`
  - `action='skipped_*'`
- **Non-terminal:** `action='rerun'`. PRMinder always re-evaluates check status after a rerun.
- **Rerun cap:** at most 2 `rerun` rows per `(repo, pr#, head_sha)`. The third failure escalates per the decision table.
- A new commit changes `head_sha`, which clears all dedup state for that PR.

## 10. Classifier (`pipeline/classify.ts`)

Single LLM call per PR per cycle. Model: small/fast (`haiku`-tier via `Inference.ts standard` or equivalent). Returns strict JSON.

**Input:** PR title, branch, list of failing check names + jobs, and a bounded log excerpt (head + tail of `gh run view --log-failed`, capped at ~6KB total).

**Output:**

```json
{
  "category": "lint" | "unit_test" | "integration_test" | "build" | "terraform" | "docker" | "other",
  "reason": "<one-sentence justification grounded in the evidence>"
}
```

The prompt steers the model toward objective signals only — file paths, folder names (`/tests/integration/`, `/e2e/`), pytest markers, job names (`integration`, `e2e`, `lint`, `format`, `terraform plan`, `docker build`), tool error signatures (`tflint`, `terraform`, `docker:`, `eslint`, `prettier`). It does **not** ask the model to judge complexity. It does **not** ask the model to recommend an action. Misclassifications fail safely: a wrong category routes to `notify` more often than to a bad fix because the gate cascade is asymmetric.

If the response is unparseable JSON or `category='other'`: action = `notify`, never spawn.

## 11. Spawning Claude (`pipeline/dispatch-fix.ts`)

The full-fledged model is the only thing that judges complex-vs-simple. Settings are not in its context.

```ts
// Brief is structured runtime context only — no flags, no permissions.
const briefPath = await writeBrief({
  repo, prNumber, headSha, branch,
  failingChecks, logExcerpt,
  category,                  // lint | unit_test | ...
});

const result = await spawnClaude({
  cwd: localPath,
  prompt: await readSkillWorkflow("Fix.md"),
  briefPath,                 // appended to prompt
  permissionMode: "bypassPermissions",
  timeoutMs: 10 * 60_000,
});
```

Claude commits but does **not** push. PRMinder, after parsing the marker, runs `git push` itself when `repoCfg.auto_push=true`. This keeps lifecycle decisions code-side.

### Marker contract

The spawned Claude must emit exactly one final line:

```
<<<PRMINDER_RESULT>>>{"outcome":"fixed"|"complex_bailout"|"failed","commit_sha":"<sha-or-null>","summary":"<one sentence>"}<<<END>>>
```

Parser rules:
- Missing marker → `outcome='failed'`, notify with log path.
- `commit_sha` non-null + `outcome='fixed'` + `auto_push=true` → PRMinder runs `git push`. Records `fix_pushed`.
- `outcome='complex_bailout'` → notify the user with Claude's summary.
- `outcome='failed'` → notify with log path.

### `Workflows/Fix.md` (prompt skeleton)

```
You are PRMinder's fix executor. You are running headless in a checked-out clone of a PR's repo.

Your job:
1. Read the BRIEF (PR title, branch, failing checks, log excerpt, category).
2. `gh pr checkout <n>` if you are not already on the PR branch.
3. Investigate the failure. Stay scoped to the cited failing checks.
4. Decide: is this a SURGICAL fix?
   • One file, one rule / one obvious bug, no design implication: yes — apply it.
   • Multi-file, ambiguous, design call, or product decision: NO. Bail out.
5. If fixing: make the smallest change that resolves the failing check. Run the check
   locally if cheap to do so. `git add` the touched files. Commit with the message
   "fix: <one-line> [PRMinder]". DO NOT push.
6. Emit exactly one final marker:
   <<<PRMINDER_RESULT>>>{...}<<<END>>>

Hard rules:
- Surgical fixes only. Never delete tests, never rearchitect, never refactor unrelated code.
- Never amend. Never force-push. Never run destructive git operations.
- If anything is unclear, bail out with complex_bailout — a notification is better than a bad fix.
- Do not push. PRMinder pushes if configured.
```

## 12. Comment notifications (`pipeline/fetch-comments.ts`)

Pulls the same three GitHub surfaces FetchPR pulls:

- REST `/repos/{owner}/{repo}/issues/{n}/comments` (issue chatter)
- REST `/repos/{owner}/{repo}/pulls/{n}/reviews` (review-summary bodies — CodeRabbit nitpick sections live here)
- GraphQL `pullRequest.reviewThreads` (inline thread comments with `isResolved`/`isOutdated`)

Per cycle, for each open PR:

1. Fetch all three surfaces.
2. Filter `author != viewer` (resolved via `gh api user`).
3. Insert each `(repo, pr#, comment_id, comment_type)` into `pr_comments_seen` with `ON CONFLICT DO NOTHING`.
4. The rows actually inserted are the net-new ones. Group by `(repo, pr#)`.
5. Per group, fire one notification: `"PR #<n>: <count> new comments from <distinct authors>"` with click-action = PR URL. Set `notified_at`.

Disabled by `defaults.notify_on_new_comments=false` (or per-repo override).

## 13. Skill surface

### `stow/skills/PRMinder/SKILL.md`

```yaml
---
name: PRMinder
description: Babysitter for your open PRs. Watches CI failures, distinguishes flaky from real,
  reruns flakies, fixes simple lint/bug failures by spawning a full Claude session, and
  notifies you on new PR comments. Runs every 10 minutes via launchd/systemd. USE WHEN:
  pr minder, prminder, monitor my prs, what's the state of my prs, why is CI failing,
  set up pr autopilot, configure pr fixing, who commented on my pr.
---
```

| Slash invocation        | Workflow              | Behaviour                                                                  |
|-------------------------|-----------------------|----------------------------------------------------------------------------|
| `/PRMinder`             | `Workflows/Status.md` | Read the latest brief file. Optionally query Postgres for richer context. |
| `/PRMinder configure`   | `Workflows/Configure.md` | Walks the user through editing `~/.config/pr-minder/config.json`.       |
| `/PRMinder run [PR#]`   | `Workflows/Triage.md` | One-off invocation against a single PR. `--force` skips dedup.            |

### Brief file (`~/.claude/skills/PRMinder/brief.md`)

Written every cycle. Read by the SessionStart hook.

```markdown
# PRMinder — last run 2026-05-07T14:32:11+01:00

3 of 5 open PRs healthy.

## Awaiting your attention
- PR #1234 (foo/bar): integration test failed twice on rerun — escalation needed (auto_fix_bugs=off)
- PR #5678 (team/shared): 2 new comments from coderabbitai

## Recent autonomous actions
- 14:32 — PR #2345 (foo/bar): rerun lint check (1st attempt)
- 14:21 — PR #1122 (foo/bar): pushed lint fix `abc1234` "fix: reformat src/x.ts [PRMinder]"

## Healthy PRs
- PR #3344, PR #4455, PR #6677
```

The brief shows the absolute datetime of the last run (no relative "X minutes ago" — keeps it deterministic and easy to diff).

### SessionStart hook

A one-liner: `cat ~/.claude/skills/PRMinder/brief.md` (silent if missing). Installed by `bun install:hook` into `~/.claude/settings.json` (merged, not overwritten — same pattern as `email-brief`).

## 14. Error handling

| Error                                  | Behaviour                                                                                  |
|----------------------------------------|--------------------------------------------------------------------------------------------|
| `gh` unauthenticated                   | Append to `pr_runs.errors`, single notification per cycle ("PRMinder: gh auth expired"). |
| Repo not found locally                 | Insert `local_repos` row (`not_found`), single notification, `action='skipped_no_local_path'`. |
| Postgres unavailable                   | Write `~/Library/Logs/pr-minder/fallback-<ts>.jsonl`. Exit non-zero so the scheduler logs it. |
| Claude spawn timeout (10 min default)  | Kill subprocess. `outcome='failed'`. Notify with log path.                                 |
| Claude spawn marker missing/malformed  | `outcome='failed'`. Notify.                                                                |
| `git push` fails post-fix              | `fix_pushed=false`. Notify with the local commit SHA.                                       |
| Classifier returns invalid JSON        | Treat as `category='other'`. `action='notified'`. Never spawn.                              |
| `gh pr checks` rate-limit              | Per-step error in `pr_runs.errors`. Skip the PR this cycle. Pipeline continues.           |

All notifications are throttled implicitly by dedup state — once a (head_sha, failing_check_set) is `notified`, repeats are suppressed until the SHA advances.

## 15. Testing strategy

`vitest`. Run with `bun run test` (per pai_email convention — `bun test` shares a single process and leaks mocks).

- **Unit tests** for every pipeline step: pure functions over fixture JSON in `tests/fixtures/` (sample `gh pr list`, `gh pr checks`, `gh run view --log-failed`, `gh api` review/comment shapes).
- **Repo resolver** against an in-memory tmp filesystem covering: cache hit, cache stale, convention success, convention miss, disk search hit, search miss, not-found persistence.
- **Classifier** with stubbed inference: assert correct prompt, assert JSON schema enforcement, assert behaviour on malformed responses. Snapshot the prompt to detect drift.
- **Orchestrator gating** matrix tests: `category × auto_fix_linting × auto_fix_bugs × dirty × localPath` → expected `action`.
- **Spawn-Claude** harness: env-var override that points the spawn to a fake binary emitting canned markers. Covers parsing success, missing marker, timeout, malformed marker.
- **Comment notifier**: insert-on-conflict semantics, author filtering, batched message format.
- **No tests hit Postgres.** `lib/db.ts` exposes typed query functions; tests stub them.

## 16. Install

`bun run setup` mirrors pai_email:

1. Check prerequisites (bun, psql, golang-migrate, gh, terminal-notifier).
2. Copy `config.example.json` → `~/.config/pr-minder/config.json` if missing.
3. `bun install`.
4. Create database `pr_minder` and user `pr_minder_user` (skip if no superuser access — print manual instructions).
5. `bun db:migrate`.
6. `bun stow:install` symlinks the skill into `~/.claude/skills/`.
7. `bun run scripts/install-scheduler.ts` registers the 10-minute launchd plist (macOS) or systemd timer (Linux).
8. `bun install:hook` adds the SessionStart hook.

## 17. Open questions / v2 deferments

- Per-category fix flags (`auto_fix_lint`, `auto_fix_bugs`, `auto_fix_infra`) instead of bundling under `auto_fix_bugs`.
- Per-PR pause toggle (e.g. `[no-prminder]` in PR description).
- Web dashboard (deferred — brief file + slash command suffice for v1).
- Parallel per-PR processing within a cycle.
- Linux `notify-send` parity for click-to-open-PR (terminal-notifier supports `-open` natively; notify-send doesn't — may need a small wrapper).
- Webhook mode for sub-minute reactivity.
