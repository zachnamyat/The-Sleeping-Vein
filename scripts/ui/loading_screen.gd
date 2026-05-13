extends CanvasLayer
class_name LoadingScreen

## Phase 1 ticket 1.20. Black overlay with a progress bar and a rotating
## tip-of-the-day. Used for scene transitions and chunk pre-warm waits.
## Tips read from assets/i18n/en.json under the "loading_tips" key when
## available, falling back to a hard-coded short list.

const FALLBACK_TIPS: Array[String] = [
	"The Aphelion beats every 23 seconds. So does the world.",
	"A torch is heavier than it looks. So is its absence.",
	"Stoneslough crumble — strike low.",
	"Slivers are finite. Spend them deliberately.",
	"Resonance Looms remember your last breath.",
	"The Diadem is louder than it sounds.",
]

var _bg: ColorRect
var _bar: ProgressBar
var _tip_label: Label


func _ready() -> void:
	layer = 110
	visible = false
	_build()


func _build() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 1)
	_bg.anchor_right = 1.0
	_bg.anchor_bottom = 1.0
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_bar = ProgressBar.new()
	_bar.max_value = 1.0
	_bar.value = 0.0
	_bar.show_percentage = false
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_top = 0.65
	_bar.offset_left = -120.0
	_bar.offset_right = 120.0
	_bar.offset_top = 0.0
	_bar.offset_bottom = 8.0
	add_child(_bar)

	_tip_label = Label.new()
	_tip_label.modulate = Color(0.85, 0.78, 0.55)
	_tip_label.anchor_left = 0.5
	_tip_label.anchor_right = 0.5
	_tip_label.anchor_top = 0.78
	_tip_label.offset_left = -180.0
	_tip_label.offset_right = 180.0
	_tip_label.offset_top = 0.0
	_tip_label.offset_bottom = 32.0
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_tip_label)


func show_with_tip(progress: float = 0.0) -> void:
	_tip_label.text = _pick_tip()
	_bar.value = clampf(progress, 0.0, 1.0)
	visible = true


func update_progress(progress: float) -> void:
	_bar.value = clampf(progress, 0.0, 1.0)


func hide_screen() -> void:
	visible = false


func _pick_tip() -> String:
	if I18n and I18n.has_method("t"):
		var i18n_tips: Variant = I18n.t("loading_tips")
		if i18n_tips is Array and (i18n_tips as Array).size() > 0:
			var arr: Array = i18n_tips
			return String(arr[randi() % arr.size()])
	return FALLBACK_TIPS[randi() % FALLBACK_TIPS.size()]
