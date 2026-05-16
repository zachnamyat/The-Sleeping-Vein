extends Node
class_name TalentEffects

## Phase 7.3-7.6 — Talent effect registry.
##
## Each talent node carries an `effect_id` + `effect_value`. The systems that
## care about a derived stat call `TalentEffects.sum_value(skill_id, effect_id)`
## which sums (rank × effect_value) across every allocated node in that skill's
## tree that maps to that effect_id.
##
## This lets us add new talents without touching CombatMath or PlayerStats —
## just register the effect_id in a .tres node and consume it where it matters.

## Phase 7 effect ids. Centralised so typo'd talent nodes blow up at load time
## rather than silently doing nothing. Add new ids in lock-step with the talent
## tree authoring pass.
const KNOWN_EFFECTS: Array[StringName] = [
	# Mining
	&"mining_damage_pct",
	&"mining_speed_pct",
	&"mining_pierce_chance",
	&"mining_area_radius",
	&"mining_xp_pct",
	# Running
	&"move_speed_pct",
	&"dodge_cooldown_reduction",
	&"dodge_distance_pct",
	&"stamina_regen_pct",
	# Melee
	&"melee_damage_pct",
	&"crit_chance_flat",
	&"crit_damage_flat",
	&"lifesteal_flat",
	&"backstab_damage_pct",
	# Ranged
	&"ranged_damage_pct",
	&"ranged_speed_pct",
	&"aim_cone_reduction",
	&"projectile_pierce_chance",
	&"ammo_save_chance",
	# Vitality
	&"max_hp_flat",
	&"armor_flat",
	&"thorns_flat",
	&"knockback_resistance_flat",
	&"regen_per_second",
	# Crafting
	&"craft_speed_pct",
	&"craft_cost_reduction",
	&"craft_quality_chance",
	&"workstation_radius_pct",
	# Gardening
	&"crop_growth_pct",
	&"crop_yield_pct",
	&"water_radius_pct",
	&"seed_save_chance",
	# Fishing
	&"fish_bite_pct",
	&"fish_quality_pct",
	&"fish_size_pct",
	&"rare_fish_chance",
	# Cooking
	&"food_buff_duration_pct",
	&"food_heal_pct",
	&"recipe_discover_chance",
	&"cooking_xp_pct",
	# Magic
	&"magic_damage_pct",
	&"mana_max_flat",
	&"mana_regen_flat",
	&"mana_cost_reduction",
	# Summoning
	&"summon_damage_pct",
	&"summon_hp_pct",
	&"summon_duration_pct",
	&"summon_slot_extra",
	# Explosives
	&"explosive_damage_pct",
	&"explosive_radius_pct",
	&"bomb_fuse_reduction",
	&"bomb_save_chance",
	# Universal
	&"luck_flat",
	&"loot_magnet_pct",
	&"all_xp_pct",
]


## Returns the summed magnitude of (rank * effect_value) for every allocated
## node in this skill that maps to `effect_id`. 0.0 if no allocation matches.
static func sum_value(skill_id: StringName, effect_id: StringName) -> float:
	var tree: TalentTree = TalentRegistry.tree_for(skill_id)
	if tree == null:
		return 0.0
	var by_node: Dictionary = GameState.allocated_talent_nodes.get(skill_id, {})
	if by_node.is_empty():
		return 0.0
	var total: float = 0.0
	for n in tree.nodes:
		var nid := StringName(n.get("id", ""))
		var eid := StringName(n.get("effect_id", ""))
		if eid != effect_id:
			continue
		var rank: int = int(by_node.get(nid, 0))
		if rank <= 0:
			continue
		total += float(rank) * float(n.get("effect_value", 0.0))
	return total


## Convenience: sum the effect across ALL skill trees. Used for "luck" or
## universal bonuses that show up on more than one tree.
static func sum_global(effect_id: StringName) -> float:
	var total: float = 0.0
	for s in SkillSystem.ALL_SKILLS:
		total += sum_value(s, effect_id)
	return total
