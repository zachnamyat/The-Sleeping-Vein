extends GutTest

## Phase 3.4 — Equipment slots: validation, equip/unequip, swap with another
## equipped piece.


func before_each() -> void:
	Inventory.clear()
	for s in Inventory.EQUIPMENT_SLOTS:
		Inventory.equipment[s] = &""


func test_equipment_slot_field_present_on_shaleseed_helmet() -> void:
	var defn: ItemDef = ItemRegistry.get_def(&"shaleseed_helmet")
	assert_not_null(defn)
	assert_eq(String(defn.equipment_slot), "helmet",
		"shaleseed_helmet must declare equipment_slot=helmet for slot validation to work")


func test_equip_from_slot_moves_item_to_equipment() -> void:
	Inventory.try_add(&"shaleseed_helmet", 1)
	# Find the inventory index where it landed (try_add fills lowest empty slot).
	var inv_idx: int = -1
	for i in range(Inventory.slots.size()):
		var s = Inventory.slots[i]
		if s != null and StringName(s.get("item_id", "")) == &"shaleseed_helmet":
			inv_idx = i
			break
	assert_gte(inv_idx, 0)
	var ok: bool = Inventory.equip_from_slot(inv_idx, &"helmet")
	assert_true(ok, "equip should succeed when target slot matches item")
	assert_eq(String(Inventory.equipment[&"helmet"]), "shaleseed_helmet")
	assert_eq(Inventory.count_of(&"shaleseed_helmet"), 0,
		"item should have moved out of the inventory slot")


func test_equip_from_slot_rejects_mismatched_slot() -> void:
	Inventory.try_add(&"shaleseed_helmet", 1)
	var inv_idx: int = -1
	for i in range(Inventory.slots.size()):
		var s = Inventory.slots[i]
		if s != null and StringName(s.get("item_id", "")) == &"shaleseed_helmet":
			inv_idx = i
			break
	var ok: bool = Inventory.equip_from_slot(inv_idx, &"boots")
	assert_false(ok, "helmet must not fit boots slot")
	assert_eq(String(Inventory.equipment[&"boots"]), "")


func test_equip_swaps_when_slot_occupied() -> void:
	Inventory.try_add(&"shaleseed_helmet", 1)
	# Manually equip something else first so the slot has a previous occupant.
	Inventory.equipment[&"helmet"] = &"placeholder_helm"
	var inv_idx: int = -1
	for i in range(Inventory.slots.size()):
		var s = Inventory.slots[i]
		if s != null and StringName(s.get("item_id", "")) == &"shaleseed_helmet":
			inv_idx = i
			break
	assert_gte(inv_idx, 0)
	Inventory.equip_from_slot(inv_idx, &"helmet")
	assert_eq(String(Inventory.equipment[&"helmet"]), "shaleseed_helmet")
	# Previous occupant should now sit in the inventory slot.
	var post = Inventory.slots[inv_idx]
	assert_not_null(post)
	assert_eq(String(post["item_id"]), "placeholder_helm")


func test_unequip_returns_to_first_free_slot() -> void:
	Inventory.equipment[&"chest"] = &"shaleseed_chest"
	assert_true(Inventory.unequip(&"chest"))
	assert_eq(String(Inventory.equipment[&"chest"]), "")
	assert_eq(Inventory.count_of(&"shaleseed_chest"), 1)
