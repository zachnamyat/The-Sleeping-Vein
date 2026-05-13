extends Node

## Food-buff manager. One of each buff type stacks; new application replaces older.
## Phase 8 MVP: tracks buff_id → remaining_seconds and emits change signal.
## Phase 15 polish wires buff effects (mining_speed, magic_damage, etc.) into
## the systems that read them.

signal buff_applied(buff_id: StringName, duration: float)
signal buff_expired(buff_id: StringName)

const TICK: float = 0.5

var _active: Dictionary = {}    ## { buff_id (StringName) -> remaining_seconds (float) }
var _accum: float = 0.0


func _ready() -> void:
	set_process(true)


func apply(buff_id: StringName, duration: float) -> void:
	if buff_id == &"" or duration <= 0.0:
		return
	_active[buff_id] = duration
	buff_applied.emit(buff_id, duration)
	EventBus.ui_toast.emit("Buff: %s" % String(buff_id).replace("buff_", "").capitalize(), 1.2)


func has(buff_id: StringName) -> bool:
	return _active.has(buff_id)


func remaining(buff_id: StringName) -> float:
	return float(_active.get(buff_id, 0.0))


func _process(delta: float) -> void:
	_accum += delta
	if _accum < TICK:
		return
	_accum = 0.0
	var to_drop: Array = []
	for k in _active.keys():
		_active[k] = float(_active[k]) - TICK
		if _active[k] <= 0.0:
			to_drop.append(k)
	for k in to_drop:
		_active.erase(k)
		buff_expired.emit(k)
