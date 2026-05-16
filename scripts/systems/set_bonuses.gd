extends Node
class_name SetBonuses

## Phase 3.20 — Equipment set-bonus registry.
##
## Each gear set (Ember Iron, Auroric Ice, Bone Plate, etc.) defines bonus
## thresholds keyed by the number of pieces worn. Bonuses are additive across
## thresholds you've reached (so wearing 4 pieces gives you 2- + 3- + 4-piece
## bonuses).
##
## PlayerStats counts how many items share a set_id; this module resolves the
## piece count into the bonus dictionary.

const SETS: Dictionary = {
	&"set_ember_iron": {
		2: {"armor": 4, "max_hp": 10},
		3: {"crit_chance": 0.05},
		4: {"crit_damage": 0.20},
	},
	&"set_auroric_ice": {
		2: {"armor": 4, "max_hp": 8},
		3: {"crit_chance": 0.04, "luck": 1.0},
		4: {"crit_damage": 0.18},
	},
	&"set_bone_plate": {
		2: {"armor": 6},
		3: {"max_hp": 25},
		4: {"thorns": 5},
	},
}


## Phase 3.20 — sum every threshold up to `pieces_worn` and return the combined
## bonus dictionary. e.g. piece_count=3 returns the 2-piece + 3-piece bonuses.
static func bonus_for(set_id: StringName, pieces_worn: int) -> Dictionary:
	var out: Dictionary = {}
	var spec: Dictionary = SETS.get(set_id, {})
	if spec.is_empty():
		return out
	for threshold in spec.keys():
		if int(threshold) > pieces_worn:
			continue
		var values: Dictionary = spec[threshold]
		for k in values.keys():
			out[k] = float(out.get(k, 0.0)) + float(values[k])
	return out


## Phase 3.61 — tooltip preview. Returns every threshold/bonus pair for the set,
## flagged as active vs. potential based on the player's current piece count.
static func tooltip_preview(set_id: StringName, current_pieces: int) -> Array:
	var out: Array = []
	var spec: Dictionary = SETS.get(set_id, {})
	if spec.is_empty():
		return out
	var thresholds: Array = spec.keys()
	thresholds.sort()
	for t in thresholds:
		var active: bool = int(t) <= current_pieces
		out.append({"threshold": int(t), "bonus": spec[t], "active": active})
	return out


## Returns the human-readable name for a set id (for tooltips).
static func display_name_for(set_id: StringName) -> String:
	match set_id:
		&"set_ember_iron": return "Ember Iron"
		&"set_auroric_ice": return "Auroric Ice"
		&"set_bone_plate": return "Bone Plate"
		_: return String(set_id).replace("set_", "").capitalize()
