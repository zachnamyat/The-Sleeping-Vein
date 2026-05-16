extends Node

## Phase 8.25/8.41/8.49/8.50 — Pet system. Tracks tamed pets, per-pet XP, the
## food-favorite mood (8.41), and pet-revive flow (8.50). A pet item lives in
## the player's `pet` equipment slot and follows the Walker; this autoload
## holds the persistent state (level, mood, dead-flag) keyed by pet_id.

signal pet_tamed(pet_id: StringName)
signal pet_leveled_up(pet_id: StringName, new_level: int)
signal pet_died(pet_id: StringName)
signal pet_revived(pet_id: StringName)

const XP_PER_LEVEL_BASE: int = 50
const XP_PER_LEVEL_GROWTH: float = 1.15
const MAX_LEVEL: int = 20
const FAVORITE_BONUS_XP: int = 3
const NEUTRAL_FOOD_XP: int = 1

## { pet_id -> { "xp": int, "level": int, "mood": int (0..100), "dead": bool } }
var pets: Dictionary = {}

## { pet_id -> taming_food_id (favorite food) }
const FAVORITES: Dictionary = {
	&"pet_pale_fox":     &"heart_berry",
	&"pet_charred_goat": &"bloat_oat",
	&"pet_root_finch":   &"glow_cap",
	&"pet_lantern_eel":  &"cave_guppy",
}


func _ready() -> void:
	EventBus.entity_killed.connect(_on_entity_killed)


## Player approaches a wild fauna with the right feed → tame.
## Returns true if a new pet was registered.
func tame(pet_id: StringName, with_food_id: StringName) -> bool:
	if pets.has(pet_id) and not bool(pets[pet_id].get("dead", false)):
		return false
	var fav: StringName = FAVORITES.get(pet_id, &"")
	if fav != &"" and with_food_id != fav:
		return false
	pets[pet_id] = { "xp": 0, "level": 1, "mood": 75, "dead": false }
	pet_tamed.emit(pet_id)
	Inventory.try_add(pet_id, 1)
	EventBus.ui_toast.emit("Tamed: %s" % String(pet_id).replace("pet_", "").capitalize(), 2.5)
	return true


func feed(pet_id: StringName, food_id: StringName) -> bool:
	if not pets.has(pet_id):
		return false
	var fav: StringName = FAVORITES.get(pet_id, &"")
	var xp_gain: int = FAVORITE_BONUS_XP if food_id == fav else NEUTRAL_FOOD_XP
	pets[pet_id]["mood"] = clampi(int(pets[pet_id].get("mood", 50)) + (10 if food_id == fav else 4), 0, 100)
	add_xp(pet_id, xp_gain)
	return true


## Phase 8.49 — XP from being near combat. Each player-source kill gives the
## currently-equipped pet 1 XP (or 2 if the food it likes is the player's
## active food buff).
func _on_entity_killed(_entity: Node, killer: Node) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var players := tree.get_nodes_in_group("player")
	if players.is_empty() or killer == null:
		return
	if killer != players[0] and (killer is Node2D and (killer as Node2D).get_parent() != players[0]):
		# Only credit kills the player or a player-spawned summon caused.
		var team_node: Node = killer
		var team: StringName = StringName(team_node.get("team")) if team_node and "team" in team_node else &""
		if team != &"player":
			return
	var active_pet: StringName = StringName(Inventory.equipment.get(&"pet", &""))
	if active_pet == &"":
		return
	add_xp(active_pet, 1)


func add_xp(pet_id: StringName, amount: int) -> void:
	if not pets.has(pet_id):
		return
	var rec: Dictionary = pets[pet_id]
	if int(rec.get("level", 1)) >= MAX_LEVEL:
		return
	rec["xp"] = int(rec.get("xp", 0)) + amount
	while int(rec["level"]) < MAX_LEVEL and rec["xp"] >= xp_for_level(int(rec["level"]) + 1):
		rec["level"] = int(rec["level"]) + 1
		pet_leveled_up.emit(pet_id, int(rec["level"]))
		EventBus.ui_toast.emit("%s reaches Lv %d" % [String(pet_id).capitalize(), int(rec["level"])], 2.0)
		# Phase 9.31 — evolution check.
		_check_evolution(pet_id, int(rec["level"]))
	pets[pet_id] = rec


