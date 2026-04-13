# Phase D: Domain Interview — Capture Business and Domain Context

This phase captures knowledge that CANNOT be derived from source code: business domain, customer context, domain-specific terminology, regulatory constraints, historical decisions, and operational tribal knowledge.

**This phase is interactive — it requires human input.** It runs after Phase 0 so it can use the existing documentation assessment to ask informed questions.

---

## Skip Logic

Before starting, check whether this phase should run:

1. Read `~/.claude/MEMORY/llm-docs/<repo-slug>/_original_docs.md`
2. Check if `docs/llm/domain-context.md` was assessed by Phase 0
3. **Skip if ALL of these are true:**
   - The file exists AND Phase 0 scored it `high-confidence`
   - The `Last interview` timestamp in the file is within 6 months
   - The user did NOT pass `--interview` or `--redo-interview`
4. **Run if:** the file does not exist, OR Phase 0 scored it below `high-confidence`, OR the timestamp is older than 6 months, OR the user explicitly requested an interview

If skipping, mark Phase D complete in `state.md` with note: "Skipped — existing domain-context.md scored high-confidence by Phase 0 and is within 6 months." Proceed to Phase 1.

---

## Checklist

Copy this checklist into `state.md` under the Phase D entry. Mark each item `[x]` immediately upon completion.

```
- [ ] D.0: Check skip condition
- [ ] D.1: Present the interview prompt to the user
- [ ] D.2: Ingest user-provided material (text dump + URLs)
- [ ] D.3: Summarise ingested material into structured domain knowledge
- [ ] D.4: Identify remaining gaps — questions the material didn't answer
- [ ] D.5: Ask the user remaining questions directly (max 5)
- [ ] D.6: Write `docs/llm/domain-context.md` to the target repo
- [ ] D.7: Update `state.md` — mark Phase D complete
```

---

## Inputs and Outputs

| Direction | File | Location | Description |
|---|---|---|---|
| **Input** | `_original_docs.md` | `~/.claude/MEMORY/llm-docs/<repo-slug>/` | Phase 0's doc assessment (informs skip logic and questions) |
| **Input** | `state.md` | `~/.claude/MEMORY/llm-docs/<repo-slug>/` | Phase progress |
| **Input** | Human input | Interactive | Text dumps, URLs, direct answers |
| **Output** | `domain-context.md` | Target repo: `docs/llm/` | Structured domain knowledge |

---

## Updating state

After completing **each numbered step** below, immediately update `state.md`:

1. Mark the step's checkbox `[x]` in the Phase D checklist
2. Update the `updated:` timestamp

Do not batch state updates. If context is lost between steps, the recovery protocol relies on `state.md` being current. A completed step with no state update will be repeated on resume.

---

## Step 1: Present the Interview Prompt (D.1)

Present the following to the user. This is the FIRST human interaction in the pipeline — make it count.

```
I've completed an initial scan of your repository's existing documentation.

To generate the most accurate documentation possible, I need some context
about your business domain — things I can't figure out from source code alone.

You can help in any combination of these ways:

1. **Paste text** — dump any amount of product docs, wiki pages, onboarding
   guides, pitch decks, or other context. I'll extract what I need.

2. **Provide URLs** — link to your product website, docs site, wiki,
   Confluence, Notion, or any other pages. I'll try to fetch and read
   them (including via any integrations you have set up). If I can't
   access a page, I'll ask you to paste the content instead.

3. **Answer questions** — I'll ask targeted questions about anything the
   above didn't cover.

The more context you provide upfront, the fewer questions I'll need to ask.
You can combine all three — paste some text, give me some links, and I'll
ask about the rest.

This should take about 5-10 minutes.
```

**Update state:** Mark step D.1 complete.

---

## Step 2: Ingest User Material (D.2)

### Text Dump Processing

If the user provides pasted text:

