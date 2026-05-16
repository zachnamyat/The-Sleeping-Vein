extends CanvasLayer
class_name ServerLogsViewer

## Phase 13.34 — Host-only server log viewer. Shows the in-memory log ring from
## NetSystem.dump_server_log(). Press F8 with the dev console open to surface.

const PANEL_W: float = 480.0
const PANEL_H: float = 320.0


var _root: Panel
var _text: RichTextLabel


func _ready() -> void:
	add_to_group("server_logs_viewer")
	layer = 110
	visible = false
	_root = Panel.new()
	_root.size = Vector2(PANEL_W, PANEL_H)
	_root.anchor_left = 0.5
	_root.anchor_top = 0.5
	_root.anchor_right = 0.5
	_root.anchor_bottom = 0.5
	_root.offset_left = -PANEL_W / 2
	_root.offset_top = -PANEL_H / 2
	_root.offset_right = PANEL_W / 2
	_root.offset_bottom = PANEL_H / 2
	add_child(_root)
	var title := Label.new()
	title.text = "Server Logs (host only)"
	title.position = Vector2(12, 6)
	_root.add_child(title)
	_text = RichTextLabel.new()
	_text.position = Vector2(12, 28)
	_text.size = Vector2(PANEL_W - 24, PANEL_H - 60)
	_text.fit_content = true
	_text.scroll_following = true
	_text.bbcode_enabled = true
	_root.add_child(_text)
	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.position = Vector2(12, PANEL_H - 30)
	refresh_btn.pressed.connect(_refresh)
	_root.add_child(refresh_btn)
	var close := Button.new()
	close.text = "Close"
	close.position = Vector2(PANEL_W - 80, PANEL_H - 30)
	close.pressed.connect(_on_close)
	_root.add_child(close)


func open() -> void:
	if NetSystem == null or not NetSystem.is_host:
		EventBus.ui_toast.emit("Logs are host-only.", 2.0)
		return
	visible = true
	_refresh()


func _refresh() -> void:
	if NetSystem == null:
		return
	var lines: Array = NetSystem.dump_server_log()
	_text.text = "\n".join(lines)


func _on_close() -> void:
	visible = false
