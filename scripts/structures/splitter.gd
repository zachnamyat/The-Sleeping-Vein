extends Area2D
class_name Splitter

## Phase 14.16 — Splitter conveyor. Round-robins ItemDrops between two output
## directions. Inputs come from the back (opposite of the splitter's `direction`).

@export var direction: Vector2 = Vector2.RIGHT
@export var output_count: int = 2
@export var push_speed: float = 28.0

var _instance_id: int = 0


func _ready() -> void:
	add_to_group("conveyor")
	add_to_group("splitter")
	add_to_group("demolishable")
	collision_layer = 0
	collision_mask = 16
	_instance_id = get_instance_id()


func _physics_process(delta: float) -> void:
	for area in get_overlapping_areas():
		var drop := area as ItemDrop
		if drop == null:
			continue
		if not Phase14Helpers.conveyor_allows(_instance_id, drop.item_id):
			continue
		var output_dir: Vector2 = _pick_output_direction()
		drop.global_position += output_dir * push_speed * delta


func _pick_output_direction() -> Vector2:
	var idx: int = Phase14Helpers.splitter_next_output(_instance_id, max(1, output_count))
	# For a 2-output splitter, branch left/right of the main direction.
	if output_count == 2:
		if idx == 0:
			return direction.rotated(deg_to_rad(45.0)).normalized()
		else:
			return direction.rotated(deg_to_rad(-45.0)).normalized()
	# Fall back to evenly-spaced rotations around the forward axis.
	var spread_deg: float = 90.0 / float(max(1, output_count - 1))
	var angle: float = (idx - (output_count - 1) / 2.0) * spread_deg
	return direction.rotated(deg_to_rad(angle)).normalized()


func get_refund_meta() -> Dictionary:
	return { "item_id": "splitter_placeable", "count": 1 }
