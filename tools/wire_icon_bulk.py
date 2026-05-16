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
    # Phase 8 — crops + seeds.
    ("bloat_oat",                "res://assets/sprites/items/bloat_oat.png"),
    ("bloat_oat_seed",           "res://assets/sprites/items/bloat_oat_seed.png"),
    ("heart_berry",              "res://assets/sprites/items/heart_berry.png"),
    ("heart_berry_seed",         "res://assets/sprites/items/heart_berry_seed.png"),
    ("glow_cap",                 "res://assets/sprites/items/glow_cap.png"),
    ("glow_cap_seed",            "res://assets/sprites/items/glow_cap_seed.png"),
    ("bomb_pepper",              "res://assets/sprites/items/bomb_pepper.png"),
    ("bomb_pepper_seed",         "res://assets/sprites/items/bomb_pepper_seed.png"),
    # Phase 8 — cooked food.
    ("bloat_loaf",               "res://assets/sprites/items/bloat_loaf.png"),
    ("heart_berry_jam",          "res://assets/sprites/items/heart_berry_jam.png"),
    ("glow_cap_skewer",          "res://assets/sprites/items/glow_cap_skewer.png"),
    ("bomb_pepper_chili",        "res://assets/sprites/items/bomb_pepper_chili.png"),
    ("honeyed_loaf",             "res://assets/sprites/items/honeyed_loaf.png"),
    ("bread",                    "res://assets/sprites/items/bread.png"),
    ("berry_pie",                "res://assets/sprites/items/berry_pie.png"),
    ("mushroom_skewer",          "res://assets/sprites/items/mushroom_skewer.png"),
    ("fish_grilled_basic",       "res://assets/sprites/items/fish_grilled_basic.png"),
    ("fish_grilled_salt",        "res://assets/sprites/items/fish_grilled_salt.png"),
    ("fish_stew",                "res://assets/sprites/items/fish_stew.png"),
    ("dried_meat",               "res://assets/sprites/items/dried_meat.png"),
    ("glaurem_jerky",            "res://assets/sprites/items/glaurem_jerky.png"),
    ("combat_tonic",             "res://assets/sprites/items/combat_tonic.png"),
    ("crafting_tonic",           "res://assets/sprites/items/crafting_tonic.png"),
    # Phase 8 — raw ingredients + tools.
    ("honey",                    "res://assets/sprites/items/honey.png"),
    ("flour",                    "res://assets/sprites/items/flour.png"),
    ("raw_meat",                 "res://assets/sprites/items/raw_meat.png"),
    ("fertilizer",               "res://assets/sprites/items/fertilizer.png"),
    ("bug_net",                  "res://assets/sprites/items/bug_net.png"),
    ("canteen",                  "res://assets/sprites/items/canteen.png"),
    ("canteen_full",             "res://assets/sprites/items/canteen_full.png"),
    ("coral_fragment",           "res://assets/sprites/items/coral_fragment.png"),
    ("pet_revive_charm",         "res://assets/sprites/items/pet_revive_charm.png"),
    # Phase 8 — bait + rod tiers.
    ("bait_basic",               "res://assets/sprites/items/bait_basic.png"),
    ("bait_glow",                "res://assets/sprites/items/bait_glow.png"),
    ("bait_meat",                "res://assets/sprites/items/bait_meat.png"),
    ("fishing_rod_copper",       "res://assets/sprites/items/fishing_rod_copper.png"),
    ("fishing_rod_iron",         "res://assets/sprites/items/fishing_rod_iron.png"),
    # Phase 8 — fish species.
    ("root_bream",               "res://assets/sprites/items/root_bream.png"),
    ("glow_eel",                 "res://assets/sprites/items/glow_eel.png"),
    ("tide_perch",               "res://assets/sprites/items/tide_perch.png"),
    ("glass_pike",               "res://assets/sprites/items/glass_pike.png"),
    ("vesari_eel",               "res://assets/sprites/items/vesari_eel.png"),
    ("deep_pike",                "res://assets/sprites/items/deep_pike.png"),
    ("drowned_pearl",            "res://assets/sprites/items/drowned_pearl.png"),
    # Phase 8 — critters.
    ("critter_glow_moth",        "res://assets/sprites/items/critter_glow_moth.png"),
    ("critter_cave_cricket",     "res://assets/sprites/items/critter_cave_cricket.png"),
    ("critter_root_ant",         "res://assets/sprites/items/critter_root_ant.png"),
    ("critter_glass_beetle",     "res://assets/sprites/items/critter_glass_beetle.png"),
    ("critter_salt_fly",         "res://assets/sprites/items/critter_salt_fly.png"),
    ("critter_deep_jelly",       "res://assets/sprites/items/critter_deep_jelly.png"),
    # Phase 8 — pets.
    ("pet_pale_fox",             "res://assets/sprites/items/pet_pale_fox.png"),
    ("pet_charred_goat",         "res://assets/sprites/items/pet_charred_goat.png"),
    ("pet_root_finch",           "res://assets/sprites/items/pet_root_finch.png"),
    ("pet_lantern_eel",          "res://assets/sprites/items/pet_lantern_eel.png"),
    # Phase 8 — placeable structures (inventory icons).
    ("sprinkler_placeable",      "res://assets/sprites/items/sprinkler_placeable.png"),
    ("aquarium_placeable",       "res://assets/sprites/items/aquarium_placeable.png"),
    ("composter_placeable",      "res://assets/sprites/items/composter_placeable.png"),
    ("greenhouse_placeable",     "res://assets/sprites/items/greenhouse_placeable.png"),
    ("beehive_placeable",        "res://assets/sprites/items/beehive_placeable.png"),
    ("drying_rack_placeable",    "res://assets/sprites/items/drying_rack_placeable.png"),
    ("mill_placeable",           "res://assets/sprites/items/mill_placeable.png"),
    ("oven_placeable",           "res://assets/sprites/items/oven_placeable.png"),
    ("pot_planter_placeable",    "res://assets/sprites/items/pot_planter_placeable.png"),
    ("trellis_placeable",        "res://assets/sprites/items/trellis_placeable.png"),
    ("sapling_placeable",        "res://assets/sprites/items/sapling_placeable.png"),
    ("crystal_sprig",            "res://assets/sprites/items/crystal_sprig.png"),
    ("coral_sprig",              "res://assets/sprites/items/coral_sprig.png"),
    ("fish_trophy_placeable",    "res://assets/sprites/items/fish_trophy_placeable.png"),
    ("net_trap_placeable",       "res://assets/sprites/items/net_trap_placeable.png"),
    ("glow_cap_placeable",       "res://assets/sprites/items/glow_cap_placeable.png"),
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
