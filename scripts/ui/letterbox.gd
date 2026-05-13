extends CanvasLayer
class_name Letterbox

## Phase 1 ticket 1.51. Two black ColorRect bars (top + bottom) that slide in
## from the screen edges for cinematic moments. Toggle via EventBus signal.

const BAR_HEIGHT_RATIO: float = 0.12

var _top: ColorRect
var _bot: ColorRect


func _ready() -> void:
	layer = 95
	_top = ColorRect.new()
	_top.color = Color.BLACK
	_top.anchor_left = 0.0
	_top.anchor_right = 1.0
	_top.anchor_top = 0.0
	_top.anchor_bottom = 0.0
	_top.offset_right = 0.0
	_top.offset_bottom = 0.0
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)
	_bot = ColorRect.new()
	_bot.color = Color.BLACK
	_bot.anchor_left = 0.0
	_bot.anchor_right = 1.0
	_bot.anchor_top = 1.0
	_bot.anchor_bottom = 1.0
	_bot.offset_right = 0.0
	_bot.offset_bottom = 0.0
	_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bot)
	EventBus.letterbox_requested.connect(_on_letterbox_requested)


func _on_letterbox_requested(enabled: bool, fade_seconds: float) -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var target_h: float = vp_size.y * BAR_HEIGHT_RATIO if enabled else 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_top, "size", Vector2(vp_size.x, target_h), max(fade_seconds, 0.01))
	tween.tween_property(_bot, "size", Vector2(vp_size.x, target_h), max(fade_seconds, 0.01))
	if enabled:
		_bot.offset_top = -target_h
	else:
		_bot.offset_top = 0.0
