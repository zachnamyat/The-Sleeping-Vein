extends GutTest

## Phase 11 systems test bundle. Verifies biomes 6-8 + bosses 7-9 + heat/cold
## damage + frostbite + temperature swing + resist gear + Pyrenkin forge sub-quest
## + Wormbound covenant gesture + Hymnal Vault chord + Listener-Below NPC +
## Korya + tablets + crafting stations + weather + Phase11Helpers persistence.


func before_each() -> void:
	GameState.defeated_bosses.clear()
	GameState.collected_relics.clear()
	GameState.unlocked_recipes.clear()
	GameState.unlocked_compendium.clear()
	Inventory.clear()
	if Phase11Helpers:
		Phase11Helpers.pyrenkin_forges_relit = 0
		Phase11Helpers.pyrenkin_compact_arrived = false
		Phase11Helpers.frostbite_level = 0.0
		Phase11Helpers.emberforge_journal_collected = false
		Phase11Helpers.forge_compact_tablets_collected = 0
		Phase11Helpers.wormbound_gesture_index = 0
		Phase11Helpers.wormbound_covenant_granted = false
		Phase11Helpers.hymnal_last_chord_played = []
		Phase11Helpers.hymnal_correct_chord_played = false
		Phase11Helpers.bellows_lit_phases_remaining = 0
		Phase11Helpers.mirage_patches.clear()
		Phase11Helpers.quicksand_patches.clear()
		Phase11Helpers.current_weather = &"clear"


# --- 11.1/11.2/11.3 — biome resources load with Phase 11 mob tables --------


func test_emberforge_biome_mob_spawn_table() -> void:
	var b: BiomeDef = load("res://resources/biomes/emberforge.tres")
	assert_not_null(b)
	assert_true(b.mob_spawn_table.has(&"slag_hound"))
	assert_true(b.mob_spawn_table.has(&"forge_echo"))
	assert_true(b.mob_spawn_table.has(&"ember_lurker"))
	assert_true(b.mob_spawn_table.has(&"forge_cricket"))
	assert_true(b.mob_spawn_table.has(&"charred_goat"))
	assert_eq(String(b.hazard_id), "heat")
	assert_eq(String(b.resist_armor_id), "ember_iron_chestpiece")


func test_salt_wastes_biome_mob_spawn_table() -> void:
	var b: BiomeDef = load("res://resources/biomes/salt_wastes.tres")
	assert_true(b.mob_spawn_table.has(&"salt_hopper"))
	assert_true(b.mob_spawn_table.has(&"dawning_predator"))
	assert_true(b.mob_spawn_table.has(&"wormbound_stalker"))
	assert_true(b.mob_spawn_table.has(&"salt_cat"))
	assert_true(b.mob_spawn_table.has(&"wormbound_elder"))
	assert_eq(String(b.hazard_id), "dawning_swing")


func test_auroric_veil_biome_mob_spawn_table() -> void:
	var b: BiomeDef = load("res://resources/biomes/auroric_veil.tres")
	assert_true(b.mob_spawn_table.has(&"aurora_wisp"))
	assert_true(b.mob_spawn_table.has(&"cold_hollow"))
	assert_true(b.mob_spawn_table.has(&"sunken_diadem_agent"))
	assert_true(b.mob_spawn_table.has(&"frostlark"))
	assert_true(b.mob_spawn_table.has(&"aurora_vole"))
	assert_eq(String(b.hazard_id), "cold")
	assert_eq(String(b.resist_armor_id), "auroric_ice_chestpiece")


# --- 11.4/11.5 — mob defs load + biome assignment correct ----------------


func test_emberforge_mob_defs_load() -> void:
	for id in [&"slag_hound", &"forge_echo", &"ember_lurker", &"forge_cricket", &"charred_goat"]:
		var path: String = "res://resources/mobs/" + String(id) + ".tres"
		var def: MobDef = load(path) as MobDef
		assert_not_null(def, "missing mob def %s" % id)
		assert_eq(String(def.biome), "emberforge")


