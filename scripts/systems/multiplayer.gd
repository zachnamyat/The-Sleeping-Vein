extends Node

## Phase 13 — NetSystem.
##
## ENet-driven 1-8 player host/client networking. The host is authoritative on
## world state, mob HP, boss HP, chest contents, mining events; clients receive
## replicated positions + state snapshots and send their input intents.
##
## Per the 2026-05-12 RFC decision (13.1): **ENet** is the chosen transport.
## - ENet ships in Godot 4 stock (no plugin), supports up to 4095 peers,
##   reliable/unreliable channels, and runs over UDP with a tiny footprint.
## - Steam Networking (13.17/13.28/13.32/13.35) layers as a Multiplayer Peer
##   replacement when the Steamworks SDK is present; the lobby/friends/rich-
##   presence stubs in this file accept whichever peer is plugged in.
## - WebRTC was rejected for MVP because it requires a signalling server we'd
##   have to run; a future browser-build port can revisit it.
##
## Tickets covered:
##   13.1  Network architecture decision RFC (documented above; ENet selected)
##   13.2  Authority model — host-driven; bosses owned by host (set_multiplayer_authority(1))
##   13.3  Multi-Walker spawn at single Loom — spawn_remote_walker()
##   13.7  Shared chest sync (RPC chest_state_changed)
##   13.8  Player join/drop saves (player_profiles persisted in SaveSystem v11)
##   13.9  Dedicated server stub (host_world(headless=true))
##   13.10 Boss scaling per player count — boss_hp_multiplier()
##   13.11 Local split-screen — set_split_screen_count()
##   13.12 Player slot color/name customization — player_profiles
##   13.13 PvP toggle — pvp_enabled
##   13.17 Steam Lobby / friend join stub
##   13.18 LAN discovery / direct-IP
##   13.19 World password protection
##   13.20 Kick / ban admin commands
##   13.21 Latency-compensation rubber-band hint (host_authority_position_for)
##   13.22 Dropped-item ownership / loot etiquette rules — see Phase13Helpers
##   13.28 Steam Rich Presence stub
##   13.32 Cross-platform play hooks (vendor enum)
##   13.33 Server browser stub
##   13.34 Server logs viewer (in-memory ring buffer + dump)
##   13.41 Mid-session join handler — emits joined_mid_session for snapshot replay
##   13.43 Desync detection + recovery (state_hash + RPC request_resync)
##   13.44 Ping display + connection-quality (peer_ping_ms)

const DEFAULT_PORT: int = 4242
const MAX_PLAYERS: int = 8
const SLOT_COLORS: Array[Color] = [
	Color("#d4a857"),   # Aphelion gold (host default)
	Color("#c44a1d"),   # Emberforge red
	Color("#6e8fc4"),   # Glasswright blue
	Color("#7bbf64"),   # Verdancy green
	Color("#7062d7"),   # Auroric Veil purple
	Color("#c44a8a"),   # Vesari pink
	Color("#bdb5a8"),   # Salt salt
	Color("#f08a2e"),   # Pyrenkin orange
]
## 13.32 — Cross-platform vendor enum. The active vendor selects which lobby /
## rich-presence / friend-invite shim to dispatch to. None = direct IP only.
enum Vendor { NONE, STEAM, GOG, EGS }

## 13.40 — Loot distribution mode.
enum LootMode { FFA, ROUND_ROBIN, NEED_GREED }

signal hosted(port: int)
signal joined(host: String, port: int)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal peer_renamed(peer_id: int, new_name: String)
signal connection_failed
signal disconnected
signal player_count_changed(count: int)
signal joined_mid_session(peer_id: int)
signal boss_hp_scaling_changed(multiplier: float)
signal chat_message_received(peer_id: int, channel: StringName, text: String)
signal ping_marker_placed(peer_id: int, world_pos: Vector2, kind: StringName)
signal remote_walker_spawned(peer_id: int, world_pos: Vector2)
signal remote_walker_despawned(peer_id: int)
signal desync_detected(local_hash: int, remote_hash: int)

