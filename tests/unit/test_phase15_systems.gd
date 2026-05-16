extends GutTest

## Phase 15 — Polish & gap closure system tests.
## Covers Phase15Helpers, AccessibilityManager, CosmeticsManager,
## AchievementsExtended, SteamIntegration, LocalizationManager, AudioProfile,
## PerfManager, SaveBackup, NetPolish, PhotoMode, DebugOverlay, CrashReporter,
## ReplaySystem, GameModes, MobDeathSfx, Phase 15 UI panel loads, sprite paths,
## SaveSystem v13 round-trip.

const TEST_SLOT: String = "_gut_phase15_slot"


func before_each() -> void:
	if Phase15Helpers:
		Phase15Helpers.set_difficulty(&"normal")
		Phase15Helpers.set_hardcore(false)
		Phase15Helpers.combo_counter = 0
		Phase15Helpers.combo_max = 0
		Phase15Helpers.current_run_deaths = 0
		Phase15Helpers.run_history.clear()
		Phase15Helpers.discovered_eggs.clear()
		Phase15Helpers.console_was_used = false
		Phase15Helpers.world_stats.clear()
		Phase15Helpers.world_stats = {
			&"tiles_mined": 0, &"distance_walked_px": 0, &"damage_dealt": 0,
			&"damage_taken": 0, &"items_picked_up": 0, &"items_crafted": 0,
			&"food_eaten": 0, &"fish_caught": 0, &"crops_harvested": 0,
			&"mobs_killed": 0, &"bosses_defeated": 0, &"chests_opened": 0,
			&"slivers_lost": 0, &"days_passed": 0,
		}
	if SaveSystem.slot_exists(TEST_SLOT):
		SaveSystem.delete_slot(TEST_SLOT)


func after_each() -> void:
	if SaveSystem.slot_exists(TEST_SLOT):
		SaveSystem.delete_slot(TEST_SLOT)


# ---------- Autoload presence ----------

func test_phase15_autoloads_loaded() -> void:
	for sn in ["Phase15Helpers", "AccessibilityManager", "CosmeticsManager",
		"AchievementsExtended", "SteamIntegration", "LocalizationManager",
		"AudioProfile", "PerfManager", "SaveBackup", "NetPolish", "PhotoMode",
		"DebugOverlay", "CrashReporter", "ReplaySystem", "GameModes",
		"MobDeathSfx"]:
		var node: Node = get_node_or_null("/root/" + sn)
		assert_not_null(node, "autoload missing: " + sn)


# ---------- Phase15Helpers difficulty (15.39) ----------

func test_difficulty_preset_normal_defaults() -> void:
	Phase15Helpers.set_difficulty(&"normal")
	assert_eq(Phase15Helpers.player_damage_mult(), 1.0)
	assert_eq(Phase15Helpers.mob_hp_mult(), 1.0)


func test_difficulty_preset_casual_easier() -> void:
	Phase15Helpers.set_difficulty(&"casual")
	assert_true(Phase15Helpers.player_damage_mult() > 1.0)
	assert_true(Phase15Helpers.mob_damage_mult() < 1.0)


func test_difficulty_preset_hard_harder() -> void:
	Phase15Helpers.set_difficulty(&"hard_plus")
	assert_true(Phase15Helpers.player_damage_mult() < 1.0)
	assert_true(Phase15Helpers.mob_hp_mult() > 1.5)


func test_unknown_difficulty_rejected() -> void:
	assert_false(Phase15Helpers.set_difficulty(&"nonsense"))


# ---------- Hardcore (15.38) ----------

func test_hardcore_toggle() -> void:
	Phase15Helpers.set_hardcore(true)
	assert_true(Phase15Helpers.hardcore_active)
	Phase15Helpers.set_hardcore(false)
	assert_false(Phase15Helpers.hardcore_active)


# ---------- Speedrun timer (15.28) ----------

func test_speedrun_lifecycle() -> void:
	Phase15Helpers.speedrun_start()
	assert_true(Phase15Helpers.speedrun_active)
	Phase15Helpers.speedrun_add_split("checkpoint_a")
	Phase15Helpers.speedrun_add_split("checkpoint_b")
	assert_eq(Phase15Helpers.speedrun_splits.size(), 2)
	Phase15Helpers.speedrun_stop()
	assert_false(Phase15Helpers.speedrun_active)


# ---------- Boss-rush + endless (15.30 / 15.31) ----------

func test_boss_rush_progress() -> void:
	Phase15Helpers.boss_rush_start()
	assert_true(Phase15Helpers.boss_rush_active)
	Phase15Helpers.boss_rush_record_kill()
	Phase15Helpers.boss_rush_record_kill()
	assert_eq(Phase15Helpers.boss_rush_progress, 2)


