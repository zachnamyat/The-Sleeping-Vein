extends GutTest

## Phase 12 systems test bundle. Verifies the Final Spiral biome + Diadem
## mobs + Diadem-Bearer boss + Aphelion bullet-hell + 3-endings UI + Phase12
## Helpers persistence + Reliquary conversion + density curve.


func before_each() -> void:
	GameState.defeated_bosses.clear()
	GameState.collected_relics.clear()
	GameState.unlocked_recipes.clear()
	GameState.unlocked_compendium.clear()
	GameState.arrived_npcs.clear()
	GameState.sovereign_threads = 0
	GameState.aphelion_slivers_remaining = GameState.APHELION_STARTING_SLIVERS
	GameState.ng_plus = false
	GameState.ng_plus_cycles = 0
	Inventory.clear()
	if Phase12Helpers:
		Phase12Helpers.vacancy_appeared_flag = false
		Phase12Helpers.vacancy_encounter_completed = false
		Phase12Helpers.elision_fragments_collected = 0
		Phase12Helpers.elided_name_revealed = false
		Phase12Helpers.manifestos_read.clear()
		Phase12Helpers.loom_twin_discovered = false
		Phase12Helpers.selected_ending = &""
		Phase12Helpers.endings_taken_history.clear()
		Phase12Helpers.aphelion_chamber_path_locked_in = false
		Phase12Helpers.reliquary_conversions_performed = 0
		Phase12Helpers.wave_spawn_total = 0
		Phase12Helpers.lamp_before_lamp_revealed = false
		Phase12Helpers.footstep_echo_active = false
		Phase12Helpers.bearer_self_shatter_played = false
		Phase12Helpers.aphelion_apology_revealed_flag = false
		Phase12Helpers.listener_mask_revealed_flag = false
		Phase12Helpers.final_act_commentary_spoken.clear()
		Phase12Helpers.bearer_child_tablet_read = false
		Phase12Helpers.compendium_reward_granted = false
		Phase12Helpers.joren_name_revealed = false
		Phase12Helpers.mira_sibling_scene_played = false
		Phase12Helpers.walker_epilogue_emote_played = false
		Phase12Helpers.mote_tide_active = false


# --- 12.1 — Final Spiral biome resource -------------------------------------


func test_final_spiral_biome_loads() -> void:
	var b: BiomeDef = load("res://resources/biomes/final_spiral.tres")
	assert_not_null(b)
	assert_eq(String(b.id), "final_spiral")
	assert_eq(b.stratum_index, 9)


func test_final_spiral_mob_table_includes_diadem_agents() -> void:
	var b: BiomeDef = load("res://resources/biomes/final_spiral.tres")
	assert_true(b.mob_spawn_table.has(&"diadem_reader"))
	assert_true(b.mob_spawn_table.has(&"diadem_censer"))
	assert_true(b.mob_spawn_table.has(&"diadem_warden"))
	assert_true(b.mob_spawn_table.has(&"pure_hollowling_mote"))


# --- 12.2 — Diadem mob defs --------------------------------------------------


func test_diadem_reader_mob_def_loads() -> void:
	var m: MobDef = load("res://resources/mobs/diadem_reader.tres") as MobDef
	assert_not_null(m)
	assert_eq(String(m.biome), "final_spiral")
	assert_true(m.weaknesses.has("lightning"))


func test_diadem_warden_is_tank_class() -> void:
	var m: MobDef = load("res://resources/mobs/diadem_warden.tres") as MobDef
	assert_eq(m.mob_class, MobDef.MobClass.TANK)
	assert_gt(m.max_health, 200)


func test_diadem_censer_is_caster_class() -> void:
	var m: MobDef = load("res://resources/mobs/diadem_censer.tres") as MobDef
	assert_eq(m.mob_class, MobDef.MobClass.CASTER)


# --- 12.3 — Pure Hollowling Mote --------------------------------------------