1. Read the full text
2. Extract structured domain knowledge into these categories:
   - **Product/Business:** What the product does, who it serves, business model
   - **Domain Terms:** Any terminology with domain-specific meanings
   - **Regulatory/Compliance:** Any mentioned compliance requirements
   - **Architecture Rationale:** Any "why" explanations for technical decisions
   - **Operational Knowledge:** Any operational procedures, common issues, fixes
   - **User/Customer Context:** Who the users are, their needs, their technical level
3. Log what was extracted and what categories remain unfilled

### URL Processing

If the user provides URLs:

1. For each URL, dispatch a **subagent** (model: `sonnet`) to fetch and summarise. Each subagent follows this escalation order:

   **a. Check for relevant MCP tools first.** Before attempting a raw fetch, check if MCP tools are available that can access the URL's domain:
   - Confluence/Jira URLs → check for Atlassian MCP (`mcp__atlassian__*` tools)
   - Notion URLs → check for Notion MCP (`mcp__claude_ai_Notion__*` tools)
   - SharePoint/Teams URLs → check for Microsoft 365 MCP (`mcp__claude_ai_Microsoft_365__*` tools)
   - Slack message links → check for Slack MCP (`mcp__claude_ai_Slack__*` tools)
   
   If a matching MCP is available and authenticated, use it to fetch the page content.

   **b. If no MCP available, try WebFetch.** Attempt a standard HTTP fetch. A 403/401 response is fast — this is not expensive to try.

   **c. If both fail, note the failure** for reporting back to the user.

   On success (via MCP or WebFetch):
   - Extract the domain knowledge categories listed above
   - Write a structured summary (max 500 words) to `~/.claude/MEMORY/llm-docs/<repo-slug>/_url_summary_<N>.md`

2. **Dispatch all URL subagents in parallel** using `run_in_background: true`

3. When all subagents complete, read their summary files and merge into the domain knowledge categories

4. Delete the `_url_summary_*.md` working files after merging

**Failure handling:** For any URLs that failed both MCP and WebFetch, report them to the user: "I couldn't access [URL] — could you paste the content from that page instead?" This keeps the interaction flowing without blocking the pipeline.

**Update state:** Mark step D.2 complete.

---

## Step 3: Summarise into Structured Knowledge (D.3)

Merge all ingested material (text dump + URL summaries) into the domain knowledge categories. For each category, note:
- What was learned (with source: "from pasted text" or "from URL: ...")
- Confidence level (clear statement vs. inferred from context)
- What's still missing

**Update state:** Mark step D.3 complete.

---

## Step 4: Identify Remaining Gaps (D.4)

Compare what was learned against this complete questionnaire. Any question NOT answered by the ingested material becomes a direct question for the user.

### Domain Knowledge Questionnaire

**Essential (always ask if unanswered):**
1. What does this product do, in one sentence? Who is the primary customer?
2. What industry or vertical does this serve?

**Important (ask if unanswered and time permits):**
3. What are the 2-3 main user types? What is their technical level?
4. Are there compliance/regulatory requirements? (HIPAA, GDPR, PCI, SOX, etc.)
5. List any domain terms that have specific meaning in this product (e.g., "a 'Project' means X, not the generic sense")

**Helpful (ask if unanswered and the user is engaged):**
6. Are there parts of the codebase that look odd but are intentional? Why?
7. What approaches have been tried and abandoned? Why didn't they work?
8. What is currently being deprecated or planned for replacement?

**Optional (ask only if the user seems willing):**
9. What breaks most often? What's the typical fix?
10. Are there VPN, network, or access requirements for local development?

**Update state:** Mark step D.4 complete.

---

## Step 5: Ask Remaining Questions (D.5)

**Hard cap: Ask at most 10 direct questions.** If more gaps remain after 10 questions, note them in the Unanswered Questions section of `domain-context.md` for Phase 8 to revisit.

**Target time: Under 10 minutes of the user's time.** This phase should feel thorough but respectful of the user's attention.

