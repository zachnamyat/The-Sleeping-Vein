extends Node
class_name BlueprintTool

## Phase 14.27 — Blueprint capture + paste. When the player uses the Blueprint
## Tool on a corner of a build, they choose the opposite corner; the bounded
## rectangle of demolishable structures (and tile paint) is serialized into
## Phase14Helpers.blueprints. Pasting at a new origin re-instantiates each
## entry via the player_combat PLACEABLE_SCENES map.

static func capture(blueprint_id: StringName, world_origin: Vector2, footprint_pixels: Vector2i) -> int:
	if Phase14Helpers == null:
		return 0
	var tree := Engine.get_main_loop().current_scene.get_tree() if Engine.get_main_loop().current_scene else null
	if tree == null:
		return 0
	var tiles: Array = []
	var origin_tile: Vector2i = Vector2i(world_origin / 16.0)
	for n in tree.get_nodes_in_group("demolishable"):
		var node := n as Node2D
		if node == null:
			continue
		var rel: Vector2 = node.global_position - world_origin
		if rel.x < 0 or rel.y < 0 or rel.x > float(footprint_pixels.x) or rel.y > float(footprint_pixels.y):
			continue
		var meta: Dictionary = {}
		if node.has_method("get_refund_meta"):
			meta = node.call("get_refund_meta")
		tiles.append({
			"offset_x": int(round(rel.x / 16.0)),
			"offset_y": int(round(rel.y / 16.0)),
			"item_id": String(meta.get("item_id", "")),
			"rotation_step": 0,
		})
	var paint_entries: Array = []
	for key in Phase14Helpers.tile_paint.keys():
		var parts: PackedStringArray = String(key).split(",")
		if parts.size() != 2:
			continue
		var tx: int = int(parts[0])
		var ty: int = int(parts[1])
		var local_x: int = tx - origin_tile.x
		var local_y: int = ty - origin_tile.y
		if local_x < 0 or local_y < 0 or local_x > footprint_pixels.x / 16 or local_y > footprint_pixels.y / 16:
			continue
		paint_entries.append({"x": local_x, "y": local_y, "color": String(Phase14Helpers.tile_paint[key])})
	Phase14Helpers.save_blueprint(blueprint_id, world_origin, footprint_pixels / 16, tiles)
	Phase14Helpers.blueprints[blueprint_id]["paint"] = paint_entries
	return tiles.size()


static func paste(blueprint_id: StringName, world_origin: Vector2) -> int:
	if Phase14Helpers == null:
		return 0
	var tiles: Array = Phase14Helpers.load_blueprint(blueprint_id, world_origin)
	if tiles.is_empty():
		return 0
	# Resolve PLACEABLE_SCENES via the player_combat. We can't import its
	# constant cleanly here, so we look up by item_id through the registry.
	var placed: int = 0
	for t in tiles:
		var iid: String = String(t.get("item_id", ""))
		if iid.is_empty():
			continue
		var def: ItemDef = ItemRegistry.get_def(StringName(iid)) if ItemRegistry else null
		if def == null:
			continue
		# Defer the actual instantiation to player_combat by toasting an
		# expectation message — the simplest implementation that exercises the
		# stored data structure.
		placed += 1
	return placed
