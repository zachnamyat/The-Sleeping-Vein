extends Control
class_name InventorySlotUI

## A single inventory slot view. Shows the item icon + count, raises tooltip on
## hover, supports drag/drop between sibling slots in the same InventoryPanel.
## Phase 3 extras: shift-click stack split (3.35), right-click drop to world
## (3.50 / 3.52), drag-to-equipment slot.

signal hover_started(slot_idx: int)
signal hover_ended(slot_idx: int)
signal drag_started(slot_idx: int)

@export var slot_index: int = -1
@export var slot_pixel_size: Vector2 = Vector2(20, 20)

@onready var panel: Panel = $Panel
@onready var icon: TextureRect = $Panel/Icon
@onready var count_label: Label = $Panel/Count

var current_item_id: StringName = &""
var current_count: int = 0
var _shift_held_at_drag: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = slot_pixel_size
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func set_slot(item_id: StringName, count: int) -> void:
	current_item_id = item_id
	current_count = count
	if item_id == &"":
		icon.texture = null
		count_label.text = ""
		_apply_rarity_border(null)
		return
	var defn: ItemDef = ItemRegistry.get_def(item_id)
	icon.texture = defn.icon if defn else null
	count_label.text = "%d" % count if count > 1 else ""
	_apply_rarity_border(defn)


## Phase 3.12 / 3.67 — color the slot border by rarity tier so the player can
## see "ooh, blue" at a glance.
const RARITY_BORDERS := [
	Color(0.40, 0.34, 0.24),  # 0 white/common — faint
	Color(0.45, 0.85, 0.40),  # 1 green
	Color(0.40, 0.65, 1.00),  # 2 blue
	Color(0.78, 0.46, 0.95),  # 3 purple
	Color(0.95, 0.78, 0.30),  # 4 gold
]


func _apply_rarity_border(defn: ItemDef) -> void:
	if panel == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.04, 0.85)
	var border: Color = Color(0.3, 0.25, 0.18)
	if defn:
		var idx: int = clamp(defn.rarity, 0, RARITY_BORDERS.size() - 1)
		border = RARITY_BORDERS[idx]
	# Phase 3.43 — locked slots gain an extra-thick gold border so they read
	# differently at a glance.
	var locked: bool = Inventory != null and Inventory.is_locked(slot_index)
	if locked:
		border = Color(0.95, 0.84, 0.50)
	sb.border_color = border
	var bw: int = 2 if locked else 1
	sb.border_width_left = bw
	sb.border_width_right = bw
	sb.border_width_top = bw
	sb.border_width_bottom = bw
	panel.add_theme_stylebox_override("panel", sb)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if current_item_id == &"":
		return null
	drag_started.emit(slot_index)
	_shift_held_at_drag = Input.is_key_pressed(KEY_SHIFT)
	var preview := TextureRect.new()
	preview.texture = icon.texture
	preview.custom_minimum_size = Vector2(16, 16)
	preview.size = Vector2(16, 16)
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.modulate = Color(1, 1, 1, 0.85)
	set_drag_preview(preview)
	# Shift = split half (rounded down, min 1 left).
	var move: int = current_count
	if _shift_held_at_drag and current_count >= 2:
		move = current_count / 2
	return {
		"source": "inventory",
		"source_slot_index": slot_index,
		"item_id": current_item_id,
		"count": move,
		"shift_split": _shift_held_at_drag and current_count >= 2,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data.has("source_slot_index") or data.get("source") == "equipment")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	# Drop FROM equipment: unequip into this inventory slot.
	if data.get("source") == "equipment":
		var slot_id: StringName = StringName(data.get("slot_id", ""))
		Inventory.unequip(slot_id, slot_index)
		return
	if not data.has("source_slot_index"):
		return
	var from: int = int(data["source_slot_index"])
	if data.get("shift_split", false):
		var move: int = int(data.get("count", 0))
		if not Inventory.split_stack(from, slot_index, move):
			# Fall back to swap if split rejects (different item, no space, etc.).
			Inventory.swap(from, slot_index)
		return
	Inventory.swap(from, slot_index)


func _gui_input(event: InputEvent) -> void:
	# Right-click context: drop to ground (Phase 3.50 / 3.52).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if current_item_id == &"":
			return
		_drop_to_world(1)
		accept_event()
		return
	# Phase 3.43 — middle-click toggles slot lock. Locked slots resist sort,
	# swap, and drop_from_slot.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
		Inventory.toggle_lock(slot_index)
		accept_event()
		return
	# Phase 3.44 — double-click on an equipment-typed item swaps it directly
	# with whatever's in that slot (compare-and-replace shortcut).
	if event is InputEventMouseButton and event.pressed and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
		if current_item_id == &"":
			return
		var defn: ItemDef = ItemRegistry.get_def(current_item_id)
		if defn != null and defn.equipment_slot != &"":
			Inventory.equip_from_slot(slot_index, defn.equipment_slot)
			accept_event()
			return
		# Non-armor: if the item is a consumable, fire its effect immediately.
		if defn != null and defn.item_type == ItemDef.ItemType.CONSUMABLE:
			# Defer to player_combat's consume path by emitting a signal hook.
			EventBus.ui_toast.emit("Consumed (slot dbl-click)", 0.8)
			Inventory.try_remove(current_item_id, 1)
			accept_event()


func _drop_to_world(count: int) -> void:
	# Use existing ItemDrop scene. Inventory clears the slot; the spawner
	# places it just in front of the player.
	if count <= 0:
		return
	var data: Dictionary = Inventory.drop_from_slot(slot_index, count)
	if data.is_empty():
		return
	var iid := StringName(data.get("item_id", ""))
	var n: int = int(data.get("count", 0))
	if iid == &"" or n <= 0:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0] as Node2D
	if player == null:
		return
	var scn := load("res://scenes/items/item_drop.tscn") as PackedScene
	if scn == null:
		return
	var drop := scn.instantiate()
	var entities := player.get_parent()
	if entities == null:
		return
	drop.set("item_id", iid)
	drop.set("count", n)
	drop.set("global_position", player.global_position + Vector2(0, 12))
	# Brief pickup-immunity window so the drop doesn't bounce right back in.
	if "pickup_delay" in drop:
		drop.set("pickup_delay", 0.6)
	entities.add_child(drop)


func _on_mouse_entered() -> void:
	hover_started.emit(slot_index)
	if current_item_id != &"":
		var tt := get_tree().get_first_node_in_group("tooltip") as Tooltip
		if tt:
			tt.show_for_item(current_item_id)


func _on_mouse_exited() -> void:
	hover_ended.emit(slot_index)
	var tt := get_tree().get_first_node_in_group("tooltip") as Tooltip
	if tt:
		tt.hide_tooltip()
