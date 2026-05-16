extends CharacterBody2D
class_name Boss

## Multi-phase boss base. Driven by `mob_def` for stats and an array of `phase_thresholds`
## (HP fractions where phase increments). Specific bosses subclass for phase-specific
## attacks; Glaur-em is the first implementation.
##
## Phase 5 boss-systems layered in 2026-05-15:
##   5.18 — boss music swap (per-boss override via `boss_music_id`)
##   5.25 — arena gate-lock: a BossArena child blocks reentry while _engaged
##   5.26 — intro voice/sting on first engagement
##   5.28 — telegraph red-zone shader attached as `BossTelegraph` child
##   5.29 — enrage timer: after `enrage_after_seconds` the boss gains a
##           damage / speed boost that ramps toward instant-kill if ignored
##   5.30 — defeat fanfare: long shake + screen pulse + AudioBus sting

signal phase_advanced(phase: int)
signal enrage_started

@export var mob_def: MobDef
@export var phase_thresholds: Array[float] = [1.0, 0.5, 0.2]
@export var boss_id: StringName = &"boss_generic"
@export var minion_def_path: String = ""
@export var minion_spawn_period: float = 6.0
@export var minion_max_alive: int = 3
@export var boss_music_id: StringName = &"boss_glaurem_theme"
@export var intro_sfx_id: StringName = &"boss_intro_sting"
@export var enrage_after_seconds: float = 240.0
@export var enrage_damage_multiplier: float = 2.0
@export var enrage_speed_multiplier: float = 1.6
@export var fanfare_sfx_id: StringName = &"boss_defeat_fanfare"
@export var defeat_shake_intensity: float = 5.0
@export var defeat_shake_duration: float = 1.2
@export var trinket_item_id: StringName = &"glaurem_trinket"
@export var shell_item_id: StringName = &"engorged_stone_shell"
@export var shell_drop_count: int = 4
@export var fragment_item_id: StringName = &"sovereign_name_fragment_1"
@export var pulse_item_id: StringName = &"stone_fathers_pulse"
@export var telegraph_radius_px: float = 36.0
@export var telegraph_period_seconds: float = 4.5
## Phase 6.48 — per-phase attack pattern resources. Index matches `current_phase`.
## When provided, BossAttackCycler drives the boss instead of the per-class
## hardcoded patterns from earlier phases.
@export var phase_patterns: Array[Resource] = []

@onready var sprite: Sprite2D = $Sprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var contact_hitbox: HitboxComponent = $ContactHitbox

var current_phase: int = 0
var _engaged: bool = false
var _enraged: bool = false
var _target: Node2D
var _facing: Vector2 = Vector2.DOWN
var _minion_timer: float = 0.0
var _spawned_minions: Array = []
var _engagement_seconds: float = 0.0
var _telegraph_node: Node2D
var _telegraph_accum: float = 0.0
var _attack_cycler: BossAttackCycler


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
	_attach_telegraph()
	_attach_attack_cycler()


func _attach_attack_cycler() -> void:
	# Phase 6.48 — when phase_patterns are configured, spin up an attack-cycler
	# child that walks the current phase's pattern. Existing per-boss minion +
	# slam logic still runs alongside; the cycler adds telegraphed AoEs.
	if phase_patterns.is_empty():
		return
	_attack_cycler = BossAttackCycler.new()
	_attack_cycler.name = "AttackCycler"
	_attack_cycler.attached_boss = self
	_attack_cycler.pattern = phase_patterns[0] if phase_patterns.size() > 0 else null
	add_child(_attack_cycler)


func _attach_telegraph() -> void:
	# Phase 5.28 — a translucent red ring on the boss that grows just before a
	# slam. The scene loads only when an arena is nearby; the boss itself draws
	# the ring procedurally so we don't need a separate art asset for MVP.
	var scn := load("res://scenes/fx/boss_telegraph.tscn") as PackedScene
	if scn == null:
		return
	var node := scn.instantiate() as Node2D
	if node == null:
		return
	node.position = Vector2.ZERO
	node.set("ring_radius_px", telegraph_radius_px)
	node.visible = false
	add_child(node)
	_telegraph_node = node


func _physics_process(delta: float) -> void:
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
			_on_first_engaged()
			if _attack_cycler:
				_attack_cycler.start()
	if _engaged:
		_engagement_seconds += delta
		if not _enraged and _engagement_seconds >= enrage_after_seconds and enrage_after_seconds > 0.0:
			_trigger_enrage()
		var dir: Vector2 = (_target.global_position - global_position)
		var base_speed: float = (mob_def.move_speed if mob_def else 24.0) * (1.0 + 0.2 * current_phase)
		if _enraged:
			base_speed *= enrage_speed_multiplier
		velocity = dir.normalized() * base_speed
		move_and_slide()
		if dir.length() > 1.0:
			_facing = dir.normalized()
			if sprite:
				sprite.flip_h = _facing.x < -0.1
		_tick_minions(delta)
		_tick_telegraph(delta)


func _on_first_engaged() -> void:
	EventBus.boss_engaged.emit(boss_id)
	# Phase 5.18 — kick boss-fight music on first engagement.
	if AudioBus:
		if boss_music_id != &"":
			AudioBus.play_music(boss_music_id, 1.0)
		# Phase 5.26 — voice / sting on intro.
		if intro_sfx_id != &"":
			AudioBus.play_sfx(intro_sfx_id)
	# Phase 5.25 — close the arena gate behind the player.
	for arena in get_tree().get_nodes_in_group("boss_arena"):
		if arena.has_method("lock_gate_for"):
			arena.call("lock_gate_for", self)


