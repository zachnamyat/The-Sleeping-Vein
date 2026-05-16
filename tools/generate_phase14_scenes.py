#!/usr/bin/env python3
"""Generate Phase 14 .tscn scene files in bulk.

Most Phase 14 placeables share the same scene structure: root Area2D/Node2D
with a Script, a Sprite2D, and a CollisionShape2D (for interactable Area2Ds).
"""
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "scenes" / "structures"
OUT.mkdir(parents=True, exist_ok=True)


def write_area2d_scene(filename: str, class_name: str, script_path: str, icon_name: str, shape_size: tuple[int, int], uid_short: str) -> None:
    """Area2D root — fits buttons, plates, fence gates, hoppers, etc."""
    sw, sh = shape_size
    tres = f"""[gd_scene load_steps=4 format=3 uid="uid://p14s{uid_short}"]

[ext_resource type="Script" path="{script_path}" id="1_scr"]
[ext_resource type="Texture2D" path="res://assets/sprites/items/{icon_name}.png" id="2_tex"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2({sw}, {sh})

[node name="{class_name}" type="Area2D"]
script = ExtResource("1_scr")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture_filter = 1
texture = ExtResource("2_tex")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_1")
"""
    (OUT / filename).write_text(tres, encoding="utf-8")
    print(f"  wrote {filename}")


def write_node2d_scene(filename: str, class_name: str, script_path: str, icon_name: str, uid_short: str) -> None:
    """Node2D root for non-interactable nodes (wire, aphelion_tap, etc.)."""
    tres = f"""[gd_scene load_steps=3 format=3 uid="uid://p14s{uid_short}"]

[ext_resource type="Script" path="{script_path}" id="1_scr"]
[ext_resource type="Texture2D" path="res://assets/sprites/items/{icon_name}.png" id="2_tex"]

[node name="{class_name}" type="Node2D"]
script = ExtResource("1_scr")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture_filter = 1
texture = ExtResource("2_tex")
"""
    (OUT / filename).write_text(tres, encoding="utf-8")
    print(f"  wrote {filename}")


def write_static_body_scene(filename: str, class_name: str, script_path: str, icon_name: str, shape_size: tuple[int, int], uid_short: str) -> None:
    """StaticBody2D for solid blocks (glass)."""
    sw, sh = shape_size
    tres = f"""[gd_scene load_steps=4 format=3 uid="uid://p14s{uid_short}"]

[ext_resource type="Script" path="{script_path}" id="1_scr"]
[ext_resource type="Texture2D" path="res://assets/sprites/items/{icon_name}.png" id="2_tex"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2({sw}, {sh})

[node name="{class_name}" type="StaticBody2D"]
script = ExtResource("1_scr")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture_filter = 1
texture = ExtResource("2_tex")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_1")
"""
    (OUT / filename).write_text(tres, encoding="utf-8")
    print(f"  wrote {filename}")


def write_fence_gate_scene(filename: str, uid_short: str) -> None:
    """Fence gate needs both an Area2D (interact) and a child StaticBody2D (blocking)."""
    tres = f"""[gd_scene load_steps=4 format=3 uid="uid://p14s{uid_short}"]

[ext_resource type="Script" path="res://scripts/structures/fence_gate.gd" id="1_scr"]
[ext_resource type="Texture2D" path="res://assets/sprites/items/fence_gate.png" id="2_tex"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(16, 12)

[node name="FenceGate" type="Area2D"]
script = ExtResource("1_scr")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture_filter = 1
texture = ExtResource("2_tex")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_1")

[node name="StaticBody2D" type="StaticBody2D" parent="."]

[node name="CollisionShape2D" type="CollisionShape2D" parent="StaticBody2D"]
shape = SubResource("RectangleShape2D_1")
"""
    (OUT / filename).write_text(tres, encoding="utf-8")
    print(f"  wrote {filename}")


