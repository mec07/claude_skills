#!/bin/sh
# Asserts on the grammar artifacts generated into a target repo.
# Usage: assert-artifacts.sh <repo-root>
set -u
REPO="${1:?usage: assert-artifacts.sh <repo-root>}"
FAILED=0

file_has() {
    # file_has <description> <file> <grep-pattern>
    if [ -f "$REPO/$2" ] && grep -qi -- "$3" "$REPO/$2"; then
        printf "  ok   %s\n" "$1"
    else
        printf "  FAIL %s\n       %s missing or no match for [%s]\n" "$1" "$2" "$3"
        FAILED=1
    fi
}
exists() {
    if [ -f "$REPO/$2" ]; then printf "  ok   %s\n" "$1"
    else printf "  FAIL %s\n       %s does not exist\n" "$1" "$2"; FAILED=1; fi
}

exists   "conventions.md generated"          ".ai/skills/conventions.md"
file_has "records the precedence rule"       ".ai/skills/conventions.md" "code > README > conventions"
file_has "records the gated candidate's decision line" ".ai/skills/conventions.md" "src/reporting"
file_has "records declined candidates too"   ".ai/skills/conventions.md" "declined"
file_has "marks generated sections"          ".ai/skills/conventions.md" "provenance=generated"

printf "\n%s\n" "$([ "$FAILED" -eq 0 ] && echo PASS || echo FAIL)"
[ "$FAILED" -eq 0 ]
