extends Area2D
class_name Painting

## Phase 9.13 — placed painting/canvas. Like a sign but shows the text via a
## proximity toast instead of E-to-read.

@export var caption: String = "An unsigned painting."

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("painting")
	add_to_group("placed_decor")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit(caption, 3.0)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func dump_state() -> Dictionary:
	return { "caption": caption }


func restore_state(d: Dictionary) -> void:
	caption = String(d.get("caption", caption))
