extends Node2D
class_name PowerStorageCell

## Phase 14.13 — Battery / energy storage cell. Stores excess supply on a wire
## group, releases it when supply < demand.

@export var wire_group: int = 0
@export var max_capacity: float = 50.0

var _power_node_id: int = -1


func _ready() -> void:
	add_to_group("power_storage_cell")
	add_to_group("battery")
	add_to_group("demolishable")
	_power_node_id = Phase14Helpers.register_power_node(&"battery", wire_group, 0.0, 0.0, max_capacity)


func _exit_tree() -> void:
	if Phase14Helpers:
		Phase14Helpers.unregister_power_node(_power_node_id)


func charge_fraction() -> float:
	return Phase14Helpers.battery_charge_fraction(_power_node_id)


func get_refund_meta() -> Dictionary:
	return { "item_id": "power_storage_cell_placeable", "count": 1 }
