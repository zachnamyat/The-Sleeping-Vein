extends Node2D
class_name AnchorPlateau

## Marks the central player-spawn plateau at world origin. Clears walls/ore from
## a small radius around (0,0) so the Anchor reads as the player's home space.

@export var clear_radius_tiles: int = 5
@export var floor_layer_path: NodePath
@export var wall_base_layer_path: NodePath
@export var wall_cap_layer_path: NodePath
@export var ore_layer_path: NodePath


func _ready() -> void:
	# Defer a frame so the worldgen has a chance to paint first.
	await get_tree().process_frame
	_clear_anchor_circle()


func _clear_anchor_circle() -> void:
	var fl := _layer(floor_layer_path)
	var wb := _layer(wall_base_layer_path)
	var wc := _layer(wall_cap_layer_path)
	var ol := _layer(ore_layer_path)
	for y in range(-clear_radius_tiles, clear_radius_tiles + 1):
		for x in range(-clear_radius_tiles, clear_radius_tiles + 1):
			if x * x + y * y > clear_radius_tiles * clear_radius_tiles:
				continue
			if fl: fl.set_cell(Vector2i(x, y), 0, Vector2i(0, 0), 0)
			if wb: wb.set_cell(Vector2i(x, y), -1)
			if wc: wc.set_cell(Vector2i(x, y), -1)
			if ol: ol.set_cell(Vector2i(x, y), -1)


func _layer(path: NodePath) -> TileMapLayer:
	if path == NodePath():
		return null
	return get_node_or_null(path) as TileMapLayer
