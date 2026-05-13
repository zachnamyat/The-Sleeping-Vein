extends Control
class_name CraftingPanel

## Crafting UI. When a Workstation emits `interacted`, this panel opens with
## a recipe list filtered by station_id. Player clicks a recipe to craft it
## (if they have the inputs). Listens for `chest_ui` group; reuses container_ui.

@export var slot_size: Vector2 = Vector2(20, 20)

@onready var title: Label = $Panel/Title
@onready var list: VBoxContainer = $Panel/Scroll/RecipeList

var _current_station: StringName = &""


func _ready() -> void:
	add_to_group("crafting_ui")
	visible = false


func open_for(station_id: StringName, display_name: String) -> void:
	_current_station = station_id
	if title:
		title.text = "Station: %s" % display_name
	visible = true
	_refresh_list()


func close_if_for(station_id: StringName) -> void:
	if _current_station == station_id:
		visible = false


func _refresh_list() -> void:
	if list == null:
		return
	for child in list.get_children():
		child.queue_free()
	for r in CraftingSystem.recipes_for_station(_current_station):
		var rec: Recipe = r
		var row := _make_row(rec)
		list.add_child(row)


func _make_row(rec: Recipe) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(220, 18)
	var name_lbl := Label.new()
	name_lbl.text = rec.display_name
	name_lbl.custom_minimum_size = Vector2(110, 18)
	row.add_child(name_lbl)
	var inputs_lbl := Label.new()
	var input_text := ""
	for inp in rec.inputs:
		var defn: ItemDef = ItemRegistry.get_def(StringName(inp.get("item_id", "")))
		var name: String = defn.display_name if defn else String(inp.get("item_id", ""))
		input_text += "%s x%d  " % [name, int(inp.get("count", 1))]
	inputs_lbl.text = input_text
	inputs_lbl.modulate = Color(0.86, 0.85, 0.80, 1)
	inputs_lbl.custom_minimum_size = Vector2(170, 18)
	row.add_child(inputs_lbl)
	var btn := Button.new()
	btn.text = "Craft"
	btn.custom_minimum_size = Vector2(48, 16)
	btn.pressed.connect(func() -> void:
		var ok: bool = CraftingSystem.try_craft(rec.id)
		if ok:
			EventBus.ui_toast.emit("Crafted %s" % rec.display_name, 1.5)
			_refresh_list()
		else:
			EventBus.ui_toast.emit("Missing materials.", 1.5)
	)
	row.add_child(btn)
	return row
