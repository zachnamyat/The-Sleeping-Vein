extends CanvasLayer
class_name BandwidthMeterHUD

## Phase 15.65 — Network bandwidth meter HUD. Hidden by default; toggle via
## NetPolish.toggle_bandwidth_meter() (DevConsole command "netmeter").

var _root: Control
var _label: Label


func _ready() -> void:
	layer = 5
	add_to_group("bandwidth_meter")
	_build_ui()
	visible = false
	if NetPolish:
		NetPolish.bandwidth_sampled.connect(_on_sampled)
	set_process(true)


func _process(_delta: float) -> void:
	if NetPolish:
		visible = NetPolish.bandwidth_meter_visible


func _build_ui() -> void:
	_root = Control.new()
	_root.offset_left = 16
	_root.offset_top = 240
	_root.offset_right = 240
	_root.offset_bottom = 280
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	_root.add_child(bg)
	_label = Label.new()
	_label.offset_left = 6
	_label.offset_top = 4
	_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	_label.text = "net: idle"
	_root.add_child(_label)


func _on_sampled(b_in: int, b_out: int, p_in: int, p_out: int) -> void:
	_label.text = "net  ↓ %d B/s (%d pkt)  ↑ %d B/s (%d pkt)" % [b_in, p_in, b_out, p_out]
