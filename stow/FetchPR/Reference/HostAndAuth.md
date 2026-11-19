# Host and Auth Resolution

Run this **before** any forge call (FetchPR tools or MCP). "PR" and "MR" are synonyms.

## 1. Detect host

From `git remote get-url origin` (or `--repo`):

| Remote host | Forge |
|-------------|-------|
| `github.com` | GitHub |
| `gitlab.com`, or hostname contains `gitlab` | GitLab |
| Ambiguous self-managed | Probe: `glab repo view` then `gh repo view`; if still unclear, ask the user once |

Nested GitLab groups are valid repo paths: `group/subgroup/project`.

## 2. Probe auth (read-only)

| Forge | Check |
|-------|-------|
| GitHub | `gh auth status` |
| GitLab CLI | `glab auth status` |
| GitLab MCP | `GetDynamicTools` on namespace `plugin-gitlab-GitLab` — usable only when status is **not** `needsAuth` / `error` / `loading` |

## 3. Choose interface (fixed preference)

| Need | Preference |
|------|------------|
| **GitHub** (fetch or write) | `gh` only |
| **GitLab fetch** | Prefer `glab` + `FetchPR/Tools/*.sh`. If `glab` is not authed but GitLab MCP is, fetch the same sections via MCP (`get_merge_request`, diffs, notes/discussions, pipelines) and **do not** call the shell tools. If neither is authed, stop and ask the user to run `glab auth login` **or** authenticate the GitLab MCP in Cursor Settings → Tools & MCP. |
| **GitLab write (pending drafts)** | Owned by ReviewPR — see `ReviewPR/Reference/HostAndAuth.md`. FetchPR is read-only. |

## 4. Auth prompt copy

**GitHub:**
> `gh` is not authenticated. Run `gh auth login`, then retry.

**GitLab (neither interface):**
> Neither `glab` nor the GitLab MCP is authenticated. Authenticate one of them:
> 1. CLI: `glab auth login` (supports GitLab.com and self-managed via host config)
> 2. Cursor: Settings → Tools & MCP → authenticate the GitLab MCP
>
> Prefer `glab` when you have a choice — shell tools and draft notes depend on it.

## 5. MCP-only fetch checklist (GitLab)

When scripts cannot run because only MCP is authed, gather the equivalent of `fetch.sh` / `diff.sh`:

1. MR metadata (title, state, branches, author, labels, diff stats, merge status, web URL)
2. Pipelines / CI status
3. Reviewer / approval state
4. Description body
5. Changed files (+/- if available)
6. Commits (note head SHA / `diff_refs.head_sha`)
7. Notes and discussions (map resolved/outdated as available)
8. Full unified diff (save large diffs to a temp file)

Exit-equivalent: if the MR is closed or merged, stop and ask for a new IID — do not chase successors.
