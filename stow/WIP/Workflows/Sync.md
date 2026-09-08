# WIP Sync Workflow

Query GitHub, Azure DevOps and Jira, cross-reference the results, and render the
summary. Nothing is stored between runs.

## Step 0 — Detect what is available

Run each check. Record which sources are usable; skip the rest with a note in the
output rather than failing the run.

```bash
command -v gh >/dev/null && gh auth status >/dev/null 2>&1 && echo "github: ok"
command -v az >/dev/null && az extension show --name azure-devops >/dev/null 2>&1 && echo "azure: ok"
```

For Azure, also confirm an organization is configured — without one,
`az repos pr list` cannot run:

```bash
az devops configure -l 2>/dev/null | grep -q '^organization' && echo "azure org: ok"
```

Jira availability means the Atlassian MCP tools are present in this session.

## Step 1 — GitHub: enumerate PRs across all repos

`gh search prs` spans every repository you can see, so no owner or repo is named.

```bash
# Open PRs you authored, anywhere
gh search prs --author=@me --state=open --limit 50 \
  --json number,title,repository,url,isDraft,createdAt,updatedAt

# PRs waiting on your review, anywhere
gh search prs --review-requested=@me --state=open --limit 50 \
  --json number,title,repository,url,updatedAt

# Merged in the last 14 days (GNU date first, BSD/macOS fallback)
SINCE=$(date -u -d '14 days ago' +%F 2>/dev/null || date -u -v-14d +%F)
gh search prs --author=@me --merged --merged-at=">=$SINCE" --limit 50 \
  --json number,title,repository,url,closedAt
```

> `gh search prs --json` does **not** offer `reviewDecision`, `statusCheckRollup`
> or `mergeable`. Its fields are: `assignees, author, authorAssociation, body,
> closedAt, commentsCount, createdAt, id, isDraft, isLocked, labels, number,
> repository, state, title, updatedAt, url`. Detail needs step 2.

## Step 2 — GitHub: per-PR detail

For each open PR found in step 1, fetch the state that search cannot return:

```bash
gh pr view <url> --json number,title,url,headRefName,reviewDecision,mergeable,statusCheckRollup,isDraft,updatedAt,body
```

Run them in parallel. Put the URLs in a file and the fetch in a script, then let
`xargs` pair them:

```bash
printf '%s\n' "${urls[@]}" > "$W/urls.txt"
cat > "$W/fetch.sh" <<'SH'
#!/bin/sh
n=$(printf '%s' "$1" | sed 's|https://github.com/||; s|/pull/|_|; s|/|-|g')
gh pr view "$1" --json number,title,url,headRefName,reviewDecision,mergeable,statusCheckRollup,isDraft,updatedAt,body > "$2/$n.json" 2>/dev/null
SH
chmod +x "$W/fetch.sh"
mkdir -p "$W/detail"
xargs -P 8 -I{} "$W/fetch.sh" {} "$W/detail" < "$W/urls.txt"
```

> Do not inline the loop body into `xargs -I{} sh -c '...'` with the working
> directory interpolated. With a few dozen URLs that fails outright:
> `xargs: command line cannot be assembled, too long`. A script file on disk
> keeps each invocation short.

- `reviewDecision` — `APPROVED`, `CHANGES_REQUESTED`, `REVIEW_REQUIRED`, or empty
- `mergeable` — `CONFLICTING` means merge conflicts
- `statusCheckRollup` — any entry with `conclusion` of `FAILURE` or `TIMED_OUT`
  means CI is broken

## Step 3 — Azure DevOps

Organization and project come from the user's own `az devops configure` defaults;
the identity comes from the signed-in account. Nothing is hardcoded.

```bash
AZ_USER=$(az account show --query "user.name" -o tsv)

# Active PRs you created
az repos pr list --status active --creator "$AZ_USER" --detect false -o json

# Active PRs where you are a reviewer
az repos pr list --status active --reviewer "$AZ_USER" --detect false -o json

# Recently completed
az repos pr list --status completed --creator "$AZ_USER" --detect false --top 20 -o json
```

> `--detect false` matters. Without it `az` tries to infer the organization from
> the current repo's git remote and prints a warning to stderr whenever you run
> `/WIP` from a non-Azure checkout. Disabling detection forces it to use the
> `az devops configure` defaults, which is what we want.

Useful fields per PR: `pullRequestId`, `title`, `sourceRefName`,
`targetRefName`, `creationDate`, `status`, `isDraft`, `mergeStatus`,
`repository.name`, `reviewers[].vote`.

- `mergeStatus` of `conflicts` — merge conflicts
- `reviewers[].vote`: `10` approved, `5` approved with suggestions, `0` no vote,
  `-5` waiting for author, `-10` rejected

Azure PR URLs are built as
`{org}/{project}/_git/{repository.name}/pullrequest/{pullRequestId}`, using the
org and project already read from `az devops configure -l`.

If `az repos pr list` errors because no default project is set, retry once
without `--project` scoping by listing per repository, and if that also fails,
skip the Azure section and say why.

## Step 4 — Jira

Atlassian MCP `searchJiraIssuesUsingJql`:

```
assignee = currentUser() AND statusCategory != Done ORDER BY status ASC, updated DESC
```

`statusCategory` is used rather than `status` because status names differ between
projects; the category is standard. Fall back to `status != Done` if a Jira
instance rejects `statusCategory`.

Keep for each ticket: key, summary, status name, status category, updated.

## Step 5 — Cross-reference

Extract candidate keys matching `[A-Z][A-Z0-9]+-[0-9]+` from each PR's title,
branch name and description. The pattern is deliberately generic — a project
prefix is never hardcoded, so this works on any Jira instance and on the several
prefixes one person often has.

A candidate is not yet a ticket: `UTF-8`, `SHA-256` and `RFC-2119` all match the
shape too. Separate real keys from noise using the **project list**, fetched at
runtime — never a written-down prefix:

```
Atlassian MCP: getVisibleJiraProjects (action: browse)
```

That returns every project key the user can see. Keep a candidate only if its
prefix is one of them; discard the rest as noise.

> Filtering against the prefixes seen in step 4 instead would be wrong. Step 4
> only returns tickets **currently assigned to you and not Done**, so a PR citing
> a ticket in any other project — a tech-debt project, an escalation project, a
> team you occasionally contribute to — would be silently misreported as
> untracked. The project list is the correct authority and costs one call.

Then resolve the surviving candidates in two passes:

1. **In the open set** — the key appears in step 4's results. Cross-reference it.
2. **Not in the open set** — do *not* discard it. A well-formed key that is
   absent from step 4 is a ticket that is Done, or open but assigned to somebody
   else. Both are worth reporting. Resolve them in one batched query rather than
   per key:

```
key IN (ABC-123, XY-45, ZZZ-7) ORDER BY key
```

   Ask for `assignee` as well as `status`, so the two cases can be told apart.

Anything still unresolved is genuinely untracked work.

Then flag:

| Ticket state | PR state | Flag |
|---|---|---|
| To Do, yours | open PR exists | ⚠️ Status mismatch — should be in progress |
| In Progress, yours | PR merged | ⚠️ Status mismatch — should be in review or done |
| In Progress, yours | no PR at all | ⚠️ No PR yet |
| In review, yours | no open PR | ⚠️ Status mismatch — PR missing or already merged |
| Done | PR still open | ⚠️ Ticket closed but PR not merged |
| Open, assigned to someone else | your PR is open | ⚠️ You are working on someone else's ticket |
| Open, unassigned | your PR is open | ⚠️ Ticket has no assignee — claim it |
| — | no resolvable key | ℹ️ Untracked work |

## Step 6 — Detect staleness

For each open PR, from either source:

- `updatedAt` / `creationDate` more than 3 days ago → ⚠️ Stale
- CI failing → 🔴 CI broken
- Merge conflicts → 🔴 Conflicts
- Review requested from you → ⚠️ Needs review
- Review requested from others with no vote for 3+ days → ⚠️ Needs chase

For each ticket in an in-progress category with no PR and no update in 3+ days →
⚠️ Stale.

## Step 7 — Write the summary file

Overwrite `~/.claude/wip/WIP.md` completely. Never append. Open items only —
merged and closed work appears as a count, not a list.

**Every PR and every ticket carries a link.** A summary you cannot click is a
summary you have to re-search. PR URLs come straight from the query; ticket URLs
are `{jira-site}/browse/{KEY}`, with the site taken from the Atlassian resource
already resolved for the MCP call.

```markdown
# Work In Progress — {date}

## Needs attention
- 🔴 CI failing — [{repo}#{n}]({url}) "{title}" ({age})
- ⚠️  Waiting on review {age} — [{project}!{n}]({url}) "{title}"

## Status mismatches
- [{KEY}]({ticket_url}) is "{status}" but [{repo}#{n}]({url}) is open → move it to in progress

## Open PRs ({count})
| Source | PR | Ticket | State | Age |
|---|---|---|---|---|
| GitHub | [{repo}#{n}]({url}) | [{KEY}]({ticket_url}) | draft | 3d |
| Azure  | [{project}!{n}]({url}) | — | review requested | 5d |

## Active tickets ({count})
- [{KEY}]({ticket_url}) {status} — {summary}

## Merged last 14 days: {count}

## Sources
GitHub ✅ · Azure DevOps ✅ · Jira ✅
```

When the open-PR list is long, split it into **active** and **stalled** at the
28-day line rather than printing one long table. Stalled entries can be grouped
by repo with a count, since the per-PR decision belongs to
`Workflows/Triage.md`.

Omit any section that is empty. List skipped sources under `## Sources` with the
reason, e.g. `Azure DevOps ⏭ (az devops organization not configured)`.

## Step 8 — Present

Display the same content in the terminal, flags first, then confirm the file
path that was written.

## Step 9 — Offer triage

Count the open PRs whose last activity is more than 28 days ago and that have no
live deferral (`Reference/Deferrals.md`). If there are any, say how many and
offer to run `Workflows/Triage.md` now.

```
21 PRs have had no activity in over 28 days. Triage them?
```

Do not start triage unprompted — it asks a lot of questions, and a sync should
stay something you can run in a few seconds.
