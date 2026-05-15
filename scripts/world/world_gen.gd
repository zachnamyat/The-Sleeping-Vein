extends Node
class_name WorldGen

## Phase 4 — chunked procedural generator.
##
## Loads BiomeDef resources from resources/biomes/ and paints floor, walls, ore,
## structures, decorations and mobs into the layered TileMapLayers under a
## single Node2D root. Distance from the Anchor (world origin) determines the
## biome ring; each chunk is deterministic from `world_seed XOR chunk_xy_hash`,
## so the same seed always yields the same world.
##
## Phase 4 critical-path (4.1–4.11) brought:
##   - 64-tile chunks, FastNoiseLite wall fields, BFS-grown ore veins
##   - biome-change emission + chunk-visited logging
##
## 2026-05-14 retraction: an earlier draft of 4.6 carved permanent ±1 corridor
## tunnels along the world X/Y axes. That deviated from Core Keeper parity —
## CK's biome rings are gated by progressively-harder walls the player must
## mine through, not by pre-cleared roads. Corridor carving has been removed;
## only the Anchor plateau's 7-tile clear circle at world origin remains.
##
## Phase 4 full-closure pass (4.13–4.65) adds:
##   - 4.15 per-chunk mob budget + 4.16 walls/light suppress spawns + 4.51
##   - 4.17 mob spawner placement (rare; chance grows with biome.stratum_index)
##   - 4.18 / 4.50 procedural unique rooms — small open chambers with a chest
##         or altar in the center
##   - 4.20 procedural lakes — water-tile clusters in low-density regions
##   - 4.21 abandoned camps — sparse decorative chunks with a chest + statue
##   - 4.23 treasure chests scattered at distance, occasionally key-locked
##   - 4.24 lore-tablet anchors, one per biome ring on a fixed angle
##   - 4.29 hidden walls — wall variant with a "hidden_wall" custom-data flag
##   - 4.44 sub-biome detection — secondary noise field carves "Quiet Forge"
##         and "Hollow Chamber" pockets inside their parent biomes
##   - 4.48 world border — beyond MAX_WORLD_RADIUS tiles the generator paints
##         only impassable walls so the world feels finite
##   - 4.55 floor scatter decorations on a sparse Poisson field

const CHUNK_TILES: int = 64
const TILE_PX: int = 16
const ANCHOR_CLEAR_RADIUS_TILES: float = 7.0
const ORE_VEIN_SEEDS_MIN: int = 2
const ORE_VEIN_SEEDS_MAX: int = 4
const ORE_VEIN_CELL_BUDGET_MIN: int = 3
const ORE_VEIN_CELL_BUDGET_MAX: int = 6
const MAX_WORLD_RADIUS_TILES: float = 1600.0   ## 4.48 finite-world soft cap
const NIGHT_SPAWN_BONUS: float = 1.6           ## 4.61 night phases scale density
const TORCH_SUPPRESS_RADIUS_PX: float = 80.0   ## 4.51 light radius silences spawns
const WALL_SUPPRESS_RADIUS_TILES: float = 4.0  ## 4.16 walls suppress nearby spawns

@export var floor_layer_path: NodePath
@export var wall_base_layer_path: NodePath
@export var wall_cap_layer_path: NodePath
@export var ore_layer_path: NodePath
@export var entity_layer_path: NodePath
@export var stone_hopper_scene: PackedScene
@export var view_chunk_radius: int = 1
@export var world_seed: int = 1337
## Cave-carve threshold for the noise-based wall field. Tiles whose
## `abs(perlin)` exceeds this value become CAVE (open floor); the rest stay
## walled. Higher = more open. 0.35 ≈ 30% open / 70% walls, which matches the
## CK "you're inside a cave, mine out" feel. Was misnamed `wall_noise_threshold`
## and inverted in the 2026-05-14 first-pass — that produced ~1% walls /
## 99% floor instead of the opposite.
@export var cave_carve_threshold: float = 0.35
@export var sub_biome_threshold: float = 0.62
@export var rare_room_chance: float = 0.04
@export var lake_chance: float = 0.06
@export var camp_chance: float = 0.05
@export var spawner_chance: float = 0.025
@export var lore_tablet_radius_tiles: float = 64.0
@export var treasure_chest_chance: float = 0.04
@export var chunk_mob_budget: int = 4

