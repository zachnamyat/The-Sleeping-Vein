extends Area2D
class_name Chest

## Placeable storage container. Holds 18 item slots (3x6). Player interacts to
## open the chest UI. Contents persist via SaveSystem in Phase 4+.

signal opened(chest: Chest)
signal closed

const SLOT_COUNT: int = 18

@export var unique_id: StringName = &""
var slots: Array = []  ## same format as Inventory: {"item_id", "count"} or null

var _player_in_range: bool = false


func _ready() -> void:
	for i in range(SLOT_COUNT):
		slots.append(null)
	if unique_id == &"":
		unique_id = StringName("chest_%d" % get_instance_id())
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 2
	set_collision_mask_value(2, true)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("interact"):
		opened.emit(self)
		get_tree().call_group("chest_ui", "open_for_chest", self)


func deposit(item_id: StringName, count: int) -> int:
	if item_id == &"" or count <= 0:
		return 0
	var defn: ItemDef = ItemRegistry.get_def(item_id)
	var max_stack: int = defn.max_stack if defn else 99
	var remaining: int = count
	for i in range(SLOT_COUNT):
		var s = slots[i]
		if s == null:
			continue
		if StringName(s["item_id"]) != item_id:
			continue
		var space: int = max_stack - int(s["count"])
		if space <= 0:
			continue
		var added: int = mini(space, remaining)
		s["count"] = int(s["count"]) + added
		remaining -= added
		if remaining <= 0:
			return count
	for i in range(SLOT_COUNT):
		if slots[i] != null:
			continue
		var added: int = mini(max_stack, remaining)
		slots[i] = { "item_id": item_id, "count": added }
		remaining -= added
		if remaining <= 0:
			break
	return count - remaining


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] Open chest", 1.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		closed.emit()
		get_tree().call_group("chest_ui", "close_if_for_chest", self)
