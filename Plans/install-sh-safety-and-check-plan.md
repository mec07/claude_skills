# install.sh Safety and Drift Check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop `install.sh` destroying files it did not create, and give it a `--check` mode that reports drift between `stow/` and the installed skills.

**Architecture:** Two surgical changes to the existing `install.sh`, plus a dependency-free test harness. `remove_install()` gains a guard that refuses to proceed when the target directory holds regular files (which are never installer-created, since the installer only writes symlinks and directories). A new `--check` mode walks the same source tree the installer walks and reports what is missing, stale, or extra. `TARGET_DIR` becomes overridable so tests never touch the real `~/.claude/skills`.

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

# Creates an isolated fake HOME-side install dir and echoes its path.
setup_fixture() {
    d="$(mktemp -d)"
    mkdir -p "$d/skills"
    printf "%s" "$d/skills"
}

# ---- tests ----

test_target_dir_is_overridable() {
    target="$(setup_fixture)"
    CLAUDE_SKILLS_DIR="$target" sh "$INSTALL" Sleep >/dev/null 2>&1
    if [ -e "$target/Sleep/SKILL.md" ]; then
        pass "CLAUDE_SKILLS_DIR redirects the install target"
    else
        fail "CLAUDE_SKILLS_DIR redirects the install target" "no Sleep/SKILL.md under $target"
    fi
    rm -rf "$(dirname "$target")"
}

test_does_not_touch_real_skills_dir() {
    target="$(setup_fixture)"
    before="$(ls "$HOME/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')"
    CLAUDE_SKILLS_DIR="$target" sh "$INSTALL" Sleep >/dev/null 2>&1
    after="$(ls "$HOME/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')"
    assert_eq "real skills dir is untouched" "$before" "$after"
    rm -rf "$(dirname "$target")"
}

test_target_dir_is_overridable
test_does_not_touch_real_skills_dir

printf "\n%s run, %s failed\n" "$TESTS_RUN" "$TESTS_FAILED"
[ "$TESTS_FAILED" -eq 0 ]
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `sh tests/install.test.sh`

Expected: FAIL on `CLAUDE_SKILLS_DIR redirects the install target`, because `TARGET_DIR` is currently hardcoded so `Sleep` installs into the real `~/.claude/skills` and nothing appears under the fixture.

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

Expected: `2 run, 0 failed`

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
test_refuses_to_destroy_real_files() {
    target="$(setup_fixture)"
    CLAUDE_SKILLS_DIR="$target" sh "$INSTALL" Sleep >/dev/null 2>&1
    printf "precious\n" > "$target/Sleep/NOTES.md"

    out="$(CLAUDE_SKILLS_DIR="$target" sh "$INSTALL" --force Sleep 2>&1)" || true

    if [ -f "$target/Sleep/NOTES.md" ]; then
        pass "real file survives --force"
    else
        fail "real file survives --force" "NOTES.md was destroyed"
    fi
    assert_contains "error names the file at risk" "NOTES.md" "$out"
    rm -rf "$(dirname "$target")"
}

test_allow_destroy_opts_back_in() {
    target="$(setup_fixture)"
    CLAUDE_SKILLS_DIR="$target" sh "$INSTALL" Sleep >/dev/null 2>&1
    printf "disposable\n" > "$target/Sleep/NOTES.md"

    CLAUDE_SKILLS_DIR="$target" sh "$INSTALL" --force --allow-destroy Sleep >/dev/null 2>&1

    if [ -f "$target/Sleep/NOTES.md" ]; then
        fail "--allow-destroy removes the file" "NOTES.md still present"
    else
        pass "--allow-destroy removes the file"
    fi
    rm -rf "$(dirname "$target")"
}

test_force_still_works_on_symlinks_only() {
    target="$(setup_fixture)"
    CLAUDE_SKILLS_DIR="$target" sh "$INSTALL" Sleep >/dev/null 2>&1
    out="$(CLAUDE_SKILLS_DIR="$target" sh "$INSTALL" --force Sleep 2>&1)"
    assert_contains "clean --force still reports installed" "installed" "$out"
    rm -rf "$(dirname "$target")"
}

test_refuses_to_destroy_real_files
test_allow_destroy_opts_back_in
test_force_still_works_on_symlinks_only
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `sh tests/install.test.sh`

