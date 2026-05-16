extends GutTest

## Phase 7 — talent trees, presets, set bonuses, reforge, luck, mob affixes.


func before_each() -> void:
	GameState.allocated_talents.clear()
	GameState.allocated_talent_nodes.clear()
	GameState.talent_presets = [{}, {}, {}]
	GameState.unallocated_talent_points = 0
	Inventory.clear()
	Inventory.equipped_affixes.clear()
	for s in Inventory.EQUIPMENT_SLOTS:
		Inventory.equipment[s] = &""


# --- 7.1 / 7.3-7.6 — Tree data --------------------------------------------------


func test_talent_registry_loads_all_12_trees() -> void:
	var seen: Dictionary = {}
	for s in SkillSystem.ALL_SKILLS:
		var t: TalentTree = TalentRegistry.tree_for(s)
		if t:
			seen[s] = true
	assert_eq(seen.size(), 12, "Each of the 12 skills should have a TalentTree")


func test_every_tree_has_capstone_at_tier_5() -> void:
	for s in SkillSystem.ALL_SKILLS:
		var t: TalentTree = TalentRegistry.tree_for(s)
		assert_not_null(t)
		var found_capstone: bool = false
		for n in t.nodes:
			if int(n.get("tier", 1)) == 5:
				found_capstone = true
				break
		assert_true(found_capstone, "%s tree missing tier-5 capstone" % s)


# --- 7.7 — Allocation -----------------------------------------------------------


func test_allocate_talent_node_increments_rank_and_decrements_pool() -> void:
	GameState.unallocated_talent_points = 3
	var ok: bool = GameState.allocate_talent_node(&"skill_mining", &"mining_dmg_1")
	assert_true(ok)
	assert_eq(GameState.unallocated_talent_points, 2)
	var by_node: Dictionary = GameState.allocated_talent_nodes.get(&"skill_mining", {})
	assert_eq(int(by_node.get(&"mining_dmg_1", 0)), 1)


func test_allocation_fails_without_points() -> void:
	GameState.unallocated_talent_points = 0
	var ok: bool = GameState.allocate_talent_node(&"skill_mining", &"mining_dmg_1")
	assert_false(ok)


# --- 7.13 — Prerequisites -------------------------------------------------------


func test_prerequisites_block_allocation() -> void:
	GameState.unallocated_talent_points = 1
	# Mining "mining_speed_1" requires "mining_dmg_1" first.
	var ok: bool = GameState.allocate_talent_node(&"skill_mining", &"mining_speed_1")
	assert_false(ok)


func test_prerequisites_pass_once_parent_allocated() -> void:
	GameState.unallocated_talent_points = 2
	assert_true(GameState.allocate_talent_node(&"skill_mining", &"mining_dmg_1"))
	assert_true(GameState.allocate_talent_node(&"skill_mining", &"mining_speed_1"))


func test_capstone_requires_all_tier_4_paths() -> void:
	GameState.unallocated_talent_points = 5
	# Mining capstone requires mining_area_1 AND mining_pierce.
	assert_true(GameState.allocate_talent_node(&"skill_mining", &"mining_dmg_1"))
	assert_true(GameState.allocate_talent_node(&"skill_mining", &"mining_speed_1"))
	assert_true(GameState.allocate_talent_node(&"skill_mining", &"mining_xp_1"))
	assert_true(GameState.allocate_talent_node(&"skill_mining", &"mining_area_1"))
	# Trying capstone without mining_pierce should fail.
	var ok: bool = GameState.allocate_talent_node(&"skill_mining", &"mining_capstone")
	assert_false(ok)


# --- 7.16 — Presets -------------------------------------------------------------


func test_save_preset_captures_allocation_snapshot() -> void:
	GameState.unallocated_talent_points = 2
	GameState.allocate_talent_node(&"skill_mining", &"mining_dmg_1")
	GameState.allocate_talent_node(&"skill_mining", &"mining_dmg_1")
	var ok: bool = GameState.save_talent_preset(0)
	assert_true(ok)
	assert_eq(GameState.talent_preset_point_total(0), 2)


func test_load_preset_refunds_then_respends() -> void:
	GameState.unallocated_talent_points = 4
	GameState.allocate_talent_node(&"skill_mining", &"mining_dmg_1")
	GameState.allocate_talent_node(&"skill_mining", &"mining_dmg_1")
	GameState.save_talent_preset(0)
	# Reset and load.
	GameState.refund_all_talents()
	assert_eq(GameState.unallocated_talent_points, 4)
	var ok: bool = GameState.load_talent_preset(0)
	assert_true(ok)
	assert_eq(int(GameState.allocated_talent_nodes[&"skill_mining"][&"mining_dmg_1"]), 2)


# --- 7.9 — Refund all -----------------------------------------------------------


func test_refund_all_zeros_allocations() -> void:
	GameState.unallocated_talent_points = 2
	GameState.allocate_talent_node(&"skill_mining", &"mining_dmg_1")
	GameState.allocate_talent_node(&"skill_mining", &"mining_dmg_1")
	GameState.refund_all_talents()
	assert_eq(GameState.unallocated_talent_points, 2)
	assert_eq(GameState.allocated_talent_nodes.size(), 0)


# --- TalentEffects sum_value --------------------------------------------------


func test_talent_effects_sum_value_returns_rank_times_value() -> void:
	GameState.unallocated_talent_points = 5
	for _i in range(5):
		GameState.allocate_talent_node(&"skill_mining", &"mining_dmg_1")
	var v: float = TalentEffects.sum_value(&"skill_mining", &"mining_damage_pct")
	# 5 ranks * 0.10 = 0.50
	assert_almost_eq(v, 0.50, 0.001)


# --- 3.20 — Set bonuses ---------------------------------------------------------


