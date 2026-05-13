extends Node

## Tickets 0.12 + 0.13 + 0.14 — persisted user settings (display, audio, controls).
## Stored as JSON at user://settings.json so they survive across runs and are easy to
## hand-edit during testing. Apply on _ready() so settings take effect at every launch.
##
## Public API:
##     Settings.set_volume("master", 0.8)
##     Settings.get_volume("master")              # 0.0..1.0
##     Settings.set_window_mode("fullscreen")     # windowed | fullscreen | borderless
##     Settings.set_resolution(Vector2i(1920, 1080))
##     Settings.set_vsync(true)
##     Settings.rebind_action("attack_primary", InputEvent)
##     Settings.reset_to_defaults()
##     Settings.save() / Settings.load()

const SETTINGS_PATH: String = "user://settings.json"
const VALID_BUSES: Array[StringName] = [&"master", &"music", &"sfx", &"ambient"]
const DEFAULT_RESOLUTION: Vector2i = Vector2i(1920, 1080)

signal settings_applied()

var volumes: Dictionary = {
	&"master": 1.0,
	&"music": 0.8,
	&"sfx": 0.9,
	&"ambient": 0.7,
}
var window_mode: StringName = &"windowed" # windowed | fullscreen | borderless
var resolution: Vector2i = DEFAULT_RESOLUTION
var vsync: bool = true
var input_overrides: Dictionary = {} # action_name -> Array of InputEvent dicts
var custom: Dictionary = {} # generic kv store for HUD scale/opacity, tooltip delay, accent color, etc.

signal value_changed(key: String, value: Variant)


func _ready() -> void:
	load_from_disk()
	apply_all()


# ----- Public API -----

func set_volume(bus: StringName, linear_value: float) -> void:
	if bus not in VALID_BUSES:
		push_warning("Settings: unknown audio bus '%s'" % bus)
		return
	volumes[bus] = clamp(linear_value, 0.0, 1.0)
	_apply_volume(bus)
	save()


func get_volume(bus: StringName) -> float:
	return float(volumes.get(bus, 1.0))


func set_window_mode(mode: StringName) -> void:
	if mode not in [&"windowed", &"fullscreen", &"borderless"]:
		push_warning("Settings: unknown window mode '%s'" % mode)
		return
	window_mode = mode
	_apply_window_mode()
	save()


func set_resolution(size: Vector2i) -> void:
	resolution = size
	_apply_window_mode() # also re-applies size
	save()


func set_vsync(enabled: bool) -> void:
	vsync = enabled
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	)
	save()


func get_value(key: String, default: Variant) -> Variant:
	return custom.get(key, default)


func set_value(key: String, value: Variant) -> void:
	custom[key] = value
	value_changed.emit(key, value)
	save()


func rebind_action(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		push_warning("Settings: unknown action '%s'" % action)
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	input_overrides[String(action)] = [_event_to_dict(event)]
	save()


func reset_to_defaults() -> void:
	volumes = {
		&"master": 1.0,
		&"music": 0.8,
		&"sfx": 0.9,
		&"ambient": 0.7,
	}
	window_mode = &"windowed"
	resolution = DEFAULT_RESOLUTION
	vsync = true
	input_overrides.clear()
	custom.clear()
	# Re-load InputMap from project.godot defaults.
	InputMap.load_from_project_settings()
	apply_all()
	save()


func apply_all() -> void:
	for bus in VALID_BUSES:
		_apply_volume(bus)
	_apply_window_mode()
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
	for action_str in input_overrides.keys():
		var action := StringName(action_str)
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for event_dict in input_overrides[action_str]:
			var event := _dict_to_event(event_dict)
			if event != null:
				InputMap.action_add_event(action, event)
	settings_applied.emit()


func save() -> void:
	var data := {
		"volumes": _stringify_keys(volumes),
		"window_mode": String(window_mode),
		"resolution": [resolution.x, resolution.y],
		"vsync": vsync,
		"input_overrides": input_overrides,
		"custom": custom,
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Settings: cannot write %s" % SETTINGS_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func load_from_disk() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("Settings: parse error in %s, using defaults" % SETTINGS_PATH)
		return
	var data: Dictionary = json.data
	for k in (data.get("volumes", {}) as Dictionary):
		volumes[StringName(k)] = float((data["volumes"] as Dictionary)[k])
	window_mode = StringName(data.get("window_mode", "windowed"))
	var res_arr: Array = data.get("resolution", [DEFAULT_RESOLUTION.x, DEFAULT_RESOLUTION.y])
	if res_arr.size() == 2:
		resolution = Vector2i(int(res_arr[0]), int(res_arr[1]))
	vsync = bool(data.get("vsync", true))
	input_overrides = data.get("input_overrides", {})
	custom = data.get("custom", {})


# ----- Internals -----

func _apply_volume(bus: StringName) -> void:
	var idx := AudioServer.get_bus_index(String(bus).capitalize())
	if idx < 0:
		# Master is always present (bus 0); custom buses are added via the AudioBus autoload.
		if String(bus) == "master":
			idx = 0
		else:
			return
	var linear: float = float(volumes.get(bus, 1.0))
	AudioServer.set_bus_volume_db(idx, linear_to_db(max(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.0)


func _apply_window_mode() -> void:
	match String(window_mode):
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_size(resolution)
		_: # windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_size(resolution)


func _event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var k: InputEventKey = event
		return {
			"type": "key",
			"physical_keycode": int(k.physical_keycode),
			"keycode": int(k.keycode),
			"alt": k.alt_pressed,
			"shift": k.shift_pressed,
			"ctrl": k.ctrl_pressed,
		}
	if event is InputEventMouseButton:
		var m: InputEventMouseButton = event
		return {"type": "mouse", "button_index": int(m.button_index)}
	if event is InputEventJoypadButton:
		var j: InputEventJoypadButton = event
		return {"type": "joypad", "button_index": int(j.button_index)}
	return {}


func _dict_to_event(d: Dictionary) -> InputEvent:
	match String(d.get("type", "")):
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = int(d.get("physical_keycode", 0))
			k.keycode = int(d.get("keycode", 0))
			k.alt_pressed = bool(d.get("alt", false))
			k.shift_pressed = bool(d.get("shift", false))
			k.ctrl_pressed = bool(d.get("ctrl", false))
			return k
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = int(d.get("button_index", 1))
			return m
		"joypad":
			var j := InputEventJoypadButton.new()
			j.button_index = int(d.get("button_index", 0))
			return j
	return null


func _stringify_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d.keys():
		out[String(k)] = d[k]
	return out
