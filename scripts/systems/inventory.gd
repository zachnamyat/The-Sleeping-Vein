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
	&"helmet", &"chest", &"legs", &"boots",
	&"off_hand", &"necklace", &"ring_1", &"ring_2",
	&"bracelet", &"belt", &"pet",
]

var slots: Array = []   ## Each entry: {"item_id": StringName, "count": int} or null
var equipment: Dictionary = {}

## Phase 3.29 — reforge affixes applied to equipped items. equipped_affixes[slot]
## holds the per-slot bonus dictionary (mirrored from the inventory slot's
## "affix" key when the item was equipped). Cleared on unequip.
var equipped_affixes: Dictionary = {}

## Phase 3.43 — locked slot indices won't be sorted, dropped, trashed, or
## quick-stacked. Toggle via Inventory.toggle_lock(idx).
var locked_slots: Dictionary = {}

## Phase 3.66 — monotonic counter assigned every try_add so we can sort by
## "most recently acquired". Slot index -> int sequence number.
var _acquired_seq: Dictionary = {}
var _acquired_counter: int = 0

## Phase 3.15 — most recent chest the player interacted with. ChestPanel sets
## this on open. Auto-deposit + Quick Stack target this when present.
var last_used_container: Node = null

## Phase 3.27 — Bag-in-bag UX. A `Bag` consumable item, when right-clicked
## (or kept in the bracelet slot), exposes 6 extra slots accessible without
## closing the inventory. Each bag has its own contents.
const BAG_SLOTS_PER_BAG: int = 6
var open_bag_index: int = -1  ## inventory slot index of the bag currently open, or -1
var bag_contents: Dictionary = {}  ## { inv_slot_index -> Array of {item_id, count} }


## Phase 3.27 — open or close a bag stored at inventory slot index `idx`.
## Returns whether the bag is now open.
func toggle_bag_open(idx: int) -> bool:
	if open_bag_index == idx:
		open_bag_index = -1
		return false
	open_bag_index = idx
	if not bag_contents.has(idx):
		bag_contents[idx] = []
	return true


func bag_slot_contents(bag_inv_index: int) -> Array:
	if not bag_contents.has(bag_inv_index):
		bag_contents[bag_inv_index] = []
	return bag_contents[bag_inv_index]


func bag_try_add(bag_inv_index: int, item_id: StringName, count: int = 1) -> bool:
	var bag := bag_slot_contents(bag_inv_index)
	# Try stacking onto existing entries first.
	var defn: ItemDef = ItemRegistry.get_def(item_id)
	var max_stack: int = defn.max_stack if defn else 99
	var remaining: int = count
	for entry in bag:
		if StringName(entry.get("item_id", "")) == item_id:
			var space: int = max_stack - int(entry.get("count", 0))
			var add: int = mini(space, remaining)
			entry["count"] = int(entry["count"]) + add
			remaining -= add
			if remaining <= 0:
				return true
	if bag.size() >= BAG_SLOTS_PER_BAG:
		return remaining == 0
	bag.append({ "item_id": String(item_id), "count": remaining })
	return true


func bag_try_remove(bag_inv_index: int, slot_in_bag: int) -> Dictionary:
	var bag := bag_slot_contents(bag_inv_index)
	if slot_in_bag < 0 or slot_in_bag >= bag.size():
		return {}
	var out: Dictionary = bag[slot_in_bag]
	bag.remove_at(slot_in_bag)
	return out


func _ready() -> void:
	_resize(DEFAULT_ROWS * DEFAULT_COLS)
	for s in EQUIPMENT_SLOTS:
		equipment[s] = &""


