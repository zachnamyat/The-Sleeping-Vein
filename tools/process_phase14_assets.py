#!/usr/bin/env python3
"""Split the Phase 14 Gemini sheets into canonical PNGs.

Phase 14 produces three raw item sheets, each a 4x4 grid on magenta:
  - items_phase14_sheet1_automation_core.png — 16x16 icons
  - items_phase14_sheet2_power_logic.png      — 16x16 icons
  - items_phase14_sheet3_tools_buckets_paint.png — 16x16 icons

Reuses the bbox detection + magenta-key + clean_alpha helpers from the
Phase 10 processor.
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
# Mapping tables (matches the prompts in Phase 14 closure).
# ---------------------------------------------------------------------------

SHEET1_AUTOMATION_MAP = [
    (0, 0, "conveyor_belt"),
    (0, 1, "drill_placeable"),
    (0, 2, "robotic_arm"),
    (0, 3, "aphelion_tap"),
    (1, 0, "wire"),
    (1, 1, "pressure_plate"),
    (1, 2, "button"),
    (1, 3, "logic_gate_and"),
    (2, 0, "sensor"),
    (2, 1, "storage_piping"),
    (2, 2, "auto_sprinkler"),
    (2, 3, "auto_harvester"),
    (3, 0, "auto_furnace"),
    (3, 1, "auto_smelter"),
    (3, 2, "power_storage_cell"),
    (3, 3, "splitter"),
]

SHEET2_POWER_LOGIC_MAP = [
    (0, 0, "logic_gate_or"),
    (0, 1, "logic_gate_not"),
    (0, 2, "logic_gate_nand"),
    (0, 3, "logic_gate_xor"),
    (1, 0, "timer_block"),
    (1, 1, "hopper"),
    (1, 2, "item_filter"),
    (1, 3, "signal_transmitter"),
    (2, 0, "signal_receiver"),
    (2, 1, "mob_farm_block"),
    (2, 2, "glass_block"),
    (2, 3, "fence_gate"),
    (3, 0, "auctioneer_node"),
    (3, 1, "auto_cooking_pot"),
    (3, 2, "auto_fishing_rig"),
    (3, 3, "wireless_relay"),
]

SHEET3_TOOLS_BUCKETS_MAP = [
    (0, 0, "bucket_empty"),
    (0, 1, "bucket_full_water"),
    (0, 2, "bucket_full_lava"),
    (0, 3, "bucket_full_slime"),
    (1, 0, "bucket_full_acid"),
    (1, 1, "paint_brush"),
    (1, 2, "color_wheel_palette"),
    (1, 3, "pattern_paint_stamp"),
    (2, 0, "wallpaper_roll"),
    (2, 1, "demolition_tool"),
    (2, 2, "blueprint_tool"),
    (2, 3, "place_grid_toggle"),
    (3, 0, "merger"),
    (3, 1, "signal_relay"),
    (3, 2, "mod_compat_token"),
    (3, 3, "sample_mod_kit"),
]


def main() -> None:
    items_out = REPO / "assets" / "sprites" / "items"
    structures_out = REPO / "assets" / "sprites" / "structures"

    out: list[Path] = []
    out += split_grid("assets/raw/items/items_phase14_sheet1_automation_core.png", 4, 4, 16, SHEET1_AUTOMATION_MAP, items_out)
    out += split_grid("assets/raw/items/items_phase14_sheet2_power_logic.png", 4, 4, 16, SHEET2_POWER_LOGIC_MAP, items_out)
    out += split_grid("assets/raw/items/items_phase14_sheet3_tools_buckets_paint.png", 4, 4, 16, SHEET3_TOOLS_BUCKETS_MAP, items_out)

    # Run clean_alpha (binary alpha threshold) on each file individually so
    # corrupted edges from the resize get cleaned up.
    for p in out:
        run_clean_alpha(p)

    print(f"[done] {len(out)} sprites written")


if __name__ == "__main__":
    main()
