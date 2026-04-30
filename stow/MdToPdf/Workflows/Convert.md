# MdToPdf — Convert

Convert a markdown file to a styled A4 PDF. Self-contained: uses `reportlab` + stdlib only. No pandoc, no browser, no network.

## Tool

**`md_to_pdf.py`** — reads a `.md` file, writes a `.pdf`.

```bash
python3 ~/.claude/skills/MdToPdf/Tools/md_to_pdf.py <input.md> [output.pdf]
```

- If `output.pdf` is omitted, writes alongside the input with the `.pdf` extension.
- Input path is expanded (`~` supported) and resolved to an absolute path.

## How to Execute

1. Parse arguments. The first token is the input markdown path. An optional second token is the output PDF path.
2. **Ensure reportlab is installed** (one-time):
   ```bash
   python3 -c "import reportlab" 2>/dev/null || pip3 install --user --break-system-packages --quiet reportlab
   ```
3. Run the converter via Bash:
   ```bash
   python3 ~/.claude/skills/MdToPdf/Tools/md_to_pdf.py <input.md> [output.pdf]
   ```
4. Report the output path and file size from the tool's stdout.

## Supported Markdown

| Element | Syntax |
|---|---|
| Headings | `# H1` through `###### H6` (rendered H1-H4 distinctly; H5/H6 render as H4) |
| Bold | `**text**` or `__text__` |
| Italic | `*text*` or `_text_` |
| Inline code | `` `code` `` |
| Links | `[text](url)` |
| Unordered list | `- item`, `* item`, `+ item` |
| Ordered list | `1. item` |
| Fenced code block | ```` ```...``` ```` |
| Blockquote | `> quoted text` |
| Horizontal rule | `---`, `***`, `___` |

## Limitations

- No tables (reportlab Table support would be a future addition).
- No images (reportlab can embed them, but markdown `![alt](url)` parsing is not implemented).
- No nested lists (single level only).
- Code blocks are rendered without syntax highlighting.

## Examples

| Input | Action |
|-------|--------|
| `/MdToPdf ~/notes/report.md` | Writes `~/notes/report.pdf` |
| `/MdToPdf ./README.md /tmp/out.pdf` | Writes `/tmp/out.pdf` |
| `/MdToPdf ~/.claude/MEMORY/WORK/20260424-130500_bupropion-rage-resolution-mechanism/RESEARCH.md` | Writes `RESEARCH.pdf` in same directory |
