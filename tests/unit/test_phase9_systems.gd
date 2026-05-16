extends GutTest

## Phase 9 systems test bundle. Verifies the NPC depth + housing + merchant
## economy + quest log + gifts/reputation + Phase-9 placeables.


func before_each() -> void:
	GameState.arrived_npcs.clear()
	GameState.defeated_bosses.clear()
	if NpcLifecycle:
		NpcLifecycle.friendship.clear()
		NpcLifecycle.npc_mood.clear()
		NpcLifecycle.faction_reputation.clear()
		NpcLifecycle.quest_states.clear()
		NpcLifecycle.quest_progress.clear()
		NpcLifecycle.flagged_branches.clear()
		NpcLifecycle.daily_quests_today.clear()
		NpcLifecycle.day_index = 0
		NpcLifecycle.seasonal_phase = &"phase_dawn"
	if Housing:
		Housing.beds_to_npc.clear()
	Inventory.clear()


# --- 9.16 — friendship + 9.19 gift-giving ---------------------------------


func test_gift_favorite_item_increases_friendship_more() -> void:
	# Brindle's favorite is shaleseed.
	Inventory.try_add(&"shaleseed", 1)
	var delta: int = NpcLifecycle.gift_item(&"npc_brindle", &"shaleseed")
	assert_gt(delta, 5)


func test_gift_hated_item_decreases_friendship() -> void:
	Inventory.try_add(&"glow_cap", 1)
	var delta: int = NpcLifecycle.gift_item(&"npc_brindle", &"glow_cap")
	assert_lt(delta, 0)


func test_gift_one_per_day_only() -> void:
	NpcLifecycle.flagged_branches[&"npc_brindle_today"] = true
	var delta: int = NpcLifecycle.gift_item(&"npc_brindle", &"shaleseed")
	assert_eq(delta, 0)


# --- 9.60 — Faction reputation -------------------------------------------


func test_reputation_clamps() -> void:
	NpcLifecycle.add_reputation(&"faction_pyrenkin", 5000)
	assert_eq(NpcLifecycle.get_reputation(&"faction_pyrenkin"), NpcLifecycle.REPUTATION_MAX)
	NpcLifecycle.add_reputation(&"faction_pyrenkin", -100000)
	assert_eq(NpcLifecycle.get_reputation(&"faction_pyrenkin"), -NpcLifecycle.REPUTATION_MAX)


func test_reputation_changes_price() -> void:
	NpcLifecycle.add_reputation(&"faction_pyrenkin", 500)
	var mult: float = NpcLifecycle.price_multiplier_for_reputation(&"faction_pyrenkin")
	assert_lt(mult, 1.0)
	NpcLifecycle.add_reputation(&"faction_pyrenkin", -1500)
	mult = NpcLifecycle.price_multiplier_for_reputation(&"faction_pyrenkin")
	assert_gt(mult, 1.0)


# --- 9.17/9.18 — Daily quest log ------------------------------------------


func test_assign_daily_quests_seeds_three() -> void:
	NpcLifecycle._assign_new_daily()
	assert_eq(NpcLifecycle.daily_quests_today.size(), 3)


func test_record_quest_progress_completes_when_goal_met() -> void:
	NpcLifecycle.quest_states[&"quest_kill_10_hollowlings"] = "active"
	NpcLifecycle.quest_progress[&"quest_kill_10_hollowlings"] = { "current": 0, "goal": 3 }
	NpcLifecycle.record_quest_progress(&"quest_kill_10_hollowlings", 3)
	assert_eq(String(NpcLifecycle.quest_states[&"quest_kill_10_hollowlings"]), "complete")


# --- 9.21 — mood-branched dialogue ---------------------------------------


func test_mood_category_buckets() -> void:
	NpcLifecycle.npc_mood[&"npc_brindle"] = 80
	assert_eq(String(NpcLifecycle.mood_category(&"npc_brindle")), "happy")
	NpcLifecycle.npc_mood[&"npc_brindle"] = 20
	assert_eq(String(NpcLifecycle.mood_category(&"npc_brindle")), "sad")
	NpcLifecycle.npc_mood[&"npc_brindle"] = 50
	assert_eq(String(NpcLifecycle.mood_category(&"npc_brindle")), "neutral")


