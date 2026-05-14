extends Area2D
class_name Workstation

## A placeable crafting station the player can interact with. When the player
## enters the interact radius and presses `interact`, the workstation UI opens
## with the recipes filtered to this station's `station_id`.
## Phase 3.32 — adjacency: when the player opens any workstation, the crafting
## panel queries every workstation in the `workstation` group within
## ADJACENCY_RADIUS px and concatenates their station_ids. This lets a player
## standing between a Loam Bench and a Furnace see both stations' recipes
## without walking across.

signal interacted(station: Workstation)
signal closed

const ADJACENCY_RADIUS: float = 48.0

@export var station_id: StringName = &"loam_bench"
@export var display_name: String = "Loam Bench"

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("workstation")
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
			# Phase 3.32 — pass adjacent station ids so the panel can show all
			# of their recipes in one list.
			var ids := nearby_station_ids()
			get_tree().call_group(
				"crafting_ui",
				"open_for_adjacent",
				station_id,
				display_name,
				ids,
			)


## Returns the StringName ids of every Workstation within ADJACENCY_RADIUS,
## including this one. Order: this station first, then nearest first.
func nearby_station_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.append(station_id)
	var stations := get_tree().get_nodes_in_group("workstation")
	for s in stations:
		if s == self:
			continue
		var node := s as Node2D
		if node == null:
			continue
		var dist: float = node.global_position.distance_to(global_position)
		if dist > ADJACENCY_RADIUS:
			continue
		var sid: StringName = node.get("station_id")
		if sid == &"" or sid in out:
			continue
		out.append(sid)
	return out


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] %s" % display_name, 1.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		closed.emit()
		get_tree().call_group("crafting_ui", "close_if_for", station_id)