func test_pure_hollowling_mote_def_loads() -> void:
	var m: MobDef = load("res://resources/mobs/pure_hollowling_mote.tres") as MobDef
	assert_not_null(m)
	assert_gt(m.move_speed, 60.0)
	assert_true(m.weaknesses.has("fire"))


func test_mote_tide_starts_and_ends() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	assert_false(Phase12Helpers.mote_tide_active)
	Phase12Helpers.start_mote_tide()
	assert_true(Phase12Helpers.mote_tide_active)
	Phase12Helpers.end_mote_tide()
	assert_false(Phase12Helpers.mote_tide_active)


# --- 12.4 — Vacancy ---------------------------------------------------------


func test_vacancy_def_loads_with_zero_damage() -> void:
	var m: MobDef = load("res://resources/mobs/vacancy.tres") as MobDef
	assert_not_null(m)
	assert_eq(m.contact_damage, 0)


func test_vacancy_appearance_flags() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	assert_false(Phase12Helpers.vacancy_appeared_flag)
	Phase12Helpers.make_vacancy_appear()
	assert_true(Phase12Helpers.vacancy_appeared_flag)
	assert_false(Phase12Helpers.vacancy_encounter_completed)
	Phase12Helpers.complete_vacancy_encounter()
	assert_true(Phase12Helpers.vacancy_encounter_completed)


# --- 12.5 + 12.30 — Elision-Script puzzle -----------------------------------


func test_elision_fragments_accumulate_to_reveal() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	for i in range(4):
		Phase12Helpers.collect_elision_fragment()
	assert_eq(Phase12Helpers.elision_fragments_collected, 4)
	assert_true(Phase12Helpers.elided_name_revealed)
	assert_eq(Phase12Helpers.elided_name_string(), "VAEL-IOR-RI-ON")


func test_elision_partial_does_not_reveal() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	Phase12Helpers.collect_elision_fragment()
	Phase12Helpers.collect_elision_fragment()
	assert_false(Phase12Helpers.elided_name_revealed)
	assert_eq(Phase12Helpers.elided_name_string(), "VAEL-IOR-___-___")


# --- 12.6 + 12.14 — Manifestos ---------------------------------------------


func test_manifesto_read_tracking() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	for i in range(8):
		Phase12Helpers.mark_manifesto_read(i)
	assert_eq(Phase12Helpers.manifestos_read_count(), 8)
	assert_true(Phase12Helpers.all_manifestos_read())


func test_manifesto_read_is_idempotent() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	Phase12Helpers.mark_manifesto_read(0)
	Phase12Helpers.mark_manifesto_read(0)
	Phase12Helpers.mark_manifesto_read(0)
	assert_eq(Phase12Helpers.manifestos_read_count(), 1)


# --- 12.7 — Loom's Twin -----------------------------------------------------


func test_loom_twin_discovery() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	assert_false(Phase12Helpers.loom_twin_discovered)
	Phase12Helpers.discover_loom_twin()
	assert_true(Phase12Helpers.loom_twin_discovered)
	assert_true(bool(GameState.collected_relics.get(&"loom_twin", false)))


# --- 12.8 — Diadem-Bearer ---------------------------------------------------


func test_diadem_bearer_def_loads() -> void:
	var m: MobDef = load("res://resources/mobs/diadem_bearer.tres") as MobDef
	assert_not_null(m)
	assert_gt(m.max_health, 5000)


func test_diadem_bearer_scene_loads() -> void:
	var scn := load("res://scenes/enemies/diadem_bearer.tscn") as PackedScene
	assert_not_null(scn)


func test_diadem_bearer_attack_patterns_load() -> void:
	for i in range(4):
		var p: AttackPattern = load("res://resources/attack_patterns/diadem_bearer_phase%d.tres" % (i + 1)) as AttackPattern
		assert_not_null(p, "missing phase%d pattern" % (i + 1))
		assert_eq(p.phase_index, i)


# --- 12.10 — Aphelion bullet-hell ------------------------------------------


