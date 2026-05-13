#!/usr/bin/env python3
"""Ticket 0.7 — generate a placeholder 8x8 pixel font from Pillow's default
bitmap font and emit a BMFont (.fnt + .png) pair Godot can load.

Run once and commit the output:
    python tools/generate_default_font.py

Outputs:
    assets/fonts/sleeping_vein_8x8.png     (atlas, 128x48, ASCII 32..127)
    assets/fonts/sleeping_vein_8x8.fnt     (BMFont text descriptor)

This is a deliberate placeholder. Real choice for The Sleeping Vein is 8x8
pixel readout (480x270 viewport => 60 cols of body text). Drop a prettier
permissive 8x8 TTF (monogram, m5x7, PixelOperator) into assets/fonts/ to
upgrade later — the theme references the BMFont by path so the swap is one
.tres edit away.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO_ROOT = Path(__file__).resolve().parent.parent
OUT_PNG = REPO_ROOT / "assets" / "fonts" / "sleeping_vein_8x8.png"
OUT_FNT = REPO_ROOT / "assets" / "fonts" / "sleeping_vein_8x8.fnt"

CELL_W = 8
CELL_H = 8
COLS = 16
ASCII_ROWS = 6  # ASCII 32..127 => 96 chars / 16 cols = 6 rows
EXTRA_ROWS = 1  # one row for hand-drawn typographic glyphs (em dash, en dash, …)
ROWS = ASCII_ROWS + EXTRA_ROWS
ASCII_BASE = 32
ASCII_LAST = ASCII_BASE + COLS * ASCII_ROWS - 1

# Hand-drawn glyphs in the 7th row. (codepoint, draw_fn(d, x0, y0)) pairs in cell order.
# x0/y0 is the top-left of the glyph's 8x8 cell in atlas pixel coordinates.

def _draw_em_dash(d: ImageDraw.ImageDraw, x0: int, y0: int) -> None:
    d.line([(x0, y0 + 4), (x0 + 7, y0 + 4)], fill=(255, 255, 255, 255))


def _draw_en_dash(d: ImageDraw.ImageDraw, x0: int, y0: int) -> None:
    d.line([(x0 + 1, y0 + 4), (x0 + 6, y0 + 4)], fill=(255, 255, 255, 255))


def _draw_ellipsis(d: ImageDraw.ImageDraw, x0: int, y0: int) -> None:
    for dx in (1, 3, 5):
        d.point((x0 + dx, y0 + 6), fill=(255, 255, 255, 255))


def _draw_bullet(d: ImageDraw.ImageDraw, x0: int, y0: int) -> None:
    d.rectangle([(x0 + 3, y0 + 3), (x0 + 4, y0 + 4)], fill=(255, 255, 255, 255))


def _draw_lsquo(d: ImageDraw.ImageDraw, x0: int, y0: int) -> None:
    d.line([(x0 + 3, y0 + 1), (x0 + 3, y0 + 3)], fill=(255, 255, 255, 255))
    d.point((x0 + 4, y0 + 3), fill=(255, 255, 255, 255))


def _draw_rsquo(d: ImageDraw.ImageDraw, x0: int, y0: int) -> None:
    d.line([(x0 + 4, y0 + 1), (x0 + 4, y0 + 3)], fill=(255, 255, 255, 255))
    d.point((x0 + 3, y0 + 1), fill=(255, 255, 255, 255))


def _draw_ldquo(d: ImageDraw.ImageDraw, x0: int, y0: int) -> None:
    d.line([(x0 + 2, y0 + 1), (x0 + 2, y0 + 3)], fill=(255, 255, 255, 255))
    d.line([(x0 + 5, y0 + 1), (x0 + 5, y0 + 3)], fill=(255, 255, 255, 255))


def _draw_rdquo(d: ImageDraw.ImageDraw, x0: int, y0: int) -> None:
    d.line([(x0 + 2, y0 + 1), (x0 + 2, y0 + 3)], fill=(255, 255, 255, 255))
    d.line([(x0 + 5, y0 + 1), (x0 + 5, y0 + 3)], fill=(255, 255, 255, 255))
    d.point((x0 + 1, y0 + 1), fill=(255, 255, 255, 255))


# Order matters — these fill cells left-to-right in the 7th row.
EXTRA_GLYPHS: list[tuple[int, str]] = [
    (0x2013, "en_dash"),
    (0x2014, "em_dash"),
    (0x2026, "ellipsis"),
    (0x2022, "bullet"),
    (0x2018, "lsquo"),
    (0x2019, "rsquo"),
    (0x201C, "ldquo"),
    (0x201D, "rdquo"),
]
EXTRA_DRAWERS: dict[str, callable] = {
    "em_dash": _draw_em_dash,
    "en_dash": _draw_en_dash,
    "ellipsis": _draw_ellipsis,
    "bullet": _draw_bullet,
    "lsquo": _draw_lsquo,
    "rsquo": _draw_rsquo,
    "ldquo": _draw_ldquo,
    "rdquo": _draw_rdquo,
}


def main() -> int:
    OUT_PNG.parent.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGBA", (CELL_W * COLS, CELL_H * ROWS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(atlas)
    font = ImageFont.load_default()

    for i in range(ASCII_BASE, ASCII_LAST + 1):
        idx = i - ASCII_BASE
        col = idx % COLS
        row = idx // COLS
        ch = chr(i)
        # PIL default font is roughly 6x11. Center it inside an 8x8 cell.
        try:
            l, t, r, b = draw.textbbox((0, 0), ch, font=font)
            w = r - l
            h = b - t
        except Exception:
            w, h = 6, 8
            l, t = 0, 0
        x = col * CELL_W + max(0, (CELL_W - w) // 2) - l
        y = row * CELL_H + max(0, (CELL_H - h) // 2) - t
        draw.text((x, y), ch, font=font, fill=(255, 255, 255, 255))

    # 7th-row hand-drawn typographic glyphs.
    extra_row = ASCII_ROWS
    for col, (_codepoint, name) in enumerate(EXTRA_GLYPHS):
        x0 = col * CELL_W
        y0 = extra_row * CELL_H
        EXTRA_DRAWERS[name](draw, x0, y0)

    atlas.save(OUT_PNG)

    # BMFont text descriptor (subset Godot understands).
    total_glyphs = (ASCII_LAST - ASCII_BASE + 1) + len(EXTRA_GLYPHS)
    lines: list[str] = []
    lines.append(f'info face="sleeping_vein_8x8" size={CELL_H} bold=0 italic=0 charset="" '
                 f'unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0')
    lines.append(f'common lineHeight={CELL_H} base={CELL_H - 1} scaleW={CELL_W * COLS} scaleH={CELL_H * ROWS} '
                 f'pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4')
    lines.append(f'page id=0 file="sleeping_vein_8x8.png"')
    lines.append(f'chars count={total_glyphs}')
    for i in range(ASCII_BASE, ASCII_LAST + 1):
        idx = i - ASCII_BASE
        col = idx % COLS
        row = idx // COLS
        x = col * CELL_W
        y = row * CELL_H
        lines.append(
            f'char id={i} x={x} y={y} width={CELL_W} height={CELL_H} '
            f'xoffset=0 yoffset=0 xadvance={CELL_W} page=0 chnl=15'
        )
    for col, (codepoint, _name) in enumerate(EXTRA_GLYPHS):
        x = col * CELL_W
        y = extra_row * CELL_H
        lines.append(
            f'char id={codepoint} x={x} y={y} width={CELL_W} height={CELL_H} '
            f'xoffset=0 yoffset=0 xadvance={CELL_W} page=0 chnl=15'
        )
    OUT_FNT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"wrote {OUT_PNG.relative_to(REPO_ROOT)} ({atlas.size[0]}x{atlas.size[1]})")
    print(f"wrote {OUT_FNT.relative_to(REPO_ROOT)} ({total_glyphs} glyphs incl. {len(EXTRA_GLYPHS)} typographic extras)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