func test_endless_descend_increments() -> void:
	Phase15Helpers.endless_start()
	assert_eq(Phase15Helpers.endless_floor, 1)
	var f2: int = Phase15Helpers.endless_descend()
	assert_eq(f2, 2)


# ---------- Daily / weekly challenge (15.29) ----------

func test_challenge_seed_is_deterministic_for_day() -> void:
	var a: int = Phase15Helpers.challenge_seed_for_today()
	var b: int = Phase15Helpers.challenge_seed_for_today()
	assert_eq(a, b)


func test_weekly_seed_is_deterministic_for_week() -> void:
	var a: int = Phase15Helpers.challenge_seed_for_week()
	var b: int = Phase15Helpers.challenge_seed_for_week()
	assert_eq(a, b)


# ---------- World statistics (15.47) ----------

func test_world_stats_bump() -> void:
	Phase15Helpers.bump_stat(&"tiles_mined", 3)
	assert_eq(Phase15Helpers.get_stat(&"tiles_mined"), 3)
	Phase15Helpers.bump_stat(&"tiles_mined", 2)
	assert_eq(Phase15Helpers.get_stat(&"tiles_mined"), 5)


# ---------- Combo (2.39) ----------

func test_combo_increments_and_tracks_max() -> void:
	Phase15Helpers.register_hit_landed()
	Phase15Helpers.register_hit_landed()
	Phase15Helpers.register_hit_landed()
	assert_eq(Phase15Helpers.combo_counter, 3)
	assert_eq(Phase15Helpers.combo_max, 3)
	Phase15Helpers._set_combo(0)
	assert_eq(Phase15Helpers.combo_counter, 0)
	assert_eq(Phase15Helpers.combo_max, 3)


# ---------- Easter eggs (15.57) ----------

func test_easter_egg_discovery() -> void:
	var first: bool = Phase15Helpers.discover_easter_egg(&"egg_dev_credits")
	var second: bool = Phase15Helpers.discover_easter_egg(&"egg_dev_credits")
	assert_true(first)
	assert_false(second)
	assert_eq(Phase15Helpers.easter_egg_count_discovered(), 1)


# ---------- Login streak (15.49) ----------

func test_login_streak_first_call_sets_to_one() -> void:
	Phase15Helpers.last_login_iso = ""
	Phase15Helpers.login_streak_days = 0
	Phase15Helpers._check_login_streak()
	assert_eq(Phase15Helpers.login_streak_days, 1)
	assert_true(Phase15Helpers.streak_reward_pending)


func test_login_streak_consume_returns_coins() -> void:
	Phase15Helpers.streak_reward_pending = true
	Phase15Helpers.login_streak_days = 3
	var coins: int = Phase15Helpers.consume_streak_reward()
	assert_eq(coins, 30)
	assert_false(Phase15Helpers.streak_reward_pending)


# ---------- Cheat detection (15.35) ----------

func test_console_use_disables_achievements() -> void:
	Phase15Helpers.console_was_used = false
	assert_true(Phase15Helpers.achievements_enabled())
	Phase15Helpers.note_console_opened()
	assert_false(Phase15Helpers.achievements_enabled())


# ---------- NG+ inheritance (15.94) ----------

func test_ng_plus_inheritance_defaults() -> void:
	assert_true(Phase15Helpers.is_ng_plus_carry_over(&"sovereign_threads"))
	assert_false(Phase15Helpers.is_ng_plus_carry_over(&"defeated_bosses"))


func test_ng_plus_inheritance_override() -> void:
	Phase15Helpers.set_ng_plus_carry_override(&"defeated_bosses", true)
	assert_true(Phase15Helpers.is_ng_plus_carry_over(&"defeated_bosses"))


# ---------- Seasonal events (15.6) ----------

func test_seasonal_event_date_range_wraps_year() -> void:
	# Winter event wraps Dec 18 → Jan 7. Jan 4 should be within range.
	assert_true(Phase15Helpers._date_within_range(1, 4, 12, 18, 1, 7))
	# July is outside.
	assert_false(Phase15Helpers._date_within_range(7, 1, 12, 18, 1, 7))


# ---------- Damage breakdown (15.40) ----------

func test_damage_breakdown_resets_on_boss_engaged() -> void:
	# Force-engage; check zeroed counters.
	Phase15Helpers._on_boss_engaged(&"test_boss")
	assert_true(Phase15Helpers.damage_breakdown_active)
	assert_eq(int(Phase15Helpers.damage_breakdown[&"damage_dealt"]), 0)


