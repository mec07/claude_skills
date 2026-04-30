#!/usr/bin/env python3
"""Convert a markdown file to a styled PDF using reportlab Platypus.

Usage:
    md_to_pdf.py <input.md> [output.pdf]

If output is omitted, writes alongside the input with a .pdf extension.
Supports: headings (h1-h6), paragraphs, bold, italic, inline code, links,
ordered/unordered lists, fenced code blocks, blockquotes, horizontal rules.
"""
import re
import sys
from pathlib import Path

from reportlab.lib.colors import HexColor
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import (
    HRFlowable,
    ListFlowable,
    ListItem,
    Paragraph,
    Preformatted,
    SimpleDocTemplate,
    Spacer,
)


def md_inline_to_rl(text: str) -> str:
    """Convert inline markdown (bold, italic, code, links) to ReportLab mini-HTML."""
    text = text.replace("&", "&amp;")
    text = text.replace("<", "&lt;").replace(">", "&gt;")

    # Inline code `code`
    text = re.sub(
        r"`([^`]+)`",
        r'<font face="Courier" color="#b00040">\1</font>',
        text,
    )
    # Bold **text** or __text__
    text = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", text)
    text = re.sub(r"__([^_]+)__", r"<b>\1</b>", text)
    # Italic *text* or _text_
    text = re.sub(r"(?<!\*)\*([^*\n]+)\*(?!\*)", r"<i>\1</i>", text)
    text = re.sub(r"(?<!_)_([^_\n]+)_(?!_)", r"<i>\1</i>", text)
    # Links [text](url)
    text = re.sub(
        r"\[([^\]]+)\]\(([^)]+)\)",
        r'<link href="\2" color="blue">\1</link>',
        text,
    )
    return text


def build_styles():
    base = getSampleStyleSheet()
    body = ParagraphStyle(
        "Body",
        parent=base["BodyText"],
        fontName="Helvetica",
        fontSize=10,
        leading=14,
        spaceAfter=6,
        alignment=TA_LEFT,
    )
    h1 = ParagraphStyle(
        "H1", parent=base["Heading1"], fontName="Helvetica-Bold",
        fontSize=20, leading=24, spaceBefore=14, spaceAfter=10,
        textColor=HexColor("#1a1a1a"),
    )
    h2 = ParagraphStyle(
        "H2", parent=base["Heading2"], fontName="Helvetica-Bold",
        fontSize=16, leading=20, spaceBefore=12, spaceAfter=8,
        textColor=HexColor("#1a1a1a"),
    )
    h3 = ParagraphStyle(
        "H3", parent=base["Heading3"], fontName="Helvetica-Bold",
        fontSize=13, leading=17, spaceBefore=10, spaceAfter=6,
        textColor=HexColor("#222222"),
    )
    h4 = ParagraphStyle(
        "H4", parent=base["Heading4"], fontName="Helvetica-Bold",
        fontSize=11, leading=15, spaceBefore=8, spaceAfter=4,
    )
    code = ParagraphStyle(
        "Code", parent=base["Code"], fontName="Courier",
        fontSize=8.5, leading=11, leftIndent=12,
        backColor=HexColor("#f4f4f4"),
        borderColor=HexColor("#dddddd"), borderWidth=0.5,
        borderPadding=6, spaceBefore=6, spaceAfter=8,
    )
    bq = ParagraphStyle(
        "BQ", parent=body, leftIndent=14,
        textColor=HexColor("#555555"), borderPadding=4,
    )
    return {"body": body, "h1": h1, "h2": h2, "h3": h3, "h4": h4, "code": code, "bq": bq}


