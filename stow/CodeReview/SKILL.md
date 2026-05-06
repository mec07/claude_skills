---
name: CodeReview
description: Opinionated code review inspired by Robert C. Martin's Clean Code principles, using severity tiers and 6 review lenses. Also supports plan alignment reviews — reviewing code changes against an original plan or spec using git diff ranges. USE WHEN user asks for brutal review, clean code review, uncle bob review, code review, codebase critique, plan alignment review, review against plan, or check against spec.
---

# CodeReview

Opinionated code review in the tradition of Robert C. Martin (Uncle Bob) and Clean Code principles. Also supports plan alignment reviews — reviewing completed work against its original plan or spec using git diff ranges. Direct, line-number-cited, no rubber-stamping.

## Companion Skills

CodeReview operates on **local code** — files on disk, working tree, or git ref ranges (`{BASE_SHA}..{HEAD_SHA}`). When the user asks to critique a **PR** that isn't checked out locally, pair with `FetchPR`:

```bash
# Save the PR's diff to a patch file, then point CodeReview at it
~/.claude/skills/FetchPR/Tools/diff.sh --pr {PR_NUMBER} --save /tmp/pr-{N}.patch
```

The patch file plus the underlying repo (or a fresh `git fetch origin pull/{N}/head`) gives CodeReview everything it needs to apply the 6 lenses without round-tripping through the GitHub UI. To **post** findings as a pending PR review instead of writing them into the conversation, use `ReviewPR` — different surface, different output.

## Workflow Routing

| Trigger | Workflow |
|---------|----------|
| "review the codebase", "brutal review", "uncle bob review" | `Workflows/Review.md` |
| "review this file", "review [filename]" | `Workflows/SingleFile.md` |
| "review against plan", "plan alignment", "check against spec" | `Workflows/PlanAlignment.md` |

