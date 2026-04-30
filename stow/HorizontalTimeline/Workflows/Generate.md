# HorizontalTimeline — Generate

Generates a horizontal SVG timeline with phase-coloured dots, 290deg rotated text below, connector underlines, and ellipsis breaks for time gaps.

## When to Use

- Any chronological event sequence in HTML slides or documents
- Medical/project/life timelines
- When events need phase colouring (good/bad/recovery)

## Geometry (the hard-won math)

The text is rotated **290deg** (equivalent to -70deg). From a bottom anchor point, text reads upward-right toward the dot.

**Direction vectors at 290deg (screen coords, y-down):**
- Reading direction: `dx=0.342, dy=-0.940` (upper-right)
- Opposite (anchor direction): `dx=-0.342, dy=0.940` (lower-left)

**Key formula — bottom anchor position from dot:**
```
bottomX = dotX - (0.364 * verticalDrop)
bottomY = dotY + verticalDrop
```

Where `verticalDrop = bottomY - dotY`. The factor `0.364 = tan(20deg)` maintains the 290deg angle.

**Critical rule:** Connector length MUST exceed the longest text pixel length, or text overshoots the dot. At font-size 11.5, budget ~6.5px per character. A 45-char string ≈ 293px. Connector length = `sqrt(dx^2 + dy^2)` must be > 293.

## Input Format

Provide events as a list:

```
date | phase | description
Jul 2019 | ok | Started at Sky. Best physical & mental state.
Late Oct 2019 | danger | Injury + FND onset. Signed off work.
~Spring 2022 | danger | Off ketotifen. Self-sustaining state.
[GAP ~3.5 years]
~Aug-Sep 2025 | danger | HRT + MCAS resolves. Distress persists.
Feb 2026 | recovery:critical | Bupropion. "Like a light switch."
```

**Phases:** `ok` (#6366f1 blue), `danger` (#f87171 red), `recovery` (#4ade80 green), `amber` (#fbbf24)
Append `:critical` for larger dot with glow ring.

**`[GAP label]`** inserts an ellipsis break with label text.

## SVG Template

```svg
<svg viewBox="-15 0 1000 380" width="985" height="380">
  <!-- 1. Horizontal lines between each adjacent pair of dots -->
  <line x1="[dot1X]" y1="[lineY]" x2="[dot2X]" y2="[lineY]"
        stroke="[phaseColor]" stroke-width="3"/>

  <!-- 2. Gap section (if needed): line + ellipsis + line -->
  <line x1="[prevDotX]" y1="[lineY]" x2="[midLeft]" y2="[lineY]"
        stroke="#f87171" stroke-width="3" opacity="0.4"/>
  <circle cx="[mid-5]" cy="[lineY]" r="2.5" fill="#666"/>
  <circle cx="[mid]"   cy="[lineY]" r="2.5" fill="#666"/>
  <circle cx="[mid+5]" cy="[lineY]" r="2.5" fill="#666"/>
  <line x1="[midRight]" y1="[lineY]" x2="[nextDotX]" y2="[lineY]"
        stroke="#f87171" stroke-width="3" opacity="0.4"/>
  <text x="[mid]" y="[lineY+20]" text-anchor="middle" fill="#666"
        font-size="9" font-style="italic">~N years</text>

  <!-- 3. Connector lines (behind dots and text) -->
  <line x1="[bottomX]" y1="[bottomY]" x2="[dotX]" y2="[lineY]"
        stroke="[phaseColor]" stroke-width="1" opacity="0.35"/>

  <!-- 4. Dots (on top of connectors) -->
  <circle cx="[dotX]" cy="[lineY]" r="6" fill="[phaseColor]"/>
  <!-- Critical events: larger dot + glow -->
  <circle cx="[dotX]" cy="[lineY]" r="8" fill="[phaseColor]"/>
  <circle cx="[dotX]" cy="[lineY]" r="14" fill="none"
          stroke="rgba([r],[g],[b],0.3)" stroke-width="1.5"/>

  <!-- 5. Rotated text labels -->
  <g transform="translate([bottomX], [bottomY]) rotate(290)">
    <text x="4" y="-22" fill="[dateColor]" font-size="13"
          font-weight="600" font-family="Inter, sans-serif">[Date]</text>
    <text x="4" y="-6" fill="[eventColor]" font-size="11.5"
          font-family="Inter, sans-serif">[Description]</text>
  </g>
</svg>
```

## Sizing Checklist

| Parameter | Typical Value | How to Calculate |
|-----------|--------------|------------------|
| lineY (dot row) | 65 | Leave room above for slide title |
| bottomY (text anchor) | 361 | lineY + verticalDrop; ensure connector > longest text |
| verticalDrop | 296 | `longestTextPx / 0.940 + 20` (20px bare connector margin) |
| bottomX offset | 108 | `verticalDrop * 0.364` |
| Dot spacing | 75-85px | `(lastDotX - firstDotX) / (N-1)` |
| Gap spacing | 150px | Wider than normal, holds ellipsis |
| viewBox x-start | -15 | Accommodate leftmost text spilling left |
| viewBox height | 380 | `bottomY + 20` |
| Font: date | 13 (normal), 14 (critical) | |
| Font: event | 11.5 (normal), 12 (critical) | |
| Date text y | -22 | In rotated local coords |
| Event text y | -6 | In rotated local coords |

## Colour Reference

| Phase | Dot/Date | Event text | Connector |
|-------|----------|------------|-----------|
| ok | `#6366f1` | `#c8c8d8` | `#6366f1` opacity 0.35 |
| danger | `#f87171` | `#c8c8d8` | `#f87171` opacity 0.35 |
| danger:critical | `#f87171` | `#fca5a5` weight 600 | `#f87171` opacity 0.45, width 1.3 |
| recovery | `#4ade80` | `#86efac` | `#4ade80` opacity 0.45 |
| recovery:critical | `#4ade80` | `#86efac` weight 600 | `#4ade80` opacity 0.45, width 1.3 |
| amber | `#fbbf24` | `#fbbf24` | `#fbbf24` opacity 0.35 |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Text overshoots dot | Increase verticalDrop so connector > longest text |
| Text clipped at top of SVG | Increase viewBox height or move lineY down |
| Text clipped on left edge | Set viewBox x-start to -15 or lower |
| CSS overflow clips rotated text | Use SVG (not CSS transforms) — immune to `overflow:hidden` |
| Adjacent text overlaps | Perpendicular distance = `dotSpacing * sin(70deg)`. At 75px spacing = 70px apart. Two text lines ≈ 30px. Safe. |
| Connector angle wrong | `bottomX = dotX - (0.364 * verticalDrop)`. Don't approximate. |

## Dark Theme Defaults

Background: `#0a0a0f`. These colours are designed for dark backgrounds. For light backgrounds, invert text fills and reduce dot saturation.
