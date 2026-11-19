# Host and Auth Resolution

Run this **before** any forge call. "PR" and "MR" are synonyms.

Also read `FetchPR/Reference/HostAndAuth.md` for fetch-side details. This file covers **write** (pending draft) rules.

## 1. Detect host + probe auth

Same rules as FetchPR:

1. Detect forge from `git remote get-url origin` (`github.com` → GitHub; `gitlab.com` / hostname contains `gitlab` → GitLab; ambiguous → probe CLIs or ask once).
2. Probe: `gh auth status` (GitHub), `glab auth status` + GitLab MCP namespace `plugin-gitlab-GitLab` (GitLab).
3. If nothing is authenticated for the detected forge, stop and ask the user to auth.

## 2. Interface preference (write)

| Forge | Pending / draft write path |
|-------|----------------------------|
| **GitHub** | `gh api` Create Review **without** `event` → `PENDING`. Never submit (`APPROVE` / `REQUEST_CHANGES` / `COMMENT`) from this skill. |
| **GitLab** | Prefer `glab mr note draft create` (experimental draft notes). If that subcommand fails, try Draft Notes REST via `glab api` `POST projects/:id/merge_requests/:iid/draft_notes`. **Never** publish (`glab mr note draft publish`, `bulk_publish`, or MCP `submit_review` / `create_diff_note` / `create_note`). Those post under the user's name immediately. |
| **GitLab drafts unavailable** | Use `Reference/ConversationFallback.md` — lay out every comment in chat. Do not publish as a substitute. |

## 3. Why MCP must not write reviews for this skill

Official GitLab MCP `save_merge_request_review` methods (`create_diff_note`, `submit_review`, etc.) create **published** notes. Draft-note MCP support is not available on the official server yet. Using MCP for write would violate the "user controls submission" contract.

MCP remains valid for **fetch** when `glab` is not authed (see FetchPR HostAndAuth).

## 4. Auth prompt copy (GitLab write)

If drafts need `glab` and it is missing:

> Draft (pending) MR comments require `glab` (`glab auth login`). The GitLab MCP can fetch MR context but cannot stage unpublished draft notes. Without `glab`, I will put the full review in this chat using the conversation fallback format instead of posting anything to GitLab.
