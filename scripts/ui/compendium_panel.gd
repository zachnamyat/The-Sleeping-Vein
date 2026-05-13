extends CanvasLayer
class_name CompendiumPanel

## Phase 5.12 — viewer for Compendium entries.
## Tabs: Bestiary (mobs/bosses killed) + Tablets (lore items found).
## Toggle with J (for "journal").

@onready var tab_bestiary: Button = $Root/Tabs/BestiaryTab
@onready var tab_tablets: Button = $Root/Tabs/TabletsTab
@onready var list_root: VBoxContainer = $Root/Scroll/List
@onready var hint: Label = $Root/Hint

var _current_tab: StringName = &"bestiary"


func _ready() -> void:
	add_to_group("compendium_panel")
	visible = false
	tab_bestiary.pressed.connect(func() -> void: _switch_tab(&"bestiary"))
	tab_tablets.pressed.connect(func() -> void: _switch_tab(&"tablets"))
	EventBus.ui_compendium_entry_unlocked.connect(_on_unlock)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J:
		toggle()
	elif visible and event.is_action_pressed("ui_cancel"):
		visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		_rebuild()


func _switch_tab(tab: StringName) -> void:
	_current_tab = tab
	_rebuild()


func _on_unlock(_entry_id: StringName) -> void:
	if visible:
		_rebuild()


func _rebuild() -> void:
	for child in list_root.get_children():
		child.queue_free()
	tab_bestiary.modulate = Color(1, 1, 1) if _current_tab == &"bestiary" else Color(0.55, 0.5, 0.42)
	tab_tablets.modulate = Color(1, 1, 1) if _current_tab == &"tablets" else Color(0.55, 0.5, 0.42)
	var entries: Array = []
	if _current_tab == &"bestiary":
		for key in GameState.unlocked_compendium.keys():
			var k: String = String(key)
			if k.begins_with("bestiary_"):
				entries.append(k.substr(9).capitalize())
	else:
		for key in GameState.unlocked_compendium.keys():
			var k: String = String(key)
			if k.begins_with("tablet_"):
				entries.append("Tablet %s" % k.substr(7))
	if entries.is_empty():
		hint.text = "(no entries yet — descend further)"
	else:
		hint.text = "%d entries" % entries.size()
	entries.sort()
	for entry_text in entries:
		var l := Label.new()
		l.text = "• " + entry_text
		l.modulate = Color(0.97, 0.85, 0.5, 1)
		list_root.add_child(l)
