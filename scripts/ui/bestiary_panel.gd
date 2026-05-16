extends CanvasLayer
class_name BestiaryPanel

## Phase 15.3 — full bestiary screen.
## Lists every MobDef + BossDef the player has ever encountered with HP / damage
## / weakness data unlocked over time (first encounter shows silhouette, kill
## reveals stats, three kills reveal weaknesses).
##
## Self-contained: builds its own UI in code so we don't need a .tscn.

const BESTIARY_ROOT: String = "res://resources/mobs/"
const PANEL_W: int = 720
const PANEL_H: int = 480

var _open: bool = false
var _root: Control
var _list: VBoxContainer
var _detail: VBoxContainer
var _scroll: ScrollContainer
var _entries: Array[Dictionary] = []
var _selected_idx: int = -1


func _ready() -> void:
	layer = 25
	add_to_group("bestiary_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = (event as InputEventKey).keycode
		if k == KEY_K and not _open:
			# Allow K to open from gameplay; if other handlers also use K we
			# rely on cancel to close.
			toggle()


func toggle() -> void:
	_open = not _open
	visible = _open
	if _open:
		_refresh()


func _build_ui() -> void:
	_root = Control.new()
	_root.anchor_left = 0.5
	_root.anchor_right = 0.5
	_root.anchor_top = 0.5
	_root.anchor_bottom = 0.5
	_root.offset_left = -PANEL_W / 2
	_root.offset_right = PANEL_W / 2
	_root.offset_top = -PANEL_H / 2
	_root.offset_bottom = PANEL_H / 2
	add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.96)
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	_root.add_child(bg)

	var border := ColorRect.new()
	border.color = Color(0.55, 0.50, 0.35, 1)
	border.anchor_right = 1
	border.anchor_top = 0
	border.anchor_bottom = 0
	border.offset_top = 0
	border.offset_bottom = 1
	_root.add_child(border)

	var title := Label.new()
	title.text = "Bestiary"
	title.offset_left = 16
	title.offset_top = 8
	title.add_theme_color_override("font_color", Color(0.85, 0.74, 0.45))
	_root.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.offset_left = 16
	hbox.offset_top = 36
	hbox.offset_right = PANEL_W - 16
	hbox.offset_bottom = PANEL_H - 16
	hbox.anchor_right = 0
	hbox.anchor_bottom = 0
	_root.add_child(hbox)

	# Left scroll-list.
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(280, PANEL_H - 60)
	hbox.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_scroll.add_child(_list)

	# Right detail.
	_detail = VBoxContainer.new()
	_detail.custom_minimum_size = Vector2(380, PANEL_H - 60)
	_detail.add_theme_constant_override("separation", 4)
	hbox.add_child(_detail)


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	_entries.clear()
	# Scan unlocked compendium for bestiary_* prefixed keys + look up MobDef.
	for key in GameState.unlocked_compendium.keys():
		var k: String = String(key)
		if not k.begins_with("bestiary_"):
			continue
		var mob_id: String = k.substr(9)
		var def_path: String = "res://resources/mobs/%s.tres" % mob_id
		var def: Resource = null
		if ResourceLoader.exists(def_path):
			def = load(def_path)
		var entry: Dictionary = {
			"id": mob_id,
			"display_name": _label_for(mob_id, def),
			"def": def,
			"unlock_count": _unlock_tier_for(mob_id),
		}
		_entries.append(entry)
	_entries.sort_custom(func(a, b): return String(a["display_name"]) < String(b["display_name"]))
	if _entries.is_empty():
		var l := Label.new()
		l.text = "(no entries yet — defeat enemies to record them)"
		l.modulate = Color(0.7, 0.65, 0.55)
		_list.add_child(l)
	for i in range(_entries.size()):
		var row := Button.new()
		row.text = String(_entries[i]["display_name"])
		row.flat = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx := i
		row.pressed.connect(func() -> void: _select(idx))
		_list.add_child(row)
	if _selected_idx < 0 and not _entries.is_empty():
		_select(0)
	elif _selected_idx >= 0:
		_render_detail()


func _select(idx: int) -> void:
	_selected_idx = idx
	_render_detail()


func _render_detail() -> void:
	for child in _detail.get_children():
		child.queue_free()
	if _selected_idx < 0 or _selected_idx >= _entries.size():
		return
	var entry: Dictionary = _entries[_selected_idx]
	var def: Resource = entry["def"]
	var name_lbl := Label.new()
	name_lbl.text = String(entry["display_name"])
	name_lbl.add_theme_color_override("font_color", Color(0.97, 0.85, 0.5))
	_detail.add_child(name_lbl)
	if def == null:
		var miss := Label.new()
		miss.text = "(definition unavailable — silhouette only)"
		miss.modulate = Color(0.7, 0.65, 0.55)
		_detail.add_child(miss)
		return
	var tier: int = int(entry["unlock_count"])
	# Always show class.
	_add_stat("Class", String(def.get("mob_class") if def.get("mob_class") else "—"))
	if tier >= 1:
		_add_stat("HP", str(def.get("base_hp") if def.get("base_hp") else "—"))
		_add_stat("Damage", str(def.get("base_damage") if def.get("base_damage") else "—"))
	if tier >= 3:
		var weaknesses: Variant = def.get("weaknesses") if def.get("weaknesses") else null
		if weaknesses != null and weaknesses is Dictionary:
			var ws: String = ""
			for k in (weaknesses as Dictionary).keys():
				ws += "%s ×%.1f  " % [String(k), float((weaknesses as Dictionary)[k])]
			_add_stat("Weaknesses", ws)
	# Lore blurb.
	if def.get("lore_blurb"):
		var l := Label.new()
		l.text = String(def.get("lore_blurb"))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.modulate = Color(0.85, 0.78, 0.6)
		l.add_theme_constant_override("line_separation", 2)
		_detail.add_child(l)


func _add_stat(label: String, value: String) -> void:
	var l := Label.new()
	l.text = "%s: %s" % [label, value]
	l.modulate = Color(0.9, 0.86, 0.7)
	_detail.add_child(l)


func _label_for(mob_id: String, def: Resource) -> String:
	if def and def.get("display_name"):
		return String(def.get("display_name"))
	return mob_id.replace("_", " ").capitalize()


func _unlock_tier_for(mob_id: String) -> int:
	# Bestiary tier scales with kill count. The Compendium autoload stores
	# the per-mob kill count for this purpose via a "_kill_count_<id>" prefix
	# we manage here.
	var key: StringName = StringName("_kill_count_%s" % mob_id)
	return int(GameState.unlocked_compendium.get(key, 1))
