extends Node2D
class_name RoboticArm

## Phase 14.3 / 14.39 — Robotic arm. Each Aphelion-Beat it scans `source_radius`
## around `source_offset_pixels` for an ItemDrop, picks it up, and drops it at
## `target_offset_pixels`. Wired to a power source through Phase14Helpers (when
## the wire_group is unpowered the arm stops).

@export var source_offset_pixels: Vector2i = Vector2i(-16, 0)
@export var target_offset_pixels: Vector2i = Vector2i(16, 0)
@export var source_radius: float = 12.0
@export var wire_group: int = 0
@export var demand: float = 5.0

var _power_node_id: int = -1
var _arm_id: int = -1
var _beat_pending: bool = false


func _ready() -> void:
	add_to_group("robotic_arm")
	add_to_group("demolishable")
	_power_node_id = Phase14Helpers.register_power_node(&"sink", wire_group, 0.0, demand)
	_arm_id = Phase14Helpers.register_arm(global_position + Vector2(source_offset_pixels), global_position + Vector2(target_offset_pixels))
	if AudioBus and AudioBus.has_signal("aphelion_beat"):
		AudioBus.aphelion_beat.connect(_on_beat)
	if Phase14Helpers:
		Phase14Helpers.robotic_arm_cycled.connect(_on_helper_cycled)


func _on_beat() -> void:
	## A direct hook so the arm can move items immediately on its scheduled beat.
	_beat_pending = true


func _on_helper_cycled(arm_id: int, _picked: StringName, _count: int) -> void:
	if arm_id != _arm_id or not _beat_pending:
		return
	_beat_pending = false
	# Power gate.
	if not Phase14Helpers.resolve_power_for_group(wire_group):
		return
	_cycle()


func _cycle() -> void:
	var source_pos: Vector2 = global_position + Vector2(source_offset_pixels)
	var target_pos: Vector2 = global_position + Vector2(target_offset_pixels)
	# Find the nearest ItemDrop in the source radius.
	var best: ItemDrop = null
	var best_d: float = source_radius * source_radius
	for n in get_tree().get_nodes_in_group("item_drop"):
		var d := n as ItemDrop
		if d == null:
			continue
		var dist_sq: float = d.global_position.distance_squared_to(source_pos)
		if dist_sq <= best_d:
			best = d
			best_d = dist_sq
	if best == null:
		return
	best.global_position = target_pos
	Phase14Helpers.robotic_arm_cycled.emit(_arm_id, best.item_id, best.count)


func _exit_tree() -> void:
	if Phase14Helpers:
		Phase14Helpers.unregister_arm(_arm_id)
		Phase14Helpers.unregister_power_node(_power_node_id)


func get_refund_meta() -> Dictionary:
	return { "item_id": "robotic_arm_placeable", "count": 1 }
