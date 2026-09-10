# Discovery fixture

`make-fixture-repo.sh <dir>` builds a deterministic repo for testing RepoSkills
discovery. Each shape exists to pin down one behaviour. Do not add shapes without
adding the behaviour they test, and do not remove one without removing its assertion.

| Path | Signals | Must be treated as |
|---|---|---|
| `.` (workspace root) | Strong manifest, no README | **Never a unit.** The workspace root is out of the gate's scope by rule, however strong its signals |
| `services/orders` | Strong manifest, Strong Dockerfile, Medium CI | Unit. Deployable. Full skeleton. Create README |
| `services/billing` | Strong manifest, Strong Dockerfile | Unit. Deployable. **Has a README**, so update, never create |
| `services/notifications` | Strong manifest, Strong Dockerfile | Unit. **Has `readme.md`, miscased**: recorded as `exists-miscased`, `update`. The rename belongs to the writing phase |
| `services/orders/pricing` | Strong manifest | Unit, **nested inside `services/orders`**. Both get a README. Parent freshness must subtract this path |
| `packages/utils` | Strong manifest, no Dockerfile | Unit. Non-deployable. **Slim skeleton** |
| `analytics/pipeline` | Strong manifest (`pyproject.toml`), Medium CI | Unit, invisible to the `workspaces` globs. **The counterexample** that proves the visible query is a subset |
| `src/reporting` | Medium Domain (own imported types, own tables) plus Medium Deployment (own CI workflow): two Medium **types** | Unit candidate, **Medium-only, so gated**: no README without human confirmation |
| `src/ingest` | Strong Service (own entry point, own port binding), no manifest, no Dockerfile | Boundary, but **gated**: an entry point alone never earns ungated creation |
| `experiments/spike` | Strong manifest, but excluded from `workspaces`; has a README | **Not a unit.** Exclusion beats the README; the README is its self-documentation |
| `node_modules/left-pad` | Manifest | **Never a unit.** Exclusion list |
