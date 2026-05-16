extends GutTest

## Phase 10 systems test bundle. Verifies the biomes 3-5 + bosses 2-6 +
## swimming + breath + hazards + tile-hazards + new equipment + lore moments
## + Glow-Crane sub-quest + Phase10Helpers persistence.


func before_each() -> void:
	GameState.defeated_bosses.clear()
	GameState.collected_relics.clear()
	Inventory.clear()
	if Phase10Helpers:
		Phase10Helpers.boss_cooldowns.clear()
		Phase10Helpers.kill_counts.clear()
		Phase10Helpers.awakened_available.clear()
		Phase10Helpers.lore_moments_fired.clear()
		Phase10Helpers.verdancy_age_beats = 0
		Phase10Helpers.sunken_glyph_fragments_collected = 0
		Phase10Helpers.glow_crane_quest_state = &"locked"
		Phase10Helpers.glow_crane_feathers_delivered = 0


# --- 10.1/10.2/10.3 — biome resources load with Phase 10 mob tables --------


func test_vesari_biome_mob_spawn_table() -> void:
	var b: BiomeDef = load("res://resources/biomes/vesari_necropolis.tres")
	assert_not_null(b)
	assert_true(b.mob_spawn_table.has(&"salt_bound_sailor"))
	assert_true(b.mob_spawn_table.has(&"coral_hollow"))
	assert_eq(String(b.hazard_id), "salt_corrosion")


func test_verdancy_biome_mob_spawn_table() -> void:
	var b: BiomeDef = load("res://resources/biomes/sunless_verdancy.tres")
	assert_true(b.mob_spawn_table.has(&"spore_lurk"))
	assert_true(b.mob_spawn_table.has(&"vine_stalker"))
	assert_true(b.mob_spawn_table.has(&"bloom_hag"))
	assert_eq(String(b.hazard_id), "toxic_spore")
	assert_eq(String(b.resist_item_id), "gas_mask")


func test_drowned_biome_mob_spawn_table() -> void:
	var b: BiomeDef = load("res://resources/biomes/drowned_aphelion.tres")
	assert_true(b.mob_spawn_table.has(&"deep_mawl"))
	assert_true(b.mob_spawn_table.has(&"hollow_coral"))
	assert_true(b.mob_spawn_table.has(&"wreck_wraith"))
	assert_eq(String(b.resist_item_id), "coral_veil")


# --- 10.4/10.5/10.6 — mob defs load + map to expected biome --------------


func test_vesari_mob_defs_load() -> void:
	for id in [&"salt_bound_sailor", &"salt_bound_captain", &"coral_hollow", &"tideglass_cricket", &"salt_fox"]:
		var def: MobDef = Phase10Helpers.mob_def_for(id)
		assert_not_null(def, "missing mob def %s" % id)
		assert_eq(String(def.biome), "vesari_necropolis")


func test_verdancy_mob_defs_load() -> void:
	for id in [&"spore_lurk", &"vine_stalker", &"bloom_hag", &"verdant_hare", &"glow_crane"]:
		var def: MobDef = Phase10Helpers.mob_def_for(id)
		assert_not_null(def, "missing mob def %s" % id)
		assert_eq(String(def.biome), "sunless_verdancy")


func test_drowned_mob_defs_load() -> void:
	for id in [&"deep_mawl", &"hollow_coral", &"wreck_wraith", &"lantern_squid", &"brinekin"]:
		var def: MobDef = Phase10Helpers.mob_def_for(id)
		assert_not_null(def, "missing mob def %s" % id)
		assert_eq(String(def.biome), "drowned_aphelion")


func test_critters_use_flee_behavior() -> void:
	# All friendly critters should have CRITTER_FLEE (value 5) and zero contact damage.
	for id in [&"tideglass_cricket", &"salt_fox", &"verdant_hare", &"glow_crane", &"lantern_squid", &"brinekin"]:
		var def: MobDef = Phase10Helpers.mob_def_for(id)
		assert_eq(def.behavior, MobDef.Behavior.CRITTER_FLEE, "%s is not CRITTER_FLEE" % id)
		assert_eq(def.contact_damage, 0)


# --- 10.7/10.8 — swim mechanic + breath items -----------------------------


func test_coral_veil_item_exists() -> void:
	var d: ItemDef = ItemRegistry.get_def(&"coral_veil")
	assert_not_null(d)
	assert_true(d.resonance_bound)
	assert_eq(String(d.equipment_slot), "helmet")


func test_underwater_goggles_item_exists() -> void:
	var d: ItemDef = ItemRegistry.get_def(&"underwater_goggles")
	assert_not_null(d)
	assert_eq(String(d.equipment_slot), "helmet")


# --- 10.15/10.16 — biome hazards apply ------------------------------------


