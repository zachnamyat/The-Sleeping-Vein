extends GutTest

## Phase 3.6 — Chest deposit / withdraw / dump-state / restore-state.

var chest: Chest


func before_each() -> void:
	Inventory.clear()
	chest = Chest.new()
	add_child_autofree(chest)
	# add_child triggers _ready automatically — don't call it again or signal
	# connections will throw INVALID_PARAMETER (already-connected).


func test_deposit_into_empty_chest() -> void:
	var moved: int = chest.deposit(&"loam", 5)
	assert_eq(moved, 5)
	assert_eq(int(chest.slots[0]["count"]), 5)


func test_deposit_stacks_into_existing_slot() -> void:
	chest.deposit(&"loam", 5)
	chest.deposit(&"loam", 3)
	var total: int = 0
	for s in chest.slots:
		if s != null and StringName(s["item_id"]) == &"loam":
			total += int(s["count"])
	assert_eq(total, 8)


func test_withdraw_moves_to_player_inventory() -> void:
	chest.deposit(&"shaleseed", 4)
	# Find slot with shaleseed.
	var idx: int = -1
	for i in range(chest.slots.size()):
		var s = chest.slots[i]
		if s != null and StringName(s["item_id"]) == &"shaleseed":
			idx = i
			break
	var moved: int = chest.withdraw_slot(idx)
	assert_eq(moved, 4)
	assert_eq(Inventory.count_of(&"shaleseed"), 4)
	assert_null(chest.slots[idx])


func test_dump_state_round_trips_through_restore_state() -> void:
	chest.deposit(&"loam", 7)
	chest.deposit(&"shaleseed", 2)
	chest.unique_id = &"test_persist_chest"
	chest.global_position = Vector2(123, -45)
	var payload: Dictionary = chest.dump_state()
	# Recreate a fresh chest and restore.
	var fresh := Chest.new()
	add_child_autofree(fresh)
	fresh.restore_state(payload)
	assert_eq(String(fresh.unique_id), "test_persist_chest")
	assert_eq(int(fresh.global_position.x), 123)
	# Verify a populated slot survives.
	var found_loam: bool = false
	var found_shale: bool = false
	for s in fresh.slots:
		if s == null: continue
		match String(s["item_id"]):
			"loam":
				found_loam = true
				assert_eq(int(s["count"]), 7)
			"shaleseed":
				found_shale = true
				assert_eq(int(s["count"]), 2)
	assert_true(found_loam, "restored chest must contain loam stack")
	assert_true(found_shale, "restored chest must contain shaleseed stack")
