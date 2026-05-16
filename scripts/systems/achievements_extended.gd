extends Node

## Phase 15 — Extended achievements registry.
## Augments the base Achievements autoload with the full Phase 15 backlog:
##   15.4 — full achievement system across all categories
##   15.14 — title cosmetic backend (per-achievement title unlock map)
##   15.15 — in-world achievement toast popups (handled by SteamIntegration stub + EventBus)
##   15.41 — hidden achievements (no tooltip until unlocked)
##   15.42 — "Visit all biomes"
##   15.43 — "Catch every fish"
##   15.44 — "Cook every recipe"
##   15.45 — "Talk to every NPC"
##   15.46 — "Read every tablet"
##   15.57 — easter-egg discovery achievements
##
## NB the existing Achievements autoload retains its first-strike / first-craft /
## boss-defeat handlers; this extension layers cumulative + category goals.

const CATEGORIES: Array[StringName] = [
	&"combat", &"exploration", &"crafting", &"survival",
	&"social", &"cosmetic", &"hidden", &"meta",
]

## Each entry: { id, name, desc, category, hidden, title_grant, target }
const EXTENDED: Array[Dictionary] = [
	# --- Exploration ---
	{ "id": &"ach_visit_all_biomes", "name": "Walked Every Floor", "desc": "Visit all 9 biomes.",
	  "category": &"exploration", "target": 9 },
	{ "id": &"ach_read_all_tablets", "name": "Recorder of Memory", "desc": "Read every lore tablet.",
	  "category": &"exploration", "target": 24 },
	{ "id": &"ach_explore_500_chunks", "name": "Cartographer of Loss", "desc": "Explore 500 chunks.",
	  "category": &"exploration", "target": 500 },
	# --- Cooking / Fishing / Crafting ---
	{ "id": &"ach_catch_every_fish", "name": "Net-Bearer", "desc": "Catch one of every fish.",
	  "category": &"crafting", "target": 18 },
	{ "id": &"ach_cook_every_recipe", "name": "Pot-Master", "desc": "Cook every recipe once.",
	  "category": &"crafting", "target": 20 },
	{ "id": &"ach_craft_100_items", "name": "Industrious", "desc": "Craft 100 items.",
	  "category": &"crafting", "target": 100 },
	{ "id": &"ach_grow_50_crops", "name": "Patient Hands", "desc": "Harvest 50 crops.",
	  "category": &"crafting", "target": 50 },
	# --- Combat ---
	{ "id": &"ach_kill_500_mobs", "name": "Long Walking", "desc": "Defeat 500 mobs.",
	  "category": &"combat", "target": 500 },
	{ "id": &"ach_combo_50", "name": "Unbroken", "desc": "Hit a 50× combo.",
	  "category": &"combat", "target": 50 },
	{ "id": &"ach_no_damage_boss", "name": "Threadless", "desc": "Defeat a boss without taking damage.",
	  "category": &"combat", "target": 0 },
	# --- Social ---
	{ "id": &"ach_meet_all_npcs", "name": "All Welcomed", "desc": "Bring all NPCs to the Anchor.",
	  "category": &"social", "target": 7 },
	{ "id": &"ach_friendship_brindle", "name": "Brindle's Friend", "desc": "Max Brindle's friendship.",
	  "category": &"social", "target": 250 },
	{ "id": &"ach_friendship_all", "name": "Hand on Every Shoulder", "desc": "Reach friendship 200+ with all NPCs.",
	  "category": &"social", "target": 7 },
	# --- Cosmetic / Wardrobe ---
	{ "id": &"ach_save_first_outfit", "name": "Wardrobe", "desc": "Save an outfit.",
	  "category": &"cosmetic", "target": 1 },
	{ "id": &"ach_dye_three_items", "name": "Stained Hands", "desc": "Apply dye to three items.",
	  "category": &"cosmetic", "target": 3 },
	# --- Survival / Hardcore ---
	{ "id": &"ach_hardcore_first_boss", "name": "Permanent Memory", "desc": "Defeat a boss in Hardcore.",
	  "category": &"survival", "target": 1 },
	{ "id": &"ach_no_death_to_glaurem", "name": "Held Breath", "desc": "Defeat Glaur-em without dying once.",
	  "category": &"survival", "target": 1 },
	# --- Meta ---
	{ "id": &"ach_first_speedrun_finish", "name": "Recorded", "desc": "Complete a speedrun.",
	  "category": &"meta", "target": 1 },
	{ "id": &"ach_boss_rush_complete", "name": "All Doors at Once", "desc": "Complete Boss-Rush.",
	  "category": &"meta", "target": 11 },
	{ "id": &"ach_endless_floor_10", "name": "Deeper Than Maps", "desc": "Reach Endless floor 10.",
	  "category": &"meta", "target": 10 },
	{ "id": &"ach_login_streak_7", "name": "Weekly Walker", "desc": "Log in 7 days in a row.",
	  "category": &"meta", "target": 7 },
	# --- Hidden ---
	{ "id": &"ach_easter_dev_credits", "name": "Behind the Names", "desc": "Find the dev-credits wall.",
	  "category": &"hidden", "hidden": true, "target": 1 },
	{ "id": &"ach_easter_all", "name": "Hidden in the Stones", "desc": "Find all hidden rooms.",
	  "category": &"hidden", "hidden": true, "target": 9 },
	{ "id": &"ach_first_photo", "name": "Witnessed", "desc": "Save a photograph.",
	  "category": &"meta", "target": 1 },
	{ "id": &"ach_ng_plus_3", "name": "Three Walkings", "desc": "Complete NG+3.",
	  "category": &"meta", "target": 3 },
]

