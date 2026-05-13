extends GutTest

## Phase 2.3 — Inventory pickup happy path. Adds stack-overflow, removal, and
## the count_of helper used by player_combat's ammo-check.

func before_each() -> void:
	Inventory.clear()


func test_try_add_into_empty_slot() -> void:
	assert_true(Inventory.try_add(&"loam", 1))
	assert_eq(Inventory.count_of(&"loam"), 1)


func test_try_add_stacks() -> void:
	Inventory.try_add(&"loam", 5)
	Inventory.try_add(&"loam", 3)
	assert_eq(Inventory.count_of(&"loam"), 8)


func test_try_add_respects_max_stack() -> void:
	# wooden_pickaxe.tres has max_stack = 1
	Inventory.try_add(&"wooden_pickaxe", 1)
	Inventory.try_add(&"wooden_pickaxe", 1)
	# Two picks should occupy two separate slots, totalling 2.
	assert_eq(Inventory.count_of(&"wooden_pickaxe"), 2)


func test_try_remove_partial() -> void:
	Inventory.try_add(&"shaleseed", 10)
	var removed := Inventory.try_remove(&"shaleseed", 3)
	assert_eq(removed, 3)
	assert_eq(Inventory.count_of(&"shaleseed"), 7)


func test_try_remove_more_than_held_returns_actual() -> void:
	Inventory.try_add(&"shaleseed", 2)
	var removed := Inventory.try_remove(&"shaleseed", 5)
	assert_eq(removed, 2)
	assert_eq(Inventory.count_of(&"shaleseed"), 0)


func test_pickup_emits_inventory_changed() -> void:
	# Phase 2.3 — HUD/UI relies on EventBus.inventory_changed to refresh.
	var received := [false]
	var cb := func() -> void: received[0] = true
	EventBus.inventory_changed.connect(cb)
	Inventory.try_add(&"loambeetle", 1)
	EventBus.inventory_changed.disconnect(cb)
	assert_true(received[0])


func test_hotbar_lookup_first_row() -> void:
	Inventory.try_add(&"wooden_sword", 1)
	# wooden_sword should land in slot 0 (the first hotbar slot).
	assert_eq(Inventory.get_hotbar_item(0), &"wooden_sword")
