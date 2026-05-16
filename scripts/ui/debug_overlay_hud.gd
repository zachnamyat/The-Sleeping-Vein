extends CanvasLayer
class_name DebugOverlayHUD

## Phase 15 — F3 / F6 debug overlay HUD.
## Renders the live debug stats coming from DebugOverlay autoload.

var _root: Control
var _label: Label
var _perf_panel: Control
var _perf_draw: Control


func _ready() -> void:
	layer = 80
	add_to_group("debug_overlay_hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	set_process(true)
	if DebugOverlay:
		DebugOverlay.f3_visibility_changed.connect(_on_f3_toggled)
		DebugOverlay.perf_graph_changed.connect(_on_perf_toggled)


func _process(_delta: float) -> void:
	if DebugOverlay == null:
		return
	if DebugOverlay.f3_visible:
		_label.text = DebugOverlay.f3_report()
	if DebugOverlay.perf_graph_visible and _perf_draw:
		_perf_draw.queue_redraw()


func _on_f3_toggled(vis: bool) -> void:
	_label.visible = vis
	visible = vis or (DebugOverlay and DebugOverlay.perf_graph_visible)


func _on_perf_toggled(vis: bool) -> void:
	_perf_panel.visible = vis
	visible = vis or (DebugOverlay and DebugOverlay.f3_visible)


func _build_ui() -> void:
	_root = Control.new()
	_root.anchor_right = 1
	_root.anchor_bottom = 1
	add_child(_root)
	_label = Label.new()
	_label.offset_left = 8
	_label.offset_top = 8
	_label.add_theme_color_override("font_color", Color(0.97, 0.85, 0.45))
	_label.visible = false
	_root.add_child(_label)
	# Perf graph panel.
	_perf_panel = Control.new()
	_perf_panel.offset_left = -240
	_perf_panel.offset_top = -100
	_perf_panel.offset_right = -8
	_perf_panel.offset_bottom = -8
	_perf_panel.anchor_left = 1
	_perf_panel.anchor_right = 1
	_perf_panel.anchor_top = 1
	_perf_panel.anchor_bottom = 1
	_perf_panel.visible = false
	_root.add_child(_perf_panel)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	_perf_panel.add_child(bg)
	_perf_draw = Control.new()
	_perf_draw.anchor_right = 1
	_perf_draw.anchor_bottom = 1
	_perf_panel.add_child(_perf_draw)
	_perf_draw.draw.connect(_draw_perf_graph)


func _draw_perf_graph() -> void:
	if DebugOverlay == null:
		return
	var rect: Rect2 = _perf_draw.get_rect()
	var w: float = rect.size.x
	var h: float = rect.size.y
	var samples: PackedFloat32Array = DebugOverlay.fps_samples
	if samples.is_empty():
		return
	var max_fps: float = 144.0
	var step_x: float = w / float(max(1, samples.size()))
	var prev: Vector2 = Vector2(0, h - (samples[0] / max_fps) * h)
	for i in range(1, samples.size()):
		var cur: Vector2 = Vector2(step_x * float(i), h - (samples[i] / max_fps) * h)
		_perf_draw.draw_line(prev, cur, Color(0.4, 1.0, 0.4, 0.9), 1.0)
		prev = cur
	# 60 + 30 baselines.
	var y60: float = h - (60.0 / max_fps) * h
	_perf_draw.draw_line(Vector2(0, y60), Vector2(w, y60), Color(0.7, 0.7, 0.3, 0.5), 1.0)
	var y30: float = h - (30.0 / max_fps) * h
	_perf_draw.draw_line(Vector2(0, y30), Vector2(w, y30), Color(1.0, 0.4, 0.3, 0.5), 1.0)
