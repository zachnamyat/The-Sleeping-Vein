#!/usr/bin/env python3
"""Generate Phase 14 recipe .tres files in bulk."""
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "resources" / "recipes"
OUT.mkdir(parents=True, exist_ok=True)


def write_recipe(
    id: str,
    display: str,
    inputs: list[tuple[str, int]],
    outputs: list[tuple[str, int]],
    stations: list[str],
    skill_xp: int = 6,
    uid_short: str | None = None,
) -> None:
    """Emit a Recipe .tres file."""
    short = uid_short or id.replace("craft_", "").replace("_", "")[:18]
    inputs_str = ", ".join(f'{{ "item_id": "{i}", "count": {c} }}' for i, c in inputs)
    outputs_str = ", ".join(f'{{ "item_id": "{i}", "count": {c} }}' for i, c in outputs)
    stations_str = ", ".join(f'&"{s}"' for s in stations)
    tres = f"""[gd_resource type="Resource" script_class="Recipe" format=3 uid="uid://r14{short}"]

[ext_resource type="Script" path="res://scripts/resources/recipe.gd" id="1_rec"]

[resource]
script = ExtResource("1_rec")
id = &"{id}"
display_name = "{display}"
inputs = [{inputs_str}]
outputs = [{outputs_str}]
stations = [{stations_str}]
skill_xp_grant = {skill_xp}
skill_xp_id = &"skill_crafting"
"""
    out_path = OUT / f"{id}.tres"
    out_path.write_text(tres, encoding="utf-8")
    print(f"  wrote {out_path.relative_to(REPO)}")


# Tier-1 (loam_bench) — buckets + the cheapest tools.
write_recipe(
    "craft_bucket_empty", "Empty Bucket",
    [("wood", 3), ("shaleseed_ingot", 1)],
    [("bucket_empty", 1)],
    ["loam_bench"], skill_xp=2, uid_short="bcktemp",
)
write_recipe(
    "craft_paint_brush", "Paint Brush",
    [("wood", 2), ("aphelion_fragment", 1)],
    [("paint_brush", 1)],
    ["loam_bench"], skill_xp=2, uid_short="paintbr",
)
write_recipe(
    "craft_wallpaper_roll", "Wallpaper Roll",
    [("wood", 1), ("loam_wax", 1)],
    [("wallpaper_roll", 4)],
    ["loam_bench"], skill_xp=2, uid_short="wallrol",
)
write_recipe(
    "craft_demolition_tool", "Demolition Mallet",
    [("wood", 4), ("shaleseed_ingot", 3)],
    [("demolition_tool", 1)],
    ["loam_bench"], skill_xp=3, uid_short="demoml",
)
write_recipe(
    "craft_place_grid_toggle", "Place-Grid Toggle",
    [("shaleseed_ingot", 1)],
    [("place_grid_toggle", 1)],
    ["loam_bench"], skill_xp=1, uid_short="grdtgl",
)
write_recipe(
    "craft_glass_block", "Mob-Proof Glass",
    [("clearstone", 2)],
    [("glass_block_placeable", 1)],
    ["loam_bench"], skill_xp=2, uid_short="glsbl1",
)
write_recipe(
    "craft_fence_gate", "Fence Gate",
    [("wood", 3), ("shaleseed_ingot", 1)],
    [("fence_gate_placeable", 1)],
    ["loam_bench"], skill_xp=2, uid_short="fncgt1",
)

