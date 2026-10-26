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

# Link lines to the Migrating section (Task 4) are exempt from the MEMORY checks.
without_migration_links() { grep -v 'Migrating from ~/.claude/MEMORY'; }

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
need "summary lists generated files to commit" "$O" 'List the files to commit: every file the run wrote or changed outside the RepoSkills directory'
need "phase 9 summary lists generated files to commit" "$REPO_ROOT/stow/RepoSkills/phase-9-human-checkpoint.md" 'Files to commit: \[every file the run wrote or changed outside the RepoSkills directory'
need "commit is start HEAD" "$O" 'HEAD recorded at the start of the run'
absent "cleanup no longer advances to end HEAD" "$O" 'in case commits happened during the run'
absent "pipeline does not commit" "$O" 'Commit updated/new skill files'

# The Migrating section (Task 4) may be linked from elsewhere; those link lines are exempt.
outside_section "$O" '### Migrating from ~/.claude/MEMORY' | without_migration_links > "$TMP/outside.md"
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

echo "phase files"

PHASES="$REPO_ROOT/stow/RepoSkills"
for f in "$PHASES"/phase-*.md; do
    b="$(basename "$f")"
    without_migration_links < "$f" > "$TMP/$b"
    absent "$b: no MEMORY" "$TMP/$b" 'MEMORY'
    absent "$b: no slug" "$f" 'slug'
done

need "phase 0 writes only to RepoSkills dir" "$PHASES/phase-0-discover.md" 'writes only to `.ai/RepoSkills/`'
need "boundaries Path column" "$PHASES/phase-2-map-generate.md" '^| Path | Boundary | Type | Entry Point | Evidence |'
need "boundaries header" "$PHASES/phase-2-map-generate.md" 'Snapshot at <commit>. Pipeline bookkeeping'
need "phase 2 writes the manifest" "$PHASES/phase-2-map-generate.md" 'Write `.ai/RepoSkills/_manifest.md`'
extract_section "$O" '### State file' > "$TMP/statefile.md"
need "state template lists step 2.7" "$TMP/statefile.md" '^  - \[ \] 2\.7: Write _manifest.md and delete the _explore_ and _skill_ working files$'
need "phase 2 deletes its working files" "$PHASES/phase-2-map-generate.md" 'delete every `_explore_\*.md` and `_skill_\*.md`'
extract_section "$O" '### Manifest format' > "$TMP/manifest.md"
need "manifest header" "$TMP/manifest.md" 'Snapshot at <commit>. Pipeline bookkeeping'
for f in phase-9-human-checkpoint.md phase-drift-resolve.md; do
    need "$f: commit-mode summary" "$PHASES/$f" '`.ai/RepoSkills/` among the files to commit'
    need "$f: start HEAD" "$PHASES/$f" 'HEAD recorded at the start of the run'
done
absent "phase 9 has no commit_hash" "$PHASES/phase-9-human-checkpoint.md" 'commit_hash:'

echo "trust rule"

S="$(extract_section "$O" '### Trust rule for stored state')"
printf "%s\n" "$S" > "$TMP/trust.md"
if [ -z "$S" ]; then fail "trust rule section exists" "no '### Trust rule for stored state' in $O"; else pass "trust rule section exists"; fi
need "trust: changed-paths command" "$TMP/trust.md" "-- \. ':!\.ai'"
need "trust: match rule" "$TMP/trust.md" "a changed path equals the entry's path or lies under it"
need "trust: Unit List" "$TMP/trust.md" 'Unit List'
need "trust: Path" "$TMP/trust.md" 'Path'
need "trust: signal detection" "$TMP/trust.md" 'Phase 0 Step 4'
need "trust: human confirms" "$TMP/trust.md" 'only after the human confirms'
need "trust: gone from disk" "$TMP/trust.md" 'no longer exists on disk'
need "trust: record line" "$TMP/trust.md" 'Re-checked:'
need "drift links trust rule" "$PHASES/phase-drift-resolve.md" 'Trust rule for stored state'
need "drift uses changed-paths command" "$PHASES/phase-drift-resolve.md" "':!\.ai'"

CMD="$(printf "%s\n" "$S" | grep 'diff --name-only' | head -1 | sed -n 's/^[^`]*`\([^`]*\)`.*$/\1/p')"
if [ -z "$CMD" ]; then
    fail "trust: extracted command runs" "no backticked diff --name-only command in the section"
