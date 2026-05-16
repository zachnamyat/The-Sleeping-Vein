extends Area2D
class_name ListenerBelowFinal

## Phase 12.28 — second Listener-Below encounter in the Final Spiral. She
## approaches; she removes her mask; her face is the Walker's. The Walker may
## attempt to attack (the strike does not connect — the Listener phases out),
## may emote, or may simply wait. After a Beat, the Listener replaces the
## mask and walks away.
##
## One-shot. After the encounter:
##   Phase12Helpers.reveal_listener_mask() sets the flag + Compendium entry.
##   The node free's itself with a tween fade.

const MASK_REVEAL_DELAY: float = 1.6
const STAGE_DURATION: float = 4.5

@onready var sprite: Sprite2D = $Sprite2D

var _triggered: bool = false


func _ready() -> void:
	add_to_group("listener_below_final")
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or _triggered:
		return
	if Phase12Helpers and Phase12Helpers.listener_mask_revealed_flag:
		# Already revealed — silent cameo only.
		return
	_triggered = true
	_play_encounter()


func _play_encounter() -> void:
	EventBus.letterbox_requested.emit(true, 0.6)
	if AudioBus:
		AudioBus.play_sfx(&"listener_approach")
	# Phase 1: approach (sprite walks toward player).
	var t1 := create_tween()
	t1.tween_property(self, "position", position + Vector2(0, 8), 1.0)
	# Phase 2: mask reveal after a delay.
	await get_tree().create_timer(MASK_REVEAL_DELAY).timeout
	if Phase12Helpers:
		Phase12Helpers.reveal_listener_mask()
	if sprite:
		sprite.modulate = Color(0.7, 0.7, 0.85, 1.0)
	if AudioBus:
		AudioBus.play_sfx(&"mask_off")
	# Phase 3: linger, then fade.
	await get_tree().create_timer(STAGE_DURATION).timeout
	EventBus.letterbox_requested.emit(false, 1.0)
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 1.0)
	fade.tween_callback(queue_free)