## Cumulative progress map: ach_id -> current count.
var progress: Dictionary = {}

signal achievement_progress_updated(id: StringName, current: int, target: int)
signal achievement_revealed(id: StringName)


func _ready() -> void:
	for entry in EXTENDED:
		progress[entry["id"]] = 0
	# Hook into existing event bus.
	EventBus.biome_changed.connect(_on_biome_changed)
	EventBus.chunk_visited.connect(_on_chunk_visited)
	EventBus.npc_arrived.connect(_on_npc_arrived)
	EventBus.entity_killed.connect(_on_entity_killed)
	EventBus.item_crafted.connect(_on_item_crafted)
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.phase15_combo_changed.connect(_on_combo_changed)
	EventBus.phase15_easter_egg_discovered.connect(_on_easter_egg_discovered)
	EventBus.boss_defeated.connect(_on_boss_defeated)


func bump(ach_id: StringName, by: int = 1) -> void:
	if not Achievements:
		return
	# Block when achievements are disabled via difficulty / cheats.
	if Phase15Helpers and not Phase15Helpers.achievements_enabled():
		return
	if Achievements.is_unlocked(ach_id):
		return
	progress[ach_id] = int(progress.get(ach_id, 0)) + by
	var entry: Dictionary = _find_entry(ach_id)
	if entry.is_empty():
		return
	var target: int = int(entry.get("target", 1))
	achievement_progress_updated.emit(ach_id, int(progress[ach_id]), target)
	if int(progress[ach_id]) >= target:
		_unlock(ach_id, entry)


func mark_revealed(ach_id: StringName) -> void:
	if Phase15Helpers:
		Phase15Helpers.hidden_achievement_revealed[ach_id] = true
		achievement_revealed.emit(ach_id)


func is_revealed(ach_id: StringName) -> bool:
	if Phase15Helpers and Phase15Helpers.hidden_achievement_revealed.get(ach_id, false):
		return true
	# Not hidden by default? Visible.
	var entry: Dictionary = _find_entry(ach_id)
	return not bool(entry.get("hidden", false))


func _find_entry(ach_id: StringName) -> Dictionary:
	for entry in EXTENDED:
		if entry["id"] == ach_id:
			return entry
	return {}


func _unlock(ach_id: StringName, entry: Dictionary) -> void:
	# Reveal hidden achievements on unlock.
	if Phase15Helpers:
		Phase15Helpers.hidden_achievement_revealed[ach_id] = true
	# Register with the base Achievements registry so the title earns + toast pop.
	if not Achievements:
		return
	GameState.unlocked_compendium[ach_id] = true
	EventBus.ui_toast.emit("Achievement: %s" % String(entry.get("name", String(ach_id))), 3.5)
	if SteamIntegration:
		SteamIntegration.unlock_achievement(ach_id)


