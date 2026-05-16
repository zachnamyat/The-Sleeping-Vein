extends Area2D
class_name LarvaTrap

## Phase 10.44 — placeable trap. When a hostile mob steps inside the area,
## broadcasts a 60% slow status to all mobs within RADIUS for SLOW_SECONDS,
## then breaks. Saves trigger state via dump_state / restore_state.

const RADIUS_PX: float = 64.0
const SLOW_SECONDS: float = 8.0
const SLOW_MAGNITUDE: float = 0.6

@export var triggered: bool = false


func _ready() -> void:
	add_to_group("larva_trap")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _on_body_entered(body: Node) -> void:
	if triggered:
		return
	if not body.is_in_group("mob"):
		return
	_trigger(body.global_position)


func _on_area_entered(_area: Area2D) -> void:
	pass  # ignore hurtbox enters; only body collision counts


func _trigger(epicenter: Vector2) -> void:
	triggered = true
	EventBus.aoe_indicator_requested.emit(epicenter, RADIUS_PX, 0.6, Color(0.5, 0.9, 0.7, 0.5))
	for m in get_tree().get_nodes_in_group("mob"):
		if not (m is Node2D):
			continue
		if (m as Node2D).global_position.distance_to(epicenter) > RADIUS_PX:
			continue
		var se: StatusEffects = m.get_node_or_null("StatusEffects") as StatusEffects
		if se:
			se.apply(&"slow", SLOW_SECONDS, null, SLOW_MAGNITUDE)
	if AudioBus:
		AudioBus.play_sfx(&"larva_trap_pop")
	# Brief flash, then destroy.
	var t := get_tree().create_timer(0.5, true, false, false)
	t.timeout.connect(queue_free)


func dump_state() -> Dictionary:
	return {"triggered": triggered}


func restore_state(d: Dictionary) -> void:
	triggered = bool(d.get("triggered", false))
	if triggered:
		queue_free()