## Phase 3.43 — toggle a locked slot. Returns the new locked state.
func toggle_lock(idx: int) -> bool:
	if idx < 0 or idx >= slots.size():
		return false
	var new_state: bool = not bool(locked_slots.get(idx, false))
	if new_state:
		locked_slots[idx] = true
	else:
		locked_slots.erase(idx)
	slot_changed.emit(idx,
		StringName(slots[idx].get("item_id", "")) if slots[idx] != null else &"",
		int(slots[idx].get("count", 0)) if slots[idx] != null else 0,
	)
	return new_state


func is_locked(idx: int) -> bool:
	return bool(locked_slots.get(idx, false))


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
		_acquired_counter += 1
		_acquired_seq[i] = _acquired_counter
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
	# Phase 3.43 — locked slots refuse swap. Either party locked = no-op.
	if is_locked(a) or is_locked(b):
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


## Phase 3.4 — Move an item from an inventory slot to an equipment slot.
## Validates that the item's `equipment_slot` matches the target.
## Returns true if the equip happened. The inventory slot is cleared on success.
func equip_from_slot(inv_index: int, target_slot: StringName) -> bool:
	if inv_index < 0 or inv_index >= slots.size():
		return false
	var entry = slots[inv_index]
	if entry == null:
		return false
	var item_id := StringName(entry.get("item_id", ""))
	if item_id == &"":
		return false
	var defn: ItemDef = ItemRegistry.get_def(item_id)
	if defn == null or defn.equipment_slot == &"":
		return false
	if defn.equipment_slot != target_slot:
		return false
	# Swap with whatever's already in the slot (back into the inventory slot).
	var previous: StringName = StringName(equipment.get(target_slot, &""))
	var previous_affix: Dictionary = equipped_affixes.get(target_slot, {})
	var new_affix: Dictionary = (entry.get("affix", {}) as Dictionary).duplicate(true)
	equip(target_slot, item_id)
	if new_affix.is_empty():
		equipped_affixes.erase(target_slot)
	else:
		equipped_affixes[target_slot] = new_affix
	if previous != &"":
		var restored: Dictionary = {"item_id": previous, "count": 1}
		if not previous_affix.is_empty():
			restored["affix"] = previous_affix
		slots[inv_index] = restored
		slot_changed.emit(inv_index, previous, 1)
	else:
		slots[inv_index] = null
		slot_changed.emit(inv_index, &"", 0)
	EventBus.inventory_changed.emit()
	return true


## Phase 3.4 — Take an equipped item back to inventory (or swap into a target slot).
## If target_inv_index >= 0, swap-place at that slot.
func unequip(slot: StringName, target_inv_index: int = -1) -> bool:
	var equipped: StringName = StringName(equipment.get(slot, &""))
	if equipped == &"":
		return false
	var equipped_affix: Dictionary = (equipped_affixes.get(slot, {}) as Dictionary).duplicate(true)
	if target_inv_index >= 0 and target_inv_index < slots.size():
		var existing = slots[target_inv_index]
		if existing == null:
			var restored: Dictionary = {"item_id": equipped, "count": 1}
			if not equipped_affix.is_empty():
				restored["affix"] = equipped_affix
			slots[target_inv_index] = restored
			slot_changed.emit(target_inv_index, equipped, 1)
			equip(slot, &"")
			equipped_affixes.erase(slot)
		else:
			# Swap: if the existing item fits this slot, equip it; otherwise abort.
			var existing_id := StringName(existing.get("item_id", ""))
			var ex_defn: ItemDef = ItemRegistry.get_def(existing_id)
			if ex_defn != null and ex_defn.equipment_slot == slot:
				var existing_affix: Dictionary = (existing.get("affix", {}) as Dictionary).duplicate(true)
				equip(slot, existing_id)
				if existing_affix.is_empty():
					equipped_affixes.erase(slot)
				else:
					equipped_affixes[slot] = existing_affix
				var restored2: Dictionary = {"item_id": equipped, "count": 1}
				if not equipped_affix.is_empty():
					restored2["affix"] = equipped_affix
				slots[target_inv_index] = restored2
				slot_changed.emit(target_inv_index, equipped, 1)
			else:
				return false
		EventBus.inventory_changed.emit()
		return true
	# No target index — drop into the first free inventory slot.
	if not try_add(equipped, 1):
		return false
	equip(slot, &"")
	equipped_affixes.erase(slot)
	return true


