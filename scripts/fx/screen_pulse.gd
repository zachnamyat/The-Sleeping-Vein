extends CanvasLayer
class_name ScreenPulse

## Phase 1 ticket 1.40 — subtle whole-screen flash synced to the Aphelion Beat.
## A full-viewport ColorRect briefly modulates alpha 0 → peak → 0 on each beat.
## Layer set above gameplay (90) but below HUD (100) so HUD remains legible.

const BEAT_PEAK_ALPHA: float = 0.07
const BEAT_DURATION: float = 0.65

var _rect: ColorRect


func _ready() -> void:
	layer = 90
	_rect = ColorRect.new()
	_rect.color = Color(0.95, 0.85, 0.55, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.anchor_left = 0.0
	_rect.anchor_top = 0.0
	_rect.anchor_right = 1.0
	_rect.anchor_bottom = 1.0
	add_child(_rect)
	AudioBus.aphelion_beat.connect(_on_beat)
	EventBus.screen_pulse_requested.connect(_on_pulse_requested)


func _on_beat() -> void:
	_pulse(BEAT_PEAK_ALPHA, BEAT_DURATION)


func _on_pulse_requested(strength: float, duration: float) -> void:
	_pulse(clamp(strength, 0.0, 1.0), max(duration, 0.05))


func _pulse(peak_alpha: float, duration: float) -> void:
	if _rect == null:
		return
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", peak_alpha, duration * 0.3)
	tween.tween_property(_rect, "color:a", 0.0, duration * 0.7)
