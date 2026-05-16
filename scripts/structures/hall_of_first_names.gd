extends Area2D
class_name HallOfFirstNames

## Phase 12.24 — Hall of First Names tablet (single anchor in the Final
## Spiral). Reading reveals the "lamp before the lamp" line — proof that
## the Aphelion was preceded by an earlier intelligence. Surfaced only
## once the elided name is recovered (12.30), so the player has the
## context to receive it.

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("hall_of_first_names")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 2


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("interact"):
		_read()


func _read() -> void:
	if Phase12Helpers == null:
		return
	if not Phase12Helpers.elided_name_revealed:
		EventBus.ui_toast.emit("The tablet's surface ripples. You cannot read it yet.", 3.0)
		return
	if Phase12Helpers.lamp_before_lamp_revealed:
		EventBus.ui_toast.emit("\"A lamp before the lamp.\"", 3.0)
		return
	Phase12Helpers.reveal_lamp_before_lamp()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] Read the Hall of First Names", 1.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
