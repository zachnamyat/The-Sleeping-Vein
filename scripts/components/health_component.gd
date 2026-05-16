extends Node
class_name HealthComponent

## Reusable health pool. Attach as a child of any damageable entity.
## Emits signals so HUDs/AI can react without polling.
##
## Phase 6 additions:
##   - Damage flow consults `weaknesses` (multiplier > 1.0) before resistances.
##   - `apply_damage` returns the post-mitigation amount so HitboxComponent can
##     route lifesteal / thorns off the actual damage dealt.
##   - Stagger meter accumulates from heavy hits and triggers the `staggered`
##     signal once full (mob.gd consumes it for a brief stun).
##   - `heal()` honours the entity's StatusEffects healing multiplier (poison
##     drops it to 25%).

signal health_changed(current: int, maximum: int)
signal damaged(amount: int, source: Node, type: StringName)
signal healed(amount: int, source: Node)
signal died(killer: Node)
signal staggered(seconds: float)

@export var max_health: int = 100
@export var armor: int = 0
@export var is_invulnerable: bool = false

## Phase 6.39 — stagger meter, mirrored from MobDef on _ready.
@export var stagger_threshold: int = 30
@export var stagger_recovery_seconds: float = 1.0

## Phase 7 — extra HP / regen pumped in from PlayerStats (talents + Vitality
## set bonuses + accessory items). `bonus_max_health` is added on top of
## `max_health`; effective_max_health() is the cap exposed to callers.
var bonus_max_health: int = 0:
	set(value):
		var ratio: float = effective_health_ratio()
		bonus_max_health = value
		# Keep ratio so a Walker who gains HP mid-game doesn't lose all of it.
		current_health = clampi(int(round(effective_max_health() * ratio)), 1, effective_max_health())
		health_changed.emit(current_health, effective_max_health())
var regen_per_second: float = 0.0
var _regen_accum: float = 0.0

var current_health: int = 100
var stagger_meter: int = 0
var _resistances: Dictionary = {}
var _weaknesses: Dictionary = {}


func _ready() -> void:
	current_health = effective_max_health()
	health_changed.emit(current_health, effective_max_health())
	set_process(true)


func effective_max_health() -> int:
	return max_health + bonus_max_health


func effective_health_ratio() -> float:
	var cap: int = effective_max_health()
	if cap <= 0:
		return 1.0
	return float(current_health) / float(cap)


func _process(delta: float) -> void:
	if regen_per_second <= 0.0 or is_dead():
		return
	_regen_accum += regen_per_second * delta
	if _regen_accum >= 1.0:
		var whole: int = int(floor(_regen_accum))
		_regen_accum -= float(whole)
		heal(whole, self)


func set_max_health(value: int, keep_ratio: bool = false) -> void:
	if value <= 0:
		value = 1
	var ratio: float = effective_health_ratio()
	max_health = value
	if keep_ratio:
		current_health = int(round(effective_max_health() * ratio))
	else:
		current_health = mini(current_health, effective_max_health())
	health_changed.emit(current_health, effective_max_health())


## Phase 6 — damage pipeline. Multiplier order: weakness > resistance > armor
## (handled by CombatMath in the caller, not here).
##   final = amount * weakness_mult * (1 - resist)
## Returns the post-mitigation damage actually applied.
func apply_damage(amount: int, source: Node = null, type: StringName = DamageType.PHYSICAL, is_heavy: bool = false) -> int:
	if is_invulnerable or current_health <= 0:
		return 0
	var weakness: float = float(_weaknesses.get(type, 1.0))
	var resist: float = float(_resistances.get(type, 0.0))
	var post_f: float = float(amount) * weakness * (1.0 - resist)
	var post: int = int(round(post_f))
	post = maxi(post, 0)
	current_health = maxi(0, current_health - post)
	damaged.emit(post, source, type)
	health_changed.emit(current_health, effective_max_health())
	# Phase 6.39 — heavy hits build the stagger meter; once it caps, trigger.
	if is_heavy and stagger_threshold > 0 and not is_dead():
		stagger_meter = mini(stagger_threshold, stagger_meter + post)
		if stagger_meter >= stagger_threshold:
			stagger_meter = 0
			staggered.emit(stagger_recovery_seconds)
	if current_health <= 0:
		died.emit(source)
	return post


func heal(amount: int, source: Node = null) -> int:
	if amount <= 0 or current_health <= 0:
		return 0
	# Phase 6.7 — poison cuts incoming healing.
	var sef := get_node_or_null("../StatusEffects") as StatusEffects
	if sef:
		amount = int(round(float(amount) * sef.current_heal_multiplier()))
	if amount <= 0:
		return 0
	var before: int = current_health
	current_health = mini(effective_max_health(), current_health + amount)
	var delta: int = current_health - before
	if delta > 0:
		healed.emit(delta, source)
		health_changed.emit(current_health, effective_max_health())
	return delta


func set_resistance(type: StringName, fraction: float) -> void:
	_resistances[type] = clampf(fraction, -1.0, 0.95)


func add_resistance(type: StringName, fraction: float) -> void:
	var current: float = float(_resistances.get(type, 0.0))
	set_resistance(type, current + fraction)


func get_resistance(type: StringName) -> float:
	return _resistances.get(type, 0.0)


func set_weakness(type: StringName, multiplier: float) -> void:
	_weaknesses[type] = max(0.0, multiplier)


func get_weakness(type: StringName) -> float:
	return _weaknesses.get(type, 1.0)


func revive(at_fraction: float = 1.0) -> void:
	current_health = clampi(int(round(effective_max_health() * at_fraction)), 1, effective_max_health())
	stagger_meter = 0
	health_changed.emit(current_health, effective_max_health())


func is_dead() -> bool:
	return current_health <= 0
