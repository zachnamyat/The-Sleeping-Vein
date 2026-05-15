extends Node

## Phase 4.32 + 4.42 — random world events scheduler.
##
## Listens to AudioBus.aphelion_beat and rolls for events every N beats.
## Active events emit UI toasts + EventBus signals so other systems (mobs,
## ambient music, screen shake) can react.
##
## Catalog (parity-minimum):
##   - "wandering_trader"  : NPC arrives at the Anchor for 4 beats (Phase 9
##                           will replace the placeholder toast with a real
##                           merchant scene; the event hook is in place now).
##   - "suncrack"          : Aphelion-damage Sliver-burst event (4.42).
##                           Player loses 50 slivers immediately; screen
##                           pulses red. Triggers at a baseline 1/200 per
##                           beat, biased upward as remaining slivers fall.
##   - "hollowling_swarm"  : Triggers 4.43 motes VFX + scales mob spawn rate.

const ROLL_INTERVAL_BEATS: int = 4

signal world_event_started(event_id: StringName)
signal world_event_ended(event_id: StringName)

var _beat_counter: int = 0
var _active_events: Dictionary = {}   ## event_id -> beats_remaining


func _ready() -> void:
	if AudioBus:
		AudioBus.aphelion_beat.connect(_on_beat)


func _on_beat() -> void:
	_beat_counter += 1
	_tick_active()
	if _beat_counter % ROLL_INTERVAL_BEATS == 0:
		_roll_new()


func _tick_active() -> void:
	for k in _active_events.keys():
		_active_events[k] -= 1
		if _active_events[k] <= 0:
			world_event_ended.emit(k)
			_active_events.erase(k)


func _roll_new() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Suncrack: chance grows as the Aphelion dims. The closer to zero slivers,
	# the more frequent the event — narratively pressuring the player to
	# finish runs faster as the world withers.
	var dim_fraction: float = 1.0 - clampf(
		float(GameState.aphelion_slivers_remaining) / float(GameState.APHELION_STARTING_SLIVERS),
		0.0, 1.0,
	)
	var suncrack_chance: float = 0.005 + dim_fraction * 0.05
	if rng.randf() < suncrack_chance:
		_start_suncrack()
		return
	if rng.randf() < 0.03:
		_start_event(&"wandering_trader", 8)
		EventBus.ui_toast.emit("A trader has arrived at the Anchor.", 3.0)
		return
	if rng.randf() < 0.02:
		_start_event(&"hollowling_swarm", 4)
		EventBus.ui_toast.emit("The Hollowling motes thicken.", 3.0)


func _start_event(id: StringName, beats: int) -> void:
	_active_events[id] = beats
	world_event_started.emit(id)


func _start_suncrack() -> void:
	_start_event(&"suncrack", 2)
	EventBus.ui_toast.emit("Suncrack — the Aphelion bleeds light.", 3.0)
	EventBus.screen_pulse_requested.emit(0.65, 0.45)
	for _i in range(50):
		if GameState.aphelion_slivers_remaining <= 0:
			break
		GameState.consume_sliver()


func is_active(event_id: StringName) -> bool:
	return _active_events.has(event_id)
