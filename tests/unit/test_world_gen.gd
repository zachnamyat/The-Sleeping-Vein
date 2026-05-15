extends GutTest

## Phase 4 — world generation parity tests.
##
## We can't easily instance the full WorldGen scene in unit tests (it needs
## TileMapLayers and the player), but we can exercise the deterministic
## pieces: the biome-ring picker, the hash-per-chunk function, and the
## corridor-tile predicate. Those drive the *shape* of the world; the rest is
## paint-on-top.

const WorldGenScript: Script = preload("res://scripts/world/world_gen.gd")


func _make_world_gen() -> Object:
	# WorldGen.new() returns a fresh Node, but without the autoload SceneTree
	# we can't add it as a child. We exercise pure-data methods directly via
	# the script's _ready-independent helpers.
	var inst: Object = WorldGenScript.new()
	return inst


func test_chunk_tiles_constant_is_64() -> void:
	# Phase 4.1 — chunk size locked at 64 for CK parity. Minimap + FogOfWar
	# read the same constant; bumping this without updating both will desync
	# their drawing rects.
	assert_eq(WorldGenScript.CHUNK_TILES, 64, "WorldGen.CHUNK_TILES must be 64 for Phase 4")


func test_anchor_plateau_blocks_walls_and_ore() -> void:
	# 2026-05-14 — Phase 4.6 corridor carving was retracted as anti-parity (CK
	# gates biome rings with progressively-harder walls, not pre-cleared roads).
	# The only remaining "always clear" zone is the Anchor plateau — a 7-tile
	# radius circle at world origin where the player spawns. Verify the wall +
	# ore eligibility predicates honour that and nothing else.
	var wg: Object = _make_world_gen()
	# Inside the plateau: walls and ore must be suppressed.
	assert_false(wg.call("_is_wall_eligible", Vector2i(0, 0)))
	assert_false(wg.call("_is_wall_eligible", Vector2i(3, 4)))
	assert_false(wg.call("_is_ore_eligible", Vector2i(0, 0)))
	assert_false(wg.call("_is_ore_eligible", Vector2i(3, 4)))
	# On-axis tiles outside the plateau must be eligible again (no corridor).
	assert_true(wg.call("_is_wall_eligible", Vector2i(0, 50)))
	assert_true(wg.call("_is_wall_eligible", Vector2i(100, 0)))
	assert_true(wg.call("_is_ore_eligible", Vector2i(0, -100)))
	# Off-axis far from origin still eligible.
	assert_true(wg.call("_is_wall_eligible", Vector2i(20, 50)))
	assert_true(wg.call("_is_ore_eligible", Vector2i(20, 50)))
	wg.free()


func test_hash_chunk_is_deterministic_per_seed() -> void:
	# Same chunk + same world_seed -> same hash. Different seed -> different hash.
	var wg: Object = _make_world_gen()
	GameState.world_seed = 1337
	var h_a: int = wg.call("_hash_chunk", Vector2i(3, -2))
	var h_b: int = wg.call("_hash_chunk", Vector2i(3, -2))
	assert_eq(h_a, h_b, "hash_chunk must be deterministic for a fixed seed")
	GameState.world_seed = 4242
	var h_c: int = wg.call("_hash_chunk", Vector2i(3, -2))
	assert_ne(h_a, h_c, "different world_seed should produce different chunk hash")
	wg.free()


func test_world_to_chunk_translates_pixels() -> void:
	var wg: Object = _make_world_gen()
	# CHUNK_TILES (64) * TILE_PX (16) = 1024 px per chunk.
	assert_eq(wg.call("_world_to_chunk", Vector2(0, 0)), Vector2i(0, 0))
	assert_eq(wg.call("_world_to_chunk", Vector2(1023, 1023)), Vector2i(0, 0))
	assert_eq(wg.call("_world_to_chunk", Vector2(1024, 0)), Vector2i(1, 0))
	assert_eq(wg.call("_world_to_chunk", Vector2(-1, 0)), Vector2i(-1, 0))
	wg.free()
