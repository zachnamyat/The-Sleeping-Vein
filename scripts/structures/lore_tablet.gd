extends Area2D
class_name LoreTablet

## Phase 4.24 — pre-placed lore-tablet structure. Reading grants a Compendium
## entry + emits ui_compendium_entry_unlocked. The Compendium owns the actual
## text per entry_id; this scene is just the world-anchor.

@export var entry_id: StringName = &"lore_tablet_generic"
@export var preview_text: String = "A stone tablet carved with golden glyphs."

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("lore_tablet")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 2


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("interact"):
		_read()


func _read() -> void:
	if GameState.unlocked_compendium.get(entry_id, false):
		EventBus.ui_toast.emit("The tablet hums — you have already heard its name.", 2.0)
		return
	GameState.unlocked_compendium[entry_id] = true
	EventBus.ui_compendium_entry_unlocked.emit(entry_id)
	EventBus.ui_toast.emit("Lore unlocked: %s" % String(entry_id), 3.0)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] Read tablet", 1.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
