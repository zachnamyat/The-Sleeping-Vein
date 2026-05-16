#!/usr/bin/env python3
"""Generate Phase 14 ItemDef .tres files in bulk.

Each entry produces a .tres that points at the icon under
`assets/sprites/items/<icon_name>.png`.

Item types (matches scripts/resources/item_def.gd ItemType enum):
  0 MATERIAL  1 TOOL  2 WEAPON  3 ARMOR  4 CONSUMABLE  5 PLACEABLE  6 AMMO  7 KEY
"""
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "resources" / "items"
OUT.mkdir(parents=True, exist_ok=True)


def write_item(
    id: str,
    icon: str,
    display: str,
    desc: str,
    item_type: int = 5,
    tier: int = 2,
    rarity: int = 1,
    max_stack: int = 99,
    extra: list[str] | None = None,
    uid_short: str | None = None,
) -> None:
    """Emit a .tres ItemDef. UID is derived from the id (hash-style)."""
    short = uid_short or id.replace("_", "")[:18]
    extra = extra or []
    extra_block = "\n".join(extra)
    tres = f"""[gd_resource type="Resource" script_class="ItemDef" format=3 uid="uid://p14{short}"]

[ext_resource type="Script" path="res://scripts/resources/item_def.gd" id="1_def"]
[ext_resource type="Texture2D" path="res://assets/sprites/items/{icon}.png" id="2_icon"]

[resource]
script = ExtResource("1_def")
icon = ExtResource("2_icon")
id = &"{id}"
display_name = "{display}"
description = "{desc}"
max_stack = {max_stack}
item_type = {item_type}
tier = {tier}
rarity = {rarity}
placeable_layer = &"structures"
"""
    if extra_block:
        tres += extra_block + "\n"
    out_path = OUT / f"{id}.tres"
    out_path.write_text(tres, encoding="utf-8")
    print(f"  wrote {out_path.relative_to(REPO)}")


# ---------------------------------------------------------------------------
# Automation core (sheet 1).
# ---------------------------------------------------------------------------
write_item(
    "conveyor_placeable", "conveyor_belt",
    "Conveyor Belt",
    "Pushes loose items in its facing direction. Placeable; rotates with R.",
    tier=2, rarity=1,
    uid_short="conv01",
)
write_item(
    "drill_placeable", "drill_placeable",
    "Tier-1 Drill",
    "Mines the wall tile in front every 4 Beats. Requires Aphelion-Tap power.",
    tier=2, rarity=1,
    uid_short="drill01",
)
write_item(
    "robotic_arm_placeable", "robotic_arm",
    "Robotic Arm",
    "Picks an item from one tile and places it on another every 2 Beats. Powered.",
    tier=3, rarity=2,
    uid_short="roboarm01",
)
write_item(
    "aphelion_tap_placeable", "aphelion_tap",
    "Aphelion-Tap",
    "Draws Aphelion light through a diadem-gold ring. Supplies 50 watts to its wire group.",
    tier=4, rarity=2,
    extra=['lore_text = "A small theft from a fading sun."', 'lore_ref = "lore/01_cosmology_and_universe.md"'],
    uid_short="aphtap01",
)
write_item(
    "wire_placeable", "wire",
    "Insulated Wire",
    "Carries electric signal between machines. Place several in a line to link them.",
    tier=2, rarity=1,
    max_stack=99,
    uid_short="wire01",
)
write_item(
    "pressure_plate_placeable", "pressure_plate",
    "Pressure Plate",
    "Emits a signal while something stands on it. Triggers doors, traps, and gates.",
    tier=2, rarity=1,
    uid_short="presspl01",
)
write_item(
    "button_placeable", "button",
    "Button / Switch",
    "Interact to pulse a signal. Configurable as a momentary button or toggle switch.",
    tier=2, rarity=1,
    uid_short="button01",
)
write_item(
    "logic_gate_and_placeable", "logic_gate_and",
    "Logic Gate — AND",
    "Outputs high only when both inputs are high. Wire signal up via the input ports.",
    tier=3, rarity=2,
    uid_short="andgate01",
)
write_item(
    "sensor_placeable", "sensor",
    "Sensor Dome",
    "Emits a signal on proximity, mob detection, low health, or open sky exposure.",
    tier=3, rarity=2,
    uid_short="sensor01",
)
write_item(
    "storage_piping_placeable", "storage_piping",
    "Storage Piping",
    "Transfers one item per Beat between two chest-like nodes. Optional filter.",
    tier=3, rarity=1,
    uid_short="pipe01",
)
write_item(
    "auto_sprinkler_placeable", "auto_sprinkler",
    "Auto-Sprinkler",
    "Powered upgrade over the basic sprinkler. Wider radius, every-Beat pulse.",
    tier=3, rarity=2,
    uid_short="autospr01",
)
write_item(
    "auto_harvester_placeable", "auto_harvester",
    "Auto-Harvester",
    "Harvests ready crops within 3 tiles every Beat. Output piped via a Hopper.",
    tier=4, rarity=2,
    uid_short="autohar01",
)
write_item(
    "auto_furnace_placeable", "auto_furnace",
    "Auto-Furnace",
    "Smelts ore into ingots once per Beat. Input + output via storage piping.",
    tier=4, rarity=2,
    uid_short="autofur01",
)
write_item(
    "auto_smelter_placeable", "auto_smelter",
    "Auto-Smelter",
    "Forges ingots into plates once per Beat. Input + output via storage piping.",
    tier=5, rarity=2,
    uid_short="autosml01",
)
write_item(
    "power_storage_cell_placeable", "power_storage_cell",
    "Power Storage Cell",
    "Battery. Stores surplus supply and releases it during shortfalls.",
    tier=4, rarity=2,
    uid_short="pwrbat01",
)
write_item(
    "splitter_placeable", "splitter",
    "Splitter Belt",
    "Round-robins items between two output directions.",
    tier=3, rarity=1,
    uid_short="splitt01",
)