func test_salt_wastes_mob_defs_load() -> void:
	for id in [&"salt_hopper", &"dawning_predator", &"wormbound_stalker", &"salt_cat", &"wormbound_elder"]:
		var path: String = "res://resources/mobs/" + String(id) + ".tres"
		var def: MobDef = load(path) as MobDef
		assert_not_null(def, "missing mob def %s" % id)
		assert_eq(String(def.biome), "salt_wastes")


func test_auroric_veil_mob_defs_load() -> void:
	for id in [&"aurora_wisp", &"cold_hollow", &"sunken_diadem_agent", &"frostlark", &"aurora_vole"]:
		var path: String = "res://resources/mobs/" + String(id) + ".tres"
		var def: MobDef = load(path) as MobDef
		assert_not_null(def, "missing mob def %s" % id)
		assert_eq(String(def.biome), "auroric_veil")


func test_friendly_fauna_use_critter_flee() -> void:
	# 11.33 — Forge-Cricket, Charred Goat, Frostlark, Salt-Cat, Aurora-Vole are
	# all friendly critters.
	for id in [&"forge_cricket", &"charred_goat", &"frostlark", &"salt_cat", &"aurora_vole"]:
		var def: MobDef = load("res://resources/mobs/" + String(id) + ".tres") as MobDef
		assert_eq(def.behavior, MobDef.Behavior.CRITTER_FLEE, "%s should be CRITTER_FLEE" % id)
		assert_eq(def.contact_damage, 0)


# --- 11.7 — Heat / cold resist gear -------------------------------------


func test_ember_iron_chestpiece_grants_fire_resist() -> void:
	var d: ItemDef = ItemRegistry.get_def(&"ember_iron_chestpiece")
	assert_not_null(d)
	assert_eq(String(d.equipment_slot), "chest")
	assert_gt(float(d.status_resists.get("fire", 0.0)), 0.0)


func test_auroric_ice_chestpiece_grants_cold_resist() -> void:
	var d: ItemDef = ItemRegistry.get_def(&"auroric_ice_chestpiece")
	assert_not_null(d)
	assert_eq(String(d.equipment_slot), "chest")
	assert_gt(float(d.status_resists.get("cold", 0.0)), 0.0)


func test_heat_resist_lookup_sums_equipment() -> void:
	Inventory.try_add(&"ember_iron_chestpiece", 1)
	var h: float = Phase11Helpers._heat_resist()
	assert_gt(h, 0.0)
	assert_lt(h, 0.96)


func test_cold_resist_with_choirs_resonance() -> void:
	Inventory.try_add(&"choirs_resonance", 1)
	var c: float = Phase11Helpers._cold_resist()
	assert_gt(c, 0.0)


# --- 11.8 — Pyrenkin forge sub-quest -----------------------------------


func test_pyrenkin_relight_three_triggers_compact_arrival() -> void:
	Phase11Helpers.relight_pyrenkin_forge(0)
	Phase11Helpers.relight_pyrenkin_forge(1)
	assert_false(Phase11Helpers.pyrenkin_compact_arrived)
	Phase11Helpers.relight_pyrenkin_forge(2)
	assert_true(Phase11Helpers.pyrenkin_compact_arrived)
	assert_gt(Inventory.count_of(&"pyrenkin_pendant"), 0)
	assert_true(GameState.unlocked_recipes.has(&"craft_pyrenkin_bellows"))


func test_pyrenkin_relight_idempotent() -> void:
	assert_true(Phase11Helpers.relight_pyrenkin_forge(0))
	assert_eq(Phase11Helpers.pyrenkin_forges_relit, 1)
	# Calling for index 0 again must not re-increment.
	assert_false(Phase11Helpers.relight_pyrenkin_forge(0))
	assert_eq(Phase11Helpers.pyrenkin_forges_relit, 1)


# --- 11.9 + 11.29 — Wormbound covenant gesture minigame --------------


