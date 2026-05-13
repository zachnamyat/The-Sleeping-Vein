extends Resource
class_name LootTable

## A weighted set of possible item drops. Roll once with `roll(rng)` to get an
## array of (item_id, count) pairs.

@export var guaranteed_drops: Array[Dictionary] = []
@export var weighted_drops: Array[Dictionary] = []
@export var max_rolls: int = 1


func roll(rng: RandomNumberGenerator = null) -> Array:
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
	for _i in range(max_rolls):
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
