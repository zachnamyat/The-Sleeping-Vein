extends Area2D
class_name Chest

## Placeable storage container. Holds 18 item slots (3x6). Player interacts to
## open the chest UI. Contents persist via SaveSystem.dump_world_chests() /
## restore_world_chests() — see scripts/autoloads/save_system.gd.
##
## Each chest registers itself with the `chest` group at _ready so the
## SaveSystem can iterate without scene-specific paths.

signal opened(chest: Chest)
signal closed
## Fires whenever slots change (deposit/withdraw/restore). ChestPanel subscribes
## to the *active* chest's signal so any path that mutates contents — drag-drop,
## quick-stack, programmatic, save-restore — refreshes the open UI without
## needing each call site to remember to ping it manually.
signal contents_changed

const SLOT_COUNT: int = 18

@export var unique_id: StringName = &""
## Persisted contents. Same format as Inventory: {"item_id", "count"} or null.
var slots: Array = []

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("chest")
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
			contents_changed.emit()
			return count
	for i in range(SLOT_COUNT):
		if slots[i] != null:
			continue
		var added: int = mini(max_stack, remaining)
		slots[i] = { "item_id": item_id, "count": added }
		remaining -= added
		if remaining <= 0:
			break
	if count - remaining > 0:
		contents_changed.emit()
	return count - remaining


## Phase 3.6 — take an item out of a specific chest slot into the player
## inventory. Returns the amount actually moved.
func withdraw_slot(index: int, count: int = -1) -> int:
	if index < 0 or index >= SLOT_COUNT:
		return 0
	var s = slots[index]
	if s == null:
		return 0
	var have: int = int(s.get("count", 0))
	var iid := StringName(s.get("item_id", ""))
	var take: int = have if count < 0 else mini(have, count)
	if take <= 0:
		return 0
	# Only move what the inventory can actually accept.
	var before: int = Inventory.count_of(iid)
	Inventory.try_add(iid, take)
	var after: int = Inventory.count_of(iid)
	var moved: int = after - before
	if moved <= 0:
		return 0
	s["count"] = have - moved
	if int(s["count"]) <= 0:
		slots[index] = null
	contents_changed.emit()
	return moved


func dump_state() -> Dictionary:
	var serialised: Array = []
	for s in slots:
		if s == null:
			serialised.append(null)
		else:
			serialised.append({
				"item_id": String(s["item_id"]),
				"count": int(s["count"]),
			})
	return {
		"unique_id": String(unique_id),
		"position_x": global_position.x,
		"position_y": global_position.y,
		"slots": serialised,
	}


func restore_state(data: Dictionary) -> void:
	unique_id = StringName(String(data.get("unique_id", String(unique_id))))
	if data.has("position_x") and data.has("position_y"):
		global_position = Vector2(
			float(data["position_x"]),
			float(data["position_y"]),
		)
	var saved: Array = data.get("slots", [])
	for i in range(SLOT_COUNT):
		if i >= saved.size():
			slots[i] = null
			continue
		var entry = saved[i]
		if entry == null:
			slots[i] = null
		else:
			slots[i] = {
				"item_id": StringName(String(entry.get("item_id", ""))),
				"count": int(entry.get("count", 0)),
			}


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] Open chest", 1.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		closed.emit()
		get_tree().call_group("chest_ui", "close_if_for_chest", self)
