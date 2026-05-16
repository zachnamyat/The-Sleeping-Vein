extends Area2D
class_name ResurrectionAltar

## Phase 13.24 — placeable resurrection altar. Interacting (E) opens the
## ResurrectionAltarPanel; one click reduces the targeted peer's awaiting-
## respawn timer to ~0.1s and emits player_revival_requested.
##
## Recipe lives in resources/recipes/craft_resurrection_altar.tres at the
## tier-8 Auroric Anvil; cost is 2 Aphelion Shards + 4 Diadem-Gold Plate.

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("resurrection_altar")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("interact"):
		_open_panel()


func _open_panel() -> void:
	var panels := get_tree().get_nodes_in_group("resurrection_altar_ui") if get_tree() else []
	for p in panels:
		if p.has_method("open"):
			p.call("open")
			return


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] Resurrection Altar", 1.2)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
