extends Node

## Boss spawn director. Places one boss per biome at a fixed angle around the
## Anchor at the biome's distance. Bosses spawn into the world after the player
## crosses into the biome (lazy spawn) and persist (defeated bosses don't respawn).

const BOSS_PLACEMENTS: Array[Dictionary] = [
	{
		"id": &"boss_glaurem",
		"def_path": "res://resources/mobs/glaurem.tres",
		"distance_tiles": 40.0,
		"angle_degrees": 90.0,
	},
	{
		"id": &"boss_vorrkell",
		"def_path": "res://resources/mobs/vorrkell.tres",
		"distance_tiles": 120.0,
		"angle_degrees": 45.0,
	},
	{
		"id": &"boss_spawnmother",
		"def_path": "res://resources/mobs/spawnmother.tres",
		"distance_tiles": 200.0,
		"angle_degrees": 0.0,
	},
	{
		"id": &"boss_sythrenn",
		"def_path": "res://resources/mobs/sythrenn.tres",
		"distance_tiles": 270.0,
		"angle_degrees": 315.0,
	},
	{
		"id": &"boss_auriax",
		"def_path": "res://resources/mobs/auriax.tres",
		"distance_tiles": 295.0,
		"angle_degrees": 285.0,
	},
	{
		"id": &"boss_volthaar",
		"def_path": "res://resources/mobs/volthaar.tres",
		"distance_tiles": 360.0,
		"angle_degrees": 250.0,
	},
	{
		"id": &"boss_drowned_crown",
		"def_path": "res://resources/mobs/drowned_crown.tres",
		"distance_tiles": 380.0,
		"angle_degrees": 270.0,
	},
	{
		"id": &"boss_skoldur",
		"def_path": "res://resources/mobs/skoldur.tres",
		"distance_tiles": 440.0,
		"angle_degrees": 215.0,
	},
	{
		"id": &"boss_naeren",
		"def_path": "res://resources/mobs/naeren.tres",
		"distance_tiles": 520.0,
		"angle_degrees": 180.0,
	},
	{
		"id": &"boss_veyl_aurora",
		"def_path": "res://resources/mobs/veyl_aurora.tres",
		"distance_tiles": 600.0,
		"angle_degrees": 145.0,
	},
	{
		"id": &"boss_diadem_bearer",
		"def_path": "res://resources/mobs/diadem_bearer.tres",
		"distance_tiles": 680.0,
		"angle_degrees": 110.0,
	},
]

const BOSS_TEMPLATE_PATH: String = "res://scenes/enemies/glaurem.tscn"
const PROXIMITY_TILES: float = 64.0

var _spawned: Dictionary = {}
var _player: Node2D
var _template: PackedScene


func _ready() -> void:
	_template = load(BOSS_TEMPLATE_PATH) as PackedScene
	set_process(true)


const PREP_PANEL_RADIUS_TILES: float = 18.0


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("player")
		if players.is_empty():
			return
		_player = players[0]
	for entry in BOSS_PLACEMENTS:
		var id: StringName = entry["id"]
		var pos: Vector2 = _world_position(entry["distance_tiles"], entry["angle_degrees"])
		# Phase 5.38 — surface the prep panel when the player crosses the arena
		# soft perimeter (does NOT engage the boss yet — the player must walk
		# into the detection_radius to do that).
		var dist: float = _player.global_position.distance_to(pos)
		if dist < PREP_PANEL_RADIUS_TILES * 16.0 and not GameState.has_defeated_boss(id):
			_try_show_prep_panel(id)
		if _spawned.get(id, false):
			continue
		if GameState.has_defeated_boss(id):
			continue
		if dist > PROXIMITY_TILES * 16.0:
			continue
		_spawn_boss(entry, pos)
		_spawned[id] = true


func _try_show_prep_panel(boss_id: StringName) -> void:
	for panel in (Engine.get_main_loop() as SceneTree).get_nodes_in_group("boss_prep_panel"):
		if panel.has_method("show_for"):
			panel.call("show_for", boss_id)
			return


func _world_position(distance_tiles: float, angle_degrees: float) -> Vector2:
	var rad: float = deg_to_rad(angle_degrees)
	return Vector2(cos(rad), sin(rad)) * distance_tiles * 16.0


func _spawn_boss(entry: Dictionary, pos: Vector2) -> void:
	if _template == null:
		return
	var def := load(entry["def_path"]) as MobDef
	if def == null:
		push_warning("BossDirector: missing mob_def at %s" % entry["def_path"])
		return
	var instance := _template.instantiate() as Boss
	if instance == null:
		return
	instance.mob_def = def
	instance.boss_id = entry["id"]
	instance.global_position = pos
	# NG+ scaling: +30% HP per cycle.
	if GameState.ng_plus and GameState.ng_plus_cycles > 0:
		var hc := instance.get_node_or_null("HealthComponent") as HealthComponent
		if hc:
			hc.max_health = int(round(def.max_health * (1.0 + 0.3 * GameState.ng_plus_cycles)))
			hc.current_health = hc.max_health
	var entities := _entities_layer()
	if entities:
		entities.add_child(instance)
	_spawn_arena(pos, def)


func _spawn_arena(pos: Vector2, def: MobDef) -> void:
	var arena_scn := load("res://scenes/enemies/boss_arena.tscn") as PackedScene
	if arena_scn == null:
		return
	var arena := arena_scn.instantiate() as BossArena
	if arena == null:
		return
	arena.global_position = pos
	var sprite_size: int = def.sprite_size.x if def else 64
	arena.radius_tiles = maxi(6, sprite_size / 12)
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene:
		var floor_layer := tree.current_scene.get_node_or_null("WorldGen/Floor") as Node2D
		if floor_layer:
			floor_layer.add_child(arena)
		else:
			tree.current_scene.add_child(arena)


func _entities_layer() -> Node2D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null("WorldGen/YSortRoot/Entities") as Node2D


## Phase 5.17 — re-fight summoning entry point. Boss-altars call into this so
## the player can re-engage a defeated Sovereign for trinkets / titles. The
## defeated record on GameState is *not* cleared; this is a re-spawn, not an
## un-kill, so drops scale down to a re-fight loot rule (which sits in the
## per-boss _drop_boss_loot fallback when GameState.has_defeated_boss is true —
## not strictly enforced in MVP; the boss still drops the standard table).
func respawn_boss(boss_id: StringName, at_world_pos: Vector2) -> bool:
	if _template == null:
		return false
	var entry: Dictionary = {}
	for e in BOSS_PLACEMENTS:
		if e["id"] == boss_id:
			entry = e
			break
	if entry.is_empty():
		return false
	_spawn_boss(entry, at_world_pos)
	# Clear the per-session spawned flag so the altar can spawn it again later.
	_spawned[boss_id] = false
	return true
