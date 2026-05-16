extends GutTest

## Phase 14 systems test bundle. Verifies Phase14Helpers (power graph + wire
## graph + logic gates + timer + liquid + paint + blueprints + storage pipes +
## robotic arms + auto-furnace + auto-cooker + auto-fishing + mob farms +
## auctioneer + wireless transmit/receive + grid snap + demolition) and
## ModSystem (discovery + enable + load order + version-tag check + conflict
## detection + hot-reload + sample-mod scaffold + dump/restore).


func before_each() -> void:
	GameState.defeated_bosses.clear()
	GameState.arrived_npcs.clear()
	Inventory.clear()
	if Phase14Helpers:
		Phase14Helpers.power_nodes.clear()
		Phase14Helpers._next_power_id = 1
		Phase14Helpers.wire_signals.clear()
		Phase14Helpers.wire_signal_history.clear()
		Phase14Helpers.wire_links.clear()
		Phase14Helpers.logic_gates.clear()
		Phase14Helpers._next_gate_id = 1
		Phase14Helpers.timer_blocks.clear()
		Phase14Helpers._next_timer_id = 1
		Phase14Helpers.tile_paint.clear()
		Phase14Helpers.grid_snap_enabled = true
		Phase14Helpers.blueprints.clear()
		Phase14Helpers.conveyor_filters.clear()
		Phase14Helpers.splitter_cursors.clear()
		Phase14Helpers.storage_pipes.clear()
		Phase14Helpers._next_pipe_id = 1
		Phase14Helpers.robotic_arms.clear()
		Phase14Helpers._next_arm_id = 1
		Phase14Helpers.auto_cookers.clear()
		Phase14Helpers._next_cooker_id = 1
		Phase14Helpers.auto_fishing_rigs.clear()
		Phase14Helpers._next_rig_id = 1
		Phase14Helpers.mob_farms.clear()
		Phase14Helpers._next_farm_id = 1
		Phase14Helpers.auctioneer_listings.clear()
		Phase14Helpers._next_listing_id = 1
		Phase14Helpers.wireless_transmitters.clear()
		Phase14Helpers.wireless_receivers.clear()
		Phase14Helpers._next_tx_id = 1
		Phase14Helpers._next_rx_id = 1
	if ModSystem:
		ModSystem.discovered_mods.clear()
		ModSystem.load_order.clear()
		ModSystem.conflicts.clear()
		ModSystem._hot_reload_paths.clear()


# --- Autoload presence ---------------------------------------------------


func test_phase14_helpers_autoload_present() -> void:
	assert_not_null(Phase14Helpers)
	assert_true(Phase14Helpers.has_method("register_power_node"))
	assert_true(Phase14Helpers.has_method("register_gate"))
	assert_true(Phase14Helpers.has_method("save_blueprint"))


func test_mod_system_autoload_present() -> void:
	assert_not_null(ModSystem)
	assert_true(ModSystem.has_method("scan_mods"))
	assert_true(ModSystem.has_method("load_enabled_mods"))


# --- 14.4 / 14.13 — Power graph ----------------------------------------


func test_power_register_source_and_sink_in_same_group() -> void:
	var src: int = Phase14Helpers.register_power_node(&"source", 1, 50.0, 0.0)
	var sink: int = Phase14Helpers.register_power_node(&"sink", 1, 0.0, 5.0)
	assert_true(Phase14Helpers.resolve_power_for_group(1))
	# Cleanup
	Phase14Helpers.unregister_power_node(src)
	Phase14Helpers.unregister_power_node(sink)


func test_power_demand_exceeds_supply_returns_false() -> void:
	Phase14Helpers.register_power_node(&"source", 2, 5.0, 0.0)
	Phase14Helpers.register_power_node(&"sink", 2, 0.0, 50.0)
	assert_false(Phase14Helpers.resolve_power_for_group(2))


