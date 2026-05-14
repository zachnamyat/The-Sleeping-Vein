#!/usr/bin/env python3
"""Bulk-add icon ExtResource references to ItemDef .tres files.

Reads a list of (item_id, icon_path) pairs and rewrites each matching .tres
file in resources/items/ to declare the icon. Idempotent — skips files that
already have an `icon = ExtResource(...)` line.

Pattern handled:
- The .tres has `[ext_resource type="Script" ... id="1_def"]` (always present).
- We add `[ext_resource type="Texture2D" path="..." id="2_icon"]` after it.
- We add `icon = ExtResource("2_icon")` immediately after the `script = ExtResource("1_def")` line.

Run once after generating the icon PNGs.
"""
from __future__ import annotations

from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# (item_id stem, icon path)
TARGETS = [
    ("loam",                     "res://assets/sprites/items/loam.png"),
    ("loambeetle",               "res://assets/sprites/items/loambeetle.png"),
    ("ancient_coin",             "res://assets/sprites/items/ancient_coin.png"),
    ("lantern_glint",            "res://assets/sprites/items/lantern_glint.png"),
    ("respec_scroll",            "res://assets/sprites/items/respec_scroll.png"),
    ("pale_cap",                 "res://assets/sprites/items/pale_cap.png"),
    ("memory_root",              "res://assets/sprites/items/memory_root.png"),
    ("fishing_rod_wood",         "res://assets/sprites/items/fishing_rod_wood.png"),
    ("pale_cap_seed",            "res://assets/sprites/items/pale_cap_seed.png"),
    ("memory_root_seed",         "res://assets/sprites/items/memory_root_seed.png"),
    ("pale_cap_stew",            "res://assets/sprites/items/pale_cap_stew.png"),
    ("memory_root_broth",        "res://assets/sprites/items/memory_root_broth.png"),
    ("loam_loaf",                "res://assets/sprites/items/loam_loaf.png"),
    ("cave_guppy",               "res://assets/sprites/items/cave_guppy.png"),
    ("salt_minnow",              "res://assets/sprites/items/salt_minnow.png"),
    ("sovereign_name_fragment_1","res://assets/sprites/items/sovereign_name_fragment_1.png"),
]


def wire_one(stem: str, icon_path: str) -> str:
    tres = REPO / "resources" / "items" / f"{stem}.tres"
    if not tres.exists():
        return f"SKIP missing  {tres}"
    text = tres.read_text(encoding="utf-8")
    if "icon = ExtResource" in text:
        return f"SKIP wired    {tres.name}"
    # Find the script ExtResource line and add a Texture2D ExtResource after it.
    script_line_marker = '[ext_resource type="Script" path="res://scripts/resources/item_def.gd" id="1_def"]'
    if script_line_marker not in text:
        return f"SKIP no-script {tres.name}"
    icon_ext = f'[ext_resource type="Texture2D" path="{icon_path}" id="2_icon"]'
    text = text.replace(
        script_line_marker,
        f"{script_line_marker}\n{icon_ext}",
    )
    # Find `script = ExtResource("1_def")` and add icon = ExtResource("2_icon") after it.
    script_assign = 'script = ExtResource("1_def")'
    if script_assign not in text:
        return f"SKIP no-assign {tres.name}"
    text = text.replace(
        script_assign,
        f'{script_assign}\nicon = ExtResource("2_icon")',
    )
    tres.write_text(text, encoding="utf-8")
    return f"WIRED         {tres.name}"


def main() -> int:
    for stem, icon in TARGETS:
        print(wire_one(stem, icon))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
