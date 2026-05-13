extends CharacterBody2D
class_name PlayerController

## The Echo-Walker. CharacterBody2D with 8-directional movement, sprite-direction tracking,
## an attached HealthComponent + ManaComponent, hurtbox, and a hotbar reference.
##
## Movement is free 8-directional per Core Keeper parity (docs/reference/core-keeper-mechanics.md §1.2).
## Speed scales with the Running skill (+0.1% per level).

const BASE_SPEED: float = 80.0
const RUNNING_BONUS_PER_LEVEL: float = 0.001
const PIXEL_SNAP: bool = true
const SPRITE_VISUAL_SCALE: float = 1.0   ## Walker sprite is now 24x48 native — no upscale needed.

@export var hand_glow_strength: float = 1.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var mana: ManaComponent = $ManaComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox

var facing: Vector2 = Vector2.DOWN
var is_dead: bool = false
var _respawn_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("player")
	# Force visibility: scale up + add a soft golden halo + drop shadow so the
	# tan Walker doesn't blend into warm-earth biomes. Built procedurally so
	# Godot's editor auto-save can't strip them.
	if sprite:
		sprite.scale = Vector2(SPRITE_VISUAL_SCALE, SPRITE_VISUAL_SCALE)
		sprite.offset = Vector2(0, -24)   ## 24x48 walker: feet at row 47, offset half-height up
		sprite.z_index = 5
		_attach_visibility_aura()
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.make_current()
	if hurtbox:
		hurtbox.team = &"player"
		hurtbox.health_component = health
	if health:
		health.died.connect(_on_died)
		var hp_bonus: int = CombatMath.talent_max_hp_bonus()
		var armor_bonus: int = CombatMath.talent_armor_bonus()
		if hp_bonus > 0:
			health.set_max_health(health.max_health + hp_bonus, true)
		if armor_bonus > 0:
			health.armor += armor_bonus
		EventBus.skill_leveled_up.connect(_on_skill_leveled_up)
	EventBus.player_spawned.emit(self)
	_respawn_position = global_position


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return
	var input: Vector2 = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up"),
	)
	if input.length() > 1.0:
		input = input.normalized()
	if input.length() > 0.01:
		facing = input.normalized()
		_update_sprite_facing()
	var speed_mult: float = CombatMath.player_speed_multiplier()
	velocity = input * BASE_SPEED * speed_mult
	move_and_slide()
	if PIXEL_SNAP:
		global_position = global_position.round()


func _update_sprite_facing() -> void:
	if sprite == null:
		return
	if abs(facing.x) > abs(facing.y):
		sprite.flip_h = facing.x < 0.0
	else:
		sprite.flip_h = false


func set_respawn_position(pos: Vector2) -> void:
	_respawn_position = pos


func _on_died(killer: Node) -> void:
	is_dead = true
	EventBus.player_died.emit(self)
	GameState.consume_sliver()
	var timer := get_tree().create_timer(1.5)
	timer.timeout.connect(_respawn)


func _respawn() -> void:
	if not is_dead:
		return
	global_position = _respawn_position
	health.revive(1.0)
	is_dead = false
	EventBus.player_respawned.emit(self, GameState.aphelion_slivers_remaining)


func _on_skill_leveled_up(skill_id: StringName, _new_level: int) -> void:
	if skill_id == &"skill_vitality" and health:
		health.set_max_health(health.max_health + 5, true)


func _attach_visibility_aura() -> void:
	# Adjusted for 24x48 walker — shadow at feet, halo slightly lower than chest.
	var shadow := PlayerShadow.new()
	shadow.position = Vector2(0, -1)
	shadow.z_index = -1
	add_child(shadow)
	var halo := PlayerHalo.new()
	halo.position = Vector2(0, -18)
	halo.z_index = -1
	add_child(halo)


class PlayerShadow extends Node2D:
	func _draw() -> void:
		# Wider oval to match the 24-wide walker.
		draw_colored_polygon(_oval_points(9.0, 3.0, 24), Color(0, 0, 0, 0.5))

	func _oval_points(rx: float, ry: float, segments: int) -> PackedVector2Array:
		var pts: PackedVector2Array = []
		for i in range(segments):
			var a: float = float(i) / float(segments) * TAU
			pts.append(Vector2(cos(a) * rx, sin(a) * ry))
		return pts


class PlayerHalo extends Node2D:
	# Tight gold rim glow at the Walker's hand position, not a full-body aura.
	# The walker sprite now has binary alpha + visible detail (face, hand-glow),
	# so the halo's only job is a small flicker around the hand-of-light.
	var _t: float = 0.0
	func _ready() -> void:
		set_process(true)
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		var pulse: float = 0.85 + 0.15 * sin(_t * 2.5)
		var hand: Vector2 = Vector2(-3, 4)
		draw_circle(hand, 4.0 * pulse, Color(1.0, 0.85, 0.45, 0.18))
		draw_circle(hand, 2.5 * pulse, Color(1.0, 0.98, 0.7, 0.30))
