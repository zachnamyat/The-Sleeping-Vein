extends CanvasLayer
class_name AccessibilitySettingsPanel

## Phase 15 — Accessibility settings panel. Surfaces every flag on the
## AccessibilityManager autoload through a single screen.
## Tickets: 15.10 / 15.17 / 15.18 / 15.59 / 15.60 / 15.61 / 15.62 / 15.63.

var _root: Control
var _content: VBoxContainer


func _ready() -> void:
	layer = 25
	add_to_group("accessibility_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()


func _build_ui() -> void:
	_root = Control.new()
	_root.anchor_left = 0.5
	_root.anchor_right = 0.5
	_root.anchor_top = 0.5
	_root.anchor_bottom = 0.5
	_root.offset_left = -240
	_root.offset_right = 240
	_root.offset_top = -240
	_root.offset_bottom = 240
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.96)
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	_root.add_child(bg)
	var t := Label.new()
	t.text = "Accessibility"
	t.offset_left = 16
	t.offset_top = 8
	t.add_theme_color_override("font_color", Color(0.85, 0.74, 0.45))
	_root.add_child(t)
	var scroll := ScrollContainer.new()
	scroll.offset_left = 16
	scroll.offset_top = 40
	scroll.offset_right = -16
	scroll.offset_bottom = -16
	scroll.anchor_right = 1
	scroll.anchor_bottom = 1
	_root.add_child(scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)


func _refresh() -> void:
	for c in _content.get_children():
		c.queue_free()
	if AccessibilityManager == null:
		return
	_content.add_child(_make_picker("Colorblind",
		AccessibilityManager.COLORBLIND_MODES,
		AccessibilityManager.COLORBLIND_MODES.find(AccessibilityManager.colorblind_mode),
		func(i): AccessibilityManager.set_colorblind_mode(AccessibilityManager.COLORBLIND_MODES[i])
	))
	var ts_idx: int = 1
	for i in AccessibilityManager.TEXT_SCALE_PRESETS.size():
		if abs(AccessibilityManager.TEXT_SCALE_PRESETS[i] - AccessibilityManager.text_scale) < 0.01:
			ts_idx = i
			break
	_content.add_child(_make_picker("Text scale",
		_format_scale_labels(),
		ts_idx,
		func(i): AccessibilityManager.set_text_scale(AccessibilityManager.TEXT_SCALE_PRESETS[i])
	))
	_content.add_child(_make_toggle("High contrast", AccessibilityManager.high_contrast,
		func(b): AccessibilityManager.set_high_contrast(b)))
	_content.add_child(_make_toggle("Aim assist", AccessibilityManager.aim_assist,
		func(b): AccessibilityManager.set_aim_assist(b)))
	_content.add_child(_make_toggle("Pause on focus loss", AccessibilityManager.pause_on_focus_loss,
		func(b): AccessibilityManager.set_pause_on_focus_loss(b)))
	_content.add_child(_make_toggle("One-handed preset", AccessibilityManager.one_handed_preset,
		func(b): AccessibilityManager.set_one_handed_preset(b)))
	_content.add_child(_make_toggle("Subtitles", AccessibilityManager.subtitles_enabled,
		func(b): AccessibilityManager.set_subtitles(b)))
	_content.add_child(_make_toggle("Reduce screen shake", AccessibilityManager.screen_shake_scale < 0.5,
		func(b): AccessibilityManager.set_screen_shake_scale(0.0 if b else 1.0)))
	_content.add_child(_make_toggle("Reduce flashes (photosensitive)", AccessibilityManager.photosensitive_safe,
		func(b): AccessibilityManager.set_photosensitive_safe(b)))
	# Hold-vs-toggle per action.
	var section := Label.new()
	section.text = "Hold-vs-Toggle inputs"
	section.modulate = Color(0.97, 0.85, 0.5)
	_content.add_child(section)
	for a in AccessibilityManager.TOGGLEABLE_ACTIONS:
		_content.add_child(_make_toggle(
			"%s (toggle)" % String(a),
			AccessibilityManager.is_action_toggle(a),
			func(b): AccessibilityManager.set_action_toggle(a, b)
		))


func _format_scale_labels() -> Array:
	var out := []
	for s in AccessibilityManager.TEXT_SCALE_PRESETS:
		out.append("%.0f%%" % (float(s) * 100.0))
	return out


func _make_picker(label: String, options: Array, initial: int, on_change: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(200, 0)
	l.modulate = Color(0.9, 0.86, 0.7)
	h.add_child(l)
	var opt := OptionButton.new()
	for o in options:
		opt.add_item(String(o))
	opt.select(clampi(initial, 0, max(options.size() - 1, 0)))
	opt.item_selected.connect(func(i: int) -> void: on_change.call(i))
	h.add_child(opt)
	return h


func _make_toggle(label: String, initial: bool, on_change: Callable) -> Control:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(280, 0)
	l.modulate = Color(0.9, 0.86, 0.7)
	h.add_child(l)
	var c := CheckBox.new()
	c.button_pressed = initial
	c.toggled.connect(func(p: bool) -> void: on_change.call(p))
	h.add_child(c)
	return h
