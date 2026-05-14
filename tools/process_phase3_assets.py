#!/usr/bin/env python3
"""Post-process Phase 3 Gemini outputs into final pixel-art assets.

Three Gemini sheets become 20 final PNGs:

UI sheet (1344x768) -> 3 panels:
  - inventory_grid_panel.png (176x64)
  - equipment_slots_panel.png (112x48)
  - tooltip_frame.png (128x80)

Items sheet (1536x672, 8x2 grid) -> 16 icons at 16x16:
  - row 0: wooden_pickaxe, wooden_sword, torch, loam_floor, loam_wall, hoe, watering_can, cooking_pot
  - row 1: shaleseed_pickaxe, shaleseed_sword, shaleseed_helmet, shaleseed_chest,
           shaleseed_legs, shaleseed_boots, small_healing_potion, small_mana_potion

Clearstone Forge solo (1024x1024) -> 32x32 placeable.

Pipeline per asset:
1. Find content bbox by scanning for non-magenta-ish pixels
   (excludes the visible text labels Gemini adds to grid sheets by clipping
   the bottom 25% of each cell on the items sheet).
2. NEAREST-NEIGHBOR downsample to target size.
3. Magenta -> transparent alpha key.
4. clean_alpha.ps1 (ImageMagick fuzz threshold) to nuke anti-aliased magenta edge.
5. snap_to_palette.py to enforce the project ramp.

Idempotent. Run once after generating raws.
"""
from __future__ import annotations

import subprocess
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent


def is_magenta(px: tuple, tol: int = 0) -> bool:
    r, g, b = px[0], px[1], px[2]
    return r > 150 and b > 90 and g < 80


