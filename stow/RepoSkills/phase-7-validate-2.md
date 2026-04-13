# Phase 7: Validate (Pass 2)

This is a second validation pass. Phases 5 and 6 made changes to the skills — the clarity review found gaps, and the self-resolve phase updated skills based on those findings. These updates need validation just as rigorously as the original content.

**Read `phase-4-validate.md` and follow its full procedure** with the modifications below.

---

## Checklist

Copy this checklist into `state.md` under the Phase 7 entry. Mark each item `[x]` immediately upon completion.

```
- [ ] 7.0: Clear and rebuild _audit.md from scratch in MEMORY directory
- [ ] 7.1: File path verification (all skill files)
- [ ] 7.2: Command verification (all skill files)
- [ ] 7.3: Architectural claim verification (all skill files)
- [ ] 7.4: Relationship verification (all module skills)
- [ ] 7.5: Cross-link verification (all skill files)
- [ ] 7.6: Duplication check (all skill files)
- [ ] 7.7: Staleness check (all skill files)
- [ ] 7.8: Coverage check (all skill files)
- [ ] 7.9: The 5-second grep test (all skill files)
- [ ] 7.10: Cross-skill consistency (all skill files)
- [ ] 7.11: Token budget enforcement
- [ ] 7.12: Regression check — Phase 5-6 specific (see Difference 3 below)
- [ ] 7.13: Verify Phase 6 resolutions from _simulation_report.md (see Difference 4 below)
- [ ] 7.14: Update _audit.md summary with final tallies
- [ ] 7.15: Update state.md — mark Phase 7 complete with timestamp
```

---

## Inputs and Outputs

| Direction | File | Location | Description |
|---|---|---|---|
| **Input** | `state.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Repo path, slug, phase progress |
| **Input** | `_audit.md` (stale) | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Phase 4 audit — delete contents, start fresh |
| **Input** | `_simulation_report.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Clarity review findings and Phase 6 resolutions |
| **Input** | All skill files | Target repo: `.ai/skills/` | Skills to validate |
| **Input** | Platform glue files | Target repo root | `AGENTS.md`, `CLAUDE.md`, etc. |
| **Input** | Codebase | Target repo on disk | Source of truth for all claims |
| **Output** | `_audit.md` (rebuilt) | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Fresh validation ledger with all findings |

---

## Updating state

After completing **each numbered step** below, immediately update `state.md`:

1. Mark the step's checkbox `[x]` in the Phase 7 checklist
2. Update the `updated:` timestamp

Do not batch state updates. If context is lost between steps, the recovery protocol relies on `state.md` being current. A completed step with no state update will be repeated on resume.

---

## Differences from Phase 4

### 1. Clear and rebuild `_audit.md` from scratch (Step 7.0)

Delete the contents of `~/.claude/MEMORY/RepoSkills/<repo-slug>/_audit.md` and start a fresh audit. The Phase 4 audit is stale — the skills have changed since then. Do not carry over previous findings.

**Recovery note:** If Phase 7 fails after clearing `_audit.md` but before completing the new audit, the Phase 4 findings are lost. On resume, Phase 7 will re-run the full audit from scratch — this is safe because the audit is derived from skills + source code, both of which are still on disk.

Create the fresh `_audit.md` with the same format specified in `phase-4-validate.md`:

```markdown
# Validation Audit (Pass 2)

## Findings

[entries added as you work — log every finding immediately]

## Summary
- Files audited: N
- Claims checked: N
- Errors found and fixed: N
- Claims removed as unverifiable: N
- Remaining <!-- TODO: verify --> markers: N
- Token budget violations: N
- Overall confidence: high | medium | low
- Concerns: [anything that still worries you]
```

Update `state.md`: mark step 7.0 complete.

### 2. Pay special attention to Phase 5-6 changes

The self-resolve phase (Phase 6) added new content to the skills based on issues found in the clarity review (Phase 5). This new content is the most likely source of errors because:
- It was written to fill gaps, which means it covers areas the original author may not have fully understood
- It may have been added hastily to resolve review issues
- It may have introduced inconsistencies with surrounding content

Validate this new content with the same rigour as everything else. When you encounter content that looks like a Phase 6 addition (gap fills, new sections, expanded explanations), give it extra scrutiny — check every claim against source code.

### 3. Check for regressions (Step 7.12)

Phases 5-6 may have introduced new problems while fixing old ones. After completing the standard Phase 4 audit procedure (steps 7.1 through 7.11), perform a dedicated regression check. Look specifically for:

- **Broken file paths** — paths that were correct before but broken by edits
- **Broken cross-links** — links that point to moved or renamed sections
- **Accidental modifications** — content that was correct but got accidentally modified during nearby edits
- **New duplication** — content introduced when filling gaps that restates something already documented elsewhere
- **Relationship asymmetry** — Phase 6 may have added a dependency to module A without updating module B's "Depended on by" section

Log all regression findings to `_audit.md` under a dedicated `## Regressions` section.

Update `state.md`: mark step 7.12 complete.

### 4. Verify Phase 6 resolutions (Step 7.13)

After completing the standard audit checks (steps 7.1-7.11), read `~/.claude/MEMORY/RepoSkills/<repo-slug>/_simulation_report.md`. For each issue marked `resolved` by Phase 6:

1. Find the skill file(s) Phase 6 claimed to have fixed
2. Verify the fix is actually present and correct in the skill
3. If the resolution is correct: no action needed
4. If the resolution is incomplete or incorrect: log it in `_audit.md` with verdict `Phase 6 resolution incorrect — [what's wrong]` and fix the skill yourself

This is the only point in the pipeline where Phase 6's work is independently validated. Do not skip this step.

Update `state.md`: mark step 7.13 complete.

---

## Execution

Now read `phase-4-validate.md` and execute the full validation procedure with the modifications above. The standard audit procedure (Checks 1 through 12) maps to steps 7.1 through 7.11 in the checklist. Update `state.md` after each check completes.

When you have audited every skill file:

1. Update the Summary section of `_audit.md` with final tallies (step 7.14)
2. Update `state.md`: mark Phase 7 complete with timestamp (step 7.15)
3. Report a brief summary to the orchestrator: how many errors found/fixed, claims removed, regressions found, remaining concerns, and overall confidence level
