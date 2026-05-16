extends Area2D
class_name WormboundElder

## Phase 11.9 + 11.26 + 11.29 — Wormbound elder threshold encounter.
##
## The elder is silent; the player must perform the gesture-input minigame
## (up / right / down) within range to receive the Wormbound Covenant Scroll.
##
## Inputs map to the standard movement actions:
##   move_up   → &"up"
##   move_right → &"right"
##   move_down → &"down"
## Other directions reset the sequence.

@export var display_name: String = "Wormbound Elder"

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("wormbound_elder")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 2


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("move_up"):
		_gesture(&"up")
	elif event.is_action_pressed("move_right"):
		_gesture(&"right")
	elif event.is_action_pressed("move_down"):
		_gesture(&"down")
	elif event.is_action_pressed("move_left"):
		_gesture(&"left")


func _gesture(direction: StringName) -> void:
	if Phase11Helpers:
		Phase11Helpers.wormbound_gesture(direction)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("The elder waits. (WASD: up, right, down)", 4.0)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
