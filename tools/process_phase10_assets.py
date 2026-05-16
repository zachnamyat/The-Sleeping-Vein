#!/usr/bin/env python3
"""Split the Phase 10 Gemini sheets into canonical PNGs.

Phase 10 produces six raw sheets:
  - enemies_vesari_necropolis_v1.png — 2x2 grid, 24x24 enemies
  - enemies_sunless_verdancy_v1.png  — 2x2 grid, 24x24 enemies (vine_stalker is 16)
  - enemies_drowned_aphelion_v1.png  — 2x2 grid, 24x24 enemies
  - items_phase10_sheet1_relics.png  — 4x4 grid, 16x16 item icons
  - tiles_phase10_hazards.png        — 2x2 grid, 16x16 floor tiles
  - vfx_environmental_phase10.png    — 2x1 grid, 64x16 four-frame strips

Reuses the bbox detection + magenta-key + clean_alpha helpers from the
Phase 8 processor.
"""
from __future__ import annotations

import subprocess
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent


def is_magenta(px: tuple, _tol: int = 0) -> bool:
    r, g, b = px[0], px[1], px[2]
    return r > 150 and b > 90 and g < 80


def find_content_bbox(img: Image.Image, bounds: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    px = img.load()
    x0, y0, x1, y1 = bounds
    left, top, right, bottom = x1, y1, x0, y0
    found_any = False
    for y in range(y0, y1):
        for x in range(x0, x1):
            p = px[x, y]
            if len(p) >= 3 and not is_magenta(p):
                found_any = True
                if x < left:
                    left = x
                if y < top:
                    top = y
                if x > right:
                    right = x
                if y > bottom:
                    bottom = y
    if not found_any or right <= left or bottom <= top:
        return bounds
    return (left, top, right + 1, bottom + 1)


def pad_to_aspect(bbox, img_w, img_h, target_w, target_h):
    bw = bbox[2] - bbox[0]
    bh = bbox[3] - bbox[1]
    if bh <= 0 or bw <= 0:
        return bbox
    target_ratio = target_w / target_h
    bbox_ratio = bw / bh
    if abs(bbox_ratio - target_ratio) < 0.001:
        return bbox
    if bbox_ratio > target_ratio:
        new_h = int(round(bw / target_ratio))
        pad = new_h - bh
        return (
            bbox[0],
            max(0, bbox[1] - pad // 2),
            bbox[2],
            min(img_h, bbox[3] + (pad - pad // 2)),
        )
    new_w = int(round(bh * target_ratio))
    pad = new_w - bw
    return (
        max(0, bbox[0] - pad // 2),
        bbox[1],
        min(img_w, bbox[2] + (pad - pad // 2)),
        bbox[3],
    )


def magenta_to_alpha(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, _a = px[x, y]
            if is_magenta((r, g, b)):
                px[x, y] = (0, 0, 0, 0)
    return img


def run_clean_alpha(target: Path) -> None:
    ps_script = REPO / "tools" / "clean_alpha.ps1"
    cmd = ["powershell.exe", "-ExecutionPolicy", "Bypass", "-File", str(ps_script), "-Path", str(target)]
    print(f"  -> clean_alpha {target.name}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"     WARN: clean_alpha.ps1 exit {result.returncode}")
        if result.stderr:
            for line in result.stderr.splitlines():
                print(f"     {line}")


def split_grid(src_rel: str, grid_w: int, grid_h: int, target_size: int, mapping: list, dst_dir: Path) -> list[Path]:
    """Split a grid_h x grid_w grid sheet into individual PNGs of `target_size`x`target_size`."""
    src = REPO / src_rel
    if not src.exists():
        print(f"[WARN] sheet missing: {src.relative_to(REPO)}")
        return []
    img = Image.open(src).convert("RGBA")
    sw, sh = img.size
    cell_w = sw // grid_w
    cell_h = sh // grid_h
    outputs: list[Path] = []
    dst_dir.mkdir(parents=True, exist_ok=True)
    print(f"[sheet] {src.relative_to(REPO)} ({sw}x{sh}) grid={grid_w}x{grid_h} cell={cell_w}x{cell_h} -> {target_size}px")
    for entry in mapping:
        r, c, name = entry
        if name is None:
            continue
        # Inset a small margin so we don't pick up the grid line / cell border.
        inset_x = max(4, cell_w // 16)
        inset_y = max(4, cell_h // 16)
        x0 = c * cell_w + inset_x
        y0 = r * cell_h + inset_y
        x1 = (c + 1) * cell_w - inset_x
        y1 = (r + 1) * cell_h - inset_y
        bbox = find_content_bbox(img, (x0, y0, x1, y1))
        bbox = pad_to_aspect(bbox, sw, sh, target_size, target_size)
        cropped = img.crop(bbox)
        final = cropped.resize((target_size, target_size), Image.Resampling.NEAREST)
        final = magenta_to_alpha(final)
        dst = dst_dir / f"{name}.png"
        final.save(dst)
        outputs.append(dst)
        print(f"  {name}: cell=({r},{c}) bbox={bbox} -> {dst.relative_to(REPO)}")
    return outputs


# ---------------------------------------------------------------------------
# Mapping tables.
# ---------------------------------------------------------------------------

# enemies_vesari_necropolis_v1.png — prompt order:
#   (0,0) salt_bound_captain
#   (1,0) coral_hollow         -> actually cell (0,1) top-right per prompt
# Prompt says: cell (0,0) top-left, cell (1,0) top-right (col index 1, row index 0).
# In our row/col convention: (row, col).
VESARI_MAP = [
    (0, 0, "salt_bound_captain"),
    (0, 1, "coral_hollow"),
    (1, 0, "tideglass_cricket"),
    (1, 1, "salt_fox"),
]

VERDANCY_MAP = [
    (0, 0, "vine_stalker"),
    (0, 1, "bloom_hag"),
    (1, 0, "verdant_hare"),
    (1, 1, "glow_crane"),
]

DROWNED_MAP = [
    (0, 0, "hollow_coral"),
    (0, 1, "wreck_wraith"),
    (1, 0, "lantern_squid"),
    (1, 1, "brinekin"),
]

# items_phase10_sheet1_relics.png — 4x4 grid, 16 cells.
PHASE10_ITEMS_MAP = [
    (0, 0, "coral_veil"),
    (0, 1, "underwater_goggles"),
    (0, 2, "lava_boots"),
    (0, 3, "frost_boots"),
    (1, 0, "gas_mask"),
    (1, 1, "verdant_heart"),
    (1, 2, "drowned_diadem"),
    (1, 3, "sword_threnos_king"),
    (2, 0, "sythrenn_last_petal"),
    (2, 1, "volthaar_promise"),
    (2, 2, "vorrkell_lantern"),
    (2, 3, "sunken_glyph_fragment"),
    (3, 0, "pet_pup"),
    (3, 1, "larva_trap_placeable"),
    (3, 2, "verdant_soil_placeable"),
    (3, 3, "glow_crane_feather"),
]

# tiles_phase10_hazards.png — 2x2 floor tiles.
TILES_MAP = [
    (0, 0, "tile_slime"),
    (0, 1, "tile_acid"),
    (1, 0, "tile_cobweb"),
    (1, 1, "tile_verdant_soil"),
]


def split_vfx_strips(src_rel: str, dst_dir: Path) -> list[Path]:
    """The VFX sheet is 1024x1024 with 2 horizontal 4-frame strips.

    Top strip = env_toxic_spore, bottom strip = env_salt_corrosion.
    Each output is 64x16 (4 frames * 16x16).
    """
    src = REPO / src_rel
    if not src.exists():
        print(f"[WARN] vfx sheet missing: {src.relative_to(REPO)}")
        return []
    img = Image.open(src).convert("RGBA")
    sw, sh = img.size
    strips = [
        (0, "env_toxic_spore"),
        (1, "env_salt_corrosion"),
    ]
    outputs: list[Path] = []
    dst_dir.mkdir(parents=True, exist_ok=True)
    for row, name in strips:
        # Each strip is sw x (sh//2).
        y0 = row * (sh // 2)
        y1 = (row + 1) * (sh // 2)
        # Carve four equal-width frames out of this strip.
        frame_w = sw // 4
        frame_h = (sh // 2)
        # Resize each frame to 16x16 and lay them out in a 64x16 strip.
        out = Image.new("RGBA", (64, 16), (255, 0, 255, 255))
        for f in range(4):
            x0 = f * frame_w
            x1 = (f + 1) * frame_w
            bbox = find_content_bbox(img, (x0 + 8, y0 + 8, x1 - 8, y1 - 8))
            bbox = pad_to_aspect(bbox, sw, sh, 16, 16)
            cropped = img.crop(bbox).resize((16, 16), Image.Resampling.NEAREST)
            out.paste(cropped, (f * 16, 0))
        out = magenta_to_alpha(out)
        dst = dst_dir / f"{name}.png"
        out.save(dst)
        outputs.append(dst)
        print(f"  {name}: -> {dst.relative_to(REPO)}")
    return outputs


def main() -> int:
    outputs: list[Path] = []

    # Enemies — 2x2 grids, downsample each cell to 24x24 (or 16x16 for crickets/squids).
    outputs += split_grid(
        "assets/raw/enemies/enemies_vesari_necropolis_v1.png",
        grid_w=2, grid_h=2, target_size=24,
        mapping=VESARI_MAP,
        dst_dir=REPO / "assets/sprites/enemies/vesari_necropolis",
    )
    outputs += split_grid(
        "assets/raw/enemies/enemies_sunless_verdancy_v1.png",
        grid_w=2, grid_h=2, target_size=24,
        mapping=VERDANCY_MAP,
        dst_dir=REPO / "assets/sprites/enemies/sunless_verdancy",
    )
    outputs += split_grid(
        "assets/raw/enemies/enemies_drowned_aphelion_v1.png",
        grid_w=2, grid_h=2, target_size=24,
        mapping=DROWNED_MAP,
        dst_dir=REPO / "assets/sprites/enemies/drowned_aphelion",
    )

    # Items — 4x4 grid, 16x16 each.
    outputs += split_grid(
        "assets/raw/items/items_phase10_sheet1_relics.png",
        grid_w=4, grid_h=4, target_size=16,
        mapping=PHASE10_ITEMS_MAP,
        dst_dir=REPO / "assets/sprites/items",
    )

    # Tiles — 2x2 grid, 16x16 each, into tiles dir.
    outputs += split_grid(
        "assets/raw/tiles/tiles_phase10_hazards.png",
        grid_w=2, grid_h=2, target_size=16,
        mapping=TILES_MAP,
        dst_dir=REPO / "assets/sprites/tiles",
    )

    # VFX — two 4-frame strips at 64x16 each.
    outputs += split_vfx_strips(
        "assets/raw/vfx/vfx_environmental_phase10.png",
        dst_dir=REPO / "assets/sprites/vfx",
    )

    for path in outputs:
        run_clean_alpha(path)

    print(f"\nProcessed {len(outputs)} Phase 10 sprites.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
