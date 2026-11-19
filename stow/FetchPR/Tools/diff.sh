#!/usr/bin/env bash
# FetchPR — diff helper for GitHub PRs and GitLab MRs.
#
# Thin wrapper around `gh pr diff` / `glab mr diff` that adds:
#   - PR/MR resolution from current branch (consistent with fetch.sh)
#   - Closed/merged early exit (consistent with fetch.sh)
#   - --files <pattern> to filter to specific paths via filterdiff/grep
#   - --save <path> to dump to a file and print the path (avoids context bloat)
# Host detection: see Reference/HostAndAuth.md and Tools/lib/host.sh.
#
# Usage:
#   diff.sh                            # full unified diff to stdout
#   diff.sh --pr 5315                  # explicit PR/MR number (GitLab IID)
#   diff.sh --names-only               # just changed file paths
#   diff.sh --files 'lionfish2/**'     # only diff hunks for matching paths
#   diff.sh --save /tmp/pr.patch       # write to file, print path
#   diff.sh --repo owner/name          # explicit repo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/host.sh
source "$SCRIPT_DIR/lib/host.sh"

PR=""
REPO_ARG=""
NAMES_ONLY=false
FILES_FILTER=""
SAVE_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pr)            PR="$2"; shift 2 ;;
        --repo)          REPO_ARG="$2"; shift 2 ;;
        --names-only)    NAMES_ONLY=true; shift ;;
        --files)         FILES_FILTER="$2"; shift 2 ;;
        --save)          SAVE_PATH="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; /^set -euo/d'
            exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

resolve_host_and_repo "$REPO_ARG"
require_forge_cli "$FORGE"

resolve_pr_number() {
    if [[ -n "$PR" ]]; then
        return 0
    fi
    BRANCH=$(git branch --show-current 2>/dev/null || true)
    if [[ -z "$BRANCH" ]]; then
        echo "ERROR: Not on a branch and --pr not given." >&2
        exit 1
    fi
    case "$FORGE" in
        github)
            PR=$(gh pr list --repo "$REPO" --head "$BRANCH" --state all \
                --json number,state \
                --jq 'sort_by(if .state == "OPEN" then 0 else 1 end) | .[0].number' \
                2>/dev/null || true)
            ;;
        gitlab)
            local project_enc
            project_enc=$(gitlab_project_enc "$REPO")
            PR=$(glab api "projects/${project_enc}/merge_requests?source_branch=${BRANCH}&state=all" \
                | jq -r 'sort_by(if .state == "opened" then 0 else 1 end) | .[0].iid // empty' \
                2>/dev/null || true)
            ;;
    esac
    if [[ -z "$PR" || "$PR" == "null" ]]; then
        echo "ERROR: No PR/MR found for branch '$BRANCH' on $REPO." >&2
        echo "       Pass --pr <number> explicitly." >&2
        exit 1
    fi
}

assert_open() {
    case "$FORGE" in
        github)
            local pr_state url
            pr_state=$(gh api "repos/$REPO/pulls/$PR" --jq '.state')
            if [[ "$pr_state" != "open" ]]; then
                url=$(gh api "repos/$REPO/pulls/$PR" --jq '.html_url')
                {
                    echo "STATUS: PR #$PR is $pr_state."
                    echo "  URL: $url"
                    echo ""
                    echo "Re-run with --pr <N> if you meant a different PR."
                } >&2
                exit 3
            fi
            ;;
        gitlab)
            local project_enc mr_json gl_state norm
            project_enc=$(gitlab_project_enc "$REPO")
            mr_json=$(glab api "projects/${project_enc}/merge_requests/${PR}")
            gl_state=$(echo "$mr_json" | jq -r '.state')
            case "$gl_state" in
                opened) norm="OPEN" ;;
                merged) norm="MERGED" ;;
                closed) norm="CLOSED" ;;
                *)      norm=$(echo "$gl_state" | tr '[:lower:]' '[:upper:]') ;;
            esac
            if [[ "$norm" != "OPEN" ]]; then
                {
                    echo "STATUS: MR !$PR is $norm."
                    echo "  URL: $(echo "$mr_json" | jq -r '.web_url')"
                    echo ""
                    echo "Re-run with --pr <N> if you meant a different MR."
                } >&2
                exit 3
            fi
            ;;
    esac
}