def parse_markdown(md_text: str, styles: dict):
    lines = md_text.splitlines()
    story = []
    i = 0
    while i < len(lines):
        line = lines[i]

        # Fenced code block
        if line.startswith("```"):
            j = i + 1
            block = []
            while j < len(lines) and not lines[j].startswith("```"):
                block.append(lines[j])
                j += 1
            story.append(Preformatted("\n".join(block), styles["code"]))
            i = j + 1
            continue

        # Horizontal rule
        if re.match(r"^\s*(---|\*\*\*|___)\s*$", line):
            story.append(Spacer(1, 4))
            story.append(HRFlowable(width="100%", thickness=0.6, color=HexColor("#cccccc")))
            story.append(Spacer(1, 6))
            i += 1
            continue

        # Headings
        m = re.match(r"^(#{1,6})\s+(.+)$", line)
        if m:
            level = len(m.group(1))
            content = md_inline_to_rl(m.group(2).strip())
            story.append(Paragraph(content, styles[f"h{min(level, 4)}"]))
            i += 1
            continue

        # Blockquote
        if line.startswith(">"):
            bq_lines = []
            while i < len(lines) and lines[i].startswith(">"):
                bq_lines.append(lines[i].lstrip(">").strip())
                i += 1
            story.append(Paragraph(md_inline_to_rl(" ".join(bq_lines)), styles["bq"]))
            continue

        # Unordered list
        if re.match(r"^\s*[-*+]\s+", line):
            items = []
            while i < len(lines) and re.match(r"^\s*[-*+]\s+", lines[i]):
                item_text = re.sub(r"^\s*[-*+]\s+", "", lines[i])
                j = i + 1
                while j < len(lines) and lines[j].startswith("  ") and not re.match(r"^\s*[-*+]\s+", lines[j]):
                    item_text += " " + lines[j].strip()
                    j += 1
                items.append(ListItem(
                    Paragraph(md_inline_to_rl(item_text), styles["body"]),
                    leftIndent=12,
                ))
                i = j
            story.append(ListFlowable(items, bulletType="bullet", start="•", leftIndent=14))
            story.append(Spacer(1, 4))
            continue

        # Ordered list
        if re.match(r"^\s*\d+\.\s+", line):
            items = []
            while i < len(lines) and re.match(r"^\s*\d+\.\s+", lines[i]):
                item_text = re.sub(r"^\s*\d+\.\s+", "", lines[i])
                j = i + 1
                while j < len(lines) and lines[j].startswith("  ") and not re.match(r"^\s*\d+\.\s+", lines[j]):
                    item_text += " " + lines[j].strip()
                    j += 1
                items.append(ListItem(
                    Paragraph(md_inline_to_rl(item_text), styles["body"]),
                    leftIndent=12,
                ))
                i = j
            story.append(ListFlowable(items, bulletType="1", leftIndent=18))
            story.append(Spacer(1, 4))
            continue

        # Blank line
        if line.strip() == "":
            i += 1
            continue

        # Paragraph: gather lines until blank or structural
        para = [line]
        j = i + 1
        structural = re.compile(
            r"^(\s*[-*+]\s+|\s*\d+\.\s+|#{1,6}\s+|>|```|\s*(---|\*\*\*|___)\s*$)"
        )
        while j < len(lines) and lines[j].strip() != "" and not structural.match(lines[j]):
            para.append(lines[j])
            j += 1
        content = md_inline_to_rl(" ".join(p.strip() for p in para))
        story.append(Paragraph(content, styles["body"]))
        i = j

    return story


def convert(src: Path, dst: Path) -> None:
    md_text = src.read_text(encoding="utf-8")
    styles = build_styles()
    story = parse_markdown(md_text, styles)

    doc = SimpleDocTemplate(
        str(dst), pagesize=A4,
        leftMargin=2 * cm, rightMargin=2 * cm,
        topMargin=2 * cm, bottomMargin=2 * cm,
        title=src.stem,
    )
    doc.build(story)


def main():
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        print("Usage: md_to_pdf.py <input.md> [output.pdf]", file=sys.stderr)
        sys.exit(1)

    src = Path(sys.argv[1]).expanduser().resolve()
    if not src.exists():
        print(f"Error: input file not found: {src}", file=sys.stderr)
        sys.exit(1)

    if len(sys.argv) == 3:
        dst = Path(sys.argv[2]).expanduser().resolve()
    else:
        dst = src.with_suffix(".pdf")

    convert(src, dst)
    print(f"Wrote {dst} ({dst.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
