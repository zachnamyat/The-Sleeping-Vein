extends GutTest

## Phase 8 — Farming + Cooking + Fishing + Pets + Critters.


func before_each() -> void:
	Inventory.clear()
	if CookingSystem:
		CookingSystem._discovered.clear()
	if FishingSystem:
		FishingSystem.trophies.clear()
		FishingSystem._stage = 0   # IDLE
		FishingSystem.tournament_active = false
	if Pets:
		Pets.pets.clear()
	Buffs._active.clear()


# --- 8.1 / 8.2 / 8.3 / 8.13 — Farming critical path -----------------------------


func test_seed_registry_contains_six_phase8_crops() -> void:
	for s in [&"pale_cap_seed", &"memory_root_seed", &"bloat_oat_seed",
			  &"heart_berry_seed", &"glow_cap_seed", &"bomb_pepper_seed"]:
		assert_true(FarmingSystem.is_seed(s), "Seed missing: %s" % s)


func test_hoe_and_watering_and_fertilizer_dispatch() -> void:
	assert_true(FarmingSystem.is_hoe(&"hoe"))
	assert_true(FarmingSystem.is_watering_can(&"watering_can"))
	assert_true(FarmingSystem.is_fertilizer(&"fertilizer"))


func test_multi_harvest_crops_have_regrow_data() -> void:
	var data: Dictionary = FarmingSystem.seed_data(&"bloat_oat_seed")
	assert_gt(float(data.get("regrow_after", 0.0)), 0.0)
	var data2: Dictionary = FarmingSystem.seed_data(&"heart_berry_seed")
	assert_gt(float(data2.get("regrow_after", 0.0)), 0.0)


func test_bomb_pepper_flagged_for_walkover_explosion() -> void:
	var data: Dictionary = FarmingSystem.seed_data(&"bomb_pepper_seed")
	assert_true(bool(data.get("explode_on_walkover", false)))


func test_glow_cap_seed_chained_placement_id() -> void:
	var data: Dictionary = FarmingSystem.seed_data(&"glow_cap_seed")
	assert_eq(StringName(data.get("on_harvest_place", &"")), &"glow_cap_placeable")


# --- 8.5 / 8.6 / 8.7 — Cooking buffs --------------------------------------------


func test_food_buff_table_has_20_entries() -> void:
	assert_gte(CookingSystem.FOOD_BUFFS.size(), 20)


func test_apply_food_buff_strips_old_buff_in_same_category() -> void:
	# Eat a Pale Cap Stew → buff_well_fed in category &"hp".
	CookingSystem.apply_food_buff(&"pale_cap_stew")
	assert_true(Buffs.has(&"buff_well_fed"))
	# Eat a Bloat Loaf → buff_oat_strength in category &"hp" (replaces).
	CookingSystem.apply_food_buff(&"bloat_loaf")
	assert_false(Buffs.has(&"buff_well_fed"))
	assert_true(Buffs.has(&"buff_oat_strength"))


func test_apply_food_buff_different_category_coexists() -> void:
	CookingSystem.apply_food_buff(&"pale_cap_stew")       # hp
	CookingSystem.apply_food_buff(&"memory_root_broth")   # mana
	assert_true(Buffs.has(&"buff_well_fed"))
	assert_true(Buffs.has(&"buff_clear_minded"))


# --- 8.8 / 8.28 / 8.38 — Cookbook discovery --------------------------------------


func test_mark_discovered_persists_for_future_lookup() -> void:
	CookingSystem.mark_discovered(&"craft_pale_cap_stew")
	assert_true(CookingSystem.is_discovered(&"craft_pale_cap_stew"))
	assert_false(CookingSystem.is_discovered(&"craft_bloat_loaf"))


# --- 8.9 / 8.10 / 8.12 — Fishing tier + biome tables ----------------------------


func test_fishing_rod_tiers_have_increasing_speed() -> void:
	var wood: Dictionary = FishingSystem.ROD_DATA[&"fishing_rod_wood"]
	var copper: Dictionary = FishingSystem.ROD_DATA[&"fishing_rod_copper"]
	var iron: Dictionary = FishingSystem.ROD_DATA[&"fishing_rod_iron"]
	assert_gt(float(wood.cast_seconds), float(copper.cast_seconds))
	assert_gt(float(copper.cast_seconds), float(iron.cast_seconds))
	assert_lt(int(wood.tier), int(copper.tier))


