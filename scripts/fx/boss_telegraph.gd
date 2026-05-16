extends Node2D
class_name BossTelegraph

## Phase 5.28 — boss attack telegraph. A pulsing red ring drawn around the
## boss to warn the player of an incoming slam/AOE. The visual is procedurally
## drawn; no asset needed.

@export var ring_radius_px: float = 36.0
@export var ring_color: Color = Color(1.0, 0.25, 0.25, 0.55)
@export var fill_color: Color = Color(1.0, 0.18, 0.18, 0.18)

var _t: float = 0.0
var _flash_remaining: float = 0.0
var _flash_total: float = 0.0


func _ready() -> void:
	z_index = -1
	set_process(true)
	modulate.a = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _flash_remaining > 0.0:
		_flash_remaining -= delta
		var k: float = _flash_remaining / max(_flash_total, 0.001)
		# Quick rise then slow fade. The peak alpha lands ~85% in.
		var rise: float = clampf((1.0 - k) * 6.0, 0.0, 1.0)
		modulate.a = lerp(0.0, 1.0, min(rise, k * 1.2))
		queue_redraw()
		if _flash_remaining <= 0.0:
			modulate.a = 0.0
			visible = false


func flash(duration: float = 0.7) -> void:
	visible = true
	_flash_total = duration
	_flash_remaining = duration


func _draw() -> void:
	var pulse: float = 0.92 + 0.08 * sin(_t * 9.0)
	draw_circle(Vector2.ZERO, ring_radius_px * pulse, fill_color)
	draw_arc(Vector2.ZERO, ring_radius_px * pulse, 0.0, TAU, 48, ring_color, 1.5, true)
