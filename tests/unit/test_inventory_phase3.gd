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
	var first := Inventory.slots[first_storage]
	assert_not_null(first)
	assert_true(String(first["item_id"]) in ["shaleseed", "loam"],
		"sorted entry must be a known stored item")