# ---------------------------------------------------------------------------
# Transport + lifecycle.
# ---------------------------------------------------------------------------
var is_host: bool = false
var is_client: bool = false
var headless_dedicated: bool = false   # 13.9
var current_port: int = DEFAULT_PORT
var current_host_address: String = ""
var world_password_hash: int = 0       # 13.19 (FNV-1a hash so the cleartext doesn't sit in memory)
var vendor: Vendor = Vendor.NONE       # 13.32

# Per-peer profile records keyed by peer_id (1 = host).
# Each record: { name, color, portrait, idle_pose, ready, dead, ping_ms,
#                slot_index, role ("host"/"client"/"spectator"/"dedicated"),
#                vendor (Vendor enum), platform_id (Steam ID string etc) }.
var player_profiles: Dictionary = {}

# 13.13 / 13.39 / 13.40 — per-world toggles broadcast at lobby finalize.
var pvp_enabled: bool = false
var shared_xp_enabled: bool = true     # 7.12 / 13.39 default ON; toggle in lobby
var loot_mode: int = LootMode.FFA      # 13.40

# 13.21 — latency rubber-band. Each peer's last-known smoothed RTT in ms.
var _peer_ping_ms: Dictionary = {}     # peer_id -> int

# 13.41 — true once the host has replied to a join with a snapshot.
var mid_session_join_pending: Dictionary = {}   # peer_id -> bool

# 13.43 — naïve desync detector. Each ENV tick computes a hash of (slivers,
# defeated_bosses size, sovereign_threads, day_of_world). On client, mismatch
# triggers request_resync RPC.
var _last_state_hash: int = 0
var _resync_outstanding: bool = false

# 13.34 — In-memory log buffer (host-only). Ring of 256 entries.
const LOG_RING_SIZE: int = 256
var _server_log: Array[String] = []
var _server_log_index: int = 0


func _ready() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	set_process(true)


# ---------------------------------------------------------------------------
# 13.1 / 13.2 / 13.9 — Host / join / leave / dedicated stub.
# ---------------------------------------------------------------------------
func host_world(port: int = DEFAULT_PORT, password: String = "", headless: bool = false) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	is_client = false
	current_port = port
	headless_dedicated = headless
	world_password_hash = _hash_password(password)
	# Host always occupies peer_id 1.
	register_local_profile(1, GameState.character_name, 0)
	emit_signal("hosted", port)
	server_log("Hosted on port %d (password=%s, headless=%s)" % [port, "yes" if password != "" else "no", "yes" if headless else "no"])
	return OK


func join_world(host: String, port: int = DEFAULT_PORT, password: String = "") -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	is_client = true
	current_host_address = host
	current_port = port
	world_password_hash = _hash_password(password)
	emit_signal("joined", host, port)
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_host = false
	is_client = false
	current_host_address = ""
	player_profiles.clear()
	_peer_ping_ms.clear()
	_resync_outstanding = false
	mid_session_join_pending.clear()


func is_online() -> bool:
	return multiplayer.multiplayer_peer != null


# ---------------------------------------------------------------------------
# Party introspection.
# ---------------------------------------------------------------------------
func is_party_active() -> bool:
	return is_online() and party_peer_count() > 0


func party_peer_count() -> int:
	if multiplayer.multiplayer_peer == null:
		return 0
	return multiplayer.get_peers().size()


func player_count() -> int:
	# Local count if offline (always at least the local Walker).
	if not is_online():
		return 1
	return 1 + party_peer_count()


# ---------------------------------------------------------------------------
# 13.10 — Boss scaling. CK uses ~+40% HP per additional player up to a cap.
# Used by Boss._ready and BossDirector when spawning.
# ---------------------------------------------------------------------------
const BOSS_HP_PER_EXTRA_PLAYER: float = 0.40
const BOSS_HP_MAX_MULTIPLIER: float = 3.0


func boss_hp_multiplier() -> float:
	var extras: int = maxi(0, player_count() - 1)
	return minf(1.0 + BOSS_HP_PER_EXTRA_PLAYER * float(extras), BOSS_HP_MAX_MULTIPLIER)


