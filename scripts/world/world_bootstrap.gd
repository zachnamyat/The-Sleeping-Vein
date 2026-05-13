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
	# If we got here via Load, the SaveSystem already restored Inventory + Skills
	# and queued a position fix-up. Skip the starter-grant so we don't double-stack.
	var loading_save: bool = SaveSystem.consume_pending_load()
	_spawn_player()
	if not loading_save:
		_grant_starting_inventory()
		_spawn_starter_trees()


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
