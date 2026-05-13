extends Control
class_name CharacterCreationPanel

## Phase 1 ticket 1.16 placeholder. Name + template/hair/skin/outfit dropdowns
## plus accent color. Persists to GameState so the world bootstrap can apply
## the look later. Visual variants ship when the Walker sprite rig lands;
## until then the dropdowns are stubbed with single options.

const TEMPLATE_OPTIONS: Array[String] = ["Walker (default)"]
const HAIR_OPTIONS: Array[String] = ["Short", "Tied", "Crown"]
const SKIN_OPTIONS: Array[String] = ["Tan", "Pale", "Dusk", "Coal"]
const OUTFIT_OPTIONS: Array[String] = ["Starter Robes", "Hollow Wrap", "Aphelion Cloth"]

var name_edit: LineEdit
var template_btn: OptionButton
var hair_btn: OptionButton
var skin_btn: OptionButton
var outfit_btn: OptionButton
var accent_btn: ColorPickerButton
var confirm_btn: Button
var back_btn: Button


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	UIAudio.wire_button_sfx(self)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03, 0.92)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var form := VBoxContainer.new()
	form.anchor_left = 0.5
	form.anchor_right = 0.5
	form.anchor_top = 0.2
	form.offset_left = -120.0
	form.offset_right = 120.0
	form.offset_top = 0.0
	form.offset_bottom = 260.0
	form.add_theme_constant_override("separation", 4)
	add_child(form)

	var title := Label.new()
	title.text = "Create Walker"
	title.modulate = Color(0.97, 0.85, 0.5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	form.add_child(title)

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Walker name"
	name_edit.text = "Walker"
	form.add_child(name_edit)

	template_btn = _make_option_row(form, "Template", TEMPLATE_OPTIONS)
	hair_btn = _make_option_row(form, "Hair", HAIR_OPTIONS)
	skin_btn = _make_option_row(form, "Skin", SKIN_OPTIONS)
	outfit_btn = _make_option_row(form, "Outfit", OUTFIT_OPTIONS)

	var accent_row := HBoxContainer.new()
	var accent_label := Label.new()
	accent_label.text = "Accent"
	accent_label.custom_minimum_size = Vector2(80, 0)
	accent_row.add_child(accent_label)
	accent_btn = ColorPickerButton.new()
	accent_btn.color = Color(1.0, 0.85, 0.45)
	accent_btn.custom_minimum_size = Vector2(140, 0)
	accent_row.add_child(accent_btn)
	form.add_child(accent_row)

	confirm_btn = Button.new()
	confirm_btn.text = "Confirm + Wake"
	confirm_btn.pressed.connect(_on_confirm)
	form.add_child(confirm_btn)

	back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.pressed.connect(close)
	form.add_child(back_btn)


func _make_option_row(parent: Container, label_text: String, choices: Array[String]) -> OptionButton:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(80, 0)
	row.add_child(lbl)
	var opt := OptionButton.new()
	for c in choices:
		opt.add_item(c)
	opt.custom_minimum_size = Vector2(140, 0)
	row.add_child(opt)
	parent.add_child(row)
	return opt


func open() -> void:
	visible = true
	UIAudio.play_panel_open()


func close() -> void:
	visible = false
	UIAudio.play_panel_close()


func _on_confirm() -> void:
	if GameState.has_method("set"):
		GameState.set("character_name", name_edit.text.strip_edges())
		GameState.set("character_template", TEMPLATE_OPTIONS[template_btn.selected])
		GameState.set("character_hair", HAIR_OPTIONS[hair_btn.selected])
		GameState.set("character_skin", SKIN_OPTIONS[skin_btn.selected])
		GameState.set("character_outfit", OUTFIT_OPTIONS[outfit_btn.selected])
	if Settings:
		var c: Color = accent_btn.color
		Settings.set_value("accent_color", "#%02x%02x%02x" % [int(c.r * 255), int(c.g * 255), int(c.b * 255)])
	# Hand off to world creation next, then main.
	var parent_node := get_parent()
	if parent_node and parent_node.has_node("WorldCreationPanel"):
		close()
		var wc := parent_node.get_node("WorldCreationPanel") as WorldCreationPanel
		if wc:
			wc.open()
	else:
		get_tree().change_scene_to_file("res://scenes/world/main.tscn")
