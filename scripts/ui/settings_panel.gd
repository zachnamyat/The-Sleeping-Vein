extends CanvasLayer
class_name SettingsPanel

## Tickets 0.12 + 0.13 + 0.14 — settings panel.
## Three tabs: Display (window mode, resolution, vsync) / Audio (4 bus sliders) /
## Controls (per-action rebind). Persists via Settings autoload (user://settings.json).
## Toggled from PauseMenu and TitleScreen via a "Settings" button.

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]
const REBINDABLE_ACTIONS: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right",
	&"attack_primary", &"attack_secondary",
	&"interact", &"open_inventory", &"open_map", &"dodge",
	&"hotbar_1", &"hotbar_2", &"hotbar_3", &"hotbar_4", &"hotbar_5",
	&"hotbar_6", &"hotbar_7", &"hotbar_8", &"hotbar_9", &"hotbar_10",
]

@onready var _tabs: TabContainer = $Root/Tabs
@onready var _window_mode_btn: OptionButton = $Root/Tabs/Display/Grid/WindowModeBtn
@onready var _resolution_btn: OptionButton = $Root/Tabs/Display/Grid/ResolutionBtn
@onready var _vsync_check: CheckBox = $Root/Tabs/Display/Grid/VsyncCheck
@onready var _volume_grid: GridContainer = $Root/Tabs/Audio/Grid
@onready var _controls_list: VBoxContainer = $Root/Tabs/Controls/Scroll/List
@onready var _hud_scale_slider: HSlider = $Root/Tabs/Game/Grid/HudScaleSlider
@onready var _hud_opacity_slider: HSlider = $Root/Tabs/Game/Grid/HudOpacitySlider
@onready var _tooltip_delay_btn: OptionButton = $Root/Tabs/Game/Grid/TooltipDelayBtn
@onready var _accent_picker_btn: ColorPickerButton = $Root/Tabs/Game/Grid/AccentPickerBtn

const TOOLTIP_DELAYS: Array[Dictionary] = [
	{"label": "Instant", "value": 0.0},
	{"label": "0.5 seconds", "value": 0.5},
	{"label": "1.0 seconds", "value": 1.0},
]

var _waiting_for_input_action: StringName = &""
var _waiting_button: Button = null


func _ready() -> void:
	add_to_group("settings_panel")
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_populate_window_mode()
	_populate_resolutions()
	_populate_audio_sliders()
	_populate_controls()
	$Root/Buttons/Reset.pressed.connect(_on_reset)
	$Root/Buttons/Close.pressed.connect(close)
	_populate_game_tab()
	_sync_from_settings()
	UIAudio.wire_button_sfx(self)


func _populate_game_tab() -> void:
	# Ticket 1.31 / 1.32 / 1.47 — wire new Gameplay tab controls.
	if _tooltip_delay_btn:
		for opt in TOOLTIP_DELAYS:
			_tooltip_delay_btn.add_item(String(opt["label"]))
		_tooltip_delay_btn.item_selected.connect(_on_tooltip_delay_changed)
	if _hud_scale_slider:
		_hud_scale_slider.value_changed.connect(_on_hud_scale_changed)
	if _hud_opacity_slider:
		_hud_opacity_slider.value_changed.connect(_on_hud_opacity_changed)
	if _accent_picker_btn:
		_accent_picker_btn.color_changed.connect(_on_accent_changed)


func _on_hud_scale_changed(v: float) -> void:
	Settings.set_value("hud_scale", v)


func _on_hud_opacity_changed(v: float) -> void:
	Settings.set_value("hud_opacity", v)


func _on_tooltip_delay_changed(idx: int) -> void:
	if idx >= 0 and idx < TOOLTIP_DELAYS.size():
		Settings.set_value("tooltip_delay", float(TOOLTIP_DELAYS[idx]["value"]))


func _on_accent_changed(c: Color) -> void:
	Settings.set_value("accent_color", "#%02x%02x%02x" % [int(c.r * 255), int(c.g * 255), int(c.b * 255)])


# ----- Open / close -----

func open() -> void:
	_sync_from_settings()
	visible = true
	UIAudio.play_panel_open()


func close() -> void:
	visible = false
	_cancel_rebind()
	UIAudio.play_panel_close()


# ----- Display tab -----

func _populate_window_mode() -> void:
	_window_mode_btn.clear()
	_window_mode_btn.add_item("Windowed", 0)
	_window_mode_btn.add_item("Fullscreen", 1)
	_window_mode_btn.add_item("Borderless", 2)
	_window_mode_btn.item_selected.connect(_on_window_mode_selected)


func _populate_resolutions() -> void:
	_resolution_btn.clear()
	for i in RESOLUTIONS.size():
		var r: Vector2i = RESOLUTIONS[i]
		_resolution_btn.add_item("%d x %d" % [r.x, r.y], i)
	_resolution_btn.item_selected.connect(_on_resolution_selected)


func _on_window_mode_selected(idx: int) -> void:
	var modes: Array[StringName] = [&"windowed", &"fullscreen", &"borderless"]
	Settings.set_window_mode(modes[idx])


func _on_resolution_selected(idx: int) -> void:
	Settings.set_resolution(RESOLUTIONS[idx])


# ----- Audio tab -----

