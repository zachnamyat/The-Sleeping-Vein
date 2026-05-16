extends Area2D
class_name Bed

## Phase 5.13 — bed placeable. Interacting (E) calls the player's
## try_sleep_in_bed flow which:
##   - aborts if hostiles are within ~200px (Phase 4.64)
##   - fades to black via letterbox, skips ~8 minutes of world clock
##   - heals 25% of max HP on wake
## Also binds the player's respawn point to this bed when set as primary.

@export var binds_respawn: bool = true

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("bed")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 2


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("interact"):
		_use_bed()


func _use_bed() -> void:
	if binds_respawn:
		GameState.set_respawn_point(global_position)
		for p in get_tree().get_nodes_in_group("player"):
			if p.has_method("set_respawn_position"):
				p.call("set_respawn_position", global_position)
	for p in get_tree().get_nodes_in_group("player"):
		if p.has_method("try_sleep_in_bed"):
			p.call("try_sleep_in_bed")


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] Rest", 1.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
