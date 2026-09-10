#!/bin/sh
# Asserts on state.md after a Phase 0 run against the fixture.
# Usage: assert-phase0.sh <path-to-state.md>
set -u
STATE="${1:?usage: assert-phase0.sh <state.md>}"
FAILED=0

need() {
    # need <description> <grep-pattern>
    if grep -qi -- "$2" "$STATE"; then
        printf "  ok   %s\n" "$1"
    else
        printf "  FAIL %s\n       no match for [%s]\n" "$1" "$2"
        FAILED=1
    fi
}
absent() {
    if grep -qi -- "$2" "$STATE"; then
        printf "  FAIL %s\n       unexpected match for [%s]\n" "$1" "$2"
        FAILED=1
    else
        printf "  ok   %s\n" "$1"
    fi
}

need "Project System section exists"        "^## Project System"
need "enumeration query recorded"           "enumeration-query:"
need "detail query recorded"                "detail-query:"
need "deployability predicate recorded"     "deployability-predicate:"
need "exclusions recorded"                  "exclusions:"
need "authoritative source recorded"        "authoritative-source:"
need "the plausible-subset counterexample is recorded on the authoritative-source line" "authoritative-source:.*analytics/pipeline"
need "workspace globs identified as the enumeration source" "workspaces"
need "the excluded spike is named as an exclusion" "experiments/spike"
absent "node_modules never appears as a unit" "node_modules/left-pad"

printf "\n%s\n" "$([ "$FAILED" -eq 0 ] && echo PASS || echo FAIL)"
[ "$FAILED" -eq 0 ]
