---
name: CodeReview
description: Opinionated code review inspired by Robert C. Martin's Clean Code principles, using severity tiers and 6 review lenses. Also supports plan alignment reviews — reviewing code changes against an original plan or spec using git diff ranges. USE WHEN user asks for brutal review, clean code review, uncle bob review, code review, codebase critique, plan alignment review, review against plan, or check against spec.
---

# CodeReview

Opinionated code review in the tradition of Robert C. Martin (Uncle Bob) and Clean Code principles. Also supports plan alignment reviews — reviewing completed work against its original plan or spec using git diff ranges. Direct, line-number-cited, no rubber-stamping.

## Workflow Routing

| Trigger | Workflow |
|---------|----------|
| "review the codebase", "brutal review", "uncle bob review" | `Workflows/Review.md` |
| "review this file", "review [filename]" | `Workflows/SingleFile.md` |
| "review against plan", "plan alignment", "check against spec" | `Workflows/PlanAlignment.md` |

