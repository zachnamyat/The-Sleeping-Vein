extends Area2D
class_name AutoCookingPot

## Phase 14.37 — Auto cooking pot. Takes one input every 8 beats, produces the
## matching cooked-food output. Default recipes map raw → cooked from
## CookingSystem.FOOD_BUFFS keys, but `cook_table` can override per-pot.

@export var source_path: NodePath
@export var dest_path: NodePath
@export var cook_table: Dictionary = {
	&"raw_meat": &"dried_meat",
	&"bloat_oat": &"bloat_loaf",
	&"pale_cap": &"pale_cap_stew",
	&"memory_root": &"memory_root_broth",
	&"heart_berry": &"heart_berry_jam",
	&"glow_cap": &"glow_cap_skewer",
}
@export var wire_group: int = 0
@export var demand: float = 3.0

var _cooker_id: int = -1
var _power_node_id: int = -1


func _ready() -> void:
	add_to_group("auto_cooking_pot")
	add_to_group("demolishable")
	collision_layer = 0
	collision_mask = 2
	_power_node_id = Phase14Helpers.register_power_node(&"sink", wire_group, 0.0, demand)
	_cooker_id = Phase14Helpers.register_auto_cooker(&"", source_path, dest_path)
	if AudioBus and AudioBus.has_signal("aphelion_beat"):
		AudioBus.aphelion_beat.connect(_on_beat)


func _on_beat() -> void:
	if not Phase14Helpers.resolve_power_for_group(wire_group):
		return
	var source := get_node_or_null(source_path)
	var dest := get_node_or_null(dest_path)
	if source == null or dest == null:
		return
	if not source.has_method("first_item_id"):
		return
	var input: StringName = source.call("first_item_id")
	if not cook_table.has(input):
		return
	var output: StringName = cook_table[input]
	if source.has_method("try_remove") and source.call("try_remove", input, 1):
		if dest.has_method("try_insert"):
			dest.call("try_insert", output, 1)


func _exit_tree() -> void:
	if Phase14Helpers:
		Phase14Helpers.unregister_power_node(_power_node_id)


func get_refund_meta() -> Dictionary:
	return { "item_id": "auto_cooking_pot_placeable", "count": 1 }
