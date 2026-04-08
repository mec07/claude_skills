---
name: UncleBob
description: Uncle Bob style opinionated code review using Clean Code principles, severity tiers, and 5 review lenses. USE WHEN user asks for brutal review, clean code review, uncle bob review, or codebase critique.
triggers:
  - uncle bob
  - clean code review
  - bob review
  - brutal review
  - review codebase
  - code review
  - opinionated review
tier: deferred
---

# UncleBob

Uncle Bob (Robert C. Martin) style code review. Direct, opinionated, line-number-cited, no rubber-stamping.

## Workflow Routing

| Trigger | Workflow |
|---------|----------|
| "review the codebase", "brutal review", "uncle bob review" | `Workflows/Review.md` |
| "review this file", "review [filename]" | `Workflows/SingleFile.md` |

## Quick Reference

- **5 Lenses:** Architecture, Type Safety, State Management, Testing, Pragmatics
- **4 Severity Tiers:** 🔴 Critical · 🟠 Significant · 🟡 Worth Noting · 🟢 What's Good
- **Voice:** Direct, named, opinionated — every issue gets a file:line citation
- **Output:** Ends with a priority table: what to fix first and why