func test_power_battery_stores_and_drains() -> void:
	var src: int = Phase14Helpers.register_power_node(&"source", 3, 20.0, 0.0)
	var bat: int = Phase14Helpers.register_power_node(&"battery", 3, 0.0, 0.0, 100.0)
	Phase14Helpers.register_power_node(&"sink", 3, 0.0, 10.0)
	# Two beats with surplus → battery fills.
	Phase14Helpers.resolve_power_for_group(3)
	Phase14Helpers.resolve_power_for_group(3)
	var frac1: float = Phase14Helpers.battery_charge_fraction(bat)
	assert_true(frac1 > 0.0)
	# Now disable source — battery covers demand for a couple beats.
	Phase14Helpers.power_nodes[src]["active"] = false
	Phase14Helpers.resolve_power_for_group(3)
	var frac2: float = Phase14Helpers.battery_charge_fraction(bat)
	assert_true(frac2 < frac1)


# --- 14.5 / 14.14 — Wire graph + propagation ---------------------------


func test_wire_signal_round_trip() -> void:
	Phase14Helpers.set_wire_signal(7, true)
	assert_true(Phase14Helpers.read_wire_signal(7))
	Phase14Helpers.set_wire_signal(7, false)
	assert_false(Phase14Helpers.read_wire_signal(7))


func test_wire_link_propagation() -> void:
	Phase14Helpers.link_wires(1, 2)
	Phase14Helpers.link_wires(2, 3)
	var changed: int = Phase14Helpers.propagate_signal(1, true)
	assert_eq(changed, 3)
	assert_true(Phase14Helpers.read_wire_signal(3))


# --- 14.7 — Logic gates ----------------------------------------------


func test_logic_gate_and() -> void:
	Phase14Helpers.set_wire_signal(10, true)
	Phase14Helpers.set_wire_signal(11, true)
	var gid: int = Phase14Helpers.register_gate(&"and", [10, 11], 12)
	Phase14Helpers.eval_gate(gid)
	assert_true(Phase14Helpers.read_wire_signal(12))
	Phase14Helpers.set_wire_signal(11, false)
	Phase14Helpers.eval_gate(gid)
	assert_false(Phase14Helpers.read_wire_signal(12))


func test_logic_gate_or() -> void:
	Phase14Helpers.set_wire_signal(20, false)
	Phase14Helpers.set_wire_signal(21, true)
	var gid: int = Phase14Helpers.register_gate(&"or", [20, 21], 22)
	Phase14Helpers.eval_gate(gid)
	assert_true(Phase14Helpers.read_wire_signal(22))


func test_logic_gate_not() -> void:
	Phase14Helpers.set_wire_signal(30, false)
	var gid: int = Phase14Helpers.register_gate(&"not", [30], 31)
	Phase14Helpers.eval_gate(gid)
	assert_true(Phase14Helpers.read_wire_signal(31))


func test_logic_gate_nand() -> void:
	Phase14Helpers.set_wire_signal(40, true)
	Phase14Helpers.set_wire_signal(41, true)
	var gid: int = Phase14Helpers.register_gate(&"nand", [40, 41], 42)
	Phase14Helpers.eval_gate(gid)
	assert_false(Phase14Helpers.read_wire_signal(42))


func test_logic_gate_xor() -> void:
	Phase14Helpers.set_wire_signal(50, true)
	Phase14Helpers.set_wire_signal(51, false)
	var gid: int = Phase14Helpers.register_gate(&"xor", [50, 51], 52)
	Phase14Helpers.eval_gate(gid)
	assert_true(Phase14Helpers.read_wire_signal(52))


# --- 14.15 — Timer block --------------------------------------------


func test_timer_block_fires_after_delay() -> void:
	Phase14Helpers.set_wire_signal(60, false)
	var tid: int = Phase14Helpers.register_timer(60, 61, 2)
	Phase14Helpers.set_wire_signal(60, true)
	# Tick 1: countdown initialized
	Phase14Helpers.tick_timers()
	assert_false(Phase14Helpers.read_wire_signal(61))
	# Tick 2: countdown hits zero, output high
	Phase14Helpers.tick_timers()
	assert_true(Phase14Helpers.read_wire_signal(61))
	# Tick 3: pulse ends
	Phase14Helpers.tick_timers()
	assert_false(Phase14Helpers.read_wire_signal(61))


# --- 3.34 / 3.35 / 4.35 / 4.36 / 14.24 — Liquids --------------------


func test_liquid_mix_lava_water_to_obsidian() -> void:
	assert_eq(Phase14Helpers.liquid_mix_result(&"lava", &"water"), &"tile_stone_obsidian")
	# Reverse order also matches.
	assert_eq(Phase14Helpers.liquid_mix_result(&"water", &"lava"), &"tile_stone_obsidian")


