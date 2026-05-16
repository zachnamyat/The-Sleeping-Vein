extends CanvasLayer
class_name FirstRunWizard

## Phase 15 — First-run wizard / new-player setup flow.
## Tickets: 4.65, plus 15.10 / 15.75 (locale autodetect surfaces here).
##
## Three pages: Welcome -> Display / Locale -> Accessibility. Shows on the
## very first launch; never again unless Settings.first_run_done is reset.

signal completed()

const PAGES: Array[StringName] = [&"welcome", &"display", &"accessibility"]

var _page: int = 0
var _root: Control
var _content: VBoxContainer
var _next_btn: Button
var _prev_btn: Button


func _ready() -> void:
	layer = 60
	add_to_group("first_run_wizard")
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Settings and bool(Settings.get_value("first_run.completed", false)):
		# Already done. Stay hidden.
		visible = false
		queue_free()
		return
	_build_ui()
	visible = true
	_render_page()


func _build_ui() -> void:
	_root = Control.new()
	_root.anchor_left = 0.5
	_root.anchor_right = 0.5
	_root.anchor_top = 0.5
	_root.anchor_bottom = 0.5
	_root.offset_left = -260
	_root.offset_right = 260
	_root.offset_top = -200
	_root.offset_bottom = 200
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.98)
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	_root.add_child(bg)
	var v := VBoxContainer.new()
	v.offset_left = 16
	v.offset_top = 16
	v.offset_right = -16
	v.offset_bottom = -52
	v.anchor_right = 1
	v.anchor_bottom = 1
	v.add_theme_constant_override("separation", 6)
	_root.add_child(v)
	_content = v
	# Footer.
	var footer := HBoxContainer.new()
	footer.offset_left = 16
	footer.offset_top = -44
	footer.offset_right = -16
	footer.offset_bottom = -16
	footer.anchor_top = 1
	footer.anchor_bottom = 1
	footer.anchor_right = 1
	_root.add_child(footer)
	_prev_btn = Button.new()
	_prev_btn.text = "Back"
	_prev_btn.pressed.connect(_on_prev)
	footer.add_child(_prev_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	_next_btn = Button.new()
	_next_btn.text = "Next"
	_next_btn.pressed.connect(_on_next)
	footer.add_child(_next_btn)


func _render_page() -> void:
	for c in _content.get_children():
		c.queue_free()
	_prev_btn.disabled = _page == 0
	_next_btn.text = "Finish" if _page == PAGES.size() - 1 else "Next"
	match PAGES[_page]:
		&"welcome":
			_render_welcome()
		&"display":
			_render_display()
		&"accessibility":
			_render_accessibility()


func _render_welcome() -> void:
	var t := Label.new()
	t.text = "Welcome, Walker."
	t.add_theme_color_override("font_color", Color(0.85, 0.74, 0.45))
	_content.add_child(t)
	var body := Label.new()
	body.text = "We will tune a few things before you descend.\n\nNothing here is final — every setting can be changed later from the pause menu."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.modulate = Color(0.92, 0.88, 0.74)
	_content.add_child(body)


func _render_display() -> void:
	var t := Label.new()
	t.text = "Display & Language"
	t.add_theme_color_override("font_color", Color(0.85, 0.74, 0.45))
	_content.add_child(t)
	# Locale row.
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	_content.add_child(h)
	var l := Label.new()
	l.text = "Language"
	l.custom_minimum_size = Vector2(120, 0)
	h.add_child(l)
	var opt := OptionButton.new()
	var locales: Array = []
	if LocalizationManager:
		locales = LocalizationManager.SUPPORTED_LOCALES
	else:
		locales = [&"en"]
	var auto_idx: int = 0
	for i in locales.size():
		opt.add_item(String(locales[i]))
		if LocalizationManager and locales[i] == LocalizationManager.auto_detected_locale:
			auto_idx = i
	opt.select(auto_idx)
	opt.item_selected.connect(func(i: int) -> void:
		if LocalizationManager:
			LocalizationManager.apply_locale(locales[i])
	)
	h.add_child(opt)
	# Window mode.
	var win_row := HBoxContainer.new()
	win_row.add_theme_constant_override("separation", 8)
	_content.add_child(win_row)
	var wl := Label.new()
	wl.text = "Window mode"
	wl.custom_minimum_size = Vector2(120, 0)
	win_row.add_child(wl)
	var wopt := OptionButton.new()
	wopt.add_item("Windowed")
	wopt.add_item("Fullscreen")
	wopt.add_item("Borderless")
	wopt.select(0)
	wopt.item_selected.connect(func(i: int) -> void:
		if Settings:
			Settings.set_window_mode([&"windowed", &"fullscreen", &"borderless"][i])
	)
	win_row.add_child(wopt)


func _render_accessibility() -> void:
	var t := Label.new()
	t.text = "Accessibility"
	t.add_theme_color_override("font_color", Color(0.85, 0.74, 0.45))
	_content.add_child(t)
	if AccessibilityManager == null:
		var miss := Label.new()
		miss.text = "(accessibility module not loaded)"
		miss.modulate = Color(0.7, 0.65, 0.55)
		_content.add_child(miss)
		return
	# Text scale.
	var ts_row := HBoxContainer.new()
	var ts_l := Label.new()
	ts_l.text = "Text scale"
	ts_l.custom_minimum_size = Vector2(140, 0)
	ts_row.add_child(ts_l)
	var ts_opt := OptionButton.new()
	for s in AccessibilityManager.TEXT_SCALE_PRESETS:
		ts_opt.add_item("%.0f%%" % (float(s) * 100.0))
	ts_opt.select(1)
	ts_opt.item_selected.connect(func(i: int) -> void:
		AccessibilityManager.set_text_scale(AccessibilityManager.TEXT_SCALE_PRESETS[i])
	)
	ts_row.add_child(ts_opt)
	_content.add_child(ts_row)
	# Colorblind mode.
	var cb_row := HBoxContainer.new()
	var cb_l := Label.new()
	cb_l.text = "Colorblind"
	cb_l.custom_minimum_size = Vector2(140, 0)
	cb_row.add_child(cb_l)
	var cb_opt := OptionButton.new()
	for m in AccessibilityManager.COLORBLIND_MODES:
		cb_opt.add_item(String(m).capitalize())
	cb_opt.select(0)
	cb_opt.item_selected.connect(func(i: int) -> void:
		AccessibilityManager.set_colorblind_mode(AccessibilityManager.COLORBLIND_MODES[i])
	)
	cb_row.add_child(cb_opt)
	_content.add_child(cb_row)
	# Subtitles + aim assist.
	var sub_row := HBoxContainer.new()
	var sub_l := Label.new()
	sub_l.text = "Subtitles"
	sub_l.custom_minimum_size = Vector2(140, 0)
	sub_row.add_child(sub_l)
	var sub_chk := CheckBox.new()
	sub_chk.button_pressed = true
	sub_chk.toggled.connect(func(p: bool) -> void: AccessibilityManager.set_subtitles(p))
	sub_row.add_child(sub_chk)
	_content.add_child(sub_row)
	var aa_row := HBoxContainer.new()
	var aa_l := Label.new()
	aa_l.text = "Aim assist"
	aa_l.custom_minimum_size = Vector2(140, 0)
	aa_row.add_child(aa_l)
	var aa_chk := CheckBox.new()
	aa_chk.toggled.connect(func(p: bool) -> void: AccessibilityManager.set_aim_assist(p))
	aa_row.add_child(aa_chk)
	_content.add_child(aa_row)
	# Photosensitive safe mode.
	var ps_row := HBoxContainer.new()
	var ps_l := Label.new()
	ps_l.text = "Reduce flashes"
	ps_l.custom_minimum_size = Vector2(140, 0)
	ps_row.add_child(ps_l)
	var ps_chk := CheckBox.new()
	ps_chk.toggled.connect(func(p: bool) -> void: AccessibilityManager.set_photosensitive_safe(p))
	ps_row.add_child(ps_chk)
	_content.add_child(ps_row)


func _on_prev() -> void:
	if _page > 0:
		_page -= 1
		_render_page()


func _on_next() -> void:
	if _page < PAGES.size() - 1:
		_page += 1
		_render_page()
	else:
		_finish()


func _finish() -> void:
	if Settings:
		Settings.set_value("first_run.completed", true)
	completed.emit()
	EventBus.phase15_first_run_wizard_completed.emit()
	visible = false
	queue_free()
