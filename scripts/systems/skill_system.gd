extends Node

## Skill system autoload (registered in project.godot when Phase 7 lands properly).
## For Phase 1/2, this is the central tracker for the 12 skills.
## See docs/design/02_lore_to_mechanics_mapping.md §7 for skill ids and lore labels.

const SKILL_CAP_LEVEL: int = 100
const XP_PER_LEVEL_BASE: int = 100
const XP_PER_LEVEL_GROWTH: float = 1.10

const ALL_SKILLS: Array[StringName] = [
	&"skill_mining",
	&"skill_running",
	&"skill_melee",
	&"skill_ranged",
	&"skill_vitality",
	&"skill_crafting",
	&"skill_gardening",
	&"skill_fishing",
	&"skill_cooking",
	&"skill_magic",
	&"skill_summoning",
	&"skill_explosives",
]

var _xp: Dictionary = {}
var _level: Dictionary = {}


func _ready() -> void:
	for s in ALL_SKILLS:
		_xp[s] = 0
		_level[s] = 0
	EventBus.skill_xp_gained.connect(_on_xp_gained)


func get_level(skill_id: StringName) -> int:
	return _level.get(skill_id, 0)


func get_xp(skill_id: StringName) -> int:
	return _xp.get(skill_id, 0)


func xp_required_for_level(level: int) -> int:
	if level <= 0:
		return 0
	return int(round(XP_PER_LEVEL_BASE * pow(XP_PER_LEVEL_GROWTH, level - 1)))


func add_xp(skill_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var lvl: int = _level.get(skill_id, 0)
	if lvl >= SKILL_CAP_LEVEL:
		return
	var xp: int = _xp.get(skill_id, 0) + amount
	_xp[skill_id] = xp
	while lvl < SKILL_CAP_LEVEL and xp >= xp_required_for_level(lvl + 1):
		lvl += 1
		_level[skill_id] = lvl
		EventBus.skill_leveled_up.emit(skill_id, lvl)
		# Phase 7 — every level grants one allocatable talent point.
		GameState.grant_talent_point(1)


func _on_xp_gained(skill_id: StringName, amount: int) -> void:
	add_xp(skill_id, amount)
