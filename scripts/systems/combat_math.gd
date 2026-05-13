extends Node
class_name CombatMath

## Core Keeper-parity damage math.
## See docs/reference/core-keeper-mechanics.md §3.2:
##   final = base_damage * (1 + sum_pct_modifiers) * (1 + crit_bonus if crit) - armor_reduction
##
## All callers should route damage through `resolve_damage` so the curve stays consistent.

const ARMOR_FLAT_REDUCTION_RATIO: float = 0.5
const ARMOR_PCT_REDUCTION_PER_POINT: float = 0.005
const MIN_DAMAGE_FRACTION: float = 0.10


static func resolve_damage(
	base_damage: int,
	pct_modifiers: float,
	crit_chance: float,
	crit_bonus: float,
	armor: int,
	rng: RandomNumberGenerator = null
) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var crit_roll: float = rng.randf()
	var is_crit: bool = crit_roll < crit_chance
	var modifier_block: float = 1.0 + maxf(0.0, pct_modifiers)
	var crit_block: float = 1.0 + (crit_bonus if is_crit else 0.0)
	var pre_armor: float = float(base_damage) * modifier_block * crit_block
	var armor_pct: float = clampf(float(armor) * ARMOR_PCT_REDUCTION_PER_POINT, 0.0, 0.75)
	var armor_flat: float = float(armor) * ARMOR_FLAT_REDUCTION_RATIO
	var post_armor: float = pre_armor * (1.0 - armor_pct) - armor_flat
	var min_floor: float = float(base_damage) * MIN_DAMAGE_FRACTION
	var final_damage: int = int(max(min_floor, post_armor))
	return {
		"final_damage": final_damage,
		"is_crit": is_crit,
		"pre_armor": pre_armor,
		"post_armor": post_armor,
	}


## Mining damage = pickaxe base + Mining skill level + talent bonus (2 per point).
## Tier-gated: if pickaxe_tier < tile_tier, no progress.
## Returns -1 if mining is not possible.
static func resolve_mining_damage(pickaxe_base: int, pickaxe_tier: int, tile_tier: int, mining_skill_level: int) -> int:
	if pickaxe_tier < tile_tier:
		return -1
	var talent_bonus: int = int(GameState.allocated_talents.get(&"skill_mining", 0)) * 2
	return pickaxe_base + mining_skill_level + talent_bonus


## Total +%damage modifier for a given weapon class from allocated talents.
## Each allocated point in the relevant skill adds 5% damage.
static func talent_damage_modifier(skill_id: StringName) -> float:
	return 0.05 * float(GameState.allocated_talents.get(skill_id, 0))


## Player crit chance from Melee talent (1% per point) + base 5%.
static func player_crit_chance() -> float:
	return 0.05 + 0.01 * float(GameState.allocated_talents.get(&"skill_melee", 0))


## Player crit bonus damage: +50% base + 5% per Melee talent point.
static func player_crit_bonus() -> float:
	return 0.5 + 0.05 * float(GameState.allocated_talents.get(&"skill_melee", 0))


## Player run speed multiplier: Running skill level * 0.001 + 0.02 per allocated Running point.
static func player_speed_multiplier() -> float:
	var lvl_bonus: float = float(SkillSystem.get_level(&"skill_running")) * 0.001
	var talent_bonus: float = 0.02 * float(GameState.allocated_talents.get(&"skill_running", 0))
	return 1.0 + lvl_bonus + talent_bonus


## Total bonus armor from allocated Vitality talents: +2 armor per point.
static func talent_armor_bonus() -> int:
	return 2 * int(GameState.allocated_talents.get(&"skill_vitality", 0))


## Total bonus max-HP from allocated Vitality talents: +10 per point.
static func talent_max_hp_bonus() -> int:
	return 10 * int(GameState.allocated_talents.get(&"skill_vitality", 0))