func test_aphelion_def_loads() -> void:
	var m: MobDef = load("res://resources/mobs/aphelion.tres") as MobDef
	assert_not_null(m)
	assert_eq(String(m.id), "boss_aphelion")


func test_aphelion_scene_loads() -> void:
	var scn := load("res://scenes/enemies/aphelion.tscn") as PackedScene
	assert_not_null(scn)


func test_aphelion_apology_reveal() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	assert_false(Phase12Helpers.aphelion_apology_revealed_flag)
	Phase12Helpers.reveal_aphelion_apology()
	assert_true(Phase12Helpers.aphelion_apology_revealed_flag)


# --- 12.9-12.11 + 12.17 + 12.18 — Endings ----------------------------------


func test_ending_c_requires_all_conditions() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	# Nothing met → false.
	assert_false(Phase12Helpers.ending_c_unlocked())
	# Even with 9 threads, still missing other conditions.
	GameState.sovereign_threads = 9
	assert_false(Phase12Helpers.ending_c_unlocked())
	# Add all the relics + flags.
	GameState.collected_relics[&"naeren_peace"] = true
	GameState.collected_relics[&"volthaar_released"] = true
	GameState.collected_relics[&"sythrenn_mercy"] = true
	Phase12Helpers.elided_name_revealed = true
	Phase12Helpers.loom_twin_discovered = true
	assert_true(Phase12Helpers.ending_c_unlocked())


func test_commit_ending_restore_is_idempotent() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	assert_true(Phase12Helpers.commit_ending(Phase12Helpers.ENDING_RESTORE))
	# Second commit should fail because path is now locked in.
	assert_false(Phase12Helpers.commit_ending(Phase12Helpers.ENDING_BREAK))
	assert_eq(String(Phase12Helpers.selected_ending), "ending_restore")


func test_ending_c_blocked_without_unlock() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	assert_false(Phase12Helpers.commit_ending(Phase12Helpers.ENDING_BECOME))
	assert_eq(String(Phase12Helpers.selected_ending), "")


# --- 12.13 — NG+ flag --------------------------------------------------------


func test_new_game_plus_increments_cycle() -> void:
	GameState.ng_plus_cycles = 0
	GameState.start_new_game_plus()
	assert_eq(GameState.ng_plus_cycles, 1)
	assert_true(GameState.ng_plus)


# --- 12.15 + 12.34 — Endings history ---------------------------------------


func test_endings_taken_history_persists_across_endings() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	Phase12Helpers.commit_ending(Phase12Helpers.ENDING_RESTORE)
	assert_true(Phase12Helpers.has_taken_ending(Phase12Helpers.ENDING_RESTORE))
	# Simulate NG+ — unlock + reset path lock.
	Phase12Helpers.aphelion_chamber_path_locked_in = false
	Phase12Helpers.selected_ending = &""
	Phase12Helpers.commit_ending(Phase12Helpers.ENDING_BREAK)
	assert_true(Phase12Helpers.has_taken_ending(Phase12Helpers.ENDING_BREAK))
	assert_eq(Phase12Helpers.endings_taken_history.size(), 2)


# --- 12.16 — Density curve --------------------------------------------------


func test_density_multiplier_for_distance_caps_at_3x() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	# Inside the Anchor area → 1.0.
	assert_almost_eq(Phase12Helpers.density_multiplier_for_distance(0.0), 1.0, 0.01)
	# Just past Final Spiral edge → still close to 1.0.
	assert_almost_eq(Phase12Helpers.density_multiplier_for_distance(640.0), 1.0, 0.01)
	# Far inside Final Spiral → capped at 3.0.
	assert_almost_eq(Phase12Helpers.density_multiplier_for_distance(10000.0), 3.0, 0.01)


# --- 12.19 + 12.20 + 12.21 — Diadem Reliquary ------------------------------


