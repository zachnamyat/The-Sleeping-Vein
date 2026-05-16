extends Node

## Global event bus.
## All cross-system signals fire through this autoload.
## Subscribers connect on _ready in their own scripts.

# --- World / generation ---
signal world_seeded(seed_value: int)
signal chunk_generated(chunk_coord: Vector2i)
signal chunk_visited(chunk_coord: Vector2i, biome_id: StringName)
signal tile_changed(tile_coord: Vector2i, old_id: int, new_id: int)
signal biome_changed(old_biome_id: StringName, new_biome_id: StringName)
signal respawn_point_set(world_pos: Vector2)

# --- Player ---
signal player_spawned(player: Node)
signal player_died(player: Node)
signal player_respawned(player: Node, slivers_remaining: int)
signal player_health_changed(current: int, maximum: int)
signal player_mana_changed(current: int, maximum: int)
signal player_hunger_changed(current: float, maximum: float)
# Phase 10.7 — swim state toggles on water tile / drowned biome entry.
signal player_swim_changed(is_swimming: bool)
# Phase 10.8 — breath meter; HUD subscribes for the meter UI.
signal player_breath_changed(current_seconds: float, max_seconds: float)
# Phase 10 — tile-hazard / environmental events the HUD + barks listen for.
signal player_entered_hazard_tile(tile_kind: StringName)
signal player_exited_hazard_tile(tile_kind: StringName)

# --- Combat ---
signal damage_dealt(source: Node, target: Node, amount: int, type: StringName)
signal damage_floated(world_pos: Vector2, amount: int, is_crit: bool, type: StringName)
signal entity_killed(entity: Node, killer: Node)
signal camera_shake_requested(intensity: float, duration: float)
signal hit_pause_requested(duration: float)
signal screen_pulse_requested(strength: float, duration: float)
signal letterbox_requested(enabled: bool, fade_seconds: float)
## Phase 6 combat-depth signals.
signal player_dodge_started(direction: Vector2)
signal player_block_changed(active: bool, fraction: float)
signal player_parry_success(attacker: Node)
signal player_charge_progress(fraction: float)  ## 0..1 charge bar
signal player_special_used(special_id: StringName)
signal lightning_arc_requested(from_pos: Vector2, to_pos: Vector2)
signal aoe_indicator_requested(world_pos: Vector2, radius: float, duration: float, color: Color)
signal combat_intensity_changed(intensity: float)  ## 0..1 — adaptive music ramp
signal stat_recompute_requested  ## PlayerStats listens; bubbles equipment changes

# --- Inventory / crafting ---
signal item_picked_up(item_id: StringName, count: int)
signal inventory_changed
signal recipe_unlocked(recipe_id: StringName)
signal item_crafted(item_id: StringName, count: int)

# --- Skills ---
signal skill_xp_gained(skill_id: StringName, amount: int)
signal skill_leveled_up(skill_id: StringName, new_level: int)
signal talent_unlocked(skill_id: StringName, talent_id: StringName)

# --- Boss / progression ---
signal boss_engaged(boss_id: StringName)
signal boss_defeated(boss_id: StringName)
signal sovereign_defeated(sovereign_id: StringName, fragment_id: StringName)
signal aphelion_dimmed(slivers_remaining: int)

# --- NPC ---
signal npc_arrived(npc_id: StringName)
signal npc_dialogue_opened(npc_id: StringName)

# --- UI ---
signal ui_toast(text: String, duration: float)
signal ui_compendium_entry_unlocked(entry_id: StringName)

# --- Phase 15 — Polish & gap closure ---
signal phase15_combo_changed(count: int)
signal phase15_difficulty_changed(preset: StringName)
signal phase15_hardcore_toggled(active: bool)
signal phase15_seasonal_event_started(event_id: StringName)
signal phase15_seasonal_event_ended(event_id: StringName)
signal phase15_photo_mode_toggled(active: bool)
signal phase15_speedrun_split_added(label: String, total_seconds: float)
signal phase15_easter_egg_discovered(id: StringName)
signal phase15_run_history_added(record: Dictionary)
signal phase15_cosmetic_dye_applied(slot: StringName, color: Color)
signal phase15_wardrobe_outfit_changed(outfit_index: int)
signal phase15_visual_layer_changed(layer: StringName, item_id: StringName)
signal phase15_first_run_wizard_completed()
signal phase15_locale_changed(locale: StringName)
signal phase15_aim_assist_changed(active: bool)
signal phase15_subtitle_emitted(text: String, kind: StringName)
signal phase15_bandwidth_sampled(bps_in: int, bps_out: int)
signal phase15_friend_status_changed(friend_id: String, online: bool)

# --- Phase 13 — Multiplayer ---
signal net_peer_joined(peer_id: int, slot_index: int)
signal net_peer_left(peer_id: int)
signal net_chat_posted(peer_id: int, channel: StringName, text: String)
signal net_emote_played(peer_id: int, emote_id: StringName)
signal net_ping_placed(peer_id: int, world_pos: Vector2, kind: StringName)
signal net_trade_state_changed(state: int)
signal net_player_revived(target_peer: int, by_peer: int)
signal net_resonance_proximity_changed(active: bool)
signal net_boss_hp_scaled(multiplier: float)
signal net_party_player_count_changed(count: int)
signal net_lobby_ready_changed(peer_id: int, ready: bool)
signal net_vfx_broadcast(vfx_id: StringName, world_pos: Vector2, params: Dictionary)
signal net_nameplate_visibility_changed(active: bool)
signal net_desync_detected(local_hash: int, remote_hash: int)
