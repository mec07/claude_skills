# Phase 2: Restructure and Expand the LLM Documentation Layer

Phase 1 generated documentation from scratch. Your job is to assess its **structure, coverage, and organisation**, then improve it. You are not fact-checking individual claims — that is Phase 3's job. You are evaluating whether the right docs exist, cover the right areas, have sensible module boundaries, avoid duplication, and leave no significant coverage gaps.

---

## Checklist

Complete every item in order. Update `state.md` after each step.

- [ ] 0: Read inputs (baseline reference, all Phase 1 output, codebase structure)
- [ ] 1a: Module boundary assessment
- [ ] 1b: Duplication assessment
- [ ] 1c: Coverage assessment
- [ ] 1d: Verbosity assessment
- [ ] 1e: Top-level doc assessment
- [ ] 2: Plan changes
- [ ] 3: Execute changes
- [ ] 4: Structural sanity check
- [ ] 5: Self-review gate

---

## Inputs and Outputs

**Inputs:**
- `~/.claude/MEMORY/llm-docs/<repo-slug>/_original_docs.md` — Phase 0 reliability assessment of existing documentation
- `~/.claude/MEMORY/llm-docs/<repo-slug>/state.md` — current pipeline state
- `docs/llm/**` — all documentation files produced by Phase 1
- `CLAUDE.md`, `.github/copilot-instructions.md`, `docs/README.md` — entry point files from Phase 1
- Local context files in subdirectories — produced by Phase 1
- The codebase itself — for verifying new content added during expansion

**Outputs:**
- All `docs/llm/` files restructured and expanded as needed
- `CLAUDE.md`, `.github/copilot-instructions.md`, `docs/README.md` updated if necessary
- Local context files added, removed, or updated as needed
- `~/.claude/MEMORY/llm-docs/<repo-slug>/state.md` updated with Phase 2 complete

---

## CRITICAL RULES

- **You are a structural reviewer, not a fact-checker.** If a doc says "X uses Y", you do not need to verify that claim — Phase 3 will. But if a doc conflates three unrelated subsystems into one module doc, fix the structure.
- **Do not introduce new hallucinations.** When you add or expand content, verify it against source code. The same evidence standards apply to everything you write.
- **Read before changing.** Understand each doc's current content and purpose before deciding what to do with it.

---

## Baseline reference

Read `~/.claude/MEMORY/llm-docs/<repo-slug>/_original_docs.md` for the reliability assessment of all existing documentation. When your generated docs conflict with a **high-confidence** original doc on structural matters (e.g., what the major components are, where key boundaries lie), the original doc is more likely to be correct — verify against source code. For **low-confidence** originals, trust the generated docs and verify against source code if in doubt.

> **Update state:** Mark step 0 complete in `state.md` after reading all inputs.

---

## Step 1: Structural assessment

Read every file in `docs/llm/`, `CLAUDE.md`, `.github/copilot-instructions.md` (if it exists), `docs/README.md`, and any local context files created in Phase 1.

### 1a. Module boundary assessment (most important)

For each module doc in `docs/llm/modules/`:

- **Does it map to a real, coherent boundary in the codebase?** A module doc should correspond to something an engineer would think of as "a thing" — a service, an app, a package, a bounded subsystem. If a doc conflates multiple distinct subsystems, it needs to be split. If a doc covers something too granular, it should be merged.

- **Would an agent working in this area be well-served?** Imagine an LLM agent asked to fix a bug or add a feature here. Can it quickly find this doc? Does the doc tell it where to look, what to be careful about, and what else might be affected?

- **Are there major parts of the codebase with no module doc?** These are coverage gaps that need filling.

- **Are there module docs for things too trivial to warrant one?** These should be folded into a parent doc or removed.

Let the actual code structure guide you. Don't split based on what you think the architecture should be — split based on what has distinct code, distinct entry points, distinct dependencies, and distinct communication patterns.

> **Update state:** Mark step 1a complete in `state.md`.

### 1b. Duplication assessment

Look for:
- The same information repeated across multiple files
- Module docs that substantially overlap with top-level docs
- Local context files that duplicate their module doc instead of pointing to it
- `CLAUDE.md`, `copilot-instructions.md`, and `overview.md` all saying the same things

