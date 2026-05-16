extends CanvasLayer
class_name ServerBrowser

## Phase 13.18 / 13.33 — LAN discovery + server browser. Without a hosted
## master server we surface the user's "recent hosts" list (saved to
## GameState.net_recent_hosts) and lets them poke a Refresh button that calls
## the LAN-discovery stub. Direct-IP entry lives in LobbyPanel.

const PANEL_W: float = 420.0
const PANEL_H: float = 280.0


var _root: Panel
var _list: VBoxContainer
var _refresh: Button


func _ready() -> void:
	add_to_group("server_browser")
	layer = 95
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
	title.text = "Server Browser"
	title.position = Vector2(12, 6)
	_root.add_child(title)
	_list = VBoxContainer.new()
	_list.position = Vector2(12, 30)
	_list.size = Vector2(PANEL_W - 24, PANEL_H - 70)
	_root.add_child(_list)
	_refresh = Button.new()
	_refresh.text = "Refresh (LAN)"
	_refresh.position = Vector2(12, PANEL_H - 32)
	_refresh.size = Vector2(140, 24)
	_refresh.pressed.connect(_on_refresh)
	_root.add_child(_refresh)
	var close := Button.new()
	close.text = "Close"
	close.position = Vector2(PANEL_W - 80, PANEL_H - 32)
	close.size = Vector2(70, 24)
	close.pressed.connect(_on_close)
	_root.add_child(close)


func open() -> void:
	_rebuild()
	visible = true


func _on_refresh() -> void:
	if NetSystem == null:
		return
	var found: Array = NetSystem.discover_lan_hosts_stub()
	EventBus.ui_toast.emit("LAN scan: %d hosts visible." % found.size(), 3.0)
	_rebuild()


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	if GameState.net_recent_hosts.is_empty():
		var l := Label.new()
		l.text = "No recent hosts. Use Direct IP in the Lobby."
		_list.add_child(l)
		return
	for entry in GameState.net_recent_hosts:
		var rec: Dictionary = entry as Dictionary
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s:%d" % [String(rec.get("ip", "")), int(rec.get("port", 4242))]
		l.custom_minimum_size = Vector2(220, 18)
		row.add_child(l)
		var btn := Button.new()
		btn.text = "Join"
		btn.pressed.connect(_on_join.bind(rec))
		row.add_child(btn)
		_list.add_child(row)


func _on_join(entry: Dictionary) -> void:
	if NetSystem == null:
		return
	var err := NetSystem.join_world(String(entry.get("ip", "")), int(entry.get("port", 4242)))
	if err == OK:
		visible = false


func _on_close() -> void:
	visible = false
