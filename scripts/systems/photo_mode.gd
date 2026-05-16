extends Node

## Phase 15 — Photo Mode autoload.
## Ticket 15.22 — pause + free camera + filters.
##
## State and signal-only autoload; the actual visuals live in a CanvasLayer
## scene (scenes/ui/photo_mode_panel.tscn) that listens to these signals.

const FILTERS: Array[StringName] = [&"none", &"sepia", &"bw", &"aurora", &"aphelion", &"final"]
const PHOTO_DIR: String = "user://photos/"

signal photo_mode_entered()
signal photo_mode_exited()
signal photo_saved(path: String)
signal filter_changed(filter: StringName)
signal free_cam_moved(world_pos: Vector2)
signal hud_visibility_toggled(visible: bool)


var active: bool = false
var filter: StringName = &"none"
var hide_hud: bool = true
var hide_player: bool = false
var free_cam_pos: Vector2 = Vector2.ZERO
var zoom: float = 1.0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(PHOTO_DIR)


func toggle() -> bool:
	active = not active
	if Phase15Helpers:
		Phase15Helpers.photo_mode_active = active
	get_tree().paused = active
	if active:
		photo_mode_entered.emit()
	else:
		photo_mode_exited.emit()
	EventBus.phase15_photo_mode_toggled.emit(active)
	return active


func set_filter(f: StringName) -> bool:
	if f not in FILTERS:
		return false
	filter = f
	if Phase15Helpers:
		Phase15Helpers.photo_filter = f
	filter_changed.emit(f)
	return true


func set_hud_visible(visible: bool) -> void:
	hide_hud = not visible
	hud_visibility_toggled.emit(visible)


func move_free_cam(delta: Vector2) -> void:
	free_cam_pos += delta
	free_cam_moved.emit(free_cam_pos)


func set_zoom(z: float) -> void:
	zoom = clampf(z, 0.5, 4.0)


func capture_screenshot() -> String:
	var vp := get_viewport()
	if vp == null:
		return ""
	var img: Image = vp.get_texture().get_image()
	if img == null:
		return ""
	# Apply filter as a CPU pass (cheap because pixel-art is small).
	match filter:
		&"sepia":
			_apply_sepia(img)
		&"bw":
			_apply_bw(img)
		&"aurora":
			_apply_aurora(img)
		&"aphelion":
			_apply_aphelion(img)
		&"final":
			_apply_final(img)
	var ts: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path: String = PHOTO_DIR + "tsv_%s.png" % ts
	img.save_png(path)
	if Phase15Helpers:
		Phase15Helpers.photo_last_path = path
	photo_saved.emit(path)
	if AchievementsExtended:
		AchievementsExtended.note_photograph_taken()
	return path


func _apply_sepia(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in h:
		for x in w:
			var c: Color = img.get_pixel(x, y)
			var r: float = (c.r * 0.393) + (c.g * 0.769) + (c.b * 0.189)
			var g: float = (c.r * 0.349) + (c.g * 0.686) + (c.b * 0.168)
			var b: float = (c.r * 0.272) + (c.g * 0.534) + (c.b * 0.131)
			img.set_pixel(x, y, Color(clampf(r, 0, 1), clampf(g, 0, 1), clampf(b, 0, 1), c.a))


func _apply_bw(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in h:
		for x in w:
			var c: Color = img.get_pixel(x, y)
			var lum: float = (c.r * 0.299 + c.g * 0.587 + c.b * 0.114)
			img.set_pixel(x, y, Color(lum, lum, lum, c.a))


func _apply_aurora(img: Image) -> void:
	# Cool blue / green tint
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in h:
		for x in w:
			var c: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r * 0.6, c.g * 1.05, c.b * 1.15, c.a))


func _apply_aphelion(img: Image) -> void:
	# Warm gold over-tone.
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in h:
		for x in w:
			var c: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r * 1.1, c.g * 1.0, c.b * 0.7, c.a))


func _apply_final(img: Image) -> void:
	# Final-Spiral palette: high-contrast white-and-gold + black shadows.
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in h:
		for x in w:
			var c: Color = img.get_pixel(x, y)
			var lum: float = (c.r * 0.299 + c.g * 0.587 + c.b * 0.114)
			if lum > 0.6:
				img.set_pixel(x, y, Color(1.0, 0.95, 0.7, c.a))
			elif lum < 0.2:
				img.set_pixel(x, y, Color(0.04, 0.04, 0.06, c.a))
			else:
				img.set_pixel(x, y, Color(lum, lum * 0.9, lum * 0.6, c.a))
