# claude_skills

A collection of personal [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills.

## Skills

| Skill | Slash Command | Description |
|-------|---------------|-------------|
| **ReviewPR** | `/ReviewPR [PR#]` | Reviews a PR in the repo Claude Code is open in (detected via `git remote`). If no PR number is given, discovers the PR for your current branch. Fetches the diff, analyses changes with `gh` (parallel agents for large PRs), and creates a pending GitHub review with inline comments. You review and submit from the GitHub UI. |
| **Sleep** | `/sleep <duration> [follow-up]` | Delays execution for a duration (`30`, `10m`, `1h`, `2d`), then optionally runs a follow-up skill or prompt. |
| **llm-docs** | `/llm-docs` | 9-phase pipeline that generates comprehensive, LLM-optimised documentation for any codebase. Produces `docs/llm/`, `CLAUDE.md`, and Copilot instructions. |
| **JIRA** | `/Jira <command>` | Jira REST API integration. Fetch tickets, search with JQL, parse Atlassian Document Format descriptions, and create plans from tickets. |
| **TechDebt** | `/TechDebt <description>` | Create a well-formed Jira tech debt ticket from a quick description, with duplicate detection, without leaving your flow. |
| **Worktree** | `/Worktree <ticket>` | Spin up isolated git worktrees for Jira tickets. Works in the worktree, pushes a branch, creates a draft PR, and reports back. Supports parallel execution. |
| **WOP** | `/wop` | Work in Progress sync. Pulls live data from Jira and GitHub, detects staleness and status mismatches, and updates the WIP Obsidian page. |
| **STANDUP** | `/standup` | Morning standup prep. Pulls the last 24h from Clockify, Jira, GitHub, and git log and compiles it into a ready-to-use standup format. |

## Tools

Some skills include standalone tools that can be called from workflows or directly:

| Tool | Skill | Language | Description |
|------|-------|----------|-------------|
| `sleep` | Sleep | Bash + TypeScript (Bun) | Sleep for a duration, output follow-up text to stdout. |
| `Jira.ts` | JIRA | TypeScript (Bun) | Jira REST API CLI: search, get, create, transition tickets. |

## Installation

Requires: `git`, a POSIX-compatible shell (`sh`, `bash`, `zsh`, `dash`).

```bash
git clone git@github.com:mec07/claude_skills.git
cd claude_skills
./install.sh
```

This symlinks all skills into `~/.claude/skills/`. No dependencies beyond the shell — GNU stow is not required.

### Options

```bash
./install.sh                        # Install all skills
./install.sh ReviewPR Sleep         # Install specific skills only
./install.sh --force                # Overwrite existing installations
./install.sh --uninstall            # Uninstall all skills
./install.sh --uninstall llm-docs   # Uninstall a specific skill
```

### Skill-specific dependencies

- **Sleep** and **JIRA** tools require [Bun](https://bun.sh/).
- **JIRA**, **TechDebt**, **WOP**, and **STANDUP** require `JIRA_API_TOKEN` and `JIRA_EMAIL` in `~/.claude/.env`.
- **ReviewPR** and **Worktree** require the [GitHub CLI](https://cli.github.com/) (`gh`).
- **STANDUP** optionally uses a Clockify API key (`CLOCKIFY_API_KEY` in `~/.claude/.env`).

## Adding a new skill

1. Create `stow/<SkillName>/SKILL.md` with YAML frontmatter (`name`, `description`).
2. Add any workflows in `stow/<SkillName>/Workflows/` and tools in `stow/<SkillName>/Tools/`.
3. Run `./install.sh <SkillName>`.

## License

MIT
