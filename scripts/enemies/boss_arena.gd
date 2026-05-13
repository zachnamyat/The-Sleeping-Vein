extends Node2D
class_name BossArena

## A procedural rune-circle marker painted under each boss. Phase 5 MVP: a faint
## translucent gold ring + four cardinal glyph dots. Phase 15 polish replaces
## with Gemini-generated arena tile decals.

@export var radius_tiles: int = 6
@export var ring_color: Color = Color(0.86, 0.68, 0.34, 0.55)
@export var glyph_color: Color = Color(1.0, 0.92, 0.55, 0.85)

const TILE_PX: int = 16


func _ready() -> void:
	z_index = -1
	queue_redraw()


func _draw() -> void:
	var r: float = float(radius_tiles * TILE_PX)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, ring_color, 2.0, true)
	draw_arc(Vector2.ZERO, r * 0.88, 0.0, TAU, 64, ring_color * Color(1, 1, 1, 0.5), 1.0, true)
	for i in range(8):
		var a: float = float(i) / 8.0 * TAU
		var p: Vector2 = Vector2(cos(a), sin(a)) * r
		draw_circle(p, 3.0, glyph_color)
	for i in range(4):
		var a: float = float(i) / 4.0 * TAU
		var p: Vector2 = Vector2(cos(a), sin(a)) * (r * 0.5)
		draw_circle(p, 2.0, glyph_color)
