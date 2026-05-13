#!/usr/bin/env python3
"""Post-process the three Phase 1 Gemini outputs into final pixel-art assets.

Bridges the canonical Phase 0 pipeline (docs/design/01_asset_pipeline.md) to
the Phase 1 atlas + VFX outputs. Pipeline order:

1. Pillow: find non-background content bbox (hue-dominance bg detection,
   robust to Gemini's drifted "magenta" of ~RGB 220,40,137).
2. Pillow: crop to bbox.
3. Pillow: NEAREST-NEIGHBOR downsample to target size. (The gemini-image MCP's
   `process_image` uses sharp.resize which defaults to lanczos3 -- wrong for
   pixel art. The canonical doc says "nearest-neighbor" but the MCP doesn't
   expose it, so Pillow fills that gap.)
4. Pillow: write intermediate PNG with magenta keyed to alpha=0.
5. Delegate to tools/clean_alpha.ps1 (ImageMagick): multi-shade fuzz + binary
   alpha threshold -- same step as every Phase 0 asset.
6. Delegate to tools/snap_to_palette.py: palette enforcement against the
   sleeping_vein.json biome ramps.

Run once after generating with the gemini-image MCP. Idempotent.
"""
from __future__ import annotations

import subprocess
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent
MAGENTA = (255, 0, 255)


def is_magenta(px: tuple, tol: int = 0) -> bool:
    """Detect 'magenta-ish' pixels including Gemini's desaturated drift.

    The model rarely outputs pure #FF00FF — observed values centre around
    (220, 40, 137). Test by hue dominance: R high + B mid+, G low.
    """
    r, g, b = px[0], px[1], px[2]
    return r > 150 and b > 90 and g < 80


def find_content_bbox(img: Image.Image) -> tuple[int, int, int, int]:
    """Return (left, top, right, bottom) for non-magenta content."""
    w, h = img.size
    px = img.load()
    left, top, right, bottom = w, h, 0, 0
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if len(p) >= 3 and not is_magenta(p):
                if x < left:
                    left = x
                if y < top:
                    top = y
                if x > right:
                    right = x
                if y > bottom:
                    bottom = y
    if right <= left or bottom <= top:
        return (0, 0, w, h)
    return (left, top, right + 1, bottom + 1)


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


def process_atlas() -> None:
    """Ticket 1.12 — full 256×256 Root Hollows atlas."""
    src = REPO / "assets" / "raw" / "tiles" / "root_hollows_atlas_v1.png"
    dst = REPO / "assets" / "sprites" / "tiles" / "root_hollows_atlas_16.png"
    print(f"[atlas] {src.name} -> {dst.name}")
    img = Image.open(src).convert("RGBA")
    print(f"  source size: {img.size}")
    # Full image is the atlas content (no magenta border). Downsample to 256x256.
    final = downsample_nearest(img, 256, 256)
    final.save(dst)
    print(f"  wrote {dst} ({final.size})")


def process_floor_wall() -> None:
    """Ticket 1.5 — temporary 32×48 placeholder atlas."""
    src = REPO / "assets" / "raw" / "tiles" / "root_hollows_floor_wall_v1.png"
    dst = REPO / "assets" / "sprites" / "tiles" / "root_hollows_floor_wall.png"
    print(f"[floor_wall] {src.name} -> {dst.name}")
    img = Image.open(src).convert("RGBA")
    print(f"  source size: {img.size}")
    # Crop to non-magenta bounding box, then downsample to 32×48.
    bbox = find_content_bbox(img)
    print(f"  content bbox: {bbox}")
    cropped = img.crop(bbox)
    print(f"  cropped size: {cropped.size}")
    final = downsample_nearest(cropped, 32, 48)
    final = magenta_to_alpha(final)
    final.save(dst)
    print(f"  wrote {dst} ({final.size})")


def process_hand_of_light() -> None:
    """Ticket 1.9 — 48×8 hand-of-light glow strip, 6 frames."""
    # Pick whichever file Gemini saved (auto-version suffix may have applied)
    raw_dir = REPO / "assets" / "raw" / "vfx"
    candidates = sorted(raw_dir.glob("hand_of_light_v1*.png"))
    if not candidates:
        print(f"[hand_of_light] no source found in {raw_dir}")
        return
    src = candidates[-1]  # latest version
    dst = REPO / "assets" / "sprites" / "vfx" / "hand_of_light.png"
    print(f"[hand_of_light] {src.name} -> {dst.name}")
    img = Image.open(src).convert("RGBA")
    print(f"  source size: {img.size}")
    # Find the 6-frame strip's bounding box (Gemini centered it horizontally).
    bbox = find_content_bbox(img)
    print(f"  content bbox: {bbox}")
    cropped = img.crop(bbox)
    print(f"  cropped size: {cropped.size}")
    final = downsample_nearest(cropped, 48, 8)
    final = magenta_to_alpha(final)
    final.save(dst)
    print(f"  wrote {dst} ({final.size})")


def run_clean_alpha(target: Path) -> None:
    """Delegate to the canonical Phase 0 chroma-key + binary-alpha pass."""
    ps_script = REPO / "tools" / "clean_alpha.ps1"
    cmd = [
        "powershell.exe",
        "-ExecutionPolicy", "Bypass",
        "-File", str(ps_script),
        "-Path", str(target),
    ]
    print(f"  -> clean_alpha.ps1 {target.name}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        for line in result.stdout.splitlines():
            print(f"     {line}")
    if result.returncode != 0:
        print(f"     WARN: clean_alpha.ps1 exit code {result.returncode}")
        if result.stderr:
            print(f"     {result.stderr}")


def run_snap_palette(target: Path, biome: str) -> None:
    """Delegate to the canonical palette enforcement pass."""
    cmd = [
        "python",
        str(REPO / "tools" / "snap_to_palette.py"),
        "--biome", biome,
        "--in-place",
        str(target),
    ]
    print(f"  -> snap_to_palette.py --biome {biome} {target.name}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        for line in result.stdout.splitlines():
            print(f"     {line}")


def main() -> int:
    (REPO / "assets" / "sprites" / "tiles").mkdir(parents=True, exist_ok=True)
    (REPO / "assets" / "sprites" / "vfx").mkdir(parents=True, exist_ok=True)
    process_atlas()
    run_clean_alpha(REPO / "assets" / "sprites" / "tiles" / "root_hollows_atlas_16.png")
    run_snap_palette(REPO / "assets" / "sprites" / "tiles" / "root_hollows_atlas_16.png", "root_hollows")
    process_floor_wall()
    run_clean_alpha(REPO / "assets" / "sprites" / "tiles" / "root_hollows_floor_wall.png")
    run_snap_palette(REPO / "assets" / "sprites" / "tiles" / "root_hollows_floor_wall.png", "root_hollows")
    process_hand_of_light()
    run_clean_alpha(REPO / "assets" / "sprites" / "vfx" / "hand_of_light.png")
    run_snap_palette(REPO / "assets" / "sprites" / "vfx" / "hand_of_light.png", "final_spiral")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
