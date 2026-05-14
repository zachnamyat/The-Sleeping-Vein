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
	_attach_silhouette()
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


## Ticket 3.4 — paper-doll silhouette behind the slot grid so the player can
## read at a glance which slot is which (head up top, feet down low, hands
## either side). Drawn procedurally; no asset dependency. Uses anchor-fill so
## the size tracks the grid regardless of when the layout settles — querying
## grid.size at _ready returned (0,0) on the first paint.
func _attach_silhouette() -> void:
	var grid: Control = $Panel/Grid
	if grid == null:
		return
	var s := EquipmentSilhouette.new()
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_child(s)
	grid.move_child(s, 0)


class EquipmentSilhouette extends Control:
	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		if w <= 0.0 or h <= 0.0:
			return
		# Warm tan tint matching the panel border so the silhouette reads as a
		# faded body shape against the near-black slot backgrounds.
		var body: Color = Color(0.55, 0.40, 0.22, 0.85)
		var glow: Color = Color(0.70, 0.55, 0.30, 0.35)
		# Head — large enough to span the top row's two slots so it reads
		# clearly through the slot panels' translucent backgrounds.
		var head_center: Vector2 = Vector2(w * 0.5, h * 0.12)
		draw_circle(head_center, h * 0.10, glow)
		draw_circle(head_center, h * 0.075, body)
		# Torso — wide rect spanning the chest + legs slot column.
		var torso := Rect2(w * 0.30, h * 0.22, w * 0.40, h * 0.46)
		draw_rect(torso.grow(2.0), glow, true)
		draw_rect(torso, body, true)
		# Arms — thicker rects out to the off-hand / bracelet column.
		var arm_l := Rect2(w * 0.12, h * 0.24, w * 0.14, h * 0.40)
		var arm_r := Rect2(w * 0.74, h * 0.24, w * 0.14, h * 0.40)
		draw_rect(arm_l.grow(2.0), glow, true)
		draw_rect(arm_l, body, true)
		draw_rect(arm_r.grow(2.0), glow, true)
		draw_rect(arm_r, body, true)
		# Legs — descending from torso bottom to the boots row.
		var leg_l := Rect2(w * 0.34, h * 0.68, w * 0.14, h * 0.28)
		var leg_r := Rect2(w * 0.52, h * 0.68, w * 0.14, h * 0.28)
		draw_rect(leg_l.grow(2.0), glow, true)
		draw_rect(leg_l, body, true)
		draw_rect(leg_r.grow(2.0), glow, true)
		draw_rect(leg_r, body, true)
