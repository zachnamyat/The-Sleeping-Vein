extends Node

## Phase 15 — Save backup + autosave + thumbnail + corruption verify.
## Tickets:
##   15.23 — Auto-save interval + manual save in-menu
##   15.24 — Save backup rotation (last 3 autosaves on disk)
##   15.36 — Save thumbnail (screenshot at last save)
##   15.37 — Save metadata display (playtime, deaths, bosses)
##   15.51 — Save corruption verify + auto-recover from backup
##   15.52 — Save migration scripts between versions

const AUTOSAVE_DIR_PREFIX: String = "autosave"
const AUTOSAVE_KEEP: int = 3
const AUTOSAVE_INTERVAL_DEFAULT: int = 300   # 5 minutes
const THUMBNAIL_FILENAME: String = "thumb.png"
const META_DEFAULTS: Dictionary = {
	"playtime_seconds": 0,
	"deaths": 0,
	"bosses_defeated": 0,
	"highest_skill_level": 0,
	"engine_version": "unknown",
}

signal autosave_triggered(slot: String)
signal autosave_rotated(removed_slot: String)
signal thumbnail_saved(path: String)
signal corruption_detected(slot: String, reason: String)
signal corruption_recovered(slot: String, from_backup: String)
signal migration_applied(from_version: int, to_version: int)

var autosave_interval_seconds: int = AUTOSAVE_INTERVAL_DEFAULT
var autosave_enabled: bool = true
var _accumulator: float = 0.0
var _last_autosave_unix: int = 0


func _ready() -> void:
	if Settings:
		autosave_interval_seconds = int(Settings.get_value("save.autosave_interval", AUTOSAVE_INTERVAL_DEFAULT))
		autosave_enabled = bool(Settings.get_value("save.autosave_enabled", true))
	set_process(true)


func _process(delta: float) -> void:
	if not autosave_enabled:
		return
	_accumulator += delta
	if _accumulator >= float(autosave_interval_seconds):
		_accumulator = 0.0
		perform_autosave()


func set_interval(seconds: int) -> void:
	autosave_interval_seconds = clampi(seconds, 30, 3600)
	if Settings:
		Settings.set_value("save.autosave_interval", autosave_interval_seconds)


func set_enabled(active: bool) -> void:
	autosave_enabled = active
	if Settings:
		Settings.set_value("save.autosave_enabled", active)


# ---------- Autosave (15.23 / 15.24) ----------

func perform_autosave() -> bool:
	if SaveSystem == null:
		return false
	# Rotate slot names: autosave_0 (newest) → autosave_1 → autosave_2.
	_rotate_autosaves()
	var slot: String = "%s_0" % AUTOSAVE_DIR_PREFIX
	var err: int = SaveSystem.save_to_slot(slot)
	if err == OK:
		_last_autosave_unix = Time.get_unix_time_from_system()
		autosave_triggered.emit(slot)
		# 15.36 thumbnail next frame so the current frame finishes rendering.
		call_deferred("_capture_thumbnail", slot)
	return err == OK


func _rotate_autosaves() -> void:
	# Delete the oldest, shift the rest by one.
	var oldest: String = "%s_%d" % [AUTOSAVE_DIR_PREFIX, AUTOSAVE_KEEP - 1]
	if SaveSystem.slot_exists(oldest):
		SaveSystem.delete_slot(oldest)
		autosave_rotated.emit(oldest)
	for i in range(AUTOSAVE_KEEP - 2, -1, -1):
		var src: String = "%s_%d" % [AUTOSAVE_DIR_PREFIX, i]
		var dst: String = "%s_%d" % [AUTOSAVE_DIR_PREFIX, i + 1]
		if SaveSystem.slot_exists(src):
			_rename_slot(src, dst)


func _rename_slot(src: String, dst: String) -> void:
	# DirAccess.rename works on absolute paths. We rename the directory.
	var save_root: String = ProjectSettings.globalize_path("user://saves/")
	var src_abs: String = save_root + src + "/"
	var dst_abs: String = save_root + dst + "/"
	if not DirAccess.dir_exists_absolute(src_abs):
		return
	# Remove dst first if it exists to allow rename through.
	if DirAccess.dir_exists_absolute(dst_abs):
		_remove_recursive(dst_abs)
	DirAccess.rename_absolute(src_abs, dst_abs)


func _remove_recursive(abs_path: String) -> void:
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var child: String = abs_path.path_join(name)
		if dir.current_is_dir():
			_remove_recursive(child)
		else:
			DirAccess.remove_absolute(child)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(abs_path)


# ---------- Thumbnail (15.36) ----------

func _capture_thumbnail(slot: String) -> void:
	var img: Image
	var vp := get_viewport()
	if vp == null:
		return
	img = vp.get_texture().get_image()
	if img == null:
		return
	# Downscale to 160x90 for a Steam-style thumbnail.
	img.resize(160, 90, Image.INTERPOLATE_LANCZOS)
	var path: String = "user://saves/%s/%s" % [slot, THUMBNAIL_FILENAME]
	DirAccess.make_dir_recursive_absolute("user://saves/" + slot + "/")
	img.save_png(path)
	thumbnail_saved.emit(path)


func thumbnail_path(slot: String) -> String:
	return "user://saves/%s/%s" % [slot, THUMBNAIL_FILENAME]


# ---------- Save metadata (15.37) ----------

