extends CanvasLayer
class_name WorldStatisticsPanel

## Phase 15.47 — World statistics screen (per-world cumulative tally).

var _root: Control
var _list: VBoxContainer


func _ready() -> void:
	layer = 25
	add_to_group("world_stats_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	if Phase15Helpers:
		Phase15Helpers.world_stats_changed.connect(_refresh)


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
	_root.offset_left = -240
	_root.offset_right = 240
	_root.offset_top = -220
	_root.offset_bottom = 220
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.96)
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	_root.add_child(bg)
	var t := Label.new()
	t.text = "World Statistics"
	t.offset_left = 16
	t.offset_top = 8
	t.add_theme_color_override("font_color", Color(0.85, 0.74, 0.45))
	_root.add_child(t)
	_list = VBoxContainer.new()
	_list.offset_left = 16
	_list.offset_top = 40
	_list.offset_right = -16
	_list.offset_bottom = -16
	_list.anchor_right = 1
	_list.anchor_bottom = 1
	_list.add_theme_constant_override("separation", 4)
	_root.add_child(_list)


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	if Phase15Helpers == null:
		return
	for k in Phase15Helpers.world_stats.keys():
		var h := HBoxContainer.new()
		var label := Label.new()
		label.text = String(k).replace("_", " ").capitalize()
		label.custom_minimum_size = Vector2(220, 0)
		label.modulate = Color(0.9, 0.86, 0.7)
		h.add_child(label)
		var value := Label.new()
		value.text = str(Phase15Helpers.world_stats[k])
		value.modulate = Color(0.97, 0.85, 0.5)
		h.add_child(value)
		_list.add_child(h)
	# Add NG+ cycle row.
	var ng_row := HBoxContainer.new()
	var ng_l := Label.new()
	ng_l.text = "NG+ cycles"
	ng_l.custom_minimum_size = Vector2(220, 0)
	ng_l.modulate = Color(0.9, 0.86, 0.7)
	ng_row.add_child(ng_l)
	var ng_v := Label.new()
	ng_v.text = str(GameState.ng_plus_cycles)
	ng_v.modulate = Color(0.97, 0.85, 0.5)
	ng_row.add_child(ng_v)
	_list.add_child(ng_row)
