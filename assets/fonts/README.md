# Fonts (ticket 0.7)

The project picks **8×8 pixel readout** as the default body-text size.
At a 480×270 viewport that's ~60 columns of text — enough for tooltips,
dialogue, and HUD labels without crowding.

## Currently shipped

- `sleeping_vein_8x8.png` + `sleeping_vein_8x8.fnt` — placeholder BMFont generated
  by `tools/generate_default_font.py` from Pillow's bundled bitmap font. Bound by
  `resources/themes/sleeping_vein.tres` as the default font for every UI control.

The placeholder is functional but plain. Swap it for a prettier permissively-
licensed pixel font when one is on hand:

- [monogram](https://datagoblin.itch.io/monogram) by datagoblin (CC0) — clean 5×7
- [m6x11](https://managore.itch.io/m6x11) by Daniel Linssen (CC0) — bold 6×11
- [PixelOperator](https://www.dafont.com/pixel-operator.font) by Jayvee Enaguas (CC0) — readable 8×8 / 16×16

## Swap procedure

1. Drop the `.ttf` into `assets/fonts/<your_font>.ttf`.
2. Open `resources/themes/sleeping_vein.tres` in the editor and change
   `default_font` to the new font (or edit the `ExtResource` path directly).
3. Reload the project. Every UI label / button picks up the change because the
   theme is bound globally via `gui/theme/custom` in `project.godot`.

## Why BMFont and not TTF for the placeholder

Pillow's default font is bitmap-only; `tools/generate_default_font.py` packs it
into a BMFont atlas because Godot 4's `FontFile` only consumes BMFont, TTF,
OTF, or WOFF binaries. The placeholder atlas covers ASCII 32–127 plus a
hand-drawn 7th row of typographic extras: en dash (`–`), em dash (`—`),
ellipsis (`…`), bullet (`•`), and curly single/double quotes
(`‘ ’ “ ”`). Anything else (accented Latin, non-Latin scripts, box-drawing,
emoji) renders as Godot's `[hexcode]` tofu — drop in a real pixel TTF if you
need broader coverage.
