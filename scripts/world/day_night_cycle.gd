extends Node
class_name DayNightCycle

## Phase 1 cycle + Phase 4.46 extension.
##
## Two clocks now run side-by-side:
##   - The Aphelion Beat (AudioBus.aphelion_beat, 23s) drives the 4-phase
##     ambient color cycle for moody lighting beats. This is the "fast" clock.
##   - A 24-minute "world day" wraps that with a smoother dawn/noon/dusk
##     overlay so a session feels like it has time-of-day progression
##     independent of the Aphelion Beat's narrative cadence. Phase 4.46.
##
## Phase 4.61 reads `is_day_in_world_clock()` so mob spawn rates can scale.
## Phase 11 cold/heat zones consume the world clock for diurnal swing.

signal phase_changed(phase_idx: int, phase_name: StringName)
signal world_clock_phase_changed(world_phase: StringName)

const PHASE_NAMES: Array[StringName] = [
	&"high_light",
	&"falling",
	&"low_light",
	&"rising",
]

const WORLD_DAY_SECONDS: float = 24.0 * 60.0   # 24 minutes
const WORLD_DAWN_FRACTION: float = 0.20
const WORLD_DUSK_FRACTION: float = 0.65
const WORLD_NIGHT_FRACTION: float = 0.85

@export var canvas_modulate_path: NodePath
@export_color_no_alpha var phase_color_high: Color = Color(0.78, 0.72, 0.58)
@export_color_no_alpha var phase_color_falling: Color = Color(0.55, 0.50, 0.40)
@export_color_no_alpha var phase_color_low: Color = Color(0.28, 0.25, 0.20)
@export_color_no_alpha var phase_color_rising: Color = Color(0.55, 0.50, 0.40)

var phase_idx: int = 0
var _world_clock_seconds: float = 0.0
var _world_phase: StringName = &"dawn"


func _ready() -> void:
	if AudioBus:
		AudioBus.aphelion_beat.connect(_on_beat)
	_apply_phase()
	set_process(true)


func _process(delta: float) -> void:
	_world_clock_seconds = fmod(_world_clock_seconds + delta, WORLD_DAY_SECONDS)
	var f: float = _world_clock_seconds / WORLD_DAY_SECONDS
	var new_phase: StringName = _world_phase_for_fraction(f)
	if new_phase != _world_phase:
		_world_phase = new_phase
		world_clock_phase_changed.emit(_world_phase)


func _world_phase_for_fraction(f: float) -> StringName:
	if f < WORLD_DAWN_FRACTION: return &"dawn"
	if f < WORLD_DUSK_FRACTION: return &"day"
	if f < WORLD_NIGHT_FRACTION: return &"dusk"
	return &"night"


func is_day_in_world_clock() -> bool:
	return _world_phase == &"day" or _world_phase == &"dawn"


func world_clock_phase() -> StringName:
	return _world_phase


## Phase 4.63 — skip world-time forward by `seconds` (used by bed sleep).
func skip_time(seconds: float) -> void:
	_world_clock_seconds = fmod(_world_clock_seconds + seconds, WORLD_DAY_SECONDS)
	_world_phase = _world_phase_for_fraction(_world_clock_seconds / WORLD_DAY_SECONDS)
	world_clock_phase_changed.emit(_world_phase)


func _on_beat() -> void:
	phase_idx = (phase_idx + 1) % PHASE_NAMES.size()
	_apply_phase()
	phase_changed.emit(phase_idx, PHASE_NAMES[phase_idx])


func _apply_phase() -> void:
	if canvas_modulate_path == NodePath():
		return
	var node := get_node_or_null(canvas_modulate_path)
	if node == null or not (node is CanvasModulate):
		return
	var target: Color = _color_for_phase(phase_idx)
	var tween := create_tween()
	tween.tween_property(node, "color", target, 2.0)


func _color_for_phase(idx: int) -> Color:
	match idx:
		0: return phase_color_high
		1: return phase_color_falling
		2: return phase_color_low
		_: return phase_color_rising
