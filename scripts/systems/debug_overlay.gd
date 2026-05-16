extends Node

## Phase 15 — Debug overlay autoload.
## Tickets:
##   15.25 — Performance graph overlay (debug toggle)
##   15.53 — F3 debug info overlay (FPS, mem, coords, chunk id)
##   15.54 — Free-cam debug mode
##   15.55 — Wireframe / hitbox visualizer

const DEBUG_F3_KEY: int = KEY_F3
const FREE_CAM_KEY: int = KEY_F4
const WIREFRAME_KEY: int = KEY_F5
const PERF_GRAPH_KEY: int = KEY_F6

signal f3_visibility_changed(visible: bool)
signal free_cam_changed(active: bool)
signal wireframe_changed(active: bool)
signal perf_graph_changed(visible: bool)

var f3_visible: bool = false
var free_cam_active: bool = false
var wireframe_active: bool = false
var perf_graph_visible: bool = false

# Rolling 120-sample buffers for the performance graph.
var fps_samples: PackedFloat32Array = PackedFloat32Array()
var draw_call_samples: PackedFloat32Array = PackedFloat32Array()

const SAMPLE_INTERVAL_SECONDS: float = 0.25
var _accum: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)


func _process(delta: float) -> void:
	_accum += delta
	if _accum >= SAMPLE_INTERVAL_SECONDS:
		_accum = 0.0
		fps_samples.append(Engine.get_frames_per_second())
		if fps_samples.size() > 120:
			fps_samples.remove_at(0)
		draw_call_samples.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		if draw_call_samples.size() > 120:
			draw_call_samples.remove_at(0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = (event as InputEventKey).keycode
	if k == DEBUG_F3_KEY:
		toggle_f3()
	elif k == FREE_CAM_KEY:
		toggle_free_cam()
	elif k == WIREFRAME_KEY:
		toggle_wireframe()
	elif k == PERF_GRAPH_KEY:
		toggle_perf_graph()


func toggle_f3() -> bool:
	f3_visible = not f3_visible
	f3_visibility_changed.emit(f3_visible)
	return f3_visible


func toggle_free_cam() -> bool:
	free_cam_active = not free_cam_active
	free_cam_changed.emit(free_cam_active)
	return free_cam_active


func toggle_wireframe() -> bool:
	wireframe_active = not wireframe_active
	wireframe_changed.emit(wireframe_active)
	return wireframe_active


func toggle_perf_graph() -> bool:
	perf_graph_visible = not perf_graph_visible
	perf_graph_changed.emit(perf_graph_visible)
	return perf_graph_visible


func f3_report() -> String:
	var fps: float = Engine.get_frames_per_second()
	var mem_mb: float = float(Performance.get_monitor(Performance.MEMORY_STATIC)) / (1024.0 * 1024.0)
	var draw: int = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims: int = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var pos_text: String = ""
	if get_tree() and not get_tree().get_nodes_in_group("player").is_empty():
		var p := get_tree().get_nodes_in_group("player")[0] as Node2D
		var pos: Vector2 = p.global_position
		var tx: int = int(floor(pos.x / 16.0))
		var ty: int = int(floor(pos.y / 16.0))
		var cx: int = int(floor(float(tx) / 64.0))
		var cy: int = int(floor(float(ty) / 64.0))
		pos_text = "  pos %.0f,%.0f  tile %d,%d  chunk %d,%d" % [pos.x, pos.y, tx, ty, cx, cy]
	return "FPS %.0f  draws %d  prims %d  mem %.1fMB%s" % [fps, draw, prims, mem_mb, pos_text]
