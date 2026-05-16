extends Control
class_name FrostbiteMeter

## Phase 11.18 — HUD frostbite meter. Hidden unless the player is in a cold
## zone. Bar fills pale-blue → indigo → white as frostbite climbs. Triggers a
## screen pulse on each 25% milestone.

@export var bar_width: int = 96
@export var bar_height: int = 6

var _level: float = 0.0
var _visible_for_cold: bool = false
var _last_pulse_milestone: int = 0


func _ready() -> void:
	visible = false
	z_index = 100
	custom_minimum_size = Vector2(bar_width + 2, bar_height + 2)
	if Phase11Helpers:
		Phase11Helpers.cold_zone_changed.connect(_on_cold_changed)
		Phase11Helpers.frostbite_changed.connect(_on_level_changed)


func _on_cold_changed(in_cold: bool) -> void:
	_visible_for_cold = in_cold
	visible = in_cold
	if not in_cold:
		_last_pulse_milestone = 0


func _on_level_changed(level: float) -> void:
	_level = clampf(level, 0.0, 1.0)
	queue_redraw()
	var milestone: int = int(floor(_level * 4.0))
	if milestone > _last_pulse_milestone and _visible_for_cold:
		_last_pulse_milestone = milestone
		EventBus.screen_pulse_requested.emit(0.2, 0.3)


func _draw() -> void:
	draw_rect(Rect2(0, 0, bar_width, bar_height), Color(0, 0, 0, 0.6), true)
	draw_rect(Rect2(0, 0, bar_width, bar_height), Color(0.9, 0.92, 1.0, 0.5), false, 1.0)
	var color: Color = Color(0.55, 0.78, 0.98) if _level < 0.5 else (Color(0.45, 0.55, 0.92) if _level < 0.85 else Color(0.95, 0.96, 1.0))
	draw_rect(Rect2(1, 1, (bar_width - 2) * _level, bar_height - 2), color, true)
