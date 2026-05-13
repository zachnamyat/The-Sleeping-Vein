extends Node
class_name DayNightCycle

## The "Aphelion Beat" cycle. The world's primary timekeeping mechanism.
## Listens to AudioBus.aphelion_beat (period from AudioBus.APHELION_BEAT_PERIOD_SECONDS).
## On each beat, advances a phase counter; lighting drives off that.

signal phase_changed(phase_idx: int, phase_name: StringName)

const PHASE_NAMES: Array[StringName] = [
	&"high_light",
	&"falling",
	&"low_light",
	&"rising",
]

@export var canvas_modulate_path: NodePath
@export_color_no_alpha var phase_color_high: Color = Color(0.78, 0.72, 0.58)
@export_color_no_alpha var phase_color_falling: Color = Color(0.55, 0.50, 0.40)
@export_color_no_alpha var phase_color_low: Color = Color(0.28, 0.25, 0.20)
@export_color_no_alpha var phase_color_rising: Color = Color(0.55, 0.50, 0.40)

var phase_idx: int = 0


func _ready() -> void:
	if AudioBus:
		AudioBus.aphelion_beat.connect(_on_beat)
	_apply_phase()


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
