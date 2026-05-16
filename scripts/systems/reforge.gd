extends Node
class_name Reforge

## Phase 3.29 — Anvil reforge system.
##
## A reforge rolls one random affix from REFORGE_AFFIXES and applies it to the
## inventory slot's runtime data (NOT the static .tres). The affix bumps
## crit/damage/etc. for that single instance.
##
## Currently lives as a per-slot Dictionary stored under Inventory.slots[i].affix.
## When PlayerStats.recompute runs, it folds affix bonuses on top of ItemDef
## values. Save/load round-trips the slot dictionary.

const REFORGE_COST_ANCIENT_COIN: int = 8

const REFORGE_AFFIXES: Array[Dictionary] = [
	{"id": &"reforge_keen",   "name": "Keen",   "crit_chance_bonus":  0.08},
	{"id": &"reforge_brutal", "name": "Brutal", "crit_damage_bonus":  0.30},
	{"id": &"reforge_swift",  "name": "Swift",  "cooldown_reduction": 0.12},
	{"id": &"reforge_steel",  "name": "Steel",  "armor_value":        4},
	{"id": &"reforge_lucky",  "name": "Lucky",  "luck_bonus":         8.0},
	{"id": &"reforge_warm",   "name": "Warm",   "max_hp_bonus":       18},
]


## Returns true if the inventory slot can be reforged. Slot must contain a
## reforgeable item (weapon, armor, accessory) and the player must have the
## fee in ancient_coin.
static func can_reforge(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= Inventory.slots.size():
		return false
	var entry = Inventory.slots[slot_index]
	if entry == null:
		return false
	var iid := StringName(entry.get("item_id", ""))
	var defn: ItemDef = ItemRegistry.get_def(iid)
	if defn == null:
		return false
	# Weapons, armor, and accessories are reforgeable. Materials/consumables
	# never are. Items can also opt-in via the `reforgeable` flag.
	var t := defn.item_type
	if not (t == ItemDef.ItemType.WEAPON or t == ItemDef.ItemType.ARMOR or defn.reforgeable):
		return false
	if Inventory.count_of(&"ancient_coin") < REFORGE_COST_ANCIENT_COIN:
		return false
	return true


static func try_reforge(slot_index: int) -> Dictionary:
	if not can_reforge(slot_index):
		return {}
	Inventory.try_remove(&"ancient_coin", REFORGE_COST_ANCIENT_COIN)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pick: Dictionary = REFORGE_AFFIXES[rng.randi() % REFORGE_AFFIXES.size()]
	var entry: Dictionary = Inventory.slots[slot_index]
	entry["affix"] = pick.duplicate(true)
	Inventory.slots[slot_index] = entry
	Inventory.slot_changed.emit(slot_index, StringName(entry["item_id"]), int(entry["count"]))
	EventBus.inventory_changed.emit()
	EventBus.ui_toast.emit("Reforged: %s" % String(pick.get("name", "")), 2.0)
	return pick


## Compute total bonus across every equipped slot that carries a reforge affix.
## Returns a flat Dictionary of stat -> value, callers add to PlayerStats fields.
static func equipped_bonus_sum() -> Dictionary:
	var out: Dictionary = {}
	for slot in Inventory.equipment.keys():
		var iid: StringName = StringName(Inventory.equipment.get(slot, &""))
		if iid == &"":
			continue
		# Find any inventory entry matching the equipped id that still carries an
		# affix (equipment was applied via equip_from_slot, which moved the
		# entry, so we instead store affixes on a parallel dict on Inventory).
		var affix: Dictionary = Inventory.equipped_affixes.get(slot, {})
		if affix.is_empty():
			continue
		for k in affix.keys():
			if k == "id" or k == "name":
				continue
			out[k] = float(out.get(k, 0.0)) + float(affix[k])
	return out
