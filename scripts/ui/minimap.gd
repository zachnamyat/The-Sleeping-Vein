extends Control
class_name Minimap

## Top-down minimap. Paints explored chunks (per WorldGen chunk = 32 tiles) as
## faint biome-colored dots. Player as a bright gold dot at center. Each minimap
## pixel covers `tiles_per_minimap_pixel` world tiles.

@export var pixel_size: int = 96
@export var world_path: NodePath
@export var tiles_per_minimap_pixel: int = 8

@onready var player_dot: ColorRect = $Border/PlayerDot

var _explored_chunks: Dictionary = {}   ## Vector2i chunk_coord -> Color (biome accent)
var _player: Node2D
var _world_gen: Node
var _last_player_chunk: Vector2i = Vector2i(99999, 99999)

const CHUNK_TILES: int = 32  ## Must match WorldGen.CHUNK_TILES


func _ready() -> void:
	custom_minimum_size = Vector2(pixel_size, pixel_size)
	for player in get_tree().get_nodes_in_group("player"):
		_player = player
		break
	if has_node(world_path):
		_world_gen = get_node(world_path)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		for p in get_tree().get_nodes_in_group("player"):
			_player = p
			break
	if _player == null:
		return
	# Update explored chunk under player.
	var pc: Vector2i = Vector2i(
		floori(_player.global_position.x / 16.0 / float(CHUNK_TILES)),
		floori(_player.global_position.y / 16.0 / float(CHUNK_TILES)),
	)
	if pc != _last_player_chunk:
		_last_player_chunk = pc
		_mark_explored(pc)
		# Mark a small radius around the player for nicer reveal feel.
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				_mark_explored(pc + Vector2i(dx, dy))
		queue_redraw()
	# Player dot at minimap center always (it's relative to player).
	player_dot.position = Vector2(pixel_size / 2 - 1, pixel_size / 2 - 1)


func _mark_explored(chunk: Vector2i) -> void:
	if _explored_chunks.has(chunk):
		return
	var color := Color(0.6, 0.5, 0.35, 0.7)  ## default Root Hollows
	if _world_gen and _world_gen.has_method("biome_at"):
		# Center of the chunk in world coords:
		var world_pos: Vector2 = Vector2(chunk * CHUNK_TILES + Vector2i(CHUNK_TILES / 2, CHUNK_TILES / 2)) * 16.0
		var biome: BiomeDef = _world_gen.biome_at(world_pos) as BiomeDef
		if biome:
			color = biome.ambient_high_color
			color.a = 0.85
	_explored_chunks[chunk] = color


func _draw() -> void:
	if _player == null:
		return
	# Each chunk = CHUNK_TILES (32) tiles = 32 * tile-size. On the minimap, that's
	# 32 / tiles_per_minimap_pixel = 32/8 = 4 minimap pixels per chunk.
	var chunk_px: int = max(1, CHUNK_TILES / tiles_per_minimap_pixel)
	var player_chunk: Vector2i = Vector2i(
		floori(_player.global_position.x / 16.0 / float(CHUNK_TILES)),
		floori(_player.global_position.y / 16.0 / float(CHUNK_TILES)),
	)
	for chunk in _explored_chunks.keys():
		var delta: Vector2i = chunk - player_chunk
		var px: int = pixel_size / 2 + delta.x * chunk_px - chunk_px / 2
		var py: int = pixel_size / 2 + delta.y * chunk_px - chunk_px / 2
		if px < 0 or py < 0 or px + chunk_px > pixel_size or py + chunk_px > pixel_size:
			continue
		draw_rect(Rect2(Vector2(px, py), Vector2(chunk_px, chunk_px)), _explored_chunks[chunk], true)