## Phase 3.35 — Stack split. Move `take_count` units of the source slot into a
## target slot if compatible. Returns true on success. Used by shift-click
## drag-drop in InventorySlotUI.
func split_stack(source_index: int, target_index: int, take_count: int) -> bool:
	if source_index == target_index:
		return false
	if source_index < 0 or source_index >= slots.size():
		return false
	if target_index < 0 or target_index >= slots.size():
		return false
	var src = slots[source_index]
	if src == null:
		return false
	var available: int = int(src.get("count", 0))
	if take_count <= 0 or take_count >= available:
		return false  # use swap() for "take all"; split is for fractional moves
	var src_id := StringName(src.get("item_id", ""))
	var dst = slots[target_index]
	if dst == null:
		slots[target_index] = {"item_id": src_id, "count": take_count}
		src["count"] = available - take_count
		slot_changed.emit(source_index, src_id, int(src["count"]))
		slot_changed.emit(target_index, src_id, take_count)
		EventBus.inventory_changed.emit()
		return true
	if StringName(dst["item_id"]) != src_id:
		return false  # can't split onto a different item; user should swap instead
	var defn: ItemDef = ItemRegistry.get_def(src_id)
	var max_stack: int = defn.max_stack if defn else 99
	var space: int = max_stack - int(dst["count"])
	var moved: int = mini(space, take_count)
	if moved <= 0:
		return false
	dst["count"] = int(dst["count"]) + moved
	src["count"] = available - moved
	if int(src["count"]) <= 0:
		slots[source_index] = null
		slot_changed.emit(source_index, &"", 0)
	else:
		slot_changed.emit(source_index, src_id, int(src["count"]))
	slot_changed.emit(target_index, src_id, int(dst["count"]))
	EventBus.inventory_changed.emit()
	return true


## Phase 3.25 — Drop / trash. Removes a count from a specific slot index. The
## item entity creation is the caller's responsibility (drag-to-ground spawns
## an ItemDrop; trash slot deletes outright).
## Phase 3.43 — locked slots refuse drops via this path.
func drop_from_slot(slot_index: int, count: int = -1) -> Dictionary:
	if slot_index < 0 or slot_index >= slots.size():
		return {}
	if is_locked(slot_index):
		return {}
	var s = slots[slot_index]
	if s == null:
		return {}
	var have: int = int(s.get("count", 0))
	var item_id := StringName(s.get("item_id", ""))
	var taken: int = have if count < 0 else mini(have, count)
	if taken <= 0:
		return {}
	if taken >= have:
		slots[slot_index] = null
		_acquired_seq.erase(slot_index)
		slot_changed.emit(slot_index, &"", 0)
	else:
		s["count"] = have - taken
		slot_changed.emit(slot_index, item_id, int(s["count"]))
	EventBus.inventory_changed.emit()
	return {"item_id": item_id, "count": taken}


## Phase 3.33 — for every armor piece in the bag, equip the highest-armor one
## of each slot type. Returns the number of pieces equipped.
func auto_equip_best() -> int:
	var equipped_count: int = 0
	# Group by slot.
	var by_slot: Dictionary = {}
	for i in range(slots.size()):
		var s = slots[i]
		if s == null:
			continue
		var iid := StringName(s.get("item_id", ""))
		var defn: ItemDef = ItemRegistry.get_def(iid)
		if defn == null or defn.equipment_slot == &"":
			continue
		var slot_id: StringName = defn.equipment_slot
		var current_best = by_slot.get(slot_id, null)
		if current_best == null or defn.armor_value > current_best.armor:
			by_slot[slot_id] = {"index": i, "armor": defn.armor_value, "id": iid}
	for slot_id in by_slot.keys():
		var pick = by_slot[slot_id]
		# If something better is already equipped, skip.
		var equipped: StringName = StringName(equipment.get(slot_id, &""))
		if equipped != &"":
			var ed: ItemDef = ItemRegistry.get_def(equipped)
			if ed != null and ed.armor_value >= pick.armor:
				continue
		if equip_from_slot(int(pick.index), slot_id):
			equipped_count += 1
	return equipped_count


