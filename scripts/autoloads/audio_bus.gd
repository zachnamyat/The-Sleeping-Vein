extends Node

## Audio routing autoload. Centralizes SFX / Music / Ambient bus control,
## the Aphelion-Beat cadence (~23s per Lore §1.2), and emits a beat signal
## that gameplay systems can synchronize to.

signal aphelion_beat

const APHELION_BEAT_PERIOD_SECONDS: float = 23.0

var _beat_timer: Timer


var _phase_index: int = 0


func _ready() -> void:
	_beat_timer = Timer.new()
	_beat_timer.wait_time = APHELION_BEAT_PERIOD_SECONDS
	_beat_timer.one_shot = false
	_beat_timer.autostart = true
	_beat_timer.timeout.connect(_emit_beat)
	add_child(_beat_timer)


func _emit_beat() -> void:
	_phase_index = (_phase_index + 1) % 4
	aphelion_beat.emit()


func current_phase() -> int:
	return _phase_index


func is_day() -> bool:
	# Phases 0..1 = day, 2..3 = night. Used by Salt Wastes day/night temp swing.
	return _phase_index < 2


func play_sfx(_sound_id: StringName, _at_position: Vector2 = Vector2.ZERO) -> void:
	# Phase 1 stub. Real impl will pool AudioStreamPlayer2Ds and respect bus volumes.
	pass


func play_music(_track_id: StringName, _fade_seconds: float = 2.0) -> void:
	# Phase 1 stub.
	pass


func play_ambient(_track_id: StringName) -> void:
	# Phase 1 stub.
	pass
