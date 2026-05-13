extends Control
class_name WorldCreationPanel

## Phase 1 ticket 1.18. New-world creation form: name + seed + size + difficulty.
## Persists chosen values into GameState (world_seed, world_size, difficulty)
## then transitions into main.tscn. Phase 4 will consume world_size during
## procedural generation; Phase 1 just stores the value.

@export var seed_default: int = 1337

var name_edit: LineEdit
var seed_edit: LineEdit
var size_btn: OptionButton
var difficulty_btn: OptionButton
var create_btn: Button
var back_btn: Button
var status_label: Label

const SIZE_OPTIONS: Array[Dictionary] = [
	{"label": "Small (64x64 chunks)", "value": 64},
	{"label": "Standard (128x128 chunks)", "value": 128},
	{"label": "Vast (256x256 chunks)", "value": 256},
]
const DIFFICULTY_OPTIONS: Array[Dictionary] = [
	{"label": "Casual", "value": "casual"},
	{"label": "Standard", "value": "standard"},
	{"label": "Hard", "value": "hard"},
	{"label": "Hardcore", "value": "hardcore"},
]


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
	form.anchor_top = 0.3
	form.offset_left = -120.0
	form.offset_right = 120.0
	form.offset_top = 0.0
	form.offset_bottom = 240.0
	form.add_theme_constant_override("separation", 4)
	add_child(form)

	var title := Label.new()
	title.text = "Create World"
	title.modulate = Color(0.97, 0.85, 0.5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	form.add_child(title)

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "World name"
	name_edit.text = "Untitled Vein"
	form.add_child(name_edit)

	seed_edit = LineEdit.new()
	seed_edit.placeholder_text = "Seed (blank for random)"
	form.add_child(seed_edit)

	size_btn = OptionButton.new()
	for opt in SIZE_OPTIONS:
		size_btn.add_item(String(opt["label"]))
	size_btn.selected = 1
	form.add_child(size_btn)

	difficulty_btn = OptionButton.new()
	for opt in DIFFICULTY_OPTIONS:
		difficulty_btn.add_item(String(opt["label"]))
	difficulty_btn.selected = 1
	form.add_child(difficulty_btn)

	create_btn = Button.new()
	create_btn.text = "Create + Wake"
	create_btn.pressed.connect(_on_create)
	form.add_child(create_btn)

	back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.pressed.connect(close)
	form.add_child(back_btn)

	status_label = Label.new()
	status_label.modulate = Color(0.85, 0.75, 0.5)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	form.add_child(status_label)


func open() -> void:
	visible = true
	UIAudio.play_panel_open()


func close() -> void:
	visible = false
	UIAudio.play_panel_close()


func _on_create() -> void:
	var seed_text := seed_edit.text.strip_edges()
	var seed_val: int = seed_default
	if seed_text.is_empty():
		seed_val = int(Time.get_unix_time_from_system())
	elif seed_text.is_valid_int():
		seed_val = int(seed_text)
	else:
		seed_val = hash(seed_text)
	GameState.world_seed = seed_val
	if GameState.has_method("set"):
		GameState.set("world_size", int(SIZE_OPTIONS[size_btn.selected]["value"]))
		GameState.set("difficulty", String(DIFFICULTY_OPTIONS[difficulty_btn.selected]["value"]))
		GameState.set("world_name", name_edit.text.strip_edges())
	get_tree().change_scene_to_file("res://scenes/world/main.tscn")
