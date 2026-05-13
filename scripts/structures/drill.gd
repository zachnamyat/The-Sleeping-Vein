extends Node2D
class_name Drill

## Phase 14 automation MVP — drills an adjacent ore tile periodically.
## Powered: when wired to an Aphelion-tap, the cooldown is faster. Phase 14 MVP
## ignores power and just operates with a fixed cooldown.

@export var ore_layer_path: NodePath
@export var drill_offset: Vector2i = Vector2i(0, 1)
@export var tier: int = 1
@export var period_seconds: float = 4.0
@export var damage_per_tick: int = 4

var _accum: float = 0.0
var _tile_position: Vector2i = Vector2i.ZERO


func _ready() -> void:
	_tile_position = Vector2i(global_position / 16.0) + drill_offset


func _process(delta: float) -> void:
	_accum += delta
	if _accum < period_seconds:
		return
	_accum = 0.0
	var ore := get_node_or_null(ore_layer_path) as TileMapLayer
	if ore == null:
		return
	var world_pos: Vector2 = Vector2(_tile_position) * 16.0 + Vector2(8, 8)
	MiningSystem.swing_on_tile(ore, world_pos, tier, damage_per_tick)
