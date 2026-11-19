# ReviewPR — Companion Skills

ReviewPR is the **write** side of PR/MR work — it produces a pending/draft review. For **read-only** context, use `FetchPR`:

| Need | Skill | Why |
|------|-------|-----|
| Brief me on a PR/MR / pull metadata, CI, reviewer states | `FetchPR` (Full workflow) | Read-only, fast |
| Pull existing review comments / "what did X say" | `FetchPR` (Comments workflow) | Surfaces resolved/outdated state, splits inline threads vs review summaries |
| Fetch the diff (especially large ones) | `FetchPR` (Diff workflow) | `--save` flag avoids dumping huge diffs into context |
| Critique code without posting to the forge | `CodeReview` | Writes findings into the conversation, not the PR/MR |
| Post a pending/draft review with inline comments | `ReviewPR` (this skill) | Creates forge-side pending review or chat fallback |

The Review workflow uses `FetchPR`'s tools internally for fetching data when the CLI is authed — see Steps 0–3 in `Workflows/Review.md`.
