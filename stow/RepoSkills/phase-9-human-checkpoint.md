# Phase 9: Human Checkpoint

This is the final phase. Phase 6 resolved what it could from source code, and Phases 7-8 re-validated and re-reviewed. Remaining gaps need human input: domain terms the code doesn't define, business logic that isn't documented, and questions the simulations surfaced that source code can't answer.

**This phase is interactive — it requires human input.** If there is nothing to ask, it skips entirely.

---

## Skip Condition

Before starting any work, check whether this phase can be skipped entirely.

**Skip Phase 9 if ALL of the following are true:**
1. `_unresolved.md` contains zero issues (or doesn't exist)
2. The Reverse Glossary (Step 9.1) finds zero new domain terms
3. Phase 2 did not flag any modules with unknown local run/test procedures

If all three conditions are met:
- Mark Phase 9 complete in `state.md` with note: `Skipped — all issues resolved, no new domain terms, no missing info.`
- Jump directly to Cleanup (Step 9.6)
- Report to the orchestrator: "Phase 9 skipped — no human input needed."

---

## Checklist

Copy this checklist into `state.md` under the Phase 9 entry. Mark each item `[x]` immediately upon completion.

```
- [ ] 9.0: Check skip condition
- [ ] 9.1: Reverse Glossary — mine code for undefined domain terms
- [ ] 9.2: Present unresolvable issues from Phase 6
- [ ] 9.3: Present missing info questions from Phase 2
- [ ] 9.4: Incorporate human answers into skill files and domain-context.md
- [ ] 9.5: Post-answer validation — verify all changes, re-check routing, spot-check 5 claims
- [ ] 9.6: Offer drift detection integration (CI + local hook)
- [ ] 9.7: Cleanup — delete working _ prefixed files from MEMORY (preserve _boundaries.md, _manifest.md)
- [ ] 9.8: Store git commit hash in state.md
- [ ] 9.9: Update state.md — mark Phase 9 and pipeline complete
```

---

## Inputs and Outputs

| Direction | File | Location | Description |
|---|---|---|---|
| **Input** | `state.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Repo path, slug, phase progress, Phase 2 flags |
| **Input** | `_unresolved.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Unresolvable issues from Phase 6 |
| **Input** | `_simulation_report.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Full simulation history (for context when presenting questions) |
| **Input** | All skill files | Target repo: `.ai/skills/` | Documentation to update with human answers |
| **Input** | `domain-context.md` | Target repo: `.ai/skills/` | Existing domain context (if it exists) |
| **Input** | Codebase | Target repo on disk | For Reverse Glossary code mining |
| **Input** | Human input | Interactive | Answers to questions |
| **Output** | Updated skill files | Target repo: `.ai/skills/` | Final documentation with human input incorporated |
| **Output** | Updated `domain-context.md` | Target repo: `.ai/skills/` | New glossary terms added |
| **Output** | `state.md` (updated) | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Pipeline complete, git hash stored |

---

## Updating state

After completing **each numbered step** below, immediately update `state.md`:

1. Mark the step's checkbox `[x]` in the Phase 9 checklist
2. Update the `updated:` timestamp

Do not batch state updates. If context is lost between steps, the recovery protocol relies on `state.md` being current. A completed step with no state update will be repeated on resume.

---

## Step 1: Reverse Glossary (Step 9.1)

Mine the codebase for domain-specific terms that are not defined in `.ai/skills/domain-context.md` (or `.ai/skills/glossary.md` if it exists).

### Process

1. **Extract candidate terms.** Scan source code for terms that:
   - Appear frequently (5+ occurrences) in variable names, function names, class names, enum values, database column names, UI labels, API endpoint names, or string constants
   - Are NOT standard programming vocabulary (exclude: middleware, schema, endpoint, controller, service, handler, router, factory, repository, provider, adapter, util, helper, config, etc.)
   - Are NOT already defined in `domain-context.md` or `glossary.md`

2. **Build hypotheses.** For each candidate term, read the code context where it appears. Form a hypothesis about what it means based on usage patterns. This is NOT a "best guess" — it is a reasoned inference with cited evidence.

3. **Cap at 10 terms.** If more than 10 candidates exist, prioritise by:
   - Frequency (more occurrences = higher priority)
   - Cross-module usage (appears in 3+ modules = higher priority)
   - Relevance to simulation failures (if a simulation got confused by this term = highest priority)

4. **Present to the human.** For each term, show:

   ```
   I found these domain-specific terms in the codebase that aren't defined in the
   documentation. For each, I've shown where it appears and my hypothesis based on
   the code. Your answer is authoritative — correct me if I'm wrong.

   1. `settlement_window`
      - Appears in: src/services/settlement.ts (line 42), src/types/transaction.ts (line 15),
        and 12 other files
      - Code context: Used as a time range parameter in processSettlement(), compared against
        Date.now() to determine if transactions are eligible
      - Hypothesis: A configurable time period during which transactions can be batched and
        processed together. Appears to default to 24 hours based on the constant on line 8.
      - Is this correct? What else should an agent know about it?

   2. `provider_tier`
      - Appears in: src/models/provider.ts (line 23), src/routes/matching.ts (line 87)
      - Code context: Enum with values GOLD/SILVER/BRONZE. Used in matching.ts to sort
        providers before assignment — higher tiers are matched first.
      - Hypothesis: A classification of providers by quality or priority level, where GOLD
        providers are preferred over SILVER and BRONZE.
      - What determines a provider's tier? Is it manual or computed?

   You can skip any terms you don't want to define right now.
   ```

5. **For each term the human defines:** Add to `.ai/skills/domain-context.md` in the Domain Glossary section. If the file doesn't exist, create it with just the glossary. If `glossary.md` also exists, add there too.

6. **For skipped terms:** Leave them out. Do not invent definitions.

### Rules for Reverse Glossary
- Show the file path and line number where each term appears — the human needs to see the context
- State your hypothesis clearly and mark it as a hypothesis, not a fact
- The human's answer replaces your hypothesis entirely — do not blend or negotiate
- Do NOT present standard technical vocabulary as domain terms
- If `domain-context.md` doesn't exist and the human defines terms, create the file with a Glossary section

Update `state.md`: mark step 9.1 complete. Record how many terms were found and presented.

---

## Step 2: Present Unresolvable Issues (Step 9.2)

Read `~/.claude/MEMORY/RepoSkills/<repo-slug>/_unresolved.md`. Present each unresolvable issue to the human with full context.

### Presentation format

Group issues by severity (blocking first), then present:

```
Phase 5 clarity review simulations found gaps that I couldn't resolve from the source code.
Each question below includes which simulation found it and what I already checked.

**Blocking Issues**

Q1: [Specific question]
- Found by: Simulation 2 (Bug Fix in Core Module) and Simulation 5 (Refactor)
- Affects: .ai/skills/modules/payment.md
- What the simulation agent needed: How payment retries are triggered — the agent
  needed to trace the retry flow but the documentation doesn't describe the trigger
  mechanism
- What I checked: src/services/payment.ts, src/workers/retry.ts, src/config/queues.ts —
  the retry worker exists but the trigger condition depends on external configuration
  that isn't in the codebase
- Can defer? No — agents working on payment logic will make incorrect assumptions
  about retry behaviour

Q2: [next question...]

**Degrading Issues**

Q3: [next question...]

You can answer any question, or say "skip" / "defer" to leave it as a known gap.
```

### Handling responses

- **Direct answer:** Update the affected skill file(s) with the answer. Verify consistency with surrounding content.
- **"Skip" or "defer":** Mark as deferred in `_unresolved.md`. Add a `<!-- DEFERRED: [question] -->` marker in the affected skill file so future agents know there's a known gap.
- **Partial answer:** Incorporate what you can. Ask a focused follow-up for the remaining gap. If the human defers the follow-up, treat the remainder as deferred.
- **"I don't know":** Mark as unresolvable-by-human. Add a `<!-- UNKNOWN: [question] -->` marker in the affected skill file.

Update `state.md`: mark step 9.2 complete.

---

## Step 3: Present Missing Info Questions (Step 9.3)

Check `state.md` and Phase 2 outputs for any modules flagged with unknown local run/test procedures — cases where Phase 1 could not determine how to run, build, or test a component locally.

If any exist, present them:

```
During documentation generation, I couldn't determine the local development setup
for these areas:

1. [Module/component name]
   - What I found: [e.g., "No test runner configuration found", "Docker compose
     file references services not documented"]
   - What an agent needs: [e.g., "How to run integration tests for this module locally"]

Can you describe the setup for any of these?
```

Handle responses the same way as Step 2 (direct answer, skip/defer, partial, unknown).

Update `state.md`: mark step 9.3 complete.

---

## Step 4: Incorporate Answers (Step 9.4)

After receiving all human input:

1. **Update skill files** with every answer received (already done incrementally in Steps 9.1-9.3, but do a final consistency check)
2. **Update domain-context.md** with all new glossary terms from the Reverse Glossary
3. **Verify consistency** — read through each updated file to ensure new content doesn't contradict existing content
4. **Check for ripple effects** — if a human answer changes the understanding of a module, check whether other skill files reference that module and need updating

Update `state.md`: mark step 9.4 complete.

---

## Step 5: Post-Answer Validation (Step 9.5)

**Do not skip this step.** Human input must be validated before cleanup.

1. **Re-check every skill file modified by human input:**
   - File paths referenced in new content must exist
   - New glossary terms added to domain-context.md must appear in the codebase
   - New gotchas or corrections must be consistent with existing skill content
2. **Re-check routing tables in root platform files:**
   - If any module skills were added/renamed/removed based on human input, update ALL routing tables (CLAUDE.md, AGENTS.md, copilot-instructions.md, .cursorrules)
   - Verify all routing entries point to files that exist
3. **Spot-check 5 claims from modified skills against source code** — same adversarial stance as Phase 4
4. **If validation finds issues:** fix them now. Do not leave them for a future run.
5. **Cascading update check — when a human answer changes a domain term, concept, or understanding:**
   - **Identify the SCOPE of the change:** Is this a single-module correction or a repo-wide redefinition? A changed glossary term, a renamed concept, or a corrected business rule that other modules reference is repo-wide.
   - **If repo-wide** (e.g., a glossary term redefined, a business concept corrected): Grep ALL skill files for the affected term. Update every occurrence. This is not a spot-check — it is an exhaustive update. A "big reveal" from the human (e.g., "Project means client engagement, not software project") must propagate correctly across all skills.
   - **After all updates:** Re-validate every modified skill file — file paths must exist, claims must be consistent with each other, and no contradictions can be introduced by the propagated change.
   - **If more than 5 skill files were modified by the cascade:** Run ONE targeted simulation (the New Developer Onboarding scenario) using the updated skills to verify coherence. If the simulation surfaces new gaps, fix them before proceeding.
   - **Update ALL routing tables** if any module skill names or purposes changed as a result of the cascading update.

Update `state.md`: mark step 9.5 complete.

---

## Step 6: Offer Drift Detection Integration (Step 9.6)

The skill drift detection tools were generated in Phase 2. This step offers the human two integration options: CI (recommended, team-wide) and local git hooks (individual convenience).

Present both options to the human:

```
Skill drift detection is ready. There are two ways to integrate it:

**1. CI integration (recommended — benefits the entire team)**
A CI workflow runs on every pull request and posts drift reports as PR review
comments with inline annotations on affected files. This catches drift for every
contributor automatically.

I can generate a GitHub Actions workflow for this. If you use a different CI
platform (GitLab CI, Azure DevOps, CircleCI, etc.), I can adapt it.

Would you like me to add a CI workflow? (yes / no / different platform: ___)

**2. Local git hook (optional — benefits only the installing developer)**
A hook management script is available at .ai/skills/Tools/skill-drift-hook.sh.
Any developer can install it locally:

  .ai/skills/Tools/skill-drift-hook.sh install          # post-commit (default)
  .ai/skills/Tools/skill-drift-hook.sh install pre-commit
  .ai/skills/Tools/skill-drift-hook.sh uninstall
  .ai/skills/Tools/skill-drift-hook.sh status

Note: Git hooks are local to each clone. Other team members won't see drift
warnings unless they also install the hook. CI integration covers everyone.
```

### Handling CI responses

- **Yes (GitHub Actions):** Read the CI workflow template from the RepoSkills skill directory (`templates/skill-drift-ci.yml`). Write it to `.github/workflows/skill-drift.yml` in the target repo. Verify the file is valid YAML. If the `.github/workflows/` directory does not exist, create it.
- **Different platform:** Adapt the CI workflow template for the specified platform. The core logic is: run `skill-drift.sh --json`, parse the JSON output, post a PR/MR comment with the drift details. Adapt the trigger, API calls, and workflow syntax for the target CI platform.
- **No:** Skip CI. Note that CI can be added later by running `skill-drift.sh --json` in any CI pipeline.

### Handling hook responses

The hook management script is always generated during Phase 2 — no action needed here. Just inform the human it exists and how to use it. They can install it anytime.

Update `state.md`: mark step 9.6 complete.

---

## Step 7: Cleanup (Step 9.7)

Delete working `_` prefixed files from `~/.claude/MEMORY/RepoSkills/<repo-slug>/`:

- `_simulation_report.md`
- `_unresolved.md`
- `_sim_verify.md` (if it still exists)
- `_triage.md`
- `_questions.md`
- Any other `_` prefixed files created during the pipeline **except** the ones listed below

**Do NOT delete `state.md`.** It serves as the permanent record that the pipeline ran, when it completed, and what repo it targeted.

**Do NOT delete `_boundaries.md`.** It is essential for diff-based re-runs — it maps changed files to module boundaries without re-scanning the entire codebase.

**Do NOT delete `_manifest.md`.** It is essential for diff-based re-runs — it tracks the disposition of every skill file so updates can detect additions, deletions, and orphaned modules.

**Do NOT delete any files in the target repo** — `.ai/skills/domain-context.md` and all skill files are permanent outputs.

Update `state.md`: mark step 9.7 complete.

---

## Step 8: Store Git Commit Hash (Step 9.8)

Record the current HEAD commit hash in `state.md` for future diff-based updates:

```bash
git -C <repo-path> rev-parse HEAD
```

Add to `state.md`:

```markdown
## Pipeline Record
- completed: [ISO timestamp]
- commit_hash: [full SHA]
- branch: [current branch name]
```

This hash enables future runs of the pipeline to diff against the documented state and only update what changed, rather than re-documenting the entire repo.

Update `state.md`: mark step 9.8 complete.

---

## Step 9: Mark Pipeline Complete (Step 9.9)

Update `state.md`:
- Mark step 9.9 complete
- Mark Phase 9 complete with timestamp
- Mark ALL phases as `[x]` complete
- Update the `updated:` timestamp to the final completion time
- Ensure the Pipeline Record section (from Step 9.8) is present

Report to the orchestrator:

```
Pipeline complete.
- Skill files generated and validated in .ai/skills/
- Domain terms added to domain-context.md: N
- Unresolvable issues answered by human: N
- Deferred gaps (marked in docs): N
- Commit hash recorded: [short SHA]
- Working files cleaned from MEMORY. State preserved in state.md.
```

The `state.md` file at `~/.claude/MEMORY/RepoSkills/<repo-slug>/state.md` now serves as the permanent record that this repo's skill files have been generated, simulated, resolved, and reviewed.

---

## Rules

- **The human's answer is authoritative.** Do not argue, reinterpret, or blend human answers with your hypotheses. Replace your understanding with theirs.
- **Do not fabricate answers to fill gaps.** If the human skips a question, it becomes a documented gap — not an opportunity to guess.
- **Show your work when asking questions.** Every question includes what you already checked and why the code doesn't answer it. The human should never have to wonder "did you look at X?"
- **Keep questions focused and specific.** "How does payment work?" is a bad question. "What triggers a payment retry — is it time-based, event-based, or manual?" is a good question.
- **Clean up after yourself.** Working files are for state passing between phases. They are not documentation and must not persist after the pipeline completes.
- **The commit hash is essential.** Without it, future runs cannot do incremental updates. Do not skip Step 9.8.