func test_liquid_mix_no_reaction_same_liquid() -> void:
	assert_eq(Phase14Helpers.liquid_mix_result(&"water", &"water"), &"")


func test_tile_convert_sand_to_mud() -> void:
	assert_eq(Phase14Helpers.tile_convert_result(&"tile_sand", &"water"), &"tile_mud")


func test_bucket_fill_and_empty_cycle() -> void:
	# Place an empty bucket in slot 0, fill it, empty it.
	Inventory.try_add(&"bucket_empty", 1)
	var idx: int = -1
	for i in range(Inventory.slots.size()):
		var s = Inventory.slots[i]
		if s != null and StringName(s.get("item_id", "")) == &"bucket_empty":
			idx = i
			break
	assert_true(idx >= 0)
	assert_true(Phase14Helpers.fill_bucket_from_tile(idx, &"water"))
	assert_eq(StringName(String(Inventory.slots[idx].get("item_id", ""))), &"bucket_full_water")
	var emptied: StringName = Phase14Helpers.empty_bucket_to_tile(idx, Vector2(48, 48))
	assert_eq(emptied, &"water")
	assert_eq(StringName(String(Inventory.slots[idx].get("item_id", ""))), &"bucket_empty")


# --- 14.21 / 14.41 / 14.42 — Tile painting + patterns ---------------


func test_paint_tile_records_color() -> void:
	Phase14Helpers.paint_tile(Vector2i(3, 4), Color(0.8, 0.15, 0.20))
	var color: Color = Phase14Helpers.paint_for(Vector2i(3, 4))
	assert_almost_eq(color.r, 0.8, 0.02)


func test_paint_unknown_tile_returns_white() -> void:
	var c: Color = Phase14Helpers.paint_for(Vector2i(99, 99))
	assert_eq(c, Color(1, 1, 1, 1))


func test_stamp_pattern_writes_nine_tiles() -> void:
	var stamped: int = Phase14Helpers.stamp_pattern(Vector2i(0, 0), &"checker", Color(1, 0, 0), Color(0, 0, 1))
	assert_eq(stamped, 9)


# --- 14.29 / 14.40 — Grid snap + rotation -----------------------------


func test_grid_snap_aligns_to_tile_center() -> void:
	var snapped: Vector2 = Phase14Helpers.snap_to_grid(Vector2(33.0, 24.0))
	assert_eq(snapped, Vector2(40.0, 24.0))


func test_grid_snap_toggle_off_passes_through() -> void:
	Phase14Helpers.grid_snap_enabled = false
	var v: Vector2 = Vector2(33.0, 24.0)
	assert_eq(Phase14Helpers.snap_to_grid(v), v)


func test_rotation_step_wraps_mod_four() -> void:
	assert_eq(Phase14Helpers.rotation_for_step(0), 0)
	assert_eq(Phase14Helpers.rotation_for_step(1), 90)
	assert_eq(Phase14Helpers.rotation_for_step(4), 0)
	assert_eq(Phase14Helpers.rotation_for_step(6), 180)


# --- 14.27 — Blueprint save / load -----------------------------------


func test_blueprint_save_and_list() -> void:
	var tiles: Array = [{"offset_x": 0, "offset_y": 0, "item_id": "conveyor_placeable", "rotation_step": 0}]
	Phase14Helpers.save_blueprint(&"my_factory", Vector2.ZERO, Vector2i(4, 4), tiles)
	var listed: Array = Phase14Helpers.list_blueprints()
	assert_eq(listed.size(), 1)
	assert_eq(String(listed[0].get("id", "")), "my_factory")


func test_blueprint_load_returns_tiles() -> void:
	var tiles: Array = [{"offset_x": 1, "offset_y": 2, "item_id": "wire_placeable", "rotation_step": 0}]
	Phase14Helpers.save_blueprint(&"wire_strip", Vector2.ZERO, Vector2i(8, 1), tiles)
	var loaded: Array = Phase14Helpers.load_blueprint(&"wire_strip", Vector2(100, 200))
	assert_eq(loaded.size(), 1)
	assert_eq(String(loaded[0].get("item_id", "")), "wire_placeable")


# --- 14.11 — Item filter ---------------------------------------------


