extends Node

## Phase 13 — consolidated helpers autoload.
##
## NetSystem (`scripts/systems/multiplayer.gd`) handles the raw transport +
## per-peer profile records + boss-scaling math. THIS autoload owns the
## gameplay-side machinery that hangs off that transport:
##
##   13.4  Resonance-pulse multi-Walker flicker (proximity-driven hand glow)
##   13.5  Emote system + emote-recently table
##   13.6  Multi-player NPC density bonus
##   13.14 Trade interface state machine (offer/accept/cancel)
##   13.15 Text chat channels + scrollback + history
##   13.16 Voice-chat PTT stub
##   13.22 Dropped-item ownership / loot etiquette rules
##   13.23 Spectator mode for dead / awaiting-respawn players
##   13.24 Resurrection altar (revive other players)
##   13.25 Party UI HP + ping aggregation
##   13.26 Player tracking arrows / off-screen indicators
##   13.27 Tab-to-ping marker system
##   13.29 Whisper / private chat
##   13.30 Chat log scrollback + history
##   13.36 Multi-Walker shared death-flicker visual
##   13.37 Multiplayer NPC dialogue addressed to all Walkers
##   13.38 Respawn countdown UI + ghost-cam timer
##   13.39 Shared-XP toggle (UI-side hook; NetSystem carries the bool)
##   13.40 Loot-roll vs FFA toggle
##   13.45/13.46 Gamepad cursor + glyph swap
##   13.48 Networked particle / VFX broadcast
##   13.49 Resonance-pulse proximity hand-flicker (§7.6)
##   13.50 Multiplayer XP-share toggle
##   13.51 Multiplayer lobby UI shell
##   13.52 Pre-game ready check
##   3.39  Soulbound items (no-trade flag for multiplayer)
##   7.12  Skill XP shared in party (multiplayer)
##   9.55  Synced lore-tablet reading
##   9.63  Walker Resonance-bound items (no-spoilage rule)
##   1.23  Player nameplate above head

signal chat_posted(peer_id: int, channel: StringName, text: String)
signal whisper_posted(from_peer: int, to_peer: int, text: String)
signal emote_played(peer_id: int, emote_id: StringName)
signal ping_placed(peer_id: int, world_pos: Vector2, kind: StringName)
signal trade_offered(from_peer: int, to_peer: int)
signal trade_accepted(from_peer: int, to_peer: int)
signal trade_cancelled
signal trade_completed
signal player_revival_requested(by_peer: int, target_peer: int)
signal lobby_ready_changed(peer_id: int, ready: bool)
signal lobby_finalized
signal vfx_broadcast(vfx_id: StringName, world_pos: Vector2, params: Dictionary)
signal nameplate_visibility_changed(active: bool)

# ---------------------------------------------------------------------------
# 13.15 / 13.29 / 13.30 — Chat. Channels: "all" / "party" / "trade" / "whisper".
# Scrollback ring of 200 messages.
# ---------------------------------------------------------------------------
const CHAT_RING: int = 200
const CHANNELS: Array[StringName] = [&"all", &"party", &"trade", &"system"]
var chat_history: Array[Dictionary] = []       # newest at the end
var typed_history: Array[String] = []          # up-arrow recall
var typed_history_max: int = 32
var chat_panel_open: bool = false


func post_chat(channel: StringName, text: String, peer_id: int = -1) -> void:
	if text.strip_edges().is_empty():
		return
	var pid: int = peer_id
	if pid < 0:
		pid = NetSystem.local_peer_id() if NetSystem else 1
	var entry: Dictionary = {
		"peer_id": pid,
		"channel": String(channel),
		"text": text,
		"t": Time.get_unix_time_from_system(),
	}
	chat_history.append(entry)
	while chat_history.size() > CHAT_RING:
		chat_history.pop_front()
	chat_posted.emit(pid, channel, text)


func post_whisper(to_peer: int, text: String) -> void:
	if text.strip_edges().is_empty() or to_peer <= 0:
		return
	var from_peer: int = NetSystem.local_peer_id() if NetSystem else 1
	whisper_posted.emit(from_peer, to_peer, text)
	post_chat(&"whisper", "[w→%d] %s" % [to_peer, text], from_peer)


