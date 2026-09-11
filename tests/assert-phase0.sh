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

unit_has() {
    # unit_has <description> <unit-path> <line-regex>
    # Passes when the Unit List block whose "- path:" equals <unit-path>
    # contains a line matching <line-regex>. Exact path match, so
    # services/orders never swallows services/orders/pricing.
    if awk -v p="$2" -v pat="$3" '
        /^- path:/ { cur=$0; sub(/^- path:[ \t]*/, "", cur); sub(/[ \t]+$/, "", cur); inblock=(cur==p); next }
        inblock && $0 ~ pat { found=1 }
        END { exit found ? 0 : 1 }
    ' "$STATE"; then
        printf "  ok   %s\n" "$1"
    else
        printf "  FAIL %s\n       unit [%s] has no line matching [%s]\n" "$1" "$2" "$3"
        FAILED=1
    fi
}

need     "Unit List section exists"                       "^## Unit List"
unit_has "the workspace root is excluded, never a create" "."                       "action:[ \t]*excluded"
unit_has "orders is a create, ungated"                    "services/orders"         "action:[ \t]*create[ \t]*$"
unit_has "billing is an update, because it has a README"  "services/billing"        "action:[ \t]*update"
unit_has "notifications is flagged miscased"              "services/notifications"  "readme:[ \t]*exists-miscased"
unit_has "notifications is still an update"               "services/notifications"  "action:[ \t]*update"
unit_has "utils is non-deployable"                        "packages/utils"          "deployable:[ \t]*no"
unit_has "the python project is discovered despite the workspaces globs" "analytics/pipeline" "action:[ \t]*create[ \t]*$"
unit_has "reporting is gated pending confirmation"        "src/reporting"           "action:[ \t]*create-pending-confirmation"
unit_has "an entry point alone never earns ungated creation" "src/ingest"           "action:[ \t]*create-pending-confirmation"
unit_has "pricing records its parent"                     "services/orders/pricing" "nested-under:[ \t]*services/orders"
unit_has "spike is excluded despite its Strong manifest"  "experiments/spike"       "action:[ \t]*excluded"
unit_has "spike's README is recorded, not mistaken for an update" "experiments/spike" "readme:[ \t]*exists"

printf "\n%s\n" "$([ "$FAILED" -eq 0 ] && echo PASS || echo FAIL)"
[ "$FAILED" -eq 0 ]
