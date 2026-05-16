#!/usr/bin/env python3
"""Split the five Phase 8 Gemini sheets into individual 16x16 PNGs.

Each sheet is a 4x4 grid of 256x256 cells on a 1024x1024 magenta-background
canvas. For each cell we content-bbox to skip any visible label, downsample
nearest-neighbor to 16x16, magenta-key the background, and let clean_alpha.ps1
do the final binary-alpha threshold pass.

Names below match the cell-position mapping decided after inspecting the raw
sheets. Cells marked None are skipped (Gemini-rendered blanks or unused
positions).
"""
from __future__ import annotations

import subprocess
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent


def is_magenta(px: tuple, tol: int = 0) -> bool:
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
    else:
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
            r, g, b, a = px[x, y]
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


# (cell row, cell col, target asset name).  None entries are skipped.
# Sheets are 4x4 grids of 256x256 cells on a 1024x1024 canvas.

SHEET1_MAP = [
    # Row 0 — fully-grown crops
    (0, 0, "bloat_oat"),
    (0, 1, "heart_berry"),
    (0, 2, "glow_cap"),
    (0, 3, "bomb_pepper"),
    # Row 1 — seed pouches.  Gemini partially relabeled them — visuals still
    # distinguishable (pouch / loaf-ish / skewer / chili) but functionally each
    # is "a small spore container" with the matching crop's accent color.
    (1, 0, "bloat_oat_seed"),
    (1, 1, "heart_berry_seed"),
    (1, 2, "glow_cap_seed"),
    (1, 3, "bomb_pepper_seed"),
    # Row 2 — cooked crop dishes
    (2, 0, "bloat_loaf"),
    (2, 1, "heart_berry_jam"),
    (2, 2, "glow_cap_skewer"),
    (2, 3, "bomb_pepper_chili"),
    # Row 3 — baked goods
    (3, 0, "honeyed_loaf"),
    (3, 1, "bread"),
    (3, 2, "berry_pie"),
    (3, 3, "mushroom_skewer"),
]

SHEET2_MAP = [
    # Row 0 — cooked fish + meat dishes
    (0, 0, "fish_grilled_basic"),
    (0, 1, "fish_grilled_salt"),
    (0, 2, "fish_stew"),
    (0, 3, "dried_meat"),
    # Row 1 — boss food + tonics + revive
    (1, 0, "glaurem_jerky"),
    (1, 1, "combat_tonic"),
    (1, 2, "crafting_tonic"),
    (1, 3, "pet_revive_charm"),
    # Row 2 — raw ingredients
    (2, 0, "honey"),
    (2, 1, "flour"),
    (2, 2, "raw_meat"),
    (2, 3, "fertilizer"),
    # Row 3 — tools and misc
    (3, 0, "bug_net"),
    (3, 1, "canteen"),
    (3, 2, "canteen_full"),
    (3, 3, "coral_fragment"),
]

SHEET3_MAP = [
    # Row 0 — bait + copper rod
    (0, 0, "bait_basic"),
    (0, 1, "bait_glow"),
    (0, 2, "bait_meat"),
    (0, 3, "fishing_rod_copper"),
    # Row 1 — iron rod + blanks
    (1, 0, "fishing_rod_iron"),
    (1, 1, None),
    (1, 2, None),
    (1, 3, None),
    # Row 2 — fish set A
    (2, 0, "root_bream"),
    (2, 1, "glow_eel"),
    (2, 2, "tide_perch"),
    (2, 3, "glass_pike"),
    # Row 3 — fish set B + pearl
    (3, 0, "vesari_eel"),
    (3, 1, "deep_pike"),
    (3, 2, None),  # duplicate-pike cell; unused
    (3, 3, "drowned_pearl"),
]

SHEET4_MAP = [
    # Row 0 — critters set A
    (0, 0, "critter_glow_moth"),
    (0, 1, "critter_cave_cricket"),
    (0, 2, "critter_root_ant"),
    (0, 3, "critter_glass_beetle"),
    # Row 1 — critters set B + blanks
    (1, 0, "critter_salt_fly"),
    (1, 1, "critter_deep_jelly"),
    (1, 2, None),
    (1, 3, None),
    # Row 2 — pets
    (2, 0, "pet_pale_fox"),
    (2, 1, "pet_charred_goat"),
    (2, 2, "pet_root_finch"),
    (2, 3, "pet_lantern_eel"),
    # Row 3 — blanks
    (3, 0, None),
    (3, 1, None),
    (3, 2, None),
    (3, 3, None),
]

