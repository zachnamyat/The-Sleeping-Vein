extends Area2D
class_name MobSpawner

## Phase 4.17 / 4.59 — destructible enemy generator. Ticks every SPAWN_INTERVAL
## seconds while alive and a player is within DETECT_RADIUS_TILES; spawns up to
## `cap` mobs from `mob_spawn_table` in a small radius. HP is mined like a wall
## (player_combat resolves clicks against any node with HitboxComponent in the
## "wall_layer" group). Tier 2/3 variants override `tier` for elite spawns (4.59).

const MAX_SPAWN_PER_TICK: int = 1
const SPAWN_INTERVAL: float = 4.0
const DETECT_RADIUS_TILES: float = 12.0
const SPAWN_RADIUS_PX: float = 64.0
const TILE_PX: int = 16

@export var tier: int = 1
@export var max_alive_children: int = 3
@export var hp: int = 80
@export var mob_spawn_table: Array[StringName] = [&"stone_hopper"]
@export var mob_scene_paths: Dictionary = {
	&"stone_hopper": "res://scenes/enemies/stone_hopper.tscn",
}

var _accum: float = 0.0
var _alive_children: Array[Node2D] = []


func _ready() -> void:
	add_to_group("mob_spawner")
	# Phase 4.16 — mob_spawner has its own HP and is mined like a wall; the
	# wall_layer group lets player_combat hit-resolve through the same path.
	add_to_group("wall_layer")
	set_process(true)


func _process(delta: float) -> void:
	# GC dead children.
	for i in range(_alive_children.size() - 1, -1, -1):
		var c := _alive_children[i]
		if c == null or not is_instance_valid(c):
			_alive_children.remove_at(i)
	if _alive_children.size() >= max_alive_children:
		return
	if not _player_nearby():
		return
	_accum += delta
	if _accum < SPAWN_INTERVAL:
		return
	_accum = 0.0
	_spawn_one()


func _player_nearby() -> bool:
	for p in get_tree().get_nodes_in_group("player"):
		if not (p is Node2D):
			continue
		var dist: float = (p as Node2D).global_position.distance_to(global_position) / float(TILE_PX)
		if dist <= DETECT_RADIUS_TILES:
			return true
	return false


func _spawn_one() -> void:
	if mob_spawn_table.is_empty():
		return
	var pick: StringName = mob_spawn_table[randi() % mob_spawn_table.size()]
	var path: String = mob_scene_paths.get(pick, "")
	if path == "":
		return
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		return
	var mob := scene.instantiate() as Node2D
	if mob == null:
		return
	var angle: float = randf() * TAU
	var radius: float = randf_range(24.0, SPAWN_RADIUS_PX)
	mob.global_position = global_position + Vector2(cos(angle), sin(angle)) * radius
	# Phase 2.32 / 2.33 — roll for elite/champion affixes BEFORE adopting into
	# the tree, so Mob._ready can read the metadata.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Tier-2/3 spawners (4.59 elite spawn rings) get extra elite bias.
	if tier >= 2:
		rng.seed = int(Time.get_unix_time_from_system() * 1000.0) % 1000003
	var roll: Dictionary = MobAffixes.roll_for_spawn(rng)
	# Tier 2/3 spawners always upgrade to at least elite.
	if tier >= 2 and roll.get("tier", "normal") == "normal":
		roll = {"tier": "elite", "affix": MobAffixes.AFFIX_DEFS[rng.randi() % MobAffixes.AFFIX_DEFS.size()]}
	if tier >= 3 and roll.get("tier", "normal") != "champion":
		roll = {
			"tier": "champion",
			"affix1": MobAffixes.AFFIX_DEFS[rng.randi() % MobAffixes.AFFIX_DEFS.size()],
			"affix2": MobAffixes.AFFIX_DEFS[rng.randi() % MobAffixes.AFFIX_DEFS.size()],
		}
	MobAffixes.apply(mob, roll)
	_alive_children.append(mob)
	# Phase 4.16 — adopt the mob into the entity layer so y-sort works the
	# same as world-spawned mobs.
	var parent: Node = get_parent()
	while parent and not parent.is_in_group("entity_layer"):
		parent = parent.get_parent()
	if parent == null:
		parent = get_parent()
	parent.add_child(mob)


func apply_damage(amount: int, _source: Node = null, _type: StringName = &"physical") -> void:
	hp -= maxi(1, amount)
	if hp <= 0:
		_destroy()


func _destroy() -> void:
	# Drop a small reward.
	EventBus.ui_toast.emit("Spawner destroyed.", 1.5)
	if AudioBus:
		AudioBus.play_sfx(&"break_stone")
	queue_free()
