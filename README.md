# claude_skills

A collection of personal [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills.

## Skills

| Skill | Slash Command | Description |
|-------|---------------|-------------|
| **ReviewPR** | `/ReviewPR [PR#]` | Reviews a PR in the repo Claude Code is open in (detected via `git remote`). If no PR number is given, discovers the PR for your current branch. Fetches the diff, analyses changes with `gh` (parallel agents for large PRs), and creates a pending GitHub review with inline comments. You review and submit from the GitHub UI. |
| **Sleep** | `/Sleep <duration> [follow-up]` | Delays execution for a duration, then optionally runs a follow-up skill or prompt. Defaults to seconds like bash (e.g. `30`), or specify a unit: `s`, `m`, `h`, `d` (e.g. `10m`, `1h`, `2d`). |
| **RepoSkills** | `/RepoSkills` | 10-phase pipeline that generates concise, routing-oriented agent skills for any codebase. Produces `.ai/skills/`, `CLAUDE.md`, `AGENTS.md`, and cross-platform routing for Copilot, Cursor, Windsurf, JetBrains, Cline, and Codex. Includes domain interview, adversarial simulation, and living skills that self-improve. |
| ~~llm-docs~~ | ~~`/llm-docs`~~ | *Superseded by RepoSkills.* Preserved for reference — orchestration patterns carried forward. |
| **JIRA** | `/Jira <command>` | Jira integration via Atlassian MCP Server. Fetch, search, create, edit, transition, comment, and worklog via MCP; issue linking via CLI fallback. |
| **TechDebt** | `/TechDebt <description>` | Create a well-formed Jira tech debt ticket from a quick description, with duplicate detection, without leaving your flow. |
| **Worktree** | `/Worktree <ticket>` | Spin up isolated git worktrees for Jira tickets. Works in the worktree, pushes a branch, creates a draft PR, and reports back. Supports parallel execution. |
| **WIP** | `/WIP` | Work in progress sync. Pulls your open PRs from GitHub (all repos) and Azure DevOps, plus your open Jira tickets, cross-references them, and flags staleness and status mismatches. No configuration — every identity resolves from the CLIs you are logged into. |
| **STANDUP** | `/STANDUP` | Morning standup prep. Pulls the last 24h from Clockify, Jira, GitHub, and git log and compiles it into a ready-to-use standup format. |
| **CodeReview** | `/CodeReview` | Uncle Bob (Robert C. Martin) style opinionated code review. 5 lenses (Architecture, Type Safety, State Management, Testing, Pragmatics), 4 severity tiers, file:line citations, and a priority table. Supports full codebase or single-file review. |
| **Sensei** | `/sensei [on\|off\|gaps]` | Teaching/mentor mode that guides rather than gives answers. Toggles between doer and guide modes. Uses 5-level adaptive scaffolding (Observer → Full Scaffold), Socratic questioning, the TODO(human) pattern, and spaced retrieval of knowledge gaps. Generates session reports and tracks learning progress. |
| **ModelRouting** | *(always on)* | Routes subagents to the right model (opus/sonnet/haiku) based on task type. Opus for reasoning, sonnet for code, haiku for mechanical tasks. Advisory with deviation policy. |

## Tools

Some skills include standalone tools that can be called from workflows or directly:

| Tool | Skill | Language | Description |
|------|-------|----------|-------------|
| `sleep` | Sleep | Bash + TypeScript (Bun) | Sleep for a duration, output follow-up text to stdout. |
| `Jira.ts` | JIRA | TypeScript (Bun) | Issue linking CLI (fallback — pending Atlassian MCP support). |

## Installation

Requires: `git`, a POSIX-compatible shell (`sh`, `bash`, `zsh`, `dash`).

```bash
git clone git@github.com:mec07/claude_skills.git
cd claude_skills
./install.sh
```

This symlinks all skills into `~/.claude/skills/`. When the JIRA skill is included, the installer also registers the Atlassian MCP server via `claude mcp add` and checks for issue linking credentials. GNU stow is not required.

> **After installation:** If the Atlassian MCP shows "Needs authentication" (check with `claude mcp list`), type `/mcp` inside Claude Code and select `atlassian` to complete the OAuth flow. This manual step is required due to a known issue in Claude Code 2.1.80+ where the OAuth browser flow doesn't trigger automatically.

### Options

```bash
./install.sh                        # Install all skills
./install.sh ReviewPR Sleep         # Install specific skills only
./install.sh --force                # Overwrite existing installations
./install.sh --uninstall            # Uninstall all skills
./install.sh --uninstall llm-docs   # Uninstall a specific skill
./install.sh --check                # Report drift between stow/ and installed skills
./install.sh --force --allow-destroy # Overwrite, setting non-stow files aside, not deleting
```

`--check` exists because `install.sh` symlinks per file rather than linking the skill
directory as a whole. A skill that gains a file after its last install silently lacks that
file until the installer runs again, with nothing to signal it. `--check` reports `MISSING`,
`STALE`, `UNMANAGED`, `ORPHANED` and `FOREIGN` per file and exits non-zero, so it works as a CI
or pre-commit gate.

`--allow-destroy` is the opt-in for setting aside, rather than deleting, files in the
target that did not come from `stow/`: it moves them to a temporary directory and prints
the path, which is worth saving if the files matter. It applies to the paths that clear a
skill directory, meaning `--force` and `--uninstall`. A flagless install tops up in place
and never clears anything, so the flag does nothing there. The installer only ever writes
symlinks and directories, so any other regular file inside an installed skill (aside from
`.DS_Store`) was written by a human and cannot be regenerated. Without this flag the
installer refuses to delete them: it names the files, skips that skill, carries on with
the rest, and exits non-zero at the end.

### Dependencies

The installer itself only needs `git` and a POSIX shell. Individual skills have their own runtime dependencies:

| Dependency | Required by | Install |
|------------|-------------|---------|
| [GitHub CLI](https://cli.github.com/) (`gh`) | ReviewPR, WIP, STANDUP, Worktree | `brew install gh` / [github.com/cli/cli](https://github.com/cli/cli#installation) |
| [Azure CLI](https://learn.microsoft.com/cli/azure/) (`az`) + `azure-devops` extension | WIP (optional — section skipped if absent) | `brew install azure-cli && az extension add --name azure-devops` |
| [Node.js](https://nodejs.org/) (v18+) | JIRA (MCP proxy) | `brew install node` / [nodejs.org](https://nodejs.org/) |
| [Bun](https://bun.sh/) | JIRA (link fallback), Sleep, TechDebt | `curl -fsSL https://bun.sh/install \| bash` |
| [Python 3](https://www.python.org/) | TechDebt, STANDUP, Worktree, installer | Usually pre-installed on macOS/Linux |
| `curl` | TechDebt, STANDUP, Worktree | Usually pre-installed on macOS/Linux |
| `git` | ReviewPR, Worktree, STANDUP | `brew install git` / `apt install git` |

**llm-docs** and **Sleep** have no external dependencies beyond what Claude Code provides (Sleep needs Bun only for its tool script).

### API keys

Some skills need credentials in `~/.claude/.env`:

```bash
JIRA_SITE=https://your-site.atlassian.net   # JIRA issue linking fallback
JIRA_API_TOKEN=...                          # JIRA issue linking fallback
JIRA_EMAIL=...                              # JIRA issue linking fallback
CLOCKIFY_API_KEY=...  # STANDUP (optional)
```

Most Jira operations use the Atlassian MCP Server (OAuth 2.1 — no API tokens needed), including everything TechDebt does. The env vars above are required only by the issue linking CLI fallback, which the MCP does not yet cover. `JIRA_SITE` has no default: no Jira instance is compiled into any skill here. The installer prompts for whatever is missing when installing the JIRA skill.

TechDebt additionally needs to know which project, board and epic tech debt belongs in. That is a property of your team's Jira rather than a credential, so it lives in `~/.claude/techdebt/config.json` — the skill asks on first run and writes it for you. See `stow/TechDebt/Reference/Setup.md`.

## Adding a new skill

1. Create `stow/<SkillName>/SKILL.md` with YAML frontmatter (`name`, `description`).
2. Add any workflows in `stow/<SkillName>/Workflows/` and tools in `stow/<SkillName>/Tools/`.
3. Run `./install.sh <SkillName>`.

## License

MIT