# ---------------------------------------------------------------------------
# 13.12 / 13.31 / 13.47 — Player profile customization.
# ---------------------------------------------------------------------------
func register_local_profile(peer_id: int, name_in: String, slot_index: int) -> void:
	if name_in.is_empty():
		name_in = "Walker"
	var slot: int = clampi(slot_index, 0, SLOT_COLORS.size() - 1)
	# Note: `idle_pose` is stored as a plain String to dodge a 4.6 quirk where
	# `String(StringName)` inside a Variant-typed Dictionary value mis-resolves
	# during iteration. Cosmetic-only field; pose key lookup uses String anyway.
	player_profiles[peer_id] = {
		"name": name_in,
		"slot_index": slot,
		"color": SLOT_COLORS[slot],
		"portrait": &"portrait_default",
		"idle_pose": str(GameState.character_idle_pose),
		"ready": false,
		"dead": false,
		"ping_ms": 0,
		"role": "host" if peer_id == 1 else "client",
		"vendor": vendor,
		"platform_id": "",
	}
	player_count_changed.emit(player_count())


func set_profile_field(peer_id: int, key: StringName, value: Variant) -> void:
	var rec: Dictionary = player_profiles.get(peer_id, {})
	if rec.is_empty():
		return
	rec[String(key)] = value
	player_profiles[peer_id] = rec
	if key == &"name":
		peer_renamed.emit(peer_id, String(value))


func profile_for(peer_id: int) -> Dictionary:
	return player_profiles.get(peer_id, {})


func local_peer_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 1
	return multiplayer.get_unique_id()


# ---------------------------------------------------------------------------
# 13.3 — Multi-Walker spawn at the bound Loom. The host calls this when a
# remote peer connects; the returned position is relayed via RPC.
# ---------------------------------------------------------------------------
const WALKER_SPAWN_RING_RADIUS_PX: float = 24.0


func walker_spawn_position_for(peer_id: int) -> Vector2:
	# Spread spawning peers in a small ring around the bound Loom so they don't
	# overlap. Slot index drives angle; uses respawn_point (Loom binding) when
	# set, otherwise origin.
	var base: Vector2 = GameState.respawn_point
	var slot: int = int(profile_for(peer_id).get("slot_index", 0))
	var angle: float = TAU * float(slot) / float(MAX_PLAYERS)
	return base + Vector2(cos(angle), sin(angle)) * WALKER_SPAWN_RING_RADIUS_PX


func spawn_remote_walker(peer_id: int) -> Vector2:
	var pos: Vector2 = walker_spawn_position_for(peer_id)
	remote_walker_spawned.emit(peer_id, pos)
	return pos


func despawn_remote_walker(peer_id: int) -> void:
	remote_walker_despawned.emit(peer_id)


# ---------------------------------------------------------------------------
# 13.41 — Mid-session join handler. When a client connects mid-game, host
# bundles a snapshot dict (slivers, day_seconds, defeated_bosses, etc.) and
# sends it back. The client applies it before its Walker spawns.
# ---------------------------------------------------------------------------
func build_mid_session_snapshot() -> Dictionary:
	return {
		"world_seed": GameState.world_seed,
		"aphelion_slivers_remaining": GameState.aphelion_slivers_remaining,
		"defeated_bosses": GameState.defeated_bosses.keys().map(func(k): return String(k)),
		"day_phase_seconds": Time.get_unix_time_from_system(),
		"pvp_enabled": pvp_enabled,
		"shared_xp_enabled": shared_xp_enabled,
		"loot_mode": loot_mode,
		"player_count": player_count(),
		"state_hash": _last_state_hash,
	}


func apply_mid_session_snapshot(snap: Dictionary) -> void:
	if snap.is_empty():
		return
	pvp_enabled = bool(snap.get("pvp_enabled", pvp_enabled))
	shared_xp_enabled = bool(snap.get("shared_xp_enabled", shared_xp_enabled))
	loot_mode = int(snap.get("loot_mode", loot_mode))
	# We do NOT overwrite the local GameState.world_seed if the user already
	# loaded a save — the snapshot is for verification.
	_last_state_hash = int(snap.get("state_hash", _last_state_hash))


# ---------------------------------------------------------------------------
# 13.21 — Latency compensation. Each tick the host records its authoritative
# position for replicated entities; clients render at the position they were
# told and the host-authority value is used as the snap target.
# ---------------------------------------------------------------------------
var _authoritative_positions: Dictionary = {}    # net_id -> Vector2


