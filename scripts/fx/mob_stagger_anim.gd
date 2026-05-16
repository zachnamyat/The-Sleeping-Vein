extends Node
class_name MobStaggerAnim

## Ticket 2.38 — Mob stagger animation on heavy hit.
## When a Mob receives a hit whose damage exceeds its stagger_threshold, the
## mob plays a quick 0.2s tween that shifts its sprite horizontally + tints
## red briefly to telegraph the stagger.
## MobAnimator nodes look for this signal pattern to play.

const STAGGER_DURATION: float = 0.25
const STAGGER_SHIFT_PX: float = 3.0
const STAGGER_TINT: Color = Color(1.2, 0.7, 0.7, 1.0)

var _target: Sprite2D
var _t: float = 0.0
var _active: bool = false
var _orig_position: Vector2
var _orig_modulate: Color


func _ready() -> void:
	var parent: Node = get_parent()
	if parent and parent.has_node("Sprite"):
		_target = parent.get_node("Sprite") as Sprite2D
	if _target == null and parent is Mob:
		# Some mob scenes use AnimatedSprite2D. We try ourselves to find it.
		for c in parent.get_children():
			if c is Sprite2D:
				_target = c
				break
	if _target:
		_orig_position = _target.position
		_orig_modulate = _target.modulate
	# Listen for staggered signal on parent if present.
	if parent and parent.has_signal("staggered"):
		parent.connect("staggered", _begin)


func _begin(_amount: int = 0) -> void:
	if _target == null:
		return
	_active = true
	_t = 0.0
	set_process(true)


func _process(delta: float) -> void:
	if not _active or _target == null:
		return
	_t += delta
	if _t >= STAGGER_DURATION:
		_target.position = _orig_position
		_target.modulate = _orig_modulate
		_active = false
		set_process(false)
		return
	var p: float = _t / STAGGER_DURATION
	# Sin shake.
	var shake: float = sin(p * PI * 6.0) * STAGGER_SHIFT_PX * (1.0 - p)
	_target.position = _orig_position + Vector2(shake, 0)
	_target.modulate = _orig_modulate.lerp(STAGGER_TINT, 1.0 - p)
