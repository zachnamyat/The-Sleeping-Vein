extends Area2D
class_name Hopper

## Phase 14.18 — Auto-stocker / hopper. Each Beat it grabs any ItemDrops within
## `collect_radius` and transfers them to a neighbour Chest (the one at
## `dest_chest_path`). Optional filter list whitelists item ids.

@export var dest_chest_path: NodePath
@export var filter: Array[StringName] = []
@export var collect_radius: float = 16.0


func _ready() -> void:
	add_to_group("hopper")
	add_to_group("demolishable")
	collision_layer = 0
	collision_mask = 16
	if AudioBus and AudioBus.has_signal("aphelion_beat"):
		AudioBus.aphelion_beat.connect(_on_beat)


func _on_beat() -> void:
	var dest := get_node_or_null(dest_chest_path)
	if dest == null:
		return
	for area in get_overlapping_areas():
		var drop := area as ItemDrop
		if drop == null:
			continue
		if not filter.is_empty() and not filter.has(drop.item_id):
			continue
		if dest.has_method("try_insert"):
			if dest.call("try_insert", drop.item_id, drop.count):
				drop.queue_free()


func get_refund_meta() -> Dictionary:
	return { "item_id": "hopper_placeable", "count": 1 }
