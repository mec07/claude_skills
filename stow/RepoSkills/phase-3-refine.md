# Phase 3: Refine — Structural Assessment and Quality Pass

Phase 2 generated skill files from scratch. Your job is to assess their **structure, coverage, and organisation**, then improve them. You are not fact-checking individual claims — that is Phase 4's job. You are evaluating whether the right skills exist, cover the right areas, have sensible module boundaries, avoid duplication, and leave no significant coverage gaps.

**You are a structural reviewer, not a fact-checker.** If a skill says "X uses Y", you do not need to verify that claim — Phase 4 will. But if a skill conflates three unrelated subsystems into one module skill, fix the structure.

---

## Checklist

Copy this checklist into `state.md` under the Phase 3 entry. Mark each item `[x]` immediately upon completion.

```
- [ ] 3.0: Read inputs (_triage.md, _boundaries.md, all Phase 2 output, codebase structure)
- [ ] 3.1a: Module boundary assessment
- [ ] 3.1b: Duplication assessment
- [ ] 3.1c: Coverage assessment
- [ ] 3.1d: Verbosity assessment
- [ ] 3.1e: Orientation skill assessment
- [ ] 3.2: Plan changes
- [ ] 3.3: Execute changes (apply 14-question quality bar per module skill)
- [ ] 3.4: Structural sanity check
- [ ] 3.5: Self-review gate
- [ ] 3.6: Update state.md — mark Phase 3 complete with timestamp
```

---

## Inputs and Outputs

| Direction | File | Location | Description |
|---|---|---|---|
| **Input** | `state.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Repo path, slug, tier, phase progress |
| **Input** | `_triage.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Phase 0 triage assessment |
| **Input** | `_boundaries.md` | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Confirmed boundary map from Phase 2 |
| **Input** | All skill files | Target repo: `.ai/skills/` | Skills produced by Phase 2 |
| **Input** | Platform glue files | Target repo root | `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `.github/copilot-instructions.md` |
| **Input** | Codebase | Target repo on disk | For verifying new content added during expansion |
| **Output** | Updated skill files | Target repo: `.ai/skills/` | Restructured, expanded, deduplicated skills |
| **Output** | Updated platform glue | Target repo root | Updated if orientation or module skills changed |
| **Output** | `_boundaries.md` (updated) | `~/.claude/MEMORY/RepoSkills/<repo-slug>/` | Updated after any module boundary changes |

---

## Updating state

After completing **each numbered step** below, immediately update `state.md`:

1. Mark the step's checkbox `[x]` in the Phase 3 checklist
2. Update the `updated:` timestamp

Do not batch state updates. If context is lost between steps, the recovery protocol relies on `state.md` being current. A completed step with no state update will be repeated on resume.

---

## CRITICAL RULES

- **You are a structural reviewer, not a fact-checker.** If a skill says "X uses Y", you do not need to verify that claim — Phase 4 will. But if a skill conflates three unrelated subsystems into one module skill, fix the structure.
- **Do not introduce new hallucinations.** When you add or expand content, verify it against source code. The same evidence standards from Phase 2 apply to everything you write.
- **Read before changing.** Understand each skill's current content and purpose before deciding what to do with it.

---

## Step 0: Read Inputs (Step 3.0)

Read all of the following:
1. `~/.claude/MEMORY/RepoSkills/<repo-slug>/_triage.md` — Phase 0's boundary candidates and assessment
2. `~/.claude/MEMORY/RepoSkills/<repo-slug>/_boundaries.md` — confirmed boundary map from Phase 2
3. All skill files in `.ai/skills/` (orientation, modules, tasks)
4. Platform glue files (`AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `.github/copilot-instructions.md`)
5. `state.md` — current progress

Update `state.md`: mark step 3.0 complete.

---

## Step 1: Structural Assessment

Read every file in `.ai/skills/`, plus all platform glue files.

### 1a. Module boundary assessment (most important)

For each module skill in `.ai/skills/modules/`:

- **Does it map to a real, coherent boundary in the codebase?** A module skill should correspond to something an engineer would think of as "a thing" — a service, an app, a package, a bounded subsystem. If a skill conflates multiple distinct subsystems, it needs to be split. If a skill covers something too granular, it should be merged.

- **Would an agent working in this area be well-served?** Imagine an LLM agent asked to fix a bug or add a feature here. Can it quickly find this skill? Does the skill tell it where to look, what to be careful about, and what else might be affected?

