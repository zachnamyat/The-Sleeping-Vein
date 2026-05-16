extends Node

## Phase 15 — Performance manager.
## Covers tickets 15.8 / 15.19 / 15.20 / 15.25 / 15.76-15.81 / 15.90.
##
## Owns the performance preset switching (Ultra / High / Med / Low) and the
## per-system toggles that apply when a preset is picked. Provides hooks for:
##   • LOD for off-screen entities + sprite culling (15.19)
##   • Chunk unloading + save streaming (15.20)
##   • Texture atlas batch rendering verification (15.76)
##   • Sprite frustum culling (15.77)
##   • Light culling (15.78)
##   • Mob LOD (15.79)
##   • Lazy chunk regen + memory budget per chunk (15.80)
##   • GPU profiler integration / FPS report (15.81)
##   • Performance preset for low-end hardware (15.90)
##
## All toggles persist via Settings.

const PRESETS: Array[StringName] = [&"ultra", &"high", &"medium", &"low", &"potato"]

const PRESET_DEFAULTS: Dictionary = {
	&"ultra":   { "lod_distance_chunks": 4, "max_lights": 64, "particles": 1.0, "shadow_quality": 2, "chunk_memory_mb": 96, "vsync": true },
	&"high":    { "lod_distance_chunks": 3, "max_lights": 32, "particles": 1.0, "shadow_quality": 1, "chunk_memory_mb": 64, "vsync": true },
	&"medium":  { "lod_distance_chunks": 2, "max_lights": 16, "particles": 0.6, "shadow_quality": 1, "chunk_memory_mb": 48, "vsync": true },
	&"low":     { "lod_distance_chunks": 1, "max_lights": 8,  "particles": 0.3, "shadow_quality": 0, "chunk_memory_mb": 32, "vsync": false },
	&"potato":  { "lod_distance_chunks": 1, "max_lights": 4,  "particles": 0.0, "shadow_quality": 0, "chunk_memory_mb": 24, "vsync": false },
}

signal preset_changed(preset: StringName)
signal lod_distance_changed(chunks: int)
signal light_culling_changed(max_lights: int)
signal frustum_culling_changed(active: bool)
signal mob_lod_changed(active: bool)

var preset: StringName = &"high"
var lod_distance_chunks: int = 3
var max_lights: int = 32
var particles_scale: float = 1.0
var shadow_quality: int = 1
var chunk_memory_mb: int = 64
var sprite_frustum_culling: bool = true
var mob_lod_enabled: bool = true
var light_culling_enabled: bool = true
var chunk_unload_enabled: bool = true
var texture_batching_verified: bool = false
var fps_overlay_visible: bool = false


func _ready() -> void:
	if Settings:
		var saved: String = String(Settings.get_value("perf.preset", "high"))
		apply_preset(StringName(saved))
	else:
		apply_preset(&"high")


func apply_preset(p: StringName) -> bool:
	if p not in PRESETS:
		return false
	preset = p
	var rec: Dictionary = PRESET_DEFAULTS.get(p, PRESET_DEFAULTS[&"high"])
	lod_distance_chunks = int(rec.get("lod_distance_chunks", 3))
	max_lights = int(rec.get("max_lights", 32))
	particles_scale = float(rec.get("particles", 1.0))
	shadow_quality = int(rec.get("shadow_quality", 1))
	chunk_memory_mb = int(rec.get("chunk_memory_mb", 64))
	# vsync handed off to Settings if available.
	if Settings:
		Settings.set_value("perf.preset", String(p))
		Settings.set_vsync(bool(rec.get("vsync", true)))
	preset_changed.emit(p)
	lod_distance_changed.emit(lod_distance_chunks)
	light_culling_changed.emit(max_lights)
	frustum_culling_changed.emit(sprite_frustum_culling)
	mob_lod_changed.emit(mob_lod_enabled)
	return true


# 15.76 — texture batch verification. Cheap sanity check: count distinct
# TextureRect material instances; if too many, suggest atlas building.
func verify_texture_batching() -> Dictionary:
	var report: Dictionary = {"distinct_materials": 0, "draw_calls_estimated": 0, "ok": true}
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return report
	var materials: Dictionary = {}
	for n in tree.current_scene.get_children():
		_walk_for_materials(n, materials)
	report["distinct_materials"] = materials.size()
	report["draw_calls_estimated"] = materials.size() * 2
	report["ok"] = materials.size() < 32
	texture_batching_verified = report["ok"]
	return report


func _walk_for_materials(n: Node, into: Dictionary) -> void:
	if n is CanvasItem:
		var mat: Material = (n as CanvasItem).material
		if mat != null:
			into[mat.get_instance_id()] = true
	for c in n.get_children():
		_walk_for_materials(c, into)


# 15.77 — frustum culling enable/disable. Use the viewport rect to drop
# sprites that are off-camera by N pixels.
func should_cull_sprite_at(world_pos: Vector2, camera: Camera2D, margin_px: float = 64.0) -> bool:
	if not sprite_frustum_culling or camera == null:
		return false
	var viewport_size: Vector2 = camera.get_viewport_rect().size
	var top_left: Vector2 = camera.get_screen_center_position() - viewport_size * 0.5
	var bottom_right: Vector2 = camera.get_screen_center_position() + viewport_size * 0.5
	return (
		world_pos.x < top_left.x - margin_px
		or world_pos.x > bottom_right.x + margin_px
		or world_pos.y < top_left.y - margin_px
		or world_pos.y > bottom_right.y + margin_px
	)


# 15.78 — light culling.
func should_cull_light_at(world_pos: Vector2, camera: Camera2D, radius_px: float = 96.0) -> bool:
	if not light_culling_enabled or camera == null:
		return false
	var dist: float = world_pos.distance_to(camera.get_screen_center_position())
	return dist > (lod_distance_chunks * 64.0 * 16.0) + radius_px


# 15.79 — mob LOD. Off-screen mobs should run their AI at coarser intervals.
func mob_ai_tick_divisor(world_pos: Vector2, camera: Camera2D) -> int:
	if not mob_lod_enabled or camera == null:
		return 1
	var dist: float = world_pos.distance_to(camera.get_screen_center_position())
	if dist > 1024.0:
		return 4
	if dist > 512.0:
		return 2
	return 1


# 15.20 + 15.80 — chunk-memory budget. Returns true if the manager is OK with
# loading another chunk; false signals the world should unload the furthest
# chunk first.
func can_load_more_chunks(current_count: int, avg_chunk_kb: float = 96.0) -> bool:
	var budget_kb: float = float(chunk_memory_mb) * 1024.0
	return (current_count + 1) * avg_chunk_kb <= budget_kb


# 15.81 — GPU / FPS report.
func performance_report() -> Dictionary:
	var fps: float = Engine.get_frames_per_second()
	var draw_calls: int = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives: int = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var mem_static: int = Performance.get_monitor(Performance.MEMORY_STATIC)
	return {
		"fps": fps,
		"draw_calls": draw_calls,
		"primitives": primitives,
		"memory_static_bytes": mem_static,
		"preset": String(preset),
	}


func toggle_fps_overlay() -> bool:
	fps_overlay_visible = not fps_overlay_visible
	return fps_overlay_visible
