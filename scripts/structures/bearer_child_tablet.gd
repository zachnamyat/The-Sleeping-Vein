extends Area2D
class_name BearerChildTablet

## Phase 12.32 — The Bearer's pre-Diadem child memory tablet. RH-08-equivalent
## (single-tablet structure in the Final Spiral). Reading sets
## Phase12Helpers.bearer_child_tablet_read = true and unlocks the
## bearer_child_memory Compendium entry. Required for 12.36 (Joren reveal)
## and for 12.37 (Mira-Bearer sibling scene).

@export var preview_text: String = "A child's name carved in faltering Old Vesari."

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("bearer_child_tablet")
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
	if Phase12Helpers and not Phase12Helpers.bearer_child_tablet_read:
		Phase12Helpers.read_bearer_child_tablet()
	EventBus.ui_toast.emit("Tablet: \"My brother's name was Joren-of-the-Lattice. He was kind. He was afraid. The Diadem took him in.\"", 7.0)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] Read child-memory tablet", 1.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
