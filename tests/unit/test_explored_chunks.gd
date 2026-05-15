extends GutTest

## Phase 4.10 — exploration log round-trips through SaveSystem.

const TEST_SLOT: String = "_gut_explored_slot"


func before_each() -> void:
	GameState.explored_chunks.clear()
	GameState.respawn_point = Vector2.ZERO
	if SaveSystem.slot_exists(TEST_SLOT):
		SaveSystem.delete_slot(TEST_SLOT)


func after_each() -> void:
	GameState.explored_chunks.clear()
	GameState.respawn_point = Vector2.ZERO
	if SaveSystem.slot_exists(TEST_SLOT):
		SaveSystem.delete_slot(TEST_SLOT)


func test_mark_chunk_visited_records_biome() -> void:
	GameState.mark_chunk_visited(Vector2i(2, -1), &"root_hollows")
	assert_true(GameState.has_visited_chunk(Vector2i(2, -1)))
	assert_eq(GameState.explored_chunk_biome(Vector2i(2, -1)), StringName("root_hollows"))


func test_mark_chunk_visited_is_idempotent() -> void:
	# First call wins. A later re-visit with a different biome (e.g. a
	# transition chunk that picks a neighbour ring on second sample) must not
	# overwrite the original biome record, or the map would flicker biome
	# colors as the player crosses an edge.
	GameState.mark_chunk_visited(Vector2i(3, 0), &"root_hollows")
	GameState.mark_chunk_visited(Vector2i(3, 0), &"glasswright_reaches")
	assert_eq(GameState.explored_chunk_biome(Vector2i(3, 0)), StringName("root_hollows"))


func test_explored_chunks_round_trip() -> void:
	GameState.mark_chunk_visited(Vector2i(0, 0), &"root_hollows")
	GameState.mark_chunk_visited(Vector2i(1, 0), &"glasswright_reaches")
	GameState.set_respawn_point(Vector2(64, -32))
	var save_err: int = SaveSystem.save_to_slot(TEST_SLOT)
	assert_eq(save_err, OK)
	GameState.explored_chunks.clear()
	GameState.respawn_point = Vector2.ZERO
	var load_err: int = SaveSystem.load_from_slot(TEST_SLOT)
	assert_eq(load_err, OK)
	assert_true(GameState.has_visited_chunk(Vector2i(0, 0)))
	assert_true(GameState.has_visited_chunk(Vector2i(1, 0)))
	assert_eq(GameState.respawn_point, Vector2(64, -32))


func test_reset_clears_explored_chunks() -> void:
	GameState.mark_chunk_visited(Vector2i(5, 5), &"root_hollows")
	GameState.set_respawn_point(Vector2(100, 100))
	GameState.reset_for_new_game()
	assert_false(GameState.has_visited_chunk(Vector2i(5, 5)))
	assert_eq(GameState.respawn_point, Vector2.ZERO)
