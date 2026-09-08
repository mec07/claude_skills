# TechDebt Setup

Most of what this skill needs is derived at runtime. Three things cannot be:
which Jira project tech debt goes in, which board to check for duplicates, and
which epic to file under. Those describe a team's Jira, so they come from you.

## Config file

`~/.claude/techdebt/config.json` — outside the repo, so nothing about your Jira
is committed and `install.sh --check` does not see it as drift.

```json
{
  "project": "ABC",
  "board_id": 361,
  "parent_epic": "ABC-1234",
  "issue_type": "Story",
  "priority": "Lowest"
}
```

| Key | Required | Meaning |
|-----|----------|---------|
| `project` | yes | Jira project key that tech debt is filed under |
| `board_id` | no | Board scanned for duplicates. Omit to search the project instead |
| `parent_epic` | no | Epic new tickets are linked to. Omit for no parent |
| `issue_type` | no | Defaults to `Task`, or `Story` if the project has no Task type |
| `priority` | no | Defaults to the project's lowest priority |

`issue_type` and `priority` are stored as **names, not ids**. Ids differ per
project and a stale one fails with an unhelpful error; the name is resolved to an
id at creation time via `getJiraProjectIssueTypesMetadata`.

## First run

When the config is missing, do not guess and do not fail. Ask, then write it:

1. List the projects the user can see with `getVisibleJiraProjects` and ask which
   one tech debt belongs in.
2. Ask for the parent epic, offering "none" — many teams do not use one.
3. Ask for the board id, offering "none" — without it, duplicate detection
   searches the project by JQL instead, which works fine and is only slower.
4. Write `~/.claude/techdebt/config.json` and say where it went.

Never write a partially-filled config. If the user abandons the questions, create
the ticket for that run using the answers given and leave the file unwritten.

## Derived, never stored

| Value | Resolved from |
|-------|---------------|
| Jira site / cloud id | `getAccessibleAtlassianResources` |
| Assignee | `currentUser()` in JQL, or `atlassianUserInfo` for the account id |
| Issue type id | `getJiraProjectIssueTypesMetadata` for the configured project |
| Priority id | The project's priority scheme at creation time |

No account id, email, site URL or token is written into this skill or its config.
