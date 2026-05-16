extends Node

## Autoload. Centralises combat-feel routing:
## - hit-pause (Engine.time_scale microfreeze on big strikes)
## - convenience helpers callable by gameplay code or directly via EventBus signals
## Camera shake and knockback are applied at the entity level (player Camera2D
## listens to EventBus.camera_shake_requested; HurtboxComponent applies impulses).

const HIT_PAUSE_TIME_SCALE: float = 0.05
const BIG_HIT_DAMAGE_THRESHOLD: int = 20

var _restoring: bool = false


func _ready() -> void:
	EventBus.hit_pause_requested.connect(_on_hit_pause)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	# Phase 2.11 — mining hits, separate from mob damage. Plays a softer chunk
	# tone whether or not the tile is destroyed this swing.
	if MiningSystem and MiningSystem.has_signal("tile_mined"):
		MiningSystem.tile_mined.connect(_on_tile_mined)
	EventBus.tile_changed.connect(_on_tile_changed)


func _on_damage_dealt(_source: Node, target: Node, amount: int, type: StringName) -> void:
	# Damage above the big-hit threshold gets the full combo: shake + microfreeze.
	# Smaller hits emit shake only at reduced intensity.
	if amount <= 0:
		return
	# Phase 2.42 + 6.61 — damage-type-keyed hit SFX, played positionally if the
	# target is a Node2D (mob). Player hits stay non-positional since they're
	# the listener.
	_play_hit_sfx(target, type)
	if amount >= BIG_HIT_DAMAGE_THRESHOLD:
		EventBus.hit_pause_requested.emit(0.06)
		EventBus.camera_shake_requested.emit(2.5, 0.18)
	else:
		EventBus.camera_shake_requested.emit(1.0, 0.10)


func _play_hit_sfx(target: Node, type: StringName) -> void:
	if AudioBus == null:
		return
	if target == null:
		return
	# Phase 2.42 — type-keyed sound; falls back to "hit_mob" if no map entry.
	var sound: StringName = DamageType.hit_sfx_for(type)
	if target.is_in_group("player"):
		sound = &"hit_player"
	if target is Node2D and not target.is_in_group("player"):
		AudioBus.play_sfx(sound, (target as Node2D).global_position)
	else:
		AudioBus.play_sfx(sound)


func _on_tile_mined(_coord: Vector2i, _ore_id: StringName, _source: Node) -> void:
	if AudioBus:
		AudioBus.play_sfx(&"tile_broken")


func _on_tile_changed(_coord: Vector2i, _old_id: int, new_id: int) -> void:
	# Fired by MiningSystem on every swing that lands but doesn't destroy the
	# tile (new_id >= 0). Plays a softer chunk tone to give per-hit feedback.
	if new_id < 0:
		return
	if AudioBus:
		AudioBus.play_sfx(&"tile_chunk")


func _on_hit_pause(duration: float) -> void:
	if _restoring:
		return
	_restoring = true
	Engine.time_scale = HIT_PAUSE_TIME_SCALE
	# Real-time-driven timer so we resume even while time_scale is near zero.
	var timer := get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(_restore_time_scale)


func _restore_time_scale() -> void:
	Engine.time_scale = 1.0
	_restoring = false
