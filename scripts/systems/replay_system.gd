extends Node

## Phase 15 — Replay / record system.
## Ticket 15.91 — Gameplay record / replay system (for bug reports).
##
## Records compact input + position frames at a fixed sample rate. Replay is
## deterministic-ish; in practice it's used by QA to attach reproductions to
## bug reports rather than as a feature visible to the player.

const SAMPLE_HZ: float = 10.0
const RECORDING_DIR: String = "user://replays/"
const MAX_FRAMES: int = 30 * 60 * int(SAMPLE_HZ)   # 30 minutes max

signal recording_started()
signal recording_stopped(frame_count: int, path: String)
signal playback_started(path: String)
signal playback_stopped()

var recording: bool = false
var playing_back: bool = false
var frames: Array[Dictionary] = []
var _frame_accum: float = 0.0
var _playback_index: int = 0
var current_path: String = ""


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(RECORDING_DIR)
	set_process(true)


func _process(delta: float) -> void:
	if recording:
		_frame_accum += delta
		var period: float = 1.0 / SAMPLE_HZ
		if _frame_accum >= period:
			_frame_accum -= period
			_sample_frame()
			if frames.size() > MAX_FRAMES:
				# Rolling buffer.
				frames.pop_front()


func _sample_frame() -> void:
	var frame: Dictionary = {
		"t_ms": Time.get_ticks_msec(),
		"keys": {},
		"mouse_pos": [0, 0],
	}
	# Sample the four canonical actions + dodge / interact.
	for action in ["move_up", "move_down", "move_left", "move_right", "attack_primary", "dodge", "interact"]:
		frame["keys"][action] = Input.is_action_pressed(action)
	var mouse_pos: Vector2 = get_viewport().get_mouse_position() if get_viewport() else Vector2.ZERO
	frame["mouse_pos"] = [int(mouse_pos.x), int(mouse_pos.y)]
	# Sample player position if available.
	if get_tree() and not get_tree().get_nodes_in_group("player").is_empty():
		var p := get_tree().get_nodes_in_group("player")[0] as Node2D
		frame["player_pos"] = [int(p.global_position.x), int(p.global_position.y)]
	frames.append(frame)


# ---------- Recording ----------

func start_recording() -> void:
	frames.clear()
	recording = true
	playing_back = false
	recording_started.emit()


func stop_recording() -> String:
	recording = false
	if frames.is_empty():
		return ""
	var ts: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path: String = RECORDING_DIR + "replay_%s.json" % ts
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify({
		"world_seed": GameState.world_seed,
		"frames": frames,
		"sample_hz": SAMPLE_HZ,
		"build_version": GameState.VERSION,
	}, "\t"))
	file.close()
	current_path = path
	recording_stopped.emit(frames.size(), path)
	return path


# ---------- Playback ----------

func load_replay(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return false
	var data: Dictionary = json.data
	if not (data is Dictionary) or not data.has("frames"):
		return false
	frames.clear()
	for fr in data["frames"]:
		frames.append(fr)
	current_path = path
	_playback_index = 0
	playing_back = true
	playback_started.emit(path)
	return true


func stop_playback() -> void:
	playing_back = false
	playback_stopped.emit()


func current_playback_frame() -> Dictionary:
	if _playback_index < 0 or _playback_index >= frames.size():
		return {}
	return frames[_playback_index]


func advance_playback() -> bool:
	if not playing_back:
		return false
	_playback_index += 1
	if _playback_index >= frames.size():
		stop_playback()
		return false
	return true