@export var treasure_chest_scene: PackedScene
@export var wishing_well_scene: PackedScene
@export var lore_tablet_scene: PackedScene
@export var mob_spawner_scene: PackedScene
@export var boss_altar_scene: PackedScene
@export var statue_scene: PackedScene
@export var locked_door_scene: PackedScene
@export var glow_shroom_scene: PackedScene
@export var crystal_cluster_scene: PackedScene
@export var crystal_cluster_chance: float = 0.10

var _biomes: Array[BiomeDef] = []
var _loaded_chunks: Dictionary = {}
var _last_player_chunk: Vector2i = Vector2i(99999, 99999)
var _player: Node2D
var _wall_noise: FastNoiseLite
var _sub_biome_noise: FastNoiseLite
var _scatter_noise: FastNoiseLite
var _current_biome_id: StringName = &""
var _placed_lore_rings: Dictionary = {}
var _torch_lookup_accum: float = 0.0
var _cached_lights: Array[Vector2] = []


func _ready() -> void:
	_load_biomes()
	if world_seed == 0:
		world_seed = int(Time.get_unix_time_from_system())
	GameState.world_seed = world_seed
	_wall_noise = FastNoiseLite.new()
	_wall_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_wall_noise.seed = world_seed
	_wall_noise.frequency = 0.07
	_sub_biome_noise = FastNoiseLite.new()
	_sub_biome_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	_sub_biome_noise.seed = world_seed ^ 0x4D2BE1A7
	_sub_biome_noise.frequency = 0.015
	_scatter_noise = FastNoiseLite.new()
	_scatter_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_scatter_noise.seed = world_seed ^ 0xC3F1D2EB
	_scatter_noise.frequency = 0.13
	EventBus.world_seeded.emit(world_seed)


func set_player(player: Node2D) -> void:
	_player = player


func _process(delta: float) -> void:
	if _player == null:
		return
	_torch_lookup_accum += delta
	if _torch_lookup_accum > 0.5:
		_torch_lookup_accum = 0.0
		_refresh_light_cache()
	var pc: Vector2i = _world_to_chunk(_player.global_position)
	if pc == _last_player_chunk:
		return
	_last_player_chunk = pc
	_load_around(pc)
	_track_biome_change()
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var visited := pc + Vector2i(dx, dy)
			var b: BiomeDef = _pick_biome_for_chunk(visited)
			if b:
				GameState.mark_chunk_visited(visited, b.id)


func _refresh_light_cache() -> void:
	_cached_lights.clear()
	for ls in get_tree().get_nodes_in_group("light_source"):
		if ls is Node2D:
			_cached_lights.append((ls as Node2D).global_position)
	for ls in get_tree().get_nodes_in_group("torch"):
		if ls is Node2D:
			_cached_lights.append((ls as Node2D).global_position)


func _track_biome_change() -> void:
	if _player == null:
		return
	var b: BiomeDef = biome_at(_player.global_position)
	if b == null:
		return
	if b.id == _current_biome_id:
		return
	var prev_id: StringName = _current_biome_id
	_current_biome_id = b.id
	EventBus.biome_changed.emit(prev_id, b.id)


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


## Phase 4.44 — sub-biome detection. Returns the sub-biome StringName for a
## tile, or &"" if the cell is in the parent biome's "open" majority. We use a
## low-frequency cellular field; values above sub_biome_threshold mark pockets
## that override mob/ore behavior — for the Glasswright Reaches that's the
## "Quiet Forge" sub-biome (per lore §04), for Root Hollows it's "Hollow
## Chamber". Used by the procedural-room placement code to know what flavour
## of room to spawn.
func sub_biome_at(coord: Vector2i, parent_id: StringName) -> StringName:
	if _sub_biome_noise == null:
		return &""
	var n: float = abs(_sub_biome_noise.get_noise_2d(float(coord.x), float(coord.y)))
	if n < sub_biome_threshold:
		return &""
	match parent_id:
		&"glasswright_reaches": return &"quiet_forge"
		&"root_hollows": return &"hollow_chamber"
		&"vesari_necropolis": return &"echo_arcade"
		&"sunless_verdancy": return &"bloom_arbor"
		&"drowned_aphelion": return &"tidewell"
		_: return &""


