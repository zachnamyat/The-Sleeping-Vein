extends CanvasLayer
class_name RunHistoryPanel

## Phase 15.48 — Run history log.
## Shows the last 16 runs with playtime / deaths / bosses / outcome.

var _root: Control
var _list: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	layer = 25
	add_to_group("run_history_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()


func _build_ui() -> void:
	_root = Control.new()
	_root.anchor_left = 0.5
	_root.anchor_right = 0.5
	_root.anchor_top = 0.5
	_root.anchor_bottom = 0.5
	_root.offset_left = -320
	_root.offset_right = 320
	_root.offset_top = -220
	_root.offset_bottom = 220
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.96)
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	_root.add_child(bg)
	var t := Label.new()
	t.text = "Run History"
	t.offset_left = 16
	t.offset_top = 8
	t.add_theme_color_override("font_color", Color(0.85, 0.74, 0.45))
	_root.add_child(t)
	_scroll = ScrollContainer.new()
	_scroll.offset_left = 16
	_scroll.offset_top = 40
	_scroll.offset_right = -16
	_scroll.offset_bottom = -16
	_scroll.anchor_right = 1
	_scroll.anchor_bottom = 1
	_root.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_scroll.add_child(_list)


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	if Phase15Helpers == null:
		return
	if Phase15Helpers.run_history.is_empty():
		var l := Label.new()
		l.text = "(no runs yet)"
		l.modulate = Color(0.7, 0.65, 0.55)
		_list.add_child(l)
		return
	var hdr := Label.new()
	hdr.text = "Date          Duration  Deaths  Bosses  Difficulty  Outcome"
	hdr.modulate = Color(0.97, 0.85, 0.5)
	_list.add_child(hdr)
	for rec in Phase15Helpers.run_history:
		var l := Label.new()
		var iso: String = Time.get_datetime_string_from_unix_time(int(rec.get("ended_unix", 0))).substr(0, 10)
		var dur: int = int(rec.get("playtime_seconds", 0))
		var dur_str: String = "%02d:%02d" % [dur / 3600, (dur / 60) % 60]
		var deaths: int = int(rec.get("deaths", 0))
		var bosses: int = int(rec.get("bosses_defeated", 0))
		var diff: String = String(rec.get("difficulty", "normal"))
		var outcome: String = String(rec.get("outcome", "—"))
		l.text = "%s  %s     %3d     %3d    %-10s  %s" % [iso, dur_str, deaths, bosses, diff, outcome]
		l.modulate = Color(0.9, 0.86, 0.7)
		_list.add_child(l)
