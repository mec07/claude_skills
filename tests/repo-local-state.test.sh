#!/bin/sh
# Test suite for RepoSkills' repo-local state (.ai/RepoSkills/). Dependency-free: POSIX sh only.
# Run: sh tests/repo-local-state.test.sh
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
O="$REPO_ROOT/stow/RepoSkills/orchestration.md"
TESTS_RUN=0
TESTS_FAILED=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass() { TESTS_RUN=$((TESTS_RUN + 1)); printf "  ok   %s\n" "$1"; }
fail() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "  FAIL %s\n" "$1"
    printf "       %s\n" "$2"
}

# Case-sensitive BRE on purpose: -i would match "Do not rely on memory" in phase files.
need() {
    # need <name> <file> <pattern>
    if grep -q -- "$3" "$2"; then pass "$1"; else fail "$1" "missing pattern [$3] in $2"; fi
}

absent() {
    # absent <name> <file> <pattern>
    if grep -q -- "$3" "$2"; then fail "$1" "unexpected pattern [$3] in $2"; else pass "$1"; fi
}

# Prints from the line exactly equal to <first-line> up to, not including, the next ``` line.
extract_block() {
    awk -v start="$2" '
        found && /^```/ { exit }
        found { print }
        !found && $0 == start { found = 1; print }
    ' "$1"
}

# Prints from the first line starting with <heading> up to, not including, the next
# "## " or "### " line that sits outside a fenced block.
extract_section() {
    awk -v h="$2" '
        /^```/ { fence = !fence }
        found && !fence && (/^## / || /^### /) { exit }
        found { print }
        !found && index($0, h) == 1 { found = 1; print }
    ' "$1"
}

# Prints the file with that section removed.
outside_section() {
    awk -v h="$2" '
        /^```/ { fence = !fence }
        skip && !fence && (/^## / || /^### /) { skip = 0 }
        !skip && !found && index($0, h) == 1 { skip = 1; found = 1 }
        !skip { print }
    ' "$1"
}

echo "orchestration.md"

need "location stated" "$O" 'All working files and state live in `.ai/RepoSkills/`'
need "RS prefix defined" "$O" '`RS:` prefix means the file lives in `.ai/RepoSkills/`'
need "repo root derived" "$O" 'git rev-parse --show-toplevel'
need "persisted header" "$O" 'Snapshot at <commit>. Pipeline bookkeeping, not documentation. Verify against code before trusting.'
need "mode detection" "$O" 'check-ignore -q --no-index .ai/RepoSkills/state.md'
need "never rewrite gitignore" "$O" 'never rewrites'
need "fresh clone case" "$O" '`.gitignore` exists but `state.md` does not'
need "not inside skills" "$O" 'never inside `.ai/skills/`'
need "boundaries preserved in table" "$O" '^| `_boundaries.md`.*Never'
need "manifest preserved in table" "$O" '^| `_manifest.md`.*Never'
need "commit-mode summary" "$O" '`.ai/RepoSkills/` among the files to commit'
need "commit is start HEAD" "$O" 'HEAD recorded at the start of the run'
absent "cleanup no longer advances to end HEAD" "$O" 'in case commits happened during the run'
absent "pipeline does not commit" "$O" 'Commit updated/new skill files'

# The Migrating section (Task 4) may be linked from elsewhere; those link lines are exempt.
outside_section "$O" '### Migrating from ~/.claude/MEMORY' | grep -v 'Migrating from ~/.claude/MEMORY' > "$TMP/outside.md"
absent "no MEMORY outside migration section" "$TMP/outside.md" 'MEMORY'
absent "no slug field" "$TMP/outside.md" '^slug:'
absent "no repo field" "$TMP/outside.md" '^repo:'
absent "no MEMORY working-files heading" "$TMP/outside.md" '^### Working files in MEMORY'

echo "commit-mode gitignore behaviour"

COMMIT_BLOCK="$(extract_block "$O" '# RepoSkills state: commit mode')"
NOCOMMIT_BLOCK="$(extract_block "$O" '# RepoSkills state: no-commit mode')"
if [ -z "$COMMIT_BLOCK" ]; then fail "commit-mode block extracted" "extract_block printed nothing"; else pass "commit-mode block extracted"; fi
if [ -z "$NOCOMMIT_BLOCK" ]; then fail "no-commit block extracted" "extract_block printed nothing"; else pass "no-commit block extracted"; fi

R="$TMP/repo"
mkdir -p "$R/.ai/RepoSkills" "$R/src"
git -C "$R" init -q
git -C "$R" config user.name test
git -C "$R" config user.email test@example.com
printf "%s\n" "$COMMIT_BLOCK" > "$R/.ai/RepoSkills/.gitignore"
for f in state.md _boundaries.md _manifest.md _triage.md _sim_1.md; do : > "$R/.ai/RepoSkills/$f"; done

ignored() { git -C "$R" check-ignore -q --no-index ".ai/RepoSkills/$1"; }
for f in _triage.md _sim_1.md; do
    if ignored "$f"; then pass "commit mode ignores $f"; else fail "commit mode ignores $f" "not ignored"; fi
done
for f in state.md _boundaries.md _manifest.md .gitignore; do
    if ignored "$f"; then fail "commit mode keeps $f" "ignored"; else pass "commit mode keeps $f"; fi
done

detect() { (cd "$1" && git -C "$(git rev-parse --show-toplevel)" check-ignore -q --no-index .ai/RepoSkills/state.md); }
detect "$R"; rc=$?
assert_rc() { if [ "$2" -eq "$3" ]; then pass "$1"; else fail "$1" "expected exit $3 got $2"; fi; }
assert_rc "mode detection says commit mode" "$rc" 1

git -C "$R" add .ai >/dev/null 2>&1
git -C "$R" commit -q -m "track state"
printf "%s\n" "$NOCOMMIT_BLOCK" > "$R/.ai/RepoSkills/.gitignore"
detect "$R/src"; rc=$?
assert_rc "mode detection says no-commit mode from subdirectory, state.md tracked" "$rc" 0

echo
echo "$TESTS_RUN run, $TESTS_FAILED failed"
[ "$TESTS_FAILED" -eq 0 ] || exit 1
