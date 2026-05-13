extends CanvasLayer
class_name EndingsPanel

## Endings selector. Opens when the Diadem-Bearer is defeated.
## Three endings per lore §08 + roadmap Phase 12:
##   A — Restore: feed the Walker's gold threads back to the Aphelion.
##   B — Break:   shatter the seal; fight the Aphelion (Phase 12.10).
##   C — Become:  the Walker becomes the new anchor (requires 9 sovereign threads).
##
## Choice is recorded in GameState; New Game+ is unlocked.

@onready var title: Label = $Root/Title
@onready var subtitle: RichTextLabel = $Root/Sub
@onready var btn_restore: Button = $Root/Choices/Restore
@onready var btn_break: Button = $Root/Choices/Break
@onready var btn_become: Button = $Root/Choices/Become
@onready var credits_lbl: RichTextLabel = $Root/Credits


func _ready() -> void:
	add_to_group("endings_ui")
	visible = false
	EventBus.boss_defeated.connect(_on_boss_defeated)
	btn_restore.pressed.connect(_choose_restore)
	btn_break.pressed.connect(_choose_break)
	btn_become.pressed.connect(_choose_become)


func _on_boss_defeated(boss_id: StringName) -> void:
	if boss_id != &"boss_diadem_bearer":
		return
	open()


func open() -> void:
	visible = true
	title.text = "The Diadem-Bearer has fallen."
	subtitle.text = "[i]The Aphelion's last sliver hangs in the air. Three paths open before you.[/i]"
	credits_lbl.text = ""
	btn_become.disabled = GameState.sovereign_threads < 9


func _choose_restore() -> void:
	GameState.unlocked_compendium[&"ending_restore"] = true
	credits_lbl.text = "[b]ENDING A — Restore.[/b]\n[i]The Walker offers their gold threads to the Aphelion. The captive sun brightens. Slowly, the Hollow remembers how to breathe.[/i]\n\nNew Game+ unlocked."
	_finish()


func _choose_break() -> void:
	GameState.unlocked_compendium[&"ending_break"] = true
	credits_lbl.text = "[b]ENDING B — Break.[/b]\n[i]The Walker shatters the seal. The Aphelion, freed, becomes itself again — and what it becomes is something new. The Hollow ends, and the long morning begins.[/i]\n\nNew Game+ unlocked."
	_finish()


func _choose_become() -> void:
	GameState.unlocked_compendium[&"ending_become"] = true
	credits_lbl.text = "[b]ENDING C — Become.[/b]\n[i]The Walker, woven by descent into something neither Aphelion nor Hollow, takes the captive sun's place. The strata wake to a new anchor — quieter, smaller, but kept.[/i]\n\nNew Game+ unlocked."
	_finish()


func _finish() -> void:
	btn_restore.disabled = true
	btn_break.disabled = true
	btn_become.disabled = true
	get_tree().paused = false
	credits_lbl.text += "\n\n[Press N to start New Game+]"


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N:
		if btn_restore.disabled:  # implies an ending was chosen
			GameState.start_new_game_plus()
			get_tree().change_scene_to_file("res://scenes/world/main.tscn")
