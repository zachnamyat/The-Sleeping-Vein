extends CanvasLayer
class_name WorldSettingsPanel

## Phase 15.5 — World settings UI presented at New World creation.
## Surfaces: size (small/normal/large/huge), difficulty (casual/normal/hard/
## hard+), creative mode toggle, hardcore toggle, starting kit picker.

const SIZE_LABELS: Array[String] = ["Small", "Normal", "Large", "Huge"]
const SIZE_MULTS: Array[float] = [0.5, 1.0, 1.5, 2.5]

const STARTING_KITS: Array[Dictionary] = [
	{ "id": &"none", "label": "Bare Hands", "items": {} },
	{ "id": &"explorer", "label": "Explorer", "items": {&"wooden_axe": 1, &"wooden_pickaxe": 1, &"torch": 4} },
	{ "id": &"crafter", "label": "Crafter", "items": {&"wood": 32, &"loam": 32, &"shaleseed": 12} },
	{ "id": &"warrior", "label": "Warrior", "items": {&"wooden_sword": 1, &"shaleseed_helmet": 1, &"shaleseed_chestplate": 1} },
	{ "id": &"farmer", "label": "Farmer", "items": {&"hoe_wood": 1, &"watering_can": 1, &"pale_cap_seed": 5} },
]

signal settings_applied(payload: Dictionary)

var size_idx: int = 1
var difficulty_idx: int = 1
var creative: bool = false
var hardcore: bool = false
var starting_kit_idx: int = 0

var _root: Control


func _ready() -> void:
	layer = 30
	add_to_group("world_settings_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func open_for_new_world() -> void:
	visible = true


func _build_ui() -> void:
	_root = Control.new()
	_root.anchor_left = 0.5
	_root.anchor_right = 0.5
	_root.anchor_top = 0.5
	_root.anchor_bottom = 0.5
	_root.offset_left = -300
	_root.offset_right = 300
	_root.offset_top = -240
	_root.offset_bottom = 240
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.07, 0.96)
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	_root.add_child(bg)
	var v := VBoxContainer.new()
	v.offset_left = 16
	v.offset_top = 16
	v.offset_right = -16
	v.offset_bottom = -16
	v.anchor_right = 1
	v.anchor_bottom = 1
	v.add_theme_constant_override("separation", 8)
	_root.add_child(v)
	var t := Label.new()
	t.text = "New World"
	t.add_theme_color_override("font_color", Color(0.85, 0.74, 0.45))
	v.add_child(t)
	v.add_child(_make_picker("World size", SIZE_LABELS, size_idx, func(i): size_idx = i))
	v.add_child(_make_picker("Difficulty",
		_difficulty_labels(),
		difficulty_idx,
		func(i): difficulty_idx = i
	))
	v.add_child(_make_picker("Starting kit", _kit_labels(), starting_kit_idx, func(i): starting_kit_idx = i))
	# Hardcore + Creative toggles.
	v.add_child(_make_toggle("Hardcore (permadeath)", hardcore, func(b): hardcore = b))
	v.add_child(_make_toggle("Creative mode (no progression)", creative, func(b): creative = b))
	# Buttons.
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func() -> void: visible = false)
	h.add_child(cancel_btn)
	var apply_btn := Button.new()
	apply_btn.text = "Create World"
	apply_btn.pressed.connect(_on_apply)
	h.add_child(apply_btn)


func _make_picker(label: String, options: Array, initial: int, on_change: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(160, 0)
	h.add_child(l)
	var opt := OptionButton.new()
	for o in options:
		opt.add_item(String(o))
	opt.select(clampi(initial, 0, options.size() - 1))
	opt.item_selected.connect(func(i: int) -> void: on_change.call(i))
	h.add_child(opt)
	return h


func _make_toggle(label: String, initial: bool, on_change: Callable) -> Control:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(220, 0)
	h.add_child(l)
	var c := CheckBox.new()
	c.button_pressed = initial
	c.toggled.connect(func(p: bool) -> void: on_change.call(p))
	h.add_child(c)
	return h


func _difficulty_labels() -> Array:
	var out := []
	for k in [&"casual", &"normal", &"hard", &"hard_plus"]:
		if Phase15Helpers and Phase15Helpers.DIFFICULTY_PRESETS.has(k):
			out.append(String(Phase15Helpers.DIFFICULTY_PRESETS[k].get("label", String(k))))
	if out.is_empty():
		out = ["Casual", "Normal", "Hard", "Hard+"]
	return out


func _kit_labels() -> Array:
	var out := []
	for k in STARTING_KITS:
		out.append(String(k.get("label", String(k.get("id", "?")))))
	return out


func _on_apply() -> void:
	if Phase15Helpers:
		Phase15Helpers.world_size_mult = SIZE_MULTS[clampi(size_idx, 0, SIZE_MULTS.size() - 1)]
		Phase15Helpers.creative_mode = creative
		Phase15Helpers.set_hardcore(hardcore)
		var diff_keys: Array = [&"casual", &"normal", &"hard", &"hard_plus"]
		Phase15Helpers.set_difficulty(diff_keys[clampi(difficulty_idx, 0, diff_keys.size() - 1)])
		var kit_id: StringName = StringName(String(STARTING_KITS[clampi(starting_kit_idx, 0, STARTING_KITS.size() - 1)].get("id", "none")))
		Phase15Helpers.starting_kit_id = kit_id
	settings_applied.emit({
		"world_size_mult": SIZE_MULTS[clampi(size_idx, 0, SIZE_MULTS.size() - 1)],
		"difficulty": difficulty_idx,
		"creative": creative,
		"hardcore": hardcore,
		"starting_kit": starting_kit_idx,
	})
	visible = false
