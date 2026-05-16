extends Node

## Phase 3.40 — recipe-scroll drops. A consumable item; on use, picks an
## unrevealed recipe id from the registry and marks it as
## `GameState.unlocked_recipes[id] = true`. Drops are seeded by:
##   - Phase 3.72 chest loot rolls (added to TreasureChest)
##   - Phase 5 boss drops occasional (Glaur-em adds 1 scroll on death)
##
## This script doesn't own the item; it's a static helper hung off the
## SceneTree group `recipe_scroll_listener` so player_combat can dispatch
## to consume_one(item_id).

const ROLLABLE_RECIPE_IDS: Array[StringName] = [
	&"recipe_glow_tube",
	&"recipe_furnace",
	&"recipe_sawmill",
	&"recipe_plank",
	&"recipe_shaleseed_ingot",
	&"recipe_bottle_empty",
	&"recipe_station_tier_upgrade",
	&"recipe_loam_loaf",
	&"recipe_memory_root_broth",
	&"recipe_pale_cap_stew",
]


func consume_one() -> bool:
	# Pick an unrevealed recipe id at random. If everything is already known,
	# refund the scroll.
	var candidates: Array[StringName] = []
	for r in ROLLABLE_RECIPE_IDS:
		if not GameState.unlocked_recipes.get(r, false):
			candidates.append(r)
	if candidates.is_empty():
		EventBus.ui_toast.emit("You already know every recipe this scroll could teach.", 2.5)
		return false
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pick: StringName = candidates[rng.randi() % candidates.size()]
	GameState.unlocked_recipes[pick] = true
	EventBus.recipe_unlocked.emit(pick)
	EventBus.ui_toast.emit("Recipe learned: %s" % String(pick).replace("recipe_", "").capitalize(), 3.0)
	if AudioBus:
		AudioBus.play_sfx(&"scroll_unroll")
	return true
