extends CharacterBody2D
class_name Boss

## Multi-phase boss base. Driven by `mob_def` for stats and an array of `phase_thresholds`
## (HP fractions where phase increments). Specific bosses subclass for phase-specific
## attacks; Glaur-em is the first implementation.

signal phase_advanced(phase: int)

@export var mob_def: MobDef
@export var phase_thresholds: Array[float] = [1.0, 0.5, 0.2]
@export var boss_id: StringName = &"boss_generic"
@export var minion_def_path: String = ""
@export var minion_spawn_period: float = 6.0
@export var minion_max_alive: int = 3

@onready var sprite: Sprite2D = $Sprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var contact_hitbox: HitboxComponent = $ContactHitbox

var current_phase: int = 0
var _engaged: bool = false
var _target: Node2D
var _facing: Vector2 = Vector2.DOWN
var _minion_timer: float = 0.0
var _spawned_minions: Array = []


func _ready() -> void:
	add_to_group("boss")
	if mob_def:
		if sprite and mob_def.sprite:
			sprite.texture = mob_def.sprite
		if health:
			health.max_health = mob_def.max_health
			health.armor = mob_def.armor
			health.current_health = health.max_health
		if contact_hitbox:
			contact_hitbox.base_damage = mob_def.contact_damage
			contact_hitbox.damage_type = mob_def.contact_damage_type
	if hurtbox:
		hurtbox.team = &"boss"
		hurtbox.health_component = health
	if contact_hitbox:
		contact_hitbox.team = &"boss"
		contact_hitbox.arm(-1.0)
	if health:
		health.health_changed.connect(_on_hp_changed)
		health.died.connect(_on_died)


func _physics_process(_delta: float) -> void:
	if health and health.is_dead():
		return
	if _target == null or not is_instance_valid(_target):
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_target = players[0]
	if _target == null:
		return
	if not _engaged:
		var d: float = global_position.distance_to(_target.global_position)
		if d < (mob_def.detection_radius if mob_def else 96.0):
			_engaged = true
			EventBus.boss_engaged.emit(boss_id)
	if _engaged:
		var dir: Vector2 = (_target.global_position - global_position)
		var speed: float = (mob_def.move_speed if mob_def else 24.0) * (1.0 + 0.2 * current_phase)
		velocity = dir.normalized() * speed
		move_and_slide()
		if dir.length() > 1.0:
			_facing = dir.normalized()
			if sprite:
				sprite.flip_h = _facing.x < -0.1
		_tick_minions(get_physics_process_delta_time())


func _tick_minions(delta: float) -> void:
	if minion_def_path == "" or current_phase < 1:
		return
	_spawned_minions = _spawned_minions.filter(func(m): return is_instance_valid(m))
	if _spawned_minions.size() >= minion_max_alive:
		return
	_minion_timer -= delta
	if _minion_timer > 0.0:
		return
	_minion_timer = minion_spawn_period
	_spawn_minion()


func _spawn_minion() -> void:
	var def := load(minion_def_path) as MobDef
	if def == null:
		return
	var scn := load("res://scenes/enemies/stone_hopper.tscn") as PackedScene
	if scn == null:
		return
	var minion := scn.instantiate() as Mob
	if minion == null:
		return
	minion.mob_def = def
	var angle: float = randf() * TAU
	var radius: float = 28.0
	minion.global_position = global_position + Vector2(cos(angle), sin(angle)) * radius
	get_tree().current_scene.add_child(minion)
	_spawned_minions.append(minion)


func _on_hp_changed(current: int, maximum: int) -> void:
	var frac: float = float(current) / float(maximum) if maximum > 0 else 0.0
	for i in range(phase_thresholds.size()):
		if frac <= phase_thresholds[i] and current_phase < i:
			current_phase = i
			phase_advanced.emit(i)
			_apply_phase()


func _apply_phase() -> void:
	# Subclass override hook. Default behavior: scale contact damage with phase.
	if contact_hitbox and mob_def:
		contact_hitbox.base_damage = mob_def.contact_damage + current_phase * 2


func _on_died(killer: Node) -> void:
	GameState.mark_boss_defeated(boss_id)
	GameState.sovereign_threads += 1
	EventBus.sovereign_defeated.emit(boss_id, StringName("name_fragment_%d" % (GameState.sovereign_threads)))
	# Drop key relic + name fragment.
	_drop_boss_loot()
	queue_free()


func _drop_boss_loot() -> void:
	# Phase 5 specific: Glaur-em drops the Stone-Father's Pulse.
	var pulse_id: StringName = &"stone_fathers_pulse"
	var fragment_id: StringName = &"sovereign_name_fragment_1"
	var scn := load("res://scenes/items/item_drop.tscn") as PackedScene
	if scn == null:
		return
	for item in [pulse_id, fragment_id]:
		var drop := scn.instantiate() as ItemDrop
		drop.item_id = item
		drop.count = 1
		drop.global_position = global_position
		get_tree().current_scene.add_child(drop)
