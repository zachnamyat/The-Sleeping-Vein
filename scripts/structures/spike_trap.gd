extends Area2D
class_name SpikeTrap

## Phase 5.21 — placeable spike trap. Damages anything that walks over it
## (player or mob). Cooldown between hits so a stuck mob doesn't tick to
## death in one frame.

@export var damage: int = 8
@export var damage_type: StringName = &"physical"
@export var trigger_cooldown_seconds: float = 0.6
@export var owner_team: StringName = &"world"
@export var arm_delay_seconds: float = 0.2

var _last_trigger_t: float = -999.0
var _accum_time: float = 0.0
var _armed: bool = false


func _ready() -> void:
	add_to_group("spike_trap")
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2
	set_process(true)


func _process(delta: float) -> void:
	_accum_time += delta
	if not _armed and _accum_time >= arm_delay_seconds:
		_armed = true


func _on_body_entered(body: Node) -> void:
	if not _armed:
		return
	if _accum_time - _last_trigger_t < trigger_cooldown_seconds:
		return
	_last_trigger_t = _accum_time
	# Apply damage through the body's HurtboxComponent if available, otherwise
	# its HealthComponent directly.
	var hurtbox := body.get_node_or_null("Hurtbox") as HurtboxComponent
	if hurtbox:
		hurtbox.receive_hit(self, damage, damage_type, owner_team)
	else:
		var hc := body.get_node_or_null("HealthComponent") as HealthComponent
		if hc:
			hc.apply_damage(damage, self, damage_type)
	if AudioBus:
		AudioBus.play_sfx(&"spike_trap")
	EventBus.camera_shake_requested.emit(0.6, 0.12)
