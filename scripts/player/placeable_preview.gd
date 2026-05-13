extends Node2D
class_name PlaceablePreview

## Phase 2.48 — Ghost-tile preview when the player is holding a placeable item.
## Renders the item's icon at the mouse cursor at half-opacity until the player
## right-clicks to confirm. Placement is intentionally minimal: it spawns a
## scene matching the item id where one exists, else logs a TODO. Phase 4 chunk
## work will replace this with TileMapLayer commits.

const PREVIEW_SCALE: float = 1.0
const VALID_COLOR: Color = Color(0.85, 1.00, 0.85, 0.55)
const INVALID_COLOR: Color = Color(1.0, 0.55, 0.55, 0.55)

var _sprite: Sprite2D
var _player: Node2D
var _active_id: StringName = &""


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
	_sprite.visible = false
	_sprite.z_index = 4
	add_child(_sprite)
	_player = get_parent() as Node2D
	if Inventory:
		Inventory.slot_changed.connect(_on_inventory_slot_changed)
	call_deferred("_bind_hotbar")


func _bind_hotbar() -> void:
	var hotbar := _find_hotbar()
	if hotbar:
		hotbar.selected_changed.connect(_on_hotbar_selected)
		_refresh(hotbar.selected_index)


func _on_hotbar_selected(idx: int) -> void:
	_refresh(idx)


func _on_inventory_slot_changed(idx: int, _id: StringName, _count: int) -> void:
	var hotbar := _find_hotbar()
	if hotbar == null:
		return
	if idx == hotbar.selected_index:
		_refresh(hotbar.selected_index)


func _refresh(hotbar_idx: int) -> void:
	var iid: StringName = Inventory.get_hotbar_item(hotbar_idx) if Inventory else &""
	var defn: ItemDef = ItemRegistry.get_def(iid) if iid != &"" else null
	if defn == null or defn.item_type != ItemDef.ItemType.PLACEABLE or defn.icon == null:
		_active_id = &""
		_sprite.visible = false
		return
	_active_id = iid
	_sprite.texture = defn.icon
	_sprite.visible = true


func _process(_delta: float) -> void:
	if _active_id == &"" or _sprite == null or not _sprite.visible:
		return
	# Snap the preview to the 16-tile grid under the cursor.
	var camera := get_viewport().get_camera_2d() if get_viewport() else null
	if camera == null:
		return
	var mouse := camera.get_global_mouse_position()
	var snapped := Vector2(
		floor(mouse.x / 16.0) * 16.0 + 8.0,
		floor(mouse.y / 16.0) * 16.0 + 8.0,
	)
	_sprite.global_position = snapped
	# Valid if within ~3 tiles of the player.
	var valid: bool = _player != null and snapped.distance_to(_player.global_position) <= 48.0
	_sprite.modulate = VALID_COLOR if valid else INVALID_COLOR


func _find_hotbar() -> Hotbar:
	var nodes := get_tree().get_nodes_in_group("hotbar")
	if nodes.is_empty():
		return null
	return nodes[0] as Hotbar
