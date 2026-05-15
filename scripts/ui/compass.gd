extends Control
class_name CompassToLoom

## Phase 4.11 — HUD compass widget.
##   - Default mode (4.11): points to GameState.respawn_point (the bound Loom).
##   - Death mode (4.39): points to the most recent Tombstone marker.
##
## The Minimap.toggle_death_compass() flips a single flag we poll each frame.

@export var radius_pixels: float = 16.0
@export var arrow_color: Color = Color(0.95, 0.84, 0.5, 0.85)
@export var death_color: Color = Color(0.85, 0.45, 0.95, 0.95)
@export var distance_label: Label

var _player: Node2D
var _minimap: Node
var _angle: float = 0.0
var _distance_tiles: int = 0
var _color: Color = arrow_color


func _ready() -> void:
	add_to_group("compass")
	custom_minimum_size = Vector2(radius_pixels * 2 + 4, radius_pixels * 2 + 4)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("player")
		if players.is_empty():
			return
		_player = players[0]
	if _minimap == null or not is_instance_valid(_minimap):
		var maps := get_tree().get_nodes_in_group("minimap")
		_minimap = maps[0] if not maps.is_empty() else null
	var target: Vector2 = GameState.respawn_point
	var label_prefix: String = "tiles to Loom"
	_color = arrow_color
	if _minimap and bool(_minimap.get("death_compass_active")):
		var death_pos: Vector2 = _minimap.call("last_death_marker") as Vector2
		if death_pos != Vector2.ZERO:
			target = death_pos
			label_prefix = "tiles to grave"
			_color = death_color
	var to_target: Vector2 = target - _player.global_position
	_angle = to_target.angle()
	_distance_tiles = int(to_target.length() / 16.0)
	queue_redraw()
	if distance_label:
		distance_label.text = "%d %s" % [_distance_tiles, label_prefix]


func _unhandled_input(event: InputEvent) -> void:
	# Phase 4.39 — press the dedicated toggle action if available, otherwise
	# the user can flip via Minimap.toggle_death_compass() (Phase 9 UI binding).
	if event.is_action_pressed("toggle_death_compass"):
		if _minimap and _minimap.has_method("toggle_death_compass"):
			_minimap.call("toggle_death_compass")


func _draw() -> void:
	var center: Vector2 = Vector2(radius_pixels + 2, radius_pixels + 2)
	draw_arc(center, radius_pixels, 0.0, TAU, 32, _color, 1.0, true)
	var tip: Vector2 = center + Vector2(cos(_angle), sin(_angle)) * (radius_pixels - 2)
	var perp: Vector2 = Vector2(-sin(_angle), cos(_angle))
	var base_a: Vector2 = center + Vector2(cos(_angle + PI), sin(_angle + PI)) * 4.0 + perp * 3.0
	var base_b: Vector2 = center + Vector2(cos(_angle + PI), sin(_angle + PI)) * 4.0 - perp * 3.0
	draw_polygon(PackedVector2Array([tip, base_a, base_b]), PackedColorArray([_color, _color, _color]))
