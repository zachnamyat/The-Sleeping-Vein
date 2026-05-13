extends Control
class_name EquipmentPanel

## Phase 3.4 — Equipment slots panel. Lays out 11 slot widgets in a humanoid
## silhouette. Each slot is an EquipmentSlotUI bound to one Inventory.equipment
## key. Shown alongside the InventoryPanel.

const SLOT_LAYOUT: Array = [
	# [slot_id, grid_col, grid_row]
	[&"helmet",   1, 0],
	[&"necklace", 2, 0],
	[&"off_hand", 0, 1],
	[&"chest",    1, 1],
	[&"ring_1",   2, 1],
	[&"bracelet", 0, 2],
	[&"legs",     1, 2],
	[&"ring_2",   2, 2],
	[&"belt",     0, 3],
	[&"boots",    1, 3],
	[&"pet",      2, 3],
]

const SLOT_SIZE: Vector2 = Vector2(20, 20)
const SLOT_SPACING: float = 2.0

var _slot_scene: PackedScene = preload("res://scenes/ui/equipment_slot_ui.tscn")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_grid()


func _build_grid() -> void:
	var grid: Control = $Panel/Grid
	if grid == null:
		return
	for child in grid.get_children():
		child.queue_free()
	for entry in SLOT_LAYOUT:
		var slot_id: StringName = entry[0]
		var col: int = entry[1]
		var row: int = entry[2]
		var slot_ui: EquipmentSlotUI = _slot_scene.instantiate()
		slot_ui.slot_id = slot_id
		slot_ui.position = Vector2(
			(SLOT_SIZE.x + SLOT_SPACING) * col,
			(SLOT_SIZE.y + SLOT_SPACING) * row,
		)
		slot_ui.name = "Slot_%s" % String(slot_id)
		grid.add_child(slot_ui)