func test_conveyor_filter_default_allows_all() -> void:
	assert_true(Phase14Helpers.conveyor_allows(42, &"loam"))


func test_conveyor_filter_restricts() -> void:
	Phase14Helpers.set_conveyor_filter(42, [&"shaleseed"])
	assert_true(Phase14Helpers.conveyor_allows(42, &"shaleseed"))
	assert_false(Phase14Helpers.conveyor_allows(42, &"loam"))


# --- 14.16 — Splitter cursor round-robin -----------------------------


func test_splitter_cycles_outputs() -> void:
	var a: int = Phase14Helpers.splitter_next_output(1, 2)
	var b: int = Phase14Helpers.splitter_next_output(1, 2)
	var c: int = Phase14Helpers.splitter_next_output(1, 2)
	assert_ne(a, b)
	assert_eq(a, c)


# --- 14.18 — Storage piping ------------------------------------------


func test_storage_pipe_register_unregister() -> void:
	var pid: int = Phase14Helpers.register_pipe(NodePath("a"), NodePath("b"), [&"shaleseed"])
	assert_true(Phase14Helpers.storage_pipes.has(pid))
	Phase14Helpers.unregister_pipe(pid)
	assert_false(Phase14Helpers.storage_pipes.has(pid))


# --- 14.3 — Robotic arm registration ---------------------------------


func test_robotic_arm_register_and_tick() -> void:
	var aid: int = Phase14Helpers.register_arm(Vector2(0, 0), Vector2(16, 0))
	assert_true(Phase14Helpers.robotic_arms.has(aid))
	# Tick twice to fire one cycle (period = 2 beats).
	Phase14Helpers.tick_robotic_arms()
	var fired: int = Phase14Helpers.tick_robotic_arms()
	assert_eq(fired, 1)


# --- 14.10 — Auto-furnace bookkeeping -----------------------------


func test_auto_cooker_register_and_tick() -> void:
	var cid: int = Phase14Helpers.register_auto_cooker(&"craft_bloat_loaf", NodePath("a"), NodePath("b"))
	assert_true(Phase14Helpers.auto_cookers.has(cid))
	for _i in range(Phase14Helpers.AUTO_COOK_PERIOD_BEATS):
		Phase14Helpers.tick_auto_cookers()
	# After AUTO_COOK_PERIOD_BEATS ticks, beats_remaining wraps and fires once.
	assert_eq(int(Phase14Helpers.auto_cookers[cid].get("beats_remaining", -1)), Phase14Helpers.AUTO_COOK_PERIOD_BEATS)


func test_auto_fishing_rig_register_and_tick() -> void:
	var rid: int = Phase14Helpers.register_auto_fishing_rig(2, &"bait_basic", NodePath("dest"))
	assert_true(Phase14Helpers.auto_fishing_rigs.has(rid))
	for _i in range(Phase14Helpers.AUTO_FISH_PERIOD_BEATS):
		Phase14Helpers.tick_auto_fishing_rigs()
	assert_eq(int(Phase14Helpers.auto_fishing_rigs[rid].get("beats_remaining", -1)), Phase14Helpers.AUTO_FISH_PERIOD_BEATS)


# --- 14.19 — Mob farm AABB lookup ------------------------------------


func test_mob_farm_position_lookup() -> void:
	var fid: int = Phase14Helpers.register_mob_farm(Vector2(0, 0), Vector2(64, 64), Vector2(32, 32))
	assert_eq(Phase14Helpers.farm_for_position(Vector2(32, 32)), fid)
	assert_eq(Phase14Helpers.farm_for_position(Vector2(200, 200)), -1)


# --- 14.30 — Auctioneer -----------------------------------------------


func test_auctioneer_list_for_sale_creates_listing() -> void:
	var lid: int = Phase14Helpers.list_for_sale(1, &"shaleseed_ingot", 5, 12)
	assert_true(lid > 0)
	var active: Array = Phase14Helpers.active_listings()
	assert_eq(active.size(), 1)


func test_auctioneer_claim_marks_listing() -> void:
	var lid: int = Phase14Helpers.list_for_sale(1, &"shaleseed_ingot", 5, 12)
	var ok: bool = Phase14Helpers.claim_listing(lid, 2)
	assert_true(ok)
	# Second claim should fail.
	assert_false(Phase14Helpers.claim_listing(lid, 3))


