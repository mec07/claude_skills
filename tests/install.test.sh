#!/bin/sh
# Test suite for install.sh. Dependency-free: POSIX sh only.
# Run: sh tests/install.test.sh
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$REPO_ROOT/install.sh"
TESTS_RUN=0
TESTS_FAILED=0

pass() { TESTS_RUN=$((TESTS_RUN + 1)); printf "  ok   %s\n" "$1"; }
fail() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "  FAIL %s\n" "$1"
    printf "       %s\n" "$2"
}

assert_eq() {
    # assert_eq <name> <expected> <actual>
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected [$2] got [$3]"; fi
}

assert_contains() {
    # assert_contains <name> <needle> <haystack>
    case "$3" in
        *"$2"*) pass "$1" ;;
        *) fail "$1" "expected to contain [$2] in [$3]" ;;
    esac
}

# Creates an isolated fake HOME and echoes the skills dir inside it.
# HOME is sandboxed as well as CLAUDE_SKILLS_DIR, because before Task 1's fix
# lands install.sh ignores CLAUDE_SKILLS_DIR and derives TARGET_DIR from $HOME
# (install.sh:4). Without the HOME sandbox the red phase would operate on the
# real installation, which is the exact failure this whole plan exists to stop.
setup_fixture() {
    d="$(mktemp -d)"
    mkdir -p "$d/.claude/skills"
    printf "%s" "$d/.claude/skills"
}

# Run install.sh fully sandboxed. Never invoke it any other way in these tests.
# </dev/null so the interactive overwrite prompt (install.sh:118) can never block.
run_install() {
    fixture_home="$1"; shift
    HOME="$fixture_home" CLAUDE_SKILLS_DIR="$fixture_home/.claude/skills" \
        sh "$INSTALL" "$@" </dev/null 2>&1
}

# ---- tests ----

# Red-phase behaviour: with HOME sandboxed and CLAUDE_SKILLS_DIR ignored,
# install.sh installs into $fixture/.claude/skills by the HOME path. So this
# test must assert CLAUDE_SKILLS_DIR is honoured on its own, pointed somewhere
# HOME would NOT resolve to. That is what turns it red before the fix.
test_target_dir_is_overridable() {
    home="$(mktemp -d)"
    mkdir -p "$home/.claude/skills"
    elsewhere="$(mktemp -d)/other-skills"
    mkdir -p "$elsewhere"

    HOME="$home" CLAUDE_SKILLS_DIR="$elsewhere" sh "$INSTALL" Sleep </dev/null >/dev/null 2>&1

    if [ -e "$elsewhere/Sleep/SKILL.md" ]; then
        pass "CLAUDE_SKILLS_DIR redirects the install target"
    else
        fail "CLAUDE_SKILLS_DIR redirects the install target" \
             "Sleep did not land in $elsewhere (pre-fix it goes to \$HOME instead)"
    fi
    rm -rf "$home" "$(dirname "$elsewhere")"
}

test_install_lands_under_sandboxed_home() {
    target="$(setup_fixture)"
    home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep >/dev/null
    if [ -e "$target/Sleep/SKILL.md" ]; then
        pass "sandboxed install produces a working skill dir"
    else
        fail "sandboxed install produces a working skill dir" "no Sleep/SKILL.md under $target"
    fi
    rm -rf "$home"
}

test_target_dir_is_overridable
test_install_lands_under_sandboxed_home

printf "\n%s run, %s failed\n" "$TESTS_RUN" "$TESTS_FAILED"
[ "$TESTS_FAILED" -eq 0 ]
