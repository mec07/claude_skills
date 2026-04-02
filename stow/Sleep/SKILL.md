---
name: Sleep
description: Delay execution for a specified duration, then optionally execute a follow-up skill or prompt. Supports seconds (default), minutes (m), hours (h), days (d). USE WHEN sleep, wait, delay, timer, run later, after delay.
---

## Customization

**Before executing, check for user customizations at:**
`~/.claude/PAI/USER/SKILLCUSTOMIZATIONS/Sleep/`

If this directory exists, load and apply any PREFERENCES.md, configurations, or resources found there. These override default behavior. If the directory does not exist, proceed with skill defaults.

# Sleep

Delay execution for a specified duration, then execute a follow-up command — either a skill invocation or a verbal prompt.

## Tool

**`sleep`** — Sleep for a duration, output follow-up text to stdout.

```bash
bun run ~/.claude/skills/Sleep/Tools/sleep.ts <duration> [follow-up...]
```

Duration formats: `3600` (seconds, default), `10s`, `30m`, `1h`, `2d`.

Status messages go to stderr. Follow-up text (if any) goes to stdout.

## How to Execute

1. Parse the user's `/sleep` arguments. The first token is the duration; everything after is the follow-up.
2. Run the sleep tool via Bash:
   ```bash
   ~/.claude/skills/Sleep/Tools/sleep <duration> [follow-up...]
   ```
   - For durations **under 10 minutes**: run in foreground with `timeout` set to `(seconds * 1000) + 5000`.
   - For durations **10 minutes or longer**: run with `run_in_background: true`. You will be notified on completion — do NOT poll.
3. When the tool completes, read stdout:
   - **If stdout is empty**: report completion.
   - **If stdout starts with `/`**: invoke that skill using the Skill tool (e.g., stdout is `/ReviewPR 1` → `Skill(skill: "ReviewPR", args: "1")`).
   - **If stdout is any other text**: process it as if the user had typed it as a new message.

## Examples

| Input | Duration | Follow-up |
|-------|----------|-----------|
| `/sleep 30` | 30 seconds | (none) |
| `/sleep 1h` | 1 hour | (none) |
| `/sleep 1h /ReviewPR 1` | 1 hour | Invoke `/ReviewPR 1` |
| `/sleep 10m now check deploy status` | 10 minutes | Process "now check deploy status" |
| `/sleep 3600` | 1 hour | (none) |
| `/sleep 2d /Email process` | 2 days | Invoke `/Email process` |
