extends Control
class_name Minimap

## Phase 4.10 — chunk-revealed top-down map. Paints explored chunks (one
## WorldGen chunk = CHUNK_TILES tiles per side) as faint biome-colored dots.
## Player as a bright gold dot at center; the Loom (world origin / current
## respawn point) as a small azure dot so the player can sight-line their way
## back.
##
## Pressing the `open_map` action (default M) toggles between the corner widget
## and a full-screen overlay (4× scale, centered, dimmed backdrop).
##
## Reveal state lives in GameState.explored_chunks so it persists across
## save/load. WorldGen marks visited chunks as the player moves; this widget
## just reads what's already been recorded.
##
## CHUNK_TILES must match WorldGen.CHUNK_TILES.

@export var pixel_size: int = 96
@export var world_path: NodePath
@export var tiles_per_minimap_pixel: int = 16
@export var fullscreen_pixel_size: int = 240

@onready var player_dot: ColorRect = $Border/PlayerDot
@onready var border: ColorRect = $Border
@onready var bg: ColorRect = $Border/BG

var _explored_chunks: Dictionary = {}   ## Vector2i chunk_coord -> Color (biome accent)
var _player: Node2D
var _world_gen: Node
var _last_player_chunk: Vector2i = Vector2i(99999, 99999)
var _fullscreen: bool = false
var _saved_anchors: Dictionary = {}
var _backdrop: ColorRect = null
var _respawn_point: Vector2 = Vector2.ZERO
## Phase 4.19 — user-placeable markers. Stored as world-space Vector2 with a
## label + color. Tombstones (4.62) and treasure-map pings (4.30) also push
## into this list; the minimap dedupes by label within MARKER_DEDUPE_PX so the
## map doesn't fill with stale duplicates when the player walks past a chest.
var _markers: Array[Dictionary] = []
const MARKER_DEDUPE_PX: float = 24.0
const MAX_MARKERS: int = 32
## Phase 4.39 — compass-to-death toggle. The HUD compass widget reads this so
## it can swap its target.
var death_compass_active: bool = false

const CHUNK_TILES: int = 64
const TILE_PX: int = 16


func _ready() -> void:
	add_to_group("minimap")
	custom_minimum_size = Vector2(pixel_size, pixel_size)
	for player in get_tree().get_nodes_in_group("player"):
		_player = player
		break
	if has_node(world_path):
		_world_gen = get_node(world_path)
	# Phase 4.10 — hydrate cached colors from GameState explored chunks. The
	# biome lookup needs the worldgen to be ready, so we defer one frame.
	call_deferred("_hydrate_from_save")
	# Phase 4.5 — track respawn point so we can render a "home" pip.
	EventBus.respawn_point_set.connect(_on_respawn_point_set)
	_respawn_point = GameState.respawn_point
	# Chunks visited as the player walks; biome color resolved once on entry.
	EventBus.chunk_visited.connect(_on_chunk_visited)


## Phase 4.19 — public API for placing a labelled marker. World-position; the
## minimap converts to local on draw. Dedupes against any existing marker with
## the same label within MARKER_DEDUPE_PX so repeat pings don't pile up.
func add_marker(world_pos: Vector2, label: String, color: Color = Color(1, 1, 1, 1)) -> void:
	for i in range(_markers.size() - 1, -1, -1):
		var m: Dictionary = _markers[i]
		if String(m.get("label", "")) == label and Vector2(m.get("pos", Vector2.ZERO)).distance_to(world_pos) < MARKER_DEDUPE_PX:
			_markers.remove_at(i)
	_markers.append({"pos": world_pos, "label": label, "color": color})
	while _markers.size() > MAX_MARKERS:
		_markers.remove_at(0)
	queue_redraw()


## Phase 4.39 — toggle the compass widget between Loom and last-death modes.
## The compass script polls this; the minimap is the single source of truth
## because both readouts share the marker dataset.
func toggle_death_compass() -> void:
	death_compass_active = not death_compass_active
	var msg: String = "Compass: Death" if death_compass_active else "Compass: Loom"
	EventBus.ui_toast.emit(msg, 1.5)


## Returns the world-position of the most recent Tombstone marker, or ZERO if
## none exists.
func last_death_marker() -> Vector2:
	for i in range(_markers.size() - 1, -1, -1):
		var m: Dictionary = _markers[i]
		if String(m.get("label", "")) == "Tombstone":
			return Vector2(m.get("pos", Vector2.ZERO))
	return Vector2.ZERO


func _hydrate_from_save() -> void:
	for key in GameState.explored_chunks.keys():
		var parts: PackedStringArray = String(key).split(",")
		if parts.size() != 2:
			continue
		var chunk := Vector2i(int(parts[0]), int(parts[1]))
		_resolve_chunk_color(chunk)
	queue_redraw()


func _resolve_chunk_color(chunk: Vector2i) -> void:
	if _explored_chunks.has(chunk):
		return
	var color := Color(0.6, 0.5, 0.35, 0.85)
	if _world_gen and _world_gen.has_method("biome_for_chunk"):
		var biome: BiomeDef = _world_gen.call("biome_for_chunk", chunk) as BiomeDef
		if biome:
			color = biome.ambient_high_color
			color.a = 0.85
	_explored_chunks[chunk] = color


func _on_chunk_visited(chunk_coord: Vector2i, _biome_id: StringName) -> void:
	_resolve_chunk_color(chunk_coord)
	queue_redraw()


func _on_respawn_point_set(world_pos: Vector2) -> void:
	_respawn_point = world_pos
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_map"):
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()