# ---------------------------------------------------------------------------
# Power & logic (sheet 2).
# ---------------------------------------------------------------------------
write_item("logic_gate_or_placeable", "logic_gate_or", "Logic Gate — OR", "Outputs high if any input is high.", tier=3, rarity=2, uid_short="orgate01")
write_item("logic_gate_not_placeable", "logic_gate_not", "Logic Gate — NOT", "Inverts its single input signal.", tier=3, rarity=2, uid_short="notgate01")
write_item("logic_gate_nand_placeable", "logic_gate_nand", "Logic Gate — NAND", "Outputs low only when both inputs are high. Cornerstone of any latch.", tier=3, rarity=2, uid_short="nandgt01")
write_item("logic_gate_xor_placeable", "logic_gate_xor", "Logic Gate — XOR", "Outputs high when exactly one input is high.", tier=3, rarity=2, uid_short="xorgate01")
write_item("timer_block_placeable", "timer_block", "Timer Block", "Pulses its output a configurable number of Beats after its input goes high.", tier=3, rarity=2, uid_short="timer01")
write_item("hopper_placeable", "hopper", "Hopper", "Vacuums up loose items and drops them into a connected chest.", tier=3, rarity=1, uid_short="hopper01")
write_item("item_filter_placeable", "item_filter", "Item Filter", "Sits on a conveyor and lets only whitelisted items pass.", tier=3, rarity=2, uid_short="filter01")
write_item("signal_transmitter_placeable", "signal_transmitter", "Signal Transmitter", "Broadcasts an electric pulse on a chosen frequency. Wireless redstone.", tier=4, rarity=2, uid_short="sigtx01")
write_item("signal_receiver_placeable", "signal_receiver", "Signal Receiver", "Catches a transmitter's pulse on the matching frequency and writes its wire.", tier=4, rarity=2, uid_short="sigrx01")
write_item("mob_farm_block_placeable", "mob_farm_block", "Mob Farm Block", "Defines a 4-tile kill-zone. Mob drops route to this block instead of dropping where they died.", tier=4, rarity=2, uid_short="mobfar01")
write_item("glass_block_placeable", "glass_block", "Mob-Proof Glass", "Solid to mobs and projectiles but lets light and sight pass through.", tier=2, rarity=1, uid_short="glass01")
write_item("fence_gate_placeable", "fence_gate", "Fence Gate", "Opens like a door, blocks like a fence. Stays open 8s after passing through.", tier=2, rarity=1, uid_short="fence01")
write_item("auctioneer_node_placeable", "auctioneer_node", "Auctioneer Node", "List items for sale to other Walkers. Listings persist across sessions.", tier=4, rarity=2, uid_short="auctn01")
write_item("auto_cooking_pot_placeable", "auto_cooking_pot", "Auto Cooking Pot", "Cooks raw inputs into food every 8 Beats. Input + output via storage piping.", tier=4, rarity=2, uid_short="autocp01")
write_item("auto_fishing_rig_placeable", "auto_fishing_rig", "Auto-Fishing Rig", "Pulls a fish from the local biome every 12 Beats. Consumes bait.", tier=4, rarity=2, uid_short="autofh01")
write_item("wireless_relay_placeable", "wireless_relay", "Wireless Relay", "Combined transmit + receive node — bridges signals between distant bases.", tier=5, rarity=3, uid_short="wirele01")