func test_reliquary_conversion_requires_inputs() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	# No ore → can't convert.
	assert_false(Phase12Helpers.can_reliquary_convert(&"auroric_ice_ore", 1))
	# Add ore but no catalyst → still can't.
	Inventory.try_add(&"auroric_ice_ore", 4)
	assert_false(Phase12Helpers.can_reliquary_convert(&"auroric_ice_ore", 1))
	# Add catalyst → can convert.
	Inventory.try_add(&"aphelion_shard", 1)
	assert_true(Phase12Helpers.can_reliquary_convert(&"auroric_ice_ore", 1))


func test_reliquary_convert_produces_higher_ore() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	Inventory.try_add(&"auroric_ice_ore", 8)
	Inventory.try_add(&"aphelion_shard", 2)
	var produced: int = Phase12Helpers.reliquary_convert(&"auroric_ice_ore", &"diadem_gold_ore", 2)
	assert_eq(produced, 2)
	assert_eq(Inventory.count_of(&"diadem_gold_ore"), 2)
	assert_eq(Inventory.count_of(&"auroric_ice_ore"), 0)
	assert_eq(Inventory.count_of(&"aphelion_shard"), 0)


# --- 12.20 — Diadem Reliquary recipe ---------------------------------------


func test_diadem_reliquary_recipe_loads() -> void:
	var r: Recipe = load("res://resources/recipes/diadem_reliquary.tres") as Recipe
	assert_not_null(r)
	assert_eq(String(r.id), "craft_diadem_reliquary")
	assert_eq(r.outputs.size(), 1)


func test_diadem_gold_ingot_recipe_uses_aphelion_catalyst() -> void:
	var r: Recipe = load("res://resources/recipes/diadem_gold_ingot.tres") as Recipe
	assert_not_null(r)
	var ids: Array = []
	for inp in r.inputs:
		ids.append(String(inp.get("item_id", "")))
	assert_true(ids.has("aphelion_shard"))


# --- 12.22 — Wave spawn tracker --------------------------------------------


func test_wave_spawn_total_starts_zero() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	assert_eq(Phase12Helpers.wave_spawn_total, 0)


# --- 12.24 — Lamp before the lamp ------------------------------------------


func test_lamp_before_lamp_reveal_idempotent() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	Phase12Helpers.reveal_lamp_before_lamp()
	assert_true(Phase12Helpers.lamp_before_lamp_revealed)
	Phase12Helpers.reveal_lamp_before_lamp()
	assert_true(Phase12Helpers.lamp_before_lamp_revealed)


# --- 12.26 — Self-shatter cinematic flag -----------------------------------


func test_bearer_self_shatter_flag_starts_false() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	assert_false(Phase12Helpers.bearer_self_shatter_played)


# --- 12.28 — Listener mask reveal ------------------------------------------


func test_listener_mask_reveal_sets_flag_and_relic() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	Phase12Helpers.reveal_listener_mask()
	assert_true(Phase12Helpers.listener_mask_revealed_flag)
	assert_true(bool(GameState.collected_relics.get(&"listener_mask_revealed", false)))


# --- 12.32 — Bearer child tablet -------------------------------------------


func test_bearer_child_tablet_read_idempotent() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	Phase12Helpers.read_bearer_child_tablet()
	assert_true(Phase12Helpers.bearer_child_tablet_read)
	Phase12Helpers.read_bearer_child_tablet()
	assert_true(Phase12Helpers.bearer_child_tablet_read)


# --- 12.33 — Compendium completion reward ----------------------------------


func test_compendium_reward_requires_enough_entries() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	GameState.unlocked_compendium.clear()
	# Below threshold — no reward.
	assert_false(Phase12Helpers.try_grant_compendium_reward())
	# Bump entries past 40.
	for i in range(45):
		GameState.unlocked_compendium[StringName("entry_%d" % i)] = true
	assert_true(Phase12Helpers.try_grant_compendium_reward())
	assert_true(Phase12Helpers.compendium_reward_granted)
	# Second call returns false (idempotent).
	assert_false(Phase12Helpers.try_grant_compendium_reward())


