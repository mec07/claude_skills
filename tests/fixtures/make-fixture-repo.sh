#!/bin/sh
# Builds a deterministic fixture repo for RepoSkills discovery tests.
# Usage: make-fixture-repo.sh <target-dir>   (echoes the created path)
set -eu

[ $# -eq 1 ] || { echo "usage: $0 <target-dir>" >&2; exit 1; }
ROOT="$1"
mkdir -p "$ROOT"
cd "$ROOT"

# --- deployable service: Strong (manifest) + Strong (Dockerfile) + Medium (CI) ---
mkdir -p services/orders/src
cat > services/orders/package.json <<'EOF'
{ "name": "@fixture/orders", "version": "1.0.0", "scripts": { "dev": "node src/index.js" } }
EOF
printf 'FROM node:20\n' > services/orders/Dockerfile
printf 'console.log("orders");\n' > services/orders/src/index.js
mkdir -p .github/workflows
printf 'name: orders\non: push\n' > .github/workflows/orders.yml

# --- deployable service WITH a pre-existing sparse README: the update path ---
mkdir -p services/billing/src
cat > services/billing/package.json <<'EOF'
{ "name": "@fixture/billing", "version": "1.0.0" }
EOF
printf 'FROM node:20\n' > services/billing/Dockerfile
printf 'console.log("billing");\n' > services/billing/src/index.js
cat > services/billing/README.md <<'EOF'
# billing

Handles invoicing. Talks to the payments provider; retries are not idempotent.
EOF

# --- nested package INSIDE a deployable service: the nesting case.
#     NOT under vendor/: that directory is on the never-browse exclusion lists
#     (phase-0:60, orchestration:370), so a fixture there would be invisible
#     to the pipeline by its own rules. ---
mkdir -p services/orders/pricing
cat > services/orders/pricing/package.json <<'EOF'
{ "name": "@fixture/pricing", "version": "1.0.0" }
EOF
printf 'module.exports = {};\n' > services/orders/pricing/index.js

# --- non-deployable library: Strong (manifest), no Dockerfile: slim skeleton ---
mkdir -p packages/utils/src
cat > packages/utils/package.json <<'EOF'
{ "name": "@fixture/utils", "version": "1.0.0" }
EOF
printf 'export const noop = () => {};\n' > packages/utils/src/index.js

# --- Medium-only boundary: Domain (own types imported elsewhere + own tables,
#     one signal TYPE) + Deployment (own CI workflow, a second TYPE).
#     No manifest, no Dockerfile, no entry point: deliberately no barrel index.ts,
#     which an agent could read as a Strong entry-point signal.
#     MUST be gated behind confirmation. ---
mkdir -p src/reporting
printf 'export type Report = { id: string };\n' > src/reporting/types.ts
printf 'CREATE TABLE reports (id text primary key);\n' > src/reporting/schema.sql
printf 'name: reporting\non: push\n' > .github/workflows/reporting.yml
printf 'import type { Report } from "./reporting/types";\nexport const latest: Report = { id: "1" };\n' > src/app.ts

# --- entry-point-only boundary: a Strong Service signal (own entry point with a
#     port binding) but NO manifest and NO Dockerfile. Qualifies as a boundary,
#     but README creation is still gated: an internal library or sub-app inside
#     a single frontend has exactly this shape. ---
mkdir -p src/ingest
printf 'require("http").createServer(() => {}).listen(8081);\n' > src/ingest/main.js
printf 'module.exports.parse = (x) => x;\n' > src/ingest/parse.js

# --- miscased readme: the unit HAS a README and it must be renamed, not duplicated ---
mkdir -p services/notifications/src
cat > services/notifications/package.json <<'EOF'
{ "name": "@fixture/notifications", "version": "1.0.0" }
EOF
printf 'FROM node:20\n' > services/notifications/Dockerfile
printf 'console.log("notify");\n' > services/notifications/src/index.js
printf '# notifications\n\nSends email.\n' > services/notifications/readme.md

# --- looks like a unit but is deliberately excluded from the workspace.
#     It HAS a README, which is the dominant excluded shape in the reference
#     repo (the pnpm-workspace-excluded ingestion adapters all self-document),
#     so the exclusion-beats-README precedence is actually exercised. ---
mkdir -p experiments/spike/src
cat > experiments/spike/package.json <<'EOF'
{ "name": "@fixture/spike", "version": "0.0.0" }
EOF
printf 'console.log("spike");\n' > experiments/spike/src/index.js
printf '# spike\n\nExperimental. Deliberately outside the workspaces globs.\n' > experiments/spike/README.md

# --- a second project system whose visible query is a silent subset: a Python
#     project the npm workspaces globs cannot see, mirroring the real repo where
#     pnpm-workspace.yaml membership silently excludes every Python project.
#     This is the counterexample authoritative-source selection must record. ---
mkdir -p analytics/pipeline/pipeline
cat > analytics/pipeline/pyproject.toml <<'EOF'
[project]
name = "fixture-pipeline"
version = "1.0.0"
EOF
printf 'print("pipeline")\n' > analytics/pipeline/pipeline/__init__.py
printf 'name: pipeline\non: push\n' > .github/workflows/pipeline.yml

# --- the workspace definition. It excludes experiments/spike and cannot
#     express analytics/pipeline at all. The root itself has a Strong manifest
#     and no README: the gate must still never mark the workspace root create. ---
cat > package.json <<'EOF'
{ "name": "fixture-root", "private": true, "workspaces": ["services/*", "packages/*"] }
EOF

# --- a generated dir that must never be a unit ---
mkdir -p node_modules/left-pad
printf '{ "name": "left-pad" }\n' > node_modules/left-pad/package.json

git init -q .
git add -A
git -c user.email=fixture@example.com -c user.name=Fixture commit -q -m "fixture repo"
printf "%s" "$ROOT"
