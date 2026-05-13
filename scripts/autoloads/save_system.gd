extends Node

## Save / load system.
## Each save slot is a directory under user://saves/<slot>/ containing:
##   - meta.json     (save_version, slot_name, timestamp, world_seed)
##   - state.json    (GameState dump: slivers, defeated_bosses, recipes, etc.)
##   - world.json    (chunk diffs, placed structures, mob spawns — phase 4+)
##   - players.json  (per-Walker inventory, position, skills — phase 1+)
##
## JSON chosen for readability and forward-compat. Switch to binary if save size becomes a problem.
## Save format version is bumped any time a save-affecting field changes.

const SAVE_ROOT: String = "user://saves/"
const SAVE_VERSION: int = 1

signal save_started(slot_name: String)
signal save_completed(slot_name: String)
signal save_failed(slot_name: String, reason: String)
signal load_started(slot_name: String)
signal load_completed(slot_name: String)
signal load_failed(slot_name: String, reason: String)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_ROOT))


# ----- Public API -----

func save_to_slot(slot_name: String) -> Error:
	save_started.emit(slot_name)
	var dir_path := SAVE_ROOT + slot_name + "/"
	var make_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	if make_err != OK and make_err != ERR_ALREADY_EXISTS:
		save_failed.emit(slot_name, "cannot create slot dir: %s" % error_string(make_err))
		return make_err

	var meta := {
		"save_version": SAVE_VERSION,
		"slot_name": slot_name,
		"timestamp_unix": Time.get_unix_time_from_system(),
		"timestamp_iso": Time.get_datetime_string_from_system(),
		"world_seed": GameState.world_seed,
		"engine_version": Engine.get_version_info(),
	}
	var state := _dump_game_state()

	var meta_err := _write_json(dir_path + "meta.json", meta)
	if meta_err != OK:
		save_failed.emit(slot_name, "meta write failed: %s" % error_string(meta_err))
		return meta_err
	var state_err := _write_json(dir_path + "state.json", state)
	if state_err != OK:
		save_failed.emit(slot_name, "state write failed: %s" % error_string(state_err))
		return state_err

	save_completed.emit(slot_name)
	return OK


func load_from_slot(slot_name: String) -> Error:
	load_started.emit(slot_name)
	var dir_path := SAVE_ROOT + slot_name + "/"
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		load_failed.emit(slot_name, "slot directory not found")
		return ERR_FILE_NOT_FOUND

	var meta: Dictionary = {}
	var meta_err := _read_json(dir_path + "meta.json", meta)
	if meta_err != OK:
		load_failed.emit(slot_name, "meta read failed: %s" % error_string(meta_err))
		return meta_err

	var saved_version: int = int(meta.get("save_version", 0))
	if saved_version != SAVE_VERSION:
		# Phase 0: warn + best-effort. Phase 1+: migration scripts in scripts/systems/save_migrations/.
		push_warning("SaveSystem: save_version %d differs from current %d — attempting best-effort load" % [saved_version, SAVE_VERSION])

	var state: Dictionary = {}
	var state_err := _read_json(dir_path + "state.json", state)
	if state_err != OK:
		load_failed.emit(slot_name, "state read failed: %s" % error_string(state_err))
		return state_err

	GameState.world_seed = int(meta.get("world_seed", 0))
	_restore_game_state(state)

	load_completed.emit(slot_name)
	return OK


func slot_exists(slot_name: String) -> bool:
	return DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SAVE_ROOT + slot_name + "/"))


func delete_slot(slot_name: String) -> Error:
	var dir_path := ProjectSettings.globalize_path(SAVE_ROOT + slot_name + "/")
	if not DirAccess.dir_exists_absolute(dir_path):
		return ERR_FILE_NOT_FOUND
	return _remove_directory_recursive(dir_path)


func list_slots() -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(SAVE_ROOT)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and entry != "." and entry != "..":
			result.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	return result


func get_slot_meta(slot_name: String) -> Dictionary:
	var meta: Dictionary = {}
	_read_json(SAVE_ROOT + slot_name + "/meta.json", meta)
	return meta


# ----- Internals -----

func _dump_game_state() -> Dictionary:
	return {
		"aphelion_slivers_remaining": GameState.aphelion_slivers_remaining,
		"defeated_bosses": GameState.defeated_bosses,
		"collected_relics": GameState.collected_relics,
		"arrived_npcs": GameState.arrived_npcs,
		"unlocked_recipes": GameState.unlocked_recipes,
		"unlocked_compendium": GameState.unlocked_compendium,
		"sovereign_threads": GameState.sovereign_threads,
	}


func _restore_game_state(state: Dictionary) -> void:
	GameState.aphelion_slivers_remaining = int(state.get("aphelion_slivers_remaining", GameState.APHELION_STARTING_SLIVERS))
	GameState.defeated_bosses = state.get("defeated_bosses", {})
	GameState.collected_relics = state.get("collected_relics", {})
	GameState.arrived_npcs = state.get("arrived_npcs", {})
	GameState.unlocked_recipes = state.get("unlocked_recipes", {})
	GameState.unlocked_compendium = state.get("unlocked_compendium", {})
	GameState.sovereign_threads = int(state.get("sovereign_threads", 0))


func _write_json(path: String, data: Variant) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return OK


func _read_json(path: String, out_data: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return err
	if typeof(json.data) != TYPE_DICTIONARY:
		return ERR_PARSE_ERROR
	for k in (json.data as Dictionary).keys():
		out_data[k] = (json.data as Dictionary)[k]
	return OK


func _remove_directory_recursive(abs_path: String) -> Error:
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return ERR_FILE_NOT_FOUND
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var child := abs_path.path_join(entry)
		if dir.current_is_dir():
			_remove_directory_recursive(child)
		else:
			DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	return DirAccess.remove_absolute(abs_path)
