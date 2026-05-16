extends CanvasLayer
class_name SpeedrunTimerHUD

## Phase 15.28 — Speedrun timer HUD.
## Hidden by default; visible while Phase15Helpers.speedrun_active is true.

var _root: Control
var _timer_label: Label
var _splits_list: VBoxContainer


func _ready() -> void:
	layer = 5
	add_to_group("speedrun_timer")
	_build_ui()
	visible = false
	set_process(true)
	if Phase15Helpers:
		Phase15Helpers.speedrun_started.connect(_on_started)
		Phase15Helpers.speedrun_finished.connect(_on_finished)
		Phase15Helpers.speedrun_split_added.connect(_on_split)


func _process(_delta: float) -> void:
	if Phase15Helpers == null or not Phase15Helpers.speedrun_active:
		return
	var s: float = Phase15Helpers.speedrun_elapsed_seconds()
	_timer_label.text = _format_time(s)


func _on_started() -> void:
	visible = true
	for c in _splits_list.get_children():
		c.queue_free()


func _on_finished(total: float) -> void:
	EventBus.ui_toast.emit("Speedrun: %s" % _format_time(total), 4.0)


func _on_split(_idx: int, total: float, label: String) -> void:
	var l := Label.new()
	l.text = "%s  %s" % [_format_time(total), label]
	l.modulate = Color(0.97, 0.85, 0.5)
	_splits_list.add_child(l)


func _build_ui() -> void:
	_root = Control.new()
	_root.offset_left = 16
	_root.offset_top = 16
	_root.offset_right = 200
	_root.offset_bottom = 220
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	_root.add_child(bg)
	_timer_label = Label.new()
	_timer_label.offset_left = 8
	_timer_label.offset_top = 6
	_timer_label.add_theme_font_size_override("font_size", 18)
	_timer_label.add_theme_color_override("font_color", Color(0.97, 0.85, 0.45))
	_timer_label.text = "00:00.000"
	_root.add_child(_timer_label)
	_splits_list = VBoxContainer.new()
	_splits_list.offset_left = 8
	_splits_list.offset_top = 32
	_splits_list.offset_right = -8
	_splits_list.anchor_right = 1
	_root.add_child(_splits_list)


func _format_time(seconds: float) -> String:
	var h: int = int(seconds) / 3600
	var m: int = (int(seconds) / 60) % 60
	var s_int: int = int(seconds) % 60
	var ms: int = int((seconds - floor(seconds)) * 1000.0)
	if h > 0:
		return "%d:%02d:%02d.%03d" % [h, m, s_int, ms]
	return "%02d:%02d.%03d" % [m, s_int, ms]
