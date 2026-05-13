extends Node

## Player inventory autoload. 3 rows x 10 cols default, expandable via Bag Expansions.
## Hotbar is the first row (slots 0..9). Equipment slots are tracked separately.
## See docs/reference/core-keeper-mechanics.md §2.

signal slot_changed(slot_index: int, item_id: StringName, count: int)
signal inventory_resized(new_size: int)
signal equipment_changed(slot: StringName, item_id: StringName)

const HOTBAR_SIZE: int = 10
const DEFAULT_ROWS: int = 3
const DEFAULT_COLS: int = 10

const EQUIPMENT_SLOTS: Array[StringName] = [
	&"helmet", &"chest", &"legs",
	&"off_hand", &"necklace", &"ring_1", &"ring_2",
	&"bracelet", &"belt", &"pet",
]

var slots: Array = []   ## Each entry: {"item_id": StringName, "count": int} or null
var equipment: Dictionary = {}


func _ready() -> void:
	_resize(DEFAULT_ROWS * DEFAULT_COLS)
	for s in EQUIPMENT_SLOTS:
		equipment[s] = &""


func _resize(new_count: int) -> void:
	var old: Array = slots
	slots = []
	for i in range(new_count):
		if i < old.size():
			slots.append(old[i])
		else:
			slots.append(null)
	inventory_resized.emit(new_count)


func try_add(item_id: StringName, count: int) -> bool:
	if item_id == &"" or count <= 0:
		return false
	var defn: ItemDef = ItemRegistry.get_def(item_id)
	var max_stack: int = defn.max_stack if defn else 99
	var remaining: int = count
	# First pass: fill existing stacks
	for i in range(slots.size()):
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
		slot_changed.emit(i, item_id, int(s["count"]))
		if remaining <= 0:
			EventBus.inventory_changed.emit()
			return true
	# Second pass: fill empty slots
	for i in range(slots.size()):
		if slots[i] != null:
			continue
		var added: int = mini(max_stack, remaining)
		slots[i] = {"item_id": item_id, "count": added}
		remaining -= added
		slot_changed.emit(i, item_id, added)
		if remaining <= 0:
			EventBus.inventory_changed.emit()
			return true
	EventBus.inventory_changed.emit()
	return remaining <= 0


func try_remove(item_id: StringName, count: int) -> int:
	var removed: int = 0
	for i in range(slots.size()):
		var s = slots[i]
		if s == null or StringName(s["item_id"]) != item_id:
			continue
		var take: int = mini(int(s["count"]), count - removed)
		s["count"] = int(s["count"]) - take
		removed += take
		if s["count"] <= 0:
			slots[i] = null
			slot_changed.emit(i, &"", 0)
		else:
			slot_changed.emit(i, item_id, int(s["count"]))
		if removed >= count:
			break
	if removed > 0:
		EventBus.inventory_changed.emit()
	return removed


func count_of(item_id: StringName) -> int:
	var total: int = 0
	for s in slots:
		if s != null and StringName(s["item_id"]) == item_id:
			total += int(s["count"])
	return total


func swap(a: int, b: int) -> void:
	if a < 0 or b < 0 or a >= slots.size() or b >= slots.size() or a == b:
		return
	var tmp = slots[a]
	slots[a] = slots[b]
	slots[b] = tmp
	var an: StringName = StringName(slots[a]["item_id"]) if slots[a] != null else &""
	var bn: StringName = StringName(slots[b]["item_id"]) if slots[b] != null else &""
	slot_changed.emit(a, an, int(slots[a]["count"]) if slots[a] else 0)
	slot_changed.emit(b, bn, int(slots[b]["count"]) if slots[b] else 0)
	EventBus.inventory_changed.emit()


func get_slot(idx: int) -> Dictionary:
	if idx < 0 or idx >= slots.size() or slots[idx] == null:
		return {}
	return slots[idx]


func get_hotbar_item(idx: int) -> StringName:
	if idx < 0 or idx >= HOTBAR_SIZE:
		return &""
	var s = slots[idx]
	return StringName(s["item_id"]) if s != null else &""


func equip(slot: StringName, item_id: StringName) -> void:
	if not equipment.has(slot):
		return
	equipment[slot] = item_id
	equipment_changed.emit(slot, item_id)


func clear() -> void:
	for i in range(slots.size()):
		slots[i] = null
		slot_changed.emit(i, &"", 0)
	EventBus.inventory_changed.emit()
