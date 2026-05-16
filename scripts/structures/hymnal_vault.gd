extends Area2D
class_name HymnalVault

## Phase 11.27 — Hymnal Vault. Player stands near the vault and chimes notes
## by pressing hotbar 1 (low) or hotbar 2 (high). The currently-saved correct
## chord is held in Phase11Helpers.HYMNAL_CORRECT_CHORD (low / high / low).
## Three correct notes in sequence opens a hidden auroric passage flag.

@export var display_name: String = "Hymnal Vault"

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("hymnal_vault")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 2


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("hotbar_1"):
		_play_note(&"low")
	elif event.is_action_pressed("hotbar_2"):
		_play_note(&"high")


func _play_note(note: StringName) -> void:
	if Phase11Helpers:
		Phase11Helpers.play_hymnal_note(note)
	if AudioBus:
		AudioBus.play_sfx(StringName("hymnal_%s" % note))


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[1] low / [2] high — Hymnal Vault", 2.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