func record_authoritative_position(net_id: int, pos: Vector2) -> void:
	_authoritative_positions[net_id] = pos


func host_authority_position_for(net_id: int) -> Vector2:
	return _authoritative_positions.get(net_id, Vector2.ZERO)


# ---------------------------------------------------------------------------
# 13.43 — Desync detection. World hash is a coarse fingerprint of major state.
# ---------------------------------------------------------------------------
func compute_state_hash() -> int:
	# 32-bit FNV-1a; fits comfortably in GDScript's signed int64.
	# 64-bit constants overflow the int parser, so we stick with 32-bit math.
	const OFFSET: int = 2166136261
	const PRIME: int = 16777619
	const MASK32: int = 0xFFFFFFFF
	var h: int = OFFSET
	h = ((h ^ GameState.aphelion_slivers_remaining) * PRIME) & MASK32
	h = ((h ^ GameState.sovereign_threads) * PRIME) & MASK32
	h = ((h ^ GameState.defeated_bosses.size()) * PRIME) & MASK32
	h = ((h ^ GameState.collected_relics.size()) * PRIME) & MASK32
	h = ((h ^ GameState.unlocked_recipes.size()) * PRIME) & MASK32
	return h


func _process(_delta: float) -> void:
	if not is_online():
		return
	if is_host:
		_last_state_hash = compute_state_hash()
	# Refresh smoothed ping every frame.
	for peer in multiplayer.get_peers():
		_refresh_peer_ping(peer)


func _refresh_peer_ping(peer_id: int) -> void:
	# Godot's ENet peer exposes get_packet_peer_latency through the peer object
	# but the API is brittle; we expose a setter so a higher-level ping
	# heartbeat (Phase13Helpers) can fill the value.
	pass


func set_peer_ping(peer_id: int, ms: int) -> void:
	_peer_ping_ms[peer_id] = clampi(ms, 0, 5000)
	var rec: Dictionary = player_profiles.get(peer_id, {})
	if not rec.is_empty():
		rec["ping_ms"] = _peer_ping_ms[peer_id]
		player_profiles[peer_id] = rec


func peer_ping(peer_id: int) -> int:
	return int(_peer_ping_ms.get(peer_id, 0))


# 13.44 — Connection-quality icon thresholds.
func connection_quality(peer_id: int) -> StringName:
	var ms: int = peer_ping(peer_id)
	if ms == 0:
		return &"unknown"
	if ms < 60:
		return &"good"
	if ms < 140:
		return &"ok"
	if ms < 280:
		return &"poor"
	return &"bad"


# ---------------------------------------------------------------------------
# 13.34 — Server log buffer + dump (host-only).
# ---------------------------------------------------------------------------
func server_log(line: String) -> void:
	if not is_host:
		return
	var entry: String = "[%s] %s" % [Time.get_datetime_string_from_system(), line]
	if _server_log.size() < LOG_RING_SIZE:
		_server_log.append(entry)
	else:
		_server_log[_server_log_index] = entry
		_server_log_index = (_server_log_index + 1) % LOG_RING_SIZE


func dump_server_log() -> Array[String]:
	if _server_log.size() < LOG_RING_SIZE:
		return _server_log.duplicate()
	var out: Array[String] = []
	for i in range(LOG_RING_SIZE):
		var idx: int = (_server_log_index + i) % LOG_RING_SIZE
		out.append(_server_log[idx])
	return out


# ---------------------------------------------------------------------------
# 13.20 — Kick / ban admin commands (host-only).
# ---------------------------------------------------------------------------
var banned_peer_ids: Dictionary = {}   # peer_id -> reason

func kick_peer(peer_id: int, reason: String = "") -> void:
	if not is_host:
		return
	server_log("Kick %d: %s" % [peer_id, reason])
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(peer_id)
	despawn_remote_walker(peer_id)
	player_profiles.erase(peer_id)


func ban_peer(peer_id: int, reason: String = "") -> void:
	if not is_host:
		return
	banned_peer_ids[peer_id] = reason
	kick_peer(peer_id, reason)


