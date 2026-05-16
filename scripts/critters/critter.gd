extends Node2D
class_name Critter

## Phase 8.15 — Passive ambient critter. Drifts in random directions; caught
## by the Bug Net. Doesn't affect combat. Auto-despawns if it wanders too far
## from any player.

const SPEED: float = 18.0
const LIFESPAN: float = 60.0
const DESPAWN_RADIUS: float = 320.0

var _dir: Vector2 = Vector2.RIGHT
var _heartbeat: float = 0.0
var _lifespan: float = 0.0


func _ready() -> void:
	add_to_group("critter")
	_dir = Vector2.RIGHT.rotated(randf() * TAU)


func _process(delta: float) -> void:
	_heartbeat += delta
	_lifespan += delta
	# Reorient occasionally for a "fluttering" feel.
	if _heartbeat > 0.6:
		_heartbeat = 0.0
		_dir = _dir.rotated(randf_range(-0.7, 0.7))
	global_position += _dir * SPEED * delta
	if _lifespan >= LIFESPAN:
		queue_free()
		return
	# Despawn if no nearby player.
	var tree := get_tree()
	if tree == null:
		return
	var players := tree.get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0] as Node2D
	if player and global_position.distance_to(player.global_position) > DESPAWN_RADIUS:
		queue_free()
