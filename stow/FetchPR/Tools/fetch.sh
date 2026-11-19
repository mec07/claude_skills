#!/usr/bin/env bash
# FetchPR — fetch comprehensive PR/MR context from GitHub or GitLab.
#
# Returns everything an agent needs to brief a user on a PR/MR:
#   header (title/state/branches/mergeable)
#   metadata (author, dates, labels, milestone, linked issues)
#   CI checks (status rollup + per-check)
#   reviewer states (requested, approved, changes_requested)
#   files changed (with +/- stats)
#   commits
#   description body
#   issue-level comments (the side chatter)
#   review-level summaries
#   inline thread comments (with isResolved/isOutdated flags where available)
#
# Read-only. Companion to ReviewPR (which writes pending/draft reviews).
# Host detection: see Reference/HostAndAuth.md and Tools/lib/host.sh.
#
# Usage:
#   fetch.sh                       # current branch, all sections, unresolved threads
#   fetch.sh --pr 5315             # explicit PR/MR number (GitLab IID)
#   fetch.sh --author cfettes      # filter comment surfaces by author
#   fetch.sh --all                 # include resolved threads
#   fetch.sh --repo owner/name     # explicit repo (default: from git remote)
#   fetch.sh --json                # machine-readable JSON
#   fetch.sh --brief               # skip long sections (files, commits, body, issue comments)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/host.sh
source "$SCRIPT_DIR/lib/host.sh"

PR=""
AUTHOR=""
REPO_ARG=""
INCLUDE_RESOLVED=false
JSON_OUT=false
BRIEF=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pr)            PR="$2"; shift 2 ;;
        --author)        AUTHOR="$2"; shift 2 ;;
        --repo)          REPO_ARG="$2"; shift 2 ;;
        --all)           INCLUDE_RESOLVED=true; shift ;;
        --json)          JSON_OUT=true; shift ;;
        --brief)         BRIEF=true; shift ;;
        -h|--help)
            sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; /^set -euo/d'
            exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

resolve_host_and_repo "$REPO_ARG"
require_forge_cli "$FORGE"

