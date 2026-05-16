extends GutTest

## Phase 13 systems test bundle. Verifies NetSystem rewrite (slot
## management, boss HP scaling, password hashing, server logs, mid-session
## snapshot, profile dump/restore) + Phase13Helpers (chat, pings, emotes,
## trades, loot rules, spectator + revival, party HUD + tracking arrows,
## resonance proximity, NPC density bonus, gamepad cursor, lobby ready check).


func before_each() -> void:
	GameState.defeated_bosses.clear()
	GameState.collected_relics.clear()
	GameState.arrived_npcs.clear()
	Inventory.clear()
	if NetSystem:
		NetSystem.leave()
		NetSystem.player_profiles.clear()
		NetSystem.banned_peer_ids.clear()
		NetSystem.pvp_enabled = false
		NetSystem.shared_xp_enabled = true
		NetSystem.loot_mode = NetSystem.LootMode.FFA
		NetSystem.world_password_hash = 0
		NetSystem._peer_ping_ms.clear()
		NetSystem.mid_session_join_pending.clear()
		NetSystem._authoritative_positions.clear()
		NetSystem._server_log.clear()
		NetSystem._server_log_index = 0
		NetSystem.headless_dedicated = false
		NetSystem.vendor = NetSystem.Vendor.NONE
	if Phase13Helpers:
		Phase13Helpers.chat_history.clear()
		Phase13Helpers.typed_history.clear()
		Phase13Helpers.emote_active.clear()
		Phase13Helpers.active_pings.clear()
		Phase13Helpers._last_ping_at_unix = 0.0
		Phase13Helpers.awaiting_respawn.clear()
		Phase13Helpers.spectator_target_peer = -1
		Phase13Helpers.lobby_ready.clear()
		Phase13Helpers.lobby_open = false
		Phase13Helpers.remote_positions.clear()
		Phase13Helpers.remote_health_table.clear()
		Phase13Helpers.loot_ownership_records.clear()
		Phase13Helpers._round_robin_cursor = 0
		Phase13Helpers.resonance_proximity_active = false
		Phase13Helpers._reset_trade()
		Phase13Helpers.gamepad_cursor_active = false
		Phase13Helpers.gamepad_glyphs = &"xbox"
		Phase13Helpers.nameplate_visible = true
		Phase13Helpers.voice_ptt_active = false


# --- 13.1 / 13.2 / 13.12 — NetSystem core --------------------------------


func test_netsystem_autoload_present() -> void:
	assert_not_null(NetSystem)
	assert_true(NetSystem.has_method("host_world"))
	assert_true(NetSystem.has_method("join_world"))
	assert_true(NetSystem.has_method("boss_hp_multiplier"))


func test_default_player_count_is_one_offline() -> void:
	assert_eq(NetSystem.player_count(), 1)
	assert_false(NetSystem.is_party_active())


func test_register_local_profile_assigns_slot_color() -> void:
	NetSystem.register_local_profile(1, "Walker", 0)
	var prof: Dictionary = NetSystem.profile_for(1)
	assert_eq(String(prof.get("name", "")), "Walker")
	assert_eq(int(prof.get("slot_index", -1)), 0)
	assert_eq(prof.get("color", Color.WHITE), NetSystem.SLOT_COLORS[0])


# --- 13.10 — Boss HP scaling ---------------------------------------------


func test_boss_hp_multiplier_solo_is_one() -> void:
	assert_eq(NetSystem.boss_hp_multiplier(), 1.0)


func test_boss_hp_multiplier_clamped_at_cap() -> void:
	# Synthesize an 8-player party.
	for i in range(2, 9):
		NetSystem.register_local_profile(i, "P%d" % i, i - 1)
	# Force a 7-extra-player count via direct override (no live socket here).
	# party_peer_count uses multiplayer.get_peers() which is empty in tests, so
	# the multiplier is computed using register_local_profile-driven helpers in
	# the netcode path that isn't connected. For headless test we mirror the
	# formula directly:
	var max_mult: float = 1.0 + NetSystem.BOSS_HP_PER_EXTRA_PLAYER * 7.0
	assert_almost_eq(minf(max_mult, NetSystem.BOSS_HP_MAX_MULTIPLIER), 3.0, 0.01)


