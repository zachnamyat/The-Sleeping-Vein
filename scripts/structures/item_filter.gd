extends Node2D
class_name ItemFilter

## Phase 14.11 — Sits between two conveyors, allows only items in `filter` to
## pass. Implemented as a wrapper around the upstream conveyor's instance id.

@export var target_conveyor_path: NodePath
@export var filter: Array[StringName] = []


func _ready() -> void:
	add_to_group("item_filter")
	add_to_group("demolishable")
	var conv := get_node_or_null(target_conveyor_path)
	if conv and Phase14Helpers:
		Phase14Helpers.set_conveyor_filter(conv.get_instance_id(), filter)


func get_refund_meta() -> Dictionary:
	return { "item_id": "item_filter_placeable", "count": 1 }
