# install.sh Safety and Drift Check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop `install.sh` destroying files it did not create, and give it a `--check` mode that reports drift between `stow/` and the installed skills.

**Architecture:** Two surgical changes to the existing `install.sh`, plus a dependency-free test harness. `remove_install()` gains a guard that refuses to proceed when the target directory holds regular files (which are never installer-created, since the installer only writes symlinks and directories), returning non-zero so one protected skill does not abandon the rest of the run. `--allow-destroy` sets such files aside in a temp directory rather than deleting them. A new `--check` mode walks the same source tree the installer walks and reports what is missing, stale, unmanaged, orphaned or foreign. A plain install also stops skipping a partially-linked skill and tops it up instead, since detecting the April failure without repairing it would be half a tool. The top-up links only where the destination is absent or already a symlink, so it repairs installer drift without ever overwriting a user's file. `TARGET_DIR` becomes overridable so tests never touch the real `~/.claude/skills`.

**Tech Stack:** POSIX `sh` (`install.sh` is `#!/bin/sh`), `find`, `shellcheck` (already installed at `/opt/homebrew/bin/shellcheck`). No bats, no new dependencies.

**Spec:** `Plans/RepoSkills-readme-mode-and-backlog-design.md`, section 7 (Housekeeping) and section 8 stage 1.

## Global Constraints

- `install.sh` is `#!/bin/sh` with `set -e`. Do not introduce bashisms. The file's existing helpers use `local`, which is not POSIX but is universally supported and already relied on; match that, add nothing further.
- The script must keep working with macOS stock tools. No GNU-only `find` or `sed` flags.
- Existing behaviour must not change for any invocation that is currently safe. `--force` on a directory containing only symlinks must still work silently.
- Surgical changes only. Do not restructure `install.sh`, rename its functions, or reformat untouched regions.
- No em dashes in any prose added to the repository.
- Every task ends with a commit.

---

### Task 1: Make install.sh testable and add the harness

**Files:**
- Modify: `install.sh:4`
- Create: `tests/install.test.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `CLAUDE_SKILLS_DIR` environment variable honoured by `install.sh` as the install target. `tests/install.test.sh` exposes shell functions `setup_fixture`, `assert_eq`, `assert_contains`, `pass`, `fail`, and the counters `TESTS_RUN` / `TESTS_FAILED`, all used by Tasks 2 and 3.

- [ ] **Step 1: Write the failing test**

Create `tests/install.test.sh`:

```sh
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `sh tests/install.test.sh`

Expected: FAIL on `CLAUDE_SKILLS_DIR redirects the install target`. `TARGET_DIR` is derived from
`$HOME` (install.sh:4) and `CLAUDE_SKILLS_DIR` is not read at all, so `Sleep` lands under the
sandboxed `$HOME` rather than the separate directory the test names.

Note what this test does **not** do: it never touches the real `~/.claude/skills`, because `HOME` is
sandboxed in every invocation. A red phase that writes to the developer's real installation would be
the same class of mistake this plan exists to prevent.

- [ ] **Step 3: Write the minimal implementation**

In `install.sh`, replace line 4:

```sh
TARGET_DIR="$HOME/.claude/skills"
```

with:

```sh
TARGET_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `sh tests/install.test.sh`

Expected: `0 failed`.

**Gate on `0 failed`, never on the total.** The runner counts assertions, not test functions, so the
total shifts whenever you add or split an assert. Every later step in this plan uses the same gate
for the same reason.

- [ ] **Step 5: Lint**

Run: `shellcheck install.sh tests/install.test.sh`

Expected: no new warnings relative to the pre-change baseline. `install.sh` already uses `local`, so `SC2039`/`SC3043` may appear; those are pre-existing and out of scope.

- [ ] **Step 6: Commit**

```bash
git add install.sh tests/install.test.sh
git commit -m "make install target overridable and add a test harness

install.sh had no tests because TARGET_DIR was hardcoded to the real
~/.claude/skills, so any test run would clobber the developer's own
installation. CLAUDE_SKILLS_DIR now overrides it, which makes the
installer testable in a temp dir."
```

---

### Task 2: Refuse to destroy files the installer did not create

**Files:**
- Modify: `install.sh:70-77` (`remove_install`)
- Modify: `install.sh:38-49` (flag parsing, to add `--allow-destroy`)
- Modify: `install.sh` usage heredoc (to document the flag)
- Test: `tests/install.test.sh`

**Interfaces:**
- Consumes: `CLAUDE_SKILLS_DIR`, `assert_contains`, `assert_eq`, `setup_fixture` from Task 1.
- Produces: `ALLOW_DESTROY` variable (`0` or `1`) and the `--allow-destroy` flag.

**Why this matters:** `install_symlinks()` only ever creates symlinks and directories. Therefore any *regular file* inside an installed skill directory was put there by a human and is not reproducible from `stow/`. `remove_install()` currently runs `rm -rf` over it. This destroyed `IMPROVEMENTS.md`, a 523-line uncommitted document, on 2026-08-27.

- [ ] **Step 1: Write the failing test**

Append to `tests/install.test.sh`, before the `printf "\n%s run` summary line:

