extends Node2D
class_name AoeIndicator

## Phase 2.30 / 6.48 — telegraphed ring drawn on the floor before a slam-style
## AoE resolves. Spawned by AoeIndicatorSpawner in response to
## EventBus.aoe_indicator_requested.

var radius: float = 32.0
var duration: float = 0.6
var color: Color = Color(1.0, 0.3, 0.3, 0.55)
var _t: float = 0.0


func _ready() -> void:
	z_index = -1   # below mobs / players
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p: float = clampf(_t / duration, 0.0, 1.0)
	# Outer ring fades from translucent to opaque, then snaps off when done.
	var ring_color: Color = color
	ring_color.a = lerp(color.a * 0.25, color.a, p)
	# Filled disc behind a thin ring outline.
	draw_circle(Vector2.ZERO, radius, ring_color)
	# Bright outline for the final 30% so the player gets a "fire now" cue.
	if p > 0.7:
		var outline := color
		outline.a = clampf((p - 0.7) / 0.3, 0.0, 1.0)
		_draw_ring_outline(radius + 1.0, 1.5, outline)


func _draw_ring_outline(r: float, width: float, c: Color) -> void:
	var pts := PackedVector2Array()
	var segments: int = 36
	for i in range(segments + 1):
		var a: float = float(i) / float(segments) * TAU
		pts.append(Vector2(cos(a), sin(a)) * r)
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], c, width)