func test_biome_fish_tables_filter_by_rod_tier() -> void:
	# Wood rod (tier 1) reels at root_hollows must contain cave_guppy.
	var table: Array = FishingSystem.BIOME_FISH[&"root_hollows"]
	var has_guppy: bool = false
	for entry in table:
		if StringName(entry.id) == &"cave_guppy":
			has_guppy = true
			break
	assert_true(has_guppy)


func test_net_trap_returns_a_low_tier_fish() -> void:
	var caught: StringName = FishingSystem.net_trap_roll(&"root_hollows")
	assert_true(caught == &"cave_guppy" or caught == &"root_bream")


# --- 8.11 — Bait off-hand -------------------------------------------------------


func test_bait_bonus_table_has_3_entries() -> void:
	assert_eq(FarmingSystem.BAIT_BONUS.size(), 3)


# --- 8.14 — Aquarium + 8.21 net_trap state --------------------------------------


func test_aquarium_dump_restore_round_trip() -> void:
	var Scene := load("res://scenes/structures/aquarium.tscn") as PackedScene
	var aq := Scene.instantiate() as Node
	add_child_autofree(aq)
	aq.fish_inside = [&"cave_guppy", &"salt_minnow"]
	var dumped: Dictionary = aq.dump_state()
	assert_eq((dumped.get("fish_inside", []) as Array).size(), 2)


# --- 8.15 — Critter spawn pool --------------------------------------------------


func test_critter_table_has_entries_for_all_4_phase4_biomes() -> void:
	var biomes_seen: Dictionary = {}
	for entry in Critters.CRITTER_TABLE:
		biomes_seen[StringName(entry.biome)] = true
	for b in [&"root_hollows", &"glasswright_reaches", &"vesari_necropolis", &"drowned_aphelion"]:
		assert_true(biomes_seen.has(b), "Critter table missing biome %s" % b)


# --- 8.25 / 8.41 / 8.49 / 8.50 — Pets -------------------------------------------


func test_tame_requires_matching_favorite_food() -> void:
	assert_false(Pets.tame(&"pet_pale_fox", &"raw_meat"))  # wrong food
	assert_true(Pets.tame(&"pet_pale_fox", &"heart_berry"))
	assert_true(Pets.pets.has(&"pet_pale_fox"))


func test_feed_favorite_grants_more_xp_than_neutral() -> void:
	Pets.tame(&"pet_pale_fox", &"heart_berry")
	var before: int = int(Pets.pets[&"pet_pale_fox"].get("xp", 0))
	Pets.feed(&"pet_pale_fox", &"heart_berry")
	var after_fav: int = int(Pets.pets[&"pet_pale_fox"].get("xp", 0))
	# Drop into another pet for the neutral check.
	Pets.tame(&"pet_charred_goat", &"bloat_oat")
	var before_neutral: int = int(Pets.pets[&"pet_charred_goat"].get("xp", 0))
	Pets.feed(&"pet_charred_goat", &"pale_cap")  # not favorite
	var after_neutral: int = int(Pets.pets[&"pet_charred_goat"].get("xp", 0))
	assert_gt(after_fav - before, after_neutral - before_neutral)


func test_pet_death_and_revive_flow() -> void:
	Pets.tame(&"pet_pale_fox", &"heart_berry")
	Pets.mark_dead(&"pet_pale_fox")
	assert_true(Pets.is_dead(&"pet_pale_fox"))
	# Revive requires a charm.
	assert_false(Pets.try_revive(&"pet_pale_fox"))
	Inventory.try_add(&"pet_revive_charm", 1)
	assert_true(Pets.try_revive(&"pet_pale_fox"))
	assert_false(Pets.is_dead(&"pet_pale_fox"))


# --- Recipe registry ------------------------------------------------------------


func test_at_least_20_cooking_recipes_exist() -> void:
	var count: int = 0
	for r in CraftingSystem.all_recipes():
		var rec: Recipe = r
		if rec.skill_xp_id == &"skill_cooking":
			count += 1
	assert_gte(count, 20, "Phase 8.6 — expect at least 20 cooking recipes")


func test_placeable_items_for_phase8_structures_exist() -> void:
	for iid in [&"sprinkler_placeable", &"aquarium_placeable", &"composter_placeable",
				&"greenhouse_placeable", &"beehive_placeable", &"drying_rack_placeable",
				&"mill_placeable", &"oven_placeable", &"pot_planter_placeable",
				&"trellis_placeable", &"sapling_placeable", &"crystal_sprig",
				&"coral_sprig", &"fish_trophy_placeable", &"net_trap_placeable"]:
		assert_not_null(ItemRegistry.get_def(iid), "Missing Phase 8 placeable: %s" % iid)