```sh
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `sh tests/install.test.sh`

Expected: red overall. Specifically, every guard and set-aside assertion fails, because no guard
exists yet: `human file survives --force`, `error names the file at risk`, `nested human file
survives --force`, `human file survives --uninstall`, and all three `--allow-destroy` assertions
(the flag is unknown, so `die` rejects it).

Two of the new tests pass at this point and are expected to: `clean --force still reports installed`
(existing behaviour, which must not regress) and `a protected skill does not abort later skills`
(current `--force` deletes and reinstalls happily). The latter guards against the naive `exit 1`
form of the fix rather than against current behaviour, so do not expect it red here.

- [ ] **Step 3: Write the minimal implementation**

In the flag-parsing block, add `ALLOW_DESTROY=0` beside the existing `FORCE=0` / `UNINSTALL=0` initialisers, and add the case arm:

```sh
        --allow-destroy) ALLOW_DESTROY=1 ;;
```

Replace `remove_install()` in full:

```sh
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
```

The `exit 1` exits only the pipeline's subshell; the `|| { ... }` after `done` catches that non-zero
status and returns before `rm -rf` is reached. Both halves were verified on macOS `/bin/sh`: a
failing command inside a `||`-invoked function body does continue, and this construct does intercept.
With the guard in place the worst outcome of any failure is files split between the skill directory
and a named backup. Nothing is lost.

`return 1` rather than `exit 1` is deliberate. `install_skill` runs inside a `for` loop
(`install.sh:335-337`), so exiting would abandon every skill after the offending one, silently
recreating the partial-install drift Task 3 exists to detect. Both callers must therefore propagate:

```sh
# in install_skill, at each of the three remove_install call sites
remove_install "$skill_name" || {
    printf "  %-20s skipped (protected files present)\n" "$skill_name"
    RC=1
    return 0
}
```

```sh
# in uninstall_skill
remove_install "$skill_name" || { RC=1; return 0; }
```

Initialise `RC=0` beside the other flag defaults, and add `exit "$RC"` **after the closing `fi` at
`install.sh:344`**, not inside the else branch, so it is reached on both the install and uninstall
paths. `--check` exits earlier through its own accumulator by design.

Add to the usage heredoc, under `Options:`:

```
  --allow-destroy  Move files in the target that did not come from stow/ to a temp dir (path printed)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `sh tests/install.test.sh`

Expected: `0 failed`

- [ ] **Step 5: Verify the real-world case by hand**

```bash
CLAUDE_SKILLS_DIR="$(mktemp -d)/skills"
export CLAUDE_SKILLS_DIR
sh install.sh RepoSkills
```

The export is on its own line deliberately: a `VAR=value cmd` prefix scopes the variable to that
one command, so the `ls` below would expand `$CLAUDE_SKILLS_DIR` to an empty string and look under
`/RepoSkills/` instead.

Then confirm `IMPROVEMENTS.md` arrives as a symlink, not a copy:

```bash
ls -la "$CLAUDE_SKILLS_DIR/RepoSkills/IMPROVEMENTS.md"
```

Expected: a symlink into `stow/RepoSkills/`. Because the file is **present in `stow/`** the installer
links it, so it is not a regular file in the target and does not trip the guard. Note that presence
in `stow/`, not git tracked-ness, is what matters: `IMPROVEMENTS.md` is deliberately untracked per
the spec's H2, and the installer neither knows nor cares. This confirms the guard protects
human-authored files in the target without blocking normal installs.

- [ ] **Step 6: Commit**

```bash
git add install.sh tests/install.test.sh
git commit -m "refuse to delete target files that did not come from stow/

remove_install ran rm -rf over the whole skill directory. Since
install_symlinks only ever writes symlinks and directories, any regular
file in there was human-authored and unrecoverable. On 2026-08-27 this
destroyed a 523-line uncommitted document.

The installer now aborts and names the files at risk. --allow-destroy
opts back in."
```

---

### Task 3: Add a --check mode that reports drift

**Files:**
- Modify: `install.sh` (flag parsing, usage heredoc, and the dispatch block at the end)
- Test: `tests/install.test.sh`

**Interfaces:**
- Consumes: `CLAUDE_SKILLS_DIR`, `assert_contains`, `assert_eq`, `setup_fixture` from Task 1; `RC` and the wrapped `remove_install ... || { ... }` call sites in `install_skill` from Task 2, one of which Step 6 quotes verbatim as its old text.
- Produces: `--check` flag, `CHECK=0|1`, function `check_skill <skill_name>` which prints one line per drifted path and returns `0` when clean, `1` when drifted, and function `top_up_symlinks <source_dir> <target_dir>`, the guarded walker used by Step 6's no-force top-up.

