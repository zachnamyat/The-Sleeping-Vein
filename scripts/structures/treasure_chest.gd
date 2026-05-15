extends "res://scripts/structures/chest.gd"
class_name TreasureChest

## Phase 4.23 — pre-placed treasure chest with a rolled rare-loot table on
## first-open. Inherits Chest's deposit/withdraw/save behaviour; the only
## difference is the `_initial_loot_table` plus a locked-state flag for
## Phase 4.25 skeleton-key gating.

@export var loot_table_id: StringName = &"treasure_basic"
@export var requires_key: bool = false

var _initialized: bool = false


func _ready() -> void:
	super()
	add_to_group("treasure_chest")
	# Delay rolling until the first time it's actually opened — that way the
	# table reads ItemRegistry after the autoload boot order.
	opened.connect(_on_first_open)


func _on_first_open(_chest: Chest) -> void:
	if _initialized:
		return
	if requires_key:
		if Inventory.count_of(&"skeleton_key") <= 0:
			EventBus.ui_toast.emit("Locked. Find a Skeleton Key.", 2.0)
			return
		Inventory.try_remove(&"skeleton_key", 1)
		requires_key = false
		EventBus.ui_toast.emit("The key turns. The chest pops open.", 2.0)
	_initialized = true
	_roll_loot()


func _roll_loot() -> void:
	# Phase 4.23 — minimum-viable rare drops. A full LootTable resource lookup
	# can replace this when treasure loot tables ship in Phase 4.x polish.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var picks: Array[Dictionary] = [
		{"item_id": &"shaleseed_ingot", "count": rng.randi_range(2, 5)},
		{"item_id": &"ancient_coin", "count": rng.randi_range(8, 20)},
		{"item_id": &"aphelion_fragment", "count": rng.randi_range(1, 2)},
		{"item_id": &"glow_tube", "count": rng.randi_range(2, 4)},
	]
	if rng.randf() < 0.35:
		picks.append({"item_id": &"bound_compass", "count": 1})
	if rng.randf() < 0.20:
		picks.append({"item_id": &"world_scanner", "count": 1})
	for p in picks:
		deposit(StringName(p["item_id"]), int(p["count"]))
