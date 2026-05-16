extends Area2D
class_name Conveyor

## Phase 14.1 — a conveyor belt that pushes ItemDrops in its direction.
## Items on top get a small velocity nudge each physics frame. Filters via
## Phase14Helpers.conveyor_allows().

@export var direction: Vector2 = Vector2.RIGHT
@export var push_speed: float = 28.0


func _ready() -> void:
	add_to_group("conveyor")
	add_to_group("demolishable")
	collision_layer = 0
	collision_mask = 16  # item_drop layer


func _physics_process(delta: float) -> void:
	var iid: int = get_instance_id()
	for area in get_overlapping_areas():
		var drop := area as ItemDrop
		if drop == null:
			continue
		if Phase14Helpers and not Phase14Helpers.conveyor_allows(iid, drop.item_id):
			continue
		drop.global_position += direction.normalized() * push_speed * delta


func get_refund_meta() -> Dictionary:
	return { "item_id": "conveyor_placeable", "count": 1 }
