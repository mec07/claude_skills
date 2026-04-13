# Phase 0: Discover and Assess Existing Documentation

Before generating any new documentation, you must understand what documentation already exists in this repository and how reliable it is. This phase produces a single index file that all subsequent phases use as their starting point.

**This phase is read-only. Do not modify any existing files.** Your only output is `~/.claude/MEMORY/llm-docs/<repo-slug>/_original_docs.md`.

---

## Checklist

Copy this checklist into `state.md` under the Phase 0 entry. Mark each item `[x]` immediately upon completion.

```
- [ ] 0.0: Pre-check — verify _original_docs.md does not already exist
- [ ] 0.1: Find all documentation files in the repo
- [ ] 0.2: Read and categorise each documentation file
- [ ] 0.3: Assess reliability of each file (spot-check claims against code)
- [ ] 0.4: Write _original_docs.md to MEMORY directory
- [ ] 0.5: Update state.md — mark Phase 0 complete with timestamp
```

---

## Inputs and Outputs

| Direction | File | Location | Description |
|---|---|---|---|
| **Input** | `state.md` | `~/.claude/MEMORY/llm-docs/<repo-slug>/` | Repo path, slug, phase progress |
| **Input** | Codebase | Target repo on disk | All source files — read-only |
| **Output** | `_original_docs.md` | `~/.claude/MEMORY/llm-docs/<repo-slug>/` | Complete documentation assessment |

This phase reads from the target repo and writes exclusively to the MEMORY directory. No files in the target repo are created or modified.

---

## Updating state

After completing **each numbered step** below, immediately update `state.md`:

1. Mark the step's checkbox `[x]` in the Phase 0 checklist
2. Update the `updated:` timestamp

Do not batch state updates. If context is lost between steps, the recovery protocol relies on `state.md` being current. A completed step with no state update will be repeated on resume.

---

## Pre-check (Step 0.0)

If `~/.claude/MEMORY/llm-docs/<repo-slug>/_original_docs.md` already exists, this phase has already been completed in a previous run. **Mark Phase 0 complete in state.md** — check all Phase 0 sub-steps as done and add a completion timestamp. Then report to the orchestrator that Phase 0 can be skipped. Do not overwrite the existing assessment.

Update `state.md`: mark step 0.0 complete.

---

## Step 1: Find all documentation (Step 0.1)

Search the repository for every file that serves as documentation. Cast a wide net — documentation lives in many places and takes many forms:

