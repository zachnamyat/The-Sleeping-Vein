extends Control
class_name TrashSlot

## Phase 3.25 — drop an inventory item here to delete it (with confirmation).
## Visually a single 20x20 panel with a trash icon hint.

const CONFIRM_THRESHOLD: int = 2  # ask before deleting stacks > this

var _panel: Panel
var _label: Label
var _pending_delete: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(20, 20)
	_panel = Panel.new()
	_panel.size = Vector2(20, 20)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.02, 0.02, 0.9)
	sb.border_color = Color(0.55, 0.22, 0.20, 1)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_label = Label.new()
	_label.text = "X"
	_label.size = Vector2(20, 20)
	_label.position = Vector2(0, 4)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.40))
	_label.add_theme_font_size_override("font_size", 8)
	_panel.add_child(_label)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("source_slot_index")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var idx: int = int(data.get("source_slot_index", -1))
	if idx < 0:
		return
	var s := Inventory.get_slot(idx)
	if s.is_empty():
		return
	var count: int = int(s.get("count", 0))
	if count > CONFIRM_THRESHOLD:
		_pending_delete = {"index": idx, "count": count}
		_show_confirmation(StringName(s.get("item_id", "")), count)
		return
	Inventory.drop_from_slot(idx, count)
	EventBus.ui_toast.emit("Discarded.", 1.0)


func _show_confirmation(item_id: StringName, count: int) -> void:
	# Phase 3.53 — proper modal confirmation. Uses Godot's ConfirmationDialog
	# so the player has to acknowledge before a stack disappears.
	var defn: ItemDef = ItemRegistry.get_def(item_id)
	var name: String = defn.display_name if defn else String(item_id)
	var dlg := ConfirmationDialog.new()
	dlg.title = "Discard?"
	dlg.dialog_text = "Discard %d %s?" % [count, name]
	dlg.ok_button_text = "Discard"
	dlg.cancel_button_text = "Keep"
	dlg.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(dlg)
	dlg.confirmed.connect(func() -> void:
		Inventory.drop_from_slot(int(_pending_delete["index"]), count)
		EventBus.ui_toast.emit("Discarded %d %s." % [count, name], 1.5)
		_pending_delete = {}
		dlg.queue_free()
	)
	dlg.canceled.connect(func() -> void:
		_pending_delete = {}
		dlg.queue_free()
	)
	dlg.popup_centered()
