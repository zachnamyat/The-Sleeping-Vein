extends GutTest

## GUT test for SaveSystem round-trip.

const TEST_SLOT: String = "_gut_test_slot"


func before_each() -> void:
	if SaveSystem.slot_exists(TEST_SLOT):
		SaveSystem.delete_slot(TEST_SLOT)


func after_each() -> void:
	if SaveSystem.slot_exists(TEST_SLOT):
		SaveSystem.delete_slot(TEST_SLOT)


func test_save_then_load_round_trips_game_state() -> void:
	GameState.world_seed = 12345
	GameState.aphelion_slivers_remaining = 69_999
	GameState.defeated_bosses[&"boss_glaurem"] = 1
	GameState.sovereign_threads = 1
	var save_err: int = SaveSystem.save_to_slot(TEST_SLOT)
	assert_eq(save_err, OK)

	GameState.world_seed = 0
	GameState.aphelion_slivers_remaining = GameState.APHELION_STARTING_SLIVERS
	GameState.defeated_bosses = {}
	GameState.sovereign_threads = 0

	var load_err: int = SaveSystem.load_from_slot(TEST_SLOT)
	assert_eq(load_err, OK)
	assert_eq(GameState.world_seed, 12345)
	assert_eq(GameState.aphelion_slivers_remaining, 69_999)
	assert_true(GameState.defeated_bosses.has(&"boss_glaurem"))
	assert_eq(GameState.sovereign_threads, 1)


func test_load_nonexistent_slot_returns_error() -> void:
	var err: int = SaveSystem.load_from_slot("does_not_exist")
	assert_ne(err, OK)