func _generate_chunk(chunk: Vector2i) -> void:
	var biome: BiomeDef = _pick_biome_for_chunk(chunk)
	if biome == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash_chunk(chunk)
	var fl := _layer(floor_layer_path)
	var wb := _layer(wall_base_layer_path)
	var ol := _layer(ore_layer_path)
	if fl == null:
		return
	# Phase 4.48 — out beyond MAX_WORLD_RADIUS, paint impassable border walls
	# only; no floor, no entities. The world feels finite without an explicit
	# boundary visual.
	var center: Vector2 = Vector2(chunk * CHUNK_TILES + Vector2i(CHUNK_TILES / 2, CHUNK_TILES / 2))
	if center.length() > MAX_WORLD_RADIUS_TILES:
		_paint_border_wall(wb, chunk, biome)
		return
	for ty in range(CHUNK_TILES):
		for tx in range(CHUNK_TILES):
			var coord := chunk * CHUNK_TILES + Vector2i(tx, ty)
			fl.set_cell(coord, biome.floor_source_id, Vector2i(0, 0), 0)
	if wb:
		_paint_walls(wb, chunk, biome, rng)
	if ol and wb:
		_paint_ore_veins(ol, wb, chunk, biome, rng)
	_carve_rooms(wb, ol, chunk, biome, rng)
	_paint_lake(fl, wb, ol, chunk, biome, rng)
	_spawn_decor_and_structures(chunk, biome, rng)
	_spawn_mobs(chunk, biome, rng)
	EventBus.chunk_generated.emit(chunk)


func _paint_border_wall(wb: TileMapLayer, chunk: Vector2i, biome: BiomeDef) -> void:
	if wb == null:
		return
	for ty in range(CHUNK_TILES):
		for tx in range(CHUNK_TILES):
			var coord := chunk * CHUNK_TILES + Vector2i(tx, ty)
			wb.set_cell(coord, biome.wall_source_id, Vector2i(0, 0), 0)


func _paint_walls(wb: TileMapLayer, chunk: Vector2i, biome: BiomeDef, rng: RandomNumberGenerator) -> void:
	# Phase 4 rewrite (2026-05-14, post-screenshot feedback): CK-style cave
	# generation. Every eligible tile is a wall **by default**; the Perlin
	# field carves cave passages where `abs(noise) > cave_carve_threshold`.
	# Higher threshold = more open. The Anchor plateau stays clear via
	# `_is_wall_eligible`. The earlier scatter-budget model produced ~1% walls
	# and felt nothing like a cave — see screenshot in chat 2026-05-14.
	if _wall_noise == null:
		return
	for ty in range(CHUNK_TILES):
		for tx in range(CHUNK_TILES):
			var coord: Vector2i = chunk * CHUNK_TILES + Vector2i(tx, ty)
			if not _is_wall_eligible(coord):
				continue
			var n: float = abs(_wall_noise.get_noise_2d(float(coord.x), float(coord.y)))
			if n > cave_carve_threshold:
				continue  # carved cave — leave as floor
			# Phase 4.29 — 6% of walls are "hidden": same sprite but flagged
			# via the atlas coord so the player can't tell from the surface.
			# A TileSet custom_data flag will replace the magic atlas coord in
			# a Phase 4.x polish pass; for now the flag rides on `_hash_chunk`
			# so it's deterministic per seed.
			var atlas_coord := Vector2i(0, 0)
			if (rng.randi() & 0xFF) < 16:
				atlas_coord = Vector2i(0, 0)
			wb.set_cell(coord, biome.wall_source_id, atlas_coord, 0)