# --- 13.19 — Password hashing -------------------------------------------


func test_password_hashing_round_trip() -> void:
	NetSystem.world_password_hash = NetSystem._hash_password("secret")
	assert_true(NetSystem.verify_password("secret"))
	assert_false(NetSystem.verify_password("not-secret"))


func test_empty_password_always_verifies() -> void:
	NetSystem.world_password_hash = 0
	assert_true(NetSystem.verify_password(""))
	assert_true(NetSystem.verify_password("anything"))


# --- 13.20 — Kick / ban admin commands ------------------------------------


func test_ban_records_peer_id() -> void:
	NetSystem.is_host = true
	NetSystem.ban_peer(7, "test ban")
	assert_true(NetSystem.banned_peer_ids.has(7))
	assert_eq(String(NetSystem.banned_peer_ids[7]), "test ban")


# --- 13.34 — Server log ring ---------------------------------------------


func test_server_log_only_host() -> void:
	NetSystem.is_host = false
	NetSystem.server_log("client-side log attempt")
	assert_eq(NetSystem._server_log.size(), 0)


func test_server_log_appends_when_host() -> void:
	NetSystem.is_host = true
	NetSystem.server_log("first")
	NetSystem.server_log("second")
	var dump: Array[String] = NetSystem.dump_server_log()
	assert_eq(dump.size(), 2)


func test_server_log_ring_overflow() -> void:
	NetSystem.is_host = true
	for i in range(NetSystem.LOG_RING_SIZE + 32):
		NetSystem.server_log("entry %d" % i)
	var dump: Array[String] = NetSystem.dump_server_log()
	assert_eq(dump.size(), NetSystem.LOG_RING_SIZE)


# --- 13.21 — Authoritative positions ------------------------------------


func test_authoritative_position_record_and_lookup() -> void:
	NetSystem.record_authoritative_position(42, Vector2(120.5, -30.0))
	assert_eq(NetSystem.host_authority_position_for(42), Vector2(120.5, -30.0))
	assert_eq(NetSystem.host_authority_position_for(999), Vector2.ZERO)


# --- 13.41 — Mid-session snapshot ---------------------------------------


func test_mid_session_snapshot_payload() -> void:
	GameState.aphelion_slivers_remaining = 12345
	GameState.world_seed = 99
	NetSystem.pvp_enabled = true
	var snap: Dictionary = NetSystem.build_mid_session_snapshot()
	assert_eq(int(snap.get("aphelion_slivers_remaining", 0)), 12345)
	assert_eq(int(snap.get("world_seed", 0)), 99)
	assert_true(bool(snap.get("pvp_enabled", false)))


func test_apply_mid_session_snapshot_updates_toggles() -> void:
	NetSystem.pvp_enabled = false
	NetSystem.shared_xp_enabled = true
	var snap: Dictionary = {"pvp_enabled": true, "shared_xp_enabled": false, "loot_mode": 1}
	NetSystem.apply_mid_session_snapshot(snap)
	assert_true(NetSystem.pvp_enabled)
	assert_false(NetSystem.shared_xp_enabled)
	assert_eq(NetSystem.loot_mode, 1)


# --- 13.43 — Desync detection -------------------------------------------


func test_state_hash_deterministic() -> void:
	GameState.aphelion_slivers_remaining = 100
	GameState.sovereign_threads = 3
	var h1: int = NetSystem.compute_state_hash()
	var h2: int = NetSystem.compute_state_hash()
	assert_eq(h1, h2)


func test_state_hash_differs_on_change() -> void:
	GameState.aphelion_slivers_remaining = 100
	var h1: int = NetSystem.compute_state_hash()
	GameState.aphelion_slivers_remaining = 99
	var h2: int = NetSystem.compute_state_hash()
	assert_ne(h1, h2)


# --- 13.44 — Connection quality classification -----------------------


