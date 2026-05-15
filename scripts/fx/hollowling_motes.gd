extends Node2D
class_name HollowlingMotes

## Phase 4.43 — wandering ambient gold motes. Spawns 8-12 small drifting
## sparkles around the player; intensifies during a "hollowling_swarm" world
## event (Phase 4.32). Pure VFX — no gameplay interaction.

const BASE_COUNT: int = 6
const SWARM_BONUS: int = 18
const DRIFT_SPEED: float = 12.0
const MOTE_LIFE_SEC: float = 4.5

var _player: Node2D
var _motes: Array[Dictionary] = []
var _spawn_accum: float = 0.0
var _swarm_active: bool = false


func _ready() -> void:
	z_index = 80
	set_process(true)
	EventBus.player_spawned.connect(_on_player_spawned)
	# Phase 4.43 — bind to world events. The WorldEvents autoload owns the
	# swarm state; we just listen for begin/end.
	if Engine.has_singleton("WorldEvents"):
		pass  # autoload connected below
	var we: Node = get_node_or_null("/root/WorldEvents")
	if we and we.has_signal("world_event_started"):
		we.connect("world_event_started", _on_event_started)
		we.connect("world_event_ended", _on_event_ended)


func _on_player_spawned(p: Node) -> void:
	_player = p as Node2D


func _on_event_started(event_id: StringName) -> void:
	if event_id == &"hollowling_swarm":
		_swarm_active = true


func _on_event_ended(event_id: StringName) -> void:
	if event_id == &"hollowling_swarm":
		_swarm_active = false


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = null
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			_player = players[0]
	if _player == null:
		return
	_spawn_accum += delta
	var target_count: int = BASE_COUNT + (SWARM_BONUS if _swarm_active else 0)
	if _spawn_accum > 0.25 and _motes.size() < target_count:
		_spawn_accum = 0.0
		_spawn_one()
	for i in range(_motes.size() - 1, -1, -1):
		var m: Dictionary = _motes[i]
		m["life"] = float(m["life"]) - delta
		m["pos"] = Vector2(m["pos"]) + Vector2(m["vel"]) * delta
		if float(m["life"]) <= 0.0:
			_motes.remove_at(i)
	queue_redraw()


func _spawn_one() -> void:
	if _player == null:
		return
	var angle: float = randf() * TAU
	var dist: float = randf_range(48.0, 120.0)
	var pos: Vector2 = _player.global_position + Vector2(cos(angle), sin(angle)) * dist
	var drift: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * DRIFT_SPEED
	_motes.append({
		"pos": pos,
		"vel": drift,
		"life": MOTE_LIFE_SEC + randf_range(-1.0, 1.0),
		"phase": randf() * TAU,
	})


func _draw() -> void:
	if _player == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	for m in _motes:
		var pos: Vector2 = Vector2(m["pos"]) - global_position
		var phase: float = float(m["phase"]) + now * 4.0
		var pulse: float = 0.45 + 0.35 * sin(phase)
		var rim: Color = Color(0.95, 0.84, 0.5, 0.4 * pulse)
		var core: Color = Color(1.0, 0.97, 0.7, 0.85 * pulse)
		draw_circle(pos, 2.2, rim)
		draw_circle(pos, 1.0, core)
