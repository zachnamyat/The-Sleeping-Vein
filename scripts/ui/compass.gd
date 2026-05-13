extends Control
class_name CompassToLoom

## Phase 4.11 — a tiny on-screen arrow pointing from the player toward the
## Resonance Loom (world origin). The HUD shows it permanently in the top-right
## under the slivers readout.

@export var radius_pixels: float = 16.0
@export var arrow_color: Color = Color(0.95, 0.84, 0.5, 0.85)
@export var distance_label: Label

var _player: Node2D
var _angle: float = 0.0
var _distance_tiles: int = 0


func _ready() -> void:
	add_to_group("compass")
	custom_minimum_size = Vector2(radius_pixels * 2 + 4, radius_pixels * 2 + 4)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("player")
		if players.is_empty():
			return
		_player = players[0]
	# Loom is at world origin (0,0).
	var to_loom: Vector2 = Vector2.ZERO - _player.global_position
	_angle = to_loom.angle()
	_distance_tiles = int(to_loom.length() / 16.0)
	queue_redraw()
	if distance_label:
		distance_label.text = "%d tiles to Loom" % _distance_tiles


func _draw() -> void:
	var center: Vector2 = Vector2(radius_pixels + 2, radius_pixels + 2)
	draw_arc(center, radius_pixels, 0.0, TAU, 32, arrow_color, 1.0, true)
	var tip: Vector2 = center + Vector2(cos(_angle), sin(_angle)) * (radius_pixels - 2)
	var perp: Vector2 = Vector2(-sin(_angle), cos(_angle))
	var base_a: Vector2 = center + Vector2(cos(_angle + PI), sin(_angle + PI)) * 4.0 + perp * 3.0
	var base_b: Vector2 = center + Vector2(cos(_angle + PI), sin(_angle + PI)) * 4.0 - perp * 3.0
	draw_polygon(PackedVector2Array([tip, base_a, base_b]), PackedColorArray([arrow_color, arrow_color, arrow_color]))