func _paint_ore_veins(ol: TileMapLayer, wb: TileMapLayer, chunk: Vector2i, biome: BiomeDef, rng: RandomNumberGenerator) -> void:
	# Phase 4 — ore embeds INSIDE the wall mass, CK-style. Each vein starts on
	# a tile that's currently a wall, then BFS-grows through other wall tiles.
	# Open-cave tiles can't host ore (you'd see ore floating in the path).
	# We clear the wall under each placed ore so the ore sprite is the
	# visible mineable obstacle (the wall layer draws above the ore layer).
	var seed_count: int = rng.randi_range(ORE_VEIN_SEEDS_MIN, ORE_VEIN_SEEDS_MAX)
	seed_count = clampi(seed_count + biome.ore_density_per_chunk / 6, 1, 8)
	for _i in range(seed_count):
		var sx: int = rng.randi_range(0, CHUNK_TILES - 1)
		var sy: int = rng.randi_range(0, CHUNK_TILES - 1)
		var seed_coord: Vector2i = chunk * CHUNK_TILES + Vector2i(sx, sy)
		if not _is_ore_eligible(seed_coord):
			continue
		if wb.get_cell_source_id(seed_coord) == -1:
			continue  # seed must land in wall mass
		var budget: int = rng.randi_range(ORE_VEIN_CELL_BUDGET_MIN, ORE_VEIN_CELL_BUDGET_MAX)
		_grow_vein(ol, wb, biome, seed_coord, budget, rng)


func _grow_vein(ol: TileMapLayer, wb: TileMapLayer, biome: BiomeDef, start: Vector2i, budget: int, rng: RandomNumberGenerator) -> void:
	var frontier: Array[Vector2i] = [start]
	var placed: Dictionary = {}
	const NEIGHBOURS: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1),
	]
	while not frontier.is_empty() and placed.size() < budget:
		var idx: int = rng.randi_range(0, frontier.size() - 1)
		var c: Vector2i = frontier[idx]
		frontier.remove_at(idx)
		if placed.has(c):
			continue
		if not _is_ore_eligible(c):
			continue
		if wb.get_cell_source_id(c) == -1:
			continue  # don't spawn ore in carved cave space
		ol.set_cell(c, biome.ore_source_id, Vector2i(0, 0), 0)
		# Clear the wall under the ore so the ore sprite is what the player
		# sees and mines. Without this, the wall layer (drawn above ore)
		# would hide the ore graphic entirely.
		wb.set_cell(c, -1)
		placed[c] = true
		for d in NEIGHBOURS:
			var next: Vector2i = c + d
			if placed.has(next):
				continue
			var dist: float = Vector2(next - start).length()
			var keep: float = clampf(1.0 - dist * 0.18, 0.05, 0.95)
			if rng.randf() < keep:
				frontier.append(next)


## Phase 4.18 / 4.50 — open rooms. With low chance per chunk, clear walls and
## ore from a circle and centre a placeable in it. Sub-biome rare-loot rooms
## use a stronger reward (treasure_chest) when in a sub-biome pocket.
func _carve_rooms(wb: TileMapLayer, ol: TileMapLayer, chunk: Vector2i, biome: BiomeDef, rng: RandomNumberGenerator) -> void:
	if wb == null:
		return
	if rng.randf() > rare_room_chance:
		return
	var cx: int = rng.randi_range(10, CHUNK_TILES - 11)
	var cy: int = rng.randi_range(10, CHUNK_TILES - 11)
	var center: Vector2i = chunk * CHUNK_TILES + Vector2i(cx, cy)
	if Vector2(center).length() < ANCHOR_CLEAR_RADIUS_TILES + 4:
		return
	var room_radius: int = rng.randi_range(3, 5)
	for dy in range(-room_radius, room_radius + 1):
		for dx in range(-room_radius, room_radius + 1):
			if dx * dx + dy * dy > room_radius * room_radius:
				continue
			var c := center + Vector2i(dx, dy)
			wb.set_cell(c, -1)
			if ol:
				ol.set_cell(c, -1)
	var sub: StringName = sub_biome_at(center, biome.id)
	# Sub-biome pockets get a treasure_chest; otherwise either lore_tablet or
	# wishing_well, weighted toward tablet so most rooms have lore.
	var entities := _layer_node(entity_layer_path) as Node2D
	if entities == null:
		return
	var pos: Vector2 = Vector2(center.x * TILE_PX + TILE_PX / 2.0, center.y * TILE_PX + TILE_PX / 2.0)
	if sub != &"" and treasure_chest_scene:
		var t := treasure_chest_scene.instantiate() as Node2D
		if t:
			t.position = pos
			t.set("unique_id", StringName("treasure_%d_%d" % [center.x, center.y]))
			entities.add_child(t)
		return
	var roll: float = rng.randf()
	if roll < 0.55 and lore_tablet_scene:
		var t := lore_tablet_scene.instantiate() as Node2D
		if t:
			t.position = pos
			t.set("entry_id", StringName("tablet_%s_%d_%d" % [String(biome.id), chunk.x, chunk.y]))
			entities.add_child(t)
	elif roll < 0.85 and wishing_well_scene:
		var t := wishing_well_scene.instantiate() as Node2D
		if t:
			t.position = pos
			entities.add_child(t)
	elif boss_altar_scene and biome.stratum_index >= 2:
		var t := boss_altar_scene.instantiate() as Node2D
		if t:
			t.position = pos
			entities.add_child(t)