# ---------------------------------------------------------------------------
# Tools / buckets / paint (sheet 3).
# ---------------------------------------------------------------------------
write_item(
    "bucket_empty", "bucket_empty",
    "Empty Bucket",
    "Fill from a water, lava, slime, or acid tile. Hold one liquid at a time.",
    item_type=1, tier=1, rarity=0,
    uid_short="bucke01",
)
write_item("bucket_full_water", "bucket_full_water", "Bucket of Water", "Place water tiles. Mix with lava to harden into obsidian.", item_type=1, tier=1, rarity=0, uid_short="bckwt01")
write_item("bucket_full_lava", "bucket_full_lava", "Bucket of Lava", "Place lava tiles. Burns mobs that step in.", item_type=1, tier=1, rarity=0, uid_short="bcklv01")
write_item("bucket_full_slime", "bucket_full_slime", "Bucket of Slime", "Place slime tiles. Slows enemies. Mix with water for brackish slow-water.", item_type=1, tier=1, rarity=0, uid_short="bcksl01")
write_item("bucket_full_acid", "bucket_full_acid", "Bucket of Acid", "Place acid tiles. Damages over time. Mix with water to dilute.", item_type=1, tier=1, rarity=0, uid_short="bckac01")

write_item("paint_brush", "paint_brush", "Paint Brush", "Recolour any placed wall or floor with the palette wheel. Cosmetic only.", item_type=1, tier=1, rarity=0, uid_short="paint01")
write_item("color_wheel_palette", "color_wheel_palette", "Color Wheel", "Reference palette of 8 dye tones used by the paint brush and banner pigments.", item_type=0, tier=1, rarity=0, uid_short="colwh01")
write_item("pattern_paint_stamp", "pattern_paint_stamp", "Pattern Stamp", "Stamps a 3x3 pattern (checker / stripes / diamond) using two palette colours.", item_type=1, tier=2, rarity=1, uid_short="ptnst01")
write_item("wallpaper_roll", "wallpaper_roll", "Wallpaper Roll", "Lay over any wall tile to swap its appearance. Cosmetic only.", item_type=5, tier=1, rarity=0, uid_short="wallp01")
write_item("demolition_tool", "demolition_tool", "Demolition Mallet", "Smashes nearby structures. Refunds half their resources.", item_type=1, tier=2, rarity=1, uid_short="demmal01")
write_item("blueprint_tool", "blueprint_tool", "Blueprint Tool", "Capture a rectangle of structures and paste it elsewhere. Saves with the world.", item_type=1, tier=3, rarity=2, uid_short="bprnt01")
write_item("place_grid_toggle", "place_grid_toggle", "Place-Grid Toggle", "Right-click to switch between snap-to-tile placement and free placement.", item_type=1, tier=1, rarity=0, uid_short="gridtg01")
write_item("merger_placeable", "merger", "Merger Belt", "Funnels items from two input directions into a single output.", tier=3, rarity=1, uid_short="merger01")
write_item("signal_relay_placeable", "signal_relay", "Signal Relay (mini)", "Repeats a signal across a longer wire run. Cheaper than a logic gate.", tier=2, rarity=1, uid_short="sigrly01")
write_item("mod_compat_token", "mod_compat_token", "Mod Compatibility Token", "Reference disc embedded with the game's semver. Reroll-friendly.", item_type=0, tier=1, rarity=0, uid_short="modct01")
write_item("sample_mod_kit", "sample_mod_kit", "Sample Mod Kit", "Drop this on the ground to spawn an example mod scaffold in user://mods/.", item_type=4, tier=1, rarity=1, uid_short="modkt01")
