extends Node

## Achievement system. Each achievement is a {id, name, description, predicate}.
## On every relevant EventBus signal, evaluates pending predicates and unlocks
## newly-met achievements. Toast on unlock. Persistent via GameState.

signal achievement_unlocked(id: StringName, name: String)

const ACHIEVEMENTS: Array[Dictionary] = [
	{ "id": &"ach_first_loam",         "name": "First Spadeful",       "desc": "Mine your first tile." },
	{ "id": &"ach_first_shaleseed",    "name": "Seedfinder",           "desc": "Pick up your first Shaleseed." },
	{ "id": &"ach_first_kill",         "name": "First Strike",         "desc": "Defeat your first enemy." },
	{ "id": &"ach_first_craft",        "name": "Form-Maker",           "desc": "Craft an item at the Loam Bench." },
	{ "id": &"ach_glaurem_down",       "name": "Thank You for the Quiet", "desc": "Defeat Glaur-em." },
	{ "id": &"ach_two_sovereigns",     "name": "Twice Burdened",       "desc": "Defeat 2 Sovereigns." },
	{ "id": &"ach_all_sovereigns",     "name": "Threaded",             "desc": "Defeat all 9 Sovereigns." },
	{ "id": &"ach_first_loom_insert",  "name": "The Loom Drinks",      "desc": "Insert a relic into the Resonance Loom." },
	{ "id": &"ach_first_npc",          "name": "Not Alone",            "desc": "An NPC arrives at the Anchor." },
	{ "id": &"ach_first_cook",         "name": "Hearthwarmer",         "desc": "Cook your first food." },
	{ "id": &"ach_first_plant",        "name": "Slow Patience",        "desc": "Harvest your first crop." },
	{ "id": &"ach_first_talent",       "name": "Practice Tells",       "desc": "Allocate your first talent point." },
	{ "id": &"ach_diadem_bearer",      "name": "The Sunken Diadem",    "desc": "Defeat the Diadem-Bearer." },
	{ "id": &"ach_ending_restore",     "name": "Restore",              "desc": "Choose Ending A." },
	{ "id": &"ach_ending_break",       "name": "Break",                "desc": "Choose Ending B." },
	{ "id": &"ach_ending_become",      "name": "Become",               "desc": "Choose Ending C." },
	{ "id": &"ach_ng_plus",            "name": "Second Walking",       "desc": "Begin a New Game+ cycle." },
	{ "id": &"ach_first_aphelion_fight", "name": "The Sun's Pattern",  "desc": "Engage the Aphelion in Ending B." },
]

var _unlocked: Dictionary = {}


func _ready() -> void:
	EventBus.tile_changed.connect(_on_tile_changed)
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.entity_killed.connect(_on_entity_killed)
	EventBus.item_crafted.connect(_on_item_crafted)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.npc_arrived.connect(_on_npc_arrived)
	EventBus.sovereign_defeated.connect(_on_sovereign_defeated)


func unlock(id: StringName) -> void:
	if _unlocked.has(id):
		return
	if GameState.unlocked_compendium.get(id, false):
		_unlocked[id] = true
		return
	for entry in ACHIEVEMENTS:
		if entry.id == id:
			_unlocked[id] = true
			GameState.unlocked_compendium[id] = true
			achievement_unlocked.emit(id, entry.name)
			EventBus.ui_toast.emit("Achievement: %s" % entry.name, 3.0)
			return


func is_unlocked(id: StringName) -> bool:
	return _unlocked.has(id) or GameState.unlocked_compendium.get(id, false)


func _on_tile_changed(_coord: Vector2i, old_id: int, new_id: int) -> void:
	if old_id >= 0 and new_id < 0:
		unlock(&"ach_first_loam")


func _on_item_picked_up(item_id: StringName, _count: int) -> void:
	if item_id == &"shaleseed":
		unlock(&"ach_first_shaleseed")
	if item_id in [&"pale_cap", &"memory_root"]:
		unlock(&"ach_first_plant")


func _on_entity_killed(_entity: Node, _killer: Node) -> void:
	unlock(&"ach_first_kill")


func _on_item_crafted(item_id: StringName, _count: int) -> void:
	unlock(&"ach_first_craft")
	var defn: ItemDef = ItemRegistry.get_def(item_id)
	if defn and defn.item_type == ItemDef.ItemType.CONSUMABLE and defn.heal_amount > 0:
		unlock(&"ach_first_cook")


func _on_boss_defeated(boss_id: StringName) -> void:
	if boss_id == &"boss_glaurem":
		unlock(&"ach_glaurem_down")
	if boss_id == &"boss_diadem_bearer":
		unlock(&"ach_diadem_bearer")
	if boss_id == &"boss_aphelion":
		unlock(&"ach_first_aphelion_fight")


func _on_sovereign_defeated(_id: StringName, _fragment: StringName) -> void:
	if GameState.sovereign_threads >= 2:
		unlock(&"ach_two_sovereigns")
	if GameState.sovereign_threads >= 9:
		unlock(&"ach_all_sovereigns")


func _on_npc_arrived(_npc_id: StringName) -> void:
	unlock(&"ach_first_npc")
