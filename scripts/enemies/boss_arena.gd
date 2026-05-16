extends Node2D
class_name BossArena

## A procedural rune-circle marker painted under each boss. Phase 5 MVP: a faint
## translucent gold ring + four cardinal glyph dots. Phase 15 polish replaces
## with Gemini-generated arena tile decals.
##
## Phase 5.25 — arena gate-lock. While a boss is engaged the arena projects a
## soft golden ring around its perimeter; touching it from inside or outside
## bounces the player back. Unlocks on boss death.
## Phase 5.35 — the arena_approach murals (see Mural scene) draw on this
## radius to know where to seed pre-fight art.

signal gate_locked
signal gate_unlocked

@export var radius_tiles: int = 6
@export var ring_color: Color = Color(0.86, 0.68, 0.34, 0.55)
@export var glyph_color: Color = Color(1.0, 0.92, 0.55, 0.85)
@export var gate_color: Color = Color(0.98, 0.84, 0.42, 0.75)

const TILE_PX: int = 16

var _gate_locked: bool = false
var _locked_for: Node = null
var _gate_pulse_t: float = 0.0


func _ready() -> void:
	add_to_group("boss_arena")
	z_index = -1
	queue_redraw()
	set_physics_process(true)


func _draw() -> void:
	var r: float = float(radius_tiles * TILE_PX)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, ring_color, 2.0, true)
	draw_arc(Vector2.ZERO, r * 0.88, 0.0, TAU, 64, ring_color * Color(1, 1, 1, 0.5), 1.0, true)
	for i in range(8):
		var a: float = float(i) / 8.0 * TAU
		var p: Vector2 = Vector2(cos(a), sin(a)) * r
		draw_circle(p, 3.0, glyph_color)
	for i in range(4):
		var a: float = float(i) / 4.0 * TAU
		var p: Vector2 = Vector2(cos(a), sin(a)) * (r * 0.5)
		draw_circle(p, 2.0, glyph_color)
	if _gate_locked:
		var pulse: float = 0.7 + 0.3 * sin(_gate_pulse_t * 4.0)
		draw_arc(Vector2.ZERO, r * 1.04, 0.0, TAU, 96, gate_color * Color(1, 1, 1, pulse), 3.0, true)


func _physics_process(delta: float) -> void:
	if not _gate_locked:
		return
	_gate_pulse_t += delta
	queue_redraw()
	if _locked_for == null or not is_instance_valid(_locked_for):
		unlock_gate()
		return
	# Phase 5.25 — knock back players who try to slip through the wall while
	# the gate is sealed. Trivial radial repulsion at the edge.
	var arena_pos: Vector2 = global_position
	var radius_px: float = float(radius_tiles * TILE_PX) * 1.04
	for p in get_tree().get_nodes_in_group("player"):
		if not (p is Node2D):
			continue
		var node: Node2D = p
		var dist: float = node.global_position.distance_to(arena_pos)
		if dist > radius_px and dist < radius_px + 8.0:
			# Player is straddling the seal from outside — repel inward only if
			# the boss is locked here. Keep the boss penned with player together.
			var dir: Vector2 = (arena_pos - node.global_position).normalized()
			node.global_position += dir * 4.0


func lock_gate_for(boss: Node) -> void:
	# Phase 5.25 — caller is a Boss; the seal stays up until it dies. If a
	# second boss tries to take the gate the first one always wins.
	if _gate_locked:
		return
	_gate_locked = true
	_locked_for = boss
	EventBus.ui_toast.emit("The runes seal. Walk through, or fall here.", 2.5)
	if AudioBus:
		AudioBus.play_sfx(&"boss_gate_seal")
	gate_locked.emit()


func unlock_gate() -> void:
	if not _gate_locked:
		return
	_gate_locked = false
	_locked_for = null
	_gate_pulse_t = 0.0
	queue_redraw()
	if AudioBus:
		AudioBus.play_sfx(&"boss_gate_open")
	gate_unlocked.emit()


func is_gate_locked() -> bool:
	return _gate_locked
