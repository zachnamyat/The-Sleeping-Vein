extends Node
class_name StatusEffects

## Per-entity status effect manager. Holds active effects, ticks them per second,
## and applies the appropriate gameplay impact via the entity's HealthComponent
## or other components.
##
## Phase 6 effects (parity-targeted):
##   burn      — fire DoT, 8.4s default, 2 dmg per 0.5s tick (ticket 6.6)
##   poison    — poison DoT + healing reduced 75% while active (ticket 6.7)
##   cold      — speed -50%, magic damage taken +20% (ticket 6.8)
##   freeze    — speed = 0, immune for `freeze_min_remaining` (ticket 6.8)
##   stun      — speed = 0, no attacks (ticket 6.9)
##   bleed     — physical DoT scaling with target max HP (ticket 6.19)
##   confusion — input axes flip on player; mob picks random walk dir (ticket 6.22)
##   slow      — generic move-speed slow (ticket 6.30); cleansed by anti-status pot
##   shock     — lightning chain marker (ticket 6.20 / 6.54)

signal effect_applied(effect_id: StringName, duration: float)
signal effect_expired(effect_id: StringName)

const TICK_INTERVAL: float = 0.5

const BURN_DPS: float = 4.0           ## ticket 6.6 — 2 / 0.5s tick
const POISON_DPS: float = 6.0         ## ticket 6.7 — 3 / 0.5s tick
const POISON_HEAL_REDUCTION: float = 0.75  ## -75% healing received while poisoned
const COLD_SPEED_MULT: float = 0.5
const SLOW_SPEED_MULT: float = 0.65
const BLEED_FRAC_PER_TICK: float = 0.005   ## 0.5% of max HP per 0.5s tick

var _effects: Dictionary = {}   ## { effect_id (StringName) -> { remaining, source, last_tick_time, magnitude } }
var _tick_accumulator: float = 0.0

@export var health_component_path: NodePath


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	_tick_accumulator += delta
	if _tick_accumulator < TICK_INTERVAL:
		_advance_durations(delta)
		return
	_tick_accumulator = 0.0
	_advance_durations(delta)
	_apply_dot_ticks(TICK_INTERVAL)


## Apply (or refresh / extend) a status. Highest-magnitude wins; new duration is
## max(existing, requested) so a long burn isn't shortened by a fast tick.
## `magnitude` is effect-specific (slow %, bleed multiplier...). Optional.
func apply(effect_id: StringName, duration: float, source: Node, magnitude: float = 1.0) -> void:
	if effect_id == &"":
		return
	if _is_resisted(effect_id):
		return
	var existing: Variant = _effects.get(effect_id)
	if existing:
		existing["remaining"] = max(float(existing["remaining"]), duration)
		existing["source"] = source
		existing["magnitude"] = max(float(existing.get("magnitude", 1.0)), magnitude)
	else:
		_effects[effect_id] = { "remaining": duration, "source": source, "magnitude": magnitude }
		effect_applied.emit(effect_id, duration)


func has_effect(effect_id: StringName) -> bool:
	return _effects.has(effect_id)


func magnitude_of(effect_id: StringName) -> float:
	if not _effects.has(effect_id):
		return 0.0
	return float(_effects[effect_id].get("magnitude", 1.0))


func remaining(effect_id: StringName) -> float:
	if not _effects.has(effect_id):
		return 0.0
	return float(_effects[effect_id].get("remaining", 0.0))


func active_ids() -> Array:
	return _effects.keys()


## Phase 6.30 — cleanse mechanic. Pass &"" to clear all status; otherwise the
## specific id only.
func clear(effect_id: StringName) -> void:
	if effect_id == &"":
		var ids: Array = _effects.keys()
		_effects.clear()
		for id in ids:
			effect_expired.emit(id)
		return
	if not _effects.has(effect_id):
		return
	_effects.erase(effect_id)
	effect_expired.emit(effect_id)


func _advance_durations(delta: float) -> void:
	var to_remove: Array = []
	for k in _effects.keys():
		_effects[k]["remaining"] = float(_effects[k]["remaining"]) - delta
		if _effects[k]["remaining"] <= 0.0:
			to_remove.append(k)
	for k in to_remove:
		clear(k)


func _apply_dot_ticks(tick_seconds: float) -> void:
	var hc: HealthComponent = get_node_or_null(health_component_path) as HealthComponent
	if hc == null:
		hc = get_node_or_null("../HealthComponent") as HealthComponent
	if hc == null:
		return
	var ratio: float = tick_seconds / TICK_INTERVAL
	if _effects.has(&"burn"):
		var burn_amt: int = int(round(BURN_DPS * 0.5 * ratio))
		hc.apply_damage(burn_amt, _effects[&"burn"].get("source"), DamageType.FIRE)
	if _effects.has(&"poison"):
		var poison_amt: int = int(round(POISON_DPS * 0.5 * ratio))
		hc.apply_damage(poison_amt, _effects[&"poison"].get("source"), DamageType.POISON)
	if _effects.has(&"bleed"):
		var bleed_amt: int = int(round(float(hc.max_health) * BLEED_FRAC_PER_TICK * ratio))
		bleed_amt = maxi(1, bleed_amt)
		hc.apply_damage(bleed_amt, _effects[&"bleed"].get("source"), DamageType.BLEED)
	# Cold / Freeze / Stun / Confusion / Slow are handled by other systems polling has_effect().


## Phase 6.30 — look up the speed multiplier this tick. Combines cold + slow +
## freeze + stun + (confusion has no inherent slow). Returns 0..1.
func current_speed_multiplier() -> float:
	if has_effect(&"freeze") or has_effect(&"stun"):
		return 0.0
	var mult: float = 1.0
	if has_effect(&"cold"):
		mult *= COLD_SPEED_MULT
	if has_effect(&"slow"):
		mult *= SLOW_SPEED_MULT
	return mult


## Phase 6.7 — healing-received multiplier (poison drops to 25%).
func current_heal_multiplier() -> float:
	if has_effect(&"poison"):
		return 1.0 - POISON_HEAL_REDUCTION
	return 1.0


## Phase 6.22 — input flip while confused. PlayerController consults this every
## frame in _physics_process.
func is_inputs_flipped() -> bool:
	return has_effect(&"confusion")


## Phase 6.17 — shouldn't apply this status because the entity has high resist
## to it. Looked up via the entity's HealthComponent.get_resistance.
func _is_resisted(effect_id: StringName) -> bool:
	var hc: HealthComponent = get_node_or_null(health_component_path) as HealthComponent
	if hc == null:
		hc = get_node_or_null("../HealthComponent") as HealthComponent
	if hc == null:
		return false
	# Map status to its damage type for resist lookup. Stun/confusion/slow don't
	# have a damage component so they ignore resists by default.
	var type_for_status: StringName = &""
	match effect_id:
		&"burn":     type_for_status = DamageType.FIRE
		&"poison":   type_for_status = DamageType.POISON
		&"cold":     type_for_status = DamageType.COLD
		&"freeze":   type_for_status = DamageType.COLD
		&"bleed":    type_for_status = DamageType.PHYSICAL
		&"shock":    type_for_status = DamageType.LIGHTNING
	if type_for_status == &"":
		return false
	# 95% resist or higher fully ignores the effect.
	return hc.get_resistance(type_for_status) >= 0.95
