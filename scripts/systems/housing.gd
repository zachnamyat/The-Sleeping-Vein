extends Node

## Phase 9.1 — NPC housing checker.
##
## Walks an 8×8 area around a candidate bed coordinate and verifies:
##   (a) enclosed by wall tiles on the perimeter (>= 80% of perimeter cells)
##   (b) >= 1 door (placeable group: "door") inside or on the perimeter
##   (c) >= 16 floor cells available
##   (d) >= 1 bed (this very bed is allowed)
##   (e) >= 1 light source (group "light_source" — torches, lanterns)
##   (f) area <= 8x8 (this is enforced by ROOM_HALF — we never scan further)
##
## Returns Dictionary { valid: bool, reason: String, walls: int, floors: int }.
## NpcLifecycle (Phase 9.1 NpcDirector) calls this when the player places a bed,
## or any time a door/bed/light is added inside an already-validated room.

const ROOM_HALF: int = 4  ## 9×9 max viewport scan; the room must fit within ±4 tiles of the bed.

signal house_validated(bed_world_pos: Vector2, npc_id: StringName)

## Bed -> NPC binding. Persistent across saves.
## { "x,y" (String) -> npc_id (String) }. Bed world-pos is the key so duplicate
## beds in different cells don't compete.
var beds_to_npc: Dictionary = {}


func _ready() -> void:
	pass


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
	var perimeter: int = 0
	var perimeter_walls: int = 0
	for y in range(-ROOM_HALF, ROOM_HALF + 1):
		for x in range(-ROOM_HALF, ROOM_HALF + 1):
			var coord: Vector2i = center + Vector2i(x, y)
			var is_perim := (abs(x) == ROOM_HALF) or (abs(y) == ROOM_HALF)
			if wall_layer.get_cell_source_id(coord) >= 0:
				walls += 1
				if is_perim:
					perimeter_walls += 1
			if floor_layer.get_cell_source_id(coord) >= 0:
				floors += 1
			if is_perim:
				perimeter += 1
	if floors < 16:
		return { "valid": false, "reason": "too_few_floor_tiles", "floors": floors, "walls": walls }
	if walls < 8:
		return { "valid": false, "reason": "no_walls_enclosing", "walls": walls, "floors": floors }
	# Phase 9.1: perimeter must be mostly walled (>= 80%).
	if perimeter > 0 and float(perimeter_walls) / float(perimeter) < 0.80:
		return { "valid": false, "reason": "perimeter_open", "walls": walls, "perimeter_walls": perimeter_walls }
	# Door check: any node in group "door" within ROOM_HALF tiles of the bed.
	var bbox := Rect2(
		bed_world_pos - Vector2(ROOM_HALF * 16, ROOM_HALF * 16),
		Vector2(ROOM_HALF * 32, ROOM_HALF * 32),
	)
	var has_door: bool = false
	for d in tree.get_nodes_in_group("door"):
		if d is Node2D and bbox.has_point((d as Node2D).global_position):
			has_door = true
			break
	if not has_door:
		return { "valid": false, "reason": "no_door", "walls": walls, "floors": floors }
	# Light check.
	var has_light: bool = false
	for l in tree.get_nodes_in_group("light_source"):
		if l is Node2D and bbox.has_point((l as Node2D).global_position):
			has_light = true
			break
	# Phase 9.41 — light pollution: too many lights penalizes mood. For room
	# validation, missing-light is only a soft fail (warning toast); the room
	# is still NPC-eligible.
	if not has_light:
		EventBus.ui_toast.emit("Room ok but unlit — NPCs prefer light.", 2.5)
	return {
		"valid": true,
		"floors": floors,
		"walls": walls,
		"has_door": has_door,
		"has_light": has_light,
		"bed_world_pos": bed_world_pos,
	}


## Phase 9.2 — bind a bed world-position to an NPC. Returns false if already
## bound to another NPC.
func bind_bed_to_npc(bed_world_pos: Vector2, npc_id: StringName) -> bool:
	var key := _bed_key(bed_world_pos)
	if beds_to_npc.has(key):
		return String(beds_to_npc[key]) == String(npc_id)
	beds_to_npc[key] = String(npc_id)
	house_validated.emit(bed_world_pos, npc_id)
	return true


func npc_for_bed(bed_world_pos: Vector2) -> StringName:
	return StringName(String(beds_to_npc.get(_bed_key(bed_world_pos), "")))


func bed_for_npc(npc_id: StringName) -> Vector2:
	for k in beds_to_npc.keys():
		if String(beds_to_npc[k]) == String(npc_id):
			return _key_to_pos(String(k))
	return Vector2.ZERO


func unbind_npc(npc_id: StringName) -> void:
	for k in beds_to_npc.keys():
		if String(beds_to_npc[k]) == String(npc_id):
			beds_to_npc.erase(k)
			return


func _bed_key(p: Vector2) -> String:
	return "%d,%d" % [int(p.x), int(p.y)]


func _key_to_pos(k: String) -> Vector2:
	var parts := k.split(",")
	if parts.size() < 2:
		return Vector2.ZERO
	return Vector2(int(parts[0]), int(parts[1]))


# ----- Save round-trip -----

func dump_state() -> Dictionary:
	return { "beds_to_npc": beds_to_npc.duplicate() }


func restore_state(d: Dictionary) -> void:
	beds_to_npc.clear()
	for k in (d.get("beds_to_npc", {}) as Dictionary).keys():
		beds_to_npc[String(k)] = String(d["beds_to_npc"][k])
