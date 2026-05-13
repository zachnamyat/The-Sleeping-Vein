extends Node
class_name ManaComponent

## Reusable mana pool for staves and magic abilities.
## Mana regenerates passively at `regen_per_second` mana per second.

signal mana_changed(current: int, maximum: int)
signal mana_spent(amount: int)
signal mana_failed(amount_needed: int)

@export var max_mana: int = 100
@export var regen_per_second: float = 2.0

var current_mana: float = 100.0


func _ready() -> void:
	current_mana = float(max_mana)
	mana_changed.emit(int(current_mana), max_mana)


func _process(delta: float) -> void:
	if current_mana < float(max_mana):
		var before: int = int(current_mana)
		current_mana = minf(float(max_mana), current_mana + regen_per_second * delta)
		var after: int = int(current_mana)
		if after != before:
			mana_changed.emit(after, max_mana)


func try_spend(amount: int) -> bool:
	if amount <= 0:
		return true
	if int(current_mana) < amount:
		mana_failed.emit(amount)
		return false
	current_mana -= float(amount)
	mana_spent.emit(amount)
	mana_changed.emit(int(current_mana), max_mana)
	return true


func can_afford(amount: int) -> bool:
	return int(current_mana) >= amount


func add_mana(amount: int) -> void:
	if amount <= 0:
		return
	current_mana = minf(float(max_mana), current_mana + float(amount))
	mana_changed.emit(int(current_mana), max_mana)


func set_max_mana(value: int, keep_ratio: bool = false) -> void:
	if value <= 0:
		value = 1
	var ratio: float = current_mana / float(max_mana) if max_mana > 0 else 1.0
	max_mana = value
	if keep_ratio:
		current_mana = float(max_mana) * ratio
	else:
		current_mana = minf(current_mana, float(max_mana))
	mana_changed.emit(int(current_mana), max_mana)
