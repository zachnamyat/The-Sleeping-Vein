extends Node
class_name DamageType

## Damage type registry. Used as StringName tags throughout combat code.
## See docs/reference/core-keeper-mechanics.md §3.1 — Void & Voltage list:
## physical, fire, poison, cold, magic, summon, explosive, lightning, void.

const PHYSICAL: StringName = &"physical"
const FIRE: StringName = &"fire"
const POISON: StringName = &"poison"
const COLD: StringName = &"cold"
const MAGIC: StringName = &"magic"
const SUMMON: StringName = &"summon"
const EXPLOSIVE: StringName = &"explosive"
const LIGHTNING: StringName = &"lightning"
const VOID: StringName = &"void"

const ALL_TYPES: Array[StringName] = [
	PHYSICAL, FIRE, POISON, COLD, MAGIC, SUMMON, EXPLOSIVE, LIGHTNING, VOID,
]


static func is_valid(type: StringName) -> bool:
	return type in ALL_TYPES