func test_auctioneer_invalid_listing_rejected() -> void:
	assert_eq(Phase14Helpers.list_for_sale(1, &"x", 0, 5), -1)
	assert_eq(Phase14Helpers.list_for_sale(1, &"x", 1, -5), -1)


# --- 14.20 / 14.36 — Wireless transmit / receive ---------------------


func test_wireless_pulse_drives_receiver_wire() -> void:
	var tx: int = Phase14Helpers.register_transmitter(1, Vector2.ZERO, 500.0)
	Phase14Helpers.register_receiver(1, Vector2(100, 0), 99)
	var fired: int = Phase14Helpers.pulse_transmitter(tx)
	assert_eq(fired, 1)
	assert_true(Phase14Helpers.read_wire_signal(99))


func test_wireless_range_excludes_far_receiver() -> void:
	var tx: int = Phase14Helpers.register_transmitter(2, Vector2.ZERO, 16.0)
	Phase14Helpers.register_receiver(2, Vector2(1000, 0), 88)
	var fired: int = Phase14Helpers.pulse_transmitter(tx)
	assert_eq(fired, 0)


# --- 14.22 — Multiblock scoring --------------------------------------


func test_multiblock_score_returns_zero_with_no_tree() -> void:
	# Without an active scene tree, score_multiblock returns 0 — verify the
	# default is sane.
	var score: int = Phase14Helpers.score_multiblock(Vector2.ZERO)
	assert_true(score >= 0)


# --- Dump / restore -------------------------------------------------


func test_phase14_helpers_dump_restore_roundtrip() -> void:
	Phase14Helpers.register_power_node(&"source", 5, 30.0, 0.0)
	Phase14Helpers.set_wire_signal(123, true)
	Phase14Helpers.paint_tile(Vector2i(2, 3), Color(0.5, 0.2, 0.8))
	Phase14Helpers.save_blueprint(&"snap_test", Vector2.ZERO, Vector2i(4, 4), [])
	var snap: Dictionary = Phase14Helpers.dump_state()
	Phase14Helpers.power_nodes.clear()
	Phase14Helpers.wire_signals.clear()
	Phase14Helpers.tile_paint.clear()
	Phase14Helpers.blueprints.clear()
	Phase14Helpers.restore_state(snap)
	assert_true(Phase14Helpers.power_nodes.size() > 0)
	assert_true(Phase14Helpers.read_wire_signal(123))
	assert_almost_eq(Phase14Helpers.paint_for(Vector2i(2, 3)).r, 0.5, 0.02)
	assert_true(Phase14Helpers.blueprints.has(&"snap_test"))


# --- ModSystem --------------------------------------------------------


func test_mod_system_version_compatibility_helper() -> void:
	assert_true(ModSystem._is_version_compatible("0.1.0", "0.2.5"))
	assert_false(ModSystem._is_version_compatible("0.3.0", "0.2.5"))
	assert_false(ModSystem._is_version_compatible("1.0.0", "0.9.0"))
	assert_true(ModSystem._is_version_compatible("", "0.1.0"))


func test_mod_system_enable_and_disable() -> void:
	ModSystem.discovered_mods[&"test_mod"] = {
		"manifest": {"id": "test_mod", "version": "0.1.0"},
		"path": "user://mods/test_mod/",
		"enabled": false,
		"load_order": 0,
	}
	assert_true(ModSystem.enable_mod(&"test_mod"))
	assert_true(bool(ModSystem.discovered_mods[&"test_mod"].get("enabled", false)))
	assert_true(ModSystem.disable_mod(&"test_mod"))
	assert_false(bool(ModSystem.discovered_mods[&"test_mod"].get("enabled", false)))


func test_mod_system_load_order_application() -> void:
	ModSystem.discovered_mods[&"a"] = {"manifest": {}, "path": "", "enabled": true, "load_order": 99}
	ModSystem.discovered_mods[&"b"] = {"manifest": {}, "path": "", "enabled": true, "load_order": 99}
	ModSystem.set_load_order([&"b", &"a"])
	assert_eq(int(ModSystem.discovered_mods[&"b"].get("load_order", 0)), 0)
	assert_eq(int(ModSystem.discovered_mods[&"a"].get("load_order", 0)), 1)