# Tier-2 (clearstone_forge) — wires + basic automation.
write_recipe(
    "craft_wire", "Insulated Wire",
    [("clearstone_ingot", 1), ("loam_wax", 1)],
    [("wire_placeable", 4)],
    ["clearstone_forge"], skill_xp=2, uid_short="wir01",
)
write_recipe(
    "craft_pressure_plate", "Pressure Plate",
    [("clearstone_ingot", 2)],
    [("pressure_plate_placeable", 1)],
    ["clearstone_forge"], skill_xp=2, uid_short="prspl1",
)
write_recipe(
    "craft_button", "Button",
    [("clearstone_ingot", 1), ("loam_wax", 1)],
    [("button_placeable", 1)],
    ["clearstone_forge"], skill_xp=2, uid_short="btn1",
)
write_recipe(
    "craft_conveyor", "Conveyor Belt",
    [("clearstone_ingot", 2), ("shaleseed_ingot", 1)],
    [("conveyor_placeable", 4)],
    ["clearstone_forge"], skill_xp=3, uid_short="conv1",
)
write_recipe(
    "craft_splitter", "Splitter Belt",
    [("clearstone_ingot", 3), ("wire_placeable", 2)],
    [("splitter_placeable", 1)],
    ["clearstone_forge"], skill_xp=3, uid_short="splt1",
)
write_recipe(
    "craft_merger", "Merger Belt",
    [("clearstone_ingot", 3), ("wire_placeable", 2)],
    [("merger_placeable", 1)],
    ["clearstone_forge"], skill_xp=3, uid_short="mrg1",
)
write_recipe(
    "craft_hopper", "Hopper",
    [("clearstone_ingot", 4), ("wood", 2)],
    [("hopper_placeable", 1)],
    ["clearstone_forge"], skill_xp=3, uid_short="hopp1",
)
write_recipe(
    "craft_item_filter", "Item Filter",
    [("clearstone_ingot", 2), ("wire_placeable", 2)],
    [("item_filter_placeable", 1)],
    ["clearstone_forge"], skill_xp=3, uid_short="ifltr1",
)
write_recipe(
    "craft_signal_relay", "Signal Relay",
    [("clearstone_ingot", 1), ("wire_placeable", 2)],
    [("signal_relay_placeable", 2)],
    ["clearstone_forge"], skill_xp=2, uid_short="sigrl1",
)
write_recipe(
    "craft_pattern_paint_stamp", "Pattern Paint Stamp",
    [("clearstone_ingot", 1), ("wood", 2)],
    [("pattern_paint_stamp", 1)],
    ["clearstone_forge"], skill_xp=2, uid_short="ptnst1",
)

# Tier-3 (furnace / anvil) — sensors + logic gates + storage piping.
write_recipe(
    "craft_storage_piping", "Storage Piping",
    [("clearstone_ingot", 3), ("shaleseed_ingot", 1)],
    [("storage_piping_placeable", 4)],
    ["furnace"], skill_xp=4, uid_short="stpipe1",
)
write_recipe(
    "craft_sensor", "Sensor Dome",
    [("clearstone_ingot", 2), ("aphelion_fragment", 1), ("wire_placeable", 2)],
    [("sensor_placeable", 1)],
    ["furnace"], skill_xp=5, uid_short="sens1",
)
write_recipe(
    "craft_logic_gate_and", "Logic Gate — AND",
    [("clearstone_ingot", 2), ("wire_placeable", 3)],
    [("logic_gate_and_placeable", 1)],
    ["furnace"], skill_xp=4, uid_short="andg1",
)
write_recipe(
    "craft_logic_gate_or", "Logic Gate — OR",
    [("clearstone_ingot", 2), ("wire_placeable", 3)],
    [("logic_gate_or_placeable", 1)],
    ["furnace"], skill_xp=4, uid_short="orgg1",
)
write_recipe(
    "craft_logic_gate_not", "Logic Gate — NOT",
    [("clearstone_ingot", 1), ("wire_placeable", 2)],
    [("logic_gate_not_placeable", 1)],
    ["furnace"], skill_xp=4, uid_short="notg1",
)
write_recipe(
    "craft_logic_gate_nand", "Logic Gate — NAND",
    [("clearstone_ingot", 2), ("wire_placeable", 3)],
    [("logic_gate_nand_placeable", 1)],
    ["furnace"], skill_xp=4, uid_short="nandg1",
)
write_recipe(
    "craft_logic_gate_xor", "Logic Gate — XOR",
    [("clearstone_ingot", 2), ("wire_placeable", 3)],
    [("logic_gate_xor_placeable", 1)],
    ["furnace"], skill_xp=4, uid_short="xorg1",
)
write_recipe(
    "craft_timer_block", "Timer Block",
    [("clearstone_ingot", 3), ("wire_placeable", 2)],
    [("timer_block_placeable", 1)],
    ["furnace"], skill_xp=4, uid_short="tmrbk1",
)
write_recipe(
    "craft_drill", "Tier-1 Drill",
    [("clearstone_ingot", 4), ("shaleseed_ingot", 2), ("wire_placeable", 2)],
    [("drill_placeable", 1)],
    ["furnace"], skill_xp=6, uid_short="drll1",
)

