extends CanvasLayer
class_name DeathScreen

## Phase 1 tickets 1.14 + 1.49. Full-screen overlay that shows the sliver cost,
## a summary line, and Retry / Load / Quit buttons when the player dies.
## Subscribes to EventBus.player_died and EventBus.player_respawned.

const SLOT_NAME: String = "auto"

var _root: Control
var _msg: Label
var _slivers_label: Label
var _retry: Button
var _load: Button
var _quit: Button


func _ready() -> void:
	add_to_group("death_screen")
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_respawned.connect(_on_player_respawned)


func _build() -> void:
	_root = Control.new()
	_root.anchor_left = 0.0
	_root.anchor_top = 0.0
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	_root.add_child(bg)

	_msg = Label.new()
	_msg.text = "You Died"
	_msg.modulate = Color(0.97, 0.32, 0.25)
	_msg.add_theme_font_size_override("font_size", 24)
	_msg.anchor_left = 0.5
	_msg.anchor_right = 0.5
	_msg.offset_left = -100.0
	_msg.offset_right = 100.0
	_msg.offset_top = 70.0
	_msg.offset_bottom = 100.0
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_msg)

	_slivers_label = Label.new()
	_slivers_label.modulate = Color(0.95, 0.85, 0.5)
	_slivers_label.anchor_left = 0.5
	_slivers_label.anchor_right = 0.5
	_slivers_label.offset_left = -120.0
	_slivers_label.offset_right = 120.0
	_slivers_label.offset_top = 108.0
	_slivers_label.offset_bottom = 124.0
	_slivers_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_slivers_label)

	var btns := VBoxContainer.new()
	btns.anchor_left = 0.5
	btns.anchor_right = 0.5
	btns.offset_left = -60.0
	btns.offset_right = 60.0
	btns.offset_top = 140.0
	btns.offset_bottom = 220.0
	btns.add_theme_constant_override("separation", 4)
	_root.add_child(btns)

	_retry = Button.new()
	_retry.text = "Retry"
	_retry.pressed.connect(_on_retry)
	btns.add_child(_retry)

	_load = Button.new()
	_load.text = "Load Save"
	_load.pressed.connect(_on_load)
	btns.add_child(_load)

	_quit = Button.new()
	_quit.text = "Quit to Title"
	_quit.pressed.connect(_on_quit)
	btns.add_child(_quit)


func _on_player_died(_player: Node) -> void:
	if _slivers_label:
		_slivers_label.text = "Aphelion slivers: %d" % GameState.aphelion_slivers_remaining
	visible = true
	UIAudio.wire_button_sfx(self)


func _on_player_respawned(_player: Node, _slivers: int) -> void:
	visible = false


func _on_retry() -> void:
	# Player controller auto-respawns; just hide.
	visible = false


func _on_load() -> void:
	if not SaveSystem.slot_exists(SLOT_NAME):
		return
	SaveSystem.load_from_slot(SLOT_NAME)
	visible = false


func _on_quit() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