# --- 12.36 — Joren name reveal ---------------------------------------------


func test_joren_reveal_idempotent() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	Phase12Helpers.reveal_joren_name()
	assert_true(Phase12Helpers.joren_name_revealed)


# --- 12.37 — Mira sibling scene gating -------------------------------------


func test_mira_sibling_scene_requires_joren_and_tablet() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	# Without prerequisites, scene does not play.
	assert_false(Phase12Helpers.try_play_mira_sibling_scene())
	# Add prerequisites.
	Phase12Helpers.joren_name_revealed = true
	Phase12Helpers.bearer_child_tablet_read = true
	# Still requires Mira friendship — without NpcLifecycle stub, fails gracefully.
	if NpcLifecycle and NpcLifecycle.has_method("get_friendship"):
		# In a fresh save, friendship is 0 → still false.
		assert_false(Phase12Helpers.try_play_mira_sibling_scene())


# --- 12.38 — Walker epilogue emote -----------------------------------------


func test_walker_epilogue_emote_can_be_played() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	assert_false(Phase12Helpers.walker_epilogue_emote_played)
	Phase12Helpers.play_walker_epilogue_emote()
	assert_true(Phase12Helpers.walker_epilogue_emote_played)


# --- Save round-trip -------------------------------------------------------


func test_phase12_state_round_trip() -> void:
	if Phase12Helpers == null:
		pending("Phase12Helpers autoload missing")
		return
	Phase12Helpers.collect_elision_fragment()
	Phase12Helpers.collect_elision_fragment()
	Phase12Helpers.discover_loom_twin()
	Phase12Helpers.mark_manifesto_read(3)
	Phase12Helpers.mark_manifesto_read(5)
	Phase12Helpers.bearer_child_tablet_read = true
	Phase12Helpers.joren_name_revealed = true
	Phase12Helpers.endings_taken_history.append(&"ending_restore")
	var dumped: Dictionary = Phase12Helpers.dump_state()
	# Wipe state.
	Phase12Helpers.elision_fragments_collected = 0
	Phase12Helpers.loom_twin_discovered = false
	Phase12Helpers.manifestos_read.clear()
	Phase12Helpers.bearer_child_tablet_read = false
	Phase12Helpers.joren_name_revealed = false
	Phase12Helpers.endings_taken_history.clear()
	# Restore.
	Phase12Helpers.restore_state(dumped)
	assert_eq(Phase12Helpers.elision_fragments_collected, 2)
	assert_true(Phase12Helpers.loom_twin_discovered)
	assert_eq(Phase12Helpers.manifestos_read_count(), 2)
	assert_true(Phase12Helpers.bearer_child_tablet_read)
	assert_true(Phase12Helpers.joren_name_revealed)
	assert_true(Phase12Helpers.has_taken_ending(&"ending_restore"))


# --- Items load ------------------------------------------------------------


func test_phase12_items_load() -> void:
	for id in [
		&"aphelion_shard",
		&"diadem_gold_ore",
		&"diadem_gold_ingot",
		&"shattered_diadem",
		&"elision_script_fragment",
		&"diadem_gold_plate",
		&"bearers_pre_diadem_name",
		&"cantors_compass",
		&"diadem_reliquary_placeable",
		&"loom_twin_placeable",
		&"diadem_bearer_sword",
		&"sovereign_name_fragment_11",
		&"sovereign_name_fragment_12",
	]:
		var path: String = "res://resources/items/" + String(id) + ".tres"
		var i: ItemDef = load(path) as ItemDef
		assert_not_null(i, "missing item def %s" % id)
		assert_eq(String(i.id), String(id))


# --- Save format version ---------------------------------------------------


func test_save_format_version_at_least_10() -> void:
	# Phase 12 introduced v10. Later phases (Phase 13 → v11) bumped it further.
	# Assert >= so this test survives subsequent phase closures without churn.
	assert_gte(SaveSystem.SAVE_VERSION, 10)