# Phase 9.31 — evolution. When the pet hits a level threshold, swap the pet
# entry to a new pet id (preserving level/XP). The pet item in the equipment
# slot is also replaced so the held visual changes.
func _check_evolution(pet_id: StringName, new_level: int) -> void:
	if Phase9Helpers == null:
		return
	var target: StringName = Phase9Helpers.get_evolution_target(pet_id, new_level)
	if target == &"" or target == pet_id:
		return
	# Carry over level + xp + mood.
	var rec: Dictionary = pets[pet_id]
	pets.erase(pet_id)
	pets[target] = rec
	# Swap the equipment slot if currently held.
	var active: StringName = StringName(Inventory.equipment.get(&"pet", &""))
	if active == pet_id:
		Inventory.equipment[&"pet"] = target
		Inventory.equipment_changed.emit(&"pet", target)
	EventBus.ui_toast.emit("%s evolves into %s!" % [String(pet_id).capitalize(), String(target).capitalize()], 3.5)


# Phase 9.22 — Pet saddlebag inventory. Per-pet, capped at 4 slots. Items can
# only go in if the pet's level is >= 5 (representing "old enough to carry").
const SADDLEBAG_SIZE: int = 4
const SADDLEBAG_MIN_LEVEL: int = 5
var saddlebag: Dictionary = {}  ## { pet_id -> Array[ {item_id, count} ] }


func saddlebag_for(pet_id: StringName) -> Array:
	if not saddlebag.has(pet_id):
		saddlebag[pet_id] = []
	return saddlebag[pet_id]


func saddlebag_can_carry(pet_id: StringName) -> bool:
	if not pets.has(pet_id):
		return false
	if int(pets[pet_id].get("level", 1)) < SADDLEBAG_MIN_LEVEL:
		return false
	return saddlebag_for(pet_id).size() < SADDLEBAG_SIZE


func saddlebag_deposit(pet_id: StringName, item_id: StringName, count: int = 1) -> bool:
	if not saddlebag_can_carry(pet_id):
		return false
	saddlebag_for(pet_id).append({ "item_id": String(item_id), "count": count })
	return true


func saddlebag_withdraw(pet_id: StringName, index: int) -> Dictionary:
	var bag: Array = saddlebag_for(pet_id)
	if index < 0 or index >= bag.size():
		return {}
	var entry: Dictionary = bag[index]
	bag.remove_at(index)
	return entry


func xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	return int(round(XP_PER_LEVEL_BASE * pow(XP_PER_LEVEL_GROWTH, level - 1)))


## Phase 8.50 — when a pet dies in combat, leave a corpse and require the
## player to carry it back to a Resonance Loom (or use Pet Revive Charm).
func mark_dead(pet_id: StringName) -> void:
	if not pets.has(pet_id):
		return
	pets[pet_id]["dead"] = true
	pet_died.emit(pet_id)
	EventBus.ui_toast.emit("%s collapses. Revive at the Loom." % String(pet_id).capitalize(), 3.0)


func try_revive(pet_id: StringName) -> bool:
	if not pets.has(pet_id):
		return false
	if not bool(pets[pet_id].get("dead", false)):
		return false
	if Inventory.try_remove(&"pet_revive_charm", 1) <= 0:
		EventBus.ui_toast.emit("Pet Revive Charm required.", 2.0)
		return false
	pets[pet_id]["dead"] = false
	pet_revived.emit(pet_id)
	EventBus.ui_toast.emit("%s breathes again." % String(pet_id).capitalize(), 2.5)
	return true


func get_level(pet_id: StringName) -> int:
	if not pets.has(pet_id):
		return 0
	return int(pets[pet_id].get("level", 0))


func is_dead(pet_id: StringName) -> bool:
	return pets.has(pet_id) and bool(pets[pet_id].get("dead", false))