func _populate_audio_sliders() -> void:
	for child in _volume_grid.get_children():
		child.queue_free()
	for bus in [&"master", &"music", &"sfx", &"ambient"]:
		var label := Label.new()
		label.text = String(bus).capitalize()
		label.custom_minimum_size = Vector2(60, 0)
		_volume_grid.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.custom_minimum_size = Vector2(140, 0)
		slider.value = Settings.get_volume(bus)
		slider.value_changed.connect(_on_volume_changed.bind(bus))
		_volume_grid.add_child(slider)
		var pct := Label.new()
		pct.text = "%d%%" % int(slider.value * 100)
		pct.name = "Pct_" + String(bus)
		pct.custom_minimum_size = Vector2(40, 0)
		_volume_grid.add_child(pct)


func _on_volume_changed(value: float, bus: StringName) -> void:
	Settings.set_volume(bus, value)
	var pct: Label = _volume_grid.get_node_or_null("Pct_" + String(bus))
	if pct:
		pct.text = "%d%%" % int(value * 100)


# ----- Controls tab -----

func _populate_controls() -> void:
	for child in _controls_list.get_children():
		child.queue_free()
	for action in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 20)
		var name_label := Label.new()
		name_label.text = String(action).replace("_", " ")
		name_label.custom_minimum_size = Vector2(120, 0)
		row.add_child(name_label)
		var rebind := Button.new()
		rebind.text = _action_event_label(action)
		rebind.custom_minimum_size = Vector2(140, 0)
		rebind.pressed.connect(_begin_rebind.bind(action, rebind))
		row.add_child(rebind)
		_controls_list.add_child(row)


func _action_event_label(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "(unbound)"
	var ev := events[0]
	if ev is InputEventKey:
		return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	if ev is InputEventMouseButton:
		var idx := (ev as InputEventMouseButton).button_index
		return "Mouse %d" % idx
	if ev is InputEventJoypadButton:
		return "Pad %d" % (ev as InputEventJoypadButton).button_index
	return ev.as_text()


func _begin_rebind(action: StringName, button: Button) -> void:
	if _waiting_for_input_action != &"":
		return
	_waiting_for_input_action = action
	_waiting_button = button
	button.text = "press any key…"


func _cancel_rebind() -> void:
	if _waiting_for_input_action == &"":
		return
	if _waiting_button:
		_waiting_button.text = _action_event_label(_waiting_for_input_action)
	_waiting_for_input_action = &""
	_waiting_button = null


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _waiting_for_input_action == &"":
		# Allow ESC to close the panel from anywhere.
		if event.is_action_pressed("ui_cancel"):
			close()
			get_viewport().set_input_as_handled()
		return
	# Rebind capture: accept first key/mouse/joypad event.
	if event is InputEventKey and event.pressed and not event.echo:
		Settings.rebind_action(_waiting_for_input_action, event)
		_finish_rebind()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		Settings.rebind_action(_waiting_for_input_action, event)
		_finish_rebind()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		Settings.rebind_action(_waiting_for_input_action, event)
		_finish_rebind()
		get_viewport().set_input_as_handled()


func _finish_rebind() -> void:
	if _waiting_button:
		_waiting_button.text = _action_event_label(_waiting_for_input_action)
	_waiting_for_input_action = &""
	_waiting_button = null


# ----- Reset / sync -----

func _on_reset() -> void:
	Settings.reset_to_defaults()
	_sync_from_settings()
	_populate_controls()


func _sync_from_settings() -> void:
	var modes: Array[StringName] = [&"windowed", &"fullscreen", &"borderless"]
	var mode_idx: int = max(0, modes.find(Settings.window_mode))
	_window_mode_btn.select(mode_idx)
	var res_idx: int = RESOLUTIONS.find(Settings.resolution)
	if res_idx < 0:
		res_idx = RESOLUTIONS.find(Vector2i(1920, 1080))
	_resolution_btn.select(res_idx)
	_vsync_check.button_pressed = Settings.vsync
	if not _vsync_check.toggled.is_connected(_on_vsync_toggled):
		_vsync_check.toggled.connect(_on_vsync_toggled)
	# Audio sliders rebuild themselves with current values via _populate_audio_sliders.
	# To avoid duplicate signal connections, re-populate only if missing rows.
	if _volume_grid.get_child_count() == 0:
		_populate_audio_sliders()
	# Game tab values (HUD scale/opacity, tooltip delay, accent color).
	if _hud_scale_slider:
		_hud_scale_slider.set_value_no_signal(float(Settings.get_value("hud_scale", 1.0)))
	if _hud_opacity_slider:
		_hud_opacity_slider.set_value_no_signal(float(Settings.get_value("hud_opacity", 1.0)))
	if _tooltip_delay_btn:
		var stored_delay: float = float(Settings.get_value("tooltip_delay", 0.0))
		var match_idx: int = 0
		for i in TOOLTIP_DELAYS.size():
			if abs(float(TOOLTIP_DELAYS[i]["value"]) - stored_delay) < 0.01:
				match_idx = i
				break
		_tooltip_delay_btn.select(match_idx)
	if _accent_picker_btn:
		var stored_color: Variant = Settings.get_value("accent_color", "#ffd970")
		if stored_color is String:
			_accent_picker_btn.color = Color(stored_color)
		elif stored_color is Color:
			_accent_picker_btn.color = stored_color


func _on_vsync_toggled(pressed: bool) -> void:
	Settings.set_vsync(pressed)
