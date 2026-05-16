extends Node

## Phase 6.49 — DPS meter / parser. Listens to EventBus.damage_dealt + entity_killed
## and tracks per-source damage over a sliding 5-second window. Exposes:
##   - dps_for_source(node) -> float
##   - player_dps() -> float (sum of any source in group "player")
##   - kills_in_window() -> int
##
## Phase 6.59 — adaptive music intensity. Combat events bump intensity; it decays
## back to 0 over 6 seconds. Emits combat_intensity_changed each frame the value
## crosses a 0.05 boundary so AudioBus can fade between layered tracks.

signal entry_added(source: WeakRef, amount: int)

const WINDOW_SECONDS: float = 5.0
const INTENSITY_PER_HIT: float = 0.10
const INTENSITY_PER_KILL: float = 0.25
const INTENSITY_DECAY_PER_SECOND: float = 0.20

var _entries: Array = []  ## { t: float, source_id: int, amount: int }
var _kills: Array = []    ## { t: float, killer_id: int }
var _intensity: float = 0.0
var _last_intensity_emitted: float = -1.0


func _ready() -> void:
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.entity_killed.connect(_on_entity_killed)
	set_process(true)


func _process(delta: float) -> void:
	_intensity = maxf(0.0, _intensity - INTENSITY_DECAY_PER_SECOND * delta)
	if absf(_intensity - _last_intensity_emitted) >= 0.05:
		_last_intensity_emitted = _intensity
		EventBus.combat_intensity_changed.emit(_intensity)
	# Trim old entries.
	var now: float = _now()
	while not _entries.is_empty() and now - float(_entries[0].get("t", 0.0)) > WINDOW_SECONDS:
		_entries.pop_front()
	while not _kills.is_empty() and now - float(_kills[0].get("t", 0.0)) > WINDOW_SECONDS:
		_kills.pop_front()


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _on_damage_dealt(source: Node, _target: Node, amount: int, _type: StringName) -> void:
	if amount <= 0 or source == null:
		return
	_entries.append({ "t": _now(), "source_id": source.get_instance_id(), "amount": amount })
	_intensity = clampf(_intensity + INTENSITY_PER_HIT, 0.0, 1.0)


func _on_entity_killed(_entity: Node, killer: Node) -> void:
	var killer_id: int = killer.get_instance_id() if killer else 0
	_kills.append({ "t": _now(), "killer_id": killer_id })
	_intensity = clampf(_intensity + INTENSITY_PER_KILL, 0.0, 1.0)


func dps_for_source(node: Node) -> float:
	if node == null:
		return 0.0
	var id: int = node.get_instance_id()
	var total: int = 0
	for e in _entries:
		if int(e.get("source_id", 0)) == id:
			total += int(e.get("amount", 0))
	return float(total) / WINDOW_SECONDS


func player_dps() -> float:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return 0.0
	var total: int = 0
	for e in _entries:
		var sid: int = int(e.get("source_id", 0))
		var src := instance_from_id(sid)
		if src and src is Node and (src as Node).is_in_group("player"):
			total += int(e.get("amount", 0))
	return float(total) / WINDOW_SECONDS


func intensity() -> float:
	return _intensity


func kills_in_window() -> int:
	return _kills.size()