**Why this matters:** the RepoSkills install went four months with four missing files, including all three templates that Phase 2 reads. RepoSkills ships drift detection for the repos it documents and had none for itself.

- [ ] **Step 1: Write the failing test**

Append to `tests/install.test.sh`, before the summary line:

```sh
test_check_passes_on_clean_install() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep >/dev/null
    if run_install "$home" --check Sleep >/dev/null; then
        pass "--check exits 0 on a clean install"
    else
        fail "--check exits 0 on a clean install" "non-zero exit"
    fi
    rm -rf "$home"
}

test_check_detects_missing_file() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep >/dev/null
    # Simulate the April failure: a file exists in stow but was never linked.
    victim="$(cd "$target/Sleep" && find . -type l | sed 's|^\./||' | head -1)"
    rm -f "$target/Sleep/$victim"

    out="$(run_install "$home" --check Sleep)" && rc=0 || rc=1

    assert_eq "--check exits 1 when a file is missing" "1" "$rc"
    assert_contains "--check names the missing file" "$victim" "$out"
    rm -rf "$home"
}

test_check_reports_not_installed() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    out="$(run_install "$home" --check Sleep)" && rc=0 || rc=1
    assert_eq "--check exits 1 when the skill is absent" "1" "$rc"
    assert_contains "--check says not installed" "not installed" "$out"
    rm -rf "$home"
}

test_check_detects_orphaned_symlink() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep >/dev/null
    # Simulate a file renamed in stow/: the target keeps a link to nothing.
    ln -sf "$REPO_ROOT/stow/Sleep/GONE.md" "$target/Sleep/GONE.md"

    out="$(run_install "$home" --check Sleep)" && rc=0 || rc=1

    assert_eq "--check exits 1 on a dangling symlink" "1" "$rc"
    assert_contains "--check reports it as ORPHANED" "ORPHANED" "$out"
    rm -rf "$home"
}

test_check_does_not_create_the_target_dir() {
    home="$(mktemp -d)"
    # No setup_fixture here: the point is that no skills directory exists.
    # --check is read-only by contract, so it must not manufacture the
    # directory it is inspecting the way an install does.
    run_install "$home" --check Sleep >/dev/null || true
    if [ -d "$home/.claude/skills" ]; then
        fail "--check leaves a missing target dir missing" \
             "it created $home/.claude/skills"
    else
        pass "--check leaves a missing target dir missing"
    fi
    rm -rf "$home"
}

test_check_passes_on_clean_install
test_check_detects_missing_file
test_check_reports_not_installed
test_check_detects_orphaned_symlink
test_check_does_not_create_the_target_dir
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `sh tests/install.test.sh`

Expected: red overall, but not uniformly, and the detail matters so you do not mistake a pass for a
missing test. There are five tests here. `--check` is an unknown option, so `die` exits 1 in every
case. That means:

- `--check exits 0 on a clean install` FAILS.
- The three `assert_contains` message checks FAIL, since `die` prints `unknown option: --check`
  rather than any of `MISSING`, `not installed` or `ORPHANED`.
- The two exit-code assertions (`--check exits 1 when a file is missing`, `--check exits 1 when the
  skill is absent`) **pass**, coincidentally: `die` also exits 1. A coincidental pass is not
  evidence of anything.
- `--check leaves a missing target dir missing` also **passes**, coincidentally: `die` rejects the
  unknown flag during argument parsing, before the `mkdir -p "$TARGET_DIR"` at install.sh:315 can
  run. It earns its keep at Step 4: implement `--check` but leave that `mkdir -p` where it is, and
  this goes red, because the mkdir sits above the dispatch block and runs on every invocation.

- [ ] **Step 3: Write the minimal implementation**

Add `CHECK=0` beside the other initialisers, and the case arm:

```sh
        --check) CHECK=1 ;;
