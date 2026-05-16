extends CharacterBody2D
class_name VacancyFollower

## Phase 12.4 + 12.29 — Vacancy creature. Silent follower. Cannot reliably
## be attacked, never harms the Walker. Appears once, in the final corridor
## leading to the Bearer's antechamber. The encounter "completes" when the
## player passes the last manifesto (idx 7) or engages the Diadem-Bearer.
##
## Visual: silhouette with literal alpha-transparent pixels where the face/
## name would be — Gemini-MCP renders the "elided" hole.

const FOLLOW_DISTANCE_PX: float = 64.0
const FOLLOW_SPEED: float = 36.0

@export var mob_def: MobDef
@onready var sprite: Sprite2D = $Sprite2D


var _target: Node2D


func _ready() -> void:
	add_to_group("vacancy_follower")
	if mob_def and sprite:
		sprite.texture = mob_def.sprite
	# Tag as completed once the player has engaged the Bearer or passed the
	# final manifesto.
	if EventBus:
		EventBus.boss_engaged.connect(_on_boss_engaged)


func _physics_process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			_target = players[0]
	if _target == null:
		return
	var to_player: Vector2 = _target.global_position - global_position
	var dist: float = to_player.length()
	# Maintain a constant follow distance behind the player.
	if dist > FOLLOW_DISTANCE_PX:
		velocity = to_player.normalized() * FOLLOW_SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if sprite:
		sprite.flip_h = to_player.x < -0.5
		# Phase 8% sine wave fade — visual unease.
		var t: float = Time.get_ticks_msec() / 1000.0
		sprite.modulate.a = 0.55 + 0.10 * sin(t * 1.5)


func _on_boss_engaged(boss_id: StringName) -> void:
	if boss_id == &"boss_diadem_bearer":
		_complete_encounter()
		# Vacancy fades away when the fight begins.
		var t := create_tween()
		t.tween_property(self, "modulate:a", 0.0, 0.6)
		t.tween_callback(queue_free)


func _complete_encounter() -> void:
	if Phase12Helpers:
		Phase12Helpers.complete_vacancy_encounter()
