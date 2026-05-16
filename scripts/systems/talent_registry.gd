extends Node

## Phase 7.1 — Indexes every TalentTree under resources/skills/talent_trees/ by
## skill_id at startup. Provides `tree_for(skill_id)` + helpers consumed by the
## TalentPanel UI, GameState.allocate_talent_node, and TalentEffects.sum_value.

const TREES_ROOT: String = "res://resources/skills/talent_trees/"

var _trees: Dictionary = {}  ## skill_id (StringName) -> TalentTree


func _ready() -> void:
	_scan_directory(TREES_ROOT)
	# Build any tree that wasn't authored on disk in code, so the panel always
	# has 12 trees to render. This is the bootstrap fallback for first-launch.
	_ensure_default_trees()


func _scan_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full := path.path_join(entry)
		if dir.current_is_dir():
			_scan_directory(full)
		elif entry.ends_with(".tres"):
			var res := load(full) as TalentTree
			if res and res.skill_id != &"":
				_trees[res.skill_id] = res
		entry = dir.get_next()
	dir.list_dir_end()


func tree_for(skill_id: StringName) -> TalentTree:
	return _trees.get(skill_id)


func all_trees() -> Array:
	return _trees.values()


## Phase 7.13 — prerequisite check. A node is unlockable only when every entry
## in its `prerequisites` array has at least 1 rank allocated.
func prerequisites_met(skill_id: StringName, node_id: StringName) -> bool:
	var tree: TalentTree = tree_for(skill_id)
	if tree == null:
		return false
	var d := tree.node_by_id(node_id)
	var prereqs: Array = d.get("prerequisites", [])
	if prereqs.is_empty():
		return true
	var by_node: Dictionary = GameState.allocated_talent_nodes.get(skill_id, {})
	for p in prereqs:
		if int(by_node.get(StringName(p), 0)) <= 0:
			return false
	return true


## Hard-coded fallbacks ensure the panel has trees even if the .tres files
## aren't present in a clean checkout. The on-disk .tres files override these.
func _ensure_default_trees() -> void:
	for spec in DEFAULT_TREES:
		var sid := StringName(spec["skill_id"])
		if _trees.has(sid):
			continue
		var t := TalentTree.new()
		t.skill_id = sid
		t.display_name = spec["display_name"]
		t.lore_name = spec["lore_name"]
		t.nodes = spec["nodes"].duplicate(true)
		_trees[sid] = t


