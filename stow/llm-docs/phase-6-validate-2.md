# Phase 6: Validate (Pass 2)

This is a second validation pass. Phases 4 and 5 made changes to the documentation — the self-resolve phase updated docs based on clarity review findings. These updates need validation just as rigorously as the original content.

**Read `phase-3-validate.md` and follow its full procedure** with these modifications:

## Differences from Phase 3

### 1. Clear and rebuild `_audit.md` from scratch

Delete the contents of `docs/llm/_audit.md` and start a fresh audit. The Phase 3 audit is stale — the docs have changed since then. Do not carry over previous findings.

### 2. Pay special attention to Phase 4–5 changes

The self-resolve phase (Phase 5) added new content to the docs based on issues found in the clarity review (Phase 4). This new content is the most likely source of errors because:
- It was written to fill gaps, which means it covers areas the original author may not have fully understood
- It may have been added hastily to resolve review issues
- It may have introduced inconsistencies with surrounding content

Validate this new content with the same rigour as everything else.

### 3. Check for regressions

Phases 4–5 may have introduced new problems while fixing old ones. Look specifically for:
- File paths that were correct before but broken by edits
- Cross-links that point to moved or renamed sections
- Content that was correct but got accidentally modified during nearby edits
- Duplication introduced when filling gaps (new content restating something already documented elsewhere)

---

Now read `phase-3-validate.md` and execute the full validation procedure with the modifications above.
