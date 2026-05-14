extends Control
class_name ChestPanel

## Phase 3.6 — Container UI. Opens when the player interacts with a Chest.
## Shows a 3x6 grid of slots bound to the chest. Drag/drop swaps with the
## player inventory by spawning ItemDrops or using deposit()/withdraw_slot().

const COLS: int = 6
const ROWS: int = 3
const SLOT_SIZE: Vector2 = Vector2(20, 20)
const SLOT_SPACING: float = 2.0

var _chest: Chest = null
var _slot_panels: Array[Panel] = []
var _slot_icons: Array[TextureRect] = []
var _slot_counts: Array[Label] = []

@onready var title: Label = $Panel/Title
@onready var grid: Control = $Panel/Grid


func _ready() -> void:
	add_to_group("chest_ui")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_grid()
	set_process_unhandled_input(true)


func _build_grid() -> void:
	if grid == null:
		return
	for child in grid.get_children():
		child.queue_free()
	_slot_panels.clear()
	_slot_icons.clear()
	_slot_counts.clear()
	for r in range(ROWS):
		for c in range(COLS):
			var idx: int = r * COLS + c
			var slot: ChestSlotUI = ChestSlotUI.new()
			slot.slot_index = idx
			slot.size = SLOT_SIZE
			slot.position = Vector2(
				(SLOT_SIZE.x + SLOT_SPACING) * c,
				(SLOT_SIZE.y + SLOT_SPACING) * r,
			)
			grid.add_child(slot)
			_slot_panels.append(slot.panel)
			_slot_icons.append(slot.icon)
			_slot_counts.append(slot.count_label)


func open_for_chest(chest: Chest) -> void:
	if _chest != null and _chest != chest and _chest.contents_changed.is_connected(_on_active_chest_changed):
		_chest.contents_changed.disconnect(_on_active_chest_changed)
	_chest = chest
	# Phase 3.15 — auto-deposit + Quick Stack target the most recently opened
	# container. Tracked on Inventory so other systems (HUD hotkey, panel) can
	# read it without grabbing this scene.
	if Inventory:
		Inventory.last_used_container = chest
	if title:
		title.text = "Chest"
	visible = true
	if not chest.contents_changed.is_connected(_on_active_chest_changed):
		chest.contents_changed.connect(_on_active_chest_changed)
	_refresh()
	# Show the player's pouch alongside so they can drag-deposit without
	# fumbling for the inventory key.
	get_tree().call_group("inventory_ui", "force_open")


func close_if_for_chest(chest: Chest) -> void:
	if _chest == chest:
		_close_active()


func _close_active() -> void:
	if _chest and _chest.contents_changed.is_connected(_on_active_chest_changed):
		_chest.contents_changed.disconnect(_on_active_chest_changed)
	visible = false
	_chest = null


func _on_active_chest_changed() -> void:
	# Chest mutated via any code path (drag-drop, quick-stack, save-restore).
	# A direct refresh keeps the open panel in sync without each caller having
	# to remember to ping notify_chest_change().
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_inventory"):
		_close_active()
		get_viewport().set_input_as_handled()


func get_active_chest() -> Chest:
	return _chest


func _refresh() -> void:
	if _chest == null:
		return
	for i in range(min(_slot_icons.size(), Chest.SLOT_COUNT)):
		var s = _chest.slots[i]
		var icon := _slot_icons[i]
		var lbl := _slot_counts[i]
		if s == null:
			icon.texture = null
			lbl.text = ""
			continue
		var defn: ItemDef = ItemRegistry.get_def(StringName(s.get("item_id", "")))
		icon.texture = defn.icon if defn else null
		var count: int = int(s.get("count", 0))
		lbl.text = "%d" % count if count > 1 else ""


func notify_chest_change() -> void:
	# Allow ChestSlotUI children to ping us after a transfer happens.
	_refresh()


## ChestSlotUI is defined inline so we don't need a separate .tscn — chest UI
## slots are read-only-ish and don't need full reuse outside this panel.
class ChestSlotUI extends Control:
	var slot_index: int = -1
	var panel: Panel
	var icon: TextureRect
	var count_label: Label

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		panel = Panel.new()
		panel.size = Vector2(20, 20)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.03, 0.04, 0.85)
		sb.border_color = Color(0.32, 0.40, 0.55, 1)
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_top = 1
		sb.border_width_bottom = 1
		panel.add_theme_stylebox_override("panel", sb)
		add_child(panel)
		icon = TextureRect.new()
		icon.position = Vector2(2, 2)
		icon.size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		count_label = Label.new()
		count_label.position = Vector2(1, 8)
		count_label.size = Vector2(18, 12)
		count_label.add_theme_font_size_override("font_size", 6)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.add_theme_color_override("font_color", Color(1, 0.94, 0.7))
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(count_label)

	func _gui_input(event: InputEvent) -> void:
		# Left-click withdraws all from this chest slot to inventory.
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var owner := _find_chest_panel()
			if owner == null:
				return
			var chest := owner.get_active_chest()
			if chest == null or slot_index < 0:
				return
			chest.withdraw_slot(slot_index)
			owner.notify_chest_change()
			accept_event()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			# Right-click withdraws one.
			var owner := _find_chest_panel()
			if owner == null:
				return
			var chest := owner.get_active_chest()
			if chest == null or slot_index < 0:
				return
			chest.withdraw_slot(slot_index, 1)
			owner.notify_chest_change()
			accept_event()

	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("source_slot_index")

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		if not (data is Dictionary):
			return
		var owner := _find_chest_panel()
		if owner == null:
			return
		var chest := owner.get_active_chest()
		if chest == null:
			return
		var inv_idx: int = int(data.get("source_slot_index", -1))
		if inv_idx < 0:
			return
		var s := Inventory.get_slot(inv_idx)
		if s.is_empty():
			return
		var iid := StringName(s.get("item_id", ""))
		var count: int = int(s.get("count", 0))
		var moved: int = chest.deposit(iid, count)
		if moved > 0:
			Inventory.try_remove(iid, moved)
		owner.notify_chest_change()

	func _find_chest_panel() -> ChestPanel:
		var n: Node = get_parent()
		while n:
			if n is ChestPanel:
				return n as ChestPanel
			n = n.get_parent()
		return null
