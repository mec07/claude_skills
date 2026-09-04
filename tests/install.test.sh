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

# Every test below uses run_install, so HOME and CLAUDE_SKILLS_DIR are both
# sandboxed and stdin is closed. Never call sh "$INSTALL" directly here.

test_refuses_to_destroy_real_files() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep >/dev/null
    printf "precious\n" > "$target/Sleep/NOTES.md"

    out="$(run_install "$home" --force Sleep)" || true

    if [ -f "$target/Sleep/NOTES.md" ]; then
        pass "human file survives --force"
    else
        fail "human file survives --force" "NOTES.md was destroyed"
    fi
    assert_contains "error names the file at risk" "NOTES.md" "$out"
    rm -rf "$home"
}

test_refuses_to_destroy_nested_file() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" RepoSkills >/dev/null
    mkdir -p "$target/RepoSkills/templates"
    printf "nested\n" > "$target/RepoSkills/templates/MINE.md"

    run_install "$home" --force RepoSkills >/dev/null || true

    if [ -f "$target/RepoSkills/templates/MINE.md" ]; then
        pass "nested human file survives --force"
    else
        fail "nested human file survives --force" "templates/MINE.md was destroyed"
    fi
    rm -rf "$home"
}

test_uninstall_also_refuses() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep >/dev/null
    printf "precious\n" > "$target/Sleep/NOTES.md"

    run_install "$home" --uninstall Sleep >/dev/null || true

    if [ -f "$target/Sleep/NOTES.md" ]; then
        pass "human file survives --uninstall"
    else
        fail "human file survives --uninstall" "NOTES.md was destroyed by uninstall"
    fi
    rm -rf "$home"
}

test_one_protected_skill_does_not_abort_the_run() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep RepoSkills >/dev/null
    printf "precious\n" > "$target/Sleep/NOTES.md"
    rm -f "$target/RepoSkills/SKILL.md"

    run_install "$home" --force Sleep RepoSkills >/dev/null || true

    if [ -e "$target/RepoSkills/SKILL.md" ]; then
        pass "a protected skill does not abort later skills"
    else
        fail "a protected skill does not abort later skills" \
             "RepoSkills was never reinstalled, so the loop exited early"
    fi
    rm -rf "$home"
}

test_allow_destroy_sets_aside_rather_than_deleting() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep >/dev/null
    printf "disposable\n" > "$target/Sleep/NOTES.md"

    out="$(run_install "$home" --force --allow-destroy Sleep)"

    if [ -f "$target/Sleep/NOTES.md" ]; then
        fail "--allow-destroy clears the install dir" "NOTES.md still in place"
    else
        pass "--allow-destroy clears the install dir"
    fi
    assert_contains "--allow-destroy reports where files went" "set aside" "$out"

    backup="$(printf "%s" "$out" | sed -n 's/.*set aside human files in \(.*\)$/\1/p' | head -1)"
    if [ -n "$backup" ] && [ -f "$backup/NOTES.md" ]; then
        pass "--allow-destroy preserves the file contents"
    else
        fail "--allow-destroy preserves the file contents" "not found under [$backup]"
    fi
    rm -rf "$home" "$backup"
}

test_force_still_works_on_symlinks_only() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep >/dev/null
    out="$(run_install "$home" --force Sleep)"
    assert_contains "clean --force still reports installed" "installed" "$out"
    rm -rf "$home"
}

test_refuses_to_destroy_real_files
test_refuses_to_destroy_nested_file
test_uninstall_also_refuses
test_one_protected_skill_does_not_abort_the_run
test_allow_destroy_sets_aside_rather_than_deleting
test_force_still_works_on_symlinks_only

printf "\n%s run, %s failed\n" "$TESTS_RUN" "$TESTS_FAILED"
[ "$TESTS_FAILED" -eq 0 ]