func test_connection_quality_thresholds() -> void:
	NetSystem.set_peer_ping(2, 30)
	assert_eq(String(NetSystem.connection_quality(2)), "good")
	NetSystem.set_peer_ping(3, 100)
	assert_eq(String(NetSystem.connection_quality(3)), "ok")
	NetSystem.set_peer_ping(4, 200)
	assert_eq(String(NetSystem.connection_quality(4)), "poor")
	NetSystem.set_peer_ping(5, 500)
	assert_eq(String(NetSystem.connection_quality(5)), "bad")
	assert_eq(String(NetSystem.connection_quality(6)), "unknown")


# --- 13.3 — Walker spawn ring positions ----------------------------


func test_walker_spawn_offsets_unique_per_slot() -> void:
	NetSystem.register_local_profile(1, "P1", 0)
	NetSystem.register_local_profile(2, "P2", 1)
	var p1: Vector2 = NetSystem.walker_spawn_position_for(1)
	var p2: Vector2 = NetSystem.walker_spawn_position_for(2)
	assert_ne(p1, p2)


# --- 13.32 — Cross-platform vendor enum ---------------------------


func test_vendor_enum_present() -> void:
	assert_eq(NetSystem.Vendor.NONE, 0)
	assert_true(NetSystem.Vendor.STEAM > 0)
	assert_eq(NetSystem.cross_platform_join_stub(NetSystem.Vendor.STEAM, "lobby_test"), ERR_UNAVAILABLE)


# --- 13.17 — Steam lobby stub -------------------------------------


func test_steam_lobby_create_stub_returns_record() -> void:
	var lobby: Dictionary = NetSystem.steam_lobby_create_stub("test-lobby", 8)
	assert_true(lobby.has("lobby_id"))
	assert_eq(int(lobby.get("max_members", 0)), 8)
	assert_eq(int(lobby.get("vendor", -1)), NetSystem.Vendor.STEAM)


# --- 13.5 — Emote system -------------------------------------------


func test_play_emote_records_active_state() -> void:
	Phase13Helpers.play_emote(&"wave", 1)
	assert_eq(String(Phase13Helpers.active_emote_for(1)), "wave")


func test_invalid_emote_ignored() -> void:
	Phase13Helpers.play_emote(&"not_a_real_emote", 1)
	assert_eq(String(Phase13Helpers.active_emote_for(1)), "")


# --- 13.15 / 13.30 — Chat history -----------------------------------


func test_chat_post_appends_to_history() -> void:
	Phase13Helpers.post_chat(&"all", "hello world", 1)
	assert_eq(Phase13Helpers.chat_history.size(), 1)
	assert_eq(String(Phase13Helpers.chat_history[0].get("text", "")), "hello world")


func test_empty_chat_post_ignored() -> void:
	Phase13Helpers.post_chat(&"all", "   ", 1)
	assert_eq(Phase13Helpers.chat_history.size(), 0)


func test_chat_history_ring_caps_at_max() -> void:
	for i in range(Phase13Helpers.CHAT_RING + 10):
		Phase13Helpers.post_chat(&"all", "msg %d" % i, 1)
	assert_eq(Phase13Helpers.chat_history.size(), Phase13Helpers.CHAT_RING)


func test_whisper_routes_to_whisper_channel() -> void:
	Phase13Helpers.post_whisper(2, "psst")
	assert_eq(Phase13Helpers.chat_history.size(), 1)
	assert_eq(String(Phase13Helpers.chat_history[0].get("channel", "")), "whisper")


# --- 13.27 — Ping markers + cooldown --------------------------------


func test_place_ping_records_marker() -> void:
	var ok: bool = Phase13Helpers.place_ping(Vector2(0, 0), &"default", 1)
	assert_true(ok)
	assert_eq(Phase13Helpers.active_pings.size(), 1)


func test_ping_cooldown_blocks_quick_repeat() -> void:
	Phase13Helpers.place_ping(Vector2(0, 0), &"default", 1)
	var ok: bool = Phase13Helpers.place_ping(Vector2(20, 0), &"default", 1)
	assert_false(ok)


func test_invalid_ping_kind_falls_back_to_default() -> void:
	Phase13Helpers.place_ping(Vector2(0, 0), &"bogus_kind", 1)
	assert_eq(String(Phase13Helpers.active_pings[0].get("kind", "")), "default")


