#!/usr/bin/env python3
"""Quantize PNG sprites to the project palette.

Companion to tools/check_palette.py. Reads assets/palettes/sleeping_vein.json,
remaps every opaque pixel in the input image to its nearest palette color
(Manhattan distance), and writes the snapped image. Closes the missing
"snap" step in docs/design/01_asset_pipeline.md Stage 4.

Usage:
    python tools/snap_to_palette.py <image> [more...] [--biome NAME] [--in-place | --suffix S]
                                              [--dry-run] [--report]

Examples:
    python tools/snap_to_palette.py assets/sprites/structures/chest.png --in-place
    python tools/snap_to_palette.py assets/sprites/enemies/root_hollows/*.png --biome root_hollows --in-place
    python tools/snap_to_palette.py assets/sprites/structures/loom.png --suffix _snapped --report

Default writes <name>_snapped.png next to the source. --in-place overwrites.
"""
from __future__ import annotations

import argparse
import glob
import json
import sys
from pathlib import Path
from typing import Iterable

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parent.parent
PALETTE_PATH = REPO_ROOT / "assets" / "palettes" / "sleeping_vein.json"
ALPHA_TRANSPARENCY_THRESHOLD = 8


def hex_to_rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def load_palette(biome_filter: str | None) -> list[tuple[int, int, int]]:
    data = json.loads(PALETTE_PATH.read_text(encoding="utf-8"))
    palette: list[tuple[int, int, int]] = []
    for name, hex_val in (data.get("universal") or {}).items():
        if name == "background_key":
            continue
        palette.append(hex_to_rgb(hex_val))
    biome_ramps = data.get("biome_ramps", {})
    if biome_filter is not None:
        if biome_filter not in biome_ramps:
            raise SystemExit(f"snap_to_palette: unknown biome '{biome_filter}'. Known: {sorted(biome_ramps)}")
        ramps = {biome_filter: biome_ramps[biome_filter]}
    else:
        ramps = biome_ramps
    for hex_list in ramps.values():
        for hex_val in hex_list:
            palette.append(hex_to_rgb(hex_val))
    # De-dup while preserving order.
    seen: set[tuple[int, int, int]] = set()
    out: list[tuple[int, int, int]] = []
    for rgb in palette:
        if rgb not in seen:
            seen.add(rgb)
            out.append(rgb)
    return out


def nearest(rgb: tuple[int, int, int], palette: list[tuple[int, int, int]]) -> tuple[int, int, int]:
    r, g, b = rgb
    best = palette[0]
    best_d = 765
    for pr, pg, pb in palette:
        d = abs(r - pr) + abs(g - pg) + abs(b - pb)
        if d < best_d:
            best_d = d
            best = (pr, pg, pb)
            if best_d == 0:
                return best
    return best


def expand_inputs(patterns: Iterable[str]) -> list[Path]:
    out: list[Path] = []
    seen: set[Path] = set()
    for pat in patterns:
        matched = [Path(p) for p in glob.glob(pat)] if any(c in pat for c in "*?[") else [Path(pat)]
        if not matched:
            print(f"snap_to_palette: no files matched pattern '{pat}'", file=sys.stderr)
        for p in matched:
            rp = p.resolve()
            if rp in seen:
                continue
            seen.add(rp)
            out.append(p)
    return out


def snap_one(
    src: Path,
    dst: Path,
    palette: list[tuple[int, int, int]],
    dry_run: bool,
    report: bool,
) -> tuple[int, int]:
    """Return (changed_pixel_count, total_opaque_pixel_count)."""
    with Image.open(src) as img:
        rgba = img.convert("RGBA")
    width, height = rgba.size
    raw = bytearray(rgba.tobytes())
    cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}
    changed = 0
    total_opaque = 0
    for i in range(0, len(raw), 4):
        a = raw[i + 3]
        if a <= ALPHA_TRANSPARENCY_THRESHOLD:
            continue
        total_opaque += 1
        rgb = (raw[i], raw[i + 1], raw[i + 2])
        snapped = cache.get(rgb)
        if snapped is None:
            snapped = nearest(rgb, palette)
            cache[rgb] = snapped
        if snapped != rgb:
            raw[i] = snapped[0]
            raw[i + 1] = snapped[1]
            raw[i + 2] = snapped[2]
            changed += 1
    if not dry_run:
        snapped_img = Image.frombytes("RGBA", (width, height), bytes(raw))
        snapped_img.save(dst)
    if report:
        print(f"  unique input colors:    {len(cache)}")
        print(f"  unique output colors:   {len(set(cache.values()))}")
        for src_rgb, dst_rgb in sorted(cache.items()):
            if src_rgb == dst_rgb:
                continue
            print(f"    #{src_rgb[0]:02x}{src_rgb[1]:02x}{src_rgb[2]:02x} -> #{dst_rgb[0]:02x}{dst_rgb[1]:02x}{dst_rgb[2]:02x}")
    return changed, total_opaque


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Quantize PNG sprites to the project palette.")
    ap.add_argument("inputs", nargs="+", help="Image paths or glob patterns")
    ap.add_argument("--biome", default=None,
                    help="Restrict palette to universal + this biome's ramp")
    group = ap.add_mutually_exclusive_group()
    group.add_argument("--in-place", action="store_true", help="Overwrite the input file")
    group.add_argument("--suffix", default="_snapped",
                       help="Append this suffix before .png when writing (default: _snapped)")
    ap.add_argument("--dry-run", action="store_true", help="Compute snap mapping but do not write output")
    ap.add_argument("--report", action="store_true", help="Print color-by-color remap table")
    args = ap.parse_args(argv)

    try:
        palette = load_palette(args.biome)
    except FileNotFoundError:
        print(f"snap_to_palette: palette file missing at {PALETTE_PATH}", file=sys.stderr)
        return 2

    targets = expand_inputs(args.inputs)
    if not targets:
        print("snap_to_palette: no input files found", file=sys.stderr)
        return 2

    for src in targets:
        if args.in_place:
            dst = src
        else:
            dst = src.with_name(src.stem + args.suffix + src.suffix)
        action = "DRY-RUN" if args.dry_run else ("WROTE  " if dst != src else "SNAPPED")
        try:
            changed, total = snap_one(src, dst, palette, args.dry_run, args.report)
        except (FileNotFoundError, OSError) as e:
            print(f"FAIL   {src}: {e}")
            continue
        pct = 100.0 * changed / total if total else 0.0
        print(f"{action} {src} -> {dst}  ({changed}/{total} px remapped, {pct:.1f}%)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
