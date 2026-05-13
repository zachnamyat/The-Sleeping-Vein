extends Resource
class_name Recipe

## Data-driven recipe. Inputs are an array of {item_id, count}; outputs same.
## Stations: an empty array means craftable anywhere (player inventory craft).
## Workbench list lore-aligned to docs/design/02_lore_to_mechanics_mapping.md §5.

@export var id: StringName = &""
@export var display_name: String = ""
@export var inputs: Array[Dictionary] = []
@export var outputs: Array[Dictionary] = []
@export var stations: Array[StringName] = []
@export var skill_xp_grant: int = 1
@export var skill_xp_id: StringName = &"skill_crafting"
@export var unlock_on_pickup: Array[StringName] = []
@export var unlock_on_boss_kill: Array[StringName] = []
@export var craft_time_seconds: float = 0.0
@export var description: String = ""


func can_craft(inventory_counts: Callable) -> bool:
	for inp in inputs:
		var item_id: StringName = StringName(inp.get("item_id", ""))
		var need: int = int(inp.get("count", 1))
		if inventory_counts.call(item_id) < need:
			return false
	return true
