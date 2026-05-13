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
const SPRITE_VISUAL_SCALE: float = 0.5   ## Walker source is 24x48 — half-size puts the character at ~12x24, sane vs 16px tiles.

@export var hand_glow_strength: float = 1.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var mana: ManaComponent = $ManaComponent
@onready var stamina: StaminaComponent = $StaminaComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox

const SPRINT_MULT: float = 1.5

var facing: Vector2 = Vector2.DOWN
var is_dead: bool = false
var is_sitting: bool = false
var is_sleeping: bool = false
var is_eating: bool = false
var _respawn_position: Vector2 = Vector2.ZERO

# Camera shake state
var _shake_remaining: float = 0.0
var _shake_total: float = 0.0
var _shake_intensity: float = 0.0
var _camera: Camera2D

# Footstep audio state
const FOOTSTEP_INTERVAL: float = 0.32
var _footstep_accum: float = 0.0


func _ready() -> void:
	add_to_group("player")
	# Ticket 1.30 — aim cursor while a player exists (in-game). Title screen
	# clears it back to ARROW on scene change.
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	# Force visibility: scale up + add a soft golden halo + drop shadow so the
	# tan Walker doesn't blend into warm-earth biomes. Built procedurally so
	# Godot's editor auto-save can't strip them.
	if sprite:
		sprite.scale = Vector2(SPRITE_VISUAL_SCALE, SPRITE_VISUAL_SCALE)
		sprite.offset = Vector2(0, -24)   ## 24x48 walker: feet at row 47, offset half-height up
		# Y-sort relies on the entity's transform.y against tile bottom edges; an
		# explicit z_index would defeat the WallCap occlusion behind the player.
		sprite.z_index = 0
		_attach_visibility_aura()
	_camera = get_node_or_null("Camera2D") as Camera2D
	if _camera:
		_camera.make_current()
	EventBus.camera_shake_requested.connect(_on_camera_shake_requested)
	if hurtbox:
		hurtbox.team = &"player"
		hurtbox.health_component = health
	if health:
		health.died.connect(_on_died)
		health.damaged.connect(_on_damaged)
		var hp_bonus: int = CombatMath.talent_max_hp_bonus()
		var armor_bonus: int = CombatMath.talent_armor_bonus()
		if hp_bonus > 0:
			health.set_max_health(health.max_health + hp_bonus, true)
		if armor_bonus > 0:
			health.armor += armor_bonus
		EventBus.skill_leveled_up.connect(_on_skill_leveled_up)
	EventBus.player_spawned.emit(self)
	_respawn_position = global_position
	_start_idle_breath()


func _start_idle_breath() -> void:
	# Ticket 1.41 — subtle alpha bob while idle. Placeholder until a real
	# blink/breath sprite sheet lands.
	if sprite == null:
		return
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "modulate:a", 0.9, 1.6)
	tween.tween_property(sprite, "modulate:a", 1.0, 1.6)


func try_sit() -> void:
	# Ticket 1.34. Toggle a sitting state; freezes input and tints the sprite
	# until released. Real sit-pose sprite frames replace the tint later.
	is_sitting = not is_sitting
	if sprite:
		sprite.modulate = Color(0.85, 0.85, 0.95) if is_sitting else Color.WHITE


func try_sleep_in_bed() -> void:
	# Ticket 1.35 — fade-to-black on bed interaction; advances Aphelion phases.
	is_sleeping = true
	EventBus.letterbox_requested.emit(true, 0.6)
	var t := get_tree().create_timer(1.5, true, false, false)
	t.timeout.connect(_wake_from_bed)


func _wake_from_bed() -> void:
	is_sleeping = false
	EventBus.letterbox_requested.emit(false, 0.6)


func play_eat_animation() -> void:
	# Ticket 1.36 — placeholder scale-bounce on consumable use.
	if sprite == null or is_eating:
		return
	is_eating = true
	var t := create_tween()
	t.tween_property(sprite, "scale", Vector2(1.08, 0.96), 0.08)
	t.tween_property(sprite, "scale", Vector2(0.96, 1.04), 0.08)
	t.tween_property(sprite, "scale", Vector2(SPRITE_VISUAL_SCALE, SPRITE_VISUAL_SCALE), 0.08)
	t.finished.connect(func() -> void: is_eating = false)


func _physics_process(delta: float) -> void:
	if is_dead or is_sitting or is_sleeping:
		velocity = Vector2.ZERO
		return
	_unstick_if_overlapping_wall()
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
	var sprinting: bool = Input.is_action_pressed("sprint") and input.length() > 0.01
	if sprinting and stamina and stamina.drain_continuous(stamina.sprint_drain_per_second, delta):
		speed_mult *= SPRINT_MULT
	velocity = input * BASE_SPEED * speed_mult
	move_and_slide()
	if PIXEL_SNAP:
		global_position = global_position.round()
	_tick_footsteps(delta, input.length() > 0.01)
	_tick_camera_shake(delta)


func _tick_footsteps(delta: float, moving: bool) -> void:
	if not moving:
		_footstep_accum = 0.0
		return
	_footstep_accum += delta
	if _footstep_accum >= FOOTSTEP_INTERVAL:
		_footstep_accum = 0.0
		if AudioBus:
			AudioBus.play_sfx(&"footstep")