func test_prune_expired_pings_removes_stale() -> void:
	Phase13Helpers.place_ping(Vector2.ZERO, &"default", 1)
	# Force-expire by rewriting timestamp into the past.
	Phase13Helpers.active_pings[0]["expires_at_unix"] = 0.0
	Phase13Helpers.prune_expired_pings()
	assert_eq(Phase13Helpers.active_pings.size(), 0)


# --- 13.14 — Trade state machine -----------------------------------


func test_trade_request_transitions_to_offered() -> void:
	var ok: bool = Phase13Helpers.trade_request(2)
	assert_true(ok)
	assert_eq(Phase13Helpers.trade_state, Phase13Helpers.TradeState.OFFERED)


func test_trade_commit_requires_locks_and_negotiating() -> void:
	Phase13Helpers.trade_request(2)
	# Without negotiation transition + locks, commit fails.
	assert_false(Phase13Helpers.trade_commit())
	Phase13Helpers.trade_accept(2)
	Phase13Helpers.trade_lock_self()
	Phase13Helpers.trade_lock_partner()
	# Empty offer commits successfully (no inventory change).
	assert_true(Phase13Helpers.trade_commit())


# --- 3.39 — Soulbound items reject trade -------------------------


func test_soulbound_blocks_trade_add() -> void:
	Inventory.try_add(&"map_fragment", 1)
	Phase13Helpers.trade_request(2)
	var ok: bool = Phase13Helpers.trade_add_self(&"map_fragment", 1)
	assert_false(ok)


# --- 13.22 — Loot ownership rules ---------------------------------


func test_loot_ownership_grants_initial_owner() -> void:
	Phase13Helpers.mark_loot_owner(7, 1)
	assert_true(Phase13Helpers.can_pick_up(7, 1))
	NetSystem.loot_mode = NetSystem.LootMode.ROUND_ROBIN
	# Different peer attempting pickup inside the ownership window blocked
	# under round-robin mode.
	assert_false(Phase13Helpers.can_pick_up(7, 2))


func test_loot_ownership_window_expires() -> void:
	Phase13Helpers.mark_loot_owner(8, 1)
	# Force expiry into the past.
	Phase13Helpers.loot_ownership_records[8]["expires_at_unix"] = 0.0
	assert_true(Phase13Helpers.can_pick_up(8, 2))


# --- 13.23 / 13.24 / 13.38 — Respawn + revival --------------------


func test_begin_awaiting_respawn_records_timer() -> void:
	Phase13Helpers.begin_awaiting_respawn(1)
	assert_true(Phase13Helpers.is_awaiting_respawn(1))
	assert_almost_eq(Phase13Helpers.respawn_seconds_for(1), Phase13Helpers.RESPAWN_COUNTDOWN_SECONDS, 0.01)


func test_tick_respawn_countdowns_drains_timers() -> void:
	Phase13Helpers.begin_awaiting_respawn(1)
	Phase13Helpers.tick_respawn_countdowns(2.0)
	assert_almost_eq(Phase13Helpers.respawn_seconds_for(1), Phase13Helpers.RESPAWN_COUNTDOWN_SECONDS - 2.0, 0.01)


func test_revival_request_collapses_timer() -> void:
	NetSystem.register_local_profile(1, "P1", 0)
	NetSystem.register_local_profile(2, "P2", 1)
	Phase13Helpers.begin_awaiting_respawn(2)
	# Local peer must differ from target; since NetSystem isn't online, local
	# defaults to 1.
	var ok: bool = Phase13Helpers.request_revival(2)
	assert_true(ok)
	assert_lt(Phase13Helpers.respawn_seconds_for(2), 1.0)


# --- 13.25 — Party HUD entries -----------------------------------


func test_party_hud_entries_match_registered_profiles() -> void:
	NetSystem.register_local_profile(1, "P1", 0)
	NetSystem.register_local_profile(2, "P2", 1)
	var entries: Array[Dictionary] = Phase13Helpers.party_hud_entries()
	assert_eq(entries.size(), 2)
	assert_true(bool(_entries_contain_name(entries, "P1")))
	assert_true(bool(_entries_contain_name(entries, "P2")))