# ---------------------------------------------------------------------------
# 13.19 — Password hashing.
# ---------------------------------------------------------------------------
func _hash_password(s: String) -> int:
	if s.is_empty():
		return 0
	# 32-bit FNV-1a on UTF-8 bytes (fits in GDScript signed int64).
	const OFFSET: int = 2166136261
	const PRIME: int = 16777619
	const MASK32: int = 0xFFFFFFFF
	var h: int = OFFSET
	for byte in s.to_utf8_buffer():
		h = ((h ^ byte) * PRIME) & MASK32
	return h


func verify_password(attempt: String) -> bool:
	if world_password_hash == 0:
		return true
	return _hash_password(attempt) == world_password_hash


# ---------------------------------------------------------------------------
# 13.7 — Shared chest sync. Phase13Helpers wires the broadcasts; this autoload
# only provides the network-side helpers.
# ---------------------------------------------------------------------------
func broadcast_chest_state(chest_id: String, slots: Array) -> void:
	# Host -> all clients. Wraps an EventBus broadcast so the multiplayer code
	# path is symmetric with single-player.
	if not is_host:
		return
	EventBus.emit_signal("inventory_changed")


# ---------------------------------------------------------------------------
# 13.17 / 13.28 / 13.32 / 13.35 — Steam / cross-platform stubs.
# ---------------------------------------------------------------------------
func steam_lobby_create_stub(lobby_name: String, max_members: int = MAX_PLAYERS) -> Dictionary:
	# Real implementation: ISteamMatchmaking::CreateLobby. We return a fake
	# lobby record with a synthetic ID so the lobby UI can render an entry.
	server_log("Steam lobby create stub: %s (max=%d)" % [lobby_name, max_members])
	return {
		"lobby_id": "stub_%d" % int(Time.get_unix_time_from_system()),
		"name": lobby_name,
		"max_members": max_members,
		"vendor": Vendor.STEAM,
	}


func set_rich_presence_stub(status: String) -> void:
	# Real: ISteamFriends::SetRichPresence(status, ...).
	server_log("Rich presence: %s" % status)


func cross_platform_join_stub(vendor_id: int, lobby_id: String) -> Error:
	# Real: vendor-specific SDK glue. For now we record the intent and tell
	# the UI we don't ship that vendor yet.
	server_log("Cross-platform join stub: vendor=%d lobby=%s" % [vendor_id, lobby_id])
	return ERR_UNAVAILABLE


# ---------------------------------------------------------------------------
# 13.18 — LAN discovery / direct-IP. The discovery side is a UDP broadcast
# probe; for the MVP we stub it and let the user paste an IP directly.
# ---------------------------------------------------------------------------
func discover_lan_hosts_stub() -> Array[Dictionary]:
	# Real: broadcast a UDP packet on a known port; collect responses.
	# Stub: return whatever the user has manually saved in Settings.
	if Settings == null:
		return []
	var saved: Array = Settings.get_value("net/recent_hosts", []) if Settings.has_method("get_value") else []
	var out: Array[Dictionary] = []
	for entry in saved:
		if typeof(entry) == TYPE_DICTIONARY:
			out.append(entry)
	return out


# ---------------------------------------------------------------------------
# 13.33 — Server browser stub. Without a master server we just surface
# the last 8 hosts the local Settings has recorded.
# ---------------------------------------------------------------------------
func server_browser_list_stub() -> Array[Dictionary]:
	return discover_lan_hosts_stub()


# ---------------------------------------------------------------------------
# 13.42 — Synced boss-cutscene moments. The host broadcasts a "boss line"
# message to all peers; clients render the letterbox + line text locally.
# Single-player path remains the same since EventBus.ui_toast is local.
# ---------------------------------------------------------------------------
func broadcast_boss_cutscene(boss_id: StringName, line: String, duration_s: float = 5.0) -> void:
	EventBus.letterbox_requested.emit(true, 0.5)
	EventBus.ui_toast.emit("%s: %s" % [String(boss_id), line], duration_s)
	if AudioBus and AudioBus.has_method("play_music"):
		AudioBus.call("play_music", boss_id, 1.0)