func _unstick_if_overlapping_wall() -> void:
	# Recovery: chunk generation can paint a wall tile on top of the player's
	# position. CharacterBody2D doesn't auto-resolve penetration, so we detect
	# overlap with the body shape and shove outward to the nearest clear spot.
	var col_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col_shape == null or col_shape.shape == null:
		return
	var space := get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = col_shape.shape
	params.transform = Transform2D(0.0, global_position + col_shape.position)
	params.collision_mask = collision_mask
	if space.intersect_shape(params, 1).is_empty():
		return
	# Stuck. Spiral outward in 8 directions until we find a clear placement.
	var escape_dirs: Array[Vector2] = [
		Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
		(Vector2.UP + Vector2.LEFT).normalized(),
		(Vector2.UP + Vector2.RIGHT).normalized(),
		(Vector2.DOWN + Vector2.LEFT).normalized(),
		(Vector2.DOWN + Vector2.RIGHT).normalized(),
	]
	for distance in range(4, 48, 2):
		for d in escape_dirs:
			var candidate: Vector2 = global_position + d * float(distance)
			params.transform = Transform2D(0.0, candidate + col_shape.position)
			if space.intersect_shape(params, 1).is_empty():
				global_position = candidate
				return


func _tick_camera_shake(delta: float) -> void:
	if _shake_remaining <= 0.0 or _camera == null:
		return
	_shake_remaining -= delta
	if _shake_remaining <= 0.0:
		_camera.offset = Vector2.ZERO
		return
	var falloff: float = _shake_remaining / max(_shake_total, 0.001)
	_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_intensity * falloff


func _on_camera_shake_requested(intensity: float, duration: float) -> void:
	# Bigger shake wins; longer remaining duration wins. Stacks rather than replaces.
	if intensity > _shake_intensity:
		_shake_intensity = intensity
	if duration > _shake_remaining:
		_shake_remaining = duration
		_shake_total = duration


func _update_sprite_facing() -> void:
	if sprite == null:
		return
	if abs(facing.x) > abs(facing.y):
		sprite.flip_h = facing.x < 0.0
	else:
		sprite.flip_h = false


func set_respawn_position(pos: Vector2) -> void:
	_respawn_position = pos


func _on_damaged(amount: int, _source: Node, _type: StringName) -> void:
	# Hurt-flash: pulse the sprite to red for the i-frame duration so the player
	# sees they took damage. Aligns visually with HurtboxComponent.i_frames_seconds.
	if sprite == null or amount <= 0 or is_dead:
		return
	var flicker_count: int = 3
	var step: float = 0.07
	var tween := create_tween()
	for _i in range(flicker_count):
		tween.tween_property(sprite, "modulate", Color(1.4, 0.55, 0.55, 1.0), step)
		tween.tween_property(sprite, "modulate", Color.WHITE, step)


func _on_died(killer: Node) -> void:
	is_dead = true
	EventBus.player_died.emit(self)
	GameState.consume_sliver()
	# Ticket 2.16 — drop a stash corpse the player can walk back to. The
	# starter tools stay in inventory; everything else moves to the corpse.
	_drop_stash_corpse()
	var timer := get_tree().create_timer(1.5)
	timer.timeout.connect(_respawn)


const _STARTER_KEEP_IDS: Array[StringName] = [
	&"wooden_pickaxe", &"wooden_sword", &"wooden_axe", &"torch",
]


func _drop_stash_corpse() -> void:
	var stash: Array = []
	for i in range(Inventory.slots.size()):
		var s = Inventory.slots[i]
		if s == null:
			continue
		var item_id := StringName(s.get("item_id", ""))
		var count: int = int(s.get("count", 0))
		if item_id == &"" or count <= 0:
			continue
		if item_id in _STARTER_KEEP_IDS:
			continue
		stash.append({"item_id": String(item_id), "count": count})
		Inventory.try_remove(item_id, count)
	if stash.is_empty():
		return
	var corpse := DeathCorpse.new()
	corpse.stashed_slots = stash
	corpse.global_position = global_position
	var entities := _entity_layer_parent()
	if entities:
		entities.add_child(corpse)


func _entity_layer_parent() -> Node:
	# Walk up to Main and read its `entity_layer_path` if available. Falls back
	# to current_scene root.
	var n: Node = self
	while n:
		if n.has_method("get") and n.get("entity_layer_path") is NodePath:
			var ep: NodePath = n.get("entity_layer_path")
			var resolved := n.get_node_or_null(ep)
			if resolved:
				return resolved
		n = n.get_parent()
	return get_tree().current_scene


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
	# Tight rim glow at the Walker's hand position. Colour is the user-configured
	# accent (ticket 1.47), defaulting to gold; tuneable from Settings panel.
	var _t: float = 0.0
	func _ready() -> void:
		set_process(true)
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		var pulse: float = 0.85 + 0.15 * sin(_t * 2.5)
		var hand: Vector2 = Vector2(-3, 4)
		var accent: Color = _accent_color()
		var rim: Color = Color(accent.r, accent.g, accent.b, 0.18)
		var core: Color = Color(lerp(accent.r, 1.0, 0.4), lerp(accent.g, 1.0, 0.4), lerp(accent.b, 1.0, 0.4), 0.30)
		draw_circle(hand, 4.0 * pulse, rim)
		draw_circle(hand, 2.5 * pulse, core)
	func _accent_color() -> Color:
		if Settings == null:
			return Color(1.0, 0.85, 0.45)
		var stored: Variant = Settings.get_value("accent_color", null)
		if stored is Color:
			return stored
		if stored is String:
			return Color(stored)
		return Color(1.0, 0.85, 0.45)