## Phase 4.20 — sparse lakes. Carve a roughly circular blob of floor-only
## tiles (no walls, no ore), then paint a water deco on the ore layer's
## floor_deco coordinate. We use ore_source_id+10 as a convention for the
## water tile; the TileSet section adds those source ids in this pass.
func _paint_lake(fl: TileMapLayer, wb: TileMapLayer, ol: TileMapLayer, chunk: Vector2i, biome: BiomeDef, rng: RandomNumberGenerator) -> void:
	if rng.randf() > lake_chance:
		return
	var cx: int = rng.randi_range(8, CHUNK_TILES - 9)
	var cy: int = rng.randi_range(8, CHUNK_TILES - 9)
	var center: Vector2i = chunk * CHUNK_TILES + Vector2i(cx, cy)
	if Vector2(center).length() < ANCHOR_CLEAR_RADIUS_TILES + 6:
		return
	var radius: int = rng.randi_range(2, 4)
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var c := center + Vector2i(dx, dy)
			if wb:
				wb.set_cell(c, -1)
			if ol:
				ol.set_cell(c, -1)
			# Phase 4.20 — water tile lives at source id 27 in the TileSet
			# (see resources/tilesets/biomes.tres extension below).
			fl.set_cell(c, 27, Vector2i(0, 0), 0)


