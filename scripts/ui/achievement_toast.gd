extends CanvasLayer
class_name AchievementToast

## Phase 15.15 — In-world achievement toast popups. The base Achievements
## autoload emits a EventBus.ui_toast on unlock; this widget pops a small
## panel with the achievement icon + label for 3.5s and queues if multiple
## fire at once.

const DURATION_SECONDS: float = 3.5

var _root: Control
var _queue: Array[Dictionary] = []
var _showing: bool = false


func _ready() -> void:
	layer = 70
	add_to_group("achievement_toast")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	if Achievements:
		Achievements.achievement_unlocked.connect(_on_unlock)


func _build_ui() -> void:
	_root = Control.new()
	_root.anchor_left = 1
	_root.anchor_right = 1
	_root.anchor_top = 0
	_root.anchor_bottom = 0
	_root.offset_left = -260
	_root.offset_right = -16
	_root.offset_top = 16
	_root.offset_bottom = 76
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.08, 0.92)
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	_root.add_child(bg)
	var border := ColorRect.new()
	border.color = Color(0.85, 0.74, 0.45, 1.0)
	border.anchor_right = 1
	border.offset_bottom = 2
	_root.add_child(border)


func _on_unlock(id: StringName, name: String) -> void:
	_queue.append({"id": id, "name": name})
	if not _showing:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		visible = false
		return
	_showing = true
	visible = true
	var rec: Dictionary = _queue.pop_front()
	for child in _root.get_children():
		if child is Label:
			child.queue_free()
	var title := Label.new()
	title.text = "Achievement"
	title.offset_left = 8
	title.offset_top = 4
	title.add_theme_color_override("font_color", Color(0.85, 0.74, 0.45))
	_root.add_child(title)
	var n := Label.new()
	n.text = String(rec.get("name", "?"))
	n.offset_left = 8
	n.offset_top = 24
	n.add_theme_color_override("font_color", Color(0.97, 0.85, 0.5))
	_root.add_child(n)
	UIAudio.play_unlock() if UIAudio else null
	get_tree().create_timer(DURATION_SECONDS).timeout.connect(_show_next)