```

Add `check_skill` next to `install_skill`:

```sh
# Report drift between stow/<skill> and the installed copy.
# Prints one line per problem. Returns 0 when clean, 1 when drifted.
#
# Two latent divergences from the installer's walk, recorded so a future
# change does not trip over them: install_symlinks globs "$source_dir"/* and
# so skips dotfiles, while these loops use find and include them, so a dotfile
# added to stow/ would never install and would report MISSING forever; and a
# symlink in stow/ would be installed but never checked. Neither exists in
# stow/ today.
check_skill() {
    local skill_name="$1"
    local source_dir="$STOW_DIR/$skill_name"
    local skill_dir="$TARGET_DIR/$skill_name"

    [ -d "$source_dir" ] || die "Cannot find $source_dir"

    if [ ! -d "$skill_dir" ]; then
        printf "  %-20s not installed\n" "$skill_name"
        return 1
    fi

    local drifted=0
    local rel
    # Every file in stow/ must exist in the target. Each drifted path gets
    # exactly one report line, so this loop judges only symlinks and true
    # absences: a dangling symlink is loop 3's ORPHANED (test -e follows
    # links, so it looks absent here), and a regular file squatting on a stow
    # path is loop 2's UNMANAGED. Reporting those MISSING or STALE as well
    # would double-count them without changing the exit code.
    # shellcheck disable=SC2044,SC2086  # skill paths contain no whitespace
    for src in $(cd "$source_dir" && find . -type f | sed 's|^\./||'); do
        rel="$src"
        if [ -L "$skill_dir/$rel" ]; then
            if [ -e "$skill_dir/$rel" ] && [ ! "$skill_dir/$rel" -ef "$source_dir/$rel" ]; then
                printf "  %-20s STALE    %s\n" "$skill_name" "$rel"
                drifted=1
            fi
        elif [ ! -e "$skill_dir/$rel" ]; then
            printf "  %-20s MISSING  %s\n" "$skill_name" "$rel"
            drifted=1
        fi
    done

    # Anything in the target that is not a symlink is unmanaged content.
    # shellcheck disable=SC2044,SC2086  # skill paths contain no whitespace
    for extra in $(cd "$skill_dir" && find . -type f ! -name '.DS_Store' | sed 's|^\./||'); do
        printf "  %-20s UNMANAGED %s\n" "$skill_name" "$extra"
        drifted=1
    done

    # A file removed or renamed in stow/ leaves a dangling symlink here.
    # Neither loop above reports it: loop 1 deliberately leaves dangling links
    # to this one, and a broken symlink is not -type f, so loop 2 skips it
    # too. Without this, --check certifies a rotten install clean.
    # shellcheck disable=SC2044,SC2086
    for link in $(cd "$skill_dir" && find . -type l | sed 's|^\./||'); do
        if [ ! -e "$skill_dir/$link" ]; then
            printf "  %-20s ORPHANED %s\n" "$skill_name" "$link"
            drifted=1
        elif [ ! -e "$source_dir/$link" ]; then
            printf "  %-20s FOREIGN  %s\n" "$skill_name" "$link"
            drifted=1
        fi
    done

    [ "$drifted" = 0 ] && printf "  %-20s ok\n" "$skill_name"
    return "$drifted"
}
```

Move the unconditional `mkdir -p "$TARGET_DIR"` (install.sh:315) into the install branch. It sits
above the dispatch block, so today it runs on every invocation, and a `--check` that manufactures
the very directory it is inspecting is a mutation, however small; the read-only contract is what
lets `--check` run safely anywhere, including CI. Uninstall does not need it either: an absent
target just means every skill reports "not installed". Delete line 315 and add the mkdir inside
the else branch, directly after its printf:

```sh
else
    printf "Installing skills to %s\n" "$TARGET_DIR"
    mkdir -p "$TARGET_DIR"
```

Under `set -e` a failing `mkdir -p` still aborts the run exactly as it does today; only the set of
invocations that reach it shrinks.

In the final dispatch block, handle `--check` before the install/uninstall branches:

```sh
if [ "$CHECK" = 1 ]; then
    printf "Checking skills in %s\n" "$TARGET_DIR"
    check_rc=0
    for skill in $SKILLS; do
        check_skill "$skill" || check_rc=1
    done
    exit "$check_rc"
fi
```

Add to the usage heredoc, under `Options:`:

```
  --check       Report drift between stow/ and the installed skills; exit 1 if any
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `sh tests/install.test.sh`

Expected: `0 failed`

- [ ] **Step 5: Run --check against the real installation**

```bash
sh install.sh --check
```

Expected: every skill reports `ok`. If any report `MISSING`, that is real drift the new tool found.

**Fix it with `--force`, not a plain install, and note why the plain install fails.** This is worth
understanding because it is the actual April failure. `is_current_install` (`install.sh:63-69`) tests
only whether `SKILL.md` resolves to the same inode as its source. If it does, and `--force` is not
set, `install_skill` prints "already installed, skipping" and returns (`install.sh:106-110`) without
ever calling `install_symlinks`. So a skill missing four of its files still looks installed, and a
plain `sh install.sh RepoSkills` in April would have reported success and changed nothing. Only
`--force` would have repaired it, by removing and relinking.

- [ ] **Step 6: Make a plain install top up missing links, without linking over user files**

`--check` now detects the April failure, but the natural fix for it silently does nothing, which is
half a tool. So the no-force skip becomes a top-up. What the top-up must NOT be is a bare
`install_symlinks` call: that function is `ln -sf` over a directory tree (install.sh:96), and BSD
`ln -sf` silently unlinks a regular file at the destination and replaces it with a symlink,
verified on this machine. On the `--force` and fresh-install paths that is fine, because
`remove_install` runs first and Task 2's guard has certified the directory free of user files. On
this path `remove_install` never runs, so nothing has certified anything: a user who detached one
symlink to keep an edited copy of their own (`rm` the link, `cp` the stow file into place, edit it)
would have that copy destroyed by a plain, flagless `./install.sh`. That is the same incident class
as the 2026-08-27 `IMPROVEMENTS.md` loss, reachable without `--force`, which Task 2 closes and an
unguarded top-up would reopen. A user file sitting where `stow/` has a directory is worse still:
`mkdir -p` fails on it, and since `install_skill` is called bare in the `for` loop
(install.sh:335-337), `set -e` aborts the entire run mid-loop, abandoning every skill after it.

