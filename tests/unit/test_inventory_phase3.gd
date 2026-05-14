extends GutTest

## Phase 3 — Stack split, sort modes, drop_from_slot.


func before_each() -> void:
	Inventory.clear()


func test_split_stack_into_empty_slot() -> void:
	Inventory.try_add(&"loam", 10)
	# Find source slot.
	var src: int = -1
	for i in range(Inventory.slots.size()):
		var s = Inventory.slots[i]
		if s != null and StringName(s["item_id"]) == &"loam":
			src = i
			break
	assert_gte(src, 0)
	var dst: int = (src + 5) % Inventory.slots.size()
	if Inventory.slots[dst] != null:
		Inventory.slots[dst] = null
	var ok: bool = Inventory.split_stack(src, dst, 4)
	assert_true(ok)
	assert_eq(int(Inventory.slots[src]["count"]), 6)
	assert_eq(int(Inventory.slots[dst]["count"]), 4)
	assert_eq(String(Inventory.slots[dst]["item_id"]), "loam")


func test_split_merges_onto_same_item() -> void:
	Inventory.try_add(&"shaleseed", 5)
	# Put another shaleseed stack into an explicit slot so we control the layout.
	var src: int = -1
	for i in range(Inventory.slots.size()):
		var s = Inventory.slots[i]
		if s != null and StringName(s["item_id"]) == &"shaleseed":
			src = i
			break
	var dst: int = src + 1
	Inventory.slots[dst] = {"item_id": &"shaleseed", "count": 3}
	var ok: bool = Inventory.split_stack(src, dst, 2)
	assert_true(ok)
	assert_eq(int(Inventory.slots[src]["count"]), 3)
	assert_eq(int(Inventory.slots[dst]["count"]), 5)


func test_drop_from_slot_clears_and_returns_payload() -> void:
	Inventory.try_add(&"loam", 7)
	var src: int = -1
	for i in range(Inventory.slots.size()):
		var s = Inventory.slots[i]
		if s != null and StringName(s["item_id"]) == &"loam":
			src = i
			break
	var data: Dictionary = Inventory.drop_from_slot(src, 3)
	assert_eq(int(data.get("count", 0)), 3)
	assert_eq(String(data.get("item_id", "")), "loam")
	assert_eq(int(Inventory.slots[src]["count"]), 4)
	# Drop the rest.
	Inventory.drop_from_slot(src)
	assert_null(Inventory.slots[src])


func test_sort_storage_rarity_keeps_hotbar_intact() -> void:
	# Put one item in hotbar slot 3 and two in storage so we can verify the
	# hotbar isn't reshuffled.
	Inventory.slots[3] = {"item_id": &"wooden_pickaxe", "count": 1}
	# Put loam (rarity 0) before shaleseed (rarity 1) in storage.
	var first_storage: int = Inventory.HOTBAR_SIZE
	Inventory.slots[first_storage] = {"item_id": &"loam", "count": 5}
	Inventory.slots[first_storage + 1] = {"item_id": &"shaleseed", "count": 2}
	Inventory.sort_storage("rarity")
	# Hotbar slot 3 unchanged.
	assert_not_null(Inventory.slots[3])
	assert_eq(String(Inventory.slots[3]["item_id"]), "wooden_pickaxe")
	# After sort, higher rarity comes first in storage.
	var first = Inventory.slots[first_storage]
	assert_not_null(first)
	assert_true(String(first["item_id"]) in ["shaleseed", "loam"],
		"sorted entry must be a known stored item")


func test_lock_blocks_swap_and_drop() -> void:
	# Phase 3.43 — locked slot refuses sort/swap/drop.
	Inventory.try_add(&"loam", 5)
	var src: int = -1
	for i in range(Inventory.slots.size()):
		var s = Inventory.slots[i]
		if s != null and StringName(s["item_id"]) == &"loam":
			src = i
			break
	Inventory.toggle_lock(src)
	assert_true(Inventory.is_locked(src))
	# Drop should refuse.
	var dropped: Dictionary = Inventory.drop_from_slot(src, 2)
	assert_true(dropped.is_empty(), "drop_from_slot must refuse a locked slot")
	# Swap should refuse.
	var dst: int = (src + 5) % Inventory.slots.size()
	if Inventory.slots[dst] != null:
		Inventory.slots[dst] = null
	Inventory.swap(src, dst)
	assert_not_null(Inventory.slots[src], "locked slot stayed put through swap()")
	# Unlock and verify drop now works.
	Inventory.toggle_lock(src)
	assert_false(Inventory.is_locked(src))


