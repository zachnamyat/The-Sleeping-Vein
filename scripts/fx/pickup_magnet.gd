extends Node
class_name PickupMagnet

## Ticket 2.37 — Item pickup-magnet curve animation.
## Attaches to an ItemDrop. When the player enters the magnet radius, the
## drop tweens toward the player with an ease-in curve, rather than snapping.

const MAGNET_RADIUS_PX: float = 36.0
const MAGNET_ACCEL: float = 220.0
const MAGNET_MAX_SPEED: float = 320.0

var velocity: Vector2 = Vector2.ZERO
var _drop: Node2D
var _player: Node2D


func _ready() -> void:
	# Attaches to its parent ItemDrop on _ready; pulls a reference and finds
	# the player from the "player" group.
	_drop = get_parent() as Node2D
	set_process(true)


func _process(delta: float) -> void:
	if _drop == null:
		queue_free()
		return
	if _player == null:
		var players: Array = get_tree().get_nodes_in_group("player") if get_tree() else []
		if players.is_empty():
			return
		_player = players[0]
	if _player == null:
		return
	var to_player: Vector2 = _player.global_position - _drop.global_position
	var d: float = to_player.length()
	# Larger radius when the player has the loot-magnet bracelet (PlayerStats).
	var radius: float = MAGNET_RADIUS_PX
	if PlayerStats and PlayerStats.has_method("loot_magnet_radius"):
		radius = max(radius, float(PlayerStats.call("loot_magnet_radius")))
	if d > radius:
		velocity = velocity.lerp(Vector2.ZERO, 0.1)
		_drop.position += velocity * delta
		return
	# Acceleration toward player capped at MAGNET_MAX_SPEED.
	var dir: Vector2 = to_player.normalized()
	velocity = velocity + dir * MAGNET_ACCEL * delta
	if velocity.length() > MAGNET_MAX_SPEED:
		velocity = velocity.normalized() * MAGNET_MAX_SPEED
	_drop.global_position += velocity * delta