func test_damage_breakdown_dodge_records() -> void:
	Phase15Helpers._on_boss_engaged(&"test_boss")
	Phase15Helpers.record_dodge()
	Phase15Helpers.record_dodge()
	assert_eq(int(Phase15Helpers.damage_breakdown[&"dodges"]), 2)


# ---------- AccessibilityManager ----------

func test_colorblind_mode_accepts_valid() -> void:
	AccessibilityManager.set_colorblind_mode(&"protanopia")
	assert_eq(AccessibilityManager.colorblind_mode, StringName("protanopia"))


func test_colorblind_mode_rejects_invalid() -> void:
	AccessibilityManager.set_colorblind_mode(&"nonsense")
	assert_ne(AccessibilityManager.colorblind_mode, StringName("nonsense"))


func test_text_scale_clamped() -> void:
	AccessibilityManager.set_text_scale(10.0)
	assert_lt(AccessibilityManager.text_scale, 3.1)
	AccessibilityManager.set_text_scale(0.1)
	assert_gt(AccessibilityManager.text_scale, 0.4)


func test_remap_color_achromatopsia_is_grey() -> void:
	AccessibilityManager.set_colorblind_mode(&"achromatopsia")
	var c: Color = AccessibilityManager.remap_color(Color(1.0, 0.0, 0.0))
	# Grey: r=g=b.
	assert_almost_eq(c.r, c.g, 0.01)
	assert_almost_eq(c.g, c.b, 0.01)


func test_action_toggle_persists() -> void:
	AccessibilityManager.set_action_toggle(&"sprint", true)
	assert_true(AccessibilityManager.is_action_toggle(&"sprint"))


# ---------- CosmeticsManager ----------

func test_dye_apply_records_color() -> void:
	CosmeticsManager.apply_dye(&"helmet", Color(0.2, 0.6, 0.9, 1.0))
	var c: Color = CosmeticsManager.get_dye(&"helmet")
	assert_almost_eq(c.r, 0.2, 0.01)
	assert_almost_eq(c.b, 0.9, 0.01)


func test_dye_unknown_layer_rejected() -> void:
	assert_false(CosmeticsManager.apply_dye(&"banana", Color.RED))


func test_outfit_save_and_load() -> void:
	CosmeticsManager.apply_dye(&"chest", Color(0.5, 0.5, 0.5, 1.0))
	var saved: bool = CosmeticsManager.save_outfit(0, "Test Outfit")
	assert_true(saved)
	CosmeticsManager.apply_dye(&"chest", Color(1, 0, 0, 1))
	CosmeticsManager.load_outfit(0)
	var c: Color = CosmeticsManager.get_dye(&"chest")
	assert_almost_eq(c.r, 0.5, 0.05)


func test_visual_layer_set_round_trip() -> void:
	CosmeticsManager.set_visual_layer(&"cape", &"red_cloak")
	assert_eq(CosmeticsManager.get_visual_layer(&"cape"), StringName("red_cloak"))


# ---------- AchievementsExtended ----------

func test_achievement_progress_bump() -> void:
	# Reset by directly clearing.
	if Achievements:
		Achievements._unlocked.erase(&"ach_kill_500_mobs")
		GameState.unlocked_compendium.erase(&"ach_kill_500_mobs")
	AchievementsExtended.progress[&"ach_kill_500_mobs"] = 0
	AchievementsExtended.bump(&"ach_kill_500_mobs", 5)
	assert_eq(int(AchievementsExtended.progress[&"ach_kill_500_mobs"]), 5)


func test_hidden_achievement_revealed_after_unlock() -> void:
	var entry: Dictionary = AchievementsExtended._find_entry(&"ach_easter_dev_credits")
	assert_true(bool(entry.get("hidden", false)))
	AchievementsExtended._unlock(&"ach_easter_dev_credits", entry)
	assert_true(Phase15Helpers.hidden_achievement_revealed.get(&"ach_easter_dev_credits", false))


# ---------- SteamIntegration ----------

func test_steam_cloud_round_trip() -> void:
	SteamIntegration.cloud_upload("test_slot")
	var rec: Dictionary = SteamIntegration.cloud_download("test_slot")
	assert_eq(rec.get("slot", ""), "test_slot")


func test_steam_set_beta_branch() -> void:
	SteamIntegration.set_beta_branch(true)
	assert_true(SteamIntegration.on_beta_branch)


func test_steam_anti_cheat_rejects_oversize() -> void:
	assert_false(SteamIntegration.sanity_check("payload", 99 * 1024 * 1024))