## Phase 3.66 — sort by acquisition recency (latest first), preserving hotbar.
func sort_storage_recency() -> void:
	var start: int = HOTBAR_SIZE
	if start >= slots.size():
		return
	var bag := []
	for i in range(start, slots.size()):
		var s = slots[i]
		if s == null:
			continue
		bag.append({"slot": s, "seq": int(_acquired_seq.get(i, 0))})
	bag.sort_custom(func(a, b) -> bool: return a.seq > b.seq)
	var write := start
	var new_seq: Dictionary = {}
	# Preserve hotbar acquisition seq.
	for i in range(start):
		if _acquired_seq.has(i):
			new_seq[i] = _acquired_seq[i]
	for entry in bag:
		slots[write] = entry.slot
		new_seq[write] = entry.seq
		var iid := StringName(entry.slot["item_id"])
		slot_changed.emit(write, iid, int(entry.slot["count"]))
		write += 1
	while write < slots.size():
		slots[write] = null
		slot_changed.emit(write, &"", 0)
		write += 1
	_acquired_seq = new_seq
	EventBus.inventory_changed.emit()


## Phase 3.26 / 3.45 — Sort the inventory using a comparison criterion. The
## hotbar row (0..9) is NOT touched (preserve player's selected layout).
## Phase 3.43 — locked slots stay in place (skipped from the sort pool).
## Criteria: "rarity" (high→low), "name" (A→Z), "type" (groups by item_type).
func sort_storage(criterion: String = "rarity") -> void:
	var start: int = HOTBAR_SIZE  # leave hotbar alone
	if start >= slots.size():
		return
	var bag := []
	var fixed: Dictionary = {}  # locked positions to preserve
	for i in range(start, slots.size()):
		if is_locked(i):
			fixed[i] = slots[i]
			continue
		var s = slots[i]
		if s != null:
			bag.append(s)
	bag.sort_custom(func(a, b) -> bool: return _compare_for_sort(a, b, criterion))
	var write := start
	for entry in bag:
		# Skip over any locked slot positions while writing.
		while fixed.has(write):
			write += 1
		if write >= slots.size():
			break
		slots[write] = entry
		var iid := StringName(entry["item_id"])
		slot_changed.emit(write, iid, int(entry["count"]))
		write += 1
	while write < slots.size():
		if fixed.has(write):
			write += 1
			continue
		slots[write] = null
		slot_changed.emit(write, &"", 0)
		write += 1
	EventBus.inventory_changed.emit()


func _compare_for_sort(a: Dictionary, b: Dictionary, criterion: String) -> bool:
	var ad: ItemDef = ItemRegistry.get_def(StringName(a.get("item_id", "")))
	var bd: ItemDef = ItemRegistry.get_def(StringName(b.get("item_id", "")))
	if ad == null or bd == null:
		return ad != null  # known defs first
	match criterion:
		"rarity":
			if ad.rarity != bd.rarity:
				return ad.rarity > bd.rarity
			return ad.display_name < bd.display_name
		"type":
			if ad.item_type != bd.item_type:
				return ad.item_type < bd.item_type
			return ad.display_name < bd.display_name
		_:  # "name"
			return ad.display_name < bd.display_name


func clear() -> void:
	for i in range(slots.size()):
		slots[i] = null
		slot_changed.emit(i, &"", 0)
	EventBus.inventory_changed.emit()
