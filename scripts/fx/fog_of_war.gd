extends Node2D
class_name FogOfWar

## Phase 1 placeholder fog-of-war (ticket 1.13). Tracks which 32x32-tile chunks
## the player has been near and draws a dark overlay over the rest. Future
## passes will swap this for a screen-space LOS shader.

const TILE_PX: int = 16
const CHUNK_TILES: int = 32
const REVEAL_RADIUS_CHUNKS: int = 1
const DRAW_RADIUS_CHUNKS: int = 4

var _explored_chunks: Dictionary = {}
var _player: Node2D


func _ready() -> void:
	z_index = 90  # above world tiles, below HUD
	EventBus.player_spawned.connect(_on_player_spawned)
	set_process(true)


func _on_player_spawned(player: Node) -> void:
	_player = player as Node2D


func _process(_delta: float) -> void:
	if _player == null:
		return
	_mark_chunks_around_player()
	queue_redraw()


func _mark_chunks_around_player() -> void:
	var pc: Vector2i = _world_to_chunk(_player.global_position)
	for dy in range(-REVEAL_RADIUS_CHUNKS, REVEAL_RADIUS_CHUNKS + 1):
		for dx in range(-REVEAL_RADIUS_CHUNKS, REVEAL_RADIUS_CHUNKS + 1):
			_explored_chunks[pc + Vector2i(dx, dy)] = true


func _draw() -> void:
	if _player == null:
		return
	var pc: Vector2i = _world_to_chunk(_player.global_position)
	var chunk_size_px: int = CHUNK_TILES * TILE_PX
	for dy in range(-DRAW_RADIUS_CHUNKS, DRAW_RADIUS_CHUNKS + 1):
		for dx in range(-DRAW_RADIUS_CHUNKS, DRAW_RADIUS_CHUNKS + 1):
			var c := pc + Vector2i(dx, dy)
			if _explored_chunks.has(c):
				continue
			var rect_pos := Vector2(c.x * chunk_size_px, c.y * chunk_size_px)
			var rect_size := Vector2(chunk_size_px, chunk_size_px)
			draw_rect(Rect2(rect_pos, rect_size), Color(0.02, 0.02, 0.04, 0.78))


func _world_to_chunk(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / float(CHUNK_TILES * TILE_PX)), floori(p.y / float(CHUNK_TILES * TILE_PX)))


func reveal_chunk(chunk: Vector2i) -> void:
	_explored_chunks[chunk] = true
