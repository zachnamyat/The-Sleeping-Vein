extends CanvasLayer
class_name WardrobePanel

## Phase 15 — Wardrobe / dye panel.
## Tickets: 3.36 dye + 3.37 wardrobe + 3.62-3.65 + 3.68 + 3.69.
##
## Combined screen with two tabs: "Dye" and "Outfits".

var _open: bool = false
var _root: Control
var _content: VBoxContainer
var _tab: StringName = &"dye"


func _ready() -> void:
	layer = 25
	add_to_group("wardrobe_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


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
	_root.offset_left = -260
	_root.offset_right = 260
	_root.offset_top = -220
	_root.offset_bottom = 220
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.96)
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	_root.add_child(bg)
	var t := Label.new()
	t.text = "Wardrobe"
	t.offset_left = 16
	t.offset_top = 8
	t.add_theme_color_override("font_color", Color(0.85, 0.74, 0.45))
	_root.add_child(t)
	var tabs := HBoxContainer.new()
	tabs.offset_left = 16
	tabs.offset_top = 36
	_root.add_child(tabs)
	var dye_btn := Button.new()
	dye_btn.text = "Dye"
	dye_btn.pressed.connect(func() -> void: _tab = &"dye"; _refresh())
	tabs.add_child(dye_btn)
	var out_btn := Button.new()
	out_btn.text = "Outfits"
	out_btn.pressed.connect(func() -> void: _tab = &"outfits"; _refresh())
	tabs.add_child(out_btn)
	var vis_btn := Button.new()
	vis_btn.text = "Visuals"
	vis_btn.pressed.connect(func() -> void: _tab = &"visuals"; _refresh())
	tabs.add_child(vis_btn)
	_content = VBoxContainer.new()
	_content.offset_left = 16
	_content.offset_top = 76
	_content.offset_right = -16
	_content.offset_bottom = -16
	_content.anchor_right = 1
	_content.anchor_bottom = 1
	_content.add_theme_constant_override("separation", 6)
	_root.add_child(_content)


func _refresh() -> void:
	for c in _content.get_children():
		c.queue_free()
	if CosmeticsManager == null:
		var miss := Label.new()
		miss.text = "(cosmetics module not loaded)"
		miss.modulate = Color(0.7, 0.65, 0.55)
		_content.add_child(miss)
		return
	match _tab:
		&"dye":
			_build_dye_tab()
		&"outfits":
			_build_outfits_tab()
		&"visuals":
			_build_visuals_tab()


# ---------- Dye (3.36) ----------

func _build_dye_tab() -> void:
	for layer_id in CosmeticsManager.LAYERS:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = String(layer_id).replace("_", " ").capitalize()
		l.custom_minimum_size = Vector2(130, 0)
		l.modulate = Color(0.9, 0.86, 0.7)
		row.add_child(l)
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(40, 24)
		picker.color = CosmeticsManager.get_dye(layer_id)
		picker.color_changed.connect(func(c: Color) -> void:
			CosmeticsManager.apply_dye(layer_id, c)
			if AchievementsExtended:
				AchievementsExtended.note_dye_applied()
		)
		row.add_child(picker)
		var reset := Button.new()
		reset.text = "reset"
		reset.pressed.connect(func() -> void:
			CosmeticsManager.reset_dye(layer_id)
			_refresh()
		)
		row.add_child(reset)
		_content.add_child(row)


# ---------- Outfits (3.37) ----------

func _build_outfits_tab() -> void:
	for i in range(CosmeticsManager.WARDROBE_SLOTS):
		var rec: Dictionary = CosmeticsManager.wardrobe[i] if i < CosmeticsManager.wardrobe.size() else {}
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = String(rec.get("label", "Outfit %d" % (i + 1)))
		l.custom_minimum_size = Vector2(180, 0)
		l.modulate = Color(0.9, 0.86, 0.7)
		row.add_child(l)
		var save_btn := Button.new()
		save_btn.text = "Save current"
		var idx := i
		save_btn.pressed.connect(func() -> void:
			CosmeticsManager.save_outfit(idx)
			if AchievementsExtended:
				AchievementsExtended.note_outfit_saved()
			_refresh()
		)
		row.add_child(save_btn)
		var load_btn := Button.new()
		load_btn.text = "Wear"
		load_btn.pressed.connect(func() -> void: CosmeticsManager.load_outfit(idx))
		row.add_child(load_btn)
		_content.add_child(row)


# ---------- Visuals (3.62-3.65, 3.68, 3.69) ----------

func _build_visuals_tab() -> void:
	var l := Label.new()
	l.text = "Show / hide visual layers"
	l.modulate = Color(0.97, 0.85, 0.5)
	_content.add_child(l)
	for layer_id in CosmeticsManager.LAYERS:
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = String(layer_id).replace("_", " ").capitalize()
		lbl.custom_minimum_size = Vector2(180, 0)
		row.add_child(lbl)
		var c := CheckBox.new()
		c.button_pressed = not CosmeticsManager.is_layer_hidden(layer_id)
		c.toggled.connect(func(visible: bool) -> void:
			CosmeticsManager.set_layer_hidden(layer_id, not visible)
		)
		row.add_child(c)
		_content.add_child(row)