else
    T="$TMP/trustrepo"
    mkdir -p "$T/src"
    git -C "$T" init -q
    git -C "$T" config user.name test
    git -C "$T" config user.email test@example.com
    echo 1 > "$T/src/a"
    git -C "$T" add . && git -C "$T" commit -q -m one
    C="$(git -C "$T" rev-parse HEAD)"
    mkdir -p "$T/.ai/RepoSkills" "$T/.ai/skills/modules" "$T/.cursor/rules"
    echo s > "$T/.ai/RepoSkills/state.md"
    echo m > "$T/.ai/skills/modules/x.md"
    echo c > "$T/CLAUDE.md"
    echo r > "$T/.cursor/rules/x.mdc"
    git -C "$T" add . && git -C "$T" commit -q -m two
    RUN="$(printf "%s" "$CMD" | sed "s/<commit>/$C/g")"
    OUT="$(cd "$T/src" && sh -c "$RUN" 2>&1)"
    if printf "%s\n" "$OUT" | grep -q '^\.ai/'; then fail "trust: .ai excluded" "output: $OUT"; else pass "trust: .ai excluded"; fi
    if printf "%s\n" "$OUT" | grep -q '^CLAUDE.md$' && printf "%s\n" "$OUT" | grep -q '^\.cursor/rules/x\.mdc$'; then
        pass "trust: root files listed from subdirectory"
    else
        fail "trust: root files listed from subdirectory" "output: $OUT"
    fi
    echo 2 > "$T/src/a"
    git -C "$T" commit -q -am three
    OUT="$(cd "$T/src" && sh -c "$RUN" 2>&1)"
    if printf "%s\n" "$OUT" | grep -q '^src/a$'; then pass "trust: changed source listed"; else fail "trust: changed source listed" "output: $OUT"; fi
fi

extract_section "$O" '### Targeted update' > "$TMP/targeted.md"
need "targeted: trust rule applies to every matching entry" "$TMP/targeted.md" 'every stored entry the changed-paths set matches, not only this module'
extract_section "$O" '### Diff-based update' > "$TMP/diffupdate.md"
need "diff update: trust rule not applied twice" "$TMP/diffupdate.md" 'step 1 is skipped because step 3 here already applied the trust rule'

echo "migration"

M="$(extract_section "$O" '### Migrating from ~/.claude/MEMORY')"
printf "%s\n" "$M" > "$TMP/migration.md"
if [ -z "$M" ]; then fail "migration section exists" "no '### Migrating from ~/.claude/MEMORY' in $O"; else pass "migration section exists"; fi
need "migration: offer" "$TMP/migration.md" 'offer'
need "migration: boundaries" "$TMP/migration.md" '_boundaries.md'
need "migration: manifest" "$TMP/migration.md" '_manifest.md'
need "migration: repo guard" "$TMP/migration.md" 'repo:'
need "migration: toplevel" "$TMP/migration.md" 'git rev-parse --show-toplevel'
need "migration: dir-name" "$TMP/migration.md" 'basename'
need "migration: persisted header" "$TMP/migration.md" 'persisted header'
need "migration: commit-mode question" "$TMP/migration.md" '#commit-mode'
need "migration: trust rule" "$TMP/migration.md" '#trust-rule-for-stored-state'
need "migration: remove old dir" "$TMP/migration.md" 'remove the old directory'
extract_section "$O" '### Detecting update mode' > "$TMP/detect.md"
need "detect mode: step 0 migrates" "$TMP/detect.md" '^0\. .*Migrating from ~/.claude/MEMORY'
need "drift links migration" "$PHASES/phase-drift-resolve.md" 'Migrating from ~/.claude/MEMORY'
grep -q '(orchestration.md#migrating-from-claudememory)\|(#migrating-from-claudememory)' "$TMP/detect.md" \
    && pass "detect mode: migration anchor" || fail "detect mode: migration anchor" "anchor missing"

echo "helper self-test"

cat > "$TMP/fixture.md" <<'FIX'
### Migrating from ~/.claude/MEMORY
MEMORY inside section
### Other
kept line
See [Migrating from ~/.claude/MEMORY](x) link
plain MEMORY mention
FIX
outside_section "$TMP/fixture.md" '### Migrating from ~/.claude/MEMORY' > "$TMP/fx-out.md"
absent "outside_section drops section body" "$TMP/fx-out.md" 'MEMORY inside section'
need "outside_section keeps later section" "$TMP/fx-out.md" '^### Other'
without_migration_links < "$TMP/fx-out.md" > "$TMP/fx-filtered.md"
absent "filter drops link line" "$TMP/fx-filtered.md" 'link'
need "filter keeps plain MEMORY line" "$TMP/fx-filtered.md" 'plain MEMORY mention'

echo
echo "$TESTS_RUN run, $TESTS_FAILED failed"
[ "$TESTS_FAILED" -eq 0 ] || exit 1
