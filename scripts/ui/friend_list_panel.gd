extends CanvasLayer
class_name FriendListPanel

## Phase 15.67 — Friend list integration UI.
## Renders NetPolish.friends. Real Steam/EOS wire-up populates the dict; here
## we just expose the read.

var _root: Control
var _list: VBoxContainer


func _ready() -> void:
	layer = 25
	add_to_group("friend_list_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	if NetPolish:
		NetPolish.friend_status_changed.connect(_refresh)


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
	_root.offset_left = -200
	_root.offset_right = 200
	_root.offset_top = -200
	_root.offset_bottom = 200
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.96)
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	_root.add_child(bg)
	var t := Label.new()
	t.text = "Friends"
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


func _refresh(_id: String = "", _online: bool = false) -> void:
	for c in _list.get_children():
		c.queue_free()
	if NetPolish == null:
		return
	if NetPolish.friends.is_empty():
		var l := Label.new()
		l.text = "(no friends connected)"
		l.modulate = Color(0.7, 0.65, 0.55)
		_list.add_child(l)
		return
	for fid in NetPolish.friends.keys():
		var rec: Dictionary = NetPolish.friends[fid]
		var row := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = String(rec.get("name", fid))
		name_lbl.custom_minimum_size = Vector2(220, 0)
		row.add_child(name_lbl)
		var status := Label.new()
		status.text = "online" if bool(rec.get("online", false)) else "offline"
		status.modulate = Color(0.6, 0.9, 0.4) if bool(rec.get("online", false)) else Color(0.7, 0.65, 0.55)
		row.add_child(status)
		_list.add_child(row)
