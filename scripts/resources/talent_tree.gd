extends Resource
class_name TalentTree

## Phase 7.1 — Data-driven talent tree.
## One resource per skill. Stored as .tres in resources/skills/talent_trees/.
##
## Each tree has up to N nodes; each node is a Dictionary with:
##   - id              StringName, e.g. &"mining_stratabreak_1"
##   - display_name    String shown in the tooltip header
##   - description     String shown in the tooltip body (1-2 sentences)
##   - tier            int 1..5; visual row in the tree
##   - column          int 0..2; visual column (left/center/right branch)
##   - max_ranks       int how many talent points may be spent on this node
##   - prerequisites   Array[StringName] of node ids that must be ranked first
##   - effect_id       StringName key into TalentEffects (see talent_effects.gd)
##   - effect_value    float magnitude consumed by the effect handler
##   - skill_id        StringName the parent skill (e.g. &"skill_mining"). Set
##                     automatically by the loader so it matches the resource.
##
## The resource is intentionally schema-less Dictionary entries so we can iterate
## quickly on talent design without bumping the parser every change.

@export var skill_id: StringName = &""
@export var display_name: String = ""
@export var lore_name: String = ""
## Stored as untyped Array of Dictionary entries so the const tree literals in
## TalentRegistry assign cleanly without strict Array[Dictionary] casting.
@export var nodes: Array = []


func node_by_id(node_id: StringName) -> Dictionary:
	for n in nodes:
		if StringName(n.get("id", "")) == node_id:
			return n
	return {}


func tier_for(node_id: StringName) -> int:
	var d := node_by_id(node_id)
	return int(d.get("tier", 1))


func max_ranks_for(node_id: StringName) -> int:
	var d := node_by_id(node_id)
	return int(d.get("max_ranks", 1))


func prerequisites_for(node_id: StringName) -> Array:
	var d := node_by_id(node_id)
	return d.get("prerequisites", [])


func effect_value_for(node_id: StringName) -> float:
	var d := node_by_id(node_id)
	return float(d.get("effect_value", 0.0))


func effect_id_for(node_id: StringName) -> StringName:
	var d := node_by_id(node_id)
	return StringName(d.get("effect_id", ""))
