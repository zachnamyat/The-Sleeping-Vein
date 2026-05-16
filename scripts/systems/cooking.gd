extends Node

## Phase 8 cooking. Owns the food-buff category table, the recipe-discovery
## flag, and the audio sting on first discovery (ticket 8.38).
##
## Discovery is decoupled from recipe unlock: `is_unlocked` says the player
## *can* cook it; `is_discovered` says the cookbook has flipped the page from
## a question-mark hint (ticket 8.28) to the named entry. A recipe becomes
## discovered the first time the player crafts it OR fulfils every input at
## a cooking_pot (see CraftingSystem._on_item_crafted hook below).

signal recipe_discovered(recipe_id: StringName)

## Phase 8.6 — Master food list. category drives buff stacking (8.7): exactly
## one buff per category may be active at once; eating a new category-buff
## food replaces the old one.
## Buff parameters resolve through Buffs.apply(buff_id, duration). The actual
## stat application lives in PlayerStats (see _apply_food_buffs below); this
## table is just the truth source for "what buff comes from what food."
const FOOD_BUFFS: Dictionary = {
	&"pale_cap_stew":      { "buff_id": &"buff_well_fed",       "duration": 90.0,  "category": &"hp" },
	&"memory_root_broth":  { "buff_id": &"buff_clear_minded",   "duration": 90.0,  "category": &"mana" },
	&"loam_loaf":          { "buff_id": &"buff_full_belly",     "duration": 120.0, "category": &"stam" },
	&"bloat_loaf":         { "buff_id": &"buff_oat_strength",   "duration": 120.0, "category": &"hp" },
	&"heart_berry_jam":    { "buff_id": &"buff_heart_regen",    "duration": 180.0, "category": &"regen" },
	&"glow_cap_skewer":    { "buff_id": &"buff_glow_sight",     "duration": 120.0, "category": &"sight" },
	&"bomb_pepper_chili":  { "buff_id": &"buff_pepper_burn",    "duration": 60.0,  "category": &"dmg" },
	&"honeyed_loaf":       { "buff_id": &"buff_honeyed",        "duration": 240.0, "category": &"stam" },
	&"bread":              { "buff_id": &"buff_baker_warmth",   "duration": 240.0, "category": &"stam" },
	&"fish_grilled_basic": { "buff_id": &"buff_grilled_fish",   "duration": 120.0, "category": &"hp" },
	&"fish_grilled_salt":  { "buff_id": &"buff_grilled_salt",   "duration": 120.0, "category": &"hp" },
	&"fish_stew":          { "buff_id": &"buff_fish_stew",      "duration": 180.0, "category": &"regen" },
	&"berry_pie":          { "buff_id": &"buff_berry_pie",      "duration": 240.0, "category": &"regen" },
	&"mushroom_skewer":    { "buff_id": &"buff_mushroom_skew",  "duration": 90.0,  "category": &"hp" },
	&"dried_meat":         { "buff_id": &"buff_dried_meat",     "duration": 240.0, "category": &"stam" },
	&"xp_tonic":           { "buff_id": &"buff_xp_boost",       "duration": 240.0, "category": &"xp" },
	&"mining_focus_loaf":  { "buff_id": &"buff_xp_mining",      "duration": 240.0, "category": &"xp" },
	&"combat_tonic":       { "buff_id": &"buff_xp_combat",      "duration": 240.0, "category": &"xp" },
	&"crafting_tonic":     { "buff_id": &"buff_xp_crafting",    "duration": 240.0, "category": &"xp" },
	&"glaurem_jerky":      { "buff_id": &"buff_stoneblood",     "duration": 360.0, "category": &"hp" },
}

## Recipes that should play the discovery sting + a toast the first time they
## are crafted. Populated automatically from FOOD_BUFFS + cooking_pot recipes.
var _discovered: Dictionary = {}


func _ready() -> void:
	EventBus.item_crafted.connect(_on_item_crafted)


func is_discovered(recipe_id: StringName) -> bool:
	return bool(_discovered.get(recipe_id, false))


func mark_discovered(recipe_id: StringName) -> void:
	if _discovered.get(recipe_id, false):
		return
	_discovered[recipe_id] = true
	recipe_discovered.emit(recipe_id)
	# Phase 8.38 — recipe-unlock audio sting + toast on FIRST cook only.
	if AudioBus:
		AudioBus.play_sfx(&"cook_discovery")
	var rec: Recipe = CraftingSystem.get_recipe(recipe_id)
	if rec != null:
		EventBus.ui_toast.emit("Discovered: %s" % rec.display_name, 2.5)


func discovered_recipes() -> Array:
	return _discovered.keys()


## Phase 8.7 — Returns true if the food's buff category already has an active
## buff of higher tier — the new buff still wins but the UI can show "replaced".
func category_for(item_id: StringName) -> StringName:
	var rec: Dictionary = FOOD_BUFFS.get(item_id, {})
	return StringName(rec.get("category", &""))


func buff_for(item_id: StringName) -> Dictionary:
	return FOOD_BUFFS.get(item_id, {})


## When a player drinks/eats a food, the consume path in player_combat calls
## this so we can enforce one-per-category stacking + audio cue.
func apply_food_buff(item_id: StringName) -> void:
	var data: Dictionary = FOOD_BUFFS.get(item_id, {})
	if data.is_empty():
		return
	var category: StringName = StringName(data.get("category", &""))
	if category != &"":
		# Strip the previous buff in this category, if any.
		for k in FOOD_BUFFS.keys():
			var entry: Dictionary = FOOD_BUFFS[k]
			if StringName(entry.get("category", &"")) != category:
				continue
			var bid: StringName = StringName(entry.get("buff_id", &""))
			if bid == &"":
				continue
			if Buffs and Buffs.has(bid) and bid != StringName(data.get("buff_id", &"")):
				Buffs._active.erase(bid)
				Buffs.buff_expired.emit(bid)
	var buff_id: StringName = StringName(data.get("buff_id", &""))
	var dur: float = float(data.get("duration", 60.0))
	if buff_id != &"":
		Buffs.apply(buff_id, dur)


func _on_item_crafted(item_id: StringName, _count: int) -> void:
	# Phase 9.18 — count cooked meals toward the daily quest.
	if NpcLifecycle and FOOD_BUFFS.has(item_id):
		NpcLifecycle.record_quest_progress(&"quest_cook_3_meals", _count)
	# Phase 8.38 — match the produced item to its discovery toast.
	var rec_id: StringName = &""
	for r in CraftingSystem.all_recipes():
		var rec: Recipe = r
		for out in rec.outputs:
			if StringName(out.get("item_id", "")) == item_id and rec.skill_xp_id == &"skill_cooking":
				rec_id = rec.id
				break
		if rec_id != &"":
			break
	if rec_id == &"":
		return
	mark_discovered(rec_id)
