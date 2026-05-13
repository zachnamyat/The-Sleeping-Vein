extends Control
class_name InventorySlotUI

## A single inventory slot view. Shows the item icon + count, raises tooltip on
## hover, supports drag/drop between sibling slots in the same InventoryPanel.

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
		return
	var defn: ItemDef = ItemRegistry.get_def(item_id)
	icon.texture = defn.icon if defn else null
	count_label.text = "%d" % count if count > 1 else ""


func _get_drag_data(_at_position: Vector2) -> Variant:
	if current_item_id == &"":
		return null
	drag_started.emit(slot_index)
	var preview := TextureRect.new()
	preview.texture = icon.texture
	preview.custom_minimum_size = Vector2(16, 16)
	preview.size = Vector2(16, 16)
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.modulate = Color(1, 1, 1, 0.85)
	set_drag_preview(preview)
	return {
		"source_slot_index": slot_index,
		"item_id": current_item_id,
		"count": current_count,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("source_slot_index")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary) or not data.has("source_slot_index"):
		return
	var from: int = int(data["source_slot_index"])
	Inventory.swap(from, slot_index)


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
