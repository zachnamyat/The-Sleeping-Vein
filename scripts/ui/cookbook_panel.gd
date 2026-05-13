extends CanvasLayer
class_name CookbookPanel

## Phase 8 cookbook — lists every unlocked cooking recipe (those whose
## skill_xp_id is &"skill_cooking"). Toggle with B.

@onready var list_root: VBoxContainer = $Root/Scroll/List
@onready var hint: Label = $Root/Hint


func _ready() -> void:
	add_to_group("cookbook_panel")
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		toggle()
	elif visible and event.is_action_pressed("ui_cancel"):
		visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		_rebuild()


func _rebuild() -> void:
	if list_root == null:
		return
	for child in list_root.get_children():
		child.queue_free()
	var any: bool = false
	for r in CraftingSystem.all_recipes():
		var rec: Recipe = r
		if rec.skill_xp_id != &"skill_cooking":
			continue
		if not CraftingSystem.is_unlocked(rec.id):
			continue
		any = true
		var row := _build_row(rec)
		list_root.add_child(row)
	if hint:
		hint.text = "Cookbook: %s" % ("ready" if any else "no recipes discovered yet")


func _build_row(rec: Recipe) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(420, 32)
	var name_lbl := Label.new()
	name_lbl.text = rec.display_name
	name_lbl.modulate = Color(0.97, 0.85, 0.5, 1)
	col.add_child(name_lbl)
	var inputs := PackedStringArray()
	for inp in rec.inputs:
		var defn: ItemDef = ItemRegistry.get_def(StringName(inp.get("item_id", "")))
		var nm: String = defn.display_name if defn else String(inp.get("item_id", ""))
		inputs.append("%s x%d" % [nm, int(inp.get("count", 1))])
	var ingredients := Label.new()
	ingredients.text = "  " + ", ".join(inputs)
	ingredients.modulate = Color(0.7, 0.6, 0.4, 1)
	col.add_child(ingredients)
	return col