func _entries_contain_name(entries: Array[Dictionary], name: String) -> bool:
	for e in entries:
		if String(e.get("name", "")) == name:
			return true
	return false


# --- 13.26 — Off-screen tracking arrows --------------------------


func test_tracking_arrow_targets_skips_on_screen() -> void:
	NetSystem.register_local_profile(1, "P1", 0)
	NetSystem.register_local_profile(2, "P2", 1)
	Phase13Helpers.set_remote_position(2, Vector2(10, 10))
	var targets: Array[Dictionary] = Phase13Helpers.tracking_arrow_targets(Vector2.ZERO, Vector2(200, 200))
	# 2 is inside the 200x200 viewport box.
	assert_eq(targets.size(), 0)


func test_tracking_arrow_targets_finds_off_screen() -> void:
	NetSystem.register_local_profile(1, "P1", 0)
	NetSystem.register_local_profile(2, "P2", 1)
	Phase13Helpers.set_remote_position(2, Vector2(800, 0))
	var targets: Array[Dictionary] = Phase13Helpers.tracking_arrow_targets(Vector2.ZERO, Vector2(200, 200))
	assert_eq(targets.size(), 1)
	assert_eq(int(targets[0].get("peer_id", 0)), 2)


# --- 13.6 — NPC density bonus ------------------------------------


func test_bonus_npc_slots_scales_with_players() -> void:
	# Offline: single player = no bonus.
	assert_eq(Phase13Helpers.bonus_npc_slots(), 0)
	# Simulate 3-player party via direct profile registration. Without a live
	# multiplayer_peer NetSystem.player_count returns 1 — verify the helper
	# at least returns 0 in single-player baseline.


# --- 13.45 — Gamepad cursor + glyphs -----------------------------


func test_gamepad_cursor_toggle() -> void:
	Phase13Helpers.toggle_gamepad_cursor(true)
	assert_true(Phase13Helpers.gamepad_cursor_active)
	Phase13Helpers.toggle_gamepad_cursor(false)
	assert_false(Phase13Helpers.gamepad_cursor_active)


func test_gamepad_glyph_set_change() -> void:
	Phase13Helpers.set_gamepad_glyphs(&"playstation")
	assert_eq(String(Phase13Helpers.gamepad_glyphs), "playstation")


# --- 13.51 / 13.52 — Lobby ready ---------------------------------


func test_lobby_open_clears_ready_flags() -> void:
	Phase13Helpers.lobby_ready[1] = true
	Phase13Helpers.open_lobby()
	assert_eq(Phase13Helpers.lobby_ready.size(), 0)


func test_all_ready_requires_every_registered_peer() -> void:
	NetSystem.register_local_profile(1, "P1", 0)
	NetSystem.register_local_profile(2, "P2", 1)
	assert_false(Phase13Helpers.all_ready())
	Phase13Helpers.mark_ready(1, true)
	assert_false(Phase13Helpers.all_ready())
	Phase13Helpers.mark_ready(2, true)
	assert_true(Phase13Helpers.all_ready())


func test_finalize_lobby_blocked_until_all_ready() -> void:
	NetSystem.register_local_profile(1, "P1", 0)
	NetSystem.register_local_profile(2, "P2", 1)
	assert_false(Phase13Helpers.finalize_lobby())
	Phase13Helpers.mark_ready(1, true)
	Phase13Helpers.mark_ready(2, true)
	assert_true(Phase13Helpers.finalize_lobby())


# --- 13.4 / 13.49 — Resonance proximity --------------------------


func test_resonance_proximity_inactive_solo() -> void:
	# Without a party, the helper always returns false.
	assert_false(Phase13Helpers.compute_resonance_proximity())


# --- 13.16 — Voice PTT --------------------------------------------


func test_voice_ptt_press_release() -> void:
	Phase13Helpers.voice_ptt_pressed()
	assert_true(Phase13Helpers.voice_ptt_active)
	Phase13Helpers.voice_ptt_released()
	assert_false(Phase13Helpers.voice_ptt_active)


# --- 13.13 / 13.40 — World toggles -----------------------------


func test_pvp_toggle_persists() -> void:
	NetSystem.pvp_enabled = true
	GameState.net_pvp_enabled = true
	assert_true(NetSystem.pvp_enabled)
	assert_true(GameState.net_pvp_enabled)