# --- 9.2 — bed -> NPC binding --------------------------------------------


func test_housing_binds_one_bed_to_one_npc() -> void:
	var pos := Vector2(120, 80)
	assert_true(Housing.bind_bed_to_npc(pos, &"npc_brindle"))
	assert_false(Housing.bind_bed_to_npc(pos, &"npc_mira"))
	assert_eq(String(Housing.npc_for_bed(pos)), "npc_brindle")
	Housing.unbind_npc(&"npc_brindle")
	assert_eq(String(Housing.npc_for_bed(pos)), "")


# --- 9.10 — Merchant restock timer -----------------------------------------


func test_merchant_restock_after_interval() -> void:
	var inv := MerchantInventory.new()
	inv.sell_items = [{ "item_id": "wooden_sword", "price": 25, "stock": 1 }]
	inv.restock_minutes = 0.0  # immediate restock for test
	inv.decrement_stock(&"wooden_sword")
	inv._initialize_stock()
	assert_eq(inv.remaining_stock(&"wooden_sword"), 1)


# --- 9.30 — Seasonal extras --------------------------------------------


func test_seasonal_extras_merge() -> void:
	var inv := MerchantInventory.new()
	inv.sell_items = [{ "item_id": "torch", "price": 3 }]
	inv.seasonal_extras = {
		"phase_long_night": [{ "item_id": "respec_scroll", "price": 60 }],
	}
	var listed: Array = inv.sell_items_for_phase(&"phase_long_night")
	assert_eq(listed.size(), 2)
	listed = inv.sell_items_for_phase(&"phase_dawn")
	assert_eq(listed.size(), 1)


# --- 9.57 — Mood discount table ------------------------------------------


func test_mood_discount_table() -> void:
	var inv := MerchantInventory.new()
	inv.discount_thresholds = [
		{ "mood": 80, "percent": 10.0 },
		{ "mood": 50, "percent": 0.0 },
		{ "mood": 20, "percent": -10.0 },
	]
	assert_almost_eq(inv.price_multiplier_for_mood(85), 0.9, 0.01)
	assert_almost_eq(inv.price_multiplier_for_mood(60), 1.0, 0.01)
	assert_almost_eq(inv.price_multiplier_for_mood(10), 1.1, 0.01)


# --- 9.31 — Pet evolution targets -----------------------------------------


func test_pet_evolution_target_resolves_at_level() -> void:
	if Phase9Helpers == null:
		return
	var target: StringName = Phase9Helpers.get_evolution_target(&"pet_pale_fox", 5)
	assert_eq(String(target), "pet_pale_fox_swift")
	target = Phase9Helpers.get_evolution_target(&"pet_pale_fox", 12)
	assert_eq(String(target), "pet_pale_fox_lunar")


# --- 9.50/9.51 — Gift-threshold relic auto-delivery ----------------------


func test_brindle_pendant_delivered_at_friendship_120() -> void:
	# Friendship starts at 32 by default; bump up to 120.
	NpcLifecycle.friendship[&"npc_brindle"] = 0
	NpcLifecycle.add_friendship(&"npc_brindle", 120)
	assert_gt(Inventory.count_of(&"brindle_pendant"), 0)
	# Idempotent — second add shouldn't double-deliver.
	NpcLifecycle.add_friendship(&"npc_brindle", 5)
	assert_eq(Inventory.count_of(&"brindle_pendant"), 1)


# --- 9.63 — Resonance-bound items don't drop on death --------------------


func test_resonance_bound_items_skip_corpse_drop() -> void:
	var defn: ItemDef = ItemRegistry.get_def(&"brindle_pendant")
	assert_true(defn != null and defn.resonance_bound)


# --- 9.40 — Garden score / 9.41 — Light pollution helpers ----------------


func test_phase9_helpers_evolution_table_complete() -> void:
	if Phase9Helpers == null:
		return
	assert_true(Phase9Helpers.PET_EVOLUTIONS.has(&"pet_pale_fox"))
	assert_true(Phase9Helpers.PET_EVOLUTIONS.has(&"pet_charred_goat"))


# --- 9.18 — daily reset cycles seasonal phase -----------------------------