Expected: `real file survives --force` FAILS (the file is destroyed), `error names the file at risk` FAILS (no such message), `--allow-destroy removes the file` FAILS (unknown option causes `die`).

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

    # install_symlinks only ever creates symlinks and directories, so any regular
    # file here was put there by a human and cannot be regenerated from stow/.
    local real_files
    real_files="$(find "$skill_dir" -type f 2>/dev/null || true)"

    if [ -n "$real_files" ] && [ "$ALLOW_DESTROY" = 0 ]; then
        printf "Error: %s contains files that did not come from %s:\n" \
            "$skill_dir" "$STOW_DIR" >&2
        printf "%s\n" "$real_files" | sed 's|^|  |' >&2
        printf "Refusing to delete them. Move or commit them first, or pass --allow-destroy.\n" >&2
        exit 1
    fi

    rm -rf "$skill_dir"
}
```

Add to the usage heredoc, under `Options:`:

```
  --allow-destroy  Permit removal of files in the target that did not come from stow/
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `sh tests/install.test.sh`

Expected: `7 run, 0 failed`

- [ ] **Step 5: Verify the real-world case by hand**

```bash
CLAUDE_SKILLS_DIR="$(mktemp -d)/skills" sh install.sh RepoSkills
```

Then confirm the tracked `IMPROVEMENTS.md` arrives as a symlink, not a copy:

```bash
ls -la "$CLAUDE_SKILLS_DIR/RepoSkills/IMPROVEMENTS.md"
```

Expected: a symlink into `stow/RepoSkills/`. Because it is now tracked in `stow/`, it is no longer a regular file in the target and so does not trip the new guard. This confirms the guard protects genuinely-untracked files without blocking normal installs.

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
- Consumes: `CLAUDE_SKILLS_DIR`, `assert_contains`, `assert_eq`, `setup_fixture` from Task 1.
- Produces: `--check` flag, `CHECK=0|1`, and function `check_skill <skill_name>` which prints one line per drifted path and returns `0` when clean, `1` when drifted.

**Why this matters:** the RepoSkills install went four months with four missing files, including all three templates that Phase 2 reads. RepoSkills ships drift detection for the repos it documents and had none for itself.

- [ ] **Step 1: Write the failing test**

Append to `tests/install.test.sh`, before the summary line:

```sh
test_check_passes_on_clean_install() {
    target="$(setup_fixture)"
    CLAUDE_SKILLS_DIR="$target" sh "$INSTALL" Sleep >/dev/null 2>&1
    if CLAUDE_SKILLS_DIR="$target" sh "$INSTALL" --check Sleep >/dev/null 2>&1; then
        pass "--check exits 0 on a clean install"
    else
        fail "--check exits 0 on a clean install" "non-zero exit"
    fi
    rm -rf "$(dirname "$target")"
}

test_check_detects_missing_file() {
    target="$(setup_fixture)"
    CLAUDE_SKILLS_DIR="$target" sh "$INSTALL" Sleep >/dev/null 2>&1
    # Simulate the April failure: a file exists in stow but was never linked.
    victim="$(ls "$target/Sleep" | head -1)"
    rm -f "$target/Sleep/$victim"

    out="$(CLAUDE_SKILLS_DIR="$target" sh "$INSTALL" --check Sleep 2>&1)" && rc=0 || rc=1

    assert_eq "--check exits 1 when a file is missing" "1" "$rc"
    assert_contains "--check names the missing file" "$victim" "$out"
    rm -rf "$(dirname "$target")"
}

test_check_reports_not_installed() {
    target="$(setup_fixture)"
    out="$(CLAUDE_SKILLS_DIR="$target" sh "$INSTALL" --check Sleep 2>&1)" && rc=0 || rc=1
    assert_eq "--check exits 1 when the skill is absent" "1" "$rc"
    assert_contains "--check says not installed" "not installed" "$out"
    rm -rf "$(dirname "$target")"
}

test_check_passes_on_clean_install
test_check_detects_missing_file
test_check_reports_not_installed
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `sh tests/install.test.sh`

Expected: all three FAIL. `--check` is an unknown option, so `die` reports `unknown option: --check` and exits 1 in every case, which makes `test_check_passes_on_clean_install` fail and makes the two `assert_contains` checks fail on message content.

- [ ] **Step 3: Write the minimal implementation**

Add `CHECK=0` beside the other initialisers, and the case arm:

```sh
        --check) CHECK=1 ;;
