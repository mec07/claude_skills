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

file_lacks() {
    # file_lacks <description> <file> <grep-pattern>
    # Passes when the file exists and nothing in it matches.
    if [ -f "$REPO/$2" ] && ! grep -qi -- "$3" "$REPO/$2"; then
        printf "  ok   %s\n" "$1"
    else
        printf "  FAIL %s\n       %s missing or has a match for [%s]\n" "$1" "$2" "$3"
        FAILED=1
    fi
}

exists     "readme-template.md generated"        ".ai/skills/readme-template.md"
file_has   "has a full skeleton"                 ".ai/skills/readme-template.md" "full skeleton"
file_has   "has a slim skeleton"                 ".ai/skills/readme-template.md" "slim skeleton"
file_has   "Agent Notes is last"                 ".ai/skills/readme-template.md" "Agent Notes"
file_has   "carries the include test"            ".ai/skills/readme-template.md" "10 seconds"
file_has   "environment variables are a pointer" ".ai/skills/readme-template.md" "\.env\.example\|declaring file"
file_has   "fallback section names used, since the fixture has no convention" ".ai/skills/readme-template.md" "## Monitoring"
file_lacks "deferred sections are not shipped"   ".ai/skills/readme-template.md" "Contracts owned"

exists   "navigate-unit generated"           ".ai/skills/tasks/navigate-unit.md"
file_has "has a USE WHEN line"               ".ai/skills/tasks/navigate-unit.md" "USE WHEN"
file_has "links the conventions doc"         ".ai/skills/tasks/navigate-unit.md" "conventions.md"
file_has "states precedence by reference"    ".ai/skills/tasks/navigate-unit.md" "conventions"
file_has "does not restate the layout"       ".ai/skills/tasks/navigate-unit.md" "procedure"

printf "\n%s\n" "$([ "$FAILED" -eq 0 ] && echo PASS || echo FAIL)"
[ "$FAILED" -eq 0 ]