So the top-up gets its own walker with the same predicate as Task 2's guard: a non-symlink at a
stow path is human-authored, so it is reported and skipped, never overwritten. A separate function
rather than a mode parameter on `install_symlinks` keeps the proven `--force` and fresh-install
paths byte-identical, which the Global Constraints require, and spares the shared function a
second responsibility it would carry on every call. Add it directly below `install_symlinks`:

```sh
# Top-up variant of install_symlinks for the no-force path on an existing
# install, where remove_install has NOT cleared the target. Same predicate as
# the remove_install guard: a non-symlink at a stow path is human-authored,
# so it is reported and skipped, never overwritten. ln -sf runs only where
# the destination is absent or already a symlink. Returns 0 when fully
# linked, 1 when anything was protected or failed.
top_up_symlinks() {
    local source_dir="$1"
    local target_dir="$2"
    local topup_rc=0

    for item in "$source_dir"/*; do
        [ -e "$item" ] || continue
        local name
        name="$(basename "$item")"

        if [ -d "$item" ]; then
            # Anything here that is not a real directory is protected: a
            # regular file would make mkdir -p fail, and a symlink (which the
            # installer never creates at directory positions) would let the
            # recursion plant links inside whatever it points at.
            if [ -L "$target_dir/$name" ] || { [ -e "$target_dir/$name" ] && [ ! -d "$target_dir/$name" ]; }; then
                printf "    protected: %s is not a directory, not linking under it\n" "$target_dir/$name" >&2
                topup_rc=1
                continue
            fi
            mkdir -p "$target_dir/$name" || return 1
            top_up_symlinks "$item" "$target_dir/$name" || topup_rc=1
        else
            if [ -e "$target_dir/$name" ] && [ ! -L "$target_dir/$name" ]; then
                printf "    protected: %s was not written by the installer, not overwriting\n" "$target_dir/$name" >&2
                topup_rc=1
                continue
            fi
            ln -sf "$item" "$target_dir/$name" || return 1
        fi
    done
    return "$topup_rc"
}
```

The file-position guard passes symlinks through on purpose: a dangling or stale symlink is
installer debris, and relinking it is the whole point of the top-up. Trace the failure paths
through `set -e` before trusting them: this function is only ever invoked as an `if` condition,
which POSIX-suppresses `set -e` for the entire body, the same rule Task 2 documents for
`remove_install`. That suppression is why `mkdir -p` and `ln -sf` carry explicit `|| return 1`;
unchecked, an unexpected failure (permissions, disk full) would be silently swallowed. The
`return 1` lands in the caller's else branch below, which records `RC=1` and returns, so the `for`
loop moves on to the next skill instead of aborting the run.

Then, in `install_skill`, replace the early return. The old text below is the post-Task-2 form:
Task 2 Step 3 wrapped this `remove_install` call site along with the other two in `install_skill`,
so match against this, not against the two-line `uninstall_skill` form.

```sh
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
    elif
```

with:

```sh
    if is_current_install "$skill_name"; then
        if [ "$FORCE" = 0 ]; then
            # SKILL.md matching does not mean every file is linked: that is
            # exactly how four RepoSkills files went missing for four months.
            # Top up rather than skipping, but never via raw install_symlinks:
            # remove_install has not cleared this directory, so a user file
            # can sit at a stow path and ln -sf would destroy it.
            if top_up_symlinks "$source_dir" "$skill_dir"; then
                printf "  %-20s up to date\n" "$skill_name"
            else
                printf "  %-20s topped up (protected files left in place)\n" "$skill_name"
                RC=1
            fi
            return 0
        fi
        remove_install "$skill_name" || {
            printf "  %-20s skipped (protected files present)\n" "$skill_name"
            RC=1
            return 0
        }
    elif
```

`RC=1` here surfaces through the `exit "$RC"` Task 2 added, so a flagless install that had to skip
a protected file exits non-zero, consistent with the `--force` skip.

Add three tests. Append to `tests/install.test.sh`, before the summary line, and note the
invocation lines at the end of the block: a defined but never-called test runs nothing and turns
the `0 failed` gate vacuous.