func test_set_bonus_thresholds_stack_below_pieces_worn() -> void:
	var b3 := SetBonuses.bonus_for(&"set_ember_iron", 3)
	# 2-piece + 3-piece = armor 4 + max_hp 10 + crit_chance 0.05
	assert_almost_eq(float(b3.get("armor", 0)), 4.0, 0.01)
	assert_almost_eq(float(b3.get("max_hp", 0)), 10.0, 0.01)
	assert_almost_eq(float(b3.get("crit_chance", 0.0)), 0.05, 0.001)


func test_set_bonus_with_zero_pieces_is_empty() -> void:
	var b := SetBonuses.bonus_for(&"set_ember_iron", 0)
	assert_eq(b.get("armor", 0), 0)


# --- 3.29 — Reforge ------------------------------------------------------------


func test_can_reforge_requires_coins_and_reforgeable_item() -> void:
	Inventory.try_add(&"ancient_coin", 10)
	Inventory.try_add(&"bow", 1)
	# Find the bow slot.
	var bow_slot: int = -1
	for i in range(Inventory.slots.size()):
		var s = Inventory.slots[i]
		if s != null and StringName(s["item_id"]) == &"bow":
			bow_slot = i
			break
	assert_gte(bow_slot, 0)
	assert_true(Reforge.can_reforge(bow_slot))


func test_try_reforge_consumes_coins_and_writes_affix() -> void:
	Inventory.try_add(&"ancient_coin", 20)
	Inventory.try_add(&"bow", 1)
	var bow_slot: int = -1
	for i in range(Inventory.slots.size()):
		var s = Inventory.slots[i]
		if s != null and StringName(s["item_id"]) == &"bow":
			bow_slot = i
			break
	var pick: Dictionary = Reforge.try_reforge(bow_slot)
	assert_false(pick.is_empty())
	assert_eq(Inventory.count_of(&"ancient_coin"), 20 - Reforge.REFORGE_COST_ANCIENT_COIN)
	var affix: Dictionary = Inventory.slots[bow_slot].get("affix", {})
	assert_false(affix.is_empty())


# --- 7.19 — Luck ---------------------------------------------------------------


func test_luck_bonus_drop_count_scales_with_luck() -> void:
	PlayerStats.luck = 0.0
	assert_eq(LuckSystem.bonus_drop_count(), 0)
	PlayerStats.luck = 50.0
	assert_eq(LuckSystem.bonus_drop_count(), 2)
	PlayerStats.luck = 0.0


# --- 2.32 — Mob affixes --------------------------------------------------------


func test_affix_roll_returns_valid_tier() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var roll: Dictionary = MobAffixes.roll_for_spawn(rng)
	assert_true(["normal", "elite", "champion"].has(roll.get("tier", "")))


func test_affix_apply_sets_tint_metadata() -> void:
	var mob := Node.new()
	add_child_autofree(mob)
	MobAffixes.apply(mob, {"tier": "elite", "affix": MobAffixes.AFFIX_DEFS[0]})
	assert_eq(String(mob.get_meta(&"affix_tier")), "elite")
	assert_gt(float(mob.get_meta(&"affix_hp_mult", 1.0)), 1.0)


# --- 7.8 — XP buff applies ------------------------------------------------------


func test_xp_buff_multiplies_skill_xp_gain() -> void:
	GameState.allocated_talents.clear()
	GameState.allocated_talent_nodes.clear()
	SkillSystem._xp[&"skill_mining"] = 0
	SkillSystem._level[&"skill_mining"] = 0
	Buffs._active = {&"buff_xp_boost": 60.0}
	SkillSystem.add_xp(&"skill_mining", 100)
	# Base 100 * 1.25 = 125.
	assert_eq(int(SkillSystem.get_xp(&"skill_mining")), 125)
	Buffs._active.clear()


# --- 7.11 — Accessory skill level bonus ----------------------------------------


func test_accessory_skill_bonus_adds_to_effective_level() -> void:
	# Equip the Stratasinger's Ring (+5 mining).
	Inventory.equipment[&"ring_2"] = &"ring_mining_skill"
	PlayerStats.recompute()
	SkillSystem._level[&"skill_mining"] = 10
	assert_eq(SkillSystem.effective_level(&"skill_mining"), 15)
	Inventory.equipment[&"ring_2"] = &""
	PlayerStats.recompute()


# --- 7.18 — XP progress helper --------------------------------------------------


func test_progress_into_level_returns_into_and_span() -> void:
	SkillSystem._xp[&"skill_running"] = 60
	SkillSystem._level[&"skill_running"] = 0
	var prog: Dictionary = SkillSystem.progress_into_level(&"skill_running")
	assert_eq(int(prog["into"]), 60)
	assert_eq(int(prog["span"]), 100)
	assert_false(bool(prog["at_cap"]))


# --- 7.15 — Skill challenges ----------------------------------------------------


func test_skill_challenge_start_and_progress_reaches_goal() -> void:
	GameState.unallocated_talent_points = 0
	var ok: bool = SkillChallenges.start_challenge(&"skill_mining")
	assert_true(ok)
	# Simulate 10 tile-changed events that mean "tile mined" (new_id < 0).
	for _i in range(10):
		EventBus.tile_changed.emit(Vector2i.ZERO, 1, -1)
	# Active skill cleared on success.
	assert_eq(String(SkillChallenges.current_skill()), "")
	assert_eq(GameState.unallocated_talent_points, 1)


# --- 7.7 — Total talent points helper ------------------------------------------


func test_total_earned_includes_allocated_plus_unallocated() -> void:
	GameState.unallocated_talent_points = 3
	GameState.allocated_talents[&"skill_mining"] = 2
	assert_eq(GameState.total_talent_points_earned(), 5)
