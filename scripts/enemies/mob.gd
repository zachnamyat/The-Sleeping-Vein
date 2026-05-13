extends CharacterBody2D
class_name Mob

## Generic mob driven by a MobDef resource. Behavior selected per mob_def.
## Phase 2: CHASE is the only behavior. Phases 4+ will add WANDER, RANGED, BOSS_SCRIPTED.

@export var mob_def: MobDef
@export var spawn_facing: Vector2 = Vector2.DOWN

@onready var sprite: Sprite2D = $Sprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var contact_hitbox: HitboxComponent = $ContactHitbox

var _target_player: Node2D = null
var _facing: Vector2 = Vector2.DOWN
var _spawn_position: Vector2 = Vector2.ZERO
var _is_dying: bool = false  ## Set once the death tween starts to suppress further AI ticks.


func _ready() -> void:
	add_to_group("mob")
	_spawn_position = global_position
	_apply_def()
	if hurtbox:
		hurtbox.team = &"enemy"
		hurtbox.health_component = health
	if contact_hitbox:
		contact_hitbox.team = &"enemy"
		contact_hitbox.lifetime = 0.0
		# Repeat-tick so the player keeps taking damage while in contact. The
		# player's Hurtbox i_frames gate the actual damage cadence.
		contact_hitbox.repeat_interval = 0.5
		contact_hitbox.arm(-1.0)
	if health:
		health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if health == null or health.is_dead() or _is_dying or mob_def == null:
		velocity = Vector2.ZERO
		return
	_acquire_target()
	# Ticket 2.28 — leash check: if we strayed too far from spawn, drop aggro
	# and walk home regardless of player proximity.
	var dist_from_home: float = (global_position - _spawn_position).length()
	if mob_def.leash_radius > 0.0 and dist_from_home > mob_def.leash_radius:
		_target_player = null
		var home_vec: Vector2 = _spawn_position - global_position
		if home_vec.length() > 4.0:
			velocity = home_vec.normalized() * mob_def.move_speed
		else:
			velocity = Vector2.ZERO
	elif _target_player != null:
		var dir: Vector2 = (_target_player.global_position - global_position)
		var dist: float = dir.length()
		match mob_def.behavior:
			MobDef.Behavior.CHASE:
				if dist < mob_def.detection_radius:
					velocity = dir.normalized() * mob_def.move_speed
				else:
					velocity = Vector2.ZERO
			MobDef.Behavior.CRITTER_FLEE:
				# Ticket 2.18 — passive wildlife runs *away* from the player.
				if dist < mob_def.detection_radius:
					velocity = -dir.normalized() * mob_def.move_speed
				else:
					velocity = Vector2.ZERO
			_:
				velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	global_position = global_position.round()
	if velocity.length() > 1.0:
		_facing = velocity.normalized()
		_update_sprite()


func _apply_def() -> void:
	if mob_def == null:
		return
	if sprite and mob_def.sprite:
		sprite.texture = mob_def.sprite
	if health:
		health.max_health = mob_def.max_health
		health.armor = mob_def.armor
		health.current_health = health.max_health
		for type_key in mob_def.resistances.keys():
			health.set_resistance(StringName(type_key), float(mob_def.resistances[type_key]))
	if contact_hitbox:
		contact_hitbox.base_damage = mob_def.contact_damage
		contact_hitbox.damage_type = mob_def.contact_damage_type


func _update_sprite() -> void:
	if sprite == null:
		return
	sprite.flip_h = _facing.x < -0.1


func _acquire_target() -> void:
	if _target_player and is_instance_valid(_target_player):
		# Ticket 2.28 — drop target if the player walked beyond aggro range +
		# 50% (a small hysteresis stops jittering at the edge).
		if mob_def and mob_def.detection_radius > 0.0:
			var d: float = (_target_player.global_position - global_position).length()
			if d > mob_def.detection_radius * 1.5:
				_target_player = null
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.size() == 0 or mob_def == null:
		return
	# Ticket 2.19 — only aggro if the nearest player is within detection range.
	var p := players[0] as Node2D
	if p == null:
		return
	var initial_dist: float = (p.global_position - global_position).length()
	if initial_dist <= mob_def.detection_radius:
		_target_player = p


func _on_died(killer: Node) -> void:
	if mob_def == null:
		queue_free()
		return
	if _is_dying:
		return
	_is_dying = true
	_drop_loot()
	_award_xp(killer)
	EventBus.entity_killed.emit(self, killer)
	# Ticket 2.21 — short death animation before despawn. Disable colliders
	# immediately so the player can walk through the fading sprite.
	if contact_hitbox:
		contact_hitbox.disarm()
	set_collision_layer_value(5, false)
	set_collision_mask_value(1, false)
	_play_death_animation()


func _play_death_animation() -> void:
	if sprite == null:
		queue_free()
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.tween_property(sprite, "scale", sprite.scale * 1.2, 0.4)
	tween.chain().tween_callback(queue_free)


func _drop_loot() -> void:
	if mob_def.loot_table == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var drops: Array = mob_def.loot_table.roll(rng)
	for drop in drops:
		var item_id: StringName = drop["item_id"]
		var count: int = int(drop["count"])
		_spawn_drop(item_id, count)


func _spawn_drop(item_id: StringName, count: int) -> void:
	var drop_scene: PackedScene = load("res://scenes/items/item_drop.tscn") as PackedScene
	if drop_scene == null:
		return
	var drop := drop_scene.instantiate() as ItemDrop
	if drop == null:
		return
	drop.item_id = item_id
	drop.count = count
	drop.global_position = global_position
	get_tree().current_scene.add_child(drop)


func _award_xp(killer: Node) -> void:
	if mob_def.xp_value > 0 and mob_def.xp_skill != &"":
		EventBus.skill_xp_gained.emit(mob_def.xp_skill, mob_def.xp_value)