```sh
test_plain_install_tops_up_missing_files() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" RepoSkills >/dev/null
    victim="$(cd "$target/RepoSkills" && find . -type l ! -name 'SKILL.md' | sed 's|^\./||' | head -1)"
    rm -f "$target/RepoSkills/$victim"

    run_install "$home" RepoSkills >/dev/null

    if [ -e "$target/RepoSkills/$victim" ]; then
        pass "plain install restores a missing link"
    else
        fail "plain install restores a missing link" "$victim still absent after reinstall"
    fi
    rm -rf "$home"
}

test_plain_install_never_overwrites_a_user_file() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep >/dev/null
    # A user detaches one link to keep an edited copy of their own. SKILL.md
    # stays linked, so is_current_install still passes and the top-up runs.
    victim="$(cd "$target/Sleep" && find . -type l ! -name 'SKILL.md' | sed 's|^\./||' | head -1)"
    rm -f "$target/Sleep/$victim"
    printf "my precious edits\n" > "$target/Sleep/$victim"

    run_install "$home" Sleep >/dev/null || true

    if [ ! -L "$target/Sleep/$victim" ] && \
       [ "$(cat "$target/Sleep/$victim")" = "my precious edits" ]; then
        pass "flagless install leaves a detached user copy intact"
    else
        fail "flagless install leaves a detached user copy intact" \
             "$victim was linked over by the top-up"
    fi
    rm -rf "$home"
}

test_topup_collision_does_not_abort_the_run() {
    target="$(setup_fixture)"; home="$(dirname "$(dirname "$target")")"
    run_install "$home" Sleep RepoSkills >/dev/null
    # A user file where stow/Sleep has the Tools directory. Unguarded, the
    # top-up's mkdir -p fails on it and set -e kills the whole run mid-loop,
    # abandoning RepoSkills, whose missing link must still be restored.
    rm -rf "$target/Sleep/Tools"
    printf "user file\n" > "$target/Sleep/Tools"
    victim="$(cd "$target/RepoSkills" && find . -type l ! -name 'SKILL.md' | sed 's|^\./||' | head -1)"
    rm -f "$target/RepoSkills/$victim"

    run_install "$home" Sleep RepoSkills >/dev/null || true

    if [ -e "$target/RepoSkills/$victim" ]; then
        pass "a top-up collision does not abort later skills"
    else
        fail "a top-up collision does not abort later skills" \
             "RepoSkills was never topped up, so the run died on Sleep"
    fi
    if [ -f "$target/Sleep/Tools" ] && [ ! -L "$target/Sleep/Tools" ]; then
        pass "the colliding user file survives"
    else
        fail "the colliding user file survives" "Sleep/Tools was replaced"
    fi
    rm -rf "$home"
}

test_plain_install_tops_up_missing_files
test_plain_install_never_overwrites_a_user_file
test_topup_collision_does_not_abort_the_run
```

The collision test hardcodes `Tools` where the others discover their victim, because it needs a
path that is a directory in `stow/`, and `stow/Sleep/Tools` is the only one Sleep has; a discovered
path could silently stop being a directory in a future stow layout and the test would prove
nothing.

Run all three before the change. The two restore assertions fail red: "already installed,
skipping" leaves both gaps unrepaired. The three protection assertions (the detached copy, the
colliding file, and test 2 as a whole) pass against the pre-change file, coincidentally, because a
skip touches nothing; they exist to pin the guard against the naive form of this step, which no
earlier test catches. To watch them bite, substitute a bare `install_symlinks "$source_dir"
"$skill_dir"` for the guarded call and rerun: the user file dies and the collision aborts the run
mid-loop, taking the second restore assertion with it. Then implement the guarded form above and
confirm `0 failed`. Note this changes the "already installed" message to "up to date", which the
earlier tests do not assert on.

- [ ] **Step 7: Lint**

Run: `shellcheck install.sh tests/install.test.sh`

Note: `check_skill` uses unquoted `$(...)` in `for` loops to word-split on newlines, which shellcheck flags as `SC2044`/`SC2086`. This is intentional here because skill paths contain no whitespace. Add `# shellcheck disable=SC2044,SC2086` immediately above each loop with a one-line comment saying why, rather than silencing the whole file.

- [ ] **Step 8: Commit**

```bash
git add install.sh tests/install.test.sh
git commit -m "add --check mode, and make a plain install top up missing links

The RepoSkills install went four months missing four files, including
all three templates Phase 2 reads, because install.sh symlinks per file
and had not been re-run since new files landed. Nothing detected it.

--check reports MISSING, STALE, UNMANAGED, ORPHANED and FOREIGN per skill and
exits 1 on drift, so it works as a CI or pre-commit gate.

Detection alone was half a fix: is_current_install only tests SKILL.md, so a
plain install reported success and changed nothing on a skill missing files.
It now tops up instead of skipping. The top-up never links over a non-symlink:
remove_install has not cleared the directory on that path, so a regular file
there is human-authored, exactly the class of file the previous commit
protects. Protected paths are reported, skipped, and the run exits non-zero."
```

---

### Task 4: Document both flags

**Files:**
- Modify: `README.md`
- Test: none. Documentation only, verified by reading.

