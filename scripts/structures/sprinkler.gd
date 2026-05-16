extends Node2D
class_name Sprinkler

## Phase 8.13 — Sprinkler. Pulses water to every TilledSoil tile within
## `radius` every `pulse_every_beats` Aphelion Beats. Free; no fuel cost.

@export var radius: float = 32.0
@export var pulse_every_beats: int = 2

var _beats: int = 0


func _ready() -> void:
	add_to_group("sprinkler")
	if AudioBus:
		AudioBus.aphelion_beat.connect(_on_beat)


func _on_beat() -> void:
	_beats += 1
	if _beats < pulse_every_beats:
		return
	_beats = 0
	if FarmingSystem:
		FarmingSystem.sprinkler_pulse(global_position, radius)
	if AudioBus:
		AudioBus.play_sfx(&"sprinkler", global_position)
