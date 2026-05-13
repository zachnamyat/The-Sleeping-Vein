#!/usr/bin/env python3
"""Palette conformance checker for The Sleeping Vein sprites.

Reads assets/palettes/sleeping_vein.json and verifies every non-transparent
pixel in the given image(s) matches a palette color. Closes the tooling
half of roadmap ticket 0.5; see docs/design/00_tile_atlas_spec.md §6.

Usage:
    python tools/check_palette.py <image-or-glob> [more...] [--biome NAME] [--strict] [--quiet]

Examples:
    python tools/check_palette.py assets/sprites/tiles/smoke_test_shaleseed.png
    python tools/check_palette.py "assets/sprites/structures/*.png"
    python tools/check_palette.py assets/sprites/enemies/root_hollows/*.png --biome root_hollows --strict

Exit codes:
    0  every checked image is fully palette-conformant
    1  one or more images contain off-palette pixels
    2  argument or IO error
"""
from __future__ import annotations

import argparse
import glob
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Iterable

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parent.parent
PALETTE_PATH = REPO_ROOT / "assets" / "palettes" / "sleeping_vein.json"
ALPHA_TRANSPARENCY_THRESHOLD = 8  # pixels with alpha <= this are treated as transparent


def hex_to_rgb(hex_color: str) -> tuple[int, int, int]:
    h = hex_color.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def load_palette(biome_filter: str | None) -> tuple[set[tuple[int, int, int]], dict[str, list[str]]]:
    """Return (allowed_rgb_set, ramp_summary) for reporting."""
    data = json.loads(PALETTE_PATH.read_text(encoding="utf-8"))
    allowed: set[tuple[int, int, int]] = set()
    summary: dict[str, list[str]] = {}

    universal = data.get("universal", {})
    for name, hex_val in universal.items():
        if name == "background_key":
            continue  # magenta key is never a valid pixel color
        allowed.add(hex_to_rgb(hex_val))
        summary.setdefault("universal", []).append(hex_val)

    biome_ramps = data.get("biome_ramps", {})
    if biome_filter is not None:
        if biome_filter not in biome_ramps:
            raise SystemExit(f"check_palette: unknown biome '{biome_filter}'. Known: {sorted(biome_ramps)}")
        ramps = {biome_filter: biome_ramps[biome_filter]}
    else:
        ramps = biome_ramps
    for biome, hex_list in ramps.items():
        for hex_val in hex_list:
            allowed.add(hex_to_rgb(hex_val))
        summary[biome] = list(hex_list)

    return allowed, summary


def expand_inputs(patterns: Iterable[str]) -> list[Path]:
    out: list[Path] = []
    seen: set[Path] = set()
    for pat in patterns:
        matched = [Path(p) for p in glob.glob(pat)] if any(c in pat for c in "*?[") else [Path(pat)]
        if not matched:
            print(f"check_palette: no files matched pattern '{pat}'", file=sys.stderr)
        for p in matched:
            rp = p.resolve()
            if rp in seen:
                continue
            seen.add(rp)
            out.append(p)
    return out


def _nearest_distance(rgb: tuple[int, int, int], palette: list[tuple[int, int, int]]) -> int:
    """Manhattan distance to the closest palette color."""
    r, g, b = rgb
    best = 765  # 3 * 255
    for pr, pg, pb in palette:
        d = abs(r - pr) + abs(g - pg) + abs(b - pb)
        if d < best:
            best = d
            if best == 0:
                return 0
    return best


def check_image(
    path: Path,
    allowed: set[tuple[int, int, int]],
    tolerance: int = 0,
) -> tuple[int, int, Counter[tuple[int, int, int]]]:
    """Return (total_opaque_pixels, off_palette_pixel_count, Counter of off-palette colors).

    A pixel is considered on-palette when its Manhattan distance to the closest
    palette color is <= tolerance. tolerance=0 means exact match only.
    """
    with Image.open(path) as img:
        rgba = img.convert("RGBA")
        raw = rgba.tobytes()
    palette_list = list(allowed)
    total_opaque = 0
    off_counter: Counter[tuple[int, int, int]] = Counter()
    near_cache: dict[tuple[int, int, int], int] = {}
    for i in range(0, len(raw), 4):
        a = raw[i + 3]
        if a <= ALPHA_TRANSPARENCY_THRESHOLD:
            continue
        total_opaque += 1
        rgb = (raw[i], raw[i + 1], raw[i + 2])
        if rgb in allowed:
            continue
        if tolerance > 0:
            d = near_cache.get(rgb)
            if d is None:
                d = _nearest_distance(rgb, palette_list)
                near_cache[rgb] = d
            if d <= tolerance:
                continue
        off_counter[rgb] += 1
    off_total = sum(off_counter.values())
    return total_opaque, off_total, off_counter


def format_hex(rgb: tuple[int, int, int]) -> str:
    return "#{:02x}{:02x}{:02x}".format(*rgb)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Verify a sprite's pixels lie within the project palette.")
    ap.add_argument("inputs", nargs="*", help="Image paths or glob patterns")
    ap.add_argument("--biome", default=None,
                    help="Restrict palette to universal + this biome's ramp (else all biomes accepted)")
    ap.add_argument("--tolerance", type=int, default=0,
                    help="Manhattan-distance tolerance to nearest palette color (default 0 = exact match)")
    ap.add_argument("--strict", action="store_true",
                    help="Exit non-zero on any off-palette pixel (default: warn-only)")
    ap.add_argument("--quiet", action="store_true",
                    help="Suppress per-image OK output; print only failures and summary")
    ap.add_argument("--list-palette", action="store_true",
                    help="Print the active palette swatches and exit")
    args = ap.parse_args(argv)

    try:
        allowed, summary = load_palette(args.biome)
    except FileNotFoundError:
        print(f"check_palette: palette file missing at {PALETTE_PATH}", file=sys.stderr)
        return 2

    if args.list_palette:
        for group, hex_list in summary.items():
            print(f"[{group}]  {'  '.join(hex_list)}")
        print(f"total allowed colors: {len(allowed)}")
        return 0

    if not args.inputs:
        ap.print_usage(sys.stderr)
        print("check_palette: pass at least one image path or use --list-palette", file=sys.stderr)
        return 2

    targets = expand_inputs(args.inputs)
    if not targets:
        print("check_palette: no input files found", file=sys.stderr)
        return 2

    any_failures = False
    for path in targets:
        try:
            total_opaque, off_total, off_counter = check_image(path, allowed, args.tolerance)
        except (FileNotFoundError, OSError) as e:
            print(f"FAIL  {path}: {e}")
            any_failures = True
            continue
        if off_total == 0:
            if not args.quiet:
                tol_note = f", tolerance={args.tolerance}" if args.tolerance else ""
                print(f"OK    {path}  ({total_opaque} opaque px, palette-clean{tol_note})")
            continue
        any_failures = True
        pct = 100.0 * off_total / total_opaque if total_opaque else 0.0
        print(f"FAIL  {path}  {off_total}/{total_opaque} opaque px off-palette ({pct:.1f}%, tolerance={args.tolerance})")
        for color, count in off_counter.most_common(8):
            print(f"        {format_hex(color)}  rgb{color}  x{count}")
        if len(off_counter) > 8:
            print(f"        ... plus {len(off_counter) - 8} more unique colors")

    if any_failures and args.strict:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
