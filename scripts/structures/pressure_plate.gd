extends Area2D
class_name PressurePlate

## Phase 14.6 / 14.12 — Pressure plate. Emits a wire signal while any body of
## the given mask is standing on it. Use mask `2` for player only; `4` for
## mobs; `6` for both.

@export var output_wire: int = 0
@export var trigger_mask: int = 2

var _on_count: int = 0


func _ready() -> void:
	add_to_group("pressure_plate")
	add_to_group("demolishable")
	collision_layer = 0
	collision_mask = trigger_mask
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(_body: Node) -> void:
	_on_count += 1
	if _on_count == 1:
		Phase14Helpers.set_wire_signal(output_wire, true)


func _on_body_exited(_body: Node) -> void:
	_on_count = max(0, _on_count - 1)
	if _on_count == 0:
		Phase14Helpers.set_wire_signal(output_wire, false)


func get_refund_meta() -> Dictionary:
	return { "item_id": "pressure_plate_placeable", "count": 1 }
