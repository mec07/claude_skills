#!/bin/sh
set -e

TARGET_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

# Resolve the directory this script lives in (portable, no readlink -f)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STOW_DIR="$SCRIPT_DIR/stow"

usage() {
    cat <<EOF
Usage: $(basename "$0") [--force] [--uninstall] [--help] [SKILL ...]

Install Claude Code skills into ~/.claude/skills/

With no SKILL arguments, installs all skills found in stow/.
With SKILL arguments, installs only the named skills.

Options:
  --force          Overwrite existing installations without prompting
  --uninstall      Remove installed skills
  --allow-destroy  Permit removal of files in the target that did not come from stow/
  --help           Show this message

Examples:
  $(basename "$0")                      # Install all skills
  $(basename "$0") ReviewPR Sleep       # Install only ReviewPR and Sleep
  $(basename "$0") --uninstall          # Uninstall all skills
  $(basename "$0") --uninstall llm-docs # Uninstall only llm-docs
EOF
}

die() {
    printf "Error: %s\n" "$1" >&2
    exit 1
}

# Parse flags and skill names
FORCE=0
UNINSTALL=0
ALLOW_DESTROY=0
RC=0
SKILLS=""
for arg in "$@"; do
    case "$arg" in
        --force)         FORCE=1 ;;
        --uninstall)     UNINSTALL=1 ;;
        --allow-destroy) ALLOW_DESTROY=1 ;;
        --help)          usage; exit 0 ;;
        -*)              die "unknown option: $arg (see --help)" ;;
        *)               SKILLS="$SKILLS $arg" ;;
    esac
done

