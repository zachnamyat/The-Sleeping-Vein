extends Node2D
class_name AutoHarvester

## Phase 14.9 — Auto-harvester. Each Beat it inspects FarmingSystem for any
## ready-to-harvest TilledSoil within `radius`, harvests them, and drops the
## resulting items at this position so a Hopper can route them.

@export var radius: float = 48.0
@export var wire_group: int = 0
@export var demand: float = 5.0

var _power_node_id: int = -1


func _ready() -> void:
	add_to_group("auto_harvester")
	add_to_group("demolishable")
	_power_node_id = Phase14Helpers.register_power_node(&"sink", wire_group, 0.0, demand)
	if AudioBus and AudioBus.has_signal("aphelion_beat"):
		AudioBus.aphelion_beat.connect(_on_beat)


func _on_beat() -> void:
	if not Phase14Helpers.resolve_power_for_group(wire_group):
		return
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group("tilled_soil"):
		var soil := n as Node2D
		if soil == null:
			continue
		if soil.global_position.distance_to(global_position) > radius:
			continue
		if soil.has_method("is_ready_to_harvest") and soil.call("is_ready_to_harvest"):
			if soil.has_method("auto_harvest_at"):
				soil.call("auto_harvest_at", global_position)
			elif soil.has_method("harvest"):
				soil.call("harvest")


func _exit_tree() -> void:
	if Phase14Helpers:
		Phase14Helpers.unregister_power_node(_power_node_id)


func get_refund_meta() -> Dictionary:
	return { "item_id": "auto_harvester_placeable", "count": 1 }
