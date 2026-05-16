extends Resource
class_name LootTable

## A weighted set of possible item drops. Roll once with `roll(rng)` to get an
## array of (item_id, count) pairs.
##
## Phase 2.47 — randomized counts come for free from `min..max` per entry.
## Phase 7.19 — Luck adds bonus rolls via `LuckSystem.bonus_drop_count()`. The
## caller can opt in by passing `apply_luck=true`.

@export var guaranteed_drops: Array[Dictionary] = []
@export var weighted_drops: Array[Dictionary] = []
@export var max_rolls: int = 1


func roll(rng: RandomNumberGenerator = null, apply_luck: bool = true) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var results: Array = []
	for guaranteed in guaranteed_drops:
		var item_id: StringName = StringName(guaranteed.get("item_id", ""))
		if item_id == &"":
			continue
		var min_c: int = int(guaranteed.get("min", 1))
		var max_c: int = int(guaranteed.get("max", min_c))
		results.append({"item_id": item_id, "count": rng.randi_range(min_c, max_c)})
	if weighted_drops.is_empty():
		return results
	var total_weight: float = 0.0
	for w in weighted_drops:
		total_weight += float(w.get("weight", 1.0))
	if total_weight <= 0.0:
		return results
	# Phase 7.19 — Luck grants additional rolls. Each `LUCK_PER_BONUS_DROP`
	# luck = +1 extra random pick.
	var effective_rolls: int = max_rolls
	if apply_luck and Engine.get_main_loop() is SceneTree:
		var ls: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null(^"/root/LuckSystem")
		if ls and ls.has_method("bonus_drop_count"):
			effective_rolls += int(ls.call("bonus_drop_count"))
	for _i in range(effective_rolls):
		var roll_value: float = rng.randf() * total_weight
		var cumulative: float = 0.0
		for entry in weighted_drops:
			cumulative += float(entry.get("weight", 1.0))
			if roll_value <= cumulative:
				var item_id: StringName = StringName(entry.get("item_id", ""))
				if item_id == &"":
					break
				var min_c: int = int(entry.get("min", 1))
				var max_c: int = int(entry.get("max", min_c))
				results.append({"item_id": item_id, "count": rng.randi_range(min_c, max_c)})
				break
	return results