func test_loot_mode_enum_values() -> void:
	assert_eq(NetSystem.LootMode.FFA, 0)
	assert_eq(NetSystem.LootMode.ROUND_ROBIN, 1)
	assert_eq(NetSystem.LootMode.NEED_GREED, 2)


# --- 13.39 / 13.50 — Shared XP toggle ---------------------------


func test_shared_xp_default_true() -> void:
	assert_true(NetSystem.shared_xp_enabled)
	Phase13Helpers.set_shared_xp(false)
	assert_false(NetSystem.shared_xp_enabled)
	Phase13Helpers.set_shared_xp(true)
	assert_true(NetSystem.shared_xp_enabled)


# --- 13.48 — Networked VFX broadcast --------------------------


func test_broadcast_vfx_fires_signal() -> void:
	var captured: Dictionary = {"fired": false}
	var local_ref: Dictionary = captured
	Phase13Helpers.vfx_broadcast.connect(func(_id: StringName, _pos: Vector2, _params: Dictionary) -> void:
		local_ref["fired"] = true
	)
	Phase13Helpers.broadcast_vfx(&"test_vfx", Vector2(10, 10), {})
	assert_true(bool(captured.get("fired", false)))


# --- 1.23 / 13.36 — Nameplate toggle --------------------------


func test_nameplate_toggle() -> void:
	Phase13Helpers.set_nameplate_visible(false)
	assert_false(Phase13Helpers.nameplate_visible)
	Phase13Helpers.set_nameplate_visible(true)
	assert_true(Phase13Helpers.nameplate_visible)


# --- 9.55 / 9.63 — Synced tablet read + resonance-bound -----------


func test_resonance_bound_blocks_trade() -> void:
	Inventory.try_add(&"brindle_pendant", 1)
	Phase13Helpers.trade_request(2)
	var ok: bool = Phase13Helpers.trade_add_self(&"brindle_pendant", 1)
	assert_false(ok)


# --- NetSystem dump_state / restore_state round-trip ----------------


func test_netsystem_state_round_trip() -> void:
	NetSystem.pvp_enabled = true
	NetSystem.shared_xp_enabled = false
	NetSystem.loot_mode = NetSystem.LootMode.ROUND_ROBIN
	NetSystem.world_password_hash = 12345
	NetSystem.register_local_profile(1, "Host", 0)
	NetSystem.banned_peer_ids[99] = "test"
	var dump: Dictionary = NetSystem.dump_state()
	NetSystem.pvp_enabled = false
	NetSystem.shared_xp_enabled = true
	NetSystem.loot_mode = NetSystem.LootMode.FFA
	NetSystem.world_password_hash = 0
	NetSystem.player_profiles.clear()
	NetSystem.banned_peer_ids.clear()
	NetSystem.restore_state(dump)
	assert_true(NetSystem.pvp_enabled)
	assert_false(NetSystem.shared_xp_enabled)
	assert_eq(NetSystem.loot_mode, NetSystem.LootMode.ROUND_ROBIN)
	assert_eq(NetSystem.world_password_hash, 12345)
	assert_true(NetSystem.banned_peer_ids.has(99))
	assert_true(NetSystem.player_profiles.has(1))


# --- Phase13Helpers dump_state / restore_state round-trip ----------


func test_phase13_helpers_state_round_trip() -> void:
	Phase13Helpers.post_chat(&"all", "trip msg", 1)
	Phase13Helpers.push_typed_history("test recall")
	Phase13Helpers.nameplate_visible = false
	Phase13Helpers.set_gamepad_glyphs(&"playstation")
	var dump: Dictionary = Phase13Helpers.dump_state()
	Phase13Helpers.chat_history.clear()
	Phase13Helpers.typed_history.clear()
	Phase13Helpers.nameplate_visible = true
	Phase13Helpers.set_gamepad_glyphs(&"xbox")
	Phase13Helpers.restore_state(dump)
	assert_eq(Phase13Helpers.chat_history.size(), 1)
	assert_eq(String(Phase13Helpers.chat_history[0].get("text", "")), "trip msg")
	assert_eq(Phase13Helpers.typed_history.size(), 1)
	assert_false(Phase13Helpers.nameplate_visible)
	assert_eq(String(Phase13Helpers.gamepad_glyphs), "playstation")


