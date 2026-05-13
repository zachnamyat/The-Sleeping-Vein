extends Node
class_name HealthComponent

## Reusable health pool. Attach as a child of any damageable entity.
## Emits signals so HUDs/AI can react without polling.

signal health_changed(current: int, maximum: int)
signal damaged(amount: int, source: Node, type: StringName)
signal healed(amount: int, source: Node)
signal died(killer: Node)

@export var max_health: int = 100
@export var armor: int = 0
@export var is_invulnerable: bool = false

var current_health: int = 100
var _resistances: Dictionary = {}


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func set_max_health(value: int, keep_ratio: bool = false) -> void:
	if value <= 0:
		value = 1
	var ratio: float = float(current_health) / float(max_health) if max_health > 0 else 1.0
	max_health = value
	if keep_ratio:
		current_health = int(round(max_health * ratio))
	else:
		current_health = mini(current_health, max_health)
	health_changed.emit(current_health, max_health)


func apply_damage(amount: int, source: Node = null, type: StringName = DamageType.PHYSICAL) -> int:
	if is_invulnerable or current_health <= 0:
		return 0
	var resist: float = _resistances.get(type, 0.0)
	var post: int = int(round(float(amount) * (1.0 - resist)))
	post = maxi(post, 0)
	current_health = maxi(0, current_health - post)
	damaged.emit(post, source, type)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		died.emit(source)
	return post


func heal(amount: int, source: Node = null) -> int:
	if amount <= 0 or current_health <= 0:
		return 0
	var before: int = current_health
	current_health = mini(max_health, current_health + amount)
	var delta: int = current_health - before
	if delta > 0:
		healed.emit(delta, source)
		health_changed.emit(current_health, max_health)
	return delta


func set_resistance(type: StringName, fraction: float) -> void:
	_resistances[type] = clampf(fraction, -1.0, 0.95)


func get_resistance(type: StringName) -> float:
	return _resistances.get(type, 0.0)


func revive(at_fraction: float = 1.0) -> void:
	current_health = clampi(int(round(max_health * at_fraction)), 1, max_health)
	health_changed.emit(current_health, max_health)


func is_dead() -> bool:
	return current_health <= 0
