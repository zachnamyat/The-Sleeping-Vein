extends Area2D
class_name Aquarium

## Phase 8.14 — A passive display tank. Holds up to 4 fish from the player's
## inventory. Stand next to it and press E with a fish in hand to add it; press
## E again with nothing held to view contents (toast).

@export var capacity: int = 4

var fish_inside: Array = []   # Array[StringName]
var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("aquarium")
	monitorable = false
	monitoring = true
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] Aquarium (%d/%d)" % [fish_inside.size(), capacity], 1.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if not event.is_action_pressed("interact"):
		return
	var hotbar := get_tree().get_first_node_in_group("hotbar") as Hotbar
	if hotbar == null:
		return
	var iid: StringName = Inventory.get_hotbar_item(hotbar.selected_index)
	var defn: ItemDef = ItemRegistry.get_def(iid) if iid != &"" else null
	if defn and _is_displayable_fish(iid):
		_add_fish(iid)
		return
	if fish_inside.is_empty():
		EventBus.ui_toast.emit("Aquarium empty.", 1.5)
		return
	var names: Array = []
	for f in fish_inside:
		var d: ItemDef = ItemRegistry.get_def(StringName(f))
		names.append(d.display_name if d else String(f))
	EventBus.ui_toast.emit("Aquarium: %s" % ", ".join(names), 3.0)


func _is_displayable_fish(item_id: StringName) -> bool:
	const FISH := [
		&"cave_guppy", &"lantern_glint", &"salt_minnow",
		&"root_bream", &"glow_eel", &"tide_perch", &"glass_pike",
		&"vesari_eel", &"deep_pike", &"drowned_pearl",
	]
	return item_id in FISH


func _add_fish(iid: StringName) -> void:
	if fish_inside.size() >= capacity:
		EventBus.ui_toast.emit("Aquarium full.", 1.5)
		return
	if Inventory.try_remove(iid, 1) <= 0:
		return
	fish_inside.append(iid)
	EventBus.ui_toast.emit("Added to aquarium.", 1.5)


func dump_state() -> Dictionary:
	return { "fish_inside": fish_inside.duplicate(true) }


func restore_state(data: Dictionary) -> void:
	fish_inside = data.get("fish_inside", []).duplicate(true) as Array
