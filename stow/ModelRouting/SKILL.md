---
name: ModelRouting
description: Route subagents to the right model (opus/sonnet/haiku) based on task type. Applies automatically when dispatching agents.
---

# Model Routing

Route subagents to the right model based on task type. Opus for reasoning-heavy work, sonnet for code production, haiku for mechanical tasks. This is advisory with a strong default — deviate when context warrants it, but justify the deviation.

## Model Assignment Table

| Task Type | Model | Rationale |
|---|---|---|
| Planning, architecture, brainstorming, design | `opus` | Best reasoning for complex decisions |
| Code review | `opus` | Deep reasoning catches subtle issues |
| Debugging / root cause analysis | `opus` | Complex reasoning needed |
| Code implementation, feature work, refactoring | `sonnet` | Fast and capable for writing code |
| Test writing | `sonnet` | Follows patterns, doesn't need deepest reasoning |
| Simple lookups, renames, file searches, formatting | `haiku` | Cheapest, fast enough for mechanical tasks |

## When to Use

When dispatching any subagent via the Agent tool, consult the table above and set the `model` parameter accordingly.

```
Agent(model: "opus", prompt: "Review this PR for correctness...")
Agent(model: "sonnet", prompt: "Implement the user auth flow...")
Agent(model: "haiku", prompt: "Rename userId to accountId across these files...")
```

## Deviation Policy

- Default to the table assignment
- Deviation is allowed when context warrants it (e.g., a refactor touching complex cross-service boundaries might warrant opus instead of sonnet)
- When deviating, state why briefly in the agent prompt
- This skill applies only to subagent dispatch — the main conversation model is the user's choice
