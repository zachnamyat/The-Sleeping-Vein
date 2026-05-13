extends Node2D
class_name HeldItemVisual

## Phase 3.5 / 2.36 — Renders the icon of the player's selected hotbar item
## near their hand. Listens to Hotbar.selected_changed and Inventory.slot_changed
## so the visual updates the moment you cycle hotbar slots or pick up a new
## item into the active slot.
##
## Attached as a child of PlayerController. Positions itself relative to the
## player's `facing` direction so the item appears in front of the Walker.

const RIGHT_OFFSET: Vector2 = Vector2(8, -8)
const ICON_SCALE: float = 0.6  # 16x16 icons rendered at ~10x10 to match Walker

var _sprite: Sprite2D
var _player: Node2D
var _current_item: StringName = &""


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(ICON_SCALE, ICON_SCALE)
	_sprite.z_index = 1
	add_child(_sprite)
	_player = get_parent() as Node2D
	# Connect after one frame so the Hotbar (in UI canvas layer) has been added.
	call_deferred("_bind_hotbar")


func _bind_hotbar() -> void:
	if Inventory:
		Inventory.slot_changed.connect(_on_inventory_slot_changed)
	var hotbar := _find_hotbar()
	if hotbar:
		hotbar.selected_changed.connect(_on_hotbar_selected)
		_refresh(hotbar.selected_index)


func _on_hotbar_selected(idx: int) -> void:
	_refresh(idx)


func _on_inventory_slot_changed(idx: int, _id: StringName, _count: int) -> void:
	# Only react if the changed slot is the currently selected hotbar slot.
	var hotbar := _find_hotbar()
	if hotbar == null:
		return
	if idx == hotbar.selected_index:
		_refresh(hotbar.selected_index)


func _refresh(hotbar_idx: int) -> void:
	var iid: StringName = Inventory.get_hotbar_item(hotbar_idx) if Inventory else &""
	_current_item = iid
	if iid == &"" or _sprite == null:
		if _sprite:
			_sprite.texture = null
			_sprite.visible = false
		return
	var defn: ItemDef = ItemRegistry.get_def(iid) if ItemRegistry else null
	if defn == null or defn.icon == null:
		_sprite.texture = null
		_sprite.visible = false
		return
	_sprite.texture = defn.icon
	_sprite.visible = true


func _process(_delta: float) -> void:
	if _sprite == null or not _sprite.visible:
		return
	if _player == null or not ("facing" in _player):
		return
	var facing: Vector2 = _player.get("facing")
	if facing == Vector2.ZERO:
		facing = Vector2.DOWN
	# Place the held item in front-right of the Walker; flip on left-facing.
	var sign_x: float = 1.0 if facing.x >= 0.0 else -1.0
	_sprite.position = Vector2(RIGHT_OFFSET.x * sign_x, RIGHT_OFFSET.y)
	_sprite.flip_h = facing.x < 0.0


func _find_hotbar() -> Hotbar:
	var nodes := get_tree().get_nodes_in_group("hotbar")
	if nodes.is_empty():
		return null
	return nodes[0] as Hotbar
