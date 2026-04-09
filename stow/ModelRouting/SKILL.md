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
| Refactoring | `opus` | Cross-cutting changes need deep reasoning to avoid getting stuck |
| Code implementation, feature work | `sonnet` | Fast and capable for writing code |
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
- Deviation is allowed when context warrants it (e.g., a trivial rename-style refactor might warrant sonnet instead of opus)
- When deviating, state why briefly in the agent prompt
- This skill applies only to subagent dispatch — the main conversation model is the user's choice

## Self-Improvement

When a subagent produces a poor result and the likely cause is the model choice (e.g., haiku struggled with a task that needed deeper reasoning, or opus was overkill for something mechanical), update the Model Assignment Table in this file with the new scenario. This keeps the routing table comprehensive and grounded in real experience.

How to apply:
1. Identify the task type that was misrouted
2. Add a new row to the table, or refine an existing row's scope, to cover the scenario
3. Include a brief rationale so future routing decisions are informed
