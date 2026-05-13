#!/usr/bin/env python3
"""Post-process the five Phase 2 Gemini outputs into final pixel-art assets.

Pipeline mirrors tools/process_phase1_assets.py:

1. Pillow: find non-magenta content bbox (hue-dominance bg detection).
2. Pillow: crop to bbox.
3. Pillow: NEAREST-NEIGHBOR downsample to target size.
4. Pillow: magenta-keyed initial alpha.
5. Delegate to tools/clean_alpha.ps1 (ImageMagick): fuzz + binary alpha
   threshold to remove anti-aliased magenta edges.
6. Delegate to tools/snap_to_palette.py: enforce sleeping_vein.json palette.

Assets:
- assets/raw/items/wooden_axe_v1.png   -> assets/sprites/items/wooden_axe.png       16x16
- assets/raw/items/wood_v1.png         -> assets/sprites/items/wood.png             16x16
- assets/raw/items/heartwood_v1.png    -> assets/sprites/items/heartwood.png        16x16
- assets/raw/items/bomb_v1.png         -> assets/sprites/items/bomb.png             16x16
- assets/raw/world/tree_root_hollows_v1.png -> assets/sprites/world/tree_root_hollows.png 16x24

Run once after generating via the gemini-image MCP. Idempotent.
"""
from __future__ import annotations

import subprocess
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent


def is_magenta(px: tuple, tol: int = 0) -> bool:
    """Detect 'magenta-ish' pixels including Gemini's desaturated drift."""
    r, g, b = px[0], px[1], px[2]
    return r > 150 and b > 90 and g < 80


def find_content_bbox(img: Image.Image) -> tuple[int, int, int, int]:
    w, h = img.size
    px = img.load()
    left, top, right, bottom = w, h, 0, 0
    found_any = False
    for y in range(h):
        for x in range(w):
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
        return (0, 0, w, h)
    return (left, top, right + 1, bottom + 1)


def pad_to_aspect(bbox: tuple[int, int, int, int], img_w: int, img_h: int, target_w: int, target_h: int) -> tuple[int, int, int, int]:
    """Expand the content bbox so its aspect ratio matches the target. Pads
    symmetrically with magenta from the surrounding canvas; clamps to image
    bounds. Without this, a tall subject in a square frame would get squished
    when downsampled directly to a 2:3 cell."""
    bw = bbox[2] - bbox[0]
    bh = bbox[3] - bbox[1]
    target_ratio = target_w / target_h
    bbox_ratio = bw / bh if bh > 0 else 1.0
    if abs(bbox_ratio - target_ratio) < 0.001:
        return bbox
    if bbox_ratio > target_ratio:
        # Too wide — pad vertically.
        new_h = int(round(bw / target_ratio))
        pad = new_h - bh
        top_pad = pad // 2
        bot_pad = pad - top_pad
        new_top = max(0, bbox[1] - top_pad)
        new_bot = min(img_h, bbox[3] + bot_pad)
        return (bbox[0], new_top, bbox[2], new_bot)
    else:
        # Too tall — pad horizontally.
        new_w = int(round(bh * target_ratio))
        pad = new_w - bw
        left_pad = pad // 2
        right_pad = pad - left_pad
        new_left = max(0, bbox[0] - left_pad)
        new_right = min(img_w, bbox[2] + right_pad)
        return (new_left, bbox[1], new_right, bbox[3])


def downsample_nearest(img: Image.Image, target_w: int, target_h: int) -> Image.Image:
    return img.resize((target_w, target_h), Image.Resampling.NEAREST)


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


def process_one(src_rel: str, dst_rel: str, target_w: int, target_h: int) -> Path:
    src = REPO / src_rel
    dst = REPO / dst_rel
    print(f"[{src.stem}] {src.relative_to(REPO)} -> {dst.relative_to(REPO)}  ({target_w}x{target_h})")
    dst.parent.mkdir(parents=True, exist_ok=True)
    img = Image.open(src).convert("RGBA")
    print(f"  source size: {img.size}")
    bbox = find_content_bbox(img)
    print(f"  content bbox: {bbox}")
    bbox = pad_to_aspect(bbox, img.size[0], img.size[1], target_w, target_h)
    print(f"  padded bbox: {bbox}")
    cropped = img.crop(bbox)
    print(f"  cropped size: {cropped.size}")
    final = downsample_nearest(cropped, target_w, target_h)
    final = magenta_to_alpha(final)
    final.save(dst)
    print(f"  wrote {dst.relative_to(REPO)} ({final.size})")
    return dst


def run_clean_alpha(target: Path) -> None:
    ps_script = REPO / "tools" / "clean_alpha.ps1"
    cmd = [
        "powershell.exe",
        "-ExecutionPolicy", "Bypass",
        "-File", str(ps_script),
        "-Path", str(target),
    ]
    print(f"  -> clean_alpha.ps1 {target.name}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    for line in (result.stdout or "").splitlines():
        print(f"     {line}")
    if result.returncode != 0:
        print(f"     WARN: clean_alpha.ps1 exit {result.returncode}")
        for line in (result.stderr or "").splitlines():
            print(f"     {line}")


def run_snap_palette(target: Path, biome: str | None) -> None:
    cmd = [
        "python",
        str(REPO / "tools" / "snap_to_palette.py"),
        "--in-place",
        str(target),
    ]
    if biome is not None:
        cmd.extend(["--biome", biome])
    biome_str = biome if biome is not None else "(all biomes)"
    print(f"  -> snap_to_palette.py --biome {biome_str} {target.name}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    for line in (result.stdout or "").splitlines():
        print(f"     {line}")


# Each asset can either lock to one biome ramp (pure-biome look) or fall back
# to the full palette (cross-biome icons — axes have wood + iron, bombs have
# grey + ember, heartwood has wood + gold). Tuple is
# (src, dst, w, h, biome_or_None).
ASSETS = [
    ("assets/raw/items/wooden_axe_v1.png",            "assets/sprites/items/wooden_axe.png",          16, 16, None),
    ("assets/raw/items/wood_v1.png",                  "assets/sprites/items/wood.png",                16, 16, "root_hollows"),
    ("assets/raw/items/heartwood_v1.png",             "assets/sprites/items/heartwood.png",           16, 16, None),
    ("assets/raw/items/bomb_v1.png",                  "assets/sprites/items/bomb.png",                16, 16, None),
    ("assets/raw/world/tree_root_hollows_v1.png",     "assets/sprites/world/tree_root_hollows.png",   16, 24, "root_hollows"),
]


def main() -> int:
    for src_rel, dst_rel, w, h, biome in ASSETS:
        out = process_one(src_rel, dst_rel, w, h)
        run_clean_alpha(out)
        run_snap_palette(out, biome)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
