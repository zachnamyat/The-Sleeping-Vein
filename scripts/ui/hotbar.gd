extends Control
class_name Hotbar

## 10-slot hotbar. Keys 1..0 select; mouse wheel cycles. Each slot displays the
## held item's icon and count when an Inventory slot in indices 0..9 changes.

signal selected_changed(slot_index: int)

const SLOT_COUNT: int = 10

## Slot is 24×24 so a 16-px icon centers with 4px padding all round and the
## m5x7 stack-count label (16-px design size) tucks into the bottom-right
## corner without overflowing the slot.
@export var slot_size: Vector2 = Vector2(24, 24)
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
		# Center the 16×16 icon inside the 24×24 slot — 4px padding all round.
		icon.position = Vector2(int((slot_size.x - 16) * 0.5), int((slot_size.y - 16) * 0.5))
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		_slot_icons.append(icon)

		# Stack-count label. Anchored bottom-right of the slot — the m5x7 glyph
		# sits in the lower portion of its 16-px cell, so a 16-tall label whose
		# bottom edge matches the slot bottom puts the digits low-right without
		# overflowing.
		var lbl := Label.new()
		lbl.add_theme_constant_override("outline_size", 1)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.size = Vector2(slot_size.x - 2, 16)
		lbl.position = Vector2(1, slot_size.y - 16)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		lbl.clip_text = true
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(lbl)
		_slot_counts.append(lbl)

		# Hotkey number (1-9, 0). Top-left corner. m5x7 glyphs sit at the
		# baseline so a label whose top is at y=-3 lifts the digit into the
		# slot's top-left corner cleanly.
		var num_lbl := Label.new()
		num_lbl.text = "%d" % ((i + 1) % 10)
		num_lbl.size = Vector2(12, 16)
		num_lbl.position = Vector2(2, -3)
		num_lbl.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
		num_lbl.add_theme_font_size_override("font_size", 16)
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
	# Phase 3.51 — hotbar swap-sets. Q swaps the active hotbar row with a saved
	# copy. Shift+Q saves the current row over the slot. Two slots tracked
	# (active <-> saved) so the player has a "loadout A / loadout B" pair.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q or event.keycode == KEY_Q:
			if event.shift_pressed:
				_save_hotbar_layout()
			else:
				_swap_hotbar_layout()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_selected((selected_index - 1 + SLOT_COUNT) % SLOT_COUNT)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_selected((selected_index + 1) % SLOT_COUNT)


var _saved_hotbar_layout: Array = []  # parallel to Inventory.slots[0..9]


func _save_hotbar_layout() -> void:
	_saved_hotbar_layout = []
	for i in range(SLOT_COUNT):
		var s = Inventory.slots[i]
		_saved_hotbar_layout.append(s.duplicate(true) if s != null else null)
	EventBus.ui_toast.emit("Hotbar layout saved.", 1.2)


func _swap_hotbar_layout() -> void:
	# Phase 3.51 — restore the saved hotbar arrangement WITHOUT duplicating
	# items the player may have moved out into storage between Save and Swap.
	# Items are physical (each one lives in exactly one slot at a time): rather
	# than copying snapshot data into the hotbar, this swap PULLS each saved
	# item out of wherever it currently sits in the inventory. Anything that
	# was in the hotbar but isn't in the saved layout gets stashed back into
	# free storage. The previous active hotbar becomes the new saved set.
	if _saved_hotbar_layout.is_empty():
		EventBus.ui_toast.emit("No saved hotbar — Shift+Q to save first.", 1.5)
		return
	# 1) Snapshot current hotbar — this becomes the new saved layout B.
	var snapshot_b: Array = []
	for i in range(SLOT_COUNT):
		var s = Inventory.slots[i]
		snapshot_b.append(s.duplicate(true) if s != null else null)
	# 2) Pull every current hotbar item out into a temporary `displaced` list
	# so storage-search in step 3 doesn't re-grab items we just emptied.
	var displaced: Array = []
	for i in range(SLOT_COUNT):
		if Inventory.slots[i] != null:
			displaced.append(Inventory.slots[i])
			Inventory.slots[i] = null
			Inventory.slot_changed.emit(i, &"", 0)
	# 3) For each saved layout entry, find a matching item in displaced first
	# (zero-cost), then in storage. Move it into the hotbar slot.
	for i in range(SLOT_COUNT):
		var target = _saved_hotbar_layout[i]
		if target == null:
			continue
		var tid: StringName = StringName(target.get("item_id", ""))
		if tid == &"":
			continue
		var found: bool = false
		for k in range(displaced.size()):
			var d = displaced[k]
			if d != null and StringName(d.get("item_id", "")) == tid:
				Inventory.slots[i] = d
				Inventory.slot_changed.emit(i, tid, int(d["count"]))
				displaced[k] = null
				found = true
				break
		if found:
			continue
		# Search storage (slots 10+).
		for j in range(SLOT_COUNT, Inventory.slots.size()):
			var s = Inventory.slots[j]
			if s != null and StringName(s.get("item_id", "")) == tid:
				Inventory.slots[i] = s
				Inventory.slots[j] = null
				Inventory.slot_changed.emit(j, &"", 0)
				Inventory.slot_changed.emit(i, tid, int(s["count"]))
				break
		# If we found nothing, the saved item was consumed; leave the slot empty.
	# 4) Anything still in `displaced` was in the active hotbar but isn't in the
	# saved layout — push it back into the inventory. try_add will fill the
	# first free slot, which is normally storage now that hotbar is partially
	# repopulated by step 3.
	for d in displaced:
		if d == null:
			continue
		var iid: StringName = StringName(d.get("item_id", ""))
		var cnt: int = int(d.get("count", 0))
		if iid != &"" and cnt > 0:
			Inventory.try_add(iid, cnt)
	_saved_hotbar_layout = snapshot_b
	EventBus.inventory_changed.emit()
	EventBus.ui_toast.emit("Swapped hotbar layouts.", 1.2)


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
