# HtmlToPdf — Convert

Convert an HTML file to a high-fidelity PDF using Playwright (headless Chromium). Renders CSS, SVG, web fonts, and complex layouts exactly as they appear in the browser.

## Tool

**`html_to_pdf.ts`** — reads an `.html` file, writes a `.pdf`.

```bash
bun run ~/.claude/skills/HtmlToPdf/Tools/html_to_pdf.ts <input.html> [output.pdf] [flags]
```

- If `output.pdf` is omitted, writes alongside the input with the `.pdf` extension.
- Requires Playwright with Chromium browsers installed.

## How to Execute

1. Parse arguments. The first token is the input HTML path. An optional second token is the output PDF path.
2. Run the converter via Bash:
   ```bash
   bun run ~/.claude/skills/HtmlToPdf/Tools/html_to_pdf.ts <input.html> [output.pdf]
   ```
3. Report the output path and file size from the tool's stdout.

## Modes

### Slide Mode (auto-detected)

If the HTML contains elements with `[data-slide]` attributes, slide mode activates automatically:

1. Opens the HTML in headless Chromium at 1280x720 (2x retina)
2. Navigates through each slide (calls `showSlide(n)` if available)
3. Screenshots each slide at full viewport
4. Assembles all screenshots into a multi-page landscape PDF

Force slide mode: `--slides`

### Page Mode (default for non-slide HTML)

Prints the full page as a continuous A4 PDF with 1cm margins and background colors.

Force page mode: `--page`

## Flags

| Flag | Description |
|------|-------------|
| `--slides` | Force slide capture mode |
| `--page` | Force full-page print mode |
| `--width=N` | Viewport width in pixels (default: 1280) |
| `--height=N` | Viewport height in pixels (default: 720) |

## Examples

| Input | Action |
|-------|--------|
| `/HtmlToPdf ~/slides.html` | Auto-detects slides, writes `~/slides.pdf` |
| `/HtmlToPdf ./report.html /tmp/out.pdf` | Writes `/tmp/out.pdf` |
| `/HtmlToPdf slides.html --width=1920 --height=1080` | Capture at 1080p |
| `/HtmlToPdf page.html --page` | Force page mode even if slides detected |

## Dependencies

- `bun` runtime
- `playwright` npm package with Chromium browsers installed