func extended_meta(slot: String) -> Dictionary:
	if SaveSystem == null:
		return META_DEFAULTS.duplicate()
	var meta: Dictionary = SaveSystem.get_slot_meta(slot)
	if meta.is_empty():
		return META_DEFAULTS.duplicate()
	# Pull richer data from state.json if available.
	var state: Dictionary = _read_state(slot)
	var playtime: int = 0
	var deaths: int = 0
	var bosses: int = 0
	if state.has("phase15_helpers"):
		var p15: Dictionary = state["phase15_helpers"]
		playtime = int(p15.get("current_run_playtime_seconds", 0))
		deaths = int(p15.get("current_run_deaths", 0))
	if state.has("defeated_bosses"):
		bosses = (state["defeated_bosses"] as Dictionary).size()
	var skill_max: int = 0
	if state.has("skills"):
		for k in (state["skills"] as Dictionary).keys():
			var rec: Dictionary = state["skills"][k]
			var lv: int = int(rec.get("level", 0))
			if lv > skill_max:
				skill_max = lv
	return {
		"slot": slot,
		"timestamp_iso": String(meta.get("timestamp_iso", "")),
		"save_version": int(meta.get("save_version", 0)),
		"playtime_seconds": playtime,
		"deaths": deaths,
		"bosses_defeated": bosses,
		"highest_skill_level": skill_max,
		"world_seed": int(meta.get("world_seed", 0)),
	}


func _read_state(slot: String) -> Dictionary:
	var p: String = "user://saves/%s/state.json" % slot
	if not FileAccess.file_exists(p):
		return {}
	var file := FileAccess.open(p, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


# ---------- Corruption verify (15.51) ----------

func verify_slot(slot: String) -> Dictionary:
	var report: Dictionary = {"ok": false, "reason": "", "recovered_from": ""}
	if SaveSystem == null or not SaveSystem.slot_exists(slot):
		report["reason"] = "slot missing"
		return report
	var meta_p: String = "user://saves/%s/meta.json" % slot
	var state_p: String = "user://saves/%s/state.json" % slot
	if not FileAccess.file_exists(meta_p):
		report["reason"] = "meta missing"
	elif not FileAccess.file_exists(state_p):
		report["reason"] = "state missing"
	else:
		var state: Dictionary = _read_state(slot)
		if state.is_empty():
			report["reason"] = "state json parse failed"
		else:
			report["ok"] = true
	if not report["ok"]:
		corruption_detected.emit(slot, report["reason"])
		var fallback: String = _find_recovery_backup(slot)
		if fallback != "":
			report["recovered_from"] = fallback
	return report


## Find the newest autosave to use as a recovery source.
func _find_recovery_backup(_failed_slot: String) -> String:
	for i in AUTOSAVE_KEEP:
		var s: String = "%s_%d" % [AUTOSAVE_DIR_PREFIX, i]
		if SaveSystem.slot_exists(s):
			# Verify it.
			var p: String = "user://saves/%s/state.json" % s
			if FileAccess.file_exists(p):
				var f := FileAccess.open(p, FileAccess.READ)
				if f != null:
					var text := f.get_as_text()
					f.close()
					var json := JSON.new()
					if json.parse(text) == OK:
						return s
	return ""


## Auto-recover by copying a fallback into the corrupted slot's path. Returns
## true on success.
func auto_recover(slot: String) -> bool:
	var report: Dictionary = verify_slot(slot)
	if report["ok"]:
		return true
	var fallback: String = String(report.get("recovered_from", ""))
	if fallback == "":
		return false
	var save_root: String = "user://saves/"
	# Delete corrupted slot directory, then copy fallback into its place.
	if SaveSystem.slot_exists(slot):
		SaveSystem.delete_slot(slot)
	DirAccess.make_dir_recursive_absolute(save_root + slot + "/")
	for fname in ["meta.json", "state.json", "thumb.png"]:
		var src: String = save_root + fallback + "/" + fname
		var dst: String = save_root + slot + "/" + fname
		if FileAccess.file_exists(src):
			var src_file := FileAccess.open(src, FileAccess.READ)
			var dst_file := FileAccess.open(dst, FileAccess.WRITE)
			if src_file and dst_file:
				dst_file.store_buffer(src_file.get_buffer(src_file.get_length()))
			if src_file:
				src_file.close()
			if dst_file:
				dst_file.close()
	corruption_recovered.emit(slot, fallback)
	return true


# ---------- Save migration (15.52) ----------

## Try to upgrade a save dict from save_version `from_v` to `to_v` in-place.
## Migrations are versioned and idempotent. New phases add their own entries.
func migrate_state(state: Dictionary, from_v: int, to_v: int) -> Dictionary:
	var v: int = from_v
	while v < to_v:
		v = _apply_one_migration_step(state, v)
		if v == from_v:
			# No-op step; bail out to avoid infinite loop.
			break
	if v != from_v:
		migration_applied.emit(from_v, v)
	return state


func _apply_one_migration_step(state: Dictionary, from_v: int) -> int:
	# Each block here is one version-step migration.
	match from_v:
		11:
			# 11 → 12: Phase 14 added phase14_helpers + mod_system.
			if not state.has("phase14_helpers"):
				state["phase14_helpers"] = {}
			if not state.has("mod_system"):
				state["mod_system"] = {}
			return 12
		12:
			# 12 → 13: Phase 15 added phase15_helpers + cosmetics + accessibility.
			if not state.has("phase15_helpers"):
				state["phase15_helpers"] = {}
			if not state.has("cosmetics"):
				state["cosmetics"] = {}
			return 13
	return from_v
