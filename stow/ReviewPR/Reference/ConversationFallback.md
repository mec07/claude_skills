# Conversation Fallback

Use this layout whenever a pending/draft review **cannot** be opened on the forge:

- GitLab: `glab` missing/unauthed, experimental `mr note draft` fails, or Draft Notes API rejects positions
- GitHub: Create-Review API fails entirely
- Partial failure: any comment that could not be attached as a draft/pending inline note

When pending/draft posting **succeeds**, do **not** dump comments into chat — short summary only (see Review workflow Step 11).

## Lead-in

Start with one line naming the reason, for example:

```text
Couldn't open a draft review on GitLab; comments below for you to paste or submit manually.
```

Also write the full review to `/tmp/mr-review-{IID}.md` or `/tmp/pr-review-{NUMBER}.md` as a local backup.

## Per-comment layout (mandatory)

For **each** comment, in order, emit exactly this structure. Use a horizontal rule plus blank-line padding **between** comments.

```text
filename: path/to/file.ts
line: 42

  40 | two lines above
  41 | one line above
  42 | <<< comment line >>>
  43 | one line below
  44 | two lines below

❓ The comment body itself in ReviewPR voice...

────────────────────────────────────────

```

### Rules

1. **filename** — path relative to repo root (same path used for the draft note).
2. **line** — line number in the **new** file version (the line the comment targets).
3. **Code context** — exactly **two lines above**, the comment line, **two lines below**, from the new file version.
   - Near the top: use `(file start)` for missing lines above.
   - Near the end: use `(file end)` for missing lines below.
4. **Mark the comment line** with `<<<` / `>>>` around the source text on that line only.
5. **Comment body** — ReviewPR voice (emoji prefix, collaborative, short). Same body you would have posted as a draft.
6. **Separator** — a line of `─` characters, then a blank line, before the next comment (omit after the last comment if you prefer; padding before the next comment is required).

### Example (two comments)

```text
Couldn't open a draft review on GitLab; comments below for you to paste or submit manually.

filename: src/handlers/auth.ts
line: 42

  40 |   const session = await loadSession(req)
  41 |   const user = session.user
  42 | <<< const id = user.id >>>
  43 |   return respond(id)
  44 | }

❓ What happens here if `user` is null, like from a guest session? Would a guard before `user.id` be worth it?

────────────────────────────────────────

filename: src/handlers/auth.ts
line: 88

  86 |   } catch (err) {
  87 |     log.warn(err)
  88 | <<<     return null >>>
  89 |   }
  90 | }

💭 Returning null here swallows the failure for callers. Was that intentional, or should it propagate?

────────────────────────────────────────
```
