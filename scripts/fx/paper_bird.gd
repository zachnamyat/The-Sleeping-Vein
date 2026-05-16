extends Node2D
class_name PaperBird

## Phase 5.32 — Aelstren's paper-bird memorial. Spawns on first boss kill,
## flutters from her position toward the boss arena, then dissolves into a
## brief light-burst at the carving. Pure cinematic flavor.

@export var flight_seconds: float = 4.0
@export var start_pos: Vector2 = Vector2.ZERO
@export var target_pos: Vector2 = Vector2.ZERO

var _t: float = 0.0
var _flap_t: float = 0.0


func _ready() -> void:
	z_index = 10
	set_process(true)
	global_position = start_pos
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_flap_t += delta
	queue_redraw()
	if _t >= flight_seconds:
		_dissolve()
		return
	var k: float = clampf(_t / max(flight_seconds, 0.001), 0.0, 1.0)
	# Smooth flight along a slight arc.
	var lerp_pos: Vector2 = start_pos.lerp(target_pos, k)
	var arc_offset: float = sin(k * PI) * -24.0
	lerp_pos.y += arc_offset
	# Soft wing sway.
	lerp_pos.x += sin(_flap_t * 8.0) * 1.5
	global_position = lerp_pos


func _dissolve() -> void:
	set_process(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.finished.connect(queue_free)


func _draw() -> void:
	# A simple paper-crane silhouette: two triangles + tail.
	var color := Color(0.97, 0.85, 0.5, 0.95)
	var flap: float = sin(_flap_t * 9.0) * 4.0
	var pts := PackedVector2Array([
		Vector2(-8, flap),
		Vector2(0, -2),
		Vector2(8, flap),
		Vector2(0, 4),
	])
	draw_colored_polygon(pts, color)
	# Beak / head dot.
	draw_circle(Vector2(0, -3), 1.5, Color(1, 1, 1, 0.85))