# If no skills specified, discover all from stow/
if [ -z "$SKILLS" ]; then
    [ -d "$STOW_DIR" ] || die "Cannot find $STOW_DIR — run this script from the repository root."
    SKILLS=""
    for d in "$STOW_DIR"/*/; do
        [ -d "$d" ] || continue
        SKILLS="$SKILLS $(basename "$d")"
    done
fi

[ -n "$SKILLS" ] || die "No skills found in $STOW_DIR"

# Check if a skill is already correctly installed (same inode, works through symlinks)
is_current_install() {
    local skill_name="$1"
    local skill_dir="$TARGET_DIR/$skill_name"
    local source_dir="$STOW_DIR/$skill_name"
    [ -f "$skill_dir/SKILL.md" ] && [ "$skill_dir/SKILL.md" -ef "$source_dir/SKILL.md" ]
}

remove_install() {
    local skill_name="$1"
    local skill_dir="$TARGET_DIR/$skill_name"
    [ -e "$skill_dir" ] || [ -L "$skill_dir" ] || return 0

    # install_symlinks only ever creates symlinks and directories (install.sh:81-97),
    # so any regular file here was put there by a human and cannot be regenerated
    # from stow/. .DS_Store is excluded: Finder writes it, nobody authored it.
    local real_files
    real_files="$(find "$skill_dir" -type f ! -name '.DS_Store' 2>/dev/null || true)"

    if [ -n "$real_files" ]; then
        if [ "$ALLOW_DESTROY" = 0 ]; then
            printf "Error: %s contains files that did not come from %s:\n" \
                "$skill_dir" "$STOW_DIR" >&2
            printf "%s\n" "$real_files" | sed 's|^|  |' >&2
            printf "Refusing to delete them. Move them elsewhere, or pass --allow-destroy to set them aside.\n" >&2
            return 1
        fi

        # --allow-destroy sets files aside; it does not destroy them. A backup
        # costing one mv would have saved the 523-line file this guard exists for.
        #
        # Every step here is failure-checked, and that is NOT optional. Because
        # remove_install is called as `remove_install ... || { ... }`, POSIX
        # suppresses `set -e` for this entire function body, so an unchecked
        # failing mv would be ignored and execution would fall through to the
        # rm -rf below, destroying the files that were never set aside. Verified
        # empirically on macOS /bin/sh.
        local backup rel
        backup="$(mktemp -d)" && [ -n "$backup" ] || return 1
        printf "%s\n" "$real_files" | while IFS= read -r f; do
            [ -n "$f" ] || continue
            rel="${f#"$skill_dir"/}"
            mkdir -p "$backup/$(dirname "$rel")" && mv "$f" "$backup/$rel" || exit 1
        done || {
            printf "Error: failed to set aside files from %s. Partial backup in %s. Nothing deleted.\n" \
                "$skill_dir" "$backup" >&2
            return 1
        }
        printf "  %-20s set aside human files in %s\n" "$skill_name" "$backup"
    fi

    rm -rf "$skill_dir"
}

# Recursively create symlinks from source to target, preserving directory structure
install_symlinks() {
    local source_dir="$1"
    local target_dir="$2"

    for item in "$source_dir"/*; do
        [ -e "$item" ] || continue
        local name
        name="$(basename "$item")"

        if [ -d "$item" ]; then
            mkdir -p "$target_dir/$name"
            install_symlinks "$item" "$target_dir/$name"
        else
            ln -sf "$item" "$target_dir/$name"
        fi
    done
}

install_skill() {
    local skill_name="$1"
    local source_dir="$STOW_DIR/$skill_name"
    local skill_dir="$TARGET_DIR/$skill_name"

    [ -f "$source_dir/SKILL.md" ] || die "Cannot find $source_dir/SKILL.md"

    # Idempotency: if already correctly installed, nothing to do
    if is_current_install "$skill_name"; then
        if [ "$FORCE" = 0 ]; then
            printf "  %-20s already installed — skipping\n" "$skill_name"
            return
        fi
        remove_install "$skill_name" || {
            printf "  %-20s skipped (protected files present)\n" "$skill_name"
            RC=1
            return 0
        }
    elif [ -e "$skill_dir" ] || [ -L "$skill_dir" ]; then
        # Something else is there
        if [ "$FORCE" = 1 ]; then
            remove_install "$skill_name" || {
                printf "  %-20s skipped (protected files present)\n" "$skill_name"
                RC=1
                return 0
            }
        else
            printf "%s exists but was not installed from this source. Overwrite? [y/N] " "$skill_dir"
            read -r answer
            case "$answer" in
                [yY]|[yY][eE][sS])
                    remove_install "$skill_name" || {
                        printf "  %-20s skipped (protected files present)\n" "$skill_name"
                        RC=1
                        return 0
                    }
                    ;;
                *) printf "  %-20s skipped (user declined)\n" "$skill_name"; return ;;
            esac
        fi
    fi

    mkdir -p "$skill_dir"
    install_symlinks "$source_dir" "$skill_dir"
    printf "  %-20s installed\n" "$skill_name"
}

uninstall_skill() {
    local skill_name="$1"
    local skill_dir="$TARGET_DIR/$skill_name"

    if [ -e "$skill_dir" ] || [ -L "$skill_dir" ]; then
        remove_install "$skill_name" || { RC=1; return 0; }
        printf "  %-20s uninstalled\n" "$skill_name"
    else
        printf "  %-20s not installed — skipping\n" "$skill_name"
    fi
}

# --- Atlassian MCP Server Configuration ---
#
# The official Atlassian Rovo MCP Server (https://mcp.atlassian.com/v1/mcp)
# provides rich Jira tools (create, get, edit, search, transition, comment, etc.)
# via the Model Context Protocol. It uses OAuth 2.1 — on first use Claude Code
# opens a browser window for authorization. No API tokens or env vars are required.
#
# Registered via `claude mcp add` (user scope) so Claude Code manages the
# connection and OAuth lifecycle natively. No mcp-remote proxy needed.

ATLASSIAN_MCP_URL="https://mcp.atlassian.com/v1/mcp"
SETTINGS_FILE="$HOME/.claude/settings.json"

atlassian_mcp_is_configured() {
    claude mcp get atlassian >/dev/null 2>&1
}

# Remove legacy mcp-remote config from settings.json if present
remove_legacy_atlassian_mcp() {
    [ -f "$SETTINGS_FILE" ] || return 0
    python3 -c "
import json, sys

path = sys.argv[1]
with open(path) as f:
    data = json.load(f)

servers = data.get('mcpServers', {})
if 'atlassian' not in servers:
    sys.exit(0)

servers.pop('atlassian')
if not servers:
    data.pop('mcpServers', None)

with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
print('  Removed legacy mcp-remote atlassian entry from settings.json')
" "$SETTINGS_FILE" 2>/dev/null || true
}

# Remove stale mcp-remote OAuth tokens
remove_legacy_mcp_auth() {
    local auth_dir="$HOME/.mcp-auth"
    if [ -d "$auth_dir" ] && [ "$(ls -A "$auth_dir" 2>/dev/null)" ]; then
        rm -rf "$auth_dir"
        printf "  Removed stale mcp-remote tokens from %s\n" "$auth_dir"
    fi
}

configure_atlassian_mcp() {
    if ! command -v claude >/dev/null 2>&1; then
        printf "\n  Warning: claude CLI not found — cannot configure Atlassian MCP.\n"
        return 1
    fi

    # Clean up legacy configuration first
    remove_legacy_atlassian_mcp
    remove_legacy_mcp_auth

    if atlassian_mcp_is_configured; then
        printf "  %-20s already configured — skipping\n" "Atlassian MCP"
        return 0
    fi

    printf "  Registering Atlassian MCP server with Claude Code...\n"
    claude mcp add --transport http -s user atlassian "$ATLASSIAN_MCP_URL" || {
        printf "  Warning: failed to add Atlassian MCP server.\n"
        printf "  To add manually, run:\n"
        printf "    claude mcp add --transport http -s user atlassian %s\n" "$ATLASSIAN_MCP_URL"
        return 1
    }

    printf "  %-20s registered (user scope)\n" "Atlassian MCP"
    printf "\n"
    printf "  OAuth will be triggered automatically on first use in Claude Code.\n"
    printf "  Restart Claude Code after install to connect.\n"
}

# --- Jira Link Fallback Credentials ---
#
# The Jira.ts CLI tool (issue linking only) requires API credentials in
# ~/.claude/.env because the Atlassian MCP does not yet support issue linking.

ENV_FILE="$HOME/.claude/.env"

env_file_has_var() {
    [ -f "$ENV_FILE" ] && grep -q "^$1=" "$ENV_FILE" 2>/dev/null
}

configure_jira_credentials() {
    local missing=""
    for var in JIRA_API_TOKEN JIRA_EMAIL; do
        if ! env_file_has_var "$var"; then
            missing="$missing $var"
        fi
    done

    if [ -z "$missing" ]; then
        printf "  %-20s credentials present in %s\n" "Jira link CLI" "$ENV_FILE"
        return 0
    fi

    printf "\n  The Jira issue link CLI needs API credentials in %s.\n" "$ENV_FILE"
    printf "  (Only needed for issue linking — all other Jira ops use MCP OAuth.)\n"
    printf "  Missing:%s\n\n" "$missing"

    # Check if vars are already in the environment (e.g. from ~/.config/jira/credentials)
    local found_in_env=""
    if [ -n "${JIRA_API_TOKEN:-}" ] && [ -n "${JIRA_EMAIL:-}" ]; then
        found_in_env=1
        printf "  Found JIRA_API_TOKEN and JIRA_EMAIL in your environment.\n"
        printf "  Write them to %s? [Y/n] " "$ENV_FILE"
        read -r answer
        case "$answer" in
            [nN]|[nN][oO]) found_in_env="" ;;
        esac
    fi

    mkdir -p "$(dirname "$ENV_FILE")"
    touch "$ENV_FILE"

    if [ -n "$found_in_env" ]; then
        for var in JIRA_API_TOKEN JIRA_EMAIL; do
            if ! env_file_has_var "$var"; then
                eval "val=\"\$$var\""
                printf "%s=%s\n" "$var" "$val" >> "$ENV_FILE"
            fi
        done
        printf "  %-20s credentials written to %s\n" "Jira link CLI" "$ENV_FILE"
        return 0
    fi

    printf "  Enter credentials now? [Y/n] "
    read -r answer
    case "$answer" in
        [nN]|[nN][oO])
            printf "  Skipped — add JIRA_API_TOKEN and JIRA_EMAIL to %s later.\n" "$ENV_FILE"
            return 0
            ;;
    esac

    for var in JIRA_API_TOKEN JIRA_EMAIL; do
        if ! env_file_has_var "$var"; then
            printf "  %s: " "$var"
            read -r val
            if [ -n "$val" ]; then
                printf "%s=%s\n" "$var" "$val" >> "$ENV_FILE"
            fi
        fi
    done
    printf "  %-20s credentials written to %s\n" "Jira link CLI" "$ENV_FILE"
}

remove_atlassian_mcp() {
    # Clean up legacy config if present
    remove_legacy_atlassian_mcp
    remove_legacy_mcp_auth

    if ! atlassian_mcp_is_configured; then
        printf "  %-20s not configured — skipping\n" "Atlassian MCP"
        return 0
    fi

    claude mcp remove -s user atlassian 2>/dev/null || true
    printf "  %-20s removed\n" "Atlassian MCP"
}

# --- Main ---

mkdir -p "$TARGET_DIR"

# Check if JIRA is among the skills being processed
JIRA_INCLUDED=0
for skill in $SKILLS; do
    case "$skill" in
        JIRA|jira) JIRA_INCLUDED=1 ;;
    esac
done

if [ "$UNINSTALL" = 1 ]; then
    printf "Uninstalling skills from %s\n" "$TARGET_DIR"
    for skill in $SKILLS; do
        uninstall_skill "$skill"
    done
    if [ "$JIRA_INCLUDED" = 1 ]; then
        remove_atlassian_mcp
    fi
else
    printf "Installing skills to %s\n" "$TARGET_DIR"
    for skill in $SKILLS; do
        install_skill "$skill"
    done
    if [ "$JIRA_INCLUDED" = 1 ]; then
        printf "\nConfiguring Atlassian MCP server for Jira integration...\n"
        configure_atlassian_mcp || true
        printf "\nChecking Jira issue link credentials...\n"
        configure_jira_credentials
    fi
fi

exit "$RC"