# ============================================================================
# Default talent content (tickets 7.3 / 7.4 / 7.5 / 7.6).
# Each skill gets a 5-tier, 7-15-node tree. Capstones at tier 5 require all of
# tier 4 (a common ARPG-style funnel). Effects pull from TalentEffects.KNOWN_EFFECTS.
# ============================================================================
const DEFAULT_TREES: Array = [
	{
		"skill_id": &"skill_mining",
		"display_name": "Mining",
		"lore_name": "Stratabreaking",
		"nodes": [
			{"id": &"mining_dmg_1",   "display_name": "Hammer Hand",     "description": "+10% mining damage per rank.",            "tier": 1, "column": 1, "max_ranks": 5, "prerequisites": [],                  "effect_id": &"mining_damage_pct", "effect_value": 0.10},
			{"id": &"mining_speed_1", "display_name": "Quick Swing",     "description": "+6% mining speed per rank.",              "tier": 2, "column": 0, "max_ranks": 5, "prerequisites": [&"mining_dmg_1"],   "effect_id": &"mining_speed_pct",  "effect_value": 0.06},
			{"id": &"mining_pierce",  "display_name": "Strata-pierce",   "description": "+15% chance to pierce one extra tile.",   "tier": 2, "column": 2, "max_ranks": 5, "prerequisites": [&"mining_dmg_1"],   "effect_id": &"mining_pierce_chance", "effect_value": 0.15},
			{"id": &"mining_xp_1",    "display_name": "Patient Eye",     "description": "+10% mining XP per rank.",                "tier": 3, "column": 1, "max_ranks": 3, "prerequisites": [&"mining_speed_1"], "effect_id": &"mining_xp_pct",     "effect_value": 0.10},
			{"id": &"mining_area_1",  "display_name": "Resonant Strike", "description": "+8 pixel mining splash per rank.",        "tier": 4, "column": 0, "max_ranks": 3, "prerequisites": [&"mining_xp_1"],    "effect_id": &"mining_area_radius","effect_value": 8.0},
			{"id": &"mining_capstone","display_name": "Stratabreaker",   "description": "+40% mining damage. Capstone.",           "tier": 5, "column": 1, "max_ranks": 1, "prerequisites": [&"mining_area_1", &"mining_pierce"], "effect_id": &"mining_damage_pct", "effect_value": 0.40},
		],
	},
	{
		"skill_id": &"skill_running",
		"display_name": "Running",
		"lore_name": "Walking",
		"nodes": [
			{"id": &"run_speed_1",   "display_name": "Light Step",      "description": "+3% move speed per rank.",              "tier": 1, "column": 1, "max_ranks": 5, "prerequisites": [],                "effect_id": &"move_speed_pct",            "effect_value": 0.03},
			{"id": &"dodge_cd",      "display_name": "Quick Recovery",  "description": "-8% dodge cooldown per rank.",          "tier": 2, "column": 0, "max_ranks": 5, "prerequisites": [&"run_speed_1"], "effect_id": &"dodge_cooldown_reduction",  "effect_value": 0.08},
			{"id": &"dodge_dist",    "display_name": "Long Stride",     "description": "+10% dodge distance per rank.",         "tier": 2, "column": 2, "max_ranks": 5, "prerequisites": [&"run_speed_1"], "effect_id": &"dodge_distance_pct",        "effect_value": 0.10},
			{"id": &"stamina_regen", "display_name": "Steady Breath",   "description": "+10% stamina regen per rank.",          "tier": 3, "column": 1, "max_ranks": 3, "prerequisites": [&"dodge_cd"],     "effect_id": &"stamina_regen_pct",         "effect_value": 0.10},
			{"id": &"run_capstone",  "display_name": "Walker's Promise","description": "+25% move speed. Capstone.",            "tier": 5, "column": 1, "max_ranks": 1, "prerequisites": [&"stamina_regen", &"dodge_dist"], "effect_id": &"move_speed_pct",            "effect_value": 0.25},
		],
	},
	{
		"skill_id": &"skill_melee",
		"display_name": "Melee",
		"lore_name": "Hand-Strike",
		"nodes": [
			{"id": &"melee_dmg_1",    "display_name": "Heavy Hand",     "description": "+8% melee damage per rank.",          "tier": 1, "column": 1, "max_ranks": 5, "prerequisites": [],                "effect_id": &"melee_damage_pct",   "effect_value": 0.08},
			{"id": &"crit_chance_1",  "display_name": "Killing Eye",    "description": "+2% crit chance per rank.",           "tier": 2, "column": 0, "max_ranks": 5, "prerequisites": [&"melee_dmg_1"], "effect_id": &"crit_chance_flat",   "effect_value": 0.02},
			{"id": &"crit_dmg_1",     "display_name": "Bleeding Cut",   "description": "+10% crit damage per rank.",          "tier": 2, "column": 2, "max_ranks": 5, "prerequisites": [&"melee_dmg_1"], "effect_id": &"crit_damage_flat",   "effect_value": 0.10},
			{"id": &"lifesteal_1",    "display_name": "Bloodseed",      "description": "+1.5% lifesteal per rank.",           "tier": 3, "column": 1, "max_ranks": 4, "prerequisites": [&"crit_chance_1"], "effect_id": &"lifesteal_flat",     "effect_value": 0.015},
			{"id": &"backstab_1",     "display_name": "Quiet Hand",     "description": "+20% backstab damage per rank.",      "tier": 4, "column": 0, "max_ranks": 3, "prerequisites": [&"lifesteal_1"], "effect_id": &"backstab_damage_pct","effect_value": 0.20},
			{"id": &"melee_capstone", "display_name": "Sovereign-strike","description": "+5% crit chance and +30% crit damage. Capstone.", "tier": 5, "column": 1, "max_ranks": 1, "prerequisites": [&"backstab_1", &"crit_dmg_1"], "effect_id": &"crit_chance_flat",   "effect_value": 0.05},
		],
	},
	{
		"skill_id": &"skill_ranged",
		"display_name": "Ranged",
		"lore_name": "Hand-Throw",
		"nodes": [
			{"id": &"ranged_dmg_1",  "display_name": "Long Reach",   "description": "+8% ranged damage per rank.",     "tier": 1, "column": 1, "max_ranks": 5, "prerequisites": [],                 "effect_id": &"ranged_damage_pct",      "effect_value": 0.08},
			{"id": &"ranged_aim",    "display_name": "Steady Aim",   "description": "-15% aim cone per rank.",         "tier": 2, "column": 0, "max_ranks": 4, "prerequisites": [&"ranged_dmg_1"], "effect_id": &"aim_cone_reduction",     "effect_value": 0.15},
			{"id": &"ranged_speed",  "display_name": "Fast Draw",    "description": "+5% projectile speed per rank.",  "tier": 2, "column": 2, "max_ranks": 5, "prerequisites": [&"ranged_dmg_1"], "effect_id": &"ranged_speed_pct",       "effect_value": 0.05},
			{"id": &"ranged_pierce", "display_name": "Quill-Shot",   "description": "+15% chance to pierce one extra target per rank.", "tier": 3, "column": 1, "max_ranks": 4, "prerequisites": [&"ranged_aim"], "effect_id": &"projectile_pierce_chance", "effect_value": 0.15},
			{"id": &"ranged_save",   "display_name": "Frugal Quiver","description": "+15% ammo-save chance per rank.", "tier": 4, "column": 0, "max_ranks": 3, "prerequisites": [&"ranged_pierce"], "effect_id": &"ammo_save_chance",       "effect_value": 0.15},
			{"id": &"ranged_capstone","display_name": "Eye of the Walker","description": "+25% ranged damage. Capstone.","tier": 5, "column": 1, "max_ranks": 1, "prerequisites": [&"ranged_save", &"ranged_speed"], "effect_id": &"ranged_damage_pct",   "effect_value": 0.25},
		],
	},
	{
		"skill_id": &"skill_vitality",
		"display_name": "Vitality",
		"lore_name": "Anchoring",
		"nodes": [
			{"id": &"vit_hp_1",   "display_name": "Stoneblood",     "description": "+15 max HP per rank.",         "tier": 1, "column": 1, "max_ranks": 5, "prerequisites": [],              "effect_id": &"max_hp_flat",                 "effect_value": 15.0},
			{"id": &"vit_armor",  "display_name": "Granite Skin",   "description": "+3 armor per rank.",           "tier": 2, "column": 0, "max_ranks": 5, "prerequisites": [&"vit_hp_1"], "effect_id": &"armor_flat",                  "effect_value": 3.0},
			{"id": &"vit_thorns", "display_name": "Reflected Rage", "description": "+2 thorns damage per rank.",   "tier": 2, "column": 2, "max_ranks": 5, "prerequisites": [&"vit_hp_1"], "effect_id": &"thorns_flat",                 "effect_value": 2.0},
			{"id": &"vit_kb",     "display_name": "Rooted",         "description": "+10% knockback resist per rank.","tier":3, "column": 1, "max_ranks": 3, "prerequisites": [&"vit_armor"], "effect_id": &"knockback_resistance_flat",   "effect_value": 0.10},
			{"id": &"vit_regen",  "display_name": "Slow Knitting",  "description": "+1 HP/sec regen per rank.",    "tier": 4, "column": 0, "max_ranks": 3, "prerequisites": [&"vit_kb"],   "effect_id": &"regen_per_second",            "effect_value": 1.0},
			{"id": &"vit_capstone","display_name":"Sliver-Eater",   "description": "+50 max HP. Capstone.",        "tier": 5, "column": 1, "max_ranks": 1, "prerequisites": [&"vit_regen", &"vit_thorns"], "effect_id": &"max_hp_flat",                 "effect_value": 50.0},
		],
	},
	{
		"skill_id": &"skill_crafting",
		"display_name": "Crafting",
		"lore_name": "Form-Making",
		"nodes": [
			{"id": &"craft_speed_1",  "display_name": "Quick Form",       "description": "+10% craft speed per rank.",                "tier": 1, "column": 1, "max_ranks": 5, "prerequisites": [],                  "effect_id": &"craft_speed_pct",         "effect_value": 0.10},
			{"id": &"craft_cost",     "display_name": "Lean Hands",       "description": "+5% chance to refund one input per rank.",  "tier": 2, "column": 0, "max_ranks": 5, "prerequisites": [&"craft_speed_1"], "effect_id": &"craft_cost_reduction",    "effect_value": 0.05},
			{"id": &"craft_quality",  "display_name": "Resonant Touch",   "description": "+5% chance to roll +1 rarity per rank.",    "tier": 3, "column": 2, "max_ranks": 4, "prerequisites": [&"craft_cost"],     "effect_id": &"craft_quality_chance",    "effect_value": 0.05},
			{"id": &"craft_radius",   "display_name": "Wide Bench",       "description": "+25% workstation adjacency radius per rank.", "tier": 4, "column": 1, "max_ranks": 3, "prerequisites": [&"craft_quality"], "effect_id": &"workstation_radius_pct",  "effect_value": 0.25},
			{"id": &"craft_capstone", "display_name": "Form-Master",      "description": "+25% mining speed at workstations. Capstone.", "tier": 5, "column": 1, "max_ranks": 1, "prerequisites": [&"craft_radius"],  "effect_id": &"mining_speed_pct",        "effect_value": 0.25},
		],
	},
	{
		"skill_id": &"skill_gardening",
		"display_name": "Gardening",
		"lore_name": "Tending",
		"nodes": [
			{"id": &"garden_growth",  "display_name": "Patient Tending", "description": "+8% crop growth speed per rank.",  "tier": 1, "column": 1, "max_ranks": 5, "prerequisites": [],                "effect_id": &"crop_growth_pct",   "effect_value": 0.08},
			{"id": &"garden_yield",   "display_name": "Plenty",          "description": "+10% crop yield per rank.",        "tier": 2, "column": 0, "max_ranks": 5, "prerequisites": [&"garden_growth"], "effect_id": &"crop_yield_pct",    "effect_value": 0.10},
			{"id": &"garden_water",   "display_name": "Slow Stream",     "description": "+25% water-can radius per rank.",  "tier": 2, "column": 2, "max_ranks": 3, "prerequisites": [&"garden_growth"], "effect_id": &"water_radius_pct",  "effect_value": 0.25},
			{"id": &"garden_save",    "display_name": "Saved Seed",      "description": "+10% seed-save chance per rank.",  "tier": 3, "column": 1, "max_ranks": 4, "prerequisites": [&"garden_yield"], "effect_id": &"seed_save_chance",  "effect_value": 0.10},
			{"id": &"garden_capstone","display_name": "Verdancy's Gift", "description": "+50% crop yield. Capstone.",       "tier": 5, "column": 1, "max_ranks": 1, "prerequisites": [&"garden_save"],  "effect_id": &"crop_yield_pct",    "effect_value": 0.50},
		],
	},
	{
		"skill_id": &"skill_fishing",
		"display_name": "Fishing",
		"lore_name": "Listening",
		"nodes": [
			{"id": &"fish_bite",     "display_name": "Patient Float",   "description": "+10% bite chance per rank.",     "tier": 1, "column": 1, "max_ranks": 5, "prerequisites": [],              "effect_id": &"fish_bite_pct",     "effect_value": 0.10},
			{"id": &"fish_quality",  "display_name": "Sharp Eye",       "description": "+8% catch quality per rank.",    "tier": 2, "column": 0, "max_ranks": 5, "prerequisites": [&"fish_bite"], "effect_id": &"fish_quality_pct",  "effect_value": 0.08},
			{"id": &"fish_size",     "display_name": "Big Net",         "description": "+10% fish-size roll per rank.",  "tier": 3, "column": 2, "max_ranks": 4, "prerequisites": [&"fish_quality"], "effect_id": &"fish_size_pct",     "effect_value": 0.10},
			{"id": &"fish_rare",     "display_name": "Listening Hour",  "description": "+5% rare-fish chance per rank.", "tier": 4, "column": 1, "max_ranks": 4, "prerequisites": [&"fish_size"],  "effect_id": &"rare_fish_chance",  "effect_value": 0.05},
			{"id": &"fish_capstone", "display_name": "Drowned-Kin",     "description": "+25% rare-fish chance. Capstone.","tier":5, "column": 1, "max_ranks": 1, "prerequisites": [&"fish_rare"],  "effect_id": &"rare_fish_chance",  "effect_value": 0.25},
		],
	},
	{
		"skill_id": &"skill_cooking",
		"display_name": "Cooking",
		"lore_name": "Hearth",
		"nodes": [
			{"id": &"cook_duration", "display_name": "Slow Brew",    "description": "+15% food buff duration per rank.","tier": 1, "column": 1, "max_ranks": 5, "prerequisites": [],                "effect_id": &"food_buff_duration_pct", "effect_value": 0.15},
			{"id": &"cook_heal",     "display_name": "Warm Hearth",  "description": "+10% food heal per rank.",         "tier": 2, "column": 0, "max_ranks": 5, "prerequisites": [&"cook_duration"], "effect_id": &"food_heal_pct",          "effect_value": 0.10},
			{"id": &"cook_discover", "display_name": "Open Pot",     "description": "+5% recipe discover chance per rank.", "tier": 2, "column": 2, "max_ranks": 5, "prerequisites": [&"cook_duration"], "effect_id": &"recipe_discover_chance", "effect_value": 0.05},
			{"id": &"cook_xp",       "display_name": "Apprentice's Pot","description":"+12% cooking XP per rank.",      "tier": 3, "column": 1, "max_ranks": 3, "prerequisites": [&"cook_heal"],     "effect_id": &"cooking_xp_pct",         "effect_value": 0.12},
			{"id": &"cook_capstone", "display_name": "Cantor's Loaf", "description":"+50% food buff duration. Capstone.","tier":5, "column": 1, "max_ranks": 1, "prerequisites": [&"cook_xp"],       "effect_id": &"food_buff_duration_pct", "effect_value": 0.50},
		],
	},
	{
		"skill_id": &"skill_magic",
		"display_name": "Magic",
		"lore_name": "Resonance",
		"nodes": [
			{"id": &"magic_dmg",     "display_name": "Loud Resonance", "description": "+8% magic damage per rank.",         "tier": 1, "column": 1, "max_ranks": 5, "prerequisites": [],              "effect_id": &"magic_damage_pct",    "effect_value": 0.08},
			{"id": &"magic_mana",    "display_name": "Deep Well",      "description": "+8 max mana per rank.",              "tier": 2, "column": 0, "max_ranks": 5, "prerequisites": [&"magic_dmg"], "effect_id": &"mana_max_flat",       "effect_value": 8.0},
			{"id": &"magic_regen",   "display_name": "Slow Hum",       "description": "+0.5/sec mana regen per rank.",      "tier": 2, "column": 2, "max_ranks": 5, "prerequisites": [&"magic_dmg"], "effect_id": &"mana_regen_flat",     "effect_value": 0.5},
			{"id": &"magic_cost",    "display_name": "Quiet Cast",     "description": "-5% mana cost per rank.",            "tier": 3, "column": 1, "max_ranks": 4, "prerequisites": [&"magic_mana"], "effect_id": &"mana_cost_reduction", "effect_value": 0.05},
			{"id": &"magic_capstone","display_name": "Twin-Loom Voice","description": "+30% magic damage. Capstone.",       "tier": 5, "column": 1, "max_ranks": 1, "prerequisites": [&"magic_cost"], "effect_id": &"magic_damage_pct",    "effect_value": 0.30},
		],
	},
	{
		"skill_id": &"skill_summoning",
		"display_name": "Summoning",
		"lore_name": "Calling",
		"nodes": [
			{"id": &"sum_dmg",     "display_name": "Sharper Calls",  "description": "+10% summon damage per rank.",   "tier": 1, "column": 1, "max_ranks": 5, "prerequisites": [],          "effect_id": &"summon_damage_pct",   "effect_value": 0.10},
			{"id": &"sum_hp",      "display_name": "Stronger Echo",  "description": "+15% summon HP per rank.",       "tier": 2, "column": 0, "max_ranks": 5, "prerequisites": [&"sum_dmg"], "effect_id": &"summon_hp_pct",       "effect_value": 0.15},
			{"id": &"sum_dur",     "display_name": "Long Voice",     "description": "+10% summon duration per rank.", "tier": 2, "column": 2, "max_ranks": 5, "prerequisites": [&"sum_dmg"], "effect_id": &"summon_duration_pct", "effect_value": 0.10},
			{"id": &"sum_slot",    "display_name": "Extra Throat",   "description": "+1 summon slot per rank.",       "tier": 4, "column": 1, "max_ranks": 2, "prerequisites": [&"sum_hp"],  "effect_id": &"summon_slot_extra",   "effect_value": 1.0},
			{"id": &"sum_capstone","display_name": "Bound Choir",    "description": "+40% summon damage. Capstone.",  "tier": 5, "column": 1, "max_ranks": 1, "prerequisites": [&"sum_slot"], "effect_id": &"summon_damage_pct",   "effect_value": 0.40},
		],
	},
	{
		"skill_id": &"skill_explosives",
		"display_name": "Explosives",
		"lore_name": "Bursting",
		"nodes": [
			{"id": &"exp_dmg",     "display_name": "Heavy Powder",  "description": "+10% explosion damage per rank.",     "tier": 1, "column": 1, "max_ranks": 5, "prerequisites": [],          "effect_id": &"explosive_damage_pct",  "effect_value": 0.10},
			{"id": &"exp_radius",  "display_name": "Wide Burst",    "description": "+10% explosion radius per rank.",     "tier": 2, "column": 0, "max_ranks": 5, "prerequisites": [&"exp_dmg"], "effect_id": &"explosive_radius_pct",  "effect_value": 0.10},
			{"id": &"exp_fuse",    "display_name": "Short Fuse",    "description": "-15% bomb fuse time per rank.",       "tier": 2, "column": 2, "max_ranks": 4, "prerequisites": [&"exp_dmg"], "effect_id": &"bomb_fuse_reduction",   "effect_value": 0.15},
			{"id": &"exp_save",    "display_name": "Lucky Wick",    "description": "+10% bomb-save chance per rank.",     "tier": 3, "column": 1, "max_ranks": 4, "prerequisites": [&"exp_radius"], "effect_id": &"bomb_save_chance",      "effect_value": 0.10},
			{"id": &"exp_capstone","display_name": "Burst-Walker",  "description": "+40% explosion damage. Capstone.",    "tier": 5, "column": 1, "max_ranks": 1, "prerequisites": [&"exp_save", &"exp_fuse"], "effect_id": &"explosive_damage_pct",  "effect_value": 0.40},
		],
	},
]
