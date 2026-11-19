#!/usr/bin/env bash
# Shared host / repo resolution for FetchPR tools.
# Source this file — do not execute it directly.
#
# Exports (after resolve_host_and_repo):
#   FORGE   — "github" | "gitlab"
#   REPO    — owner/name or group/subgroup/project (no .git)
#   HOST    — hostname from the remote (e.g. github.com, gitlab.example.com)
#   REMOTE_URL — raw origin URL (may be empty if --repo was given)

# Parse a git remote URL into HOST and REPO path.
# Sets: _parsed_host, _parsed_repo
parse_remote_url() {
    local url="$1"
    _parsed_host=""
    _parsed_repo=""

    # SSH: git@host:path.git  or  ssh://git@host/path.git
    if [[ "$url" =~ ^git@([^:]+):(.+)$ ]]; then
        _parsed_host="${BASH_REMATCH[1]}"
        _parsed_repo="${BASH_REMATCH[2]}"
    elif [[ "$url" =~ ^ssh://([^@]+@)?([^/]+)/(.+)$ ]]; then
        _parsed_host="${BASH_REMATCH[2]}"
        _parsed_repo="${BASH_REMATCH[3]}"
    elif [[ "$url" =~ ^https?://([^/]+)/(.+)$ ]]; then
        _parsed_host="${BASH_REMATCH[1]}"
        _parsed_repo="${BASH_REMATCH[2]}"
    else
        return 1
    fi

    _parsed_repo="${_parsed_repo%.git}"
    _parsed_repo="${_parsed_repo%/}"
    return 0
}

# Infer forge from hostname.
# Echoes: github | gitlab | unknown
infer_forge_from_host() {
    local host
    host=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    case "$host" in
        github.com|www.github.com) echo "github" ;;
        gitlab.com|www.gitlab.com) echo "gitlab" ;;
        *gitlab*) echo "gitlab" ;;
        *) echo "unknown" ;;
    esac
}

# URL-encode a GitLab project path for API use (group/sub/project -> group%2Fsub%2Fproject).
gitlab_project_enc() {
    printf '%s' "$1" | jq -sRr @uri | sed 's/%0A$//'
}

# Require an authenticated CLI for the given forge. Exits 1 on failure.
require_forge_cli() {
    local forge="$1"
    case "$forge" in
        github)
            if ! command -v gh >/dev/null 2>&1; then
                echo "ERROR: gh CLI not found. Install GitHub CLI and run: gh auth login" >&2
                exit 1
            fi
            if ! gh auth status >/dev/null 2>&1; then
                echo "ERROR: gh is not authenticated. Run: gh auth login" >&2
                exit 1
            fi
            ;;
        gitlab)
            if ! command -v glab >/dev/null 2>&1; then
                echo "ERROR: glab CLI not found. Install GitLab CLI (glab) and run: glab auth login" >&2
                echo "       Or authenticate the GitLab MCP in Cursor and fetch via MCP instead." >&2
                exit 1
            fi
            if ! glab auth status >/dev/null 2>&1; then
                echo "ERROR: glab is not authenticated. Run: glab auth login" >&2
                echo "       Or authenticate the GitLab MCP in Cursor and fetch via MCP instead." >&2
                exit 1
            fi
            ;;
        *)
            echo "ERROR: Unknown forge '$forge'." >&2
            exit 1
            ;;
    esac
}

# Resolve FORGE, REPO, HOST from --repo arg and/or git remote.
# Call with optional explicit repo path as $1 (may be empty).
# On ambiguous remotes, tries glab then gh.
resolve_host_and_repo() {
    local explicit_repo="${1:-}"
    REMOTE_URL=""
    HOST=""
    FORGE=""
    REPO=""

    if [[ -n "$explicit_repo" ]]; then
        REPO="$explicit_repo"
        # Prefer forge hints from the working tree remote when present
        REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null || true)
        if [[ -n "$REMOTE_URL" ]] && parse_remote_url "$REMOTE_URL"; then
            HOST="$_parsed_host"
            FORGE=$(infer_forge_from_host "$HOST")
        fi
        if [[ -z "$FORGE" || "$FORGE" == "unknown" ]]; then
            # Explicit path alone: try glab, then gh
            if command -v glab >/dev/null 2>&1 && glab auth status >/dev/null 2>&1; then
                FORGE="gitlab"
            elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
                FORGE="github"
            else
                echo "ERROR: Cannot determine forge for repo '$REPO'." >&2
                echo "       Pass a full remote URL, or authenticate gh/glab." >&2
                exit 1
            fi
        fi
        return 0
    fi

    REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null || true)
    if [[ -z "$REMOTE_URL" ]]; then
        echo "ERROR: Not in a git repo and --repo not given." >&2
        exit 1
    fi

    if ! parse_remote_url "$REMOTE_URL"; then
        echo "ERROR: Could not parse remote URL: $REMOTE_URL" >&2
        exit 1
    fi

    HOST="$_parsed_host"
    REPO="$_parsed_repo"
    FORGE=$(infer_forge_from_host "$HOST")

    if [[ "$FORGE" == "unknown" ]]; then
        # Ambiguous self-managed host: probe CLIs against this remote
        if command -v glab >/dev/null 2>&1 && glab repo view -F json >/dev/null 2>&1; then
            FORGE="gitlab"
        elif command -v gh >/dev/null 2>&1 && gh repo view --json name >/dev/null 2>&1; then
            FORGE="github"
        else
            echo "ERROR: Ambiguous forge for host '$HOST'." >&2
            echo "       Authenticate glab (GitLab) or gh (GitHub), or set a clearer remote." >&2
            exit 1
        fi
    fi
}
