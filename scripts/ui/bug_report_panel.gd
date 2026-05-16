extends CanvasLayer
class_name BugReportPanel

## Phase 15.83 — Bug-report in-game form.
## Triggered from the pause menu (or via DevConsole bug command). Writes to
## user://bug_reports/.

var _root: Control
var _description: TextEdit
var _with_screenshot: CheckBox


func _ready() -> void:
	layer = 50
	add_to_group("bug_report_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func toggle() -> void:
	visible = not visible


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
	bg.color = Color(0.04, 0.04, 0.06, 0.96)
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	_root.add_child(bg)
	var t := Label.new()
	t.text = "Send Bug Report"
	t.offset_left = 16
	t.offset_top = 8
	t.add_theme_color_override("font_color", Color(0.85, 0.74, 0.45))
	_root.add_child(t)
	var v := VBoxContainer.new()
	v.offset_left = 16
	v.offset_top = 40
	v.offset_right = -16
	v.offset_bottom = -16
	v.anchor_right = 1
	v.anchor_bottom = 1
	v.add_theme_constant_override("separation", 8)
	_root.add_child(v)
	var prompt := Label.new()
	prompt.text = "Describe what happened (no PII please):"
	prompt.modulate = Color(0.92, 0.88, 0.74)
	v.add_child(prompt)
	_description = TextEdit.new()
	_description.custom_minimum_size = Vector2(0, 200)
	_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_description)
	_with_screenshot = CheckBox.new()
	_with_screenshot.text = "Include screenshot"
	_with_screenshot.button_pressed = true
	v.add_child(_with_screenshot)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	v.add_child(btns)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func() -> void: visible = false)
	btns.add_child(cancel)
	var send := Button.new()
	send.text = "Save report"
	send.pressed.connect(_on_send)
	btns.add_child(send)


func _on_send() -> void:
	if CrashReporter == null:
		return
	var text: String = _description.text.strip_edges()
	if text == "":
		EventBus.ui_toast.emit("Please describe the issue.", 2.0)
		return
	var path: String = CrashReporter.file_bug_report(text, _with_screenshot.button_pressed)
	if path != "":
		EventBus.ui_toast.emit("Bug report saved: " + path.get_file(), 3.0)
		_description.text = ""
		visible = false
