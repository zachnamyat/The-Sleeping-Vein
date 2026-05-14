extends Node2D
class_name WorldBootstrap

## Initializes the playable world. Phase 4: hands off to WorldGen for chunk-based
## procedural generation. Spawns player at Anchor (0,0) and grants starter items.

@export var spawn_player_scene: PackedScene
@export var stone_hopper_scene: PackedScene
@export var tree_scene: PackedScene
@export var entity_layer_path: NodePath
@export var world_gen_path: NodePath
@export var anchor_radius: int = 5


func _ready() -> void:
	# Mark layer groups so player_combat and mining can find them.
	var world := get_node_or_null(world_gen_path) as WorldGen
	if world:
		_register_layer_group(world.ore_layer_path, "ore_layer")
		_register_layer_group(world.wall_base_layer_path, "wall_layer")
		# The cap is a separate group so player_combat can redirect cap-clicks
		# to the base cell south of them, instead of treating the cap as its own
		# mineable wall (which would silently damage a different wall whose
		# base happens to sit in the cap's cell).
		_register_layer_group(world.wall_cap_layer_path, "wall_cap_layer")
	# If we got here via Load, the SaveSystem already restored Inventory + Skills
	# and queued a position fix-up. Skip the starter-grant so we don't double-stack.
	var loading_save: bool = SaveSystem.consume_pending_load()
	if not loading_save:
		# Autoloads persist across scene changes — without this reset, a second
		# New Game in the same session would inherit the prior run's inventory,
		# skills, slivers, and talents. Reset before spawning so the player
		# always wakes with the starter kit alone.
		_reset_world_state()
	_spawn_player()
	if not loading_save:
		_grant_starting_inventory()
		_spawn_starter_trees()
	else:
		_restore_chests_from_save()


func _reset_world_state() -> void:
	Inventory.clear()
	GameState.reset_for_new_game()
	for s in SkillSystem.ALL_SKILLS:
		SkillSystem._xp[s] = 0
		SkillSystem._level[s] = 0
	# reset_for_new_game cleared GameState.unlocked_recipes, so the Loam Bench
	# would otherwise have zero recipes until app restart.
	CraftingSystem.unlock_starter_recipes()


func _spawn_starter_trees() -> void:
	if tree_scene == null:
		return
	var entities := get_node_or_null(entity_layer_path) as Node2D
	if entities == null:
		return
	# Ring of trees around the Anchor plateau so the axe is immediately
	# testable. Procedural-only placement comes with Phase 4 biome work.
	var positions: Array[Vector2] = [
		Vector2(96, 0), Vector2(-96, 0), Vector2(0, 96), Vector2(0, -96),
		Vector2(80, 80), Vector2(-80, 80), Vector2(80, -80), Vector2(-80, -80),
	]
	for pos in positions:
		var tree := tree_scene.instantiate() as Node2D
		if tree == null:
			continue
		tree.position = pos
		entities.add_child(tree)


func _spawn_player() -> void:
	if spawn_player_scene == null:
		return
	var entities := get_node_or_null(entity_layer_path) as Node2D
	if entities == null:
		return
	var player := spawn_player_scene.instantiate() as Node2D
	player.position = Vector2.ZERO
	entities.add_child(player)
	var world := get_node_or_null(world_gen_path) as WorldGen
	if world:
		world.set_player(player)


func _grant_starting_inventory() -> void:
	Inventory.try_add(&"wooden_pickaxe", 1)
	Inventory.try_add(&"wooden_sword", 1)
	Inventory.try_add(&"wooden_axe", 1)
	Inventory.try_add(&"bomb", 3)
	Inventory.try_add(&"torch", 5)
	Inventory.try_add(&"loam", 20)


func _register_layer_group(path: NodePath, group_name: String) -> void:
	var world := get_node_or_null(world_gen_path) as Node
	if world == null:
		return
	var node := world.get_node_or_null(path)
	if node:
		node.add_to_group(group_name)


## Phase 3.6 — Match saved chest blobs to the chests currently in the scene
## tree. unique_id is the primary key; if a saved chest has no live match
## (e.g. user broke the chest pre-save), it's ignored. Future placeable-chest
## work (Phase 4+) will need to spawn missing ones.
func _restore_chests_from_save() -> void:
	var saved: Array = SaveSystem.consume_pending_chests()
	if saved.is_empty():
		return
	var live := get_tree().get_nodes_in_group("chest")
	for entry in saved:
		if not (entry is Dictionary):
			continue
		var uid := String(entry.get("unique_id", ""))
		if uid == "":
			continue
		for c in live:
			if String(c.unique_id) == uid:
				if c.has_method("restore_state"):
					c.call("restore_state", entry)
				break