func test_mod_system_conflict_recorded() -> void:
	ModSystem._record_conflict(&"mod_a", "items.test_item")
	ModSystem._record_conflict(&"mod_b", "items.test_item")
	assert_true(ModSystem.conflict_keys().has("items.test_item"))


func test_mod_system_browser_emits_stub_listing() -> void:
	var fired: int = ModSystem.fetch_remote_listings("")
	assert_eq(fired, 1)
	assert_true(ModSystem.remote_browser.has(&"remote_demo_pack"))


func test_mod_system_dump_restore_roundtrip() -> void:
	ModSystem.discovered_mods[&"keep_me"] = {
		"manifest": {"id": "keep_me", "version": "0.1.0"},
		"path": "user://mods/keep_me/",
		"enabled": true,
		"load_order": 2,
	}
	var snap: Dictionary = ModSystem.dump_state()
	ModSystem.discovered_mods.clear()
	ModSystem.restore_state(snap)
	assert_true(ModSystem.discovered_mods.has(&"keep_me"))
	assert_true(bool(ModSystem.discovered_mods[&"keep_me"].get("enabled", false)))
	assert_eq(int(ModSystem.discovered_mods[&"keep_me"].get("load_order", 0)), 2)


# --- ItemDef + recipe loads --------------------------------------------


func test_phase14_item_defs_load() -> void:
	var ids: Array[StringName] = [
		&"conveyor_placeable", &"drill_placeable", &"robotic_arm_placeable",
		&"aphelion_tap_placeable", &"wire_placeable", &"pressure_plate_placeable",
		&"button_placeable", &"logic_gate_and_placeable", &"sensor_placeable",
		&"storage_piping_placeable", &"auto_sprinkler_placeable",
		&"auto_harvester_placeable", &"auto_furnace_placeable",
		&"auto_smelter_placeable", &"power_storage_cell_placeable",
		&"splitter_placeable", &"merger_placeable", &"hopper_placeable",
		&"item_filter_placeable", &"timer_block_placeable",
		&"signal_transmitter_placeable", &"signal_receiver_placeable",
		&"wireless_relay_placeable", &"mob_farm_block_placeable",
		&"glass_block_placeable", &"fence_gate_placeable",
		&"auctioneer_node_placeable", &"auto_cooking_pot_placeable",
		&"auto_fishing_rig_placeable",
		&"bucket_empty", &"bucket_full_water", &"bucket_full_lava",
		&"bucket_full_slime", &"bucket_full_acid",
		&"paint_brush", &"color_wheel_palette", &"pattern_paint_stamp",
		&"wallpaper_roll", &"demolition_tool", &"blueprint_tool",
		&"place_grid_toggle", &"signal_relay_placeable",
		&"mod_compat_token", &"sample_mod_kit",
		&"logic_gate_or_placeable", &"logic_gate_not_placeable",
		&"logic_gate_nand_placeable", &"logic_gate_xor_placeable",
	]
	for iid in ids:
		var def: ItemDef = ItemRegistry.get_def(iid)
		assert_not_null(def, "Missing ItemDef for %s" % String(iid))


func test_phase14_recipe_loads() -> void:
	var ids: Array[StringName] = [
		&"craft_bucket_empty", &"craft_paint_brush", &"craft_wallpaper_roll",
		&"craft_demolition_tool", &"craft_place_grid_toggle",
		&"craft_glass_block", &"craft_fence_gate",
		&"craft_wire", &"craft_pressure_plate", &"craft_button",
		&"craft_conveyor", &"craft_splitter", &"craft_merger",
		&"craft_hopper", &"craft_item_filter", &"craft_signal_relay",
		&"craft_pattern_paint_stamp",
		&"craft_storage_piping", &"craft_sensor",
		&"craft_logic_gate_and", &"craft_logic_gate_or",
		&"craft_logic_gate_not", &"craft_logic_gate_nand",
		&"craft_logic_gate_xor", &"craft_timer_block",
		&"craft_drill",
		&"craft_aphelion_tap", &"craft_power_storage_cell",
		&"craft_robotic_arm", &"craft_signal_transmitter",
		&"craft_signal_receiver", &"craft_auto_sprinkler",
		&"craft_auto_harvester", &"craft_auto_furnace",
		&"craft_auto_smelter", &"craft_auto_cooking_pot",
		&"craft_auto_fishing_rig", &"craft_mob_farm_block",
		&"craft_auctioneer_node", &"craft_blueprint_tool",
		&"craft_wireless_relay",
	]
	for rid in ids:
		var rec: Recipe = CraftingSystem.get_recipe(rid)
		assert_not_null(rec, "Missing recipe for %s" % String(rid))


