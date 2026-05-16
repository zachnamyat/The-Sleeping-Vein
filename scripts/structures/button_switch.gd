extends Area2D
class_name ButtonSwitch

## Phase 14.6 / 14.12 — Button or switch. Interact-press (E) flips its output
## wire. If `momentary` is true, it's a button (signal only while held);
## otherwise it's a toggle switch (signal stays until pressed again).

@export var output_wire: int = 0
@export var momentary: bool = false
@export var held_seconds: float = 0.6

var _player_in_range: bool = false
var _held: bool = false
var _held_timer: float = 0.0
var _toggle_value: bool = false


func _ready() -> void:
	add_to_group("button")
	add_to_group("demolishable")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("interact"):
		_press()


func _press() -> void:
	if momentary:
		Phase14Helpers.set_wire_signal(output_wire, true)
		_held = true
		_held_timer = held_seconds
	else:
		_toggle_value = not _toggle_value
		Phase14Helpers.set_wire_signal(output_wire, _toggle_value)


func _process(delta: float) -> void:
	if not _held:
		return
	_held_timer -= delta
	if _held_timer <= 0.0:
		_held = false
		Phase14Helpers.set_wire_signal(output_wire, false)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] Press", 1.2)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func get_refund_meta() -> Dictionary:
	return { "item_id": "button_placeable", "count": 1 }
