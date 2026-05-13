extends Node
class_name StatusEffects

## Per-entity status effect manager. Holds active effects, ticks them per second,
## and applies the appropriate gameplay impact via the entity's HealthComponent
## or other components.

signal effect_applied(effect_id: StringName, duration: float)
signal effect_expired(effect_id: StringName)

const TICK_INTERVAL: float = 0.5

var _effects: Dictionary = {}   ## { effect_id (StringName) -> { remaining, source, last_tick_time } }
var _tick_accumulator: float = 0.0

@export var health_component_path: NodePath


func _ready() -> void:
	set_physics_process(true)


func _process(delta: float) -> void:
	_tick_accumulator += delta
	if _tick_accumulator < TICK_INTERVAL:
		_advance_durations(delta)
		return
	_tick_accumulator = 0.0
	_advance_durations(delta)
	_apply_dot_ticks(TICK_INTERVAL)


func apply(effect_id: StringName, duration: float, source: Node) -> void:
	if effect_id == &"":
		return
	var existing: Variant = _effects.get(effect_id)
	if existing:
		existing["remaining"] = max(float(existing["remaining"]), duration)
		existing["source"] = source
	else:
		_effects[effect_id] = { "remaining": duration, "source": source }
		effect_applied.emit(effect_id, duration)


func has_effect(effect_id: StringName) -> bool:
	return _effects.has(effect_id)


func clear(effect_id: StringName) -> void:
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
	if _effects.has(&"burn"):
		hc.apply_damage(int(round(2.0 * tick_seconds / TICK_INTERVAL)), _effects[&"burn"].get("source"), &"fire")
	if _effects.has(&"poison"):
		hc.apply_damage(int(round(3.0 * tick_seconds / TICK_INTERVAL)), _effects[&"poison"].get("source"), &"poison")
	# Cold/Freeze/Stun are handled by other systems polling has_effect().


func current_speed_multiplier() -> float:
	if has_effect(&"freeze"):
		return 0.0
	if has_effect(&"cold"):
		return 0.5
	if has_effect(&"stun"):
		return 0.0
	return 1.0
