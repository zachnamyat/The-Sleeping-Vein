extends Label
class_name AmmoLabel

## Phase 2.46 / 6.57 — small label adjacent to the hotbar that shows the ammo
## remaining for the currently held ranged weapon. Updates on inventory change
## and hotbar selection.

@export var hotbar_path: NodePath


func _ready() -> void:
	add_theme_font_size_override("font_size", 16)
	modulate = Color(1.0, 0.85, 0.55, 1.0)
	text = ""
	if Inventory:
		Inventory.slot_changed.connect(_on_slot_changed)
	var hotbar := get_node_or_null(hotbar_path) as Hotbar
	if hotbar:
		hotbar.selected_changed.connect(_on_selected_changed)
	call_deferred("_refresh")


func _on_slot_changed(_idx: int, _id: StringName, _count: int) -> void:
	_refresh()


func _on_selected_changed(_idx: int) -> void:
	_refresh()


func _refresh() -> void:
	var hotbar := get_node_or_null(hotbar_path) as Hotbar
	if hotbar == null or Inventory == null or ItemRegistry == null:
		text = ""
		return
	var iid := Inventory.get_hotbar_item(hotbar.selected_index)
	if iid == &"":
		text = ""
		return
	var defn: ItemDef = ItemRegistry.get_def(iid)
	if defn == null or defn.ammo_id == &"":
		text = ""
		return
	var have: int = Inventory.count_of(defn.ammo_id)
	var ammo_def: ItemDef = ItemRegistry.get_def(defn.ammo_id)
	var ammo_name: String = ammo_def.display_name if ammo_def else String(defn.ammo_id)
	text = "%s × %d" % [ammo_name, have]
