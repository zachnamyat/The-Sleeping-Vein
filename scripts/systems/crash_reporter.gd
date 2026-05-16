extends Node

## Phase 15 — Crash reporter + bug-report + telemetry endpoint.
## Tickets:
##   15.21 — Crash reporter / error log uploader (opt-in)
##   15.82 — Crash report telemetry endpoint (opt-in)
##   15.83 — Bug-report in-game form (description + screenshot)

const CRASH_DIR: String = "user://crash_reports/"
const BUG_DIR: String = "user://bug_reports/"
const TELEMETRY_BATCH_SIZE: int = 8

signal report_saved(path: String, kind: StringName)
signal telemetry_flushed(count: int)
signal opt_in_changed(active: bool)

var telemetry_opt_in: bool = false
var endpoint_url: String = ""   # blank → save locally only
var _pending_events: Array[Dictionary] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CRASH_DIR)
	DirAccess.make_dir_recursive_absolute(BUG_DIR)
	if Settings:
		telemetry_opt_in = bool(Settings.get_value("telemetry.opt_in", false))
		endpoint_url = String(Settings.get_value("telemetry.endpoint_url", ""))


func set_opt_in(active: bool) -> void:
	telemetry_opt_in = active
	if Settings:
		Settings.set_value("telemetry.opt_in", active)
	opt_in_changed.emit(active)


# ---------- Crash reports (15.21) ----------

func record_crash(stacktrace: String, error_message: String = "") -> String:
	var rec: Dictionary = {
		"kind": "crash",
		"timestamp_unix": Time.get_unix_time_from_system(),
		"engine_version": Engine.get_version_info(),
		"os": OS.get_name(),
		"build_version": GameState.VERSION,
		"world_seed": GameState.world_seed,
		"error_message": error_message,
		"stacktrace": stacktrace,
	}
	var ts: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path: String = CRASH_DIR + "crash_%s.json" % ts
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(rec, "\t"))
		file.close()
	report_saved.emit(path, &"crash")
	if telemetry_opt_in:
		_queue_telemetry(rec)
	return path


# ---------- Bug reports (15.83) ----------

func file_bug_report(description: String, with_screenshot: bool = true) -> String:
	var rec: Dictionary = {
		"kind": "bug",
		"timestamp_unix": Time.get_unix_time_from_system(),
		"build_version": GameState.VERSION,
		"world_seed": GameState.world_seed,
		"description": description,
	}
	if with_screenshot:
		var img: Image
		var vp := get_viewport()
		if vp:
			img = vp.get_texture().get_image()
		if img:
			var ts: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
			var img_path: String = BUG_DIR + "bug_%s.png" % ts
			img.save_png(img_path)
			rec["screenshot_path"] = img_path
	var json_path: String = BUG_DIR + "bug_%s.json" % Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(rec, "\t"))
		file.close()
	report_saved.emit(json_path, &"bug")
	if telemetry_opt_in:
		_queue_telemetry(rec)
	return json_path


# ---------- Telemetry (15.82) ----------

func _queue_telemetry(rec: Dictionary) -> void:
	if not telemetry_opt_in:
		return
	_pending_events.append(rec)
	if _pending_events.size() >= TELEMETRY_BATCH_SIZE:
		flush_telemetry()


func flush_telemetry() -> int:
	# Endpoint is left blank in the public build — we just write to a local
	# rollup file. A real wire-up would POST to the URL.
	if _pending_events.is_empty():
		return 0
	var rollup_path: String = "user://telemetry_rollup.json"
	var existing: Array = []
	if FileAccess.file_exists(rollup_path):
		var file := FileAccess.open(rollup_path, FileAccess.READ)
		if file != null:
			var text := file.get_as_text()
			file.close()
			var json := JSON.new()
			if json.parse(text) == OK and json.data is Array:
				existing = json.data
	for ev in _pending_events:
		existing.append(ev)
	var w := FileAccess.open(rollup_path, FileAccess.WRITE)
	if w == null:
		return 0
	w.store_string(JSON.stringify(existing, "\t"))
	w.close()
	var count: int = _pending_events.size()
	_pending_events.clear()
	telemetry_flushed.emit(count)
	return count
