# ReviewPR — Examples

**Example 1: Review a PR/MR by number**
```
User: "/ReviewPR 5001"
-> Detects forge + repo from git remote; probes auth
-> Fetches metadata and diff (FetchPR / glab / MCP)
-> Analyzes all changes (parallel agents for large changes)
-> Creates PENDING review (GitHub) or draft notes (GitLab)
-> Shows summary in conversation
-> User goes to GitHub/GitLab to review, edit, and submit/publish
```

**Example 2: Review current branch's PR/MR**
```
User: "/ReviewPR"
-> Detects current branch, finds associated PR/MR
-> Same analysis and pending/draft flow
```

**Example 3: Review with context**
```
User: "/ReviewPR 42 — this is a database migration"
-> Uses context to focus analysis on migration safety
-> Inline comments prioritize data integrity, rollback, schema issues
```

**Example 4: GitLab without working drafts**
```
User: "/ReviewPR 88" on a GitLab remote where glab drafts fail
-> Completes analysis
-> Cannot stage draft notes
-> Lays out every comment in chat (filename, line, ±2 context, body, separators)
-> Does NOT publish notes via MCP as a workaround
```