**Interfaces:**
- Consumes: `--check` and `--allow-destroy` from Tasks 2 and 3.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Read the current README section**

Run: `sed -n '44,56p' README.md`

The options are documented as a fenced code block of example invocations at lines 48 to 52, each with a trailing `#` comment aligned in a column. Match that format exactly. Do not convert it to a bullet list and do not restructure the file.

- [ ] **Step 2: Add the two new examples to that code block**

Append these two lines inside the existing fenced block, after the `--uninstall llm-docs` line, keeping the comment column aligned with its neighbours:

```
./install.sh --check                # Report drift between stow/ and installed skills
./install.sh --force --allow-destroy # Overwrite, setting non-stow files aside, not deleting
```

- [ ] **Step 3: Add the explanatory prose below the block**

Immediately after the closing fence, add two short paragraphs. These earn their place because neither flag's purpose is obvious from its name:

```markdown
`--check` exists because `install.sh` symlinks per file rather than linking the skill
directory as a whole. A skill that gains a file after its last install silently lacks that
file until the installer runs again, with nothing to signal it. `--check` reports `MISSING`,
`STALE`, `UNMANAGED`, `ORPHANED` and `FOREIGN` per file and exits non-zero, so it works as a CI
or pre-commit gate.

`--allow-destroy` is the opt-in for setting aside, rather than deleting, files in the
target that did not come from `stow/`: it moves them to a temporary directory and prints
the path, which is worth saving if the files matter. The installer only ever writes
symlinks and directories, so any other regular file inside an installed skill (aside from
`.DS_Store`) was written by a human and cannot be regenerated. Without this flag the
installer refuses to delete them: it names the files, skips that skill, carries on with
the rest, and exits non-zero at the end.
```

- [ ] **Step 4: Verify the rendered result**

Run: `sed -n '44,72p' README.md`