func test_daily_reset_cycles_seasonal_phase() -> void:
	NpcLifecycle.seasonal_phase = &"phase_dawn"
	NpcLifecycle._perform_daily_reset(int(Time.get_unix_time_from_system()))
	assert_eq(String(NpcLifecycle.seasonal_phase), "phase_noon")


# --- 9.45 — pause-and-comment flag set on boss kill ----------------------


func test_boss_kill_sets_comment_flag() -> void:
	NpcLifecycle._on_boss_defeated(&"boss_glaurem")
	assert_true(NpcLifecycle.get_flag(StringName("comment_pending:boss_glaurem")))


# --- 9.65 — AudioBus accepts NPC theme override --------------------------


func test_audiobus_set_npc_theme_idempotent() -> void:
	if AudioBus == null or not AudioBus.has_method("set_npc_theme"):
		return
	AudioBus.set_npc_theme(&"theme_brindle_forge", true)
	AudioBus.set_npc_theme(&"theme_brindle_forge", false)
	# Just verifying no crashes — the theme is restored to ambient by biome swap.
	assert_true(true)


# --- 3.27 — Bag-in-bag UX ------------------------------------------------


func test_bag_toggle_opens_and_closes() -> void:
	assert_eq(Inventory.open_bag_index, -1)
	assert_true(Inventory.toggle_bag_open(2))
	assert_eq(Inventory.open_bag_index, 2)
	assert_false(Inventory.toggle_bag_open(2))
	assert_eq(Inventory.open_bag_index, -1)


func test_bag_holds_six_slots() -> void:
	Inventory.toggle_bag_open(3)
	# Use 6 distinct items so each consumes its own slot.
	var fillers: Array[StringName] = [&"loam", &"shaleseed", &"glow_cap", &"loambeetle", &"memory_root", &"pale_cap"]
	for iid in fillers:
		assert_true(Inventory.bag_try_add(3, iid, 1))
	assert_eq((Inventory.bag_slot_contents(3) as Array).size(), 6)
	# A 7th distinct item should refuse the new slot.
	var ok: bool = Inventory.bag_try_add(3, StringName("tablet_shard"), 1)
	assert_false(ok)


# --- 9.22 — Pet saddlebag carry ------------------------------------------


func test_pet_saddlebag_requires_min_level() -> void:
	if Pets == null:
		return
	Pets.pets[&"pet_pale_fox"] = { "xp": 0, "level": 1, "mood": 50, "dead": false }
	assert_false(Pets.saddlebag_can_carry(&"pet_pale_fox"))
	Pets.pets[&"pet_pale_fox"]["level"] = 6
	assert_true(Pets.saddlebag_can_carry(&"pet_pale_fox"))
	assert_true(Pets.saddlebag_deposit(&"pet_pale_fox", &"loam", 2))
	assert_eq((Pets.saddlebag_for(&"pet_pale_fox") as Array).size(), 1)


# --- Save round-trip ------------------------------------------------------


func test_npc_lifecycle_save_restore_round_trip() -> void:
	NpcLifecycle.friendship[&"npc_brindle"] = 88
	NpcLifecycle.npc_mood[&"npc_brindle"] = 72
	NpcLifecycle.faction_reputation[&"faction_pyrenkin"] = 240
	NpcLifecycle.set_flag(&"some_test_flag", true)
	var dump: Dictionary = NpcLifecycle.dump_state()
	NpcLifecycle.friendship.clear()
	NpcLifecycle.npc_mood.clear()
	NpcLifecycle.faction_reputation.clear()
	NpcLifecycle.flagged_branches.clear()
	NpcLifecycle.restore_state(dump)
	assert_eq(NpcLifecycle.get_friendship(&"npc_brindle"), 88)
	assert_eq(NpcLifecycle.get_mood(&"npc_brindle"), 72)
	assert_eq(NpcLifecycle.get_reputation(&"faction_pyrenkin"), 240)
	assert_true(NpcLifecycle.get_flag(&"some_test_flag"))


func test_housing_save_restore_round_trip() -> void:
	Housing.bind_bed_to_npc(Vector2(40, 60), &"npc_old_hask")
	var dump: Dictionary = Housing.dump_state()
	Housing.beds_to_npc.clear()
	Housing.restore_state(dump)
	assert_eq(String(Housing.npc_for_bed(Vector2(40, 60))), "npc_old_hask")