# Area2D + interact scenes.
write_area2d_scene("conveyor.tscn", "Conveyor", "res://scripts/structures/conveyor.gd", "conveyor_belt", (16, 16), "conv01")
write_area2d_scene("splitter.tscn", "Splitter", "res://scripts/structures/splitter.gd", "splitter", (16, 16), "splt01")
write_area2d_scene("merger.tscn", "Merger", "res://scripts/structures/merger.gd", "merger", (16, 16), "mrg01")
write_area2d_scene("hopper.tscn", "Hopper", "res://scripts/structures/hopper.gd", "hopper", (16, 16), "hopp01")
write_area2d_scene("pressure_plate.tscn", "PressurePlate", "res://scripts/structures/pressure_plate.gd", "pressure_plate", (14, 6), "prspl01")
write_area2d_scene("button_switch.tscn", "ButtonSwitch", "res://scripts/structures/button_switch.gd", "button", (12, 12), "btn01")
write_area2d_scene("sensor_module.tscn", "SensorModule", "res://scripts/structures/sensor_module.gd", "sensor", (32, 32), "sens01")
write_area2d_scene("liquid_tile.tscn", "LiquidTile", "res://scripts/structures/liquid_tile.gd", "bucket_full_water", (14, 14), "liqtl01")
write_area2d_scene("auctioneer_node.tscn", "AuctioneerNode", "res://scripts/structures/auctioneer_node.gd", "auctioneer_node", (18, 18), "auctn01")
write_area2d_scene("auto_furnace.tscn", "AutoFurnace", "res://scripts/structures/auto_furnace.gd", "auto_furnace", (18, 22), "autofr01")
write_area2d_scene("auto_smelter.tscn", "AutoSmelter", "res://scripts/structures/auto_smelter.gd", "auto_smelter", (18, 22), "autosm01")
write_area2d_scene("auto_cooking_pot.tscn", "AutoCookingPot", "res://scripts/structures/auto_cooking_pot.gd", "auto_cooking_pot", (18, 18), "autocp01")

# Node2D scenes (no interact).
write_node2d_scene("aphelion_tap.tscn", "AphelionTap", "res://scripts/structures/aphelion_tap.gd", "aphelion_tap", "aphtap01")
write_node2d_scene("power_storage_cell.tscn", "PowerStorageCell", "res://scripts/structures/power_storage_cell.gd", "power_storage_cell", "pwrcell01")
write_node2d_scene("wire_segment.tscn", "WireSegment", "res://scripts/structures/wire_segment.gd", "wire", "wire01")
write_node2d_scene("logic_gate.tscn", "LogicGate", "res://scripts/structures/logic_gate.gd", "logic_gate_and", "lgand01")
write_node2d_scene("timer_block.tscn", "TimerBlock", "res://scripts/structures/timer_block.gd", "timer_block", "tmr01")
write_node2d_scene("storage_pipe.tscn", "StoragePipe", "res://scripts/structures/storage_pipe.gd", "storage_piping", "stpipe01")
write_node2d_scene("item_filter.tscn", "ItemFilter", "res://scripts/structures/item_filter.gd", "item_filter", "ifltr01")
write_node2d_scene("auto_sprinkler.tscn", "AutoSprinkler", "res://scripts/structures/auto_sprinkler.gd", "auto_sprinkler", "autospr01")
write_node2d_scene("auto_harvester.tscn", "AutoHarvester", "res://scripts/structures/auto_harvester.gd", "auto_harvester", "autohar01")
write_node2d_scene("auto_fishing_rig.tscn", "AutoFishingRig", "res://scripts/structures/auto_fishing_rig.gd", "auto_fishing_rig", "autofh01")
write_node2d_scene("robotic_arm.tscn", "RoboticArm", "res://scripts/structures/robotic_arm.gd", "robotic_arm", "roboarm01")
write_node2d_scene("signal_transmitter.tscn", "SignalTransmitter", "res://scripts/structures/signal_transmitter.gd", "signal_transmitter", "sigtx01")
write_node2d_scene("signal_receiver.tscn", "SignalReceiver", "res://scripts/structures/signal_receiver.gd", "signal_receiver", "sigrx01")
write_node2d_scene("wireless_relay.tscn", "WirelessRelay", "res://scripts/structures/wireless_relay.gd", "wireless_relay", "wirele01")
write_node2d_scene("mob_farm_block.tscn", "MobFarmBlock", "res://scripts/structures/mob_farm_block.gd", "mob_farm_block", "mobfar01")

# StaticBody2D scenes (solid blocks).
write_static_body_scene("glass_block.tscn", "GlassBlock", "res://scripts/structures/glass_block.gd", "glass_block", (16, 16), "glsbl01")

# Special composite (gate has both an Area2D and StaticBody2D).
write_fence_gate_scene("fence_gate.tscn", "fncgt01")