# ---------- Event handlers ----------

var _biomes_visited: Dictionary = {}

func _on_biome_changed(_old: StringName, new_b: StringName) -> void:
	_biomes_visited[new_b] = true
	progress[&"ach_visit_all_biomes"] = _biomes_visited.size()
	if _biomes_visited.size() >= 9:
		var entry: Dictionary = _find_entry(&"ach_visit_all_biomes")
		_unlock(&"ach_visit_all_biomes", entry)


func _on_chunk_visited(_c: Vector2i, _b: StringName) -> void:
	bump(&"ach_explore_500_chunks", 1)


func _on_npc_arrived(_npc_id: StringName) -> void:
	bump(&"ach_meet_all_npcs", 1)


func _on_entity_killed(entity: Node, killer: Node) -> void:
	if killer != null and killer.is_in_group("player"):
		bump(&"ach_kill_500_mobs", 1)
	# Hardcore + no-death + no-damage-boss handled below.
	if entity is Boss:
		var b := entity as Boss
		if Phase15Helpers and Phase15Helpers.hardcore_active:
			bump(&"ach_hardcore_first_boss", 1)
		if Phase15Helpers and Phase15Helpers.damage_breakdown.get(&"damage_taken", 0) == 0:
			bump(&"ach_no_damage_boss", 1)
		if b.boss_id == &"boss_glaurem" and Phase15Helpers and Phase15Helpers.current_run_deaths == 0:
			bump(&"ach_no_death_to_glaurem", 1)


var _crafted_items_seen: Dictionary = {}
func _on_item_crafted(item_id: StringName, _count: int) -> void:
	bump(&"ach_craft_100_items", 1)
	_crafted_items_seen[item_id] = true


var _fish_seen: Dictionary = {}
var _crops_harvested: Dictionary = {}
func _on_item_picked_up(item_id: StringName, _count: int) -> void:
	var s: String = String(item_id)
	if s.begins_with("fish_"):
		_fish_seen[item_id] = true
		progress[&"ach_catch_every_fish"] = _fish_seen.size()
	if s in ["pale_cap", "memory_root", "bloat_oat", "heart_berry", "salt_radish", "shadow_grain"]:
		_crops_harvested[item_id] = true
		bump(&"ach_grow_50_crops", 1)


func _on_combo_changed(count: int) -> void:
	if count >= 50:
		var entry: Dictionary = _find_entry(&"ach_combo_50")
		_unlock(&"ach_combo_50", entry)


func _on_easter_egg_discovered(egg_id: StringName) -> void:
	if egg_id == &"egg_dev_credits":
		var entry: Dictionary = _find_entry(&"ach_easter_dev_credits")
		_unlock(&"ach_easter_dev_credits", entry)
	bump(&"ach_easter_all", 1)


func _on_boss_defeated(_boss_id: StringName) -> void:
	# Boss-rush completion check.
	if Phase15Helpers and Phase15Helpers.boss_rush_active and Phase15Helpers.boss_rush_progress >= 11:
		var entry: Dictionary = _find_entry(&"ach_boss_rush_complete")
		_unlock(&"ach_boss_rush_complete", entry)


# ---------- Manual triggers ----------

func note_photograph_taken() -> void:
	bump(&"ach_first_photo", 1)


func note_speedrun_finished() -> void:
	bump(&"ach_first_speedrun_finish", 1)


func note_ng_plus_completed(cycle: int) -> void:
	if cycle >= 3:
		var entry: Dictionary = _find_entry(&"ach_ng_plus_3")
		_unlock(&"ach_ng_plus_3", entry)


func note_outfit_saved() -> void:
	bump(&"ach_save_first_outfit", 1)


func note_dye_applied() -> void:
	bump(&"ach_dye_three_items", 1)


func note_login_streak(days: int) -> void:
	if days >= 7:
		var entry: Dictionary = _find_entry(&"ach_login_streak_7")
		_unlock(&"ach_login_streak_7", entry)
