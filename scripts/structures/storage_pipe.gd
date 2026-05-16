extends Node2D
class_name StoragePipe

## Phase 14.8 — Storage container piping. Connects two storage-like nodes
## (chests, machine input slots) and transfers one item per Beat.

@export var source_node_path: NodePath
@export var dest_node_path: NodePath
@export var filter: Array[StringName] = []

var _pipe_id: int = -1


func _ready() -> void:
	add_to_group("storage_pipe")
	add_to_group("demolishable")
	_pipe_id = Phase14Helpers.register_pipe(source_node_path, dest_node_path, filter)


func _exit_tree() -> void:
	if Phase14Helpers:
		Phase14Helpers.unregister_pipe(_pipe_id)


func get_refund_meta() -> Dictionary:
	return { "item_id": "storage_piping_placeable", "count": 1 }
