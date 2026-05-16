extends Area2D
class_name Mural

## Phase 5.35 — pre-fight mural placeable. Decorative wall art; on player
## proximity it surfaces a flavor line about the depicted Sovereign.

@export var mural_text: String = "The Stone-Father slept. Then he could not stop growing."

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("mural")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 2


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit(mural_text, 4.0)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
