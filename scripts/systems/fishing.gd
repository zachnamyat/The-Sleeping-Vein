extends Node

## Phase 8 fishing MVP. PlayerCombat calls `cast(player)` when the player swings
## with a fishing rod. We hold a 5-second cast then resolve a catch based on the
## biome under the player.

signal cast_started(seconds: float)
signal cast_resolved(caught_id: StringName)

const CAST_SECONDS: float = 5.0

const BIOME_CATCH_TABLE: Dictionary = {
	&"root_hollows":      [{ "id": &"cave_guppy",   "weight": 8.0 }],
	&"glasswright_reaches": [{ "id": &"cave_guppy", "weight": 5.0 }, { "id": &"lantern_glint", "weight": 1.0 }],
	&"vesari_necropolis": [{ "id": &"salt_minnow",  "weight": 6.0 }, { "id": &"cave_guppy", "weight": 2.0 }],
	&"drowned_aphelion":  [{ "id": &"salt_minnow",  "weight": 4.0 }, { "id": &"lantern_glint", "weight": 3.0 }],
}

var _casting: bool = false
var _cast_player: Node2D


func cast(player: Node2D) -> bool:
	if _casting:
		return false
	_casting = true
	_cast_player = player
	cast_started.emit(CAST_SECONDS)
	EventBus.ui_toast.emit("[Cast — wait %d seconds]" % int(CAST_SECONDS), CAST_SECONDS)
	var t := get_tree().create_timer(CAST_SECONDS)
	t.timeout.connect(_resolve)
	return true


func _resolve() -> void:
	_casting = false
	if _cast_player == null or not is_instance_valid(_cast_player):
		return
	var tree := Engine.get_main_loop() as SceneTree
	var worldgen := tree.current_scene.get_node_or_null("WorldGen") if tree and tree.current_scene else null
	var biome_id: StringName = &"root_hollows"
	if worldgen and worldgen.has_method("biome_at"):
		var biome: BiomeDef = worldgen.biome_at(_cast_player.global_position) as BiomeDef
		if biome:
			biome_id = biome.id
	var table: Array = BIOME_CATCH_TABLE.get(biome_id, BIOME_CATCH_TABLE[&"root_hollows"])
	var total: float = 0.0
	for e in table:
		total += float(e.get("weight", 1.0))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var roll: float = rng.randf() * total
	var cumulative: float = 0.0
	var caught: StringName = &""
	for e in table:
		cumulative += float(e.get("weight", 1.0))
		if roll <= cumulative:
			caught = StringName(e.get("id", ""))
			break
	if caught == &"":
		return
	Inventory.try_add(caught, 1)
	cast_resolved.emit(caught)
	EventBus.skill_xp_gained.emit(&"skill_fishing", 4)
	var defn: ItemDef = ItemRegistry.get_def(caught)
	EventBus.ui_toast.emit("Caught: %s" % (defn.display_name if defn else String(caught)), 2.0)
