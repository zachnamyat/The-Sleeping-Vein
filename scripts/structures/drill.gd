extends Node2D
class_name Drill

## Phase 14.2 — drills an adjacent ore tile periodically. Tier-gated: the
## drill must be at or above the wall tile's required pickaxe tier to mine it.
## Wired to a power source through Phase14Helpers; when the wire group is
## unpowered the drill idles.

@export var ore_layer_path: NodePath
@export var drill_offset: Vector2i = Vector2i(0, 1)
@export var tier: int = 1
@export var period_seconds: float = 4.0
@export var damage_per_tick: int = 4
@export var wire_group: int = 0
@export var demand: float = 6.0

var _accum: float = 0.0
var _tile_position: Vector2i = Vector2i.ZERO
var _power_node_id: int = -1


func _ready() -> void:
	add_to_group("drill")
	add_to_group("demolishable")
	_tile_position = Vector2i(global_position / 16.0) + drill_offset
	if Phase14Helpers:
		_power_node_id = Phase14Helpers.register_power_node(&"sink", wire_group, 0.0, demand)


func _exit_tree() -> void:
	if Phase14Helpers:
		Phase14Helpers.unregister_power_node(_power_node_id)


func _process(delta: float) -> void:
	_accum += delta
	if _accum < period_seconds:
		return
	_accum = 0.0
	# Power gate. Wire_group 0 means "no wiring required" (always powered).
	if wire_group != 0 and not Phase14Helpers.resolve_power_for_group(wire_group):
		return
	var ore := get_node_or_null(ore_layer_path) as TileMapLayer
	if ore == null:
		return
	var world_pos: Vector2 = Vector2(_tile_position) * 16.0 + Vector2(8, 8)
	MiningSystem.swing_on_tile(ore, world_pos, tier, damage_per_tick)


func get_refund_meta() -> Dictionary:
	return { "item_id": "drill_placeable", "count": 1 }
