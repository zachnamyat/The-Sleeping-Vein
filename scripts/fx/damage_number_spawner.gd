extends Node
class_name DamageNumberSpawner

## Phase 2.20 — subscribes once to EventBus.damage_floated and spawns a
## DamageNumber instance at the world position of each hit. Lives as a child
## of the main world scene; despawned automatically with the scene.

@export var spawn_parent_path: NodePath = NodePath("..")


func _ready() -> void:
	EventBus.damage_floated.connect(_on_damage_floated)


func _on_damage_floated(world_pos: Vector2, amount: int, is_crit: bool, _type: StringName) -> void:
	if amount <= 0:
		return
	var parent := get_node_or_null(spawn_parent_path)
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return
	var node := DamageNumber.new()
	node.amount = amount
	node.is_crit = is_crit
	node.global_position = world_pos + Vector2(0, -16)
	parent.add_child(node)
	# Ticket 2.29 — crit screen pulse so the player can feel the big hit even
	# if the floating number is offscreen.
	if is_crit:
		EventBus.screen_pulse_requested.emit(0.18, 0.12)
		EventBus.camera_shake_requested.emit(3.0, 0.14)