# Tier-4 (anvil) — power source + battery + robotic arm + wireless + auto* trees.
write_recipe(
    "craft_aphelion_tap", "Aphelion-Tap",
    [("aphelion_shard", 1), ("diadem_gold_ingot", 2), ("clearstone_ingot", 4)],
    [("aphelion_tap_placeable", 1)],
    ["anvil"], skill_xp=10, uid_short="aphtap1",
)
write_recipe(
    "craft_power_storage_cell", "Power Storage Cell",
    [("aphelion_fragment", 4), ("clearstone_ingot", 4), ("wire_placeable", 4)],
    [("power_storage_cell_placeable", 1)],
    ["anvil"], skill_xp=8, uid_short="pwrcell",
)
write_recipe(
    "craft_robotic_arm", "Robotic Arm",
    [("clearstone_ingot", 6), ("aphelion_fragment", 2), ("wire_placeable", 4)],
    [("robotic_arm_placeable", 1)],
    ["anvil"], skill_xp=8, uid_short="roboarm",
)
write_recipe(
    "craft_signal_transmitter", "Signal Transmitter",
    [("aphelion_fragment", 2), ("clearstone_ingot", 3), ("wire_placeable", 2)],
    [("signal_transmitter_placeable", 1)],
    ["anvil"], skill_xp=8, uid_short="sigtx1",
)
write_recipe(
    "craft_signal_receiver", "Signal Receiver",
    [("aphelion_fragment", 2), ("clearstone_ingot", 3), ("wire_placeable", 2)],
    [("signal_receiver_placeable", 1)],
    ["anvil"], skill_xp=8, uid_short="sigrx1",
)
write_recipe(
    "craft_auto_sprinkler", "Auto-Sprinkler",
    [("sprinkler_placeable", 1), ("clearstone_ingot", 2), ("wire_placeable", 2)],
    [("auto_sprinkler_placeable", 1)],
    ["anvil"], skill_xp=7, uid_short="autosp1",
)
write_recipe(
    "craft_auto_harvester", "Auto-Harvester",
    [("clearstone_ingot", 5), ("aphelion_fragment", 2), ("wire_placeable", 3)],
    [("auto_harvester_placeable", 1)],
    ["anvil"], skill_xp=9, uid_short="autohr1",
)
write_recipe(
    "craft_auto_furnace", "Auto-Furnace",
    [("furnace_placeable", 1), ("clearstone_ingot", 3), ("wire_placeable", 2)],
    [("auto_furnace_placeable", 1)],
    ["anvil"], skill_xp=10, uid_short="autofr1",
)
write_recipe(
    "craft_auto_smelter", "Auto-Smelter",
    [("auto_furnace_placeable", 1), ("ember_iron_ingot", 4), ("wire_placeable", 4)],
    [("auto_smelter_placeable", 1)],
    ["anvil"], skill_xp=12, uid_short="autosm1",
)
write_recipe(
    "craft_auto_cooking_pot", "Auto Cooking Pot",
    [("cooking_pot_placeable", 1), ("clearstone_ingot", 3), ("wire_placeable", 2)],
    [("auto_cooking_pot_placeable", 1)],
    ["anvil"], skill_xp=8, uid_short="autocp1",
)
write_recipe(
    "craft_auto_fishing_rig", "Auto-Fishing Rig",
    [("fishing_rod_wood", 1), ("clearstone_ingot", 3), ("wire_placeable", 2)],
    [("auto_fishing_rig_placeable", 1)],
    ["anvil"], skill_xp=8, uid_short="autofh1",
)
write_recipe(
    "craft_mob_farm_block", "Mob Farm Block",
    [("clearstone_ingot", 4), ("aphelion_fragment", 2)],
    [("mob_farm_block_placeable", 1)],
    ["anvil"], skill_xp=7, uid_short="mobfm1",
)
write_recipe(
    "craft_auctioneer_node", "Auctioneer Node",
    [("wood", 8), ("ancient_coin", 5), ("aphelion_fragment", 1)],
    [("auctioneer_node_placeable", 1)],
    ["anvil"], skill_xp=8, uid_short="auctn1",
)
write_recipe(
    "craft_blueprint_tool", "Blueprint Tool",
    [("aphelion_fragment", 2), ("clearstone_ingot", 2), ("wood", 4)],
    [("blueprint_tool", 1)],
    ["anvil"], skill_xp=8, uid_short="bprnt1",
)

# Tier-5 (auroric_anvil) — wireless relay.
write_recipe(
    "craft_wireless_relay", "Wireless Relay",
    [("signal_transmitter_placeable", 1), ("signal_receiver_placeable", 1), ("aurora_shard", 2)],
    [("wireless_relay_placeable", 1)],
    ["auroric_anvil"], skill_xp=14, uid_short="wirele1",
)
