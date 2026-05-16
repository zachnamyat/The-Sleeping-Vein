extends Node
class_name StatusOverlaySpawner

## Phase 6.50 — listens to player_spawned + entity_killed and group "mob" via
## a periodic scan, attaching a StatusOverlay child to every entity that has a
## StatusEffects component but no overlay yet. Cheap (runs once per second).

const SCAN_INTERVAL: float = 0.5
var _accum: float = 0.0


func _ready() -> void:
	EventBus.player_spawned.connect(_attach_to_node)
	set_process(true)


func _process(delta: float) -> void:
	_accum += delta
	if _accum < SCAN_INTERVAL:
		return
	_accum = 0.0
	# Mobs spawn during play (chunk gen), so periodically attach to anything new.
	for n in get_tree().get_nodes_in_group("mob"):
		_attach_to_node(n)
	for n in get_tree().get_nodes_in_group("player"):
		_attach_to_node(n)


func _attach_to_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_node_or_null("StatusOverlay") != null:
		return
	var status := node.get_node_or_null("StatusEffects") as StatusEffects
	if status == null:
		return
	var overlay := StatusOverlay.new()
	overlay.name = "StatusOverlay"
	overlay.status_path = NodePath("../StatusEffects")
	node.add_child(overlay)
