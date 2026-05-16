extends Node

## Phase 15 — Network polish layer.
## Tickets:
##   15.65 — Network bandwidth meter (debug toggle)
##   15.66 — Disconnect / reconnect grace handling
##   15.67 — Friend list integration UI backend
##   15.69 — World seed sharing button (clipboard + Steam rich-presence stub)

const GRACE_SECONDS_DEFAULT: int = 30
const SAMPLE_WINDOW_SECONDS: float = 1.0

signal bandwidth_sampled(bytes_in: int, bytes_out: int, packets_in: int, packets_out: int)
signal peer_grace_started(peer_id: int, deadline_unix: int)
signal peer_grace_expired(peer_id: int)
signal peer_grace_resolved(peer_id: int)
signal friend_status_changed(friend_id: String, online: bool)
signal world_seed_copied(seed_value: int)

var grace_seconds: int = GRACE_SECONDS_DEFAULT
var bandwidth_meter_visible: bool = false
var _grace_deadlines: Dictionary = {}   # peer_id -> deadline_unix
var _bandwidth_sample_accum: float = 0.0
var _bytes_in_accum: int = 0
var _bytes_out_accum: int = 0
var _packets_in_accum: int = 0
var _packets_out_accum: int = 0

# Local stub friend list — populated by FriendListPanel from Steam/EOS bridge.
var friends: Dictionary = {}   # friend_id -> { name, online, on_world }


func _ready() -> void:
	if NetSystem and NetSystem.has_signal("peer_left"):
		NetSystem.connect("peer_left", _on_peer_left)
	set_process(true)


func _process(delta: float) -> void:
	# Bandwidth sampler (15.65)
	_bandwidth_sample_accum += delta
	if _bandwidth_sample_accum >= SAMPLE_WINDOW_SECONDS:
		_bandwidth_sample_accum = 0.0
		bandwidth_sampled.emit(_bytes_in_accum, _bytes_out_accum, _packets_in_accum, _packets_out_accum)
		EventBus.phase15_bandwidth_sampled.emit(_bytes_in_accum * 8, _bytes_out_accum * 8)
		_bytes_in_accum = 0
		_bytes_out_accum = 0
		_packets_in_accum = 0
		_packets_out_accum = 0
	# Grace expiry tick.
	var now_unix: int = Time.get_unix_time_from_system()
	for peer_id in _grace_deadlines.keys():
		var deadline: int = int(_grace_deadlines[peer_id])
		if now_unix >= deadline:
			peer_grace_expired.emit(peer_id)
			_grace_deadlines.erase(peer_id)


# ---------- Bandwidth meter (15.65) ----------

func record_bytes(direction: StringName, bytes: int, packets: int = 1) -> void:
	if direction == &"in":
		_bytes_in_accum += bytes
		_packets_in_accum += packets
	elif direction == &"out":
		_bytes_out_accum += bytes
		_packets_out_accum += packets


func toggle_bandwidth_meter() -> bool:
	bandwidth_meter_visible = not bandwidth_meter_visible
	return bandwidth_meter_visible


# ---------- Disconnect / reconnect grace (15.66) ----------

func _on_peer_left(peer_id: int) -> void:
	# In a real disconnect, NetSystem fires this. We track a grace window so
	# the peer can reconnect without losing items / position.
	begin_grace(peer_id, grace_seconds)


func begin_grace(peer_id: int, seconds: int = -1) -> void:
	var s: int = seconds if seconds > 0 else grace_seconds
	var deadline: int = Time.get_unix_time_from_system() + s
	_grace_deadlines[peer_id] = deadline
	peer_grace_started.emit(peer_id, deadline)


func resolve_grace(peer_id: int) -> bool:
	if not _grace_deadlines.has(peer_id):
		return false
	_grace_deadlines.erase(peer_id)
	peer_grace_resolved.emit(peer_id)
	return true


func peer_in_grace(peer_id: int) -> bool:
	return _grace_deadlines.has(peer_id)


# ---------- Friend list (15.67) ----------

func register_friend(friend_id: String, name: String, online: bool, on_world: String = "") -> void:
	friends[friend_id] = {"name": name, "online": online, "on_world": on_world}
	friend_status_changed.emit(friend_id, online)
	EventBus.phase15_friend_status_changed.emit(friend_id, online)


func update_friend_online(friend_id: String, online: bool) -> void:
	if not friends.has(friend_id):
		return
	friends[friend_id]["online"] = online
	friend_status_changed.emit(friend_id, online)
	EventBus.phase15_friend_status_changed.emit(friend_id, online)


func friend_count_online() -> int:
	var n: int = 0
	for fid in friends.keys():
		if bool(friends[fid].get("online", false)):
			n += 1
	return n


# ---------- World seed share (15.69) ----------

func copy_world_seed_to_clipboard() -> int:
	var seed_v: int = GameState.world_seed
	DisplayServer.clipboard_set(str(seed_v))
	world_seed_copied.emit(seed_v)
	return seed_v


func format_seed_share_text(seed_v: int) -> String:
	return "The Sleeping Vein — Seed: %d" % seed_v