func _trigger_enrage() -> void:
	_enraged = true
	enrage_started.emit()
	if contact_hitbox and mob_def:
		contact_hitbox.base_damage = int(round(float(contact_hitbox.base_damage) * enrage_damage_multiplier))
	if sprite:
		var tween := create_tween().set_loops()
		tween.tween_property(sprite, "modulate", Color(1.6, 0.5, 0.5, 1.0), 0.4)
		tween.tween_property(sprite, "modulate", Color(1.0, 0.7, 0.7, 1.0), 0.4)
	EventBus.ui_toast.emit("ENRAGED — %s draws on the Beat itself." % (mob_def.display_name if mob_def else String(boss_id)), 3.0)
	if AudioBus:
		AudioBus.play_sfx(&"boss_enrage")
	EventBus.screen_pulse_requested.emit(0.4, 0.6)


func _tick_telegraph(delta: float) -> void:
	# Phase 5.28 — periodic telegraph: glow ring for 0.7s then fade. The ring's
	# damage zone is the contact_hitbox itself; the visual is a warning.
	if _telegraph_node == null:
		return
	_telegraph_accum += delta
	if _telegraph_accum >= telegraph_period_seconds:
		_telegraph_accum = 0.0
		_telegraph_node.visible = true
		if _telegraph_node.has_method("flash"):
			_telegraph_node.call("flash", 0.8)
		else:
			# Fall back to a manual fade if the script's missing.
			var t := create_tween()
			t.tween_property(_telegraph_node, "modulate:a", 1.0, 0.05)
			t.tween_property(_telegraph_node, "modulate:a", 0.0, 0.7)
			t.finished.connect(func() -> void:
				if is_instance_valid(_telegraph_node):
					_telegraph_node.visible = false
			)


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
	# Phase 6.48 — swap to the new phase's attack pattern when one is defined.
	if _attack_cycler and current_phase < phase_patterns.size():
		var next_pat: AttackPattern = phase_patterns[current_phase] as AttackPattern
		if next_pat:
			_attack_cycler.stop()
			_attack_cycler.pattern = next_pat
			_attack_cycler.start()


func _on_died(killer: Node) -> void:
	if _attack_cycler:
		_attack_cycler.stop()
	GameState.mark_boss_defeated(boss_id)
	GameState.sovereign_threads += 1
	EventBus.sovereign_defeated.emit(boss_id, StringName("name_fragment_%d" % (GameState.sovereign_threads)))
	# Phase 5.30 — defeat fanfare.
	_play_defeat_fanfare()
	# Phase 5.33 — Glaur-em-specific carving placed on floor under corpse.
	if boss_id == &"boss_glaurem":
		_place_glaurem_carving()
	# Phase 5.19 — Hunter's Crown: first kill grants the title item.
	if GameState.sovereign_threads == 1:
		Inventory.try_add(&"hunters_crown", 1)
		EventBus.ui_toast.emit("Title earned: Hunter's Crown.", 3.0)
	# Drop key relic + name fragment + shell + trinket.
	_drop_boss_loot()
	# Phase 5.18 — clear boss music; AudioBus.play_ambient on biome cycle resumes.
	if AudioBus:
		AudioBus.stop_music()
	# Phase 5.25 — unlock the arena gate.
	for arena in get_tree().get_nodes_in_group("boss_arena"):
		if arena.has_method("unlock_gate"):
			arena.call("unlock_gate")
	queue_free()


func _play_defeat_fanfare() -> void:
	if AudioBus and fanfare_sfx_id != &"":
		AudioBus.play_sfx(fanfare_sfx_id)
	EventBus.camera_shake_requested.emit(defeat_shake_intensity, defeat_shake_duration)
	EventBus.screen_pulse_requested.emit(0.6, 0.9)
	EventBus.hit_pause_requested.emit(0.2)


func _place_glaurem_carving() -> void:
	# Phase 5.33 — leave a small carved-floor decal where Glaur-em fell. Says
	# "thank you for the quiet" in faux-Vesari script. Pure flavor.
	var scn := load("res://scenes/fx/glaurem_carving.tscn") as PackedScene
	if scn == null:
		return
	var node := scn.instantiate() as Node2D
	if node == null:
		return
	var parent: Node = get_tree().current_scene
	var entities := parent.get_node_or_null("WorldGen/YSortRoot/Entities") as Node2D
	if entities:
		parent = entities
	node.position = global_position
	parent.add_child(node)


func _drop_boss_loot() -> void:
	# Phase 5.5 — Glaur-em drops the Stone-Father's Pulse + a shell stack +
	# the Name-Fragment relic. Phase 3.70 adds a boss-unique trinket.
	var scn := load("res://scenes/items/item_drop.tscn") as PackedScene
	if scn == null:
		return
	var drops: Array[Dictionary] = [
		{"id": pulse_item_id, "count": 1},
		{"id": fragment_item_id, "count": 1},
		{"id": shell_item_id, "count": shell_drop_count},
		# Phase 9.4 — Ancient Coin guaranteed drop from bosses.
		{"id": &"ancient_coin", "count": int(round(randf_range(40.0, 65.0)))},
	]
	if trinket_item_id != &"":
		drops.append({"id": trinket_item_id, "count": 1})
	for d in drops:
		var item_id: StringName = d["id"]
		if item_id == &"":
			continue
		var drop := scn.instantiate() as ItemDrop
		drop.item_id = item_id
		drop.count = int(d["count"])
		drop.global_position = global_position + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		get_tree().current_scene.add_child(drop)
