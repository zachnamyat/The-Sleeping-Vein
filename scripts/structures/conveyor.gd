extends Area2D
class_name Conveyor

## Phase 14 automation MVP — a conveyor belt that pushes ItemDrops in its
## direction. Items on top get a small velocity nudge each physics frame.

@export var direction: Vector2 = Vector2.RIGHT
@export var push_speed: float = 28.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 16  # item_drop layer


func _physics_process(delta: float) -> void:
	for area in get_overlapping_areas():
		var drop := area as ItemDrop
		if drop == null:
			continue
		drop.global_position += direction.normalized() * push_speed * delta
