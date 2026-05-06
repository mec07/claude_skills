#!/usr/bin/env bash
# PrReviewFetch — fetch comprehensive PR context from GitHub.
#
# Returns everything an agent needs to brief a user on a PR:
#   header (title/state/branches/mergeable)
#   metadata (author, dates, labels, milestone, linked issues)
#   CI checks (status rollup + per-check)
#   reviewer states (requested, approved, changes_requested)
#   files changed (with +/- stats)
#   commits
#   PR description body
#   issue-level comments (the side chatter)
#   review-level summaries (CodeRabbit nitpick-section bodies)
#   inline thread comments (with isResolved/isOutdated flags)
#
# Read-only. Companion to ReviewPR (which writes pending reviews).
#
# Usage:
#   fetch.sh                       # current branch, all sections, unresolved threads
#   fetch.sh --pr 5315             # explicit PR
#   fetch.sh --author cfettes      # filter comment surfaces by author
#   fetch.sh --all                 # include resolved threads
#   fetch.sh --repo owner/name     # explicit repo (default: from git remote)
#   fetch.sh --json                # machine-readable JSON
#   fetch.sh --brief               # skip long sections (files, commits, body, issue comments)

set -euo pipefail

PR=""
AUTHOR=""
REPO=""
INCLUDE_RESOLVED=false
JSON_OUT=false
BRIEF=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pr)            PR="$2"; shift 2 ;;
        --author)        AUTHOR="$2"; shift 2 ;;
        --repo)          REPO="$2"; shift 2 ;;
        --all)           INCLUDE_RESOLVED=true; shift ;;
        --json)          JSON_OUT=true; shift ;;
        --brief)         BRIEF=true; shift ;;
        -h|--help)
            sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; /^set -euo/d'
            exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

# --- Resolve repo ----------------------------------------------------------
if [[ -z "$REPO" ]]; then
    REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null || true)
    if [[ -z "$REMOTE_URL" ]]; then
        echo "ERROR: Not in a git repo and --repo not given." >&2
        exit 1
    fi
    REPO=$(echo "$REMOTE_URL" \
        | sed -E 's#(git@github\.com:|https://github\.com/)##; s#\.git$##')
fi

# --- Resolve PR number -----------------------------------------------------
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

# --- Header / metadata via gh pr view (single call, lots of data) ----------
PR_JSON=$(gh pr view "$PR" --repo "$REPO" --json \
    number,title,state,isDraft,url,body,headRefName,baseRefName,\
author,createdAt,updatedAt,labels,milestone,additions,deletions,changedFiles,\
mergeable,mergeStateStatus,reviewDecision,closingIssuesReferences,\
reviewRequests,latestReviews,commits,files,statusCheckRollup)

PR_STATE=$(echo "$PR_JSON" | jq -r '.state')

# --- Closed/merged: flag and stop ------------------------------------------
# Don't try to guess a successor PR from comment chatter — the convention isn't
# reliable enough to trust. Just stop and let the caller ask the user.
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

# --- Issue-level (general PR) comments ------------------------------------
ISSUE_COMMENTS_RAW=$(gh api "repos/$REPO/issues/$PR/comments" --paginate)
ISSUE_COMMENTS=$(echo "$ISSUE_COMMENTS_RAW" | jq --arg author "$AUTHOR" '
    [ .[]
      | select(($author == "") or (.user.login == $author))
      | { author: .user.login, created_at: .created_at, url: .html_url, body: .body }
    ]')

# --- Review-level summaries ------------------------------------------------
REVIEWS_RAW=$(gh api "repos/$REPO/pulls/$PR/reviews" --paginate)
REVIEWS=$(echo "$REVIEWS_RAW" | jq --arg author "$AUTHOR" '
    [ .[]
      | select(($author == "") or (.user.login == $author))
      | select((.body // "") | length > 0)
      | { author: .user.login, state: .state, submitted_at: .submitted_at, url: .html_url, body: .body }
    ]')

# --- Inline review threads (with resolved/outdated state) ------------------
THREADS_RAW=$(gh api graphql -F owner="${REPO%/*}" -F name="${REPO#*/}" -F number="$PR" -f query='
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        nodes {
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
          resolved: $thread.isResolved,
          outdated: $thread.isOutdated,
          created_at: .createdAt,
          url: .url,
          body: .body
        }
    ]')

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
echo "PR #$PR — $(echo "$PR_JSON" | jq -r '.title')"
echo "  $(echo "$PR_JSON" | jq -r '.url')"
echo "  state: $PR_STATE  draft: $(echo "$PR_JSON" | jq -r '.isDraft')  $(echo "$PR_JSON" | jq -r '.headRefName') → $(echo "$PR_JSON" | jq -r '.baseRefName')"
echo "  author: $(echo "$PR_JSON" | jq -r '.author.login')  created: $(echo "$PR_JSON" | jq -r '.createdAt')  updated: $(echo "$PR_JSON" | jq -r '.updatedAt')"

LABELS=$(echo "$PR_JSON" | jq -r '[.labels[].name] | join(", ")')
[[ -n "$LABELS" ]] && echo "  labels: $LABELS"

MILESTONE=$(echo "$PR_JSON" | jq -r '.milestone.title // empty')
[[ -n "$MILESTONE" ]] && echo "  milestone: $MILESTONE"

LINKED=$(echo "$PR_JSON" | jq -r '[.closingIssuesReferences[] | "#\(.number) \(.title)"] | join(" | ")')
[[ -n "$LINKED" ]] && echo "  closes: $LINKED"

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
    # --- PR body / description --------------------------------------------
    BODY=$(echo "$PR_JSON" | jq -r '.body // ""')
    if [[ -n "$BODY" ]]; then
        echo "═══ Description ═══"
        echo "$BODY"
        echo ""
    fi

    # --- Files changed ----------------------------------------------------
    FILES_OUT=$(echo "$PR_JSON" | jq -r '
        .files // [] |
        if length == 0 then "" else
          "═══ Files changed ═══\n" +
          (map("  \(.path)  +\(.additions)/-\(.deletions)") | join("\n"))
        end')
    [[ -n "$FILES_OUT" ]] && echo "$FILES_OUT" && echo ""

    # --- Commits ----------------------------------------------------------
    COMMITS_OUT=$(echo "$PR_JSON" | jq -r '
        .commits // [] |
        if length == 0 then "" else
          "═══ Commits ═══\n" +
          (map("  \(.oid[0:7])  \(.messageHeadline)") | join("\n"))
        end')
    [[ -n "$COMMITS_OUT" ]] && echo "$COMMITS_OUT" && echo ""

    # --- Issue-level comments --------------------------------------------
    ISSUE_COUNT=$(echo "$ISSUE_COMMENTS" | jq 'length')
    if [[ "$ISSUE_COUNT" -gt 0 ]]; then
        echo "═══ Issue-level comments ($ISSUE_COUNT) ═══"
        echo "$ISSUE_COMMENTS" | jq -r 'sort_by(.created_at) | .[] |
            "── @\(.author)  \(.created_at)\n   \(.url)\n\n\(.body)\n"'
    fi
fi

# --- Comment surfaces ------------------------------------------------------
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
        "\n   \(.url)\n\n\(.body)\n"'
fi
