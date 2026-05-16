extends GutTest

## Phase 5 systems test bundle. Verifies the new boss/NPC/compendium/title
## hooks without spinning up a full world scene.


func before_each() -> void:
	# Reset autoloads to a deterministic empty state.
	GameState.defeated_bosses.clear()
	GameState.arrived_npcs.clear()
	GameState.unlocked_compendium.clear()
	GameState.collected_relics.clear()
	GameState.sovereign_threads = 0
	if TitleSystem:
		TitleSystem.titles_earned.clear()
		TitleSystem.equipped_title = &""
	Inventory.clear()


# --- Phase 5.16 — first-encounter compendium triggers ---------------------


func test_first_kill_unlocks_bestiary_entry() -> void:
	var fake_def := MobDef.new()
	fake_def.id = &"test_mob"
	fake_def.display_name = "Test Mob"
	var fake_mob := Mob.new()
	fake_mob.mob_def = fake_def
	# Direct call into the compendium handler (it ignores the killer).
	Compendium._on_entity_killed(fake_mob, null)
	assert_true(Compendium.is_unlocked(&"bestiary_test_mob"))
	fake_mob.free()


# --- Phase 5.19 — Hunter's Crown title earned per boss kill ----------------


func test_title_system_records_first_sovereign() -> void:
	EventBus.boss_defeated.emit(&"boss_glaurem")
	assert_true(StringName("Hunter's Crown") in TitleSystem.titles_earned)
	assert_eq(String(TitleSystem.equipped_title), "Hunter's Crown")


func test_title_system_ignores_duplicate_kills() -> void:
	EventBus.boss_defeated.emit(&"boss_glaurem")
	EventBus.boss_defeated.emit(&"boss_glaurem")
	var count: int = 0
	for t in TitleSystem.titles_earned:
		if t == StringName("Hunter's Crown"):
			count += 1
	assert_eq(count, 1)


# --- Phase 5.34 — bark system per NPC × boss ------------------------------


func test_bark_system_picks_specific_or_generic_line() -> void:
	# Aelstren × glaurem has a specific line.
	var specific: String = BarkSystem._line_for(&"npc_aelstren", &"boss_glaurem")
	assert_ne(specific, "")
	assert_true(specific.contains("Aelstren"))
	# Aelstren × unknown boss falls back to generic.
	var generic: String = BarkSystem._line_for(&"npc_aelstren", &"boss_unknown")
	assert_ne(generic, "")
	# Unknown NPC returns empty.
	assert_eq(BarkSystem._line_for(&"npc_does_not_exist", &"boss_glaurem"), "")


# --- Phase 3.40 — recipe scroll consumption -------------------------------


func test_recipe_scroll_unlocks_one_recipe() -> void:
	GameState.unlocked_recipes.clear()
	var scroll := Node.new()
	scroll.set_script(load("res://scripts/items/recipe_scroll.gd"))
	add_child_autofree(scroll)
	var ok: bool = scroll.consume_one()
	assert_true(ok, "consume_one should succeed when fresh")
	var unlocked: int = GameState.unlocked_recipes.size()
	assert_gt(unlocked, 0)


func test_recipe_scroll_refunds_when_everything_known() -> void:
	# Pre-mark every rollable recipe as already learned.
	var scroll := Node.new()
	scroll.set_script(load("res://scripts/items/recipe_scroll.gd"))
	add_child_autofree(scroll)
	for r in scroll.ROLLABLE_RECIPE_IDS:
		GameState.unlocked_recipes[r] = true
	var ok: bool = scroll.consume_one()
	assert_false(ok, "scroll should report failure so caller refunds")


# --- Phase 5.25 — boss arena gate lock state ------------------------------


func test_boss_arena_lock_and_unlock() -> void:
	var arena := BossArena.new()
	add_child_autofree(arena)
	assert_false(arena.is_gate_locked())
	var fake_boss := Node.new()
	add_child_autofree(fake_boss)
	arena.lock_gate_for(fake_boss)
	assert_true(arena.is_gate_locked())
	arena.unlock_gate()
	assert_false(arena.is_gate_locked())


# --- Phase 5.5 — boss drop list shape -------------------------------------


func test_boss_drop_defaults_include_pulse_shell_fragment_trinket() -> void:
	var boss := Boss.new()
	# Drop ids are exposed via @export, default values stand.
	assert_eq(String(boss.pulse_item_id), "stone_fathers_pulse")
	assert_eq(String(boss.fragment_item_id), "sovereign_name_fragment_1")
	assert_eq(String(boss.shell_item_id), "engorged_stone_shell")
	assert_eq(String(boss.trinket_item_id), "glaurem_trinket")
	assert_gt(boss.shell_drop_count, 0)
	boss.free()
