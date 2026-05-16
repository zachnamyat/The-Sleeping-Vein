extends Node2D
class_name WireSegment

## Phase 14.5 / 14.14 — A single placed wire tile. Each wire belongs to one
## `wire_id` (its electrical net). Wires that share an endpoint get linked via
## `link_to_neighbours` at place-time. The visual modulates between dark
## (signal off) and warm-gold (signal on); overload tints it red.

@export var wire_id: int = 0
@export var neighbour_wire_ids: Array[int] = []

@onready var _sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null


func _ready() -> void:
	add_to_group("wire")
	add_to_group("demolishable")
	for nb in neighbour_wire_ids:
		Phase14Helpers.link_wires(wire_id, nb)
	if Phase14Helpers:
		Phase14Helpers.wire_signal_changed.connect(_on_signal_changed)
		Phase14Helpers.wire_overload.connect(_on_overload)
	_apply_visual(Phase14Helpers.read_wire_signal(wire_id), false)


func _on_signal_changed(wire: int, value: bool) -> void:
	if wire == wire_id:
		_apply_visual(value, false)


func _on_overload(wire: int, _draw: float) -> void:
	if wire == wire_id:
		_apply_visual(true, true)


func _apply_visual(active: bool, overloaded: bool) -> void:
	if _sprite == null:
		return
	if overloaded:
		_sprite.modulate = Color(1.0, 0.3, 0.2, 1.0)
	elif active:
		_sprite.modulate = Color(1.0, 0.85, 0.35, 1.0)
	else:
		_sprite.modulate = Color(0.45, 0.45, 0.45, 1.0)


func get_refund_meta() -> Dictionary:
	return { "item_id": "wire_placeable", "count": 1 }