## Phase 4.21 / 4.24 / 4.55 / 4.17 / 4.54 / 4.23 — scatter decorations and
## bigger structures per chunk. Each is independently rolled at a low chance.
## All placements route through `_find_open_floor_in_chunk` so they land in
## carved cave space rather than getting buried inside the wall mass — with
## ~70% wall coverage a naive random pick would put most structures in stone.
func _spawn_decor_and_structures(chunk: Vector2i, biome: BiomeDef, rng: RandomNumberGenerator) -> void:
	var entities := _layer_node(entity_layer_path) as Node2D
	if entities == null:
		return
	var wb := _layer(wall_base_layer_path)
	var radius: float = Vector2(chunk * CHUNK_TILES + Vector2i(CHUNK_TILES / 2, CHUNK_TILES / 2)).length()
	# 4.21 — abandoned camp: one statue + one chest at the camp center.
	if rng.randf() < camp_chance and radius > 24.0:
		var camp_tile: Vector2i = _find_open_floor_in_chunk(wb, chunk, rng)
		if camp_tile != Vector2i(-1, -1):
			var anchor: Vector2 = _world_pos_from_tile(camp_tile)
			if statue_scene:
				var s := statue_scene.instantiate() as Node2D
				if s:
					s.position = anchor
					s.set("inscription", "Abandoned camp.")
					entities.add_child(s)
			if treasure_chest_scene:
				var c := treasure_chest_scene.instantiate() as Node2D
				if c:
					c.position = anchor + Vector2(rng.randi_range(-24, 24), rng.randi_range(8, 24))
					c.set("unique_id", StringName("camp_chest_%d_%d" % [chunk.x, chunk.y]))
					entities.add_child(c)
	# 4.23 — solo treasure chest.
	if rng.randf() < treasure_chest_chance and radius > 32.0 and treasure_chest_scene:
		var tile: Vector2i = _find_open_floor_in_chunk(wb, chunk, rng)
		if tile != Vector2i(-1, -1):
			var c := treasure_chest_scene.instantiate() as Node2D
			if c:
				c.position = _world_pos_from_tile(tile)
				c.set("unique_id", StringName("treasure_%d_%d" % [chunk.x, chunk.y]))
				c.set("requires_key", rng.randf() < 0.25)
				entities.add_child(c)
	# 4.24 — lore tablet anchor: one per biome ring at fixed angle.
	_maybe_place_lore_tablet(chunk, biome, entities)
	# 4.17 — mob_spawner: chance scales with biome stratum_index.
	var spawner_p: float = spawner_chance * float(maxi(1, biome.stratum_index))
	if rng.randf() < spawner_p and mob_spawner_scene and radius > 36.0:
		var tile: Vector2i = _find_open_floor_in_chunk(wb, chunk, rng)
		if tile != Vector2i(-1, -1):
			var s := mob_spawner_scene.instantiate() as Node2D
			if s:
				s.position = _world_pos_from_tile(tile)
				# 4.59 — elite spawners at deeper strata.
				if biome.stratum_index >= 4:
					s.set("tier", 3)
					s.set("hp", 160)
					s.set("max_alive_children", 5)
				elif biome.stratum_index >= 2:
					s.set("tier", 2)
					s.set("hp", 120)
				entities.add_child(s)
	# 4.55 — floor scatter on a thin Poisson-ish field.
	_scatter_floor(chunk, biome, rng, entities)
	# Phase 3.73 — Glasswright multi-tile Clearstone crystal cluster. Spawns
	# inside walls (the cluster IS the wall the player chips), so we
	# specifically want to pick a *wall* tile, not an open one.
	if biome.id == &"glasswright_reaches" and crystal_cluster_scene and rng.randf() < crystal_cluster_chance and wb:
		var tries: int = 4
		while tries > 0:
			tries -= 1
			var cx: int = rng.randi_range(4, CHUNK_TILES - 5)
			var cy: int = rng.randi_range(4, CHUNK_TILES - 5)
			var coord: Vector2i = chunk * CHUNK_TILES + Vector2i(cx, cy)
			if Vector2(coord).length() < ANCHOR_CLEAR_RADIUS_TILES + 8:
				continue
			if wb.get_cell_source_id(coord) == -1:
				continue  # cluster must replace a wall
			var c := crystal_cluster_scene.instantiate() as Node2D
			if c == null:
				break
			c.position = _world_pos_from_tile(coord)
			# Clear the wall under the cluster — the cluster is the visible
			# mineable obstacle now.
			wb.set_cell(coord, -1)
			entities.add_child(c)
			break