**The rule: every fact should live in exactly one place.** Other files should link to it, not restate it.

> **Update state:** Mark step 1b complete in `state.md`.

### 1c. Coverage assessment

Check whether the docs adequately cover:

**Inter-component communication:** For every point where one part of the system talks to another, is there documentation of the sender file, receiver file, mechanism, data contract, and downstream effects? Scan the actual codebase for communication patterns (HTTP clients, queue publishers, event emitters, direct cross-module imports) and check whether the docs account for each one.

**Data structure discoverability:** For every kind of data structure (DB schemas, API types, search indices, message formats, configs), can an agent go from "I need the schema for X" to the actual definition file in one step? Are relationships between data structures documented (e.g., API types that map to DB tables)?

**Change impact:** If an agent modifies a module, can it immediately determine what else might break? Is this covered consistently in both the module docs and `dependency-map.md`?

**Script discoverability:** Does `scripts.md` exist and comprehensively inventory all scripts? Are script directories covered with READMEs? Can an agent quickly answer: "Does a script for X already exist?", "Where should a new script go?", and "What patterns should it follow?" Check the actual repo for scripts and script directories, and compare against what `scripts.md` covers.

> **Update state:** Mark step 1c complete in `state.md`.

### 1d. Verbosity assessment

Look for:
- Introductory sentences that say nothing ("This module is responsible for handling...")
- Restating what is obvious from the file/directory name
- Generic descriptions that could apply to any project
- Hedging language ("This likely...", "This appears to...") — either it's verified or it should be marked `<!-- TODO: verify -->`
- Sections that exist but contain no real information
- Schemas, types, or data structures copied into markdown when they should just be pointed to

> **Update state:** Mark step 1d complete in `state.md`.

### 1e. Top-level doc assessment

- Does `architecture.md` reflect the real system shape, including inter-component communication and data structure locations?
- Does `dependency-map.md` show the system-wide module graph with change impact?
- Does `workflows.md` list real commands with real sources?
- Does `scripts.md` comprehensively inventory all scripts across the repo? Does it include the decision table, per-ecosystem sections, auth patterns, and shared utilities? Are all script directories covered with READMEs?
- Does `conventions.md` cite real patterns with real file paths?
- Does `gotchas.md` capture real traps with real evidence?
- Does `glossary.md` contain terms that actually need defining? If not, it should be removed.
- Is `CLAUDE.md` minimal — a pointer only, no `@` includes, no duplicated content?

> **Update state:** Mark step 1e complete in `state.md`.

---

## Step 2: Plan changes

Based on your assessment, decide:

**What to delete:**
- Docs that duplicate other docs
- Module docs for things too trivial to need one
- Local context files that add no value beyond the module doc
- `glossary.md` if no terms actually warrant defining

**What to fix in place:**
- Docs that are structurally sound but contain duplication or verbosity

**What to split:**
- Module docs that cover multiple distinct subsystems (each subsystem gets its own doc)

**What to expand:**
- Module docs that are too shallow to help an agent work in that area
- Missing module docs for significant parts of the codebase
- Gaps in communication path documentation
- Gaps in data structure discoverability
- Missing gotchas

**What to restructure at the top level:**
- Any top-level doc that isn't pulling its weight

> **Update state:** Mark step 2 complete in `state.md`.

---

## Step 3: Execute changes

Now make the changes. For each change:

1. Read the relevant source code to verify any new content you add
2. Cut duplication — move facts to their canonical location and link elsewhere
3. Expand with verified information where coverage is thin
4. Ensure cross-links are correct and point to files that exist

### Module doc quality bar

Every module doc must pass this test:

> An LLM agent is asked to make a change in this area. After reading this doc, it should know:
> 1. What this part of the system does
> 2. Which directories and files to look at
> 3. How data flows through this area
> 4. How this area communicates with the rest of the system — what it sends, what it receives, through what mechanisms, where the code for each side lives
> 5. Where the relevant data structures are defined — pointed to precisely, not copied
> 6. What it depends on and what depends on it
> 7. What will break if changes are made here
> 8. How to test changes
> 9. Any traps or non-obvious behaviour

If a module doc doesn't answer all nine after your edits, it's not done.

