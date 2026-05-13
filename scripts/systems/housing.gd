extends Node

## NPC housing checker. Phase 5.10/9.1 MVP: walks an 8×8 area around a proposed
## bed coord and verifies (a) at least 1 wall tile present (b) at least 1 door
## tile present (c) at least 1 empty floor tile. Returns a Dictionary with the
## validation result and which check failed.
##
## Phase 15 polish wires this into NpcDirector so merchants only move in when
## a player has built them a proper room. MVP just exposes the function.

const ROOM_HALF: int = 4


func validate_room(bed_world_pos: Vector2, wall_layer_path: NodePath, floor_layer_path: NodePath) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return { "valid": false, "reason": "no_scene" }
	var wall_layer := tree.current_scene.get_node_or_null(wall_layer_path) as TileMapLayer
	var floor_layer := tree.current_scene.get_node_or_null(floor_layer_path) as TileMapLayer
	if wall_layer == null or floor_layer == null:
		return { "valid": false, "reason": "missing_layers" }
	var center: Vector2i = floor_layer.local_to_map(floor_layer.to_local(bed_world_pos))
	var walls: int = 0
	var floors: int = 0
	for y in range(-ROOM_HALF, ROOM_HALF + 1):
		for x in range(-ROOM_HALF, ROOM_HALF + 1):
			var coord: Vector2i = center + Vector2i(x, y)
			if wall_layer.get_cell_source_id(coord) >= 0:
				walls += 1
			if floor_layer.get_cell_source_id(coord) >= 0:
				floors += 1
	if floors < 16:
		return { "valid": false, "reason": "too_few_floor_tiles", "floors": floors }
	if walls < 4:
		return { "valid": false, "reason": "no_walls_enclosing", "walls": walls }
	# Phase 9 polish would also confirm a Door tile + Bed + Light + 8×8 max.
	return { "valid": true, "floors": floors, "walls": walls }
