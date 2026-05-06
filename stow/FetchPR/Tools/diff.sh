#!/usr/bin/env bash
# FetchPR — diff helper.
#
# Thin wrapper around `gh pr diff` that adds:
#   - PR resolution from current branch (consistent with fetch.sh)
#   - Closed/merged early exit (consistent with fetch.sh)
#   - --files <pattern> to filter to specific paths via filterdiff/grep
#   - --save <path> to dump to a file and print the path (avoids context bloat)
#
# Usage:
#   diff.sh                            # full unified diff to stdout
#   diff.sh --pr 5315                  # explicit PR
#   diff.sh --names-only               # just changed file paths
#   diff.sh --files 'lionfish2/**'     # only diff hunks for matching paths
#   diff.sh --save /tmp/pr.patch       # write to file, print path
#   diff.sh --repo owner/name          # explicit repo

set -euo pipefail

PR=""
REPO=""
NAMES_ONLY=false
FILES_FILTER=""
SAVE_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pr)            PR="$2"; shift 2 ;;
        --repo)          REPO="$2"; shift 2 ;;
        --names-only)    NAMES_ONLY=true; shift ;;
        --files)         FILES_FILTER="$2"; shift 2 ;;
        --save)          SAVE_PATH="$2"; shift 2 ;;
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

# --- Resolve PR ------------------------------------------------------------
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

# --- Closed/merged: flag and stop ------------------------------------------
PR_STATE=$(gh api "repos/$REPO/pulls/$PR" --jq '.state')
if [[ "$PR_STATE" != "open" ]]; then
    {
        echo "STATUS: PR #$PR is $PR_STATE."
        echo "  URL: $(gh api "repos/$REPO/pulls/$PR" --jq '.html_url')"
        echo ""
        echo "Re-run with --pr <N> if you meant a different PR."
    } >&2
    exit 3
fi

# --- Names-only fast path --------------------------------------------------
if $NAMES_ONLY; then
    OUT=$(gh pr diff "$PR" --repo "$REPO" --name-only)
    if [[ -n "$FILES_FILTER" ]]; then
        # Use shell glob match on each line
        OUT=$(echo "$OUT" | while IFS= read -r f; do
            # shellcheck disable=SC2053
            [[ "$f" == $FILES_FILTER ]] && echo "$f"
        done)
    fi
    if [[ -n "$SAVE_PATH" ]]; then
        echo "$OUT" > "$SAVE_PATH"
        echo "$SAVE_PATH"
    else
        echo "$OUT"
    fi
    exit 0
fi

# --- Full diff -------------------------------------------------------------
DIFF_TMP=$(mktemp -t fetchpr-diff.XXXXXX)
trap 'rm -f "$DIFF_TMP"' EXIT
gh pr diff "$PR" --repo "$REPO" > "$DIFF_TMP"

# --- Filter to specific files ----------------------------------------------
if [[ -n "$FILES_FILTER" ]]; then
    if command -v filterdiff >/dev/null 2>&1; then
        filterdiff --include="$FILES_FILTER" "$DIFF_TMP" > "$DIFF_TMP.filtered"
        mv "$DIFF_TMP.filtered" "$DIFF_TMP"
    else
        # Portable bash fallback: walk the diff, gate each `diff --git` block
        # via bash glob match against the b/ path. Slower than filterdiff but
        # works on stock macOS without extra deps.
        include=0
        > "$DIFF_TMP.filtered"
        while IFS= read -r line; do
            if [[ "$line" == "diff --git "* ]]; then
                path="${line##* b/}"
                # shellcheck disable=SC2053
                if [[ "$path" == $FILES_FILTER ]]; then include=1; else include=0; fi
            fi
            (( include )) && printf '%s\n' "$line" >> "$DIFF_TMP.filtered"
        done < "$DIFF_TMP"
        mv "$DIFF_TMP.filtered" "$DIFF_TMP"
        if [[ ! -s "$DIFF_TMP" ]]; then
            echo "WARN: filter '$FILES_FILTER' matched no files." >&2
        fi
    fi
fi

# --- Output ----------------------------------------------------------------
if [[ -n "$SAVE_PATH" ]]; then
    cp "$DIFF_TMP" "$SAVE_PATH"
    echo "$SAVE_PATH"
else
    cat "$DIFF_TMP"
fi