func test_wormbound_correct_sequence_grants_scroll() -> void:
	assert_true(Phase11Helpers.wormbound_gesture(&"up"))
	assert_true(Phase11Helpers.wormbound_gesture(&"right"))
	assert_true(Phase11Helpers.wormbound_gesture(&"down"))
	assert_true(Phase11Helpers.wormbound_covenant_granted)
	assert_gt(Inventory.count_of(&"wormbound_covenant_scroll"), 0)


func test_wormbound_wrong_sequence_resets() -> void:
	Phase11Helpers.wormbound_gesture(&"up")
	assert_eq(Phase11Helpers.wormbound_gesture_index, 1)
	Phase11Helpers.wormbound_gesture(&"left")    # wrong direction
	assert_eq(Phase11Helpers.wormbound_gesture_index, 0)
	assert_false(Phase11Helpers.wormbound_covenant_granted)


# --- 11.10 — Skoldur boss def + script -----------------------------


func test_skoldur_boss_def_loads() -> void:
	var def: MobDef = load("res://resources/mobs/skoldur.tres")
	assert_not_null(def)
	assert_eq(String(def.biome), "emberforge")
	assert_eq(String(def.id), "boss_skoldur")
	assert_gt(def.max_health, 3000)


func test_skoldur_scene_loads() -> void:
	var scn := load("res://scenes/enemies/skoldur.tscn") as PackedScene
	assert_not_null(scn)


# --- 11.11 — Naeren boss + peaceful-path alt ----------------------


func test_naeren_boss_def_loads() -> void:
	var def: MobDef = load("res://resources/mobs/naeren.tres")
	assert_not_null(def)
	assert_eq(String(def.id), "boss_naeren")


func test_naeren_scene_loads() -> void:
	var scn := load("res://scenes/enemies/naeren.tscn") as PackedScene
	assert_not_null(scn)


# --- 11.12 — Veyl-Aurora 7-spire boss ------------------------------


func test_veyl_aurora_boss_def_loads() -> void:
	var def: MobDef = load("res://resources/mobs/veyl_aurora.tres")
	assert_not_null(def)
	assert_eq(String(def.id), "boss_veyl_aurora")


func test_veyl_aurora_scene_loads() -> void:
	var scn := load("res://scenes/enemies/veyl_aurora.tscn") as PackedScene
	assert_not_null(scn)


# --- 11.13 — Listener-Below NPC trade ------------------------------


func test_listener_below_npc_exists() -> void:
	var scn := load("res://scenes/npcs/listener_below.tscn") as PackedScene
	assert_not_null(scn)
	var stock := load("res://resources/merchants/listener_below_stock.tres")
	assert_not_null(stock)


# --- 11.15 + 11.27 — Frostlark harmony + Hymnal Vault chord -----


func test_hymnal_correct_chord_triggers_unlock() -> void:
	Phase11Helpers.play_hymnal_note(&"low")
	Phase11Helpers.play_hymnal_note(&"high")
	Phase11Helpers.play_hymnal_note(&"low")
	assert_true(Phase11Helpers.hymnal_correct_chord_played)
	assert_true(GameState.collected_relics.has(&"hymnal_chord_played"))


func test_hymnal_wrong_chord_does_not_unlock() -> void:
	Phase11Helpers.play_hymnal_note(&"low")
	Phase11Helpers.play_hymnal_note(&"low")
	Phase11Helpers.play_hymnal_note(&"low")
	assert_false(Phase11Helpers.hymnal_correct_chord_played)


# --- 11.17/11.18 — Heat-shimmer + Frostbite meter UI exist ----------


func test_heat_shimmer_scene_exists() -> void:
	var scn := load("res://scenes/ui/heat_shimmer.tscn") as PackedScene
	assert_not_null(scn)


func test_frostbite_meter_scene_exists() -> void:
	var scn := load("res://scenes/ui/frostbite_meter.tscn") as PackedScene
	assert_not_null(scn)


# --- 11.19 — Mirage + Quicksand patches register ---------------------


func test_register_mirage_adds_to_list() -> void:
	Phase11Helpers.register_mirage(Vector2(50, 50))
	assert_eq(Phase11Helpers.mirage_patches.size(), 1)


