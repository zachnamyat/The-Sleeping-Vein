extends Control
class_name HeatShimmer

## Phase 11.17 — Heat-shimmer screen post-process. While the player is in an
## Emberforge heat zone (Phase11Helpers.heat_zone_changed) we modulate a
## semi-transparent warm overlay and animate a subtle distortion offset.
## Lightweight: no shader required, only Color modulation + small sine offset.

@export var max_alpha: float = 0.18
@export var shimmer_amplitude_px: float = 1.0

var _enabled: bool = false
var _alpha: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = true
	z_index = 95
	if Phase11Helpers:
		Phase11Helpers.heat_zone_changed.connect(_on_heat_changed)


func _on_heat_changed(in_heat: bool) -> void:
	_enabled = in_heat


func _process(delta: float) -> void:
	# Fade in / out smoothly.
	var target: float = max_alpha if _enabled else 0.0
	_alpha = lerp(_alpha, target, clampf(delta * 1.5, 0.0, 1.0))
	_phase = fmod(_phase + delta * 4.0, TAU)
	queue_redraw()


func _draw() -> void:
	if _alpha <= 0.001:
		return
	var rect := get_viewport_rect()
	# Two stacked warm bands.
	var band_a := Color(0.95, 0.45, 0.20, _alpha * 0.6)
	var band_b := Color(0.85, 0.55, 0.25, _alpha * 0.4)
	draw_rect(Rect2(rect.position, rect.size), band_a, true)
	# Subtle ripple bands.
	var step: float = 14.0
	var y: float = 0.0
	while y < rect.size.y:
		var offset: float = sin(_phase + y * 0.05) * shimmer_amplitude_px
		draw_rect(Rect2(Vector2(offset, y), Vector2(rect.size.x, step * 0.4)), band_b, true)
		y += step