Present only the questions that the ingested material didn't answer. Prioritise Essential > Important > Helpful > Optional.

For each question, show what the ingested material DID reveal (if anything) so the user can confirm or correct rather than generating from scratch:

```
Based on [your docs / the URL I read], it looks like this is a [X].
Is that correct? Anything to add or correct?
```

Confirmation is cheaper than generation — always prefer "is this right?" over "tell me about X."

If the user says "skip" or "that's enough" at any point, accept what you have and proceed immediately. Partial domain context is better than no domain context.

**Update state:** Mark step D.5 complete.

---

## Step 6: Write domain-context.md (D.6)

Write to `docs/llm/domain-context.md` in the target repo.

**If this file already exists:** Compare your new content against the existing file. Only write if content has meaningfully changed (new sections, updated glossary terms, changed business context). Do not rewrite just to update the timestamp — that creates unnecessary git churn for teams.

```markdown
# Domain Context

> This file captures business and domain knowledge that cannot be derived
> from source code. It was generated from a domain interview and should be
> reviewed and maintained by the team.
>
> Last interview: [ISO timestamp]
> To update: run `llm-docs --redo-interview` or edit this file directly.

## Product

- **What it does:** [1-2 sentences]
- **Industry/Vertical:** [e.g., FinTech, HealthTech, EdTech]
- **Business model:** [e.g., B2B SaaS, marketplace, API platform]
- **Primary customers:** [who pays]

## Users

| User Type | Description | Technical Level |
|-----------|-------------|-----------------|
| [type] | [who they are] | [high/medium/low] |

## Domain Glossary

| Term | Meaning in This Product | NOT the Same As |
|------|------------------------|-----------------|
| [term] | [definition] | [common misconception] |

## Regulatory & Compliance

- [List any compliance requirements, or "None identified"]
- [Note which parts of the codebase are affected]

## Architecture Rationale

### [Decision title]
- **What:** [what looks odd]
- **Why:** [the actual reason]
- **Don't:** [what an agent should NOT do based on this]

## Operational Knowledge

- [Common issues and fixes]
- [VPN/network requirements]
- [Anything else from tribal knowledge]

## Planned Changes

- [What's being deprecated]
- [What's being replaced and with what]

## Unanswered Questions

<!-- These will be revisited in Phase 8's Reverse Glossary step -->
- [Any questions the user skipped or couldn't answer]
```

**Rules:**
- Only include sections that have content. Do not write empty sections.
- Mark any uncertain claims with `<!-- TODO: verify with team -->`
- The "NOT the Same As" column in the glossary is critical — it prevents the most common misunderstanding for each term.
- Do NOT hallucinate domain knowledge. If the user didn't provide it and the code doesn't show it, leave it out.

**Update state:** Mark step D.6 complete. Mark Phase D complete (D.7).

---

## Edge cases

**User provides nothing:** If the user says "I don't have anything to share" or provides minimal input, write a minimal `domain-context.md` with just the Unanswered Questions section populated. Phase 8's Reverse Glossary will pick up domain terms later. The pipeline continues — domain context is valuable but not blocking.

**User provides enormous text dump:** If the pasted text exceeds what can be reasonably processed in context, extract the domain knowledge categories from the first ~10,000 words, note that only partial extraction was done, and suggest the user provide the most relevant sections on a re-run.

**User provides only URLs that all fail:** Tell the user that URL fetching didn't work and ask them to paste the most important content directly. Fall back to the direct questionnaire.

---

## Rules

- **Same evidence standards as all other phases for code-derived claims.** Do not hallucinate file paths, commands, or technical claims. Domain knowledge from the user is authoritative — technical claims must still be verified.
- **The user's words are authoritative for domain knowledge.** If the user says "a Project means X", that is the definition. Do not second-guess domain terminology.
- **Update `state.md` as you go.** Do not rely on memory.
- **Respect the user's time.** This phase should be the shortest interactive experience possible while capturing the essential context.