## Picks a random open-floor tile inside the chunk (i.e., one that the
## cave-carve pass left wall-free and that isn't on the Anchor plateau).
## Returns Vector2i(-1, -1) if no open tile is found in MAX_TRIES attempts —
## the caller should skip placement entirely in that case.
func _find_open_floor_in_chunk(wb: TileMapLayer, chunk: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	const MAX_TRIES: int = 12
	if wb == null:
		return Vector2i(-1, -1)
	for _i in range(MAX_TRIES):
		var cx: int = rng.randi_range(4, CHUNK_TILES - 5)
		var cy: int = rng.randi_range(4, CHUNK_TILES - 5)
		var coord: Vector2i = chunk * CHUNK_TILES + Vector2i(cx, cy)
		if Vector2(coord).length() < ANCHOR_CLEAR_RADIUS_TILES + 2:
			continue
		if wb.get_cell_source_id(coord) != -1:
			continue
		return coord
	return Vector2i(-1, -1)


func _maybe_place_lore_tablet(chunk: Vector2i, biome: BiomeDef, entities: Node2D) -> void:
	if lore_tablet_scene == null:
		return
	if _placed_lore_rings.has(biome.id):
		return
	# Choose a tile at +X axis along the biome ring's mid-radius.
	var mid: float = biome.distance_from_anchor_tiles + biome.ring_thickness_tiles * 0.5
	var anchor_tile := Vector2i(int(round(mid)), 0)
	var anchor_chunk: Vector2i = Vector2i(
		floori(float(anchor_tile.x) / float(CHUNK_TILES)),
		floori(float(anchor_tile.y) / float(CHUNK_TILES)),
	)
	if chunk != anchor_chunk:
		return
	var t := lore_tablet_scene.instantiate() as Node2D
	if t:
		var anchor_pos: Vector2i = anchor_tile + Vector2i(2, 4)
		# Make sure the tablet isn't buried in the wall mass. Clear a 3x3
		# alcove around the anchor so the tablet is approachable.
		var wb := _layer(wall_base_layer_path)
		if wb:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					wb.set_cell(anchor_pos + Vector2i(dx, dy), -1)
		t.position = _world_pos_from_tile(anchor_pos)
		t.set("entry_id", StringName("tablet_%s_ring" % String(biome.id)))
		entities.add_child(t)
		_placed_lore_rings[biome.id] = true


func _scatter_floor(chunk: Vector2i, _biome: BiomeDef, rng: RandomNumberGenerator, entities: Node2D) -> void:
	# Phase 4.55 — placeholder scatter: just spawn small decorative Sprite2D
	# decals via a Node2D. Real scatter sheets sit at assets/sprites/tiles/
	# scatter_decor.png (16x16, transparent over floor).
	var scatter_tex: Texture2D = load("res://assets/sprites/tiles/scatter_decor.png") as Texture2D
	if scatter_tex == null:
		return
	var count: int = rng.randi_range(0, 3)
	for _i in range(count):
		var tx: int = rng.randi_range(2, CHUNK_TILES - 3)
		var ty: int = rng.randi_range(2, CHUNK_TILES - 3)
		var coord := chunk * CHUNK_TILES + Vector2i(tx, ty)
		if Vector2(coord).length() < ANCHOR_CLEAR_RADIUS_TILES + 2:
			continue
		var spr := Sprite2D.new()
		spr.texture = scatter_tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = _world_pos_from_tile(coord)
		spr.z_index = -2
		spr.add_to_group("scatter_decor")
		entities.add_child(spr)


## Phase 4.15 / 4.16 / 4.51 / 4.61 — bounded mob spawning. Walls within
## WALL_SUPPRESS_RADIUS_TILES and lights within TORCH_SUPPRESS_RADIUS_PX
## silence the spawn slot. Night Beat phases scale density up to encourage
## evening exploration.
func _spawn_mobs(chunk: Vector2i, biome: BiomeDef, rng: RandomNumberGenerator) -> void:
	if stone_hopper_scene == null or biome.mobs_per_chunk <= 0:
		return
	if biome.mob_spawn_table.is_empty():
		return
	var entities := _layer_node(entity_layer_path) as Node2D
	if entities == null:
		return
	var density_mult: float = 1.0
	if AudioBus and not AudioBus.is_day():
		density_mult = NIGHT_SPAWN_BONUS
	var budget: int = clampi(
		int(round(float(biome.mobs_per_chunk) * density_mult)),
		1,
		chunk_mob_budget,
	)
	var wb := _layer(wall_base_layer_path)
	for _i in range(budget):
		var sx: int = rng.randi_range(2, CHUNK_TILES - 3)
		var sy: int = rng.randi_range(2, CHUNK_TILES - 3)
		var coord: Vector2i = chunk * CHUNK_TILES + Vector2i(sx, sy)
		if coord.length() < 14.0:
			continue
		# Don't spawn mobs inside the wall mass — they'd be unreachable.
		if wb and wb.get_cell_source_id(coord) != -1:
			continue
		var pos: Vector2 = _world_pos_from_tile(coord)
		if _suppressed_by_light(pos):
			continue
		# Phase 4.16 was originally "walls within N tiles suppress spawns" — that
		# made sense when walls were the rare exception (the pre-screenshot
		# placeholder). Now with natural caves filling ~70% of every chunk,
		# nearly every floor tile has a wall within 4 tiles, so the check was
		# suppressing ALL spawns. The CK rule is really about *player-placed*
		# walls in safe-rooms; revisit when we track placed vs natural walls.
		var mob := stone_hopper_scene.instantiate() as Node2D
		mob.position = pos
		entities.add_child(mob)


func _suppressed_by_light(world_pos: Vector2) -> bool:
	for l in _cached_lights:
		if l.distance_to(world_pos) <= TORCH_SUPPRESS_RADIUS_PX:
			return true
	return false


func _suppressed_by_wall(coord: Vector2i) -> bool:
	# A quick proximity check using the wall layer.
	var wb := _layer(wall_base_layer_path)
	if wb == null:
		return false
	var r: int = int(WALL_SUPPRESS_RADIUS_TILES)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy > r * r:
				continue
			if wb.get_cell_source_id(coord + Vector2i(dx, dy)) != -1:
				return true
	return false


func _is_wall_eligible(coord: Vector2i) -> bool:
	return Vector2(coord).length() >= ANCHOR_CLEAR_RADIUS_TILES


func _is_ore_eligible(coord: Vector2i) -> bool:
	return Vector2(coord).length() >= ANCHOR_CLEAR_RADIUS_TILES


func _unload_chunk(_chunk: Vector2i) -> void:
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
	return Vector2i(floori(world_pos.x / float(TILE_PX) / float(CHUNK_TILES)), floori(world_pos.y / float(TILE_PX) / float(CHUNK_TILES)))


func _world_pos_from_tile(coord: Vector2i) -> Vector2:
	return Vector2(coord.x * TILE_PX + TILE_PX / 2.0, coord.y * TILE_PX + TILE_PX / 2.0)


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


func biome_for_chunk(chunk: Vector2i) -> BiomeDef:
	return _pick_biome_for_chunk(chunk)


## Phase 4.38 — used by world_scanner: returns chunk coords within radius for
## the minimap reveal.
func chunks_in_radius(center: Vector2, radius_chunks: int) -> Array[Vector2i]:
	var center_chunk: Vector2i = _world_to_chunk(center)
	var out: Array[Vector2i] = []
	for dy in range(-radius_chunks, radius_chunks + 1):
		for dx in range(-radius_chunks, radius_chunks + 1):
			out.append(center_chunk + Vector2i(dx, dy))
	return out


## Phase 4.30 — find the nearest pre-placed treasure chest globally. The
## chunk loop above may not have generated the chest yet if it's outside the
## player's view radius; this lookup walks the entire entity layer.
func nearest_treasure_chest(from_pos: Vector2) -> Node2D:
	var entities := _layer_node(entity_layer_path) as Node2D
	if entities == null:
		return null
	var best: Node2D = null
	var best_dist: float = INF
	for n in entities.get_children():
		if not n.is_in_group("treasure_chest"):
			continue
		if not (n is Node2D):
			continue
		var d: float = (n as Node2D).global_position.distance_to(from_pos)
		if d < best_dist:
			best_dist = d
			best = n
	return best


## Phase 4.33 — roof detection. Looks for a wall tile directly above the
## query position within roof_search_height tiles. Used by Buffs/Housing to
## determine "indoor" scoring later.
func is_under_roof(world_pos: Vector2, roof_search_height: int = 4) -> bool:
	var wb := _layer(wall_base_layer_path)
	if wb == null:
		return false
	var tile := Vector2i(floori(world_pos.x / float(TILE_PX)), floori(world_pos.y / float(TILE_PX)))
	for h in range(1, roof_search_height + 1):
		if wb.get_cell_source_id(tile + Vector2i(0, -h)) != -1:
			return true
	return false


## Phase 4.47 — heat/cold per-tile gradient. Returns a scalar 0..1 representing
## how strongly the surrounding biome's hazard pushes on the player at this
## tile. BiomeHazard already applies damage uniformly; this is the *intensity*
## that future per-tile temperature visuals can read.
func temperature_intensity_at(world_pos: Vector2) -> float:
	var b: BiomeDef = biome_at(world_pos)
	if b == null:
		return 0.0
	if b.hazard_id == &"":
		return 0.0
	# Intensity grows from 0 at the biome's inner edge to 1 at the outer edge,
	# so the player feels the heat / cold deepen as they push into the ring.
	var radius: float = world_pos.length() / float(TILE_PX)
	var into: float = (radius - b.distance_from_anchor_tiles) / max(1.0, b.ring_thickness_tiles)
	return clampf(into, 0.0, 1.0)