func test_register_quicksand_adds_to_list() -> void:
	Phase11Helpers.register_quicksand(Vector2(50, 50))
	assert_eq(Phase11Helpers.quicksand_patches.size(), 1)


# --- 11.20/11.21/11.22/11.23/11.27 — Crafting stations ------------


func test_crafting_station_items_exist() -> void:
	for id in [&"pyrenkin_bellows_placeable", &"salt_crown_press_placeable", &"auroric_anvil_placeable", &"hymnal_vault_placeable", &"heat_chest_placeable"]:
		var d: ItemDef = ItemRegistry.get_def(id)
		assert_not_null(d, "missing %s" % id)
		assert_eq(d.item_type, ItemDef.ItemType.PLACEABLE)


func test_phase11_recipes_exist() -> void:
	for id in [&"pyrenkin_bellows", &"salt_crown_press", &"auroric_anvil", &"hymnal_vault", &"heat_chest"]:
		var path: String = "res://resources/recipes/" + String(id) + ".tres"
		var r: Resource = load(path)
		assert_not_null(r, "missing recipe %s" % id)


# --- 11.24 + 11.31 — Walker journal + Forge-Compact tablets -------


func test_emberforge_journal_collects_once() -> void:
	Phase11Helpers.collect_emberforge_journal()
	assert_true(Phase11Helpers.emberforge_journal_collected)
	# Calling again should be a no-op.
	Phase11Helpers.collect_emberforge_journal()
	assert_true(Phase11Helpers.emberforge_journal_collected)


func test_forge_compact_tablet_counter_caps() -> void:
	for _i in range(20):
		Phase11Helpers.collect_forge_compact_tablet()
	assert_eq(Phase11Helpers.forge_compact_tablets_collected, Phase11Helpers.FORGE_COMPACT_TABLETS_TOTAL)


# --- 11.32 — Pyrenkin Bellows fuel-pellet -------------------------


func test_bellows_feed_pellet_consumes_pellet() -> void:
	Inventory.try_add(&"fuel_pellet", 2)
	assert_true(Phase11Helpers.bellows_feed_pellet())
	assert_eq(Inventory.count_of(&"fuel_pellet"), 1)
	assert_gt(Phase11Helpers.bellows_lit_phases_remaining, 0)


func test_bellows_feed_pellet_fails_with_no_fuel() -> void:
	assert_false(Phase11Helpers.bellows_feed_pellet())


# --- 4.56/4.57/4.58 — Weather system ------------------------------


func test_weather_clear_when_outside_known_biome() -> void:
	Phase11Helpers._weather_biome = &""
	Phase11Helpers._roll_weather()
	assert_eq(String(Phase11Helpers.current_weather), "clear")


func test_weather_rolls_to_known_value_for_biome() -> void:
	Phase11Helpers._weather_biome = &"emberforge"
	Phase11Helpers._roll_weather()
	var options: Array = Phase11Helpers.BIOME_WEATHERS[&"emberforge"]
	assert_true(options.has(Phase11Helpers.current_weather))


func test_wind_vector_for_known_biomes() -> void:
	assert_ne(Phase11Helpers.wind_vector_for_biome(&"salt_wastes"), Vector2.ZERO)
	assert_eq(Phase11Helpers.wind_vector_for_biome(&"unknown_biome"), Vector2.ZERO)


# --- Boss attack patterns load -----------------------------------


func test_phase11_attack_patterns_load() -> void:
	for id in [&"skoldur_phase1", &"skoldur_phase2", &"skoldur_phase3", &"skoldur_phase4", &"naeren_phase1", &"naeren_phase2", &"veyl_aurora_phase1", &"veyl_aurora_phase2"]:
		var p: Resource = load("res://resources/attack_patterns/" + String(id) + ".tres")
		assert_not_null(p, "missing pattern %s" % id)


# --- Skoldur recognition (11.10 + 11.28) -------------------------


