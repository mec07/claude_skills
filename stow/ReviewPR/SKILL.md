---
name: ReviewPR
description: Thorough PR/MR review — fetches diff, analyzes changes, creates a pending GitHub review or GitLab draft notes with inline comments on the actual diff lines. User reviews comments in the forge UI, edits as needed, then submits/publishes themselves. Falls back to a structured in-chat comment layout when drafts cannot be opened. USE WHEN review PR, review pull request, review MR, review merge request, PR review, MR review, check PR, analyze PR, look at PR.
---

## Customization

**Before executing, check for user customizations at:**
`~/.claude/PAI/USER/SKILLCUSTOMIZATIONS/ReviewPR/`

If this directory exists, load and apply any PREFERENCES.md, configurations, or resources found there. These override default behavior. If the directory does not exist, proceed with skill defaults.

## MANDATORY: Voice Notification (REQUIRED BEFORE ANY ACTION)

**You MUST send this notification BEFORE doing anything else when this skill is invoked.**

1. **Send voice notification**:
   ```bash
   curl -s -X POST http://localhost:8888/notify \
     -H "Content-Type: application/json" \
     -d '{"message": "Running the ReviewPR workflow to review pull request"}' \
     > /dev/null 2>&1 &
   ```

2. **Output text notification**:
   ```
   Running the **Review** workflow in the **ReviewPR** skill...
   ```

# ReviewPR

Stages **pending inline comments** on the PR/MR diff; the user submits/publishes in the forge UI.

| Forge | Pending mechanism | User finishes in |
|-------|-------------------|------------------|
| **GitHub** | `PENDING` review via `gh api` (omit `event`) | GitHub PR UI — edit, then submit |
| **GitLab** | Draft Notes via `glab mr note draft create` (or Draft Notes REST via `glab api`) | GitLab MR UI — edit, then publish |
| **Drafts unavailable** | Structured chat layout | [Reference/ConversationFallback.md](Reference/ConversationFallback.md) |

GitLab **does** support pending reviews (Draft Notes). Official GitLab MCP review tools currently **publish** notes — never use them as a substitute for drafts. See [Reference/HostAndAuth.md](Reference/HostAndAuth.md).

"PR" and "MR" are synonyms in triggers and docs.

**Execute:** [Workflows/Review.md](Workflows/Review.md).  
**Also load as needed:** [Reference/DesignDecisions.md](Reference/DesignDecisions.md), [Reference/CompanionSkills.md](Reference/CompanionSkills.md), [Reference/Examples.md](Reference/Examples.md).

## Workflow Routing

| Workflow | Trigger | File |
|----------|---------|------|
| **Review** | "review PR", "review MR", PR/MR number, "check this PR" | `Workflows/Review.md` |
