extends Node

## Phase 4.34 — Glasswright Reaches crystal (Clearstone) regrowth.
##
## When a Clearstone ore tile is mined inside the Glasswright Reaches biome,
## the MiningSystem emits an EventBus.tile_changed signal. We watch for those
## changes and after `REGROWTH_BEATS` beats restore the tile (only if the
## player isn't standing on top of it). Other biomes don't regrow.
##
## Implements one of the lore-specific touches from §04: the Reaches "heal"
## themselves slowly because the Veinglass is alive.

const REGROWTH_BEATS: int = 16
const REGROW_BIOMES: Array[StringName] = [&"glasswright_reaches"]

var _pending: Dictionary = {}   ## tile_coord (Vector2i) -> { beats_left, source_id }


func _ready() -> void:
	if AudioBus:
		AudioBus.aphelion_beat.connect(_on_beat)
	EventBus.tile_changed.connect(_on_tile_changed)


func _on_tile_changed(tile_coord: Vector2i, old_id: int, new_id: int) -> void:
	# Only ore tiles that went from "present" to "empty" qualify.
	if new_id != -1 or old_id < 0:
		return
	var wg: Node = _world_gen()
	if wg == null:
		return
	var b: BiomeDef = wg.call("biome_for_chunk", Vector2i(
		floori(float(tile_coord.x) / 64.0),
		floori(float(tile_coord.y) / 64.0),
	)) as BiomeDef
	if b == null or not (b.id in REGROW_BIOMES):
		return
	if b.ore_source_id != old_id:
		return
	_pending[tile_coord] = {
		"beats_left": REGROWTH_BEATS,
		"source_id": b.ore_source_id,
	}


func _on_beat() -> void:
	if _pending.is_empty():
		return
	var wg: Node = _world_gen()
	var ore_layer: TileMapLayer = null
	if wg:
		var path: NodePath = wg.get("ore_layer_path")
		if path != NodePath():
			ore_layer = wg.get_node_or_null(path) as TileMapLayer
	if ore_layer == null:
		return
	var to_remove: Array[Vector2i] = []
	for coord in _pending.keys():
		var entry: Dictionary = _pending[coord]
		entry["beats_left"] = int(entry.get("beats_left", 0)) - 1
		if int(entry["beats_left"]) > 0:
			continue
		if _player_on_tile(coord):
			continue
		ore_layer.set_cell(coord, int(entry["source_id"]), Vector2i(0, 0), 0)
		to_remove.append(coord)
	for k in to_remove:
		_pending.erase(k)


func _player_on_tile(tile_coord: Vector2i) -> bool:
	for p in get_tree().get_nodes_in_group("player"):
		if not (p is Node2D):
			continue
		var ptile := Vector2i(
			floori((p as Node2D).global_position.x / 16.0),
			floori((p as Node2D).global_position.y / 16.0),
		)
		if ptile == tile_coord:
			return true
	return false


func _world_gen() -> Node:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null("WorldGen")
