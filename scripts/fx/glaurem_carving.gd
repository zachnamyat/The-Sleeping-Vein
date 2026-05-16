extends Node2D
class_name GlauremCarving

## Phase 5.33 — leaves a carved-floor decal where Glaur-em fell. The mark
## reads, in lore-faux Vesari, "thank you for the quiet" (gloss). Purely
## decorative; persists for the session.

@export var inscription: String = "—— thank you for the quiet ——"

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("glaurem_carving")
	z_index = -2
	queue_redraw()
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 28)
	shape.shape = rect
	area.add_child(shape)
	area.collision_layer = 0
	area.collision_mask = 2
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)


func _draw() -> void:
	# A tight ring of pale gold glyph-dots scribed into the floor.
	var color := Color(0.97, 0.82, 0.45, 0.55)
	for i in range(12):
		var a: float = float(i) / 12.0 * TAU
		var p: Vector2 = Vector2(cos(a), sin(a)) * 14.0
		draw_circle(p, 1.2, color)
	# Central diamond glyph.
	var corners := PackedVector2Array([
		Vector2(0, -4), Vector2(4, 0), Vector2(0, 4), Vector2(-4, 0)
	])
	draw_colored_polygon(corners, color)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit(inscription, 3.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
