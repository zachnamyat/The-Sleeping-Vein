extends Node

## Mining system. Resolves swing → tile damage on TileMapLayer cells whose
## custom-data "tile_tier" is > 0 (mineable). Tile HP is tracked per-cell in
## the `_tile_health` dict; when HP reaches 0, the cell is cleared and loot
## drops at the cell center.

signal tile_mined(coord: Vector2i, ore_id: StringName, source: Node)

const DEFAULT_TILE_HP: int = 20

var _tile_health: Dictionary = {}  ## {(layer_path:String, coord:Vector2i) -> hp:int}


func swing_on_tile(layer: TileMapLayer, world_position: Vector2, pickaxe_tier: int, mining_damage: int) -> bool:
	if layer == null:
		return false
	var cell: Vector2i = layer.local_to_map(layer.to_local(world_position))
	var source_id: int = layer.get_cell_source_id(cell)
	if source_id < 0:
		return false
	var data: TileData = layer.get_cell_tile_data(cell)
	if data == null:
		return false
	var tier: int = int(data.get_custom_data("tile_tier"))
	if tier <= 0:
		return false  # not a mineable tile
	if pickaxe_tier < tier:
		EventBus.ui_toast.emit("Pickaxe too weak (tier %d, need %d)" % [pickaxe_tier, tier], 1.5)
		return false
	var ore_id: StringName = StringName(data.get_custom_data("ore_id"))
	var key: String = "%s|%d,%d" % [layer.get_path(), cell.x, cell.y]
	var hp: int = _tile_health.get(key, DEFAULT_TILE_HP)
	hp -= maxi(1, mining_damage)
	if hp <= 0:
		_tile_health.erase(key)
		layer.set_cell(cell, -1)
		EventBus.skill_xp_gained.emit(&"skill_mining", 3 * tier)
		EventBus.tile_changed.emit(cell, source_id, -1)
		_spawn_drop(ore_id, layer.map_to_local(cell) + layer.global_position)
		tile_mined.emit(cell, ore_id, null)
		return true
	_tile_health[key] = hp
	EventBus.tile_changed.emit(cell, source_id, source_id)
	return true


func _spawn_drop(ore_id: StringName, world_pos: Vector2) -> void:
	if ore_id == &"":
		return
	var scn := load("res://scenes/items/item_drop.tscn") as PackedScene
	if scn == null:
		return
	var drop := scn.instantiate() as ItemDrop
	if drop == null:
		return
	drop.item_id = ore_id
	drop.count = 1
	drop.global_position = world_pos
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene:
		tree.current_scene.add_child(drop)
