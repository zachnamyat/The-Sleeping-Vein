extends CanvasLayer
class_name PauseMenu

## ESC opens a pause overlay with Resume / Save / Load / Quit-to-Title / Quit.
## Pauses the SceneTree while visible. Save/Load go through SaveSystem.

const SLOT_NAME: String = "auto"

@onready var status_label: Label = $Root/Status


func _ready() -> void:
	add_to_group("pause_menu")
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Root/Buttons/Resume.pressed.connect(_resume)
	$Root/Buttons/Save.pressed.connect(_save)
	$Root/Buttons/Load.pressed.connect(_load)
	$Root/Buttons/Title.pressed.connect(_to_title)
	$Root/Buttons/Quit.pressed.connect(_quit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible and status_label:
		status_label.text = ""


func _resume() -> void:
	visible = false
	get_tree().paused = false


func _save() -> void:
	var err: int = SaveSystem.save_to_slot(SLOT_NAME)
	status_label.text = "Saved." if err == OK else "Save failed: %s" % error_string(err)


func _load() -> void:
	if not SaveSystem.slot_exists(SLOT_NAME):
		status_label.text = "No save in slot '%s'." % SLOT_NAME
		return
	var err: int = SaveSystem.load_from_slot(SLOT_NAME)
	status_label.text = "Loaded." if err == OK else "Load failed: %s" % error_string(err)
	if err == OK:
		_resume()


func _to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")


func _quit() -> void:
	get_tree().quit()
