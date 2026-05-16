extends Area2D
class_name Mailbox

## Phase 9.46 — Mailbox placeable. Offline player-to-player item delivery in
## multiplayer; in singleplayer, acts as a slow stash with a single-slot inbox.

@export var inbox_item_id: StringName = &""
@export var inbox_count: int = 0
@export var sender_label: String = ""

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("mailbox")
	add_to_group("placed_decor")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("interact"):
		_collect()


func _collect() -> void:
	if inbox_item_id == &"" or inbox_count <= 0:
		EventBus.ui_toast.emit("(empty)", 1.5)
		return
	Inventory.try_add(inbox_item_id, inbox_count)
	EventBus.ui_toast.emit("Mailbox: +%d %s%s" % [inbox_count, String(inbox_item_id),
		(" from %s" % sender_label) if sender_label != "" else ""], 3.0)
	inbox_item_id = &""
	inbox_count = 0
	sender_label = ""


func deliver(item_id: StringName, count: int, sender: String = "") -> bool:
	if inbox_item_id != &"" and inbox_count > 0:
		return false
	inbox_item_id = item_id
	inbox_count = count
	sender_label = sender
	return true


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] Open Mailbox", 1.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func dump_state() -> Dictionary:
	return {
		"inbox_item_id": String(inbox_item_id),
		"inbox_count": inbox_count,
		"sender_label": sender_label,
	}


func restore_state(d: Dictionary) -> void:
	inbox_item_id = StringName(String(d.get("inbox_item_id", "")))
	inbox_count = int(d.get("inbox_count", 0))
	sender_label = String(d.get("sender_label", ""))