func test_verdancy_resist_item_gas_mask() -> void:
	var b: BiomeDef = load("res://resources/biomes/sunless_verdancy.tres")
	assert_eq(String(b.resist_item_id), "gas_mask")


func test_necropolis_hazard_is_salt_corrosion() -> void:
	var b: BiomeDef = load("res://resources/biomes/vesari_necropolis.tres")
	assert_eq(String(b.hazard_id), "salt_corrosion")
	assert_eq(String(b.hazard_damage_type), "physical")


# --- 10.17 — boss respawn cooldown ----------------------------------------


func test_boss_defeat_starts_cooldown() -> void:
	GameState.mark_boss_defeated(&"boss_vorrkell")
	# Phase10Helpers._on_boss_defeated subscribes through EventBus.boss_defeated.
	# Drive it directly so we don't depend on signal timing in headless tests.
	Phase10Helpers._on_boss_defeated(&"boss_vorrkell")
	assert_gt(Phase10Helpers.cooldown_remaining_beats(&"boss_vorrkell"), 0)


# --- 10.18 — Awakened variant unlocks after first kill --------------------


func test_second_kill_unlocks_awakened() -> void:
	Phase10Helpers._on_boss_defeated(&"boss_sythrenn")
	assert_false(bool(Phase10Helpers.awakened_available.get(&"boss_sythrenn", false)))
	Phase10Helpers._on_boss_defeated(&"boss_sythrenn")
	assert_true(bool(Phase10Helpers.awakened_available.get(&"boss_sythrenn", false)))
	var cfg: Dictionary = Phase10Helpers.awakened_config(&"boss_sythrenn")
	assert_gt(float(cfg.get("hp_mult", 1.0)), 1.0)


# --- 10.19 — Pack-AI biased spawn (helper exists) -------------------------


func test_pheromone_present_within_radius() -> void:
	Phase10Helpers.emit_pheromone(Vector2(100, 100), &"vesari_necropolis")
	assert_true(Phase10Helpers.pheromone_present(Vector2(120, 120), &"vesari_necropolis"))
	assert_false(Phase10Helpers.pheromone_present(Vector2(800, 800), &"vesari_necropolis"))


# --- 10.27 — Vine wall-climb scoped to Verdancy ---------------------------


func test_climb_walls_helper_biome_check() -> void:
	# Without a running WorldGen the helper returns false.
	assert_false(Phase10Helpers.can_climb_walls_here(Vector2(50, 50)))


# --- 10.29/10.30/10.31/10.32 — Equipment defs exist -----------------------


func test_resistance_equipment_defs() -> void:
	for id in [&"underwater_goggles", &"lava_boots", &"frost_boots", &"gas_mask"]:
		var d: ItemDef = ItemRegistry.get_def(id)
		assert_not_null(d, "missing %s" % id)
		assert_ne(String(d.equipment_slot), "")


func test_lava_boots_give_fire_resist() -> void:
	var d: ItemDef = ItemRegistry.get_def(&"lava_boots")
	assert_gt(float(d.status_resists.get("fire", 0.0)), 0.0)


# --- 10.34 — per-biome affix bias table -----------------------------------


func test_biome_affix_bias_present() -> void:
	assert_true(not Phase10Helpers.biome_affix_bias(&"sunless_verdancy").is_empty())
	assert_true(not Phase10Helpers.biome_affix_bias(&"vesari_necropolis").is_empty())


# --- 10.42 — Sunken Glyph collection finishes at 7 ------------------------


func test_sunken_glyph_collection_caps() -> void:
	for _i in range(10):
		Phase10Helpers.register_sunken_glyph()
	assert_eq(Phase10Helpers.sunken_glyph_fragments_collected, 7)
	assert_true(bool(Phase10Helpers.lore_moments_fired.get(&"hall_of_first_names_unlocked", false)))


# --- 10.46 — Glow-Crane sub-quest --------------------------------------


func test_glow_crane_quest_flow() -> void:
	Phase10Helpers.unlock_glow_crane_quest()
	assert_eq(String(Phase10Helpers.glow_crane_quest_state), "active")
	Phase10Helpers.deliver_glow_crane_feathers(2)
	assert_eq(String(Phase10Helpers.glow_crane_quest_state), "active")
	var ok: bool = Phase10Helpers.deliver_glow_crane_feathers(1)
	assert_true(ok)
	assert_eq(String(Phase10Helpers.glow_crane_quest_state), "done")
	assert_gt(Inventory.count_of(&"vorrkell_lantern"), 0)


# --- 10.48 — Sythrenn spore-zone registration scoped to active boss -------


