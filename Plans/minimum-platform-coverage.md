# Minimum Files for Complete Platform Coverage

## The Coverage Matrix

Which platforms does each file cover?

| File | Claude Code | Copilot | Cursor | Windsurf | Cline | JetBrains | Codex CLI | Zed | Aider | Amazon Q |
|------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| `CLAUDE.md` | **ROOT** | - | - | - | - | - | - | fallback | - | - |
| `AGENTS.md` | - | partial | - | - | - | fallback | **ROOT** | fallback | fallback | - |
| `.github/copilot-instructions.md` | - | **ROOT** | - | - | - | - | - | fallback | - | - |
| `.cursorrules` | - | - | legacy | - | - | - | - | fallback | - | - |
| `.cursor/rules/*.mdc` | - | - | **ROUTING** | - | - | - | - | - | - | - |
| `.windsurfrules` | - | - | - | legacy | - | - | - | fallback | - | - |
| `.windsurf/rules/*.md` | - | - | - | **ROUTING** | - | - | - | - | - | - |
| `.clinerules/` | - | - | - | - | **ROUTING** | - | - | fallback | - | - |
| `.claude/rules/*.md` | **ROUTING** | - | - | - | - | - | - | - | - | - |
| `.aiassistant/rules/*.md` | - | - | - | - | - | **ROUTING** | - | - | - | - |
| `.amazonq/rules/*.md` | - | - | - | - | - | - | - | - | - | **ROOT** |
| `docs/llm/*.md` | read | read | read | read | read | read | read | read | read | read |

**ROOT** = auto-loaded as primary context file
**ROUTING** = conditional loading based on file patterns
**fallback** = Zed reads it if higher-priority files don't exist
**read** = agent can read it when directed to, but not auto-loaded

## Minimum File Set: 3 Files Cover ALL Platforms

```
1. AGENTS.md        → Codex CLI (root), Zed (fallback), JetBrains (fallback), Aider (fallback)
2. CLAUDE.md         → Claude Code (root), Zed (fallback if no .rules)
3. .github/copilot-instructions.md → Copilot (root), Zed (fallback)
```

**That's it.** Three files cover the auto-load for every platform that supports auto-loading.

But wait — what about Cursor, Windsurf, Cline, Amazon Q? They have their OWN file formats:
- **Cursor** reads `.cursorrules` OR `.cursor/rules/*.mdc` — neither of the 3 above
- **Windsurf** reads `.windsurfrules` OR `.windsurf/rules/*.md` — neither of the 3 above
- **Cline** reads `.clinerules` — neither of the 3 above
- **Amazon Q** reads `.amazonq/rules/*.md` — neither of the 3 above

So for truly COMPLETE auto-load coverage, we need:

## Complete Auto-Load Coverage: 7 Files

| # | File | Platforms Covered | Content |
|---|------|-------------------|---------|
| 1 | `AGENTS.md` | Codex, Zed, JetBrains, Aider (emerging standard) | Self-contained: project overview + routing index + conventions |
| 2 | `CLAUDE.md` | Claude Code | Pointer: "read docs/llm/overview.md and domain-context.md" |
| 3 | `.github/copilot-instructions.md` | Copilot, Zed | Self-contained: condensed overview + routing index |
| 4 | `.cursorrules` | Cursor (legacy), Zed | Pointer: same as AGENTS.md content |
| 5 | `.windsurfrules` | Windsurf (legacy), Zed | Pointer: same as AGENTS.md content |
| 6 | `.clinerules` | Cline, Zed | Pointer: same as AGENTS.md content |
| 7 | `.amazonq/rules/overview.md` | Amazon Q | Pointer: same as AGENTS.md content |

**The insight: files 4-6 can be IDENTICAL to AGENTS.md in content.** They just have different filenames for different platforms. This is a duplication we accept because it's tiny (one file, ~2k tokens) and gives us universal coverage.

## But There's a Better Way: The AGENTS.md Convergence

Look at what Zed does — it reads 9 formats in priority order. This is the market telling us something: **platforms are converging on reading each other's files.**