Expected: the two new example lines sit inside the original fenced block with the comment column aligned, the fence closes once, and the two prose paragraphs follow it. No duplicated heading, no second code fence.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "document install.sh --check and --allow-destroy"
```

---

## Review amendments

An independent review of this plan (2026-09-02, every finding verified against the file and against
`sh` behaviour on this machine before being acted on) was applied in place. In the style of the
spec's section 11:

| Finding | Resolution |
|---|---|
| **C1 (critical).** Task 3's top-up called `install_symlinks` unguarded on the no-force path, where `remove_install` never runs. BSD `ln -sf` silently replaces a regular file, so a flagless install would destroy a user's detached edited copy: the same incident class Task 2 closes, reopened without even `--force`. A user file where `stow/` has a directory was worse: `mkdir -p` fails and `set -e` aborts the whole run mid-loop | Step 6 now adds `top_up_symlinks`, which links only where the destination is absent or already a symlink, reports protected paths, sets `RC=1` and continues. The `--force` and fresh-install paths keep raw `install_symlinks`, correct there because `remove_install` has certified the directory. Two tests pin it: a detached user copy survives a flagless install, and a directory collision does not abort later skills |
| **M1 (major).** Step 6's replace-this snippet showed the two-line `uninstall_skill` form of the `remove_install` call, but Task 2 Step 3 leaves the four-line form at every `install_skill` call site, so an exact-match executor would find nothing and stall or improvise | Step 6's old text now quotes the post-Task-2 four-line form, with a note naming which task shaped it |
| **M2 (major).** `--check` mutated: the unconditional `mkdir -p "$TARGET_DIR"` at install.sh:315 sits above the dispatch block, so a read-only check created `~/.claude/skills` on a machine without one | Task 3 Step 3 moves the mkdir into the install branch, the only branch that needs it. A test asserts `--check` against a non-existent target leaves it non-existent |
| **m1 (minor).** Task 2 Step 5 prefixed `CLAUDE_SKILLS_DIR` to a single command, scoping it to that command, so the `ls` on the next line expanded it to nothing and looked under `/RepoSkills/` | The variable is now exported on its own line, with the reason stated. "the tracked `IMPROVEMENTS.md`" in the same step also lost the word "tracked", since the paragraph goes on to say tracked-ness is irrelevant |
| **m2 (minor).** Task 4's README prose said `--check` reports three categories; the implementation and Task 3's commit message have five | The prose now lists all five |
| **m3 (minor).** Two double-reports in `check_skill`: a dangling symlink at a stow path was both MISSING (loop 1) and ORPHANED (loop 3); a user file at a stow path was both STALE and UNMANAGED. Exit codes unaffected, but log noise | Loop 1 now judges only symlinks and true absences: dangling links are left to ORPHANED, non-symlinks to UNMANAGED, so each drifted path gets one line. A header comment also records two latent divergences from the installer's walk (dotfiles and stow-side symlinks), neither present in `stow/` today |
| **m7 (minor).** Task 3's Consumes line omitted Task 2's `RC` and the wrapped `remove_install` call sites, which its own Step 6 old text depends on | The Interfaces block now declares both, and Produces gains `top_up_symlinks` |
| **Found during amendment.** Step 6's test block defined its test but never invoked it, and gave no append location, unlike every other test block in this plan. A defined but never-called test runs nothing, so the "run it before the change" instruction would silently do nothing and the `0 failed` gate would pass vacuously | The block now ends with the three invocation lines and states where to append, and the step says why the invocations matter |
| **Found during execution.** Task 4 Step 3's prose said the installer "aborts" when it meets a protected file. It does not: `install_skill` prints the skip, sets `RC=1` and returns 0, the loop carries on with every remaining skill, and the script exits non-zero only at the end through `exit "$RC"`. A reader would expect one protected file to halt the whole install | Task 4 Step 3's paragraph now describes the real behaviour. The shipped README was corrected first, in its own commit |
| **Found during execution.** Task 2 Step 3's usage line and Task 4 Step 2's example comment both described `--allow-destroy` as deleting. It does not delete: it moves the files to a `mktemp -d` and prints the path. Documenting a recovery affordance as destruction defeats it, since a user who missed the scrollback is told the file is gone when it is still sitting under `$TMPDIR` | Both lines and Task 4 Step 3's paragraph now say the files are moved aside and the path is printed. The paragraph also notes the `.DS_Store` exclusion the guard makes |
| **Found during execution.** `check_skill`'s first loop walked `stow/` with `find . -type f`, which includes dotfiles, while `install_symlinks` globs and skips them. A Finder-dropped `.DS_Store` was therefore reported `MISSING` on every `--check` with no invocation able to clear it, which would make the CI gate this plan advertises a permanent red | The first loop now carries `! -name '.DS_Store'`, matching the two exclusions the file already had, and the header comment describes only the divergence that remains |
| **Found during execution.** Nothing asserted the install-path exit code, so the whole `RC` accumulator this plan introduced was untested while the README promised a refusing run exits non-zero | A test now runs `--force` against a protected skill and asserts the process exit code is 1 |
| **Found during execution.** `read -r answer` at the overwrite prompt returns non-zero at EOF, so under `set -e` a non-interactive run died mid-loop and abandoned every skill after the one that prompted. Pre-existing, but it holed the loop-continuation property this plan otherwise guarantees, on exactly the non-interactive path the new `--check` invites | `read -r answer \|\| answer=n` treats EOF as a decline. A test asserts a second skill still installs after a declined prompt |

---

## Self-Review

**Spec coverage.** This plan implements section 7 (Housekeeping) and stage 1 of section 8. Both recommendations in section 7 are covered: `--check` in Task 3, and the refusal to delete regular files in Task 2. Sections 3, 4, 5, 6 and 9 of the spec are out of scope for this plan and belong to the sibling plans listed below.

**Placeholder scan.** No TBD, TODO, or "add error handling". Every code step carries the actual code. The one place a value is not given literally is the `victim` in Task 3, selected at test time via `find . -type l | head -1` so the test does not hardcode a filename that may change, and so it can never pick a directory.

**Type consistency.** `ALLOW_DESTROY` and `RC` are introduced in Task 2; `RC` is also read by `uninstall_skill` and by the final `exit`. `CHECK`, `check_skill` and `top_up_symlinks` are introduced in Task 3 and read only there; the top-up caller in `install_skill` also writes `RC`, which Task 2 introduced and the final `exit` reads. `CLAUDE_SKILLS_DIR`, `setup_fixture` and `run_install` are introduced in Task 1 and used by every later test, and every test invokes the installer through `run_install` so `HOME` is always sandboxed. `assert_eq`, `assert_contains`, `pass` and `fail` are defined in Task 1 and used unchanged.

**No test-count gates.** Every step gates on `0 failed` rather than a total, because the runner counts assertions and the total shifts whenever an assert is added or split.

---

## Sibling plans still to be written

Re-cut against the spec's section 8 after it split stage 2 into expand and contract. An earlier
version of this table predated that split and listed the drift and routing retooling as a separate
plan, which contradicts the spec: 2a bundles that retooling *with* README generation deliberately,
so that no repo is ever in a broken intermediate state.

| Plan | Spec sections | Stage | Depends on |
|---|---|---|---|
| Expand: READMEs alongside `modules/`, dual-shape drift and routing, re-run surface | 3, 3.1, 3.5, 3.6, 4, 5 | 2a | This plan |
| Contract: stop generating module skills, run the harvest, remove the `modules/` contracts | 3.4, 3.5 | 2b | Expand |
| Phase-4 checks and phase-1 questions | 6.5 items 2, 3, 4, 5, 12, 16 | 3 | Contract |
| Remaining items | items 6, 8, 17 | 4 | Contract |
| The three added README sections | 5.1 | 5 | Contract |

Stages 3 and 4 are independent of each other and can be planned in parallel once 2b lands.
