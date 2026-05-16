extends Area2D
class_name Merger

## Phase 14.16 — Merger conveyor. Funnels ItemDrops from two perpendicular input
## directions into a single forward direction. Mechanically identical to a
## regular conveyor — the geometry difference is visual + the wide hitbox.

@export var direction: Vector2 = Vector2.RIGHT
@export var push_speed: float = 28.0


func _ready() -> void:
	add_to_group("conveyor")
	add_to_group("merger")
	add_to_group("demolishable")
	collision_layer = 0
	collision_mask = 16


func _physics_process(delta: float) -> void:
	for area in get_overlapping_areas():
		var drop := area as ItemDrop
		if drop == null:
			continue
		drop.global_position += direction.normalized() * push_speed * delta


func get_refund_meta() -> Dictionary:
	return { "item_id": "merger_placeable", "count": 1 }
