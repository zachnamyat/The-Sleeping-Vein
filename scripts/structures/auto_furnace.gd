extends Area2D
class_name AutoFurnace

## Phase 14.10 — Auto-furnace. Pulls one smelt-eligible item from `source_path`
## per Beat, runs the matching recipe, drops the output into `dest_path`.
## Smelting table is hardcoded for the few ore→ingot conversions; mods can
## extend by adding recipes whose station is "auto_furnace".

const SMELT_TABLE: Dictionary = {
	&"shaleseed": &"shaleseed_ingot",
	&"clearstone": &"clearstone_ingot",
	&"ember_iron_ore": &"ember_iron_ingot",
	&"saltbound_steel_ore": &"saltbound_steel_ingot",
	&"auroric_ice_ore": &"auroric_ice_ingot",
	&"diadem_gold_ore": &"diadem_gold_ingot",
}

@export var source_path: NodePath
@export var dest_path: NodePath
@export var wire_group: int = 0
@export var demand: float = 6.0

var _power_node_id: int = -1


func _ready() -> void:
	add_to_group("auto_furnace")
	add_to_group("demolishable")
	collision_layer = 0
	collision_mask = 2
	_power_node_id = Phase14Helpers.register_power_node(&"sink", wire_group, 0.0, demand)
	if AudioBus and AudioBus.has_signal("aphelion_beat"):
		AudioBus.aphelion_beat.connect(_on_beat)


func _on_beat() -> void:
	if not Phase14Helpers.resolve_power_for_group(wire_group):
		return
	var source := get_node_or_null(source_path)
	var dest := get_node_or_null(dest_path)
	if source == null or dest == null:
		return
	if not source.has_method("first_item_id"):
		return
	var input: StringName = source.call("first_item_id")
	if not SMELT_TABLE.has(input):
		return
	var output: StringName = SMELT_TABLE[input]
	if source.has_method("try_remove"):
		if source.call("try_remove", input, 1):
			if dest.has_method("try_insert"):
				dest.call("try_insert", output, 1)


func _exit_tree() -> void:
	if Phase14Helpers:
		Phase14Helpers.unregister_power_node(_power_node_id)


func get_refund_meta() -> Dictionary:
	return { "item_id": "auto_furnace_placeable", "count": 1 }
