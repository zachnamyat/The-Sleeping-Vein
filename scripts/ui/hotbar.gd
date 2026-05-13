extends Control
class_name Hotbar

## 10-slot hotbar. Keys 1..0 select; mouse wheel cycles. Each slot displays the
## held item's icon and count when an Inventory slot in indices 0..9 changes.

signal selected_changed(slot_index: int)

const SLOT_COUNT: int = 10

@export var slot_size: Vector2 = Vector2(20, 20)
@export var slot_spacing: float = 2.0

var selected_index: int = 0
var _slot_panels: Array[Control] = []
var _slot_icons: Array[TextureRect] = []
var _slot_counts: Array[Label] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_slots()
	_apply_selection_visuals()
	if Inventory:
		Inventory.slot_changed.connect(_on_inventory_slot_changed)
		_refresh_all_from_inventory()


func _build_slots() -> void:
	for i in range(SLOT_COUNT):
		var panel := Panel.new()
		panel.custom_minimum_size = slot_size
		panel.size = slot_size
		panel.position = Vector2((slot_size.x + slot_spacing) * i, 0)
		panel.name = "Slot%d" % i
		add_child(panel)
		_slot_panels.append(panel)

		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(16, 16)
		icon.position = Vector2(2, 2)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		_slot_icons.append(icon)

		var lbl := Label.new()
		lbl.add_theme_constant_override("outline_size", 1)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		lbl.add_theme_font_size_override("font_size", 6)
		lbl.size = Vector2(18, 8)
		lbl.position = Vector2(1, 11)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(lbl)
		_slot_counts.append(lbl)

		var num_lbl := Label.new()
		num_lbl.text = "%d" % ((i + 1) % 10)
		num_lbl.size = Vector2(8, 6)
		num_lbl.position = Vector2(2, 0)
		num_lbl.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
		num_lbl.add_theme_font_size_override("font_size", 6)
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(num_lbl)

	custom_minimum_size = Vector2((slot_size.x + slot_spacing) * SLOT_COUNT - slot_spacing, slot_size.y)


func _refresh_all_from_inventory() -> void:
	for i in range(SLOT_COUNT):
		var s := Inventory.get_slot(i)
		var item_id: StringName = StringName(s.get("item_id", "")) if not s.is_empty() else &""
		var count: int = int(s.get("count", 0))
		_update_slot_visual(i, item_id, count)


func _on_inventory_slot_changed(slot_index: int, item_id: StringName, count: int) -> void:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return
	_update_slot_visual(slot_index, item_id, count)


func _update_slot_visual(idx: int, item_id: StringName, count: int) -> void:
	if idx < 0 or idx >= _slot_icons.size():
		return
	var icon := _slot_icons[idx]
	var lbl := _slot_counts[idx]
	if item_id == &"":
		icon.texture = null
		lbl.text = ""
		return
	var defn: ItemDef = ItemRegistry.get_def(item_id)
	if defn and defn.icon:
		icon.texture = defn.icon
	else:
		icon.texture = null
	lbl.text = "%d" % count if count > 1 else ""


func _unhandled_input(event: InputEvent) -> void:
	for i in range(SLOT_COUNT):
		var action_name := "hotbar_%d" % (i + 1)
		if event.is_action_pressed(action_name):
			set_selected(i)
			return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_selected((selected_index - 1 + SLOT_COUNT) % SLOT_COUNT)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_selected((selected_index + 1) % SLOT_COUNT)


func set_selected(idx: int) -> void:
	if idx < 0 or idx >= SLOT_COUNT:
		return
	if idx == selected_index:
		return
	selected_index = idx
	_apply_selection_visuals()
	selected_changed.emit(idx)


func _apply_selection_visuals() -> void:
	for i in range(SLOT_COUNT):
		var p := _slot_panels[i]
		if p == null:
			continue
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.6)
		sb.border_color = Color(0.85, 0.66, 0.34) if i == selected_index else Color(0.3, 0.25, 0.18)
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_width_left = 2
		sb.border_width_right = 2
		p.add_theme_stylebox_override("panel", sb)