filter_diff_file() {
    local src="$1"
    if [[ -z "$FILES_FILTER" ]]; then
        return 0
    fi
    if command -v filterdiff >/dev/null 2>&1; then
        filterdiff --include="$FILES_FILTER" "$src" > "$src.filtered"
        mv "$src.filtered" "$src"
    else
        local include=0
        > "$src.filtered"
        while IFS= read -r line; do
            if [[ "$line" == "diff --git "* ]]; then
                local path="${line##* b/}"
                # shellcheck disable=SC2053
                if [[ "$path" == $FILES_FILTER ]]; then include=1; else include=0; fi
            fi
            (( include )) && printf '%s\n' "$line" >> "$src.filtered"
        done < "$src"
        mv "$src.filtered" "$src"
        if [[ ! -s "$src" ]]; then
            echo "WARN: filter '$FILES_FILTER' matched no files." >&2
        fi
    fi
}

emit_or_save() {
    local content_file="$1"
    if [[ -n "$SAVE_PATH" ]]; then
        cp "$content_file" "$SAVE_PATH"
        echo "$SAVE_PATH"
    else
        cat "$content_file"
    fi
}

resolve_pr_number
assert_open

# --- Names-only fast path --------------------------------------------------
if $NAMES_ONLY; then
    NAMES_TMP=$(mktemp -t fetchpr-names.XXXXXX)
    trap 'rm -f "$NAMES_TMP"' EXIT
    case "$FORGE" in
        github)
            gh pr diff "$PR" --repo "$REPO" --name-only > "$NAMES_TMP"
            ;;
        gitlab)
            project_enc=$(gitlab_project_enc "$REPO")
            glab api "projects/${project_enc}/merge_requests/${PR}/changes" \
                | jq -r '.changes[]? | .new_path // .old_path' > "$NAMES_TMP"
            ;;
    esac
    if [[ -n "$FILES_FILTER" ]]; then
        FILTERED=$(mktemp -t fetchpr-names-f.XXXXXX)
        while IFS= read -r f; do
            # shellcheck disable=SC2053
            [[ "$f" == $FILES_FILTER ]] && echo "$f"
        done < "$NAMES_TMP" > "$FILTERED"
        mv "$FILTERED" "$NAMES_TMP"
    fi
    emit_or_save "$NAMES_TMP"
    exit 0
fi

# --- Full diff -------------------------------------------------------------
DIFF_TMP=$(mktemp -t fetchpr-diff.XXXXXX)
trap 'rm -f "$DIFF_TMP"' EXIT

case "$FORGE" in
    github)
        gh pr diff "$PR" --repo "$REPO" > "$DIFF_TMP"
        ;;
    gitlab)
        # Prefer raw patch for piping; fall back to stitching API change diffs
        if ! glab mr diff "$PR" -R "$REPO" --raw --color=never > "$DIFF_TMP" 2>/dev/null; then
            project_enc=$(gitlab_project_enc "$REPO")
            glab api "projects/${project_enc}/merge_requests/${PR}/changes" | jq -r '
                .changes[]? |
                "diff --git a/\(.old_path) b/\(.new_path)\n" +
                (if .new_file then "new file mode 100644\n" else "" end) +
                (if .deleted_file then "deleted file mode 100644\n" else "" end) +
                (.diff // "")
            ' > "$DIFF_TMP"
        fi
        ;;
esac

filter_diff_file "$DIFF_TMP"
emit_or_save "$DIFF_TMP"
