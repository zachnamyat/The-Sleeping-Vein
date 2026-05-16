extends CanvasLayer
class_name CookbookPanel

## Phase 8 cookbook — lists every cooking recipe. Discovered recipes (ticket
## 8.28) show full ingredients; undiscovered show a "???" with an ingredient
## hint (1 of the inputs at random). Page-flip arrows step through 6 recipes
## per page.

const PER_PAGE: int = 6

@onready var list_root: VBoxContainer = $Root/Scroll/List
@onready var hint: Label = $Root/Hint
@onready var title_label: Label = $Root/Title

var _page: int = 0


func _ready() -> void:
	add_to_group("cookbook_panel")
	visible = false
	if CookingSystem:
		CookingSystem.recipe_discovered.connect(_on_recipe_discovered)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		toggle()
	elif visible and event.is_action_pressed("ui_cancel"):
		visible = false
		UIAudio.play_panel_close()
	elif visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT or event.keycode == KEY_A:
			_flip_page(-1)
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			_flip_page(1)


func toggle() -> void:
	visible = not visible
	if visible:
		_page = 0
		_rebuild()
		UIAudio.play_page_flip()
	else:
		UIAudio.play_panel_close()


func _on_recipe_discovered(_id: StringName) -> void:
	if visible:
		_rebuild()


func _flip_page(direction: int) -> void:
	var recipes := _all_cooking_recipes()
	var max_page: int = maxi(0, int(ceil(float(recipes.size()) / float(PER_PAGE))) - 1)
	_page = clampi(_page + direction, 0, max_page)
	_rebuild()
	UIAudio.play_page_flip()


func _all_cooking_recipes() -> Array:
	var out: Array = []
	for r in CraftingSystem.all_recipes():
		var rec: Recipe = r
		if rec.skill_xp_id == &"skill_cooking":
			out.append(rec)
	out.sort_custom(func(a: Recipe, b: Recipe) -> bool: return a.display_name < b.display_name)
	return out


func _rebuild() -> void:
	if list_root == null:
		return
	for child in list_root.get_children():
		child.queue_free()
	var all := _all_cooking_recipes()
	if all.is_empty():
		if hint:
			hint.text = "No recipes yet — craft the Cookpot first."
		return
	var max_page: int = maxi(0, int(ceil(float(all.size()) / float(PER_PAGE))) - 1)
	if title_label:
		title_label.text = "Hearth Cookbook  [B]   page %d/%d   ←/→" % [_page + 1, max_page + 1]
	var start: int = _page * PER_PAGE
	var end: int = mini(start + PER_PAGE, all.size())
	for i in range(start, end):
		var rec: Recipe = all[i]
		var discovered: bool = (CookingSystem != null and CookingSystem.is_discovered(rec.id))
		list_root.add_child(_build_row(rec, discovered))
	if hint:
		var discovered_count: int = 0
		if CookingSystem:
			discovered_count = CookingSystem.discovered_recipes().size()
		hint.text = "Discovered %d of %d" % [discovered_count, all.size()]


func _build_row(rec: Recipe, discovered: bool) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(420, 32)
	var name_lbl := Label.new()
	if discovered:
		name_lbl.text = rec.display_name
		name_lbl.modulate = Color(0.97, 0.85, 0.5, 1)
	else:
		name_lbl.text = "??? (undiscovered)"
		name_lbl.modulate = Color(0.55, 0.5, 0.4, 1)
	col.add_child(name_lbl)
	var ingredient_str: String = ""
	if discovered:
		var pieces := PackedStringArray()
		for inp in rec.inputs:
			var defn: ItemDef = ItemRegistry.get_def(StringName(inp.get("item_id", "")))
			var nm: String = defn.display_name if defn else String(inp.get("item_id", ""))
			pieces.append("%s x%d" % [nm, int(inp.get("count", 1))])
		ingredient_str = "  " + ", ".join(pieces)
	else:
		# Ticket 8.28 — show one input as a teaser to nudge the player.
		if rec.inputs.size() > 0:
			var hint_input: Dictionary = rec.inputs[0]
			var d: ItemDef = ItemRegistry.get_def(StringName(hint_input.get("item_id", "")))
			ingredient_str = "  Hint: includes %s" % (d.display_name if d else String(hint_input.get("item_id", "")))
	var ingredients := Label.new()
	ingredients.text = ingredient_str
	ingredients.modulate = Color(0.7, 0.6, 0.4, 1) if discovered else Color(0.45, 0.4, 0.3, 1)
	col.add_child(ingredients)
	return col
