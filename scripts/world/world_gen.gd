extends Node
class_name WorldGen

## Chunk-based procedural generator. Loads biome resources from resources/biomes/
## and paints the appropriate tiles into the three Layers (floor, wall_base, ore).
## Distance from origin (the Anchor) determines biome ring.

const CHUNK_TILES: int = 32

@export var floor_layer_path: NodePath
@export var wall_base_layer_path: NodePath
@export var wall_cap_layer_path: NodePath
@export var ore_layer_path: NodePath
@export var entity_layer_path: NodePath
@export var stone_hopper_scene: PackedScene
@export var view_chunk_radius: int = 2
@export var world_seed: int = 1337

var _biomes: Array[BiomeDef] = []
var _loaded_chunks: Dictionary = {}
var _last_player_chunk: Vector2i = Vector2i(99999, 99999)
var _player: Node2D


func _ready() -> void:
	_load_biomes()
	GameState.world_seed = world_seed if world_seed != 0 else int(Time.get_unix_time_from_system())


func set_player(player: Node2D) -> void:
	_player = player


func _process(_delta: float) -> void:
	if _player == null:
		return
	var pc: Vector2i = _world_to_chunk(_player.global_position)
	if pc == _last_player_chunk:
		return
	_last_player_chunk = pc
	_load_around(pc)


func _load_around(center: Vector2i) -> void:
	var keep := {}
	for dy in range(-view_chunk_radius, view_chunk_radius + 1):
		for dx in range(-view_chunk_radius, view_chunk_radius + 1):
			var c := center + Vector2i(dx, dy)
			keep[c] = true
			if not _loaded_chunks.has(c):
				_generate_chunk(c)
				_loaded_chunks[c] = true
	for c in _loaded_chunks.keys():
		if not keep.has(c):
			_unload_chunk(c)
			_loaded_chunks.erase(c)


func _generate_chunk(chunk: Vector2i) -> void:
	var biome: BiomeDef = _pick_biome_for_chunk(chunk)
	if biome == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash_chunk(chunk)
	var fl := _layer(floor_layer_path)
	var wb := _layer(wall_base_layer_path)
	var wc := _layer(wall_cap_layer_path)
	var ol := _layer(ore_layer_path)
	if fl == null:
		return
	# Floor: paint all tiles
	for ty in range(CHUNK_TILES):
		for tx in range(CHUNK_TILES):
			var coord := chunk * CHUNK_TILES + Vector2i(tx, ty)
			fl.set_cell(coord, biome.floor_source_id, Vector2i(0, 0), 0)
	# Walls and ore: scattered via Poisson-ish sampling
	for _i in range(biome.wall_density_per_chunk):
		var tx2: int = rng.randi_range(0, CHUNK_TILES - 1)
		var ty2: int = rng.randi_range(0, CHUNK_TILES - 1)
		var coord := chunk * CHUNK_TILES + Vector2i(tx2, ty2)
		# Don't place walls too close to world origin (Anchor) so the player has a clear plateau.
		if coord.length() < 7.0:
			continue
		if wb:
			wb.set_cell(coord, biome.wall_source_id, Vector2i(0, 0), 0)
		if wc:
			wc.set_cell(coord + Vector2i(0, -1), biome.wall_source_id, Vector2i(0, 0), 0)
	for _i in range(biome.ore_density_per_chunk):
		var ox: int = rng.randi_range(0, CHUNK_TILES - 1)
		var oy: int = rng.randi_range(0, CHUNK_TILES - 1)
		var coord := chunk * CHUNK_TILES + Vector2i(ox, oy)
		if coord.length() < 7.0:
			continue
		if ol:
			ol.set_cell(coord, biome.ore_source_id, Vector2i(0, 0), 0)
	# Mobs
	if stone_hopper_scene and biome.mobs_per_chunk > 0 and not biome.mob_spawn_table.is_empty():
		var entities := _layer_node(entity_layer_path) as Node2D
		if entities:
			for _i in range(biome.mobs_per_chunk):
				var sx: int = rng.randi_range(2, CHUNK_TILES - 3)
				var sy: int = rng.randi_range(2, CHUNK_TILES - 3)
				var coord := chunk * CHUNK_TILES + Vector2i(sx, sy)
				if coord.length() < 14.0:
					continue
				var mob := stone_hopper_scene.instantiate() as Node2D
				mob.position = Vector2(coord.x * 16 + 8, coord.y * 16 + 8)
				entities.add_child(mob)


func _unload_chunk(chunk: Vector2i) -> void:
	# Phase 4 keeps chunks resident. Phase 4.x can prune for memory.
	pass


func _pick_biome_for_chunk(chunk: Vector2i) -> BiomeDef:
	if _biomes.is_empty():
		return null
	var center_tile_pos := Vector2(chunk.x * CHUNK_TILES + CHUNK_TILES * 0.5, chunk.y * CHUNK_TILES + CHUNK_TILES * 0.5)
	var radius: float = center_tile_pos.length()
	for biome in _biomes:
		var inner: float = biome.distance_from_anchor_tiles
		var outer: float = inner + biome.ring_thickness_tiles
		if radius >= inner and radius < outer:
			return biome
	return _biomes[0]


func _load_biomes() -> void:
	var dir := DirAccess.open("res://resources/biomes/")
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.ends_with(".tres"):
			var res := load("res://resources/biomes/" + entry) as BiomeDef
			if res != null:
				_biomes.append(res)
		entry = dir.get_next()
	dir.list_dir_end()
	_biomes.sort_custom(func(a: BiomeDef, b: BiomeDef) -> bool: return a.distance_from_anchor_tiles < b.distance_from_anchor_tiles)


func _world_to_chunk(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / 16.0 / float(CHUNK_TILES)), floori(world_pos.y / 16.0 / float(CHUNK_TILES)))


func _hash_chunk(chunk: Vector2i) -> int:
	return chunk.x * 73856093 ^ chunk.y * 19349663 ^ GameState.world_seed


func _layer(path: NodePath) -> TileMapLayer:
	return _layer_node(path) as TileMapLayer


func _layer_node(path: NodePath) -> Node:
	if path == NodePath():
		return null
	return get_node_or_null(path)


func biome_at(world_pos: Vector2) -> BiomeDef:
	var chunk := _world_to_chunk(world_pos)
	return _pick_biome_for_chunk(chunk)
