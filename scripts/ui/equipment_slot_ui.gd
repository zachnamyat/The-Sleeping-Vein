extends Control
class_name EquipmentSlotUI

## A single equipment slot view (helmet, chest, boots, etc). Listens to
## Inventory.equipment_changed for its own slot id. Drag-drops between
## inventory slots, with per-slot type validation.

signal hover_started(slot: StringName)

@export var slot_id: StringName = &""
@export var slot_pixel_size: Vector2 = Vector2(20, 20)
@export var hint_color: Color = Color(0.45, 0.40, 0.30, 1)

@onready var panel: Panel = $Panel
@onready var icon: TextureRect = $Panel/Icon
@onready var hint: Label = $Panel/Hint


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = slot_pixel_size
	if Inventory:
		Inventory.equipment_changed.connect(_on_equipment_changed)
		_refresh()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if hint:
		hint.text = _short_hint(slot_id)
		hint.add_theme_color_override("font_color", hint_color)
		hint.add_theme_font_size_override("font_size", 6)


func _refresh() -> void:
	var equipped: StringName = StringName(Inventory.equipment.get(slot_id, &""))
	if equipped == &"":
		icon.texture = null
		if hint: hint.visible = true
	else:
		var defn: ItemDef = ItemRegistry.get_def(equipped)
		icon.texture = defn.icon if defn else null
		if hint: hint.visible = false


func _on_equipment_changed(slot: StringName, _id: StringName) -> void:
	if slot == slot_id:
		_refresh()


## Drag the equipped item back out (to inventory).
func _get_drag_data(_at_position: Vector2) -> Variant:
	var equipped: StringName = StringName(Inventory.equipment.get(slot_id, &""))
	if equipped == &"":
		return null
	var preview := TextureRect.new()
	var defn: ItemDef = ItemRegistry.get_def(equipped)
	preview.texture = defn.icon if defn else null
	preview.custom_minimum_size = Vector2(16, 16)
	preview.size = Vector2(16, 16)
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.modulate = Color(1, 1, 1, 0.85)
	set_drag_preview(preview)
	return {
		"source": "equipment",
		"slot_id": slot_id,
		"item_id": equipped,
		"count": 1,
	}


## Accept drops from inventory slots only when the item's equipment_slot matches.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	if data.get("source") == "equipment":
		return false  # equipment-to-equipment swap goes through inventory
	var iid := StringName(data.get("item_id", ""))
	if iid == &"":
		return false
	var defn: ItemDef = ItemRegistry.get_def(iid)
	return defn != null and defn.equipment_slot == slot_id


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var from: int = int(data.get("source_slot_index", -1))
	if from < 0:
		return
	Inventory.equip_from_slot(from, slot_id)


func _on_mouse_entered() -> void:
	hover_started.emit(slot_id)
	var equipped: StringName = StringName(Inventory.equipment.get(slot_id, &""))
	if equipped != &"":
		var tt := get_tree().get_first_node_in_group("tooltip") as Tooltip
		if tt:
			tt.show_for_item(equipped)


func _on_mouse_exited() -> void:
	var tt := get_tree().get_first_node_in_group("tooltip") as Tooltip
	if tt:
		tt.hide_tooltip()


func _short_hint(slot: StringName) -> String:
	match slot:
		&"helmet": return "head"
		&"chest": return "body"
		&"legs": return "legs"
		&"boots": return "feet"
		&"off_hand": return "off"
		&"necklace": return "neck"
		&"ring_1", &"ring_2": return "ring"
		&"bracelet": return "wrist"
		&"belt": return "belt"
		&"pet": return "pet"
		_: return String(slot)


func _input(event: InputEvent) -> void:
	# Right-click to unequip back to inventory.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var mouse := get_global_mouse_position()
		var rect := Rect2(global_position, size)
		if not rect.has_point(mouse):
			return
		Inventory.unequip(slot_id)
		accept_event()
