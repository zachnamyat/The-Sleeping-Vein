extends CanvasLayer
class_name GamepadCursor

## Phase 13.45 / 13.46 — Stick-controlled UI pointer + gamepad glyph swap. The
## pointer activates when a controller axis fires; deactivates on mouse motion.
## On activation, the Mouse cursor is moved by the stick at
## Phase13Helpers.GAMEPAD_CURSOR_SPEED_PX_PER_SECOND.

const STICK_DEADZONE: float = 0.18


var _cursor: ColorRect


func _ready() -> void:
	add_to_group("gamepad_cursor")
	layer = 120
	_cursor = ColorRect.new()
	_cursor.size = Vector2(8, 8)
	_cursor.color = Color(0.95, 0.85, 0.4, 0.85)
	_cursor.position = Vector2(-100, -100)
	add_child(_cursor)
	set_process(true)


func _process(delta: float) -> void:
	if Phase13Helpers == null:
		return
	if not Phase13Helpers.gamepad_cursor_active:
		_cursor.visible = false
		return
	_cursor.visible = true
	var stick: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if stick.length() < STICK_DEADZONE:
		stick = Vector2.ZERO
	var pos: Vector2 = get_viewport().get_mouse_position() + stick * Phase13Helpers.GAMEPAD_CURSOR_SPEED_PX_PER_SECOND * delta
	var vp: Vector2 = get_viewport().get_visible_rect().size
	pos.x = clampf(pos.x, 0, vp.x)
	pos.y = clampf(pos.y, 0, vp.y)
	Input.warp_mouse(pos)
	_cursor.position = pos - _cursor.size * 0.5
