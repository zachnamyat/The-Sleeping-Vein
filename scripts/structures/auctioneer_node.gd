extends Area2D
class_name AuctioneerNode

## Phase 14.30 — Auctioneer / mailbox economy node. Interact (E) opens the
## Auctioneer UI: tabs for "Sell" (list an item with a price) and "Browse" (buy
## from other peers' listings). Listings persist across sessions because they
## live in Phase14Helpers.

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("auctioneer")
	add_to_group("demolishable")
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
	var panels := get_tree().get_nodes_in_group("auctioneer_ui") if get_tree() else []
	if panels.is_empty():
		EventBus.ui_toast.emit("Auctioneer ledger empty. (Open UI not in scene.)", 2.0)
		return
	for p in panels:
		if p.has_method("open"):
			p.call("open")
			return


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] Auctioneer", 1.2)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func get_refund_meta() -> Dictionary:
	return { "item_id": "auctioneer_node_placeable", "count": 1 }