def find_content_bbox(img: Image.Image, bounds: tuple[int, int, int, int] | None = None) -> tuple[int, int, int, int]:
    """Return tight bbox around non-magenta pixels in (optionally restricted) region."""
    px = img.load()
    w, h = img.size
    if bounds is None:
        x0, y0, x1, y1 = 0, 0, w, h
    else:
        x0, y0, x1, y1 = bounds
    left, top, right, bottom = x1, y1, x0, y0
    found_any = False
    for y in range(y0, y1):
        for x in range(x0, x1):
            p = px[x, y]
            if len(p) >= 3 and not is_magenta(p):
                found_any = True
                if x < left: left = x
                if y < top: top = y
                if x > right: right = x
                if y > bottom: bottom = y
    if not found_any or right <= left or bottom <= top:
        return (x0, y0, x1, y1)
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
        return (bbox[0], max(0, bbox[1] - pad // 2), bbox[2], min(img_h, bbox[3] + (pad - pad // 2)))
    else:
        new_w = int(round(bh * target_ratio))
        pad = new_w - bw
        return (max(0, bbox[0] - pad // 2), bbox[1], min(img_w, bbox[2] + (pad - pad // 2)), bbox[3])


def magenta_to_alpha(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if is_magenta((r, g, b)):
                px[x, y] = (0, 0, 0, 0)
    return img


def downsample(img: Image.Image, w: int, h: int) -> Image.Image:
    return img.resize((w, h), Image.Resampling.NEAREST)


def run_clean_alpha(target: Path) -> None:
    ps_script = REPO / "tools" / "clean_alpha.ps1"
    cmd = ["powershell.exe", "-ExecutionPolicy", "Bypass", "-File", str(ps_script), "-Path", str(target)]
    print(f"  -> clean_alpha.ps1 {target.name}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    for line in (result.stdout or "").splitlines():
        print(f"     {line}")
    if result.returncode != 0:
        print(f"     WARN: clean_alpha.ps1 exit {result.returncode}")
        for line in (result.stderr or "").splitlines():
            print(f"     {line}")


def run_snap_palette(target: Path, biome: str | None = None) -> None:
    cmd = ["python", str(REPO / "tools" / "snap_to_palette.py"), "--in-place", str(target)]
    if biome is not None:
        cmd.extend(["--biome", biome])
    biome_str = biome if biome is not None else "(all biomes)"
    print(f"  -> snap_to_palette.py --biome {biome_str} {target.name}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    for line in (result.stdout or "").splitlines():
        print(f"     {line}")


def process_items_grid(src_rel: str, dst_dir_rel: str, names: list[str], cols: int, rows: int, icon_h_frac: float = 0.70) -> list[Path]:
    """Items sheet is a regular grid; crop top icon_h_frac of each cell.

    Defaults to 0.70 because the original Gemini items_tools_basic_set sheet
    rendered visible text labels in the bottom 30% of each cell. Newer prompts
    that don't include text labels can pass icon_h_frac=1.0.
    """
    src = REPO / src_rel
    dst_dir = REPO / dst_dir_rel
    dst_dir.mkdir(parents=True, exist_ok=True)
    img = Image.open(src).convert("RGBA")
    sw, sh = img.size
    cell_w = sw // cols
    cell_h = sh // rows
    outputs = []
    print(f"[items_grid] {src.relative_to(REPO)} ({sw}x{sh}) -> {cols}x{rows} cells of {cell_w}x{cell_h}")
    for i, name in enumerate(names):
        r = i // cols
        c = i % cols
        x0 = c * cell_w
        y0 = r * cell_h
        x1 = x0 + cell_w
        y1 = y0 + int(cell_h * icon_h_frac)
        bbox = find_content_bbox(img, (x0, y0, x1, y1))
        bbox = pad_to_aspect(bbox, sw, sh, 16, 16)
        cropped = img.crop(bbox)
        final = downsample(cropped, 16, 16)
        final = magenta_to_alpha(final)
        dst = dst_dir / f"{name}.png"
        final.save(dst)
        outputs.append(dst)
        print(f"  {name}: source cell {(x0,y0,x1,y1)} bbox {bbox} -> {dst.relative_to(REPO)}")
    return outputs


def process_ui_panels(src_rel: str) -> list[tuple[Path, str]]:
    """UI sheet packs 3 panels at measured pixel regions of the 1344x768 canvas.

    Gemini deviated from the layout spec — panels are smaller than the
    canvas-fractional positions stated in the prompt. Hand-tuned via
    magenta-transition scan (see commit history for the scan).
    """
    src = REPO / src_rel
    img = Image.open(src).convert("RGBA")
    sw, sh = img.size
    # Measured panel pixel bounds (left, top, right, bottom). 6 px inner margin
    # added so the panel border isn't sliced off when bbox-tightening on the
    # snap pass.
    panels = [
        ("inventory_grid_panel",  (20, 35, 700, 396),   176, 64),
        ("equipment_slots_panel", (795, 35, 1320, 396), 112, 48),
        ("tooltip_frame",         (20, 415, 515, 740),  128, 80),
    ]
    dst_dir = REPO / "assets/sprites/ui"
    dst_dir.mkdir(parents=True, exist_ok=True)
    outputs = []
    print(f"[ui_panels] {src.relative_to(REPO)} ({sw}x{sh})")
    for name, (sx0, sy0, sx1, sy1), tw, th in panels:
        bbox = find_content_bbox(img, (sx0, sy0, sx1, sy1))
        bbox = pad_to_aspect(bbox, sw, sh, tw, th)
        cropped = img.crop(bbox)
        final = downsample(cropped, tw, th)
        final = magenta_to_alpha(final)
        dst = dst_dir / f"{name}.png"
        final.save(dst)
        outputs.append((dst, None))
        print(f"  {name}: source {(sx0,sy0,sx1,sy1)} bbox {bbox} -> {dst.relative_to(REPO)} ({tw}x{th})")
    return outputs


def process_single(src_rel: str, dst_rel: str, tw: int, th: int) -> Path:
    src = REPO / src_rel
    dst = REPO / dst_rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    img = Image.open(src).convert("RGBA")
    sw, sh = img.size
    bbox = find_content_bbox(img)
    bbox = pad_to_aspect(bbox, sw, sh, tw, th)
    cropped = img.crop(bbox)
    final = downsample(cropped, tw, th)
    final = magenta_to_alpha(final)
    final.save(dst)
    print(f"[single] {src.relative_to(REPO)} ({sw}x{sh}) bbox {bbox} -> {dst.relative_to(REPO)} ({tw}x{th})")
    return dst


ITEM_NAMES = [
    "wooden_pickaxe", "wooden_sword", "torch", "loam_floor", "loam_wall", "hoe", "watering_can", "cooking_pot",
    "shaleseed_pickaxe", "shaleseed_sword", "shaleseed_helmet", "shaleseed_chest",
    "shaleseed_legs", "shaleseed_boots", "small_healing_potion", "small_mana_potion",
]

# Phase 3 extended-closure follow-up — sheet of 8 reagent / station-icon items
# generated separately. 4×2 grid; row 0 = plank/ingot/bottle/aphelion_fragment;
# row 1 = glow_tube/coupler/furnace_icon/sawmill_icon. The two _icon entries
# are unused (structures use their own 32x32 sprites) but the cells need names.
PHASE3_EXTRA_NAMES = [
    "plank", "shaleseed_ingot", "bottle_empty", "aphelion_fragment",
    "glow_tube", "station_tier_upgrade", "_furnace_icon_unused", "_sawmill_icon_unused",
]

# Phase 3 missing-icon backfill — Phase 1/2 materials and miscellaneous drops
# the player encounters before Phase 8/9 content is implemented.
PHASE12_BASIC_NAMES = [
    "loam", "loambeetle", "ancient_coin", "lantern_glint",
    "respec_scroll", "pale_cap", "memory_root", "fishing_rod_wood",
]

# Phase 8 farming + cooking + fishing icons.
PHASE8_FOOD_NAMES = [
    "pale_cap_seed", "memory_root_seed", "pale_cap_stew", "memory_root_broth",
    "loam_loaf", "cave_guppy", "salt_minnow", "sovereign_name_fragment_1",
]


def main() -> int:
    # 1) Items grid -> 16 icons
    item_outputs = process_items_grid(
        "assets/raw/items/items_tools_basic_set_v1.png",
        "assets/sprites/items",
        ITEM_NAMES,
        cols=8,
        rows=2,
    )
    for path in item_outputs:
        run_clean_alpha(path)
        run_snap_palette(path, None)

    # 2) UI sheet -> 3 panels
    ui_outputs = process_ui_panels("assets/raw/ui/ui_inventory_set_v1.png")
    for path, _biome in ui_outputs:
        run_clean_alpha(path)
        run_snap_palette(path, None)

    # 3) Clearstone forge solo
    forge = process_single(
        "assets/raw/structures/structure_clearstone_forge_v1.png",
        "assets/sprites/structures/clearstone_forge.png",
        32, 32,
    )
    run_clean_alpha(forge)
    run_snap_palette(forge, "glasswright_reaches")

    # 4) Phase 3 extras item sheet -> 6 useful icons (2 unused cells)
    # No text labels in this sheet — use full cell height.
    extras_outputs = process_items_grid(
        "assets/raw/items/items_phase3_extras_v1.png",
        "assets/sprites/items",
        PHASE3_EXTRA_NAMES,
        cols=4,
        rows=2,
        icon_h_frac=1.0,
    )
    for path in extras_outputs:
        # Skip the two _unused stub files we only wrote to fill the grid.
        if "_unused" in path.stem:
            try:
                path.unlink()
            except OSError:
                pass
            continue
        run_clean_alpha(path)
        run_snap_palette(path, None)

    # 5) Sawmill + Furnace structure sprites (32x32 each, solo)
    sawmill = process_single(
        "assets/raw/structures/structure_sawmill_v1.png",
        "assets/sprites/structures/sawmill.png",
        32, 32,
    )
    run_clean_alpha(sawmill)
    run_snap_palette(sawmill, "root_hollows")

    furnace = process_single(
        "assets/raw/structures/structure_furnace_v1.png",
        "assets/sprites/structures/furnace.png",
        32, 32,
    )
    run_clean_alpha(furnace)
    run_snap_palette(furnace, None)

    # 6) Phase 1/2 missing-icon backfill (8 icons) — no text labels.
    p12_outputs = process_items_grid(
        "assets/raw/items/items_phase1_2_basics_v1.png",
        "assets/sprites/items",
        PHASE12_BASIC_NAMES,
        cols=4,
        rows=2,
        icon_h_frac=1.0,
    )
    for path in p12_outputs:
        run_clean_alpha(path)
        run_snap_palette(path, None)

    # 7) Phase 8 food/farming icons (8 icons) — no text labels.
    p8_outputs = process_items_grid(
        "assets/raw/items/items_phase8_food_v1.png",
        "assets/sprites/items",
        PHASE8_FOOD_NAMES,
        cols=4,
        rows=2,
        icon_h_frac=1.0,
    )
    for path in p8_outputs:
        run_clean_alpha(path)
        run_snap_palette(path, None)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
