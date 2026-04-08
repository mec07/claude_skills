# claude_skills

A collection of personal [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills.

## Skills

| Skill | Slash Command | Description |
|-------|---------------|-------------|
| **ReviewPR** | `/ReviewPR [PR#]` | Reviews a PR in the repo Claude Code is open in (detected via `git remote`). If no PR number is given, discovers the PR for your current branch. Fetches the diff, analyses changes with `gh` (parallel agents for large PRs), and creates a pending GitHub review with inline comments. You review and submit from the GitHub UI. |
| **Sleep** | `/sleep <duration> [follow-up]` | Delays execution for a duration, then optionally runs a follow-up skill or prompt. Defaults to seconds like bash (e.g. `30`), or specify a unit: `s`, `m`, `h`, `d` (e.g. `10m`, `1h`, `2d`). |
| **llm-docs** | `/llm-docs` | 9-phase pipeline that generates comprehensive, LLM-optimised documentation for any codebase. Produces `docs/llm/`, `CLAUDE.md`, and Copilot instructions. |
| **JIRA** | `/Jira <command>` | Jira integration via Atlassian MCP Server. Fetch, search, create, edit, transition, comment, and worklog via MCP; issue linking via CLI fallback. |
| **TechDebt** | `/TechDebt <description>` | Create a well-formed Jira tech debt ticket from a quick description, with duplicate detection, without leaving your flow. |
| **Worktree** | `/Worktree <ticket>` | Spin up isolated git worktrees for Jira tickets. Works in the worktree, pushes a branch, creates a draft PR, and reports back. Supports parallel execution. |
| **WOP** | `/wop` | Work in Progress sync. Pulls live data from Jira and GitHub, detects staleness and status mismatches, and updates the WIP Obsidian page. |
| **STANDUP** | `/standup` | Morning standup prep. Pulls the last 24h from Clockify, Jira, GitHub, and git log and compiles it into a ready-to-use standup format. |
| **CodeReview** | `/CodeReview` | Uncle Bob (Robert C. Martin) style opinionated code review. 5 lenses (Architecture, Type Safety, State Management, Testing, Pragmatics), 4 severity tiers, file:line citations, and a priority table. Supports full codebase or single-file review. |
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
```

### Dependencies

The installer itself only needs `git` and a POSIX shell. Individual skills have their own runtime dependencies:

| Dependency | Required by | Install |
|------------|-------------|---------|
| [GitHub CLI](https://cli.github.com/) (`gh`) | ReviewPR, WOP, STANDUP, Worktree | `brew install gh` / [github.com/cli/cli](https://github.com/cli/cli#installation) |
| [Node.js](https://nodejs.org/) (v18+) | JIRA (MCP proxy) | `brew install node` / [nodejs.org](https://nodejs.org/) |
| [Bun](https://bun.sh/) | JIRA (link fallback), Sleep, TechDebt | `curl -fsSL https://bun.sh/install \| bash` |
| [Python 3](https://www.python.org/) | TechDebt, STANDUP, Worktree, installer | Usually pre-installed on macOS/Linux |
| `curl` | TechDebt, STANDUP, Worktree | Usually pre-installed on macOS/Linux |
| `git` | ReviewPR, Worktree, STANDUP | `brew install git` / `apt install git` |

**llm-docs** and **Sleep** have no external dependencies beyond what Claude Code provides (Sleep needs Bun only for its tool script).

### API keys

Some skills need credentials in `~/.claude/.env`:

```bash
JIRA_API_TOKEN=...    # JIRA issue linking fallback, TechDebt
JIRA_EMAIL=...        # JIRA issue linking fallback, TechDebt
CLOCKIFY_API_KEY=...  # STANDUP (optional)
```

Most Jira operations now use the Atlassian MCP Server (OAuth 2.1 — no API tokens needed). The env vars above are only required for the issue linking CLI fallback and the TechDebt skill's direct API calls. The installer will prompt for missing credentials when installing the JIRA skill.

## Adding a new skill

1. Create `stow/<SkillName>/SKILL.md` with YAML frontmatter (`name`, `description`).
2. Add any workflows in `stow/<SkillName>/Workflows/` and tools in `stow/<SkillName>/Tools/`.
3. Run `./install.sh <SkillName>`.

## License

MIT
