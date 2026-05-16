extends Area2D
class_name FishTrophy

## Phase 8.36 — A wall-mounted trophy for the heaviest fish caught of a given
## species. Interact to see the record.

@export var displayed_fish: StringName = &"cave_guppy"

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("fish_trophy")
	monitorable = false
	monitoring = true
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] Trophy: %s" % String(displayed_fish), 1.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or not event.is_action_pressed("interact"):
		return
	var weight: int = int(FishingSystem.trophies.get(displayed_fish, 0))
	if weight == 0:
		EventBus.ui_toast.emit("Catch %s first." % String(displayed_fish), 2.0)
		return
	EventBus.ui_toast.emit("Heaviest %s: %dg" % [String(displayed_fish), weight], 3.0)


func dump_state() -> Dictionary:
	return { "displayed_fish": String(displayed_fish) }


func restore_state(data: Dictionary) -> void:
	displayed_fish = StringName(String(data.get("displayed_fish", "cave_guppy")))
