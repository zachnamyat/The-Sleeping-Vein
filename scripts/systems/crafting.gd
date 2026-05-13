extends Node

## Recipe registry + crafting executor.
## Loads all .tres recipes from resources/recipes/, tracks unlocked recipes in GameState.

const RECIPES_ROOT: String = "res://resources/recipes/"

var _recipes: Dictionary = {}


func _ready() -> void:
	_scan_directory(RECIPES_ROOT)
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	# Phase 3: unlock the starter set of recipes on world load. Phase 5+ will gate
	# subsequent recipes behind discovery events (pickup, boss kill).
	for starter in [
		&"craft_wooden_pickaxe", &"craft_wooden_sword", &"craft_torch", &"craft_loam_bench",
		&"craft_bow", &"craft_arrow_wood", &"craft_small_mana_potion", &"craft_small_healing_potion",
		&"craft_clearstone_forge", &"craft_hoe", &"craft_watering_can",
		&"craft_cooking_pot",
		# Phase 8 cooking pot recipes — discovered as soon as you build the pot:
		&"craft_pale_cap_stew", &"craft_loam_loaf", &"craft_memory_root_broth",
		# Phase 7 — respec scroll
		&"craft_respec_scroll",
		# Phase 8 — fishing
		&"craft_fishing_rod_wood",
		# Phase 11.7 — heat/cold resist chest pieces
		&"craft_ember_iron_chestpiece", &"craft_auroric_ice_chestpiece",
	]:
		unlock(starter)
	# Tier-1 shaleseed gear unlocks when the player picks up their first shaleseed.
	# Wired via item_picked_up below.
	EventBus.item_crafted.connect(_on_item_crafted)


func _scan_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full := path.path_join(entry)
		if dir.current_is_dir():
			_scan_directory(full)
		elif entry.ends_with(".tres"):
			var res := load(full) as Recipe
			if res != null and res.id != &"":
				_recipes[res.id] = res
		entry = dir.get_next()
	dir.list_dir_end()


func get_recipe(id: StringName) -> Recipe:
	return _recipes.get(id)


func all_recipes() -> Array:
	return _recipes.values()


func recipes_for_station(station_id: StringName) -> Array:
	var out: Array = []
	for r in _recipes.values():
		var rec: Recipe = r
		if rec.stations.is_empty() or station_id in rec.stations:
			if is_unlocked(rec.id):
				out.append(rec)
	return out


func is_unlocked(recipe_id: StringName) -> bool:
	return GameState.unlocked_recipes.get(recipe_id, false)


func unlock(recipe_id: StringName) -> void:
	if GameState.unlocked_recipes.get(recipe_id, false):
		return
	GameState.unlocked_recipes[recipe_id] = true
	EventBus.recipe_unlocked.emit(recipe_id)


func unlock_all() -> void:
	for r in _recipes.values():
		unlock((r as Recipe).id)


func try_craft(recipe_id: StringName) -> bool:
	var rec: Recipe = _recipes.get(recipe_id)
	if rec == null:
		return false
	if not is_unlocked(rec.id):
		return false
	if not rec.can_craft(Callable(Inventory, "count_of")):
		return false
	for inp in rec.inputs:
		Inventory.try_remove(StringName(inp.get("item_id", "")), int(inp.get("count", 1)))
	for out in rec.outputs:
		Inventory.try_add(StringName(out.get("item_id", "")), int(out.get("count", 1)))
		EventBus.item_crafted.emit(StringName(out.get("item_id", "")), int(out.get("count", 1)))
	if rec.skill_xp_grant > 0 and rec.skill_xp_id != &"":
		EventBus.skill_xp_gained.emit(rec.skill_xp_id, rec.skill_xp_grant)
	return true


func _on_item_picked_up(item_id: StringName, _count: int) -> void:
	for r in _recipes.values():
		var rec: Recipe = r
		if item_id in rec.unlock_on_pickup:
			unlock(rec.id)
	if item_id == &"shaleseed":
		for rid in [&"craft_shaleseed_pickaxe", &"craft_shaleseed_sword", &"craft_shaleseed_helmet", &"craft_shaleseed_chest"]:
			unlock(rid)


func _on_boss_defeated(boss_id: StringName) -> void:
	for r in _recipes.values():
		var rec: Recipe = r
		if boss_id in rec.unlock_on_boss_kill:
			unlock(rec.id)


func _on_item_crafted(item_id: StringName, _count: int) -> void:
	# Crafting a station unlocks the player's "I now have access to" set.
	# Phase 3.11: building the Clearstone Forge unlocks Shaleseed-tier recipes.
	if item_id == &"clearstone_forge_placeable":
		for rid in [&"craft_shaleseed_pickaxe", &"craft_shaleseed_sword", &"craft_shaleseed_helmet", &"craft_shaleseed_chest"]:
			unlock(rid)