func test_steam_workshop_subscribe() -> void:
	SteamIntegration.subscribe_workshop("mod_a")
	assert_eq(SteamIntegration.subscribed_workshop_mods.size(), 1)
	SteamIntegration.subscribe_workshop("mod_a")  # idempotent
	assert_eq(SteamIntegration.subscribed_workshop_mods.size(), 1)
	SteamIntegration.unsubscribe_workshop("mod_a")
	assert_eq(SteamIntegration.subscribed_workshop_mods.size(), 0)


# ---------- LocalizationManager ----------

func test_rtl_locale_detection() -> void:
	assert_true(LocalizationManager.is_rtl_locale(&"vesari"))
	assert_false(LocalizationManager.is_rtl_locale(&"en"))


func test_locale_apply_rejects_unsupported() -> void:
	assert_false(LocalizationManager.apply_locale(&"klingon"))


func test_missing_key_tracking() -> void:
	LocalizationManager.note_missing_key("test.key")
	var n: int = LocalizationManager.missing_key_count(I18n.current_locale())
	assert_gt(n, 0)


# ---------- AudioProfile ----------

func test_audio_profile_apply() -> void:
	AudioProfile.apply(&"headphones")
	assert_eq(AudioProfile.profile, StringName("headphones"))


func test_audio_profile_rejects_unknown() -> void:
	assert_false(AudioProfile.apply(&"nonsense"))


# ---------- PerfManager ----------

func test_perf_preset_apply() -> void:
	PerfManager.apply_preset(&"low")
	assert_eq(PerfManager.preset, StringName("low"))
	assert_eq(PerfManager.lod_distance_chunks, 1)


func test_perf_preset_rejects_unknown() -> void:
	assert_false(PerfManager.apply_preset(&"plasma"))


func test_perf_chunk_budget_check() -> void:
	PerfManager.chunk_memory_mb = 4   # 4096 KB
	var ok_check: bool = PerfManager.can_load_more_chunks(0, 96.0)
	assert_true(ok_check)
	var fail: bool = PerfManager.can_load_more_chunks(50, 96.0)
	assert_false(fail)


# ---------- SaveBackup ----------

func test_save_migration_v11_to_v13() -> void:
	var state: Dictionary = {"some_field": "value"}
	state = SaveBackup.migrate_state(state, 11, 13)
	assert_true(state.has("phase14_helpers"))
	assert_true(state.has("phase15_helpers"))
	assert_true(state.has("cosmetics"))


func test_save_verify_missing_slot() -> void:
	var rep: Dictionary = SaveBackup.verify_slot("__nope__")
	assert_false(rep["ok"])


func test_save_set_interval_clamped() -> void:
	SaveBackup.set_interval(5)
	assert_gte(SaveBackup.autosave_interval_seconds, 30)


# ---------- NetPolish ----------

func test_grace_window_starts_and_resolves() -> void:
	NetPolish.begin_grace(42, 10)
	assert_true(NetPolish.peer_in_grace(42))
	var resolved: bool = NetPolish.resolve_grace(42)
	assert_true(resolved)
	assert_false(NetPolish.peer_in_grace(42))


func test_friend_register_changes_status() -> void:
	NetPolish.register_friend("steam_777", "Stranger", true)
	assert_eq(NetPolish.friend_count_online(), 1)
	NetPolish.update_friend_online("steam_777", false)
	assert_eq(NetPolish.friend_count_online(), 0)


func test_seed_share_returns_world_seed() -> void:
	GameState.world_seed = 12345
	var s: int = NetPolish.copy_world_seed_to_clipboard()
	assert_eq(s, 12345)


# ---------- PhotoMode ----------

func test_photo_filter_accepts_known() -> void:
	assert_true(PhotoMode.set_filter(&"sepia"))


func test_photo_filter_rejects_unknown() -> void:
	assert_false(PhotoMode.set_filter(&"oilpaint"))


# ---------- DebugOverlay ----------

func test_debug_overlay_toggle() -> void:
	var initial: bool = DebugOverlay.f3_visible
	DebugOverlay.toggle_f3()
	assert_ne(DebugOverlay.f3_visible, initial)
	DebugOverlay.toggle_f3()
	assert_eq(DebugOverlay.f3_visible, initial)


# ---------- CrashReporter ----------

func test_crash_report_records_file() -> void:
	var path: String = CrashReporter.record_crash("stack here", "error here")
	assert_true(path.length() > 0)
	assert_true(FileAccess.file_exists(path))


# ---------- ReplaySystem ----------

func test_replay_start_then_stop_writes_file() -> void:
	ReplaySystem.start_recording()
	# Sample one frame to ensure non-empty.
	ReplaySystem._sample_frame()
	var path: String = ReplaySystem.stop_recording()
	assert_true(path.length() > 0)