# ═══════════════════════════════════════════════════════════════════════════
# GitHub path
# ═══════════════════════════════════════════════════════════════════════════
fetch_github() {
    if [[ -z "$PR" ]]; then
        BRANCH=$(git branch --show-current 2>/dev/null || true)
        if [[ -z "$BRANCH" ]]; then
            echo "ERROR: Not on a branch and --pr not given." >&2
            exit 1
        fi
        PR=$(gh pr list --repo "$REPO" --head "$BRANCH" --state all \
            --json number,state \
            --jq 'sort_by(if .state == "OPEN" then 0 else 1 end) | .[0].number' \
            2>/dev/null || true)
        if [[ -z "$PR" || "$PR" == "null" ]]; then
            echo "ERROR: No PR found for branch '$BRANCH' on $REPO." >&2
            echo "       Pass --pr <number> explicitly." >&2
            exit 1
        fi
    fi

    PR_JSON=$(gh pr view "$PR" --repo "$REPO" --json \
        number,title,state,isDraft,url,body,headRefName,baseRefName,\
author,createdAt,updatedAt,labels,milestone,additions,deletions,changedFiles,\
mergeable,mergeStateStatus,reviewDecision,closingIssuesReferences,\
reviewRequests,latestReviews,commits,files,statusCheckRollup)

    # Inject forge marker for consumers
    PR_JSON=$(echo "$PR_JSON" | jq --arg forge "github" '. + {forge: $forge}')

    PR_STATE=$(echo "$PR_JSON" | jq -r '.state')

    if [[ "$PR_STATE" != "OPEN" ]]; then
        {
            echo "STATUS: PR #$PR is $PR_STATE."
            echo "  Title: $(echo "$PR_JSON" | jq -r '.title')"
            echo "  URL:   $(echo "$PR_JSON" | jq -r '.url')"
            echo ""
            echo "Re-run with --pr <N> if you meant a different PR."
        } >&2
        exit 3
    fi

    ISSUE_COMMENTS_RAW=$(gh api "repos/$REPO/issues/$PR/comments" --paginate)
    ISSUE_COMMENTS=$(echo "$ISSUE_COMMENTS_RAW" | jq --arg author "$AUTHOR" '
        [ .[]
          | select(($author == "") or (.user.login == $author))
          | { author: .user.login, created_at: .created_at, url: .html_url, body: .body }
        ]')

    REVIEWS_RAW=$(gh api "repos/$REPO/pulls/$PR/reviews" --paginate)
    REVIEWS=$(echo "$REVIEWS_RAW" | jq --arg author "$AUTHOR" '
        [ .[]
          | select(($author == "") or (.user.login == $author))
          | select((.body // "") | length > 0)
          | { author: .user.login, state: .state, submitted_at: .submitted_at, url: .html_url, body: .body }
        ]')

    THREADS_RAW=$(gh api graphql -F owner="${REPO%/*}" -F name="${REPO#*/}" -F number="$PR" -f query='
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          isOutdated
          comments(first: 20) {
            nodes {
              author { login }
              body
              path
              line
              originalLine
              createdAt
              url
            }
          }
        }
      }
    }
  }
}')

    THREADS=$(echo "$THREADS_RAW" | jq --arg author "$AUTHOR" --argjson include_resolved "$INCLUDE_RESOLVED" '
        [ .data.repository.pullRequest.reviewThreads.nodes[]
          | select($include_resolved or (.isResolved | not))
          | . as $thread
          | .comments.nodes[]
          | select(($author == "") or (.author.login == $author))
          | {
              author: .author.login,
              path: .path,
              line: (.line // .originalLine),
              thread_id: $thread.id,
              resolved: $thread.isResolved,
              outdated: $thread.isOutdated,
              created_at: .createdAt,
              url: .url,
              body: .body
            }
        ]')
}

# ═══════════════════════════════════════════════════════════════════════════
# GitLab path — normalize toward the GitHub-shaped fields ReviewPR expects
# ═══════════════════════════════════════════════════════════════════════════
fetch_gitlab() {
    local project_enc
    project_enc=$(gitlab_project_enc "$REPO")

    if [[ -z "$PR" ]]; then
        BRANCH=$(git branch --show-current 2>/dev/null || true)
        if [[ -z "$BRANCH" ]]; then
            echo "ERROR: Not on a branch and --pr not given." >&2
            exit 1
        fi
        # Prefer open MRs for this source branch
        PR=$(glab api "projects/${project_enc}/merge_requests?source_branch=${BRANCH}&state=all" \
            | jq -r 'sort_by(if .state == "opened" then 0 else 1 end) | .[0].iid // empty' \
            2>/dev/null || true)
        if [[ -z "$PR" || "$PR" == "null" ]]; then
            echo "ERROR: No MR found for branch '$BRANCH' on $REPO." >&2
            echo "       Pass --pr <iid> explicitly." >&2
            exit 1
        fi
    fi

    local mr_raw changes_raw commits_raw notes_raw discussions_raw approvals_raw pipelines_raw
    mr_raw=$(glab api "projects/${project_enc}/merge_requests/${PR}")
    changes_raw=$(glab api "projects/${project_enc}/merge_requests/${PR}/changes" 2>/dev/null || echo '{}')
    commits_raw=$(glab api "projects/${project_enc}/merge_requests/${PR}/commits" 2>/dev/null || echo '[]')
    notes_raw=$(glab api "projects/${project_enc}/merge_requests/${PR}/notes?sort=asc&per_page=100" 2>/dev/null || echo '[]')
    discussions_raw=$(glab api "projects/${project_enc}/merge_requests/${PR}/discussions?per_page=100" 2>/dev/null || echo '[]')
    approvals_raw=$(glab api "projects/${project_enc}/merge_requests/${PR}/approvals" 2>/dev/null || echo '{}')
    pipelines_raw=$(glab api "projects/${project_enc}/merge_requests/${PR}/pipelines" 2>/dev/null || echo '[]')

    local gl_state
    gl_state=$(echo "$mr_raw" | jq -r '.state')
    # Normalize state to OPEN / MERGED / CLOSED for exit-3 gate
    local norm_state
    case "$gl_state" in
        opened) norm_state="OPEN" ;;
        merged) norm_state="MERGED" ;;
        closed) norm_state="CLOSED" ;;
        *)      norm_state=$(echo "$gl_state" | tr '[:lower:]' '[:upper:]') ;;
    esac

    if [[ "$norm_state" != "OPEN" ]]; then
        {
            echo "STATUS: MR !$PR is $norm_state."
            echo "  Title: $(echo "$mr_raw" | jq -r '.title')"
            echo "  URL:   $(echo "$mr_raw" | jq -r '.web_url')"
            echo ""
            echo "Re-run with --pr <N> if you meant a different MR."
        } >&2
        exit 3
    fi

    # Build a GitHub-like pr object so ReviewPR Steps 1–3 stay stable.
    # Extra GitLab fields: forge, iid, diff_refs, project_path
    PR_JSON=$(jq -n \
        --argjson mr "$mr_raw" \
        --argjson changes "$changes_raw" \
        --argjson commits "$commits_raw" \
        --argjson pipelines "$pipelines_raw" \
        --argjson approvals "$approvals_raw" \
        --arg forge "gitlab" \
        --arg repo "$REPO" \
        --arg state "$norm_state" '
        ($changes.changes // []) as $ch |
        ($ch | map(.diff // "") | join("\n") | split("\n") |
          {
            additions: ([.[] | select(startswith("+") and (startswith("+++") | not))] | length),
            deletions: ([.[] | select(startswith("-") and (startswith("---") | not))] | length)
          }) as $stats |
        {
          forge: $forge,
          project_path: $repo,
          number: $mr.iid,
          iid: $mr.iid,
          title: $mr.title,
          state: $state,
          isDraft: ($mr.draft // $mr.work_in_progress // false),
          url: $mr.web_url,
          body: ($mr.description // ""),
          headRefName: $mr.source_branch,
          baseRefName: $mr.target_branch,
          author: { login: ($mr.author.username // $mr.author.name // "") },
          createdAt: $mr.created_at,
          updatedAt: $mr.updated_at,
          labels: (($mr.labels // []) | map(if type == "string" then {name: .} else {name: (.name // .title // "")} end)),
          milestone: (if $mr.milestone then {title: $mr.milestone.title} else null end),
          additions: $stats.additions,
          deletions: $stats.deletions,
          changedFiles: ($ch | length),
          mergeable: (if ($mr.merge_status // "") == "can_be_merged" then "MERGEABLE"
                      elif ($mr.detailed_merge_status // "") == "mergeable" then "MERGEABLE"
                      else ($mr.detailed_merge_status // $mr.merge_status // "UNKNOWN") end),
          mergeStateStatus: ($mr.detailed_merge_status // $mr.merge_status // ""),
          reviewDecision: (if ($approvals.approved == true) then "APPROVED" else "REVIEW_REQUIRED" end),
          closingIssuesReferences: [],
          reviewRequests: (($mr.reviewers // []) | map({login: (.username // .name // "")})),
          latestReviews: (($approvals.approved_by // []) | map({
            author: { login: (.user.username // .username // "") },
            state: "APPROVED",
            submittedAt: (.approved_at // "")
          })),
          commits: ($commits | map({
            oid: .id,
            messageHeadline: (.title // ((.message // "") | split("\n")[0]))
          })),
          files: ($ch | map({
            path: (.new_path // .old_path),
            additions: 0,
            deletions: 0
          })),
          statusCheckRollup: ($pipelines | map({
            name: ("pipeline #" + (.id | tostring)),
            conclusion: (if .status == "success" then "SUCCESS"
                         elif .status == "failed" then "FAILURE"
                         elif .status == "running" or .status == "pending" then "PENDING"
                         else ((.status // "unknown") | ascii_upcase) end),
            state: ((.status // "unknown") | ascii_upcase),
            detailsUrl: (.web_url // "")
          })),
          diff_refs: ($mr.diff_refs // {})
        }
    ')

    ISSUE_COMMENTS=$(echo "$notes_raw" | jq --arg author "$AUTHOR" '
        [ .[]
          | select(.system != true)
          | select(.position == null)
          | select(($author == "") or (.author.username == $author))
          | {
              author: .author.username,
              created_at: .created_at,
              url: "",
              body: .body
            }
        ]')

    # GitLab has no exact GitHub "review body"; surface long non-diff notes as summaries.
    REVIEWS=$(echo "$notes_raw" | jq --arg author "$AUTHOR" '
        [ .[]
          | select(.system != true)
          | select(.type != "DiffNote")
          | select(.position == null)
          | select((.body // "") | length > 200)
          | select(($author == "") or (.author.username == $author))
          | {
              author: .author.username,
              state: "COMMENTED",
              submitted_at: .created_at,
              url: "",
              body: .body
            }
        ] | unique_by(.body) | .[0:20]')

    THREADS=$(echo "$discussions_raw" | jq --arg author "$AUTHOR" --argjson include_resolved "$INCLUDE_RESOLVED" '
        [ .[]
          | . as $disc
          | select($include_resolved or ((.notes[0].resolved // false) | not))
          | .notes[]
          | select(.system != true)
          | select(.type == "DiffNote" or .position != null)
          | select(($author == "") or (.author.username == $author))
          | {
              author: .author.username,
              path: (.position.new_path // .position.old_path // .file_path // ""),
              line: (.position.new_line // .position.old_line // null),
              thread_id: $disc.id,
              resolved: (.resolved // false),
              outdated: (.outdated // false),
              created_at: .created_at,
              url: "",
              body: .body
            }
        ]')
}

# --- Dispatch --------------------------------------------------------------
case "$FORGE" in
    github) fetch_github ;;
    gitlab) fetch_gitlab ;;
esac

# --- JSON output -----------------------------------------------------------
if $JSON_OUT; then
    jq -n \
        --argjson pr "$PR_JSON" \
        --argjson issue_comments "$ISSUE_COMMENTS" \
        --argjson reviews "$REVIEWS" \
        --argjson threads "$THREADS" \
        '{pr: $pr, issue_comments: $issue_comments, reviews: $reviews, threads: $threads}'
    exit 0
fi

# --- Human-readable: header + metadata -------------------------------------
LABEL_KIND="PR"
[[ "$FORGE" == "gitlab" ]] && LABEL_KIND="MR"
echo "$LABEL_KIND #$PR — $(echo "$PR_JSON" | jq -r '.title')"
echo "  $(echo "$PR_JSON" | jq -r '.url')"
echo "  forge: $FORGE  state: $(echo "$PR_JSON" | jq -r '.state')  draft: $(echo "$PR_JSON" | jq -r '.isDraft')  $(echo "$PR_JSON" | jq -r '.headRefName') → $(echo "$PR_JSON" | jq -r '.baseRefName')"
echo "  author: $(echo "$PR_JSON" | jq -r '.author.login')  created: $(echo "$PR_JSON" | jq -r '.createdAt')  updated: $(echo "$PR_JSON" | jq -r '.updatedAt')"

LABELS=$(echo "$PR_JSON" | jq -r '[.labels[].name] | join(", ")')
[[ -n "$LABELS" ]] && echo "  labels: $LABELS"

MILESTONE=$(echo "$PR_JSON" | jq -r '.milestone.title // empty')
[[ -n "$MILESTONE" ]] && echo "  milestone: $MILESTONE"

LINKED=$(echo "$PR_JSON" | jq -r '[.closingIssuesReferences[]? | "#\(.number) \(.title)"] | join(" | ")')
[[ -n "$LINKED" ]] && echo "  closes: $LINKED"

if [[ "$FORGE" == "gitlab" ]]; then
    HEAD_SHA=$(echo "$PR_JSON" | jq -r '.diff_refs.head_sha // .commits[-1].oid // empty')
    [[ -n "$HEAD_SHA" ]] && echo "  head_sha: $HEAD_SHA"
    echo "  diff_refs: base=$(echo "$PR_JSON" | jq -r '.diff_refs.base_sha // "?"') start=$(echo "$PR_JSON" | jq -r '.diff_refs.start_sha // "?"') head=$(echo "$PR_JSON" | jq -r '.diff_refs.head_sha // "?"')"
fi

echo "  diff: $(echo "$PR_JSON" | jq -r '.changedFiles') files, +$(echo "$PR_JSON" | jq -r '.additions')/-$(echo "$PR_JSON" | jq -r '.deletions')"
echo "  mergeable: $(echo "$PR_JSON" | jq -r '.mergeable')  state: $(echo "$PR_JSON" | jq -r '.mergeStateStatus')  decision: $(echo "$PR_JSON" | jq -r '.reviewDecision // "none"')"
echo ""

# --- CI checks -------------------------------------------------------------
CHECKS=$(echo "$PR_JSON" | jq -r '
    .statusCheckRollup // [] |
    if length == 0 then "" else
      "Checks: " +
      ([(map(select(.conclusion == "SUCCESS" or .state == "SUCCESS")) | length | tostring) + "✅",
        (map(select(.conclusion == "FAILURE" or .state == "FAILURE")) | length | tostring) + "❌",
        (map(select(.conclusion == "PENDING" or .state == "PENDING" or .status == "IN_PROGRESS")) | length | tostring) + "⏳"
       ] | join("  "))
    end')
[[ -n "$CHECKS" ]] && echo "$CHECKS" && \
    echo "$PR_JSON" | jq -r '
        .statusCheckRollup // [] |
        map(select(.conclusion == "FAILURE" or .state == "FAILURE")) |
        .[] | "  ❌ \(.name // .context // "?")  \(.detailsUrl // .targetUrl // "")"' && \
    echo ""

# --- Reviewer states -------------------------------------------------------
REQUESTED=$(echo "$PR_JSON" | jq -r '[.reviewRequests[].login] | join(", ")')
[[ -n "$REQUESTED" ]] && echo "Requested reviewers: $REQUESTED"

LATEST=$(echo "$PR_JSON" | jq -r '
    .latestReviews // [] |
    if length == 0 then "" else
      "Latest reviews:\n" +
      (map("  @\(.author.login)  \(.state)  \(.submittedAt // "")") | join("\n"))
    end')
[[ -n "$LATEST" ]] && echo "$LATEST" && echo ""

# --- Brief mode stops here for the long sections --------------------------
if ! $BRIEF; then
    BODY=$(echo "$PR_JSON" | jq -r '.body // ""')
    if [[ -n "$BODY" ]]; then
        echo "═══ Description ═══"
        echo "$BODY"
        echo ""
    fi

    FILES_OUT=$(echo "$PR_JSON" | jq -r '
        .files // [] |
        if length == 0 then "" else
          "═══ Files changed ═══\n" +
          (map("  \(.path)  +\(.additions)/-\(.deletions)") | join("\n"))
        end')
    [[ -n "$FILES_OUT" ]] && echo "$FILES_OUT" && echo ""

    COMMITS_OUT=$(echo "$PR_JSON" | jq -r '
        .commits // [] |
        if length == 0 then "" else
          "═══ Commits ═══\n" +
          (map("  \(.oid[0:7])  \(.messageHeadline)") | join("\n"))
        end')
    [[ -n "$COMMITS_OUT" ]] && echo "$COMMITS_OUT" && echo ""

    ISSUE_COUNT=$(echo "$ISSUE_COMMENTS" | jq 'length')
    if [[ "$ISSUE_COUNT" -gt 0 ]]; then
        echo "═══ Issue-level comments ($ISSUE_COUNT) ═══"
        echo "$ISSUE_COMMENTS" | jq -r 'sort_by(.created_at) | .[] |
            "── @\(.author)  \(.created_at)\n   \(.url)\n\n\(.body)\n"'
    fi
fi

REV_COUNT=$(echo "$REVIEWS" | jq 'length')
THR_COUNT=$(echo "$THREADS" | jq 'length')
SCOPE="unresolved threads only"
$INCLUDE_RESOLVED && SCOPE="all threads"
[[ -n "$AUTHOR" ]] && SCOPE="$SCOPE, author=$AUTHOR"

if [[ "$REV_COUNT" -gt 0 ]]; then
    echo "═══ Review-level summaries ($REV_COUNT) ═══"
    echo "$REVIEWS" | jq -r '.[] |
        "── @\(.author) [\(.state)]  \(.submitted_at)\n   \(.url)\n\n\(.body)\n"'
fi

if [[ "$THR_COUNT" -gt 0 ]]; then
    echo "═══ Inline thread comments ($THR_COUNT — $SCOPE) ═══"
    echo "$THREADS" | jq -r 'sort_by(.author, .path, .line, .created_at) | .[] |
        "── @\(.author) — \(.path):\(.line)" +
        (if .resolved then " [RESOLVED]" else "" end) +
        (if .outdated then " [OUTDATED]" else "" end) +
        "\n   thread: \(.thread_id)\n   \(.url)\n\n\(.body)\n"'
fi