func test_spore_zones_require_active_boss() -> void:
	Phase10Helpers.sythrenn_active = false
	Phase10Helpers.register_sythrenn_spore_zone(Vector2(0, 0))
	assert_eq(Phase10Helpers.sythrenn_spore_zones.size(), 0)
	Phase10Helpers.sythrenn_active = true
	Phase10Helpers.register_sythrenn_spore_zone(Vector2(0, 0))
	assert_eq(Phase10Helpers.sythrenn_spore_zones.size(), 1)


# --- 10.49 — Boss cinematic camera lookup ---------------------------------


func test_cinematic_camera_lookup() -> void:
	var c: Dictionary = Phase10Helpers.cinematic_camera_for(&"boss_auriax", 2)
	assert_true(c.has("shake"))
	assert_gt(float(c.get("zoom", 1.0)), 1.0)
	var none: Dictionary = Phase10Helpers.cinematic_camera_for(&"boss_glaurem", 0)
	assert_eq(none.size(), 0)


# --- 10.50 — Per-biome reverb routes through AudioBus.apply_reverb_profile -


func test_reverb_profile_applied_on_biome_change() -> void:
	AudioBus.current_reverb_profile = {}
	# Manually trigger the helper's biome listener for headless tests.
	Phase10Helpers._on_biome_changed(&"root_hollows", &"vesari_necropolis")
	assert_eq(int(AudioBus.current_reverb_profile.get("room_size", 0) * 100), 75)


# --- Persistence ---------------------------------------------------------


func test_phase10_helpers_state_round_trip() -> void:
	Phase10Helpers.boss_cooldowns[&"boss_auriax"] = 12
	Phase10Helpers.kill_counts[&"boss_auriax"] = 1
	Phase10Helpers.awakened_available[&"boss_auriax"] = true
	Phase10Helpers.verdancy_age_beats = 50
	Phase10Helpers.sunken_glyph_fragments_collected = 3
	Phase10Helpers.glow_crane_quest_state = &"active"
	Phase10Helpers.glow_crane_feathers_delivered = 2
	var dump: Dictionary = Phase10Helpers.dump_state()
	# Reset.
	Phase10Helpers.boss_cooldowns.clear()
	Phase10Helpers.kill_counts.clear()
	Phase10Helpers.awakened_available.clear()
	Phase10Helpers.verdancy_age_beats = 0
	Phase10Helpers.sunken_glyph_fragments_collected = 0
	Phase10Helpers.glow_crane_quest_state = &"locked"
	Phase10Helpers.glow_crane_feathers_delivered = 0
	Phase10Helpers.restore_state(dump)
	assert_eq(int(Phase10Helpers.boss_cooldowns.get(&"boss_auriax", 0)), 12)
	assert_eq(int(Phase10Helpers.kill_counts.get(&"boss_auriax", 0)), 1)
	assert_eq(Phase10Helpers.verdancy_age_beats, 50)
	assert_eq(Phase10Helpers.sunken_glyph_fragments_collected, 3)
	assert_eq(String(Phase10Helpers.glow_crane_quest_state), "active")
	assert_eq(Phase10Helpers.glow_crane_feathers_delivered, 2)


# --- 10.9/10.10/10.11/10.12/10.13/10.14 — Boss mob defs all resolve -------


func test_phase10_boss_defs_exist() -> void:
	for id in [&"boss_vorrkell", &"boss_spawnmother", &"boss_sythrenn", &"boss_auriax", &"boss_volthaar", &"boss_drowned_crown"]:
		# Boss defs are .tres in resources/mobs/ named *.tres.
		var path: String = "res://resources/mobs/" + String(id).replace("boss_", "") + ".tres"
		var d: MobDef = load(path) as MobDef
		assert_not_null(d, "missing boss def at %s" % path)
		assert_gt(d.max_health, 100)


# --- 10.11 — Sythrenn mercy-kill default -----------------------------------


func test_sythrenn_default_kill_not_mercy() -> void:
	# Fresh boss scene starts with mercy_killed = false.
	var scn := load("res://scenes/enemies/sythrenn.tscn") as PackedScene
	assert_not_null(scn)
	var inst := scn.instantiate()
	assert_eq(bool(inst.get("mercy_killed")), false)
	inst.free()


# --- 10.13 — Vol'thaar release flag default --------------------------------


func test_volthaar_release_default() -> void:
	var scn := load("res://scenes/enemies/volthaar.tscn") as PackedScene
	assert_not_null(scn)
	var inst := scn.instantiate()
	assert_eq(bool(inst.get("released")), false)
	inst.free()


# --- 10.44 — Larva trap default not triggered -----------------------------


func test_larva_trap_default_state() -> void:
	var scn := load("res://scenes/structures/larva_trap.tscn") as PackedScene
	assert_not_null(scn)
	var inst := scn.instantiate()
	assert_eq(bool(inst.get("triggered")), false)
	var dump: Dictionary = inst.call("dump_state")
	assert_false(bool(dump.get("triggered", true)))
	inst.free()