SHEET5_MAP = [
    # Row 0 — sprinkler, aquarium, composter, greenhouse
    (0, 0, "sprinkler_placeable"),
    (0, 1, "aquarium_placeable"),
    (0, 2, "composter_placeable"),
    (0, 3, "greenhouse_placeable"),
    # Row 1 — beehive, drying rack, mill, oven
    (1, 0, "beehive_placeable"),
    (1, 1, "drying_rack_placeable"),
    (1, 2, "mill_placeable"),
    (1, 3, "oven_placeable"),
    # Row 2 — pot planter, trellis, sapling, crystal sprig
    (2, 0, "pot_planter_placeable"),
    (2, 1, "trellis_placeable"),
    (2, 2, "sapling_placeable"),
    (2, 3, "crystal_sprig"),
    # Row 3 — coral sprig, fish trophy, net trap, glow cap placeable
    (3, 0, "coral_sprig"),
    (3, 1, "fish_trophy_placeable"),
    (3, 2, "net_trap_placeable"),
    (3, 3, "glow_cap_placeable"),
]

# Ticket 3.31 (reassigned to Phase 8) — tannery production chain. 3 used cells
# in a single 4x4 sheet (rest blank).
SHEET6_MAP = [
    (0, 0, "hide"),
    (0, 1, "leather"),
    (0, 2, "tannery_placeable"),
    (0, 3, None),
    (1, 0, None), (1, 1, None), (1, 2, None), (1, 3, None),
    (2, 0, None), (2, 1, None), (2, 2, None), (2, 3, None),
    (3, 0, None), (3, 1, None), (3, 2, None), (3, 3, None),
]


def split_sheet(src_rel: str, mapping: list, icon_h_frac: float = 0.78) -> list[Path]:
    """Split a 4x4 Gemini sheet into individual 16x16 PNGs.

    icon_h_frac < 1.0 trims the bottom of each cell so visible text labels
    Gemini sometimes injects don't poison the content bbox.
    """
    src = REPO / src_rel
    img = Image.open(src).convert("RGBA")
    sw, sh = img.size
    cell_w = sw // 4
    cell_h = sh // 4
    outputs: list[Path] = []
    dst_dir = REPO / "assets/sprites/items"
    dst_dir.mkdir(parents=True, exist_ok=True)
    print(f"[sheet] {src.relative_to(REPO)} ({sw}x{sh}) cell={cell_w}x{cell_h}")
    for entry in mapping:
        r, c, name = entry
        if name is None:
            continue
        x0 = c * cell_w
        y0 = r * cell_h
        x1 = x0 + cell_w
        y1 = y0 + int(cell_h * icon_h_frac)
        bbox = find_content_bbox(img, (x0, y0, x1, y1))
        bbox = pad_to_aspect(bbox, sw, sh, 16, 16)
        cropped = img.crop(bbox)
        final = cropped.resize((16, 16), Image.Resampling.NEAREST)
        final = magenta_to_alpha(final)
        dst = dst_dir / f"{name}.png"
        final.save(dst)
        outputs.append(dst)
        print(f"  {name}: cell=({r},{c}) bbox={bbox} -> {dst.relative_to(REPO)}")
    return outputs


def main() -> int:
    all_outputs: list[Path] = []

    # Sheet 1 has visible bottom labels — crop top 78%.
    all_outputs += split_sheet(
        "assets/raw/items/items_phase8_sheet1_crops_food.png",
        SHEET1_MAP,
        icon_h_frac=0.78,
    )
    # Sheet 2 — Gemini complied, no labels.
    all_outputs += split_sheet(
        "assets/raw/items/items_phase8_sheet2_fish_raw_tools.png",
        SHEET2_MAP,
        icon_h_frac=1.0,
    )
    # Sheet 3 has labels — crop.
    all_outputs += split_sheet(
        "assets/raw/items/items_phase8_sheet3_fishing_fish.png",
        SHEET3_MAP,
        icon_h_frac=0.78,
    )
    # Sheet 4 — no labels.
    all_outputs += split_sheet(
        "assets/raw/items/items_phase8_sheet4_critters_pets.png",
        SHEET4_MAP,
        icon_h_frac=1.0,
    )
    # Sheet 5 — no labels.
    all_outputs += split_sheet(
        "assets/raw/items/items_phase8_sheet5_structures.png",
        SHEET5_MAP,
        icon_h_frac=1.0,
    )
    # Sheet 6 — Tannery (ticket 3.31 / Phase 8). One label visible on the
    # tannery cell (Gemini drew a "TANNERY" sign), but the icon sits above
    # cell midline so a 0.78 crop loses it cleanly.
    all_outputs += split_sheet(
        "assets/raw/items/items_phase8_sheet6_tannery.png",
        SHEET6_MAP,
        icon_h_frac=0.78,
    )

    for path in all_outputs:
        run_clean_alpha(path)

    print(f"\nProcessed {len(all_outputs)} Phase 8 sprites.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