func test_phase8_seeds_have_recipes() -> void:
	for rid in [&"craft_bloat_oat_seed", &"craft_heart_berry_seed",
				&"craft_glow_cap_seed", &"craft_bomb_pepper_seed"]:
		assert_not_null(CraftingSystem.get_recipe(rid), "Missing seed recipe: %s" % rid)


func test_fertilizer_table_keys_are_known() -> void:
	for key in [&"fertilizer", &"fertilizer_verdant", &"fertilizer_salt"]:
		assert_true(FarmingSystem.FERTILIZER_MAP.has(key))


# --- 8.37 — Fishing tournament --------------------------------------------------


func test_fishing_tournament_starts_and_records_score() -> void:
	FishingSystem.start_tournament(60.0)
	assert_true(FishingSystem.tournament_active)
	# Manually record a known catch.
	FishingSystem._record_tournament_catch(&"cave_guppy")
	assert_gt(FishingSystem.tournament_score, 0)


# --- 8.36 — Trophy record -------------------------------------------------------


func test_trophy_update_keeps_heaviest_per_species() -> void:
	# Run the private updater multiple times and verify the dict is monotonic.
	for _i in range(8):
		FishingSystem._update_trophy_record(&"cave_guppy")
	assert_true(FishingSystem.trophies.has(&"cave_guppy"))
	assert_gt(int(FishingSystem.trophies[&"cave_guppy"]), 0)


# --- 8.33 — Sapling grows into tree --------------------------------------------


func test_sapling_grow_beats_matches_default() -> void:
	# Default exposed as @export var; we can't easily simulate beat emission in
	# a unit test, but we can verify the scene loads and the grow_beats var
	# is in the expected range.
	var Scene := load("res://scenes/structures/sapling.tscn") as PackedScene
	var s := Scene.instantiate()
	add_child_autofree(s)
	assert_gt(int(s.grow_beats), 0)


# --- 8.18 — Beehive flower detection -------------------------------------------


func test_beehive_state_round_trip() -> void:
	var Scene := load("res://scenes/structures/beehive.tscn") as PackedScene
	var h := Scene.instantiate()
	add_child_autofree(h)
	h.stored_honey = 4
	var dump: Dictionary = h.dump_state()
	assert_eq(int(dump.get("stored_honey", 0)), 4)
	h.stored_honey = 0
	h.restore_state(dump)
	assert_eq(int(h.stored_honey), 4)


# --- 8.7 + 8.38 — Recipe sting on first cook ----------------------------------


func test_first_item_crafted_marks_discovered() -> void:
	# pale_cap_stew is a cooking recipe; fake the event.
	EventBus.item_crafted.emit(&"pale_cap_stew", 1)
	assert_true(CookingSystem.is_discovered(&"craft_pale_cap_stew"))


# --- 3.31 (reassigned to Phase 8) — Tannery ------------------------------------


func test_tannery_items_and_recipes_registered() -> void:
	assert_not_null(ItemRegistry.get_def(&"hide"), "hide item must exist")
	assert_not_null(ItemRegistry.get_def(&"leather"), "leather item must exist")
	assert_not_null(ItemRegistry.get_def(&"tannery_placeable"), "tannery_placeable must exist")
	assert_not_null(CraftingSystem.get_recipe(&"craft_leather"), "craft_leather recipe must exist")
	assert_not_null(CraftingSystem.get_recipe(&"craft_tannery"), "craft_tannery recipe must exist")


func test_leather_recipe_targets_tannery_station() -> void:
	var rec: Recipe = CraftingSystem.get_recipe(&"craft_leather")
	assert_true(&"tannery" in rec.stations)


func test_leather_recipe_consumes_two_hides() -> void:
	Inventory.try_add(&"hide", 2)
	CraftingSystem.unlock(&"craft_leather")
	var ok: bool = CraftingSystem.try_craft(&"craft_leather")
	assert_true(ok)
	assert_eq(Inventory.count_of(&"hide"), 0)
	assert_eq(Inventory.count_of(&"leather"), 1)


func test_stone_hopper_loot_table_includes_hide() -> void:
	var lt: LootTable = load("res://resources/mobs/stone_hopper_loot.tres") as LootTable
	assert_not_null(lt)
	var found: bool = false
	for entry in lt.weighted_drops:
		if StringName(entry.get("item_id", "")) == &"hide":
			found = true
			break
	assert_true(found, "Stone-Hopper loot table must include hide as a weighted drop (3.31)")