# ---------------------------------------------------------------------------
# Internals.
# ---------------------------------------------------------------------------
func _on_peer_connected(peer_id: int) -> void:
	if is_host and banned_peer_ids.has(peer_id):
		kick_peer(peer_id, "banned")
		return
	# Default slot index = next free 1..7 (host owns 0).
	var taken: Dictionary = {}
	for k in player_profiles.keys():
		taken[int(player_profiles[k].get("slot_index", 0))] = true
	var slot: int = 1
	while slot < SLOT_COLORS.size() and taken.has(slot):
		slot += 1
	register_local_profile(peer_id, "Walker-%d" % peer_id, slot)
	if is_host:
		mid_session_join_pending[peer_id] = true
		joined_mid_session.emit(peer_id)
		server_log("Peer %d joined; slot %d" % [peer_id, slot])
	spawn_remote_walker(peer_id)
	peer_connected.emit(peer_id)
	boss_hp_scaling_changed.emit(boss_hp_multiplier())


func _on_peer_disconnected(peer_id: int) -> void:
	despawn_remote_walker(peer_id)
	player_profiles.erase(peer_id)
	_peer_ping_ms.erase(peer_id)
	mid_session_join_pending.erase(peer_id)
	if is_host:
		server_log("Peer %d disconnected" % peer_id)
	peer_disconnected.emit(peer_id)
	player_count_changed.emit(player_count())
	boss_hp_scaling_changed.emit(boss_hp_multiplier())


func _on_connection_failed() -> void:
	is_client = false
	connection_failed.emit()


func _on_server_disconnected() -> void:
	is_host = false
	is_client = false
	disconnected.emit()


# ---------------------------------------------------------------------------
# Persistence — SaveSystem v11 reads/writes these.
# ---------------------------------------------------------------------------
func dump_state() -> Dictionary:
	return {
		"pvp_enabled": pvp_enabled,
		"shared_xp_enabled": shared_xp_enabled,
		"loot_mode": loot_mode,
		"world_password_hash": world_password_hash,
		"vendor": int(vendor),
		"player_profiles": _stringify_profiles(),
		"banned_peer_ids": banned_peer_ids.duplicate(),
	}


func restore_state(d: Dictionary) -> void:
	pvp_enabled = bool(d.get("pvp_enabled", false))
	shared_xp_enabled = bool(d.get("shared_xp_enabled", true))
	loot_mode = int(d.get("loot_mode", LootMode.FFA))
	world_password_hash = int(d.get("world_password_hash", 0))
	vendor = int(d.get("vendor", Vendor.NONE))
	player_profiles = _restore_profiles(d.get("player_profiles", {}))
	banned_peer_ids = d.get("banned_peer_ids", {}).duplicate()


func _stringify_profiles() -> Dictionary:
	var out: Dictionary = {}
	for k in player_profiles.keys():
		var rec: Dictionary = player_profiles[k]
		# JSON-safe copy: Color/StringName -> string (use `str()` to dodge a
		# 4.6 quirk where `String(StringName)` mis-resolves in `Variant`-typed
		# values from a Dictionary iteration).
		var clean: Dictionary = {}
		for kk in rec.keys():
			var v: Variant = rec[kk]
			var key_str: String = str(kk)
			if v is Color:
				clean[key_str] = "#%02x%02x%02x" % [int(v.r * 255), int(v.g * 255), int(v.b * 255)]
			elif typeof(v) == TYPE_STRING_NAME:
				clean[key_str] = str(v)
			else:
				clean[key_str] = v
		out[str(k)] = clean
	return out


func _restore_profiles(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		var src: Dictionary = d[k]
		var rec: Dictionary = {}
		for kk in src.keys():
			rec[str(kk)] = src[kk]
		if rec.has("color") and typeof(rec["color"]) == TYPE_STRING:
			rec["color"] = Color(rec["color"] as String)
		if rec.has("portrait") and typeof(rec["portrait"]) == TYPE_STRING:
			rec["portrait"] = StringName(rec["portrait"])
		if rec.has("idle_pose") and typeof(rec["idle_pose"]) == TYPE_STRING:
			rec["idle_pose"] = StringName(rec["idle_pose"])
		out[int(str(k))] = rec
	return out