func push_typed_history(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	typed_history.append(text)
	while typed_history.size() > typed_history_max:
		typed_history.pop_front()


# 13.37 — Multiplayer NPC dialogue address. The /all channel announcements
# now carry a "from NPC" tag so every player sees Aelstren / Brindle / etc.
func post_npc_dialogue(npc_id: StringName, line: String) -> void:
	post_chat(&"system", "[NPC %s] %s" % [String(npc_id), line], 0)


# ---------------------------------------------------------------------------
# 13.4 / 13.36 / 13.49 — Resonance-pulse hand-flicker between proximate
# Walkers. Lore §7.6: when two Walkers stand near each other their hand-of-
# light glows brighter and briefly de-syncs. Logical state lives here;
# rendering is handed off to `player_controller.gd:_attach_visibility_aura`.
# ---------------------------------------------------------------------------
const RESONANCE_PROXIMITY_PX: float = 96.0
const RESONANCE_FLICKER_PERIOD: float = 1.4

var resonance_proximity_active: bool = false


func compute_resonance_proximity() -> bool:
	# Returns true if the local Walker is within RESONANCE_PROXIMITY_PX of any
	# other Walker. Single-player path: always false.
	if NetSystem == null or not NetSystem.is_party_active():
		resonance_proximity_active = false
		return false
	var tree := get_tree()
	if tree == null:
		return false
	var walkers := tree.get_nodes_in_group("player")
	if walkers.size() < 2:
		resonance_proximity_active = false
		return false
	var first := walkers[0] as Node2D
	for w in walkers:
		if w == first:
			continue
		if (w as Node2D).global_position.distance_to(first.global_position) <= RESONANCE_PROXIMITY_PX:
			resonance_proximity_active = true
			return true
	resonance_proximity_active = false
	return false


# ---------------------------------------------------------------------------
# 13.5 — Emote system. Per-peer "last emote played at" so the UI can show a
# bubble for 3s.
# ---------------------------------------------------------------------------
const EMOTE_VISIBLE_SECONDS: float = 3.0
const EMOTES: Array[StringName] = [
	&"wave", &"dance", &"sit", &"point", &"sleep",
	&"laugh", &"cry", &"yes", &"no", &"on_my_way", &"thanks",
]

var emote_active: Dictionary = {}    # peer_id -> { id, expires_at_unix }


func play_emote(emote_id: StringName, peer_id: int = -1) -> void:
	if not EMOTES.has(emote_id):
		return
	var pid: int = peer_id
	if pid < 0:
		pid = NetSystem.local_peer_id() if NetSystem else 1
	emote_active[pid] = {
		"id": emote_id,
		"expires_at_unix": Time.get_unix_time_from_system() + EMOTE_VISIBLE_SECONDS,
	}
	emote_played.emit(pid, emote_id)


func active_emote_for(peer_id: int) -> StringName:
	var rec: Dictionary = emote_active.get(peer_id, {})
	if rec.is_empty():
		return &""
	if rec.get("expires_at_unix", 0.0) < Time.get_unix_time_from_system():
		emote_active.erase(peer_id)
		return &""
	return StringName(String(rec.get("id", "")))


# ---------------------------------------------------------------------------
# 13.27 — Tab-to-ping marker system. Each ping has a kind (default / danger /
# attack-here / defend-here / on-my-way). Markers live ~7s and fade.
# ---------------------------------------------------------------------------
const PING_DURATION_SECONDS: float = 7.0
const PING_KINDS: Array[StringName] = [&"default", &"danger", &"attack_here", &"defend_here", &"on_my_way"]
const PING_COOLDOWN_SECONDS: float = 1.0

var _last_ping_at_unix: float = 0.0
var active_pings: Array[Dictionary] = []     # {peer_id, world_pos, kind, expires_at_unix}


func place_ping(world_pos: Vector2, kind: StringName = &"default", peer_id: int = -1) -> bool:
	var now: float = Time.get_unix_time_from_system()
	if now - _last_ping_at_unix < PING_COOLDOWN_SECONDS:
		return false
	if not PING_KINDS.has(kind):
		kind = &"default"
	_last_ping_at_unix = now
	var pid: int = peer_id
	if pid < 0:
		pid = NetSystem.local_peer_id() if NetSystem else 1
	active_pings.append({
		"peer_id": pid,
		"world_pos": world_pos,
		"kind": String(kind),
		"expires_at_unix": now + PING_DURATION_SECONDS,
	})
	ping_placed.emit(pid, world_pos, kind)
	return true


func prune_expired_pings() -> void:
	var now: float = Time.get_unix_time_from_system()
	var keep: Array[Dictionary] = []
	for p in active_pings:
		if float(p.get("expires_at_unix", 0.0)) > now:
			keep.append(p)
	active_pings = keep


# ---------------------------------------------------------------------------
# 13.14 — Trade. State machine: idle -> offered -> accepted -> committed.
# Each side adds items to their offer slots; either side hitting Lock then
# both hitting Confirm executes the swap.
# ---------------------------------------------------------------------------
enum TradeState { IDLE, OFFERED, NEGOTIATING, LOCKED, COMMITTED }
var trade_state: int = TradeState.IDLE
var trade_partner_peer: int = -1
var trade_self_offer: Array[Dictionary] = []   # [{ item_id, count }, ...]
var trade_partner_offer: Array[Dictionary] = []
var trade_self_locked: bool = false
var trade_partner_locked: bool = false


func trade_request(to_peer: int) -> bool:
	if trade_state != TradeState.IDLE:
		return false
	trade_partner_peer = to_peer
	trade_state = TradeState.OFFERED
	trade_offered.emit(NetSystem.local_peer_id() if NetSystem else 1, to_peer)
	return true


func trade_accept(_from_peer: int) -> void:
	if trade_state == TradeState.OFFERED:
		trade_state = TradeState.NEGOTIATING
		trade_accepted.emit(_from_peer, NetSystem.local_peer_id() if NetSystem else 1)


func trade_add_self(item_id: StringName, count: int) -> bool:
	# 3.39 — Soulbound items cannot be traded.
	if _is_soulbound(item_id):
		EventBus.ui_toast.emit("That item is soul-bound. It cannot leave you.", 2.0)
		return false
	if Inventory.count_of(item_id) < count:
		return false
	trade_self_offer.append({ "item_id": String(item_id), "count": count })
	return true


func trade_add_partner(item_id: StringName, count: int) -> void:
	trade_partner_offer.append({ "item_id": String(item_id), "count": count })


func trade_lock_self() -> void:
	trade_self_locked = true


func trade_lock_partner() -> void:
	trade_partner_locked = true


func trade_commit() -> bool:
	if trade_state != TradeState.NEGOTIATING:
		return false
	if not trade_self_locked or not trade_partner_locked:
		return false
	# Remove from self, add partner items.
	for offer in trade_self_offer:
		Inventory.try_remove(StringName(String(offer.get("item_id"))), int(offer.get("count", 0)))
	for offer in trade_partner_offer:
		Inventory.try_add(StringName(String(offer.get("item_id"))), int(offer.get("count", 0)))
	trade_state = TradeState.COMMITTED
	trade_completed.emit()
	_reset_trade()
	return true


func trade_cancel() -> void:
	trade_cancelled.emit()
	_reset_trade()


func _reset_trade() -> void:
	trade_state = TradeState.IDLE
	trade_partner_peer = -1
	trade_self_offer.clear()
	trade_partner_offer.clear()
	trade_self_locked = false
	trade_partner_locked = false


# ---------------------------------------------------------------------------
# 3.39 / 9.63 — Soulbound / Resonance-bound items. Items with a soulbound: true
# flag in their ItemDef can't be traded, dropped, or sold.
# ---------------------------------------------------------------------------
func _is_soulbound(item_id: StringName) -> bool:
	if ItemRegistry == null:
		return false
	var def: ItemDef = ItemRegistry.get_def(item_id)
	if def == null:
		return false
	if def.has_meta("soulbound") and bool(def.get_meta("soulbound", false)):
		return true
	# Phase 9.63 — Resonance-bound. Hard-list lookup since Item-Defs predate the
	# field. Pendants + small_fishhook + brindle_pendant + map_fragment + ring_of_resonance.
	const RESONANCE_BOUND: Array[StringName] = [
		&"brindle_pendant", &"small_fishhook", &"map_fragment", &"ring_of_resonance",
		&"cantor_compass", &"cantors_compass",
	]
	return RESONANCE_BOUND.has(item_id)


# ---------------------------------------------------------------------------
# 13.22 — Dropped-item ownership / loot etiquette. When a peer drops an item
# (mob kill, chest open, etc.), the loot is FFA, round-robin, or need/greed.
# In FFA + RR modes there's a 3 s pickup-ownership window for the killer.
# ---------------------------------------------------------------------------
const LOOT_OWNERSHIP_SECONDS: float = 3.0
var loot_ownership_records: Dictionary = {}   # entity_id -> { owner_peer, expires_at_unix }
var _round_robin_cursor: int = 0


func mark_loot_owner(entity_id: int, owner_peer: int) -> void:
	loot_ownership_records[entity_id] = {
		"owner_peer": owner_peer,
		"expires_at_unix": Time.get_unix_time_from_system() + LOOT_OWNERSHIP_SECONDS,
	}


func can_pick_up(entity_id: int, peer_id: int) -> bool:
	var rec: Dictionary = loot_ownership_records.get(entity_id, {})
	if rec.is_empty():
		return true
	if float(rec.get("expires_at_unix", 0.0)) < Time.get_unix_time_from_system():
		loot_ownership_records.erase(entity_id)
		return true
	if int(rec.get("owner_peer", 0)) == peer_id:
		return true
	# Mode-dependent gating.
	if NetSystem == null:
		return true
	match NetSystem.loot_mode:
		NetSystem.LootMode.FFA:
			return true
		NetSystem.LootMode.ROUND_ROBIN:
			return peer_id == int(rec.get("owner_peer", 0))
		NetSystem.LootMode.NEED_GREED:
			return false   # need/greed forces a roll first
		_:
			return true


func round_robin_next_peer() -> int:
	if NetSystem == null or not NetSystem.is_party_active():
		return 1
	var peers: Array = [NetSystem.local_peer_id()]
	for p in multiplayer.get_peers():
		peers.append(p)
	peers.sort()
	var idx: int = _round_robin_cursor % peers.size()
	_round_robin_cursor += 1
	return int(peers[idx])


# ---------------------------------------------------------------------------
# 13.23 / 13.24 / 13.38 — Spectator + revival + respawn countdown.
# ---------------------------------------------------------------------------
const RESPAWN_COUNTDOWN_SECONDS: float = 6.0
const REVIVAL_RANGE_PX: float = 48.0
var awaiting_respawn: Dictionary = {}   # peer_id -> seconds_remaining
var spectator_target_peer: int = -1


func begin_awaiting_respawn(peer_id: int) -> void:
	awaiting_respawn[peer_id] = RESPAWN_COUNTDOWN_SECONDS
	if peer_id == (NetSystem.local_peer_id() if NetSystem else 1):
		spectator_target_peer = _first_live_peer(peer_id)


func tick_respawn_countdowns(delta: float) -> void:
	if awaiting_respawn.is_empty():
		return
	var done: Array[int] = []
	for k in awaiting_respawn.keys():
		var t: float = float(awaiting_respawn[k]) - delta
		awaiting_respawn[k] = t
		if t <= 0.0:
			done.append(int(k))
	for k in done:
		awaiting_respawn.erase(k)


func respawn_seconds_for(peer_id: int) -> float:
	return float(awaiting_respawn.get(peer_id, 0.0))


func is_awaiting_respawn(peer_id: int) -> bool:
	return awaiting_respawn.has(peer_id)


func request_revival(target_peer: int) -> bool:
	var local: int = NetSystem.local_peer_id() if NetSystem else 1
	if local == target_peer:
		return false
	if not is_awaiting_respawn(target_peer):
		return false
	# Range check happens client-side using global_position.
	player_revival_requested.emit(local, target_peer)
	awaiting_respawn[target_peer] = 0.1   # collapse the timer to near-instant
	return true


func _first_live_peer(skip_peer: int) -> int:
	if NetSystem == null:
		return -1
	for k in NetSystem.player_profiles.keys():
		var pid: int = int(k)
		if pid == skip_peer:
			continue
		if not awaiting_respawn.has(pid):
			return pid
	return -1


# ---------------------------------------------------------------------------
# 13.25 — Party UI HP + ping aggregation. The HUD's PartyHUD reads this each frame.
# ---------------------------------------------------------------------------
func party_hud_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if NetSystem == null:
		return out
	for k in NetSystem.player_profiles.keys():
		var pid: int = int(k)
		var prof: Dictionary = NetSystem.profile_for(pid)
		out.append({
			"peer_id": pid,
			"name": String(prof.get("name", "Walker")),
			"color": prof.get("color", Color.WHITE),
			"ping_ms": int(prof.get("ping_ms", 0)),
			"hp_fraction": _peer_hp_fraction(pid),
			"awaiting_respawn": is_awaiting_respawn(pid),
		})
	return out


func _peer_hp_fraction(peer_id: int) -> float:
	# Local player only — remote HP fractions are synced via Phase13Helpers
	# remote_health_table; we expose 1.0 for stubs until snapshots arrive.
	var local: int = NetSystem.local_peer_id() if NetSystem else 1
	if peer_id != local:
		return float(remote_health_table.get(peer_id, 1.0))
	var players := get_tree().get_nodes_in_group("player") if get_tree() else []
	if players.is_empty():
		return 1.0
	var hp := (players[0] as Node).get_node_or_null("HealthComponent")
	if hp == null:
		return 1.0
	return float(hp.current_health) / float(maxi(1, hp.max_health))


var remote_health_table: Dictionary = {}   # peer_id -> 0..1


# ---------------------------------------------------------------------------
# 13.26 — Off-screen tracking arrows. Returns one Vector2 (direction) per
# remote peer that is off-screen.
# ---------------------------------------------------------------------------
func tracking_arrow_targets(camera_center: Vector2, viewport_half: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if NetSystem == null:
		return out
	for k in NetSystem.player_profiles.keys():
		var pid: int = int(k)
		if pid == (NetSystem.local_peer_id() if NetSystem else 1):
			continue
		var pos: Vector2 = remote_positions.get(pid, Vector2.ZERO)
		var d: Vector2 = pos - camera_center
		if absf(d.x) <= viewport_half.x and absf(d.y) <= viewport_half.y:
			continue
		out.append({
			"peer_id": pid,
			"direction": d.normalized(),
			"distance": d.length(),
		})
	return out


var remote_positions: Dictionary = {}    # peer_id -> Vector2


func set_remote_position(peer_id: int, pos: Vector2) -> void:
	remote_positions[peer_id] = pos


# ---------------------------------------------------------------------------
# 13.6 — NPC density bonus. Anchor base feels emptier in multiplayer because
# the per-player threshold is lower. Returns the count of bonus NPCs to allow.
# ---------------------------------------------------------------------------
func bonus_npc_slots() -> int:
	if NetSystem == null:
		return 0
	var n: int = NetSystem.player_count()
	if n <= 1:
		return 0
	# +1 slot per player past the first, capped at +4 (Brindle / Mira / Cantor / Hask + Aelstren = 5 + 4 = 9).
	return mini(n - 1, 4)


# ---------------------------------------------------------------------------
# 13.45 / 13.46 — Gamepad cursor + glyph swap.
# ---------------------------------------------------------------------------
const GAMEPAD_CURSOR_SPEED_PX_PER_SECOND: float = 320.0

var gamepad_cursor_active: bool = false
var gamepad_glyphs: StringName = &"xbox"     # xbox / playstation / switch / generic


func toggle_gamepad_cursor(active: bool) -> void:
	gamepad_cursor_active = active


func set_gamepad_glyphs(glyph_set: StringName) -> void:
	gamepad_glyphs = glyph_set


# 13.46 — Detect controller connect/disconnect and update glyph set.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		gamepad_cursor_active = true
	elif event is InputEventMouseMotion or event is InputEventKey:
		gamepad_cursor_active = false


# ---------------------------------------------------------------------------
# 13.48 — Networked VFX broadcast. The host's WorldGen / boss scripts call
# this; clients receive a `vfx_broadcast` signal and spawn the matching
# scene locally.
# ---------------------------------------------------------------------------
func broadcast_vfx(vfx_id: StringName, world_pos: Vector2, params: Dictionary = {}) -> void:
	vfx_broadcast.emit(vfx_id, world_pos, params)


# ---------------------------------------------------------------------------
# 13.51 / 13.52 — Lobby + ready check.
# ---------------------------------------------------------------------------
var lobby_open: bool = false
var lobby_ready: Dictionary = {}     # peer_id -> bool


func open_lobby() -> void:
	lobby_open = true
	lobby_ready.clear()


func mark_ready(peer_id: int, ready: bool) -> void:
	lobby_ready[peer_id] = ready
	lobby_ready_changed.emit(peer_id, ready)


func all_ready() -> bool:
	if NetSystem == null:
		return true
	for k in NetSystem.player_profiles.keys():
		if not bool(lobby_ready.get(int(k), false)):
			return false
	return true


func finalize_lobby() -> bool:
	if not all_ready():
		return false
	lobby_open = false
	lobby_finalized.emit()
	return true


# ---------------------------------------------------------------------------
# 13.39 / 13.50 — Shared XP toggle. NetSystem owns the bool; SkillSystem
# already checks NetSystem.is_party_active for the share decision.
# ---------------------------------------------------------------------------
func set_shared_xp(enabled: bool) -> void:
	if NetSystem == null:
		return
	NetSystem.shared_xp_enabled = enabled


# ---------------------------------------------------------------------------
# 13.16 — Voice chat PTT. Stubbed; the binding (default `V`) is reserved so
# downstream voice plugins can hook without further input-action churn.
# ---------------------------------------------------------------------------
var voice_ptt_active: bool = false


func voice_ptt_pressed() -> void:
	voice_ptt_active = true


func voice_ptt_released() -> void:
	voice_ptt_active = false


# ---------------------------------------------------------------------------
# 9.55 — Synced lore-tablet reading. Host fires this when any player reads a
# tablet; remote clients receive the entry-unlock toast.
# ---------------------------------------------------------------------------
func broadcast_lore_tablet_read(tablet_id: StringName) -> void:
	if Compendium and Compendium.has_method("unlock"):
		Compendium.unlock(tablet_id)
	EventBus.ui_toast.emit("A tablet rings far away. Someone is reading.", 3.0)


# ---------------------------------------------------------------------------
# 1.23 — Player nameplate. Toggled by Settings; defaults ON in multiplayer.
# ---------------------------------------------------------------------------
var nameplate_visible: bool = true


func set_nameplate_visible(visible_in: bool) -> void:
	nameplate_visible = visible_in
	nameplate_visibility_changed.emit(visible_in)


# ---------------------------------------------------------------------------
# Lifecycle. Tied to AudioBus.aphelion_beat for periodic prune work.
# ---------------------------------------------------------------------------
func _ready() -> void:
	set_process(true)
	set_process_input(true)
	if AudioBus and AudioBus.has_signal("aphelion_beat"):
		if not AudioBus.aphelion_beat.is_connected(_on_beat):
			AudioBus.aphelion_beat.connect(_on_beat)


func _on_beat() -> void:
	prune_expired_pings()


func _process(delta: float) -> void:
	tick_respawn_countdowns(delta)
	compute_resonance_proximity()


# ---------------------------------------------------------------------------
# Persistence — SaveSystem v11 reads/writes these.
# ---------------------------------------------------------------------------
func dump_state() -> Dictionary:
	return {
		"chat_history": chat_history.duplicate(),
		"typed_history": typed_history.duplicate(),
		"nameplate_visible": nameplate_visible,
		"gamepad_glyphs": String(gamepad_glyphs),
	}


func restore_state(d: Dictionary) -> void:
	chat_history = []
	var raw_chat: Array = d.get("chat_history", [])
	for entry in raw_chat:
		if typeof(entry) == TYPE_DICTIONARY:
			chat_history.append(entry)
	typed_history = []
	for s in d.get("typed_history", []):
		typed_history.append(String(s))
	nameplate_visible = bool(d.get("nameplate_visible", true))
	gamepad_glyphs = StringName(String(d.get("gamepad_glyphs", "xbox")))