- **Are there major parts of the codebase with no module skill?** These are coverage gaps that need filling.

- **Are there module skills for things too trivial to warrant one?** These should be folded into a parent skill or into the orientation skill.

- **Cross-reference the confirmed boundary map.** Any boundary from `_boundaries.md` that lacks a module skill is a gap. Any module skill that does not correspond to a confirmed boundary needs justification or removal.

Let the actual code structure guide you. Don't split based on what you think the architecture should be — split based on what has distinct code, distinct entry points, distinct dependencies, and distinct communication patterns.

Update `state.md`: mark step 3.1a complete.

### 1b. Duplication assessment

Look for duplication **within the skill layer** (`.ai/skills/` files):
- The same information repeated across multiple skill files
- Module skills that substantially overlap with the orientation skill

**The rule: within the skill layer, every fact should live in exactly one place.** Other skill files should link to it, not restate it.

**Root platform files are NOT subject to this rule.** CLAUDE.md, AGENTS.md, .cursorrules, and copilot-instructions.md intentionally contain the same required sections (routing tables, key rules, etc.) because each must be self-sufficient — any one of them might be the only context an agent has after compaction. This overlap is by design. However, root files should NOT duplicate detailed module skill content — they contain routing tables and summary context, not full module write-ups.

Also check:
- Per-module routing files that duplicate their canonical module skill instead of containing it (these SHOULD contain the full module skill — that's the per-module routing design)

Update `state.md`: mark step 3.1b complete.

### 1c. Coverage assessment

Check whether the skills adequately cover:

**Common agent tasks:** For every task skill that Phase 0 flagged as warranted, does a skill exist? Is it substantive enough to actually help an agent?

**Module relationships:** For every module skill, are the Relationships sections complete? Do they cover all dependencies and dependents? Are they symmetric (if A depends on B, does B list A)?

**Change impact:** If an agent modifies a module, can it immediately determine what else might break? Is the Change Impact checklist in each module skill complete?

**Extension seams:** For each module skill, are the extension points documented? Does an agent know WHERE to add new functionality and WHAT interface to follow?

**Testing coverage:** For each module skill, is the Testing section substantive? Can an agent determine how to run tests for just that module?

**Cross-cutting concerns:** Are `utils/`, `lib/`, `config/`, `types/` directories adequately covered in the orientation skill or in the module skills that use them?

Update `state.md`: mark step 3.1c complete.

### 1d. Verbosity assessment

Look for:
- Introductory sentences that say nothing ("This module is responsible for handling...")
- Restating what is obvious from the file/directory name
- Generic descriptions that could apply to any project
- Hedging language ("This likely...", "This appears to...") — either verified or marked `<!-- TODO: verify -->`
- Sections that exist but contain no real information
- Schemas, types, or data structures copied into markdown when they should just point to the source file
- Content that fails the 5-second grep test (file lists, route lists, env var tables, function signatures)

Update `state.md`: mark step 3.1d complete.

### 1e. Orientation skill and routing assessment (CRITICAL)

**Routing tables are the single most important content in root platform files.** Without them, agents have no mechanism to discover which skill to load — the entire skill layer becomes a passive file listing that agents must guess their way through.

Check ALL of the following:

- Does EACH root platform file (CLAUDE.md, AGENTS.md, copilot-instructions.md, .cursorrules) contain BOTH a Module Routing table AND a Task Routing table? If ANY file is missing routing tables, this is a **blocking issue** — add them immediately.
- Does the Module Routing table cover ALL module skills? Every module skill must be reachable via routing.
- Does the Task Routing table cover ALL task skills? Every task skill must be reachable via routing.
- Are the routing tables IDENTICAL across all root platform files? (Different surrounding prose is fine; the routing rows must match.)
- Is orientation.md focused on system understanding (tech stack, shape, boundaries) WITHOUT routing tables?
- Is orientation.md under the ~2k token budget?

**Common failure mode:** The refine phase or later phases strip sections from CLAUDE.md or copilot-instructions.md in the name of "deduplication" or "condensing." The required sections below are NOT duplication — they are the behavioural framework that makes agents effective and MUST appear in every root file.

**Required sections in ALL root platform files** (CLAUDE.md, AGENTS.md, .cursorrules, copilot-instructions.md). Every root file must be self-sufficient — no redirects to other root files:
- [ ] Tech Stack
- [ ] Architecture
- [ ] Key Commands
- [ ] Key Rules
- [ ] Module Routing (table with USE WHEN keywords)
- [ ] Task Routing (table mapping intents to skill combinations, with USE WHEN keywords)
- [ ] Context Window Discipline
- [ ] Before Modifying Code
- [ ] Skill & Routing Maintenance
- [ ] Documentation (pointers to skill layer)
- [ ] Coding Standards
- [ ] New to This Repo?
- [ ] No root file redirects to another root file

If ANY root file is missing ANY of these sections, add them. The prose within each section may vary across files, but every section must be present in every file.

Update `state.md`: mark step 3.1e complete.

---

## Step 2: Plan Changes (Step 3.2)

Based on your assessment, decide:

**What to delete:**
- Skills that duplicate other skills
- Module skills for things too trivial to need one
- Content that fails the 5-second grep test

**What to fix in place:**
- Skills that are structurally sound but contain duplication or verbosity

**What to split:**
- Module skills that cover multiple distinct subsystems (each subsystem gets its own skill)

**What to expand:**
- Module skills that are too shallow to help an agent work in that area
- Missing module skills for significant parts of the codebase
- Incomplete Relationships, Change Impact, or Extension Seams sections
- Missing gotchas

**What to restructure at the top level:**
- Root platform file routing tables (CLAUDE.md, AGENTS.md, etc.) if module or task skills changed
- Platform glue files if the skill layer changed

Update `state.md`: mark step 3.2 complete.

---

## Step 3: Execute Changes (Step 3.3)

Now make the changes. For each change:

1. Read the relevant source code to verify any new content you add
2. Cut duplication — move facts to their canonical location and link elsewhere
3. Expand with verified information where coverage is thin
4. Ensure cross-links are correct and point to files that exist

### Module skill quality bar — 14 questions

Every module skill must pass this test after your edits:

> An LLM agent is asked to make a change in this area. After reading this skill, it should know:
> 1. What this part of the system does (WHY, not just WHAT)
> 2. Which directories and files to start with (entry point)
> 3. How data flows through this area
> 4. How this area communicates with the rest of the system — what it sends, what it receives, through what mechanisms
> 5. Where the relevant data structures are defined — pointed to precisely, not copied
> 6. What it depends on and what depends on it (Relationships section)
> 7. What will break if changes are made here (Change Impact checklist)
> 8. How to test changes (Testing section with exact commands)
> 9. Any traps or non-obvious behaviour (Gotchas section)
> 10. How to run this module locally (or why it can't run independently)
> 11. What local dependencies are needed beyond repo-wide prerequisites
> 12. Where new code plugs in (Extension Seams — registries, plugin points, event handlers)
> 13. What specific files/tests/consumers to check after a change
> 14. What module-specific overrides exist for repo-wide task skills

If a module skill doesn't answer all fourteen after your edits, it's not done. (Questions 10-14 may have "not applicable" as a valid answer for simple modules — but the answer must be explicit, not absent.)

### Duplication rules

- A fact lives in one place. Decide where and link everywhere else.
- Module-specific details live in the module skill.
- Cross-cutting information lives in the orientation skill or a task skill.
- **All root platform files (CLAUDE.md, AGENTS.md, .cursorrules, copilot-instructions.md) MUST contain ALL 12 required sections** (Tech Stack, Architecture, Key Commands, Key Rules, Module Routing, Task Routing, Context Window Discipline, Before Modifying Code, Skill & Routing Maintenance, Documentation, Coding Standards, New to This Repo?). These are the behavioural framework, NOT duplication.
- **Every root file is self-sufficient.** CLAUDE.md, AGENTS.md, .cursorrules, and copilot-instructions.md each contain ALL required sections independently. They overlap by design — each platform may only load one of these files, and any of them could be the only context surviving compaction. No root file redirects to another.
- Beyond the required sections, root platform files should NOT duplicate module skill content. Module-specific details live in module skills, not in root files.
- If a module or task skill changes, update the routing tables in ALL root platform files to stay in sync.

### Parallelisation for large repos (Tier C/D)

If there are 15+ module skills to review, dispatch parallel subagents to avoid overwhelming a single agent's context window:

1. **Split module skills into batches of 5-8.** Group by proximity (related modules in the same batch) where possible, but do not over-optimise grouping -- even distribution matters more.
2. **Each subagent (sonnet) receives:**
   - Its batch of skill files (the full content of each module skill it is reviewing)
   - The orientation skill (`orientation.md`)
   - The confirmed boundary map (`_boundaries.md`)
   - The 14-question quality bar (from above)
   - The duplication rules (from above)
   - Instructions to apply the quality bar to each assigned skill and record findings
3. **Each subagent applies the 14-question quality bar** to its assigned skills, checking structure, coverage, and verbosity. It does NOT perform cross-skill checks (those require repo-wide view).
4. **Each subagent writes findings to `_refine_batch_N.md`** in the MEMORY directory (e.g., `_refine_batch_1.md`, `_refine_batch_2.md`). Format: per-skill findings with proposed changes.
5. **After all subagents complete, the orchestrating agent:**
   - Reads all `_refine_batch_N.md` files
   - Performs the CROSS-SKILL checks that require repo-wide view: duplication across skills, routing consistency, coverage gaps, relationship symmetry
   - Merges findings and executes fixes (applying both per-skill and cross-skill changes)
   - Deletes `_refine_batch_N.md` working files after merge is complete

This enables Phase 3 to handle 30+ module skills without overwhelming a single agent's context window. For repos with fewer than 15 module skills, skip this and review sequentially.

### Update boundaries after restructuring

After completing Step 3, update `_boundaries.md` to reflect any module boundary changes: new module skills created, orphaned skills deleted, modules split or merged.

Update `state.md`: mark step 3.3 complete.

---

## Step 4: Structural Sanity Check (Step 3.4)

After making changes, verify:

1. **All module skills exist** for every Tier 1 boundary from `_boundaries.md`
2. **All cross-links resolve** — the few file paths that remain in skills (entry points, config files) point to files that exist on disk. Skills should describe conventions rather than listing individual file paths.
3. **No orphan skills** — every skill file is reachable from the routing tables in all root platform files
4. **All root files are self-sufficient** — each contains ALL required sections, no redirects to other root files
5. **No duplication within the skill layer** — no fact stated in more than one skill file. (Root platform files intentionally overlap with each other — this is by design for self-sufficiency, not duplication.)
6. **Existing content preserved** — any project-specific content that existed in root files before the skill pipeline was not discarded
7. **Module boundaries match code** — each skill covers one coherent area
8. **Relationship symmetry** — if module A depends on B, module B lists A as a dependent

Update `state.md`: mark step 3.4 complete.

---

## Step 5: Self-Review Gate (Step 3.5)

Before marking Phase 3 complete, verify all three of the following. If any check fails, go back and fix it before proceeding.

### Gate 1: Module skill 14-question test

Re-read every module skill in `.ai/skills/modules/`. For each one, confirm it answers all 14 questions from the quality bar above. List any that fail and which questions they miss. Fix them now.

### Gate 2: Cross-link integrity

Check every file path referenced across all `.ai/skills/` files and platform glue files. The only file paths that should exist are entry points and config file names — everything else should describe conventions, not list paths. For any remaining paths: verify they exist, and check whether they should be a path at all or a convention description instead.

### Gate 3: No duplication

Scan all skill files for facts stated in more than one place. If you find any, move the fact to its canonical location and replace duplicates with links. Every fact lives in exactly one place.

**All three gates must pass.** If you made fixes during this step, re-run the failed gate(s) to confirm they now pass.

**Escalation:** If a gate fails after 3 fix-and-recheck cycles, stop looping. Log the failing gate and the specific failures to `state.md` as a known issue. Proceed to Phase 4 — the validation phase will catch remaining problems. Do not loop indefinitely.

Update `state.md`: mark step 3.5 complete.

---

## Completion

Update `state.md`: mark Phase 3 complete with timestamp (step 3.6).

Report to the orchestrator:
- How many module skills were modified, added, removed, or split
- Summary of structural changes made
- Any known issues logged during the self-review gate

---

## Priority Order

1. **Structure** — module boundaries match real code boundaries
2. **Coverage** — all major areas have skills, all common agent tasks have routing
3. **Leanness** — no duplication, no filler, no copied schemas, no greppable data
4. **Navigation** — an agent can find the right skill from any starting point
5. **Depth** — module skills thorough enough to actually help an agent work

---

## Rules

- **Do not fact-check.** That is Phase 4's job. Focus on structure, coverage, and quality.
- **Do not introduce hallucinations.** Any new content must be verified against source code.
- **Read before changing.** Understand the skill's current content before modifying it.
- **Apply the 5-second grep test.** Any content an agent can find via grep/glob in 5 seconds does not belong in a skill.
- **Update `state.md` as you go.** Do not rely on memory.
- **Fix the skills, not the report.** Your output is better skills, not a list of findings.
