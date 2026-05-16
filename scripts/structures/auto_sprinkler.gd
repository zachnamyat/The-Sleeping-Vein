extends Node2D
class_name AutoSprinkler

## Phase 14.9 — Powered upgrade over the basic Sprinkler. Pulses every Beat
## (vs every 2 beats) and has a wider radius. Requires power.

@export var radius: float = 48.0
@export var wire_group: int = 0
@export var demand: float = 4.0

var _power_node_id: int = -1


func _ready() -> void:
	add_to_group("auto_sprinkler")
	add_to_group("sprinkler")
	add_to_group("demolishable")
	_power_node_id = Phase14Helpers.register_power_node(&"sink", wire_group, 0.0, demand)
	if AudioBus and AudioBus.has_signal("aphelion_beat"):
		AudioBus.aphelion_beat.connect(_on_beat)


func _on_beat() -> void:
	if not Phase14Helpers.resolve_power_for_group(wire_group):
		return
	if FarmingSystem:
		FarmingSystem.sprinkler_pulse(global_position, radius)
	if AudioBus:
		AudioBus.play_sfx(&"sprinkler", global_position)


func _exit_tree() -> void:
	if Phase14Helpers:
		Phase14Helpers.unregister_power_node(_power_node_id)


func get_refund_meta() -> Dictionary:
	return { "item_id": "auto_sprinkler_placeable", "count": 1 }