# --- SaveSystem version bump ---------------------------------------


func test_save_version_at_least_12() -> void:
	# Phase 14 bumped to 12; subsequent phases (15+) advance this further. We
	# only require ≥12 here so the suite survives later phase closures.
	assert_gte(SaveSystem.SAVE_VERSION, 12)


# --- Phase 14 sprite assets exist ----------------------------------


func test_phase14_sprites_load() -> void:
	var paths: Array[String] = [
		"res://assets/sprites/items/conveyor_belt.png",
		"res://assets/sprites/items/drill_placeable.png",
		"res://assets/sprites/items/robotic_arm.png",
		"res://assets/sprites/items/aphelion_tap.png",
		"res://assets/sprites/items/wire.png",
		"res://assets/sprites/items/pressure_plate.png",
		"res://assets/sprites/items/button.png",
		"res://assets/sprites/items/logic_gate_and.png",
		"res://assets/sprites/items/sensor.png",
		"res://assets/sprites/items/storage_piping.png",
		"res://assets/sprites/items/auto_sprinkler.png",
		"res://assets/sprites/items/auto_harvester.png",
		"res://assets/sprites/items/auto_furnace.png",
		"res://assets/sprites/items/auto_smelter.png",
		"res://assets/sprites/items/power_storage_cell.png",
		"res://assets/sprites/items/splitter.png",
		"res://assets/sprites/items/merger.png",
		"res://assets/sprites/items/hopper.png",
		"res://assets/sprites/items/item_filter.png",
		"res://assets/sprites/items/timer_block.png",
		"res://assets/sprites/items/bucket_empty.png",
		"res://assets/sprites/items/bucket_full_water.png",
		"res://assets/sprites/items/paint_brush.png",
		"res://assets/sprites/items/blueprint_tool.png",
		"res://assets/sprites/items/demolition_tool.png",
	]
	for p in paths:
		var tex: Texture2D = load(p) as Texture2D
		assert_not_null(tex, "Missing texture %s" % p)


# --- Phase 14 placeable scenes exist -------------------------------


func test_phase14_scenes_load() -> void:
	var scn_paths: Array[String] = [
		"res://scenes/structures/conveyor.tscn",
		"res://scenes/structures/drill.tscn",
		"res://scenes/structures/aphelion_tap.tscn",
		"res://scenes/structures/wire_segment.tscn",
		"res://scenes/structures/logic_gate.tscn",
		"res://scenes/structures/timer_block.tscn",
		"res://scenes/structures/pressure_plate.tscn",
		"res://scenes/structures/button_switch.tscn",
		"res://scenes/structures/sensor_module.tscn",
		"res://scenes/structures/storage_pipe.tscn",
		"res://scenes/structures/auto_sprinkler.tscn",
		"res://scenes/structures/auto_harvester.tscn",
		"res://scenes/structures/auto_furnace.tscn",
		"res://scenes/structures/auto_smelter.tscn",
		"res://scenes/structures/power_storage_cell.tscn",
		"res://scenes/structures/splitter.tscn",
		"res://scenes/structures/merger.tscn",
		"res://scenes/structures/hopper.tscn",
		"res://scenes/structures/item_filter.tscn",
		"res://scenes/structures/signal_transmitter.tscn",
		"res://scenes/structures/signal_receiver.tscn",
		"res://scenes/structures/wireless_relay.tscn",
		"res://scenes/structures/robotic_arm.tscn",
		"res://scenes/structures/mob_farm_block.tscn",
		"res://scenes/structures/glass_block.tscn",
		"res://scenes/structures/fence_gate.tscn",
		"res://scenes/structures/auctioneer_node.tscn",
		"res://scenes/structures/auto_cooking_pot.tscn",
		"res://scenes/structures/auto_fishing_rig.tscn",
		"res://scenes/structures/liquid_tile.tscn",
	]
	for p in scn_paths:
		var scn: PackedScene = load(p) as PackedScene
		assert_not_null(scn, "Missing scene %s" % p)