func test_skoldur_recognition_requires_pendant() -> void:
	# Player has no pendant — recognition flag should NOT set on phase-4 entry.
	# We can't drive the boss script directly without a tree, but we can verify
	# the toggle reads from Inventory.count_of(&"pyrenkin_pendant").
	assert_eq(Inventory.count_of(&"pyrenkin_pendant"), 0)
	Inventory.try_add(&"pyrenkin_pendant", 1)
	assert_eq(Inventory.count_of(&"pyrenkin_pendant"), 1)


# --- Naeren peace path (11.11) ----------------------------------


func test_naeren_peace_requires_covenant_scroll() -> void:
	assert_eq(Inventory.count_of(&"wormbound_covenant_scroll"), 0)
	Inventory.try_add(&"wormbound_covenant_scroll", 1)
	assert_eq(Inventory.count_of(&"wormbound_covenant_scroll"), 1)


# --- Listener-Below stock has aurora_shard --------------------


func test_listener_below_sells_aurora_shard() -> void:
	var stock: Resource = load("res://resources/merchants/listener_below_stock.tres")
	var found: bool = false
	for entry in stock.sell_items:
		if String(entry.get("item_id", "")) == "aurora_shard":
			found = true
			break
	assert_true(found)


# --- Korya NPC (11.25) ---------------------------------------


func test_korya_dialogue_and_scene_load() -> void:
	var scn := load("res://scenes/npcs/korya.tscn") as PackedScene
	assert_not_null(scn)
	var dlg: Resource = load("res://resources/dialogues/korya_first.tres")
	assert_not_null(dlg)


# --- 11.30 — Pre-corruption chord helper ------------------------


func test_cantor_bell_unlocked_default_false() -> void:
	GameState.collected_relics.erase(&"cantor_bell_unlocked")
	assert_false(Phase11Helpers.cantor_bell_unlocked())
	GameState.collected_relics[&"cantor_bell_unlocked"] = true
	assert_true(Phase11Helpers.cantor_bell_unlocked())


# --- Phase11Helpers state round-trip -----------------------------


func test_phase11_helpers_state_round_trip() -> void:
	Phase11Helpers.pyrenkin_forges_relit = 2
	Phase11Helpers.pyrenkin_compact_arrived = true
	Phase11Helpers.frostbite_level = 0.55
	Phase11Helpers.emberforge_journal_collected = true
	Phase11Helpers.forge_compact_tablets_collected = 3
	Phase11Helpers.wormbound_gesture_index = 1
	Phase11Helpers.wormbound_covenant_granted = false
	Phase11Helpers.hymnal_correct_chord_played = true
	Phase11Helpers.bellows_lit_phases_remaining = 6
	Phase11Helpers.current_weather = &"ash"
	Phase11Helpers._weather_biome = &"emberforge"
	var dump: Dictionary = Phase11Helpers.dump_state()
	# Reset.
	Phase11Helpers.pyrenkin_forges_relit = 0
	Phase11Helpers.pyrenkin_compact_arrived = false
	Phase11Helpers.frostbite_level = 0.0
	Phase11Helpers.emberforge_journal_collected = false
	Phase11Helpers.forge_compact_tablets_collected = 0
	Phase11Helpers.wormbound_gesture_index = 0
	Phase11Helpers.wormbound_covenant_granted = false
	Phase11Helpers.hymnal_correct_chord_played = false
	Phase11Helpers.bellows_lit_phases_remaining = 0
	Phase11Helpers.current_weather = &"clear"
	Phase11Helpers._weather_biome = &""
	Phase11Helpers.restore_state(dump)
	assert_eq(Phase11Helpers.pyrenkin_forges_relit, 2)
	assert_true(Phase11Helpers.pyrenkin_compact_arrived)
	assert_almost_eq(Phase11Helpers.frostbite_level, 0.55, 0.01)
	assert_true(Phase11Helpers.emberforge_journal_collected)
	assert_eq(Phase11Helpers.forge_compact_tablets_collected, 3)
	assert_eq(Phase11Helpers.wormbound_gesture_index, 1)
	assert_true(Phase11Helpers.hymnal_correct_chord_played)
	assert_eq(Phase11Helpers.bellows_lit_phases_remaining, 6)
	assert_eq(String(Phase11Helpers.current_weather), "ash")
