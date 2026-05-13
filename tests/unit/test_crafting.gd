extends GutTest

## Phase 3 — Crafting flow, recipe unlock, station filtering, XP emission.


func before_each() -> void:
	Inventory.clear()
	# Start with no per-test unlocks beyond CraftingSystem's _ready defaults.
	GameState.unlocked_recipes.clear()
	CraftingSystem.unlock(&"craft_wooden_pickaxe")


func test_recipe_loaded_from_disk() -> void:
	var rec: Recipe = CraftingSystem.get_recipe(&"craft_wooden_pickaxe")
	assert_not_null(rec, "wooden_pickaxe recipe must load from res://resources/recipes/")
	assert_eq(String(rec.id), "craft_wooden_pickaxe")
	assert_gt(rec.inputs.size(), 0, "should declare inputs")
	assert_gt(rec.outputs.size(), 0, "should declare outputs")


func test_try_craft_consumes_inputs_and_produces_outputs() -> void:
	Inventory.try_add(&"loam", 12)
	var ok: bool = CraftingSystem.try_craft(&"craft_wooden_pickaxe")
	assert_true(ok, "should craft when inputs present")
	assert_eq(Inventory.count_of(&"loam"), 6, "should consume 6 loam (recipe input)")
	assert_eq(Inventory.count_of(&"wooden_pickaxe"), 1, "should yield 1 pickaxe")


func test_try_craft_fails_without_inputs() -> void:
	Inventory.try_add(&"loam", 2)  # not enough
	var ok: bool = CraftingSystem.try_craft(&"craft_wooden_pickaxe")
	assert_false(ok, "should reject craft when inputs short")
	assert_eq(Inventory.count_of(&"wooden_pickaxe"), 0)


func test_try_craft_emits_skill_xp() -> void:
	Inventory.try_add(&"loam", 6)
	var gained := [false, 0]
	var cb := func(skill: StringName, amount: int) -> void:
		if skill == &"skill_crafting":
			gained[0] = true
			gained[1] = amount
	EventBus.skill_xp_gained.connect(cb)
	CraftingSystem.try_craft(&"craft_wooden_pickaxe")
	EventBus.skill_xp_gained.disconnect(cb)
	assert_true(gained[0], "Phase 3.12 — crafting must emit skill_xp_gained for skill_crafting")
	assert_gt(gained[1], 0, "amount granted should be positive")


func test_recipes_for_station_filters_by_station_id() -> void:
	var loam_bench: Array = CraftingSystem.recipes_for_station(&"loam_bench")
	var ids: Array = []
	for r in loam_bench:
		ids.append(String(r.id))
	# wooden_pickaxe targets loam_bench in its station list.
	assert_true("craft_wooden_pickaxe" in ids, "loam_bench recipes must include wooden_pickaxe")


func test_recipe_unlock_idempotent() -> void:
	CraftingSystem.unlock(&"craft_wooden_pickaxe")
	CraftingSystem.unlock(&"craft_wooden_pickaxe")
	assert_true(CraftingSystem.is_unlocked(&"craft_wooden_pickaxe"))


func test_clearstone_forge_unlocks_tier1_recipes() -> void:
	# Phase 3.11 — crafting the placeable triggers tier-1 unlock cascade.
	GameState.unlocked_recipes.clear()
	# Pretend the player just crafted a Clearstone Forge by emitting item_crafted.
	EventBus.item_crafted.emit(&"clearstone_forge_placeable", 1)
	assert_true(CraftingSystem.is_unlocked(&"craft_shaleseed_pickaxe"))
	assert_true(CraftingSystem.is_unlocked(&"craft_shaleseed_sword"))
	assert_true(CraftingSystem.is_unlocked(&"craft_shaleseed_helmet"))
	assert_true(CraftingSystem.is_unlocked(&"craft_shaleseed_chest"))
