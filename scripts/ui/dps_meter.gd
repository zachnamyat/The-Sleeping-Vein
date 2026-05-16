extends Label
class_name DpsMeter

## Phase 6.49 — opt-in DPS meter. Reads from CombatTracker.player_dps() once per
## 0.25s and renders "DPS: 18". Toggle visibility via Settings("show_dps", false).

const REFRESH: float = 0.25
var _accum: float = 0.0


func _ready() -> void:
	add_theme_font_size_override("font_size", 16)
	modulate = Color(0.85, 0.95, 1.0)
	visible = false
	if Settings:
		Settings.value_changed.connect(_on_settings_changed)
		_apply_visibility()


func _process(delta: float) -> void:
	if not visible:
		return
	_accum += delta
	if _accum < REFRESH:
		return
	_accum = 0.0
	if CombatTracker:
		text = "DPS: %d" % int(round(CombatTracker.player_dps()))


func _on_settings_changed(key: String, _value: Variant) -> void:
	if key == "show_dps":
		_apply_visibility()


func _apply_visibility() -> void:
	visible = bool(Settings.get_value("show_dps", false))