func _toggle_fullscreen() -> void:
	_fullscreen = not _fullscreen
	if _fullscreen:
		_saved_anchors = {
			"al": anchor_left, "ar": anchor_right, "at": anchor_top, "ab": anchor_bottom,
			"ol": offset_left, "or": offset_right, "ot": offset_top, "ob": offset_bottom,
			"ps": pixel_size, "tpp": tiles_per_minimap_pixel,
		}
		var size: int = fullscreen_pixel_size
		anchor_left = 0.5
		anchor_right = 0.5
		anchor_top = 0.5
		anchor_bottom = 0.5
		offset_left = -size / 2
		offset_right = size / 2
		offset_top = -size / 2
		offset_bottom = size / 2
		pixel_size = size
		tiles_per_minimap_pixel = max(2, _saved_anchors["tpp"] / 2)
		_resize_children(size)
		_show_backdrop()
	else:
		anchor_left = _saved_anchors["al"]
		anchor_right = _saved_anchors["ar"]
		anchor_top = _saved_anchors["at"]
		anchor_bottom = _saved_anchors["ab"]
		offset_left = _saved_anchors["ol"]
		offset_right = _saved_anchors["or"]
		offset_top = _saved_anchors["ot"]
		offset_bottom = _saved_anchors["ob"]
		pixel_size = _saved_anchors["ps"]
		tiles_per_minimap_pixel = _saved_anchors["tpp"]
		_resize_children(pixel_size)
		_hide_backdrop()
	custom_minimum_size = Vector2(pixel_size, pixel_size)
	queue_redraw()


func _resize_children(size: int) -> void:
	if border:
		border.size = Vector2(size, size)
	if bg:
		bg.position = Vector2(1, 1)
		bg.size = Vector2(size - 2, size - 2)


func _show_backdrop() -> void:
	if _backdrop != null and is_instance_valid(_backdrop):
		_backdrop.visible = true
		return
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.55)
	_backdrop.anchor_right = 1.0
	_backdrop.anchor_bottom = 1.0
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.z_index = -1
	add_sibling(_backdrop)
	move_to_front()


func _hide_backdrop() -> void:
	if _backdrop != null and is_instance_valid(_backdrop):
		_backdrop.visible = false


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		for p in get_tree().get_nodes_in_group("player"):
			_player = p
			break
	if _player == null:
		return
	var pc: Vector2i = _player_chunk()
	if pc != _last_player_chunk:
		_last_player_chunk = pc
		queue_redraw()
	player_dot.position = Vector2(pixel_size / 2 - 1, pixel_size / 2 - 1)


func _player_chunk() -> Vector2i:
	return Vector2i(
		floori(_player.global_position.x / float(TILE_PX) / float(CHUNK_TILES)),
		floori(_player.global_position.y / float(TILE_PX) / float(CHUNK_TILES)),
	)


func _draw() -> void:
	if _player == null:
		return
	var chunk_px: int = max(1, CHUNK_TILES / tiles_per_minimap_pixel)
	var player_chunk: Vector2i = _player_chunk()
	for chunk in _explored_chunks.keys():
		var delta: Vector2i = chunk - player_chunk
		var px: int = pixel_size / 2 + delta.x * chunk_px - chunk_px / 2
		var py: int = pixel_size / 2 + delta.y * chunk_px - chunk_px / 2
		if px < -chunk_px or py < -chunk_px or px > pixel_size or py > pixel_size:
			continue
		draw_rect(Rect2(Vector2(px, py), Vector2(chunk_px, chunk_px)), _explored_chunks[chunk], true)
	# Phase 4.5 — respawn pip. World-pos -> chunk -> minimap delta.
	var respawn_chunk: Vector2i = Vector2i(
		floori(_respawn_point.x / float(TILE_PX) / float(CHUNK_TILES)),
		floori(_respawn_point.y / float(TILE_PX) / float(CHUNK_TILES)),
	)
	var rd: Vector2i = respawn_chunk - player_chunk
	var rpx: int = pixel_size / 2 + rd.x * chunk_px - 1
	var rpy: int = pixel_size / 2 + rd.y * chunk_px - 1
	if rpx >= 0 and rpx <= pixel_size - 2 and rpy >= 0 and rpy <= pixel_size - 2:
		draw_rect(Rect2(Vector2(rpx, rpy), Vector2(3, 3)), Color(0.55, 0.85, 1.0, 0.95), true)
	# Phase 4.19 — draw user markers (tombstones, treasure pings, manual pins).
	# Render as a small triangle so they don't get confused with the respawn pip.
	for m in _markers:
		var mpos: Vector2 = Vector2(m.get("pos", Vector2.ZERO))
		var mchunk: Vector2i = Vector2i(
			floori(mpos.x / float(TILE_PX) / float(CHUNK_TILES)),
			floori(mpos.y / float(TILE_PX) / float(CHUNK_TILES)),
		)
		var md: Vector2i = mchunk - player_chunk
		var mpx: int = pixel_size / 2 + md.x * chunk_px
		var mpy: int = pixel_size / 2 + md.y * chunk_px
		if mpx < 0 or mpy < 0 or mpx > pixel_size or mpy > pixel_size:
			continue
		var color: Color = m.get("color", Color.WHITE) as Color
		var tri := PackedVector2Array([
			Vector2(mpx, mpy - 3),
			Vector2(mpx - 3, mpy + 2),
			Vector2(mpx + 3, mpy + 2),
		])
		draw_polygon(tri, PackedColorArray([color, color, color]))
