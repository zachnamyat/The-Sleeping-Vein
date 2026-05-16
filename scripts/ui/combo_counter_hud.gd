extends CanvasLayer
class_name ComboCounterHUD

## Ticket 2.39 — Combo counter UI. Lives in the HUD CanvasLayer; lights up
## when the combo exceeds 5, fades out as it decays. Phase15Helpers owns the
## counter; this script just renders it.

var _label: Label
var _bar: ColorRect
var _root: Control


func _ready() -> void:
	layer = 4   # above HUD but below pause menus
	add_to_group("combo_counter")
	_build_ui()
	visible = false
	if Phase15Helpers:
		Phase15Helpers.combo_changed.connect(_on_combo_changed)


func _build_ui() -> void:
	_root = Control.new()
	_root.anchor_left = 0.5
	_root.anchor_right = 0.5
	_root.anchor_top = 0
	_root.anchor_bottom = 0
	_root.offset_left = -64
	_root.offset_right = 64
	_root.offset_top = 32
	_root.offset_bottom = 80
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.4)
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	_root.add_child(bg)
	_label = Label.new()
	_label.offset_left = 0
	_label.offset_top = 0
	_label.offset_right = 0
	_label.offset_bottom = 0
	_label.anchor_right = 1
	_label.anchor_bottom = 1
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color(0.97, 0.85, 0.4))
	_root.add_child(_label)
	_bar = ColorRect.new()
	_bar.color = Color(0.97, 0.85, 0.4, 0.6)
	_bar.anchor_left = 0
	_bar.anchor_right = 1
	_bar.anchor_top = 1
	_bar.anchor_bottom = 1
	_bar.offset_top = -3
	_root.add_child(_bar)


func _on_combo_changed(count: int) -> void:
	EventBus.phase15_combo_changed.emit(count)
	if count <= 1:
		visible = false
		return
	visible = true
	_label.text = "× %d" % count
	# Color intensifies past 10, 25, 50.
	if count >= 50:
		_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
	elif count >= 25:
		_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	elif count >= 10:
		_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	else:
		_label.add_theme_color_override("font_color", Color(0.97, 0.85, 0.4))
