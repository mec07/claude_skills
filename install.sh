#!/bin/sh
set -e

TARGET_DIR="$HOME/.claude/skills"

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
  --force       Overwrite existing installations without prompting
  --uninstall   Remove installed skills
  --help        Show this message

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
SKILLS=""
for arg in "$@"; do
    case "$arg" in
        --force)     FORCE=1 ;;
        --uninstall) UNINSTALL=1 ;;
        --help)      usage; exit 0 ;;
        -*)          die "unknown option: $arg (see --help)" ;;
        *)           SKILLS="$SKILLS $arg" ;;
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
    # Remove whatever is there (symlink or directory)
    if [ -e "$skill_dir" ] || [ -L "$skill_dir" ]; then
        rm -rf "$skill_dir"
    fi
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
        remove_install "$skill_name"
    elif [ -e "$skill_dir" ] || [ -L "$skill_dir" ]; then
        # Something else is there
        if [ "$FORCE" = 1 ]; then
            remove_install "$skill_name"
        else
            printf "%s exists but was not installed from this source. Overwrite? [y/N] " "$skill_dir"
            read -r answer
            case "$answer" in
                [yY]|[yY][eE][sS]) remove_install "$skill_name" ;;
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
        remove_install "$skill_name"
        printf "  %-20s uninstalled\n" "$skill_name"
    else
        printf "  %-20s not installed — skipping\n" "$skill_name"
    fi
}

# --- Main ---

mkdir -p "$TARGET_DIR"

if [ "$UNINSTALL" = 1 ]; then
    printf "Uninstalling skills from %s\n" "$TARGET_DIR"
    for skill in $SKILLS; do
        uninstall_skill "$skill"
    done
else
    printf "Installing skills to %s\n" "$TARGET_DIR"
    for skill in $SKILLS; do
        install_skill "$skill"
    done
fi
