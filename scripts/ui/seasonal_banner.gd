extends CanvasLayer
class_name SeasonalBanner

## Phase 15.6 / 15.58 — Seasonal banner.
## Shows a tiny banner top-center when a seasonal event is active. Click /
## interact to learn more (toast). Persistent across the active window.

var _root: Control
var _label: Label


func _ready() -> void:
	layer = 5
	add_to_group("seasonal_banner")
	_build_ui()
	visible = false
	if Phase15Helpers:
		Phase15Helpers.seasonal_event_started.connect(_on_started)
		Phase15Helpers.seasonal_event_ended.connect(_on_ended)
		# Show immediately if a seasonal event is active on load.
		for event_id in Phase15Helpers.active_seasonal_events.keys():
			if Phase15Helpers.active_seasonal_events[event_id]:
				_on_started(event_id)
				break


func _build_ui() -> void:
	_root = Control.new()
	_root.anchor_left = 0.5
	_root.anchor_right = 0.5
	_root.anchor_top = 0
	_root.anchor_bottom = 0
	_root.offset_left = -100
	_root.offset_right = 100
	_root.offset_top = 12
	_root.offset_bottom = 32
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.85, 0.74, 0.45, 0.55)
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	_root.add_child(bg)
	_label = Label.new()
	_label.anchor_right = 1
	_label.anchor_bottom = 1
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color(0.06, 0.05, 0.03))
	_root.add_child(_label)


func _on_started(event_id: StringName) -> void:
	visible = true
	_label.text = _label_for(event_id)
	EventBus.phase15_seasonal_event_started.emit(event_id)
	EventBus.ui_toast.emit("Seasonal event: %s" % _label_for(event_id), 3.5)


func _on_ended(event_id: StringName) -> void:
	visible = false
	EventBus.phase15_seasonal_event_ended.emit(event_id)


func _label_for(event_id: StringName) -> String:
	match event_id:
		&"halloween":
			return "Hollow Tide"
		&"winter":
			return "Lantern Days"
		&"anniversary":
			return "Anniversary"
	return String(event_id).capitalize()
