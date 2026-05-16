extends Area2D
class_name SignPost

## Phase 9.13 / 9.48 — Player-built sign with custom text. Interact (E) opens a
## small TextEdit popup; the text is persisted on the sign and shown as a toast
## when other players (or the same player) re-interact.

@export var sign_text: String = ""

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("sign")
	add_to_group("placed_decor")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("interact"):
		_open_panel()


func _open_panel() -> void:
	var ui_nodes := get_tree().get_nodes_in_group("sign_ui")
	if ui_nodes.is_empty():
		# Fallback: just show whatever is written.
		if sign_text == "":
			EventBus.ui_toast.emit("(an unwritten sign)", 2.0)
		else:
			EventBus.ui_toast.emit("\"%s\"" % sign_text, 4.0)
		return
	(ui_nodes[0]).call("open_for_sign", self)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] Read/Write", 1.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func dump_state() -> Dictionary:
	return { "text": sign_text }


func restore_state(d: Dictionary) -> void:
	sign_text = String(d.get("text", ""))
