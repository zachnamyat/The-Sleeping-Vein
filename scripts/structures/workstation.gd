extends Area2D
class_name Workstation

## A placeable crafting station the player can interact with. When the player
## enters the interact radius and presses `interact`, the workstation UI opens
## with the recipes filtered to this station's `station_id`.

signal interacted(station: Workstation)
signal closed

@export var station_id: StringName = &"loam_bench"
@export var display_name: String = "Loam Bench"

var _player_in_range: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 2
	set_collision_mask_value(2, true)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("interact"):
		interacted.emit(self)
		if station_id == &"resonance_loom":
			get_tree().call_group("loom_panel", "open")
		else:
			get_tree().call_group("crafting_ui", "open_for", station_id, display_name)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] %s" % display_name, 1.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		closed.emit()
		get_tree().call_group("crafting_ui", "close_if_for", station_id)
