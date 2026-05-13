extends Node
class_name StaminaComponent

## Phase 1 ticket 1.27. Tracks a player resource consumed by sprint / swim / dodge.
## Regens passively when not draining. Emits `stamina_changed` for HUD wiring.

signal stamina_changed(current: float, maximum: float)

@export var max_stamina: float = 100.0
@export var regen_per_second: float = 20.0
@export var regen_delay_seconds: float = 0.5
@export var sprint_drain_per_second: float = 28.0
@export var dodge_cost: float = 25.0

var current: float
var _delay_remaining: float = 0.0


func _ready() -> void:
	current = max_stamina


func _process(delta: float) -> void:
	if _delay_remaining > 0.0:
		_delay_remaining -= delta
		return
	if current < max_stamina:
		current = min(max_stamina, current + regen_per_second * delta)
		stamina_changed.emit(current, max_stamina)


func drain(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if current < amount:
		return false
	current -= amount
	_delay_remaining = regen_delay_seconds
	stamina_changed.emit(current, max_stamina)
	return true


func drain_continuous(per_second_amount: float, delta: float) -> bool:
	var amount := per_second_amount * delta
	if current <= 0.0:
		return false
	current = max(0.0, current - amount)
	_delay_remaining = regen_delay_seconds
	stamina_changed.emit(current, max_stamina)
	return current > 0.0


func has(amount: float) -> bool:
	return current >= amount
