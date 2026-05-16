extends Area2D
class_name FenceGate

## Phase 14.26 — Fence-gate. Opens like a door but blocks mobs like a fence
## when closed. Interacting (E) toggles open/closed. Stays open for 8s after
## a player walks through (auto-close).

@export var open_seconds: float = 8.0

var _is_open: bool = false
var _open_timer: float = 0.0
var _player_in_range: bool = false


@onready var _solid: StaticBody2D = $StaticBody2D if has_node("StaticBody2D") else null


func _ready() -> void:
	add_to_group("fence_gate")
	add_to_group("demolishable")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_apply_state()


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("interact"):
		_open()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] Gate", 1.2)
		if _is_open:
			_open_timer = open_seconds


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func _process(delta: float) -> void:
	if not _is_open:
		return
	_open_timer -= delta
	if _open_timer <= 0.0:
		_is_open = false
		_apply_state()


func _open() -> void:
	_is_open = true
	_open_timer = open_seconds
	_apply_state()


func _apply_state() -> void:
	if _solid:
		_solid.set_collision_layer_value(1, not _is_open)


func get_refund_meta() -> Dictionary:
	return { "item_id": "fence_gate_placeable", "count": 1 }
