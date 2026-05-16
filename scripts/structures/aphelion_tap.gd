extends Node2D
class_name AphelionTap

## Phase 14.4 — The Aphelion-Tap power source. Lore: a diadem-gold ring draws
## power directly from Aphelion light. Mechanically it's a power source on a
## wire group. Default supply is 50 watts; the player can wire many sinks to
## a single tap up to that budget.

@export var wire_group: int = 0
@export var supply: float = 50.0

var _power_node_id: int = -1


func _ready() -> void:
	add_to_group("aphelion_tap")
	add_to_group("power_source")
	add_to_group("demolishable")
	_power_node_id = Phase14Helpers.register_power_node(&"source", wire_group, supply, 0.0)


func _exit_tree() -> void:
	if Phase14Helpers:
		Phase14Helpers.unregister_power_node(_power_node_id)


func get_refund_meta() -> Dictionary:
	return { "item_id": "aphelion_tap_placeable", "count": 1 }
