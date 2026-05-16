extends Area2D
class_name SensorModule

## Phase 14.6 — Sensor. Different `sensor_kind` values use different triggers:
##   "proximity" — mask 2 (player) within radius
##   "light"     — emit if the world_gen reports the player is NOT under a roof
##   "health"    — emit if local player's HP fraction < threshold
##   "mob"       — mask 4 (any mob) within radius

@export var output_wire: int = 0
@export var sensor_kind: StringName = &"proximity"
@export var radius: float = 32.0
@export var health_threshold: float = 0.5

var _emit: bool = false
var _bodies_inside: int = 0


func _ready() -> void:
	add_to_group("sensor")
	add_to_group("demolishable")
	collision_layer = 0
	match String(sensor_kind):
		"proximity":
			collision_mask = 2
		"mob":
			collision_mask = 4
		_:
			collision_mask = 0
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(_body: Node) -> void:
	_bodies_inside += 1
	if _bodies_inside == 1:
		_apply_signal(true)


func _on_body_exited(_body: Node) -> void:
	_bodies_inside = max(0, _bodies_inside - 1)
	if _bodies_inside == 0:
		_apply_signal(false)


func _process(_delta: float) -> void:
	match String(sensor_kind):
		"light":
			var player := _find_player()
			if player == null:
				return
			# WorldGen is a class_name, not an autoload. Look it up by group.
			var wg := _find_world_gen()
			var lit: bool = true
			if wg != null and wg.has_method("is_under_roof"):
				lit = not wg.call("is_under_roof", player.global_position)
			_apply_signal(lit)
		"health":
			var player2 := _find_player()
			if player2 == null:
				return
			var hp := player2.get_node_or_null("HealthComponent")
			if hp == null:
				return
			var frac: float = float(hp.current_health) / max(1.0, float(hp.max_health))
			_apply_signal(frac < health_threshold)


func _find_player() -> Node2D:
	var arr := get_tree().get_nodes_in_group("player")
	if arr.is_empty():
		return null
	return arr[0] as Node2D


func _find_world_gen() -> Node:
	# Search the scene tree for the WorldGen instance.
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.find_child("WorldGen", true, false)


## Different name from Object._set(StringName, Variant) -> bool to avoid
## the parent-class signature clash GDScript complains about.
func _apply_signal(value: bool) -> void:
	if _emit == value:
		return
	_emit = value
	Phase14Helpers.set_wire_signal(output_wire, value)


func get_refund_meta() -> Dictionary:
	return { "item_id": "sensor_placeable", "count": 1 }
