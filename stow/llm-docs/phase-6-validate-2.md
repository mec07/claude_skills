# Phase 6: Validate (Pass 2)

This is a second validation pass. Phases 4 and 5 made changes to the documentation — the self-resolve phase updated docs based on clarity review findings. These updates need validation just as rigorously as the original content.

**Read `phase-3-validate.md` and follow its full procedure** with the modifications below.

---

## Checklist

Copy this checklist into `state.md` under the Phase 6 entry. Mark each item `[x]` immediately upon completion.

```
- [ ] 6.0: Clear and rebuild _audit.md from scratch in MEMORY directory
- [ ] 6.1: File path verification (all doc files)
- [ ] 6.2: Command verification (all doc files)
- [ ] 6.2b: Script verification (all doc files)
- [ ] 6.3: Architectural claim verification (all doc files)
- [ ] 6.4: Data structure reference verification (all doc files)
- [ ] 6.5: Cross-link verification (all doc files)
- [ ] 6.6: Duplication check (all doc files)
- [ ] 6.7: Staleness check (all doc files)
- [ ] 6.8: Coverage check (all doc files)
- [ ] 6.9: Communication path completeness (all doc files)
- [ ] 6.10: Contradiction check (all doc files)
- [ ] 6.11: Regression check — Phase 4-5 specific (see Difference 3 below)
- [ ] 6.12: Verify Phase 5 resolutions from _review.md (see Difference 4 below)
- [ ] 6.13: Update _audit.md summary with final tallies
- [ ] 6.14: Update state.md — mark Phase 6 complete with timestamp
```

---

## Inputs and Outputs

| Direction | File | Location | Description |
|---|---|---|---|
| **Input** | `state.md` | `~/.claude/MEMORY/llm-docs/<repo-slug>/` | Repo path, slug, phase progress |
| **Input** | `_audit.md` (stale) | `~/.claude/MEMORY/llm-docs/<repo-slug>/` | Phase 3 audit — delete contents, start fresh |
| **Input** | `_review.md` | `~/.claude/MEMORY/llm-docs/<repo-slug>/` | Clarity review findings from Phases 4-5 |
| **Input** | All `docs/llm/` files | Target repo | Documentation to validate |
| **Input** | Codebase | Target repo on disk | Source of truth for all claims |
| **Output** | `_audit.md` (rebuilt) | `~/.claude/MEMORY/llm-docs/<repo-slug>/` | Fresh validation ledger with all findings |

---

## Updating state

After completing **each numbered step** below, immediately update `state.md`:

1. Mark the step's checkbox `[x]` in the Phase 6 checklist
2. Update the `updated:` timestamp

Do not batch state updates. If context is lost between steps, the recovery protocol relies on `state.md` being current. A completed step with no state update will be repeated on resume.

---

## Differences from Phase 3

### 1. Clear and rebuild `_audit.md` from scratch (Step 6.0)

Delete the contents of `~/.claude/MEMORY/llm-docs/<repo-slug>/_audit.md` and start a fresh audit. The Phase 3 audit is stale — the docs have changed since then. Do not carry over previous findings.

Create the fresh `_audit.md` with the same format specified in `phase-3-validate.md`:

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
- Overall confidence: high | medium | low
- Concerns: [anything that still worries you]
```

Update `state.md`: mark step 6.0 complete.

### 2. Pay special attention to Phase 4-5 changes

The self-resolve phase (Phase 5) added new content to the docs based on issues found in the clarity review (Phase 4). This new content is the most likely source of errors because:
- It was written to fill gaps, which means it covers areas the original author may not have fully understood
- It may have been added hastily to resolve review issues
- It may have introduced inconsistencies with surrounding content

Validate this new content with the same rigour as everything else. When you encounter content that looks like a Phase 5 addition (gap fills, new sections, expanded explanations), give it extra scrutiny — check every claim against source code.

### 3. Check for regressions (Step 6.11)

Phases 4-5 may have introduced new problems while fixing old ones. After completing the standard Phase 3 audit procedure (steps 6.1 through 6.10), perform a dedicated regression check. Look specifically for:

- **Broken file paths** — paths that were correct before but broken by edits
- **Broken cross-links** — links that point to moved or renamed sections
- **Accidental modifications** — content that was correct but got accidentally modified during nearby edits
- **New duplication** — content introduced when filling gaps that restates something already documented elsewhere

Log all regression findings to `_audit.md` under a dedicated `## Regressions` section.

Update `state.md`: mark step 6.11 complete.

### 4. Verify Phase 5 resolutions (Step 6.12)

After completing the standard audit checks (steps 6.1-6.10), read `~/.claude/MEMORY/llm-docs/<repo-slug>/_review.md`. For each issue marked `resolved` by Phase 5:

1. Find the documentation file(s) Phase 5 claimed to have fixed
2. Verify the fix is actually present and correct in the documentation
3. If the resolution is correct: no action needed
4. If the resolution is incomplete or incorrect: log it in `_audit.md` with verdict `❌ Phase 5 resolution incorrect — [what's wrong]` and fix the documentation yourself

This is the only point in the pipeline where Phase 5's work is independently validated. Do not skip this step.

Update `state.md`: mark step 6.12 complete.

---

## Execution

Now read `phase-3-validate.md` and execute the full validation procedure with the modifications above. The standard audit procedure (Checks 1 through 10) maps to steps 6.1 through 6.10 in the checklist. Update `state.md` after each check completes.

When you have audited every documentation file:

1. Update the Summary section of `_audit.md` with final tallies (step 6.13)
2. Update `state.md`: mark Phase 6 complete with timestamp (step 6.14)
3. Report a brief summary to the orchestrator: how many errors found/fixed, claims removed, regressions found, remaining concerns, and overall confidence level
