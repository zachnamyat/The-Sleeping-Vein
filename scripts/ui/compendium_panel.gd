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

## Phase 5 polish — Monogram is the lore-flavor font for Tablet / Relics /
## Titles entries (Bestiary stays on the default m5x7 body for readability).
const MONOGRAM_FONT: String = "res://assets/fonts/monogram.ttf"
var _monogram: FontFile = load(MONOGRAM_FONT) as FontFile


func _ready() -> void:
	add_to_group("compendium_panel")
	visible = false
	tab_bestiary.pressed.connect(func() -> void: _switch_tab(&"bestiary"))
	tab_tablets.pressed.connect(func() -> void: _switch_tab(&"tablets"))
	EventBus.ui_compendium_entry_unlocked.connect(_on_unlock)
	UIAudio.wire_button_sfx(self)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J:
		toggle()
	elif visible and event.is_action_pressed("ui_cancel"):
		visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		_rebuild()
		UIAudio.play_page_flip()
	else:
		UIAudio.play_panel_close()


func _switch_tab_with_sfx(tab: StringName) -> void:
	_switch_tab(tab)
	UIAudio.play_page_flip()


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
	match _current_tab:
		&"bestiary":
			for key in GameState.unlocked_compendium.keys():
				var k: String = String(key)
				if k.begins_with("bestiary_"):
					entries.append(k.substr(9).capitalize())
		&"tablets":
			for key in GameState.unlocked_compendium.keys():
				var k: String = String(key)
				if k.begins_with("tablet_"):
					entries.append("Tablet %s" % k.substr(7))
		&"relics":
			for key in GameState.unlocked_compendium.keys():
				var k: String = String(key)
				if k.begins_with("item_"):
					entries.append(k.substr(5).capitalize().replace("_", " "))
		&"titles":
			for key in GameState.unlocked_compendium.keys():
				var k: String = String(key)
				if k.begins_with("title_"):
					entries.append(k.substr(6).capitalize().replace("_", " "))
	if entries.is_empty():
		hint.text = "(no entries yet — descend further)"
	else:
		hint.text = "%d entries" % entries.size()
	entries.sort()
	var lore_tab: bool = _current_tab != &"bestiary"
	for entry_text in entries:
		var l := Label.new()
		l.text = "• " + entry_text
		l.modulate = Color(0.97, 0.85, 0.5, 1)
		# Lore tabs (tablets / relics / titles) render in Monogram for flavor;
		# the bestiary stays on the m5x7 body so casual reads are easy.
		if lore_tab and _monogram:
			l.add_theme_font_override("font", _monogram)
			l.add_theme_font_size_override("font_size", 18)
		list_root.add_child(l)