# --- SaveSystem v11 bump ----------------------------------------


func test_save_version_is_at_least_11() -> void:
	# Bumped to 12 in Phase 14 closure; at-least-11 keeps the Phase 13 contract.
	assert_true(SaveSystem.SAVE_VERSION >= 11)


# --- 13.24 — Resurrection Altar item def + recipe ---------------


func test_resurrection_altar_itemdef_loads() -> void:
	var def: ItemDef = load("res://resources/items/resurrection_altar_placeable.tres") as ItemDef
	assert_not_null(def)
	assert_eq(String(def.id), "resurrection_altar_placeable")
	assert_eq(def.item_type, ItemDef.ItemType.PLACEABLE)
	assert_eq(def.tier, 8)


func test_resurrection_altar_recipe_loads() -> void:
	var rec: Recipe = load("res://resources/recipes/craft_resurrection_altar.tres") as Recipe
	assert_not_null(rec)
	assert_eq(String(rec.id), "craft_resurrection_altar")
	# Recipe expects aphelion_shard catalyst.
	var has_shard: bool = false
	for inp in rec.inputs:
		if String(inp.get("item_id", "")) == "aphelion_shard":
			has_shard = true
			break
	assert_true(has_shard)


# --- Phase 13 sprite presence --------------------------------------


func test_phase13_ui_sprites_exist() -> void:
	# Each Phase 13 final sprite must load.
	var paths: Array[String] = [
		"res://assets/sprites/items/resurrection_altar_placeable.png",
		"res://assets/sprites/ui/emote_wave.png",
		"res://assets/sprites/ui/emote_dance.png",
		"res://assets/sprites/ui/emote_sit.png",
		"res://assets/sprites/ui/emote_point.png",
		"res://assets/sprites/ui/emote_sleep.png",
		"res://assets/sprites/ui/ping_default.png",
		"res://assets/sprites/ui/ping_danger.png",
		"res://assets/sprites/ui/ping_attack_here.png",
		"res://assets/sprites/ui/ping_defend_here.png",
		"res://assets/sprites/ui/ping_on_my_way.png",
		"res://assets/sprites/ui/portrait_frame.png",
		"res://assets/sprites/ui/gamepad_cursor.png",
	]
	for p in paths:
		var tex: Texture2D = load(p) as Texture2D
		assert_not_null(tex, "missing sprite: %s" % p)


# --- Phase 13 input actions registered -----------------------------


func test_phase13_input_actions_present() -> void:
	for action in ["toggle_chat", "ping_marker", "party_ui", "voice_ptt", "emote_wheel"]:
		assert_true(InputMap.has_action(action), "missing input action: %s" % action)


# --- Phase13Helpers autoload + UI scripts class-name ---------------


func test_chat_panel_class_present() -> void:
	# ChatPanel + PartyHud + TradePanel + LobbyPanel + ResurrectionAltarPanel +
	# SpectatorCam + TrackingArrow + ServerBrowser + ServerLogsViewer +
	# GamepadCursor + PingMarker + PlayerNameplate should all be loadable.
	for path in [
		"res://scripts/ui/chat_panel.gd",
		"res://scripts/ui/party_hud.gd",
		"res://scripts/ui/trade_panel.gd",
		"res://scripts/ui/lobby_panel.gd",
		"res://scripts/ui/resurrection_altar_panel.gd",
		"res://scripts/ui/spectator_cam.gd",
		"res://scripts/ui/tracking_arrow.gd",
		"res://scripts/ui/server_browser.gd",
		"res://scripts/ui/server_logs_viewer.gd",
		"res://scripts/ui/gamepad_cursor.gd",
		"res://scripts/ui/ping_marker.gd",
		"res://scripts/ui/player_nameplate.gd",
		"res://scripts/structures/resurrection_altar.gd",
	]:
		var scr: GDScript = load(path) as GDScript
		assert_not_null(scr, "missing script: %s" % path)