```

Add `check_skill` next to `install_skill`:

```sh
# Report drift between stow/<skill> and the installed copy.
# Prints one line per problem. Returns 0 when clean, 1 when drifted.
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
    # Every file in stow/ must exist in the target.
    for src in $(cd "$source_dir" && find . -type f | sed 's|^\./||'); do
        rel="$src"
        if [ ! -e "$skill_dir/$rel" ]; then
            printf "  %-20s MISSING  %s\n" "$skill_name" "$rel"
            drifted=1
        elif [ ! "$skill_dir/$rel" -ef "$source_dir/$rel" ]; then
            printf "  %-20s STALE    %s\n" "$skill_name" "$rel"
            drifted=1
        fi
    done

    # Anything in the target that is not a symlink is unmanaged content.
    for extra in $(find "$skill_dir" -type f 2>/dev/null); do
        printf "  %-20s UNMANAGED %s\n" "$skill_name" "$extra"
        drifted=1
    done

    [ "$drifted" = 0 ] && printf "  %-20s ok\n" "$skill_name"
    return "$drifted"
}
```

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

Expected: `13 run, 0 failed`

- [ ] **Step 5: Run --check against the real installation**

```bash
sh install.sh --check
```

Expected: every skill reports `ok`. If any report `MISSING`, that is real drift found by the new tool and should be fixed with `sh install.sh <skill>` before committing.

- [ ] **Step 6: Lint**

Run: `shellcheck install.sh tests/install.test.sh`

Note: `check_skill` uses unquoted `$(...)` in `for` loops to word-split on newlines, which shellcheck flags as `SC2044`/`SC2086`. This is intentional here because skill paths contain no whitespace. Add `# shellcheck disable=SC2044,SC2086` immediately above each loop with a one-line comment saying why, rather than silencing the whole file.

- [ ] **Step 7: Commit**

```bash
git add install.sh tests/install.test.sh
git commit -m "add --check mode reporting drift between stow/ and installed skills

The RepoSkills install went four months missing four files, including
all three templates Phase 2 reads, because install.sh symlinks per file
and had not been re-run since new files landed. Nothing detected it.

--check reports MISSING, STALE and UNMANAGED per skill and exits 1 on
drift, so it works as a CI or pre-commit gate."
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
./install.sh --force --allow-destroy # Overwrite, permitting deletion of non-stow files
```

- [ ] **Step 3: Add the explanatory prose below the block**

Immediately after the closing fence, add two short paragraphs. These earn their place because neither flag's purpose is obvious from its name:

```markdown
`--check` exists because `install.sh` symlinks per file rather than linking the skill
directory as a whole. A skill that gains a file after its last install silently lacks that
file until the installer runs again, with nothing to signal it. `--check` reports `MISSING`,
`STALE` and `UNMANAGED` per file and exits non-zero, so it works as a CI or pre-commit gate.

`--allow-destroy` is the opt-in for removing files in the target that did not come from
`stow/`. The installer only ever writes symlinks and directories, so any regular file inside
an installed skill was written by a human and cannot be regenerated. Without this flag the
installer aborts and names those files rather than deleting them.
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

## Self-Review

**Spec coverage.** This plan implements section 7 (Housekeeping) and stage 1 of section 8. Both recommendations in section 7 are covered: `--check` in Task 3, and the refusal to delete untracked files in Task 2. Sections 3, 4, 5, 6 and 9 of the spec are out of scope for this plan and belong to the four sibling plans listed below.

**Placeholder scan.** No TBD, TODO, or "add error handling". Every code step carries the actual code. The one place a value is not given literally is `victim="$(ls "$target/Sleep" | head -1)"` in Task 3, which is computed at test time on purpose so the test does not hardcode a filename that may change.

**Type consistency.** `ALLOW_DESTROY` is introduced in Task 2 and read only there. `CHECK` and `check_skill` are introduced in Task 3 and read only there. `CLAUDE_SKILLS_DIR` is introduced in Task 1 and used by every later test. `setup_fixture`, `assert_eq`, `assert_contains`, `pass` and `fail` are defined in Task 1 and used unchanged in Tasks 2 and 3. Test counts are cumulative and stated per task: 2, then 7, then 13.

---

## Sibling plans still to be written

This plan is one of six. The others, in the spec's stage order:

| Plan | Spec sections | Depends on |
|---|---|---|
| README output architecture | 3, 3.1, 3.2, 3.3, 4, 5 | nothing |
| Migration from `modules/` | 3.4 | README output architecture |
| Phase-4 checks and phase-1 questions | 6.5 items 2, 3, 4, 5, 12, 16 | nothing |
| Glue generation and drift tooling | 6.3, items 7, 9, 10 | README output architecture |
| Remaining items | items 6, 8, 17 | nothing |
