extends Node

## Phase 8.15 — Bug-net + ambient critter collection. Spawns a small flock of
## passive critters in the Root Hollows per beat cycle that the player can
## net with the Bug Net (a no-damage tool). Caught critters land in the
## inventory and slot into the Aquarium / display tank (ticket 8.14).

signal critter_caught(critter_id: StringName)

const SPAWN_PER_BEAT: int = 1
const MAX_ACTIVE: int = 12

const CRITTER_TABLE: Array = [
	{ "id": &"critter_glow_moth",  "biome": &"root_hollows" },
	{ "id": &"critter_cave_cricket","biome": &"root_hollows" },
	{ "id": &"critter_root_ant",   "biome": &"root_hollows" },
	{ "id": &"critter_glass_beetle","biome": &"glasswright_reaches" },
	{ "id": &"critter_salt_fly",   "biome": &"vesari_necropolis" },
	{ "id": &"critter_deep_jelly", "biome": &"drowned_aphelion" },
]


func _ready() -> void:
	if AudioBus:
		AudioBus.aphelion_beat.connect(_on_beat)


func is_bug_net(item_id: StringName) -> bool:
	return item_id == &"bug_net"


func _on_beat() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	if tree.get_nodes_in_group("critter").size() >= MAX_ACTIVE:
		return
	var players := tree.get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0] as Node2D
	if player == null:
		return
	# Sample biome under the player to pick which critter species can spawn.
	var biome_id: StringName = &"root_hollows"
	var worldgen := tree.current_scene.get_node_or_null("WorldGen")
	if worldgen and worldgen.has_method("biome_at"):
		var b: BiomeDef = worldgen.biome_at(player.global_position) as BiomeDef
		if b:
			biome_id = b.id
	var pool: Array = []
	for entry in CRITTER_TABLE:
		if StringName(entry.get("biome", &"")) == biome_id:
			pool.append(entry)
	if pool.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i in range(SPAWN_PER_BEAT):
		var pick: Dictionary = pool[rng.randi() % pool.size()]
		_spawn_critter(StringName(pick.id), player.global_position, rng)


func _spawn_critter(critter_id: StringName, anchor: Vector2, rng: RandomNumberGenerator) -> void:
	var scn := load("res://scenes/critters/critter.tscn") as PackedScene
	if scn == null:
		return
	var critter := scn.instantiate() as Node2D
	if critter == null:
		return
	critter.set_meta("critter_id", critter_id)
	var angle: float = rng.randf() * TAU
	var dist: float = rng.randf_range(48.0, 96.0)
	critter.global_position = anchor + Vector2.RIGHT.rotated(angle) * dist
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene:
		tree.current_scene.add_child(critter)


## Called by Critter.gd when the bug-net's swing area covers it.
func capture(critter_node: Node2D) -> void:
	if critter_node == null or not is_instance_valid(critter_node):
		return
	var cid: StringName = StringName(critter_node.get_meta("critter_id", &""))
	if cid == &"":
		critter_node.queue_free()
		return
	Inventory.try_add(cid, 1)
	critter_caught.emit(cid)
	EventBus.skill_xp_gained.emit(&"skill_gardening", 2)
	EventBus.ui_toast.emit("Caught: %s" % String(cid).replace("critter_", "").capitalize(), 1.5)
	critter_node.queue_free()
