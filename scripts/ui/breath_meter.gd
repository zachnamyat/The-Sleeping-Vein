extends Control
class_name BreathMeter

## Phase 10.8 — HUD overlay showing the player's underwater breath.
##
## Hidden unless `is_swimming` toggles true. Bar fills cyan->amber->red as
## breath depletes. Plays a single warning blink when breath drops below 25%.

@export var bar_width: int = 96
@export var bar_height: int = 6
@export var max_seconds: float = 30.0

var _current: float = 30.0
var _max: float = 30.0
var _visible_for_swim: bool = false
var _warned: bool = false


func _ready() -> void:
	visible = false
	z_index = 100
	custom_minimum_size = Vector2(bar_width + 2, bar_height + 2)
	EventBus.player_swim_changed.connect(_on_swim_changed)
	EventBus.player_breath_changed.connect(_on_breath_changed)


func _on_swim_changed(is_swimming: bool) -> void:
	_visible_for_swim = is_swimming
	visible = is_swimming
	if not is_swimming:
		_warned = false


func _on_breath_changed(current: float, maximum: float) -> void:
	_current = current
	_max = maximum
	if _max <= 0.0:
		_max = max_seconds
	queue_redraw()
	if _visible_for_swim and current / _max < 0.25 and not _warned:
		_warned = true
		EventBus.ui_toast.emit("Breath is low — surface or hold a Coral Veil!", 1.6)
		EventBus.screen_pulse_requested.emit(0.4, 0.3)


func _draw() -> void:
	if _max <= 0.0:
		return
	var ratio: float = clampf(_current / _max, 0.0, 1.0)
	# Background
	draw_rect(Rect2(0, 0, bar_width, bar_height), Color(0, 0, 0, 0.6), true)
	draw_rect(Rect2(0, 0, bar_width, bar_height), Color(0.9, 0.9, 0.9, 0.5), false, 1.0)
	# Fill
	var color: Color = Color(0.45, 0.85, 0.95) if ratio > 0.6 else (Color(0.95, 0.75, 0.35) if ratio > 0.25 else Color(0.95, 0.35, 0.35))
	draw_rect(Rect2(1, 1, (bar_width - 2) * ratio, bar_height - 2), color, true)