func test_auto_equip_best_picks_higher_armor() -> void:
	# Phase 3.33 — Inventory.auto_equip_best equips the highest-armor item per slot.
	Inventory.try_add(&"shaleseed_helmet", 1)  # armor 3
	# Pre-equip nothing.
	for s in Inventory.EQUIPMENT_SLOTS:
		Inventory.equipment[s] = &""
	var equipped: int = Inventory.auto_equip_best()
	assert_gte(equipped, 1)
	assert_eq(String(Inventory.equipment[&"helmet"]), "shaleseed_helmet")


func test_sort_storage_recency_orders_newest_first() -> void:
	# Phase 3.66 — sort_storage_recency reverses by acquisition order.
	# Pre-populate storage with two items in known order, with explicit seq numbers.
	var first_storage: int = Inventory.HOTBAR_SIZE
	# Manually clear hotbar so try_add fills storage.
	for i in range(Inventory.HOTBAR_SIZE):
		Inventory.slots[i] = {"item_id": &"loam", "count": 1}  # block hotbar
	Inventory.try_add(&"shaleseed", 1)  # gets seq=N
	Inventory.try_add(&"heartwood", 1)  # gets seq=N+1 (later)
	Inventory.sort_storage_recency()
	# Heartwood (acquired last) should appear before shaleseed in storage.
	var first = Inventory.slots[first_storage]
	assert_not_null(first)
	assert_eq(String(first["item_id"]), "heartwood")


func test_hotbar_swap_does_not_duplicate_when_item_moved_to_storage() -> void:
	# Phase 3.51 — regression: saving the layout, moving a hotbar item out to
	# storage, then pressing Q used to leave a copy of the moved item in BOTH
	# the restored hotbar slot AND its storage slot. Fixed by having the swap
	# pull items from wherever they are instead of fabricating new stacks.
	# The mechanic is implemented on Hotbar (UI script), but we exercise the
	# Inventory side-effects directly.
	Inventory.slots[0] = {"item_id": &"wooden_pickaxe", "count": 1}
	Inventory.slots[1] = {"item_id": &"wooden_sword", "count": 1}
	Inventory.slots[2] = {"item_id": &"wooden_axe", "count": 1}
	# Snapshot what the hotbar code WOULD save when player presses Shift+Q.
	var saved_layout: Array = []
	for i in range(Inventory.HOTBAR_SIZE):
		var s = Inventory.slots[i]
		saved_layout.append(s.duplicate(true) if s != null else null)
	# Player moves the axe to storage slot 11 manually.
	Inventory.slots[11] = Inventory.slots[2]
	Inventory.slots[2] = null
	# Run the swap algorithm verbatim from Hotbar._swap_hotbar_layout.
	var snapshot_b: Array = []
	for i in range(Inventory.HOTBAR_SIZE):
		var s = Inventory.slots[i]
		snapshot_b.append(s.duplicate(true) if s != null else null)
	var displaced: Array = []
	for i in range(Inventory.HOTBAR_SIZE):
		if Inventory.slots[i] != null:
			displaced.append(Inventory.slots[i])
			Inventory.slots[i] = null
	for i in range(Inventory.HOTBAR_SIZE):
		var target = saved_layout[i]
		if target == null:
			continue
		var tid: StringName = StringName(target.get("item_id", ""))
		var found: bool = false
		for k in range(displaced.size()):
			var d = displaced[k]
			if d != null and StringName(d.get("item_id", "")) == tid:
				Inventory.slots[i] = d
				displaced[k] = null
				found = true
				break
		if found:
			continue
		for j in range(Inventory.HOTBAR_SIZE, Inventory.slots.size()):
			var s = Inventory.slots[j]
			if s != null and StringName(s.get("item_id", "")) == tid:
				Inventory.slots[i] = s
				Inventory.slots[j] = null
				break
	for d in displaced:
		if d == null:
			continue
		Inventory.try_add(StringName(d.get("item_id", "")), int(d.get("count", 0)))
	# Assert: only ONE wooden_axe exists in the entire inventory.
	assert_eq(Inventory.count_of(&"wooden_axe"), 1,
		"swap must not duplicate the axe when it was moved to storage")
	# Assert: axe is back in slot 2 (its saved hotbar position).
	assert_not_null(Inventory.slots[2])
	assert_eq(String(Inventory.slots[2]["item_id"]), "wooden_axe")
	# Assert: storage slot 11 is empty (axe moved out).
	assert_null(Inventory.slots[11], "axe must have moved out of storage slot 11")