If we generate AGENTS.md as our PRIMARY cross-platform file, here's what happens:
- Codex CLI: reads it natively ✅
- Zed: reads it as fallback #7 ✅
- JetBrains: reads it as fallback ✅
- Aider: can be configured to read it ✅
- Claude Code: has its own CLAUDE.md (richer features) ✅
- Copilot: has its own copilot-instructions.md ✅
- Cursor: needs .cursorrules or .cursor/rules/ ❌
- Windsurf: needs .windsurfrules or .windsurf/rules/ ❌
- Cline: needs .clinerules ❌
- Amazon Q: needs .amazonq/rules/ ❌

So the MINIMUM for universal auto-load coverage:

## Recommended: 4 Root Files + Conditional Routing

### Always Generated (4 root files):

| File | Content Strategy | Size |
|------|-----------------|------|
| `AGENTS.md` | **Self-contained master file.** Project overview, tech stack, USE WHEN routing index, key conventions, gotchas summary. The "one file that tells you everything essential." | <4k tokens |
| `CLAUDE.md` | **Pointer + routing.** Points to docs/llm/overview.md and domain-context.md. Includes "before modifying code" checklist. Uses @file imports. | <1k tokens |
| `.github/copilot-instructions.md` | **Condensed version of AGENTS.md** tailored for Copilot's single-file constraint. | <4k tokens |
| `.cursorrules` | **Symlink or copy of AGENTS.md.** Covers Cursor legacy + Zed fallback + Windsurf cross-reading. | = AGENTS.md |

Why `.cursorrules` and not `.windsurfrules`? Because Zed reads `.cursorrules` at priority #2 (before `.windsurfrules` at #3), and Cursor's legacy format is the most widely cross-read.

**Wait — can we do even better?** If `.cursorrules` IS `AGENTS.md` content, and Cline/Windsurf users just need their own filename... we could recommend users create symlinks:
```bash
ln -s AGENTS.md .windsurfrules
ln -s AGENTS.md .clinerules
```
But symlinks are fragile. Better to just generate the copies — they're small.

### Conditionally Generated (per-module routing files):

Only generated if the platform's config directory already exists in the repo:

| Condition | Generate | Content |
|-----------|----------|---------|
| `.cursor/` exists | `.cursor/rules/<module>.mdc` | Frontmatter with `globs: ["<source-path>/**"]` + module doc content |
| `.github/` exists | `.github/instructions/<module>.instructions.md` | Path matching + module doc content |
| `.claude/` exists | `.claude/rules/<module>.md` | Module doc content (Claude Code auto-loads by directory) |
| `.aiassistant/` exists | `.aiassistant/rules/<module>.md` | File pattern type + module doc content |
| `.windsurf/` exists | `.windsurf/rules/<module>.md` | Frontmatter triggers + module doc content |
| `.clinerules/` exists | `.clinerules/<module>.md` | YAML paths frontmatter + module doc content |
| `.amazonq/` exists | `.amazonq/rules/<module>.md` | Module doc content |

## Summary

| Strategy | Root Files | Platform Coverage | Maintenance Cost |
|----------|-----------|------------------|-----------------|
| Minimum (3 files) | AGENTS.md + CLAUDE.md + copilot-instructions.md | 6/10 platforms auto-load | Low |
| Recommended (4 files) | Above + .cursorrules | 7/10 auto-load (Cursor/Zed covered) | Low |
| Complete (7 files) | Above + .windsurfrules + .clinerules + .amazonq/rules/ | 10/10 auto-load | Medium (but files 4-7 are identical content) |
| Complete + routing | 7 root + conditional per-module | 10/10 auto-load + 6 platforms get smart routing | Medium-high |

### Recommendation: Start with "Recommended (4 files)" + detect-and-generate routing

Generate 4 root files always. Generate per-module routing files only for platforms whose config directories already exist. This gives:
- Universal basic coverage (every platform gets at least a root context file)
- Smart routing where available (6 platforms)
- Zero wasted effort on platforms the team doesn't use
- Easy expansion: user installs Windsurf → next llm-docs run detects `.windsurf/` → generates routing files

The AGENTS.md content is the keystone — it's the one file that needs to be genuinely good because it's self-contained and read by the most platforms.
