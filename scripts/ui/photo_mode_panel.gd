extends CanvasLayer
class_name PhotoModePanel

## Phase 15.22 — Photo Mode UI.
## Listens to PhotoMode autoload; renders the filter picker / HUD toggle /
## capture button.

var _root: Control
var _content: VBoxContainer
var _filter_opt: OptionButton
var _hud_chk: CheckBox


func _ready() -> void:
	layer = 60
	add_to_group("photo_mode_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	if PhotoMode:
		PhotoMode.photo_mode_entered.connect(func() -> void: visible = true)
		PhotoMode.photo_mode_exited.connect(func() -> void: visible = false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = (event as InputEventKey).keycode
		if k == KEY_F2:
			if PhotoMode:
				PhotoMode.toggle()


func _build_ui() -> void:
	_root = Control.new()
	_root.anchor_left = 1
	_root.anchor_right = 1
	_root.anchor_top = 0
	_root.anchor_bottom = 0
	_root.offset_left = -220
	_root.offset_right = -16
	_root.offset_top = 16
	_root.offset_bottom = 240
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.85)
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	_root.add_child(bg)
	var t := Label.new()
	t.text = "Photo Mode"
	t.offset_left = 12
	t.offset_top = 8
	t.add_theme_color_override("font_color", Color(0.85, 0.74, 0.45))
	_root.add_child(t)
	_content = VBoxContainer.new()
	_content.offset_left = 12
	_content.offset_top = 36
	_content.offset_right = -12
	_content.offset_bottom = -12
	_content.anchor_right = 1
	_content.anchor_bottom = 1
	_content.add_theme_constant_override("separation", 6)
	_root.add_child(_content)
	_filter_opt = OptionButton.new()
	for f in (PhotoMode.FILTERS if PhotoMode else [&"none"]):
		_filter_opt.add_item(String(f).capitalize())
	_filter_opt.item_selected.connect(_on_filter_selected)
	_content.add_child(_filter_opt)
	_hud_chk = CheckBox.new()
	_hud_chk.text = "Show HUD"
	_hud_chk.toggled.connect(func(p: bool) -> void:
		if PhotoMode:
			PhotoMode.set_hud_visible(p)
	)
	_content.add_child(_hud_chk)
	var save_btn := Button.new()
	save_btn.text = "Capture"
	save_btn.pressed.connect(_on_capture)
	_content.add_child(save_btn)
	var close_btn := Button.new()
	close_btn.text = "Exit (F2)"
	close_btn.pressed.connect(func() -> void:
		if PhotoMode:
			PhotoMode.toggle()
	)
	_content.add_child(close_btn)


func _on_filter_selected(i: int) -> void:
	if PhotoMode == null:
		return
	var f: StringName = PhotoMode.FILTERS[clampi(i, 0, PhotoMode.FILTERS.size() - 1)]
	PhotoMode.set_filter(f)


func _on_capture() -> void:
	if PhotoMode == null:
		return
	var path: String = PhotoMode.capture_screenshot()
	if path != "":
		EventBus.ui_toast.emit("Photo saved: " + path.get_file(), 3.0)