- **Root-level docs:** `README.md`, `CONTRIBUTING.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `SECURITY.md`, or similar
- **LLM agent instructions:** `CLAUDE.md`, `.github/copilot-instructions.md`, `.cursorrules`, `.cursor/rules/*.md`, or similar
- **Documentation directories:** `docs/`, `wiki/`, `documentation/`, `guides/`, or similar
- **Module-level READMEs:** `README.md` files in subdirectories (list them, but batch-assess — see Step 3)
- **Architecture Decision Records:** `adr/`, `decisions/`, or similar
- **API documentation:** OpenAPI/Swagger specs, GraphQL schema docs, `api-docs/`, or similar
- **Environment documentation:** `.env.example`, `.env.template`, `.env.local.example`
- **Inline config documentation:** Significant comment blocks in CI/CD configs, Docker configs, or build configs that serve as documentation
- **Domain context:** `docs/llm/domain-context.md` — if this exists from a previous llm-docs run, assess its reliability alongside other docs. This file is consumed by Phase D to determine whether the domain interview can be skipped. Pay special attention to the `Last interview` timestamp — domain context older than 6 months may be stale even if file paths within it are still correct.

Exclude generated documentation output (e.g., TypeDoc output in a `docs/api/` that's gitignored, Javadoc output, auto-generated API reference from build tools). If you're unsure whether docs are generated, check `.gitignore` and look for a generation script — generated docs are typically gitignored and have a build step.

Exclude files in `node_modules`, `.git`, `dist`, `build`, `.next`, `__pycache__`, `.turbo`, `.cache`, and other dependency/build output directories.

Update `state.md`: mark step 0.1 complete.

---

## Step 2: Read and categorise each file (Step 0.2)

For each documentation file found, read it fully and record:

- **Path:** exact file path
- **Type:** one of: `project-overview` | `architecture` | `module-readme` | `contributing-guide` | `llm-instructions` | `api-docs` | `environment-docs` | `adr` | `changelog` | `other`
- **Scope:** `whole-project` | `specific-module` | `specific-topic`
- **Topics covered:** brief list of what the doc addresses (e.g., "tech stack, repo structure, dev setup, testing approach")
- **Last updated:** check `git log -1 --format="%ai" -- <path>` for the last commit date. Note how this compares to overall repo activity — a doc last updated 2 years ago in an actively developed repo is likely stale.

### Module-level READMEs at scale

If the repo has more than 10 module-level READMEs, you do not need to deeply assess each one individually. Instead:
1. Read them all
2. Group them by quality pattern (e.g., "12 READMEs follow a consistent template, 3 are stubs, 2 are detailed")
3. Deeply assess 2-3 representative examples from each quality group
4. Assign the group confidence based on the representative samples

**Contradiction warning:** During batch assessment, watch for contradictions within groups. If READMEs in the same quality group make conflicting claims about the same module, component, or responsibility, note the conflict explicitly in `_original_docs.md`. Do not assign a single confidence score to a group with internal contradictions — split the conflicting READMEs into separate assessments.

### Parallelisation for large repos

If the repo contains **50 or more documentation files**, you may dispatch parallel subagents to read and categorise files concurrently. Split the work by directory tree — one subagent per top-level directory that contains documentation files. Each subagent:

1. Receives a list of file paths to read within its assigned directory tree
2. Reads each file fully and records path, type, scope, topics covered, and last updated
3. Writes its findings to `~/.claude/MEMORY/llm-docs/<repo-slug>/_discover_<dirname>.md`

When all subagents complete, merge their output files into a single categorised list and delete the per-directory working files. Continue to Step 3 with the merged results.

**If a subagent fails** to produce its `_discover_<dirname>.md` file: re-dispatch once with the same directory scope. If it fails again, fall back to sequential processing for that directory — read and categorise its docs yourself. Log the failure as a note in `state.md` under Phase 0.

Use `sonnet` for these subagents — the task is mechanical reading and categorisation.

Update `state.md`: mark step 0.2 complete.

---

## Step 3: Assess reliability (Step 0.3)

For each documentation file (or group, for batch-assessed module READMEs), **spot-check a sample of its verifiable claims** against the actual codebase. You are establishing a confidence level, not doing a full audit.

**Check up to 10 claims per file**, prioritising:
1. **File paths mentioned** — do they exist?
2. **Commands mentioned** — are they in `package.json` scripts, `Makefile`, CI config, or equivalent?
3. **Tech stack claims** — do they match actual dependencies in config files?
4. **Architecture claims** — do they match actual directory structure and imports?
5. **Environment variable names** — do they match `.env.example` or actual usage in code?
6. **API endpoints or routes** — do they match actual route definitions?

### Confidence scoring

- **high:** Most claims verified (>80%), doc appears actively maintained (recent updates relative to repo activity), content aligns with current codebase structure and code
- **medium:** Some claims verified (50-80%), doc may be partially stale, core facts are correct but details have drifted (e.g., file paths slightly wrong, commands missing newer additions)
- **low:** Many claims wrong or stale (<50% verified), doc appears unmaintained, significant disconnect from current codebase (e.g., references removed files, describes old architecture)
- **unscored:** Doc makes few verifiable claims (e.g., conceptual overview, changelog, ADR) — cannot meaningfully assess accuracy, but may still provide useful context

**Sampling limitation:** Confidence scores are based on spot-checking up to 10 claims per doc — not an exhaustive audit. A doc scored `high` may still contain incorrect claims that weren't in the sample. Record the number of claims checked vs. total verifiable claims for each doc so that later phases can judge the sampling depth. Example: `Claims checked: 8/8 (all verifiable claims)` is stronger than `Claims checked: 10/47 (21% sample)`.

### What makes a doc unreliable

Watch for these red flags beyond just wrong claims:
- References to files/directories that no longer exist
- Tech stack descriptions that don't match current `package.json` / config
- Architecture descriptions that don't match current directory structure
- Commands that aren't in any script/config file
- Environment variables that don't appear in the actual codebase
- "Coming soon" or "TODO" sections that suggest the doc was never completed

Update `state.md`: mark step 0.3 complete.

---

## Step 4: Write `_original_docs.md` (Step 0.4)

Write the assessment to `~/.claude/MEMORY/llm-docs/<repo-slug>/_original_docs.md`:

```markdown
# Original Documentation Assessment

## Summary
- Documentation files found: N
- High confidence: N
- Medium confidence: N
- Low confidence: N
- Unscored: N
- Well-documented areas: [list topics/areas that have reliable existing docs]
- Undocumented areas: [list major areas of the codebase with no documentation at all]
- Domain context file: exists | missing
- Domain context confidence: high | medium | low | n/a (if missing)
- Domain context last interview: [ISO date from file, or n/a]

## Baseline Recommendations

Subsequent phases should:
- **Trust as starting facts:** [list high-confidence files and what topics each covers reliably]
- **Use with caution:** [list medium-confidence files — note what's reliable vs. suspect in each]
- **Do not build on:** [list low-confidence files — verify all claims independently against source code]
- **Explore from scratch:** [list areas with no existing documentation]
- **Domain interview:** [needed — no domain-context.md exists | skip — domain-context.md exists, is high-confidence, and interview is within 6 months | recommended — domain-context.md exists but is stale or low-confidence]

## File Assessments

### `path/to/file.md`
- **Confidence:** high | medium | low | unscored
- **Type:** [type]
- **Scope:** [scope]
- **Topics covered:** [brief list]
- **Last updated:** [date from git log]
- **Claims checked:** N verified / N checked
- **Issues found:** [specific stale/wrong claims, or "none found"]
- **Reliable for:** [which aspects of the codebase this doc can be trusted on]

[repeat for each file, or group for batch-assessed module READMEs]
```

Update `state.md`: mark step 0.4 complete, then mark Phase 0 complete with timestamp (step 0.5).

---

## Edge cases

**No documentation exists at all:** This is a valid outcome. Write `_original_docs.md` with zero files listed, note that all areas are undocumented, and the baseline recommendation is "explore everything from scratch." Phase 1 will have no starting facts and must rely entirely on source code exploration.

**Hundreds of markdown files:** Prioritise assessment of: (1) root-level docs, (2) LLM instruction files, (3) main docs/ directory, (4) top-level module READMEs. Use batch-assessment for the rest. Focus your detailed assessment time on the docs most likely to be used as a baseline. Use parallel subagents for the reading and categorisation step if there are 50+ files — see the parallelisation note in Step 2.

**Shallow git clone (no history):** If `git log` fails, note "unable to determine last update date" and rely on content-based assessment only.

---

## Rules

- **Read every doc you find.** Do not skip files because of their name or location.
- **Check claims against actual code.** Do not assess reliability based on how professional the doc looks — verify against the codebase.
- **Be honest about confidence.** A polished doc that references files that no longer exist is low confidence. A rough README that accurately describes current code is high confidence.
- **Note what's missing.** The gaps in documentation are as important as the documentation itself — they tell Phase 1 where to focus original exploration.
- **Do not modify any existing files.** This phase is discovery and assessment only.
