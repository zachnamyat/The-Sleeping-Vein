extends Control
class_name CraftingPanel

## Crafting UI. When a Workstation emits `interacted`, this panel opens with
## a recipe list filtered by station_id. Player clicks a recipe to craft it
## (if they have the inputs). Multi-craft via shift-click (3.18). Favorites
## via star button (3.16). Listens for `chest_ui` group; reuses container_ui.

@export var slot_size: Vector2 = Vector2(20, 20)

@onready var title: Label = $Panel/Title
@onready var list: VBoxContainer = $Panel/Scroll/RecipeList
@onready var search_box: LineEdit = $Panel/SearchBox
@onready var favorites_toggle: CheckButton = $Panel/FavoritesOnly

var _current_station: StringName = &""
var _search_filter: String = ""
var _favorites_only: bool = false

const FAVORITES_KEY: String = "crafting_favorites"


func _ready() -> void:
	add_to_group("crafting_ui")
	visible = false
	if search_box:
		search_box.text_changed.connect(_on_search_changed)
	if favorites_toggle:
		favorites_toggle.toggled.connect(_on_favorites_toggled)
	if EventBus.recipe_unlocked.is_connected(_on_recipe_unlocked):
		pass
	else:
		EventBus.recipe_unlocked.connect(_on_recipe_unlocked)


func open_for(station_id: StringName, display_name: String) -> void:
	_current_station = station_id
	if title:
		title.text = "Station: %s" % display_name
	visible = true
	_refresh_list()


func close_if_for(station_id: StringName) -> void:
	if _current_station == station_id:
		visible = false


func _on_search_changed(text: String) -> void:
	_search_filter = text.strip_edges().to_lower()
	_refresh_list()


func _on_favorites_toggled(pressed: bool) -> void:
	_favorites_only = pressed
	_refresh_list()


func _on_recipe_unlocked(recipe_id: StringName) -> void:
	# A small celebratory toast. Avoid double-toast on bulk starter unlocks
	# during initial CraftingSystem _ready().
	if not visible:
		return
	var rec: Recipe = CraftingSystem.get_recipe(recipe_id)
	if rec == null:
		return
	EventBus.ui_toast.emit("New recipe: %s" % rec.display_name, 1.5)
	_refresh_list()


func _is_favorite(recipe_id: StringName) -> bool:
	if Settings == null:
		return false
	var saved: Dictionary = Settings.get_value(FAVORITES_KEY, {})
	return bool(saved.get(String(recipe_id), false))


func _toggle_favorite(recipe_id: StringName) -> void:
	if Settings == null:
		return
	var saved: Dictionary = Settings.get_value(FAVORITES_KEY, {})
	var key := String(recipe_id)
	if saved.get(key, false):
		saved.erase(key)
	else:
		saved[key] = true
	Settings.set_value(FAVORITES_KEY, saved)
	_refresh_list()


func _refresh_list() -> void:
	if list == null:
		return
	for child in list.get_children():
		child.queue_free()
	var recipes: Array = CraftingSystem.recipes_for_station(_current_station)
	# Sort: favorites first, then alphabetical.
	recipes.sort_custom(func(a, b) -> bool:
		var fa: bool = _is_favorite(a.id)
		var fb: bool = _is_favorite(b.id)
		if fa != fb:
			return fa
		return a.display_name < b.display_name
	)
	for r in recipes:
		var rec: Recipe = r
		if _favorites_only and not _is_favorite(rec.id):
			continue
		if _search_filter != "" and rec.display_name.to_lower().find(_search_filter) < 0:
			continue
		var row := _make_row(rec)
		list.add_child(row)


func _make_row(rec: Recipe) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(248, 18)
	# Favorite star button.
	var fav_btn := Button.new()
	fav_btn.toggle_mode = true
	fav_btn.button_pressed = _is_favorite(rec.id)
	fav_btn.text = "*" if fav_btn.button_pressed else "."
	fav_btn.custom_minimum_size = Vector2(12, 16)
	fav_btn.tooltip_text = "Favorite"
	fav_btn.pressed.connect(func() -> void: _toggle_favorite(rec.id))
	row.add_child(fav_btn)
	var name_lbl := Label.new()
	name_lbl.text = rec.display_name
	name_lbl.custom_minimum_size = Vector2(100, 18)
	row.add_child(name_lbl)
	var inputs_lbl := Label.new()
	var input_text := ""
	var ok_to_craft: bool = true
	for inp in rec.inputs:
		var iid: StringName = StringName(inp.get("item_id", ""))
		var need: int = int(inp.get("count", 1))
		var defn: ItemDef = ItemRegistry.get_def(iid)
		var iname: String = defn.display_name if defn else String(iid)
		var have: int = Inventory.count_of(iid)
		if have < need:
			ok_to_craft = false
		input_text += "%s %d/%d  " % [iname, have, need]
	inputs_lbl.text = input_text
	inputs_lbl.modulate = Color(0.86, 0.85, 0.80, 1) if ok_to_craft else Color(0.70, 0.50, 0.50, 1)
	inputs_lbl.custom_minimum_size = Vector2(154, 18)
	row.add_child(inputs_lbl)
	var btn := Button.new()
	btn.text = "Craft"
	btn.custom_minimum_size = Vector2(36, 16)
	btn.tooltip_text = "Shift-click to craft all you can afford."
	btn.disabled = not ok_to_craft
	btn.pressed.connect(func() -> void: _on_craft_pressed(rec))
	row.add_child(btn)
	return row


func _on_craft_pressed(rec: Recipe) -> void:
	# Phase 3.18 — multi-craft when Shift held. Crafts as many copies as the
	# player can afford in one click. Otherwise single craft.
	var shift_held: bool = Input.is_key_pressed(KEY_SHIFT)
	var max_n: int = 1 if not shift_held else _max_craftable(rec)
	var made: int = 0
	for _i in range(max_n):
		if not CraftingSystem.try_craft(rec.id):
			break
		made += 1
	if made == 0:
		EventBus.ui_toast.emit("Missing materials.", 1.5)
	elif made == 1:
		EventBus.ui_toast.emit("Crafted %s" % rec.display_name, 1.5)
	else:
		EventBus.ui_toast.emit("Crafted %s x%d" % [rec.display_name, made], 1.8)
	_refresh_list()


func _max_craftable(rec: Recipe) -> int:
	var max_n: int = 99
	for inp in rec.inputs:
		var iid: StringName = StringName(inp.get("item_id", ""))
		var need: int = int(inp.get("count", 1))
		if need <= 0:
			continue
		var have: int = Inventory.count_of(iid)
		var per_item: int = have / need
		if per_item < max_n:
			max_n = per_item
	return max(0, max_n)
