# Phase 0: Discover and Assess Existing Documentation

Before generating any new documentation, you must understand what documentation already exists in this repository and how reliable it is. This phase produces a single index file that all subsequent phases use as their starting point.

**This phase is read-only. Do not modify any existing files.** Your only output is `docs/llm/_original_documentation.md`.

---

## Pre-check

If `docs/llm/_original_documentation.md` already exists, this phase has already been completed in a previous run. **Report to the orchestrator that Phase 0 can be skipped and proceed directly to Phase 1.** Do not overwrite the existing assessment.

---

## Step 1: Find all documentation

Search the repository for every file that serves as documentation. Cast a wide net — documentation lives in many places and takes many forms:

- **Root-level docs:** `README.md`, `CONTRIBUTING.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `SECURITY.md`, or similar
- **LLM agent instructions:** `CLAUDE.md`, `.github/copilot-instructions.md`, `.cursorrules`, `.cursor/rules/*.md`, or similar
- **Documentation directories:** `docs/`, `wiki/`, `documentation/`, `guides/`, or similar
- **Module-level READMEs:** `README.md` files in subdirectories (list them, but batch-assess — see Step 3)
- **Architecture Decision Records:** `adr/`, `decisions/`, or similar
- **API documentation:** OpenAPI/Swagger specs, GraphQL schema docs, `api-docs/`, or similar
- **Environment documentation:** `.env.example`, `.env.template`, `.env.local.example`
- **Inline config documentation:** Significant comment blocks in CI/CD configs, Docker configs, or build configs that serve as documentation

Exclude generated documentation output (e.g., TypeDoc output in a `docs/api/` that's gitignored, Javadoc output, auto-generated API reference from build tools). If you're unsure whether docs are generated, check `.gitignore` and look for a generation script — generated docs are typically gitignored and have a build step.

Exclude files in `node_modules`, `.git`, `dist`, `build`, `.next`, `__pycache__`, `.turbo`, `.cache`, and other dependency/build output directories.

---

## Step 2: Read and categorise each file

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

---

## Step 3: Assess reliability

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

### What makes a doc unreliable

Watch for these red flags beyond just wrong claims:
- References to files/directories that no longer exist
- Tech stack descriptions that don't match current `package.json` / config
- Architecture descriptions that don't match current directory structure
- Commands that aren't in any script/config file
- Environment variables that don't appear in the actual codebase
- "Coming soon" or "TODO" sections that suggest the doc was never completed

---

## Step 4: Write `docs/llm/_original_documentation.md`

Create the `docs/llm/` directory if it doesn't exist. Then write:

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

## Baseline Recommendations

Subsequent phases should:
- **Trust as starting facts:** [list high-confidence files and what topics each covers reliably]
- **Use with caution:** [list medium-confidence files — note what's reliable vs. suspect in each]
- **Do not build on:** [list low-confidence files — verify all claims independently against source code]
- **Explore from scratch:** [list areas with no existing documentation]

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

---

## Edge cases

**No documentation exists at all:** This is a valid outcome. Write `_original_documentation.md` with zero files listed, note that all areas are undocumented, and the baseline recommendation is "explore everything from scratch." Phase 1 will have no starting facts and must rely entirely on source code exploration.

**Hundreds of markdown files:** Prioritise assessment of: (1) root-level docs, (2) LLM instruction files, (3) main docs/ directory, (4) top-level module READMEs. Use batch-assessment for the rest. Focus your detailed assessment time on the docs most likely to be used as a baseline.

**Shallow git clone (no history):** If `git log` fails, note "unable to determine last update date" and rely on content-based assessment only.

---

## Rules

- **Read every doc you find.** Do not skip files because of their name or location.
- **Check claims against actual code.** Do not assess reliability based on how professional the doc looks — verify against the codebase.
- **Be honest about confidence.** A polished doc that references files that no longer exist is low confidence. A rough README that accurately describes current code is high confidence.
- **Note what's missing.** The gaps in documentation are as important as the documentation itself — they tell Phase 1 where to focus original exploration.
- **Do not modify any existing files.** This phase is discovery and assessment only.
