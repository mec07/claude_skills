# Runtime Resolution

No identity, organisation, repository, project or ticket prefix is written into
this skill. Everything resolves from the CLIs the user is already logged into.

| Value | Resolved from |
|-------|---------------|
| GitHub user | `@me` in search qualifiers |
| GitHub repos | none — `gh search prs` spans every repo you can see |
| Azure user | `az account show --query "user.name" -o tsv` |
| Azure org/project | `az devops configure -l` defaults |
| Jira user | `currentUser()` in JQL |
| Jira projects | `getVisibleJiraProjects` at runtime |

## Why each one matters

**GitHub repos.** Using `gh pr list --repo X` would tie the skill to one
repository. `gh search prs` has no repo scope and returns everything visible,
which is the point.

**Reviews you owe are a first-class source, not a footnote.** A large part of the
work is reviewing other people's changes, and those are the items where somebody
else is blocked waiting on you. `--review-requested=@me` on GitHub and
`--reviewer "$AZ_USER"` on Azure are queried alongside the authored-PR queries,
and the output lists them first. See the bucket rules in `Workflows/Sync.md`.

**Jira projects.** Ticket keys are found by shape, `[A-Z][A-Z0-9]+-[0-9]+`, then
validated against the project list. Filtering by the prefixes seen in the
assigned-ticket query instead would hide any PR citing a project you have no open
ticket in — a tech-debt or escalation project, for instance. The project list is
the correct authority and costs one call.

**Jira status.** Workflow status names are project-specific ("In Development",
"New", "Completed"), so match on the status *category* — To Do, In Progress,
Done — and report the project's own status text back to the user.
