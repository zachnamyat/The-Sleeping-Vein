extends Control
class_name InventoryPanel

## Full inventory grid (3 rows x 10 cols by default). Toggled by `open_inventory`
## action. Slots subscribe to Inventory.slot_changed.

@export var rows: int = 3
@export var cols: int = 10
@export var slot_size: Vector2 = Vector2(20, 20)
@export var slot_spacing: float = 2.0

var _slot_uis: Array[InventorySlotUI] = []
var _slot_scene: PackedScene = preload("res://scenes/ui/inventory_slot_ui.tscn")


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_grid()
	Inventory.slot_changed.connect(_on_slot_changed)
	for i in range(Inventory.slots.size()):
		var s := Inventory.get_slot(i)
		if s.is_empty():
			_set_slot_visual(i, &"", 0)
		else:
			_set_slot_visual(i, StringName(s["item_id"]), int(s["count"]))


func _build_grid() -> void:
	var container := $Panel/Grid
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	_slot_uis.clear()
	for r in range(rows):
		for c in range(cols):
			var idx: int = r * cols + c
			var slot_ui: InventorySlotUI = _slot_scene.instantiate()
			slot_ui.slot_index = idx
			slot_ui.position = Vector2((slot_size.x + slot_spacing) * c, (slot_size.y + slot_spacing) * r)
			container.add_child(slot_ui)
			_slot_uis.append(slot_ui)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inventory"):
		visible = not visible


func _on_slot_changed(slot_index: int, item_id: StringName, count: int) -> void:
	_set_slot_visual(slot_index, item_id, count)


func _set_slot_visual(idx: int, item_id: StringName, count: int) -> void:
	if idx < 0 or idx >= _slot_uis.size():
		return
	_slot_uis[idx].set_slot(item_id, count)