# ---------- GameModes ----------

func test_game_mode_speedrun_finish() -> void:
	GameModes.speedrun_start()
	GameModes.speedrun_split("a")
	var total: float = GameModes.speedrun_finish()
	assert_gte(total, 0.0)


# ---------- SaveSystem v13 round-trip ----------

func test_save_version_is_13() -> void:
	assert_eq(SaveSystem.SAVE_VERSION, 13)


func test_phase15_state_round_trip() -> void:
	Phase15Helpers.set_difficulty(&"hard")
	Phase15Helpers.set_hardcore(true)
	Phase15Helpers.discover_easter_egg(&"egg_glow_pit")
	Phase15Helpers.bump_stat(&"tiles_mined", 7)
	Phase15Helpers.combo_max = 12
	CosmeticsManager.apply_dye(&"chest", Color(0.1, 0.2, 0.3, 1.0))
	CosmeticsManager.save_outfit(2, "RoundTripOutfit")
	var save_err: int = SaveSystem.save_to_slot(TEST_SLOT)
	assert_eq(save_err, OK)
	# Reset everything.
	Phase15Helpers.set_difficulty(&"normal")
	Phase15Helpers.set_hardcore(false)
	Phase15Helpers.discovered_eggs.clear()
	Phase15Helpers.combo_max = 0
	CosmeticsManager.apply_dye(&"chest", Color.WHITE)
	var load_err: int = SaveSystem.load_from_slot(TEST_SLOT)
	assert_eq(load_err, OK)
	assert_eq(Phase15Helpers.difficulty_preset, StringName("hard"))
	assert_true(Phase15Helpers.hardcore_active)
	assert_true(Phase15Helpers.discovered_eggs.get(&"egg_glow_pit", false))
	assert_eq(Phase15Helpers.combo_max, 12)
	var c: Color = CosmeticsManager.get_dye(&"chest")
	assert_almost_eq(c.r, 0.1, 0.01)
	assert_eq(String(CosmeticsManager.wardrobe[2].get("label", "")), "RoundTripOutfit")


# ---------- Sprite paths ----------

func test_phase15_sprite_paths_load() -> void:
	for sprite in [
		"res://assets/sprites/ui/ach_badge_walker.png",
		"res://assets/sprites/ui/photo_mode_icon.png",
		"res://assets/sprites/ui/wardrobe_icon.png",
		"res://assets/sprites/ui/logbook_icon.png",
		"res://assets/sprites/ui/speedrun_icon.png",
		"res://assets/sprites/ui/accessibility_icon.png",
		"res://assets/sprites/ui/dye_pot_icon.png",
		"res://assets/sprites/ui/bug_report_icon.png",
		"res://assets/sprites/ui/ach_medallion_hunters_crown.png",
		"res://assets/sprites/steam/cards/trading_card_walker.png",
	]:
		assert_true(ResourceLoader.exists(sprite), "sprite missing: " + sprite)


# ---------- New input actions registered ----------

func test_phase15_input_actions_registered() -> void:
	for action in ["photo_mode", "toggle_bestiary", "toggle_wardrobe"]:
		assert_true(InputMap.has_action(action), "missing input action: " + action)


# ---------- UI panel scripts loadable ----------

func test_phase15_ui_panel_scripts_load() -> void:
	for path in [
		"res://scripts/ui/bestiary_panel.gd",
		"res://scripts/ui/logbook_panel.gd",
		"res://scripts/ui/world_settings_panel.gd",
		"res://scripts/ui/first_run_wizard.gd",
		"res://scripts/ui/run_history_panel.gd",
		"res://scripts/ui/world_statistics_panel.gd",
		"res://scripts/ui/damage_breakdown_panel.gd",
		"res://scripts/ui/death_recap_panel.gd",
		"res://scripts/ui/combo_counter_hud.gd",
		"res://scripts/ui/wardrobe_panel.gd",
		"res://scripts/ui/accessibility_settings_panel.gd",
		"res://scripts/ui/photo_mode_panel.gd",
		"res://scripts/ui/debug_overlay_hud.gd",
		"res://scripts/ui/speedrun_timer_hud.gd",
		"res://scripts/ui/achievement_toast.gd",
		"res://scripts/ui/subtitle_overlay.gd",
		"res://scripts/ui/bug_report_panel.gd",
		"res://scripts/ui/friend_list_panel.gd",
		"res://scripts/ui/bandwidth_meter_hud.gd",
		"res://scripts/ui/seasonal_banner.gd",
	]:
		var s: Script = load(path) as Script
		assert_not_null(s, "script missing: " + path)
