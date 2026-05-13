extends Node2D
class_name Bomb

## Phase 2.17 — throwable bomb. Lobs in an arc toward the aim point, ticks down
## a fuse, then explodes: instantiates a 32-px AoE HitboxComponent for one
## frame that strikes every Hurtbox in range. Also queues the underlying tile
## (if any) to take heavy mining damage so bombs can clear weak walls.

const FUSE_SECONDS: float = 1.5
const TRAVEL_SECONDS: float = 0.4
const TRAVEL_ARC_PIXELS: float = 28.0
const EXPLOSION_RADIUS: float = 32.0
const EXPLOSION_DAMAGE: int = 35
const TILE_MINING_DAMAGE: int = 40

@export var base_damage: int = EXPLOSION_DAMAGE
@export var explosion_radius: float = EXPLOSION_RADIUS

var _start_pos: Vector2 = Vector2.ZERO
var _target_pos: Vector2 = Vector2.ZERO
var _travel_t: float = 0.0
var _fuse_t: float = FUSE_SECONDS
var _exploded: bool = false


func toss(from: Vector2, to: Vector2) -> void:
	_start_pos = from
	_target_pos = to
	global_position = from
	_travel_t = 0.0
	_fuse_t = FUSE_SECONDS


func _ready() -> void:
	z_index = 6
	set_process(true)


func _process(delta: float) -> void:
	if _exploded:
		return
	if _travel_t < TRAVEL_SECONDS:
		_travel_t += delta
		var p: float = clampf(_travel_t / TRAVEL_SECONDS, 0.0, 1.0)
		var flat: Vector2 = _start_pos.lerp(_target_pos, p)
		var arc: float = sin(p * PI) * TRAVEL_ARC_PIXELS
		global_position = flat + Vector2(0, -arc)
		queue_redraw()
		return
	# Landed — fuse runs.
	_fuse_t -= delta
	if _fuse_t <= 0.0:
		_explode()
	queue_redraw()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	# Damage every Hurtbox in radius.
	var space := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = explosion_radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = 4  # hurtbox layer
	var hits: Array = space.intersect_shape(params, 16)
	for h in hits:
		var hurtbox := h.get("collider") as HurtboxComponent
		if hurtbox == null:
			continue
		hurtbox.receive_hit(self, base_damage, DamageType.EXPLOSIVE, &"player")
	# Mining damage to any underlying ore/wall tile within ~1 tile of the
	# explosion (so bombs can chunk through soft walls).
	for layer in get_tree().get_nodes_in_group("ore_layer"):
		MiningSystem.swing_on_tile(layer as TileMapLayer, global_position, 99, TILE_MINING_DAMAGE)
	for layer in get_tree().get_nodes_in_group("wall_layer"):
		MiningSystem.swing_on_tile(layer as TileMapLayer, global_position, 99, TILE_MINING_DAMAGE)
	# Feedback: shake + flash + sfx.
	EventBus.camera_shake_requested.emit(4.0, 0.25)
	EventBus.screen_pulse_requested.emit(0.25, 0.15)
	if AudioBus:
		AudioBus.play_sfx(&"bomb_explode")
	# Visible burst — short tween before despawn.
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)


func _draw() -> void:
	if _exploded:
		# Expanding ring after detonation.
		var ring_color := Color(1.0, 0.6, 0.2, 0.7)
		draw_arc(Vector2.ZERO, explosion_radius, 0.0, TAU, 32, ring_color, 2.0, true)
		return
	# Pre-explosion bomb: small dark circle with a tiny flickering fuse spark.
	draw_circle(Vector2(0, -2), 4.0, Color(0.10, 0.08, 0.05, 1))
	var fuse_p: float = clampf(1.0 - _fuse_t / FUSE_SECONDS, 0.0, 1.0)
	var spark_size: float = 1.0 + sin(_fuse_t * 30.0) * 0.5
	var spark_color := Color(1.0, lerp(0.9, 0.3, fuse_p), 0.2, 1)
	draw_circle(Vector2(2, -6), spark_size, spark_color)
