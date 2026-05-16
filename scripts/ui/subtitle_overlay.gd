extends CanvasLayer
class_name SubtitleOverlay

## Phase 15.17 — Subtitle overlay for VO + ambient audio cues.
## Listens to EventBus.phase15_subtitle_emitted.

const FADE_OUT_SECONDS: float = 4.0

var _root: Control
var _label: Label
var _bg: ColorRect


func _ready() -> void:
	layer = 6
	add_to_group("subtitle_overlay")
	_build_ui()
	visible = false
	EventBus.phase15_subtitle_emitted.connect(_on_subtitle)
	if AccessibilityManager:
		AccessibilityManager.subtitles_changed.connect(func(active: bool) -> void:
			if not active:
				visible = false
		)


func _build_ui() -> void:
	_root = Control.new()
	_root.anchor_left = 0.5
	_root.anchor_right = 0.5
	_root.anchor_top = 1
	_root.anchor_bottom = 1
	_root.offset_left = -260
	_root.offset_right = 260
	_root.offset_top = -64
	_root.offset_bottom = -16
	add_child(_root)
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.55)
	_bg.anchor_right = 1
	_bg.anchor_bottom = 1
	_root.add_child(_bg)
	_label = Label.new()
	_label.offset_left = 8
	_label.offset_top = 4
	_label.offset_right = -8
	_label.offset_bottom = -4
	_label.anchor_right = 1
	_label.anchor_bottom = 1
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color(0.97, 0.92, 0.78))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_label)


func _on_subtitle(text: String, kind: StringName) -> void:
	if AccessibilityManager and not AccessibilityManager.subtitles_enabled:
		return
	visible = true
	_label.text = "[%s]  %s" % [String(kind).to_upper(), text] if kind != &"" else text
	if AccessibilityManager:
		_bg.color.a = AccessibilityManager.subtitle_background_alpha
		_label.add_theme_font_size_override("font_size", AccessibilityManager.subtitle_size)
	# Auto-hide.
	get_tree().create_timer(FADE_OUT_SECONDS).timeout.connect(func() -> void:
		visible = false
	)