### Duplication rules

- A fact lives in one place. Decide where and link everywhere else.
- Module-specific details live in the module doc.
- Cross-cutting information lives in the appropriate top-level doc.
- `CLAUDE.md` contains only a pointer to `docs/llm/` and the "before modifying" checklist. No prose, no `@` includes.
- `.github/copilot-instructions.md` is the concise human-readable entry point. Add links to `docs/llm/` for depth — don't bloat it.
- Local context files are max 5 lines: what this is, link to module doc, critical local caveat if any.

### Local context file maintenance

When module boundaries change in Step 1a (modules split, merged, or removed), update corresponding local context files:
- **Module split:** Create new local context files in the new module directories, each pointing to the correct new module doc.
- **Module removed:** Delete the local context file for the removed module.
- **Module renamed:** Update the local context file's pointer to the renamed module doc.
- **Boundary shift:** If files moved between modules, ensure local context files in affected directories point to the correct module doc.

### Communication documentation rules

When adding or expanding communication documentation:
- **Always document both sides.** A communication path has a sender and a receiver. Document the file path for both.
- **Always identify the contract.** What governs the data shape at this boundary? Point to the definition file.
- **Always note the mechanism.** Don't just say "A talks to B" — say how (HTTP, gRPC, queue, event, direct import, etc.).
- **Don't document internals as communication.** Focus on boundaries between distinct parts of the system, not function calls within a module.
- **Highlight coupled changes.** If changing one side requires changing the other, say so explicitly.

### Data structure documentation rules

When adding or expanding data structure documentation:
- **Never copy schemas or type definitions into markdown.** Point to the source file.
- **Document the location of every definition file.** One step from "I need the schema for X" to the file.
- **Document relationships.** If a search index mirrors a DB table, say so and point to both definitions and the sync code.
- **Document naming conventions.** If there's a pattern to how tables/types/fields are named, state it.

> **Update state:** Mark step 3 complete in `state.md`.

---

## Step 4: Structural sanity check

After making changes, verify:

1. **All module docs exist** for every significant area of the codebase
2. **All script directories have READMEs** and `scripts.md` covers all script locations
3. **All cross-links resolve** — every `[text](path)` points to a file that exists
4. **No orphan docs** — every doc is reachable from `overview.md` or `CLAUDE.md`
5. **`CLAUDE.md` is minimal** — pointer only, no `@` includes
6. **No duplication** — no fact stated in more than one place
7. **Module boundaries match code** — each doc covers one coherent area

This is a structural check only. Factual accuracy verification is Phase 3's job.

> **Update state:** Mark step 4 complete in `state.md`.

---

## Step 5: Self-review gate

Before marking Phase 2 complete, verify all three of the following. If any check fails, go back and fix it before proceeding.

### Gate 1: Module doc 9-question test

Re-read every module doc in `docs/llm/modules/`. For each one, confirm it answers all 9 questions from the module doc quality bar above. List any that fail and which questions they miss. Fix them now.

### Gate 2: Cross-link integrity

Check every markdown link (`[text](path)`) across all `docs/llm/` files, `CLAUDE.md`, `.github/copilot-instructions.md`, `docs/README.md`, and local context files. Every link must resolve to a file that exists. Fix or remove any that don't.

### Gate 3: No duplication

Scan all documentation files for facts stated in more than one place. If you find any, move the fact to its canonical location and replace duplicates with links. Every fact lives in exactly one place.

**All three gates must pass.** If you made fixes during this step, re-run the failed gate(s) to confirm they now pass.

**Escalation:** If a gate fails after 3 fix-and-recheck cycles, stop looping. Log the failing gate and the specific failures to `state.md` as a known issue. Proceed to Phase 3 — the validation phase will investigate and catch remaining problems. Do not loop indefinitely on the self-review gate.

> **Update state:** Mark step 5 complete and Phase 2 complete in `state.md`.

---

## Priority order

1. **Structure** — module boundaries match real code boundaries
2. **Coverage** — all major areas documented, all communication paths mapped
3. **Leanness** — no duplication, no filler, no copied schemas
4. **Navigation** — an agent can find the right doc from any starting point
5. **Depth** — module docs thorough enough to actually help an agent work
