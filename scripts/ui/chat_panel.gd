extends CanvasLayer
class_name ChatPanel

## Phase 13.15 / 13.29 / 13.30 — In-game text chat. Press Enter to open input.
## Channels: All (default), Party, Trade. /w <peer_id> <text> for whispers.
## Up/Down recall typed history. Last 200 messages persist in Phase13Helpers.

const MAX_VISIBLE_LINES: int = 14
const PANEL_W: float = 360.0
const PANEL_H: float = 200.0

var _root: Panel
var _history_label: RichTextLabel
var _input_box: LineEdit
var _channel_label: Label
var _current_channel: StringName = &"all"
var _history_cursor: int = -1


func _ready() -> void:
	add_to_group("chat_ui")
	layer = 90
	visible = false
	_root = Panel.new()
	_root.size = Vector2(PANEL_W, PANEL_H)
	_root.anchor_left = 0.0
	_root.anchor_top = 1.0
	_root.anchor_right = 0.0
	_root.anchor_bottom = 1.0
	_root.offset_left = 12.0
	_root.offset_top = -PANEL_H - 80.0
	_root.offset_right = PANEL_W + 12.0
	_root.offset_bottom = -80.0
	add_child(_root)
	_channel_label = Label.new()
	_channel_label.text = "[All]"
	_channel_label.position = Vector2(6, 4)
	_root.add_child(_channel_label)
	_history_label = RichTextLabel.new()
	_history_label.bbcode_enabled = true
	_history_label.scroll_following = true
	_history_label.fit_content = true
	_history_label.position = Vector2(6, 22)
	_history_label.size = Vector2(PANEL_W - 12, PANEL_H - 56)
	_history_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(_history_label)
	_input_box = LineEdit.new()
	_input_box.placeholder_text = "Say… (/all /party /trade /w <peer> <text>)"
	_input_box.position = Vector2(6, PANEL_H - 26)
	_input_box.size = Vector2(PANEL_W - 12, 20)
	_input_box.text_submitted.connect(_on_submit)
	_root.add_child(_input_box)
	if Phase13Helpers:
		Phase13Helpers.chat_posted.connect(_on_chat_posted)
	_render_history()


func toggle() -> void:
	visible = not visible
	if visible:
		_input_box.grab_focus()
		_history_cursor = -1
	else:
		_input_box.release_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_chat"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_UP:
			_recall_history(1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			_recall_history(-1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			visible = false
			get_viewport().set_input_as_handled()


func _recall_history(direction: int) -> void:
	if Phase13Helpers == null or Phase13Helpers.typed_history.is_empty():
		return
	_history_cursor = clampi(_history_cursor + direction, -1, Phase13Helpers.typed_history.size() - 1)
	if _history_cursor < 0:
		_input_box.text = ""
	else:
		var idx: int = Phase13Helpers.typed_history.size() - 1 - _history_cursor
		_input_box.text = Phase13Helpers.typed_history[idx]
		_input_box.caret_column = _input_box.text.length()


func _on_submit(text: String) -> void:
	if text.strip_edges().is_empty():
		_input_box.clear()
		return
	if Phase13Helpers:
		Phase13Helpers.push_typed_history(text)
	# Channel switch commands or whisper.
	var msg: String = text.strip_edges()
	if msg.begins_with("/"):
		_handle_slash(msg)
	else:
		if Phase13Helpers:
			Phase13Helpers.post_chat(_current_channel, msg)
	_input_box.clear()
	_history_cursor = -1


func _handle_slash(msg: String) -> void:
	var parts: PackedStringArray = msg.split(" ")
	var cmd: String = (parts[0] as String).to_lower()
	match cmd:
		"/all":
			_current_channel = &"all"
			_channel_label.text = "[All]"
		"/party":
			_current_channel = &"party"
			_channel_label.text = "[Party]"
		"/trade":
			_current_channel = &"trade"
			_channel_label.text = "[Trade]"
		"/w":
			if parts.size() < 3:
				return
			var peer: int = int(parts[1])
			var body: String = " ".join(Array(parts).slice(2))
			if Phase13Helpers:
				Phase13Helpers.post_whisper(peer, body)
		_:
			if Phase13Helpers:
				Phase13Helpers.post_chat(_current_channel, msg)


func _on_chat_posted(_peer_id: int, _channel: StringName, _text: String) -> void:
	_render_history()


func _render_history() -> void:
	if _history_label == null or Phase13Helpers == null:
		return
	var lines: Array = Phase13Helpers.chat_history
	var start: int = maxi(0, lines.size() - MAX_VISIBLE_LINES)
	var out: String = ""
	for i in range(start, lines.size()):
		var entry: Dictionary = lines[i]
		var channel: String = String(entry.get("channel", "all"))
		var color: String = "ffffff"
		match channel:
			"system": color = "d4a857"
			"party":  color = "7bbf64"
			"trade":  color = "f08a2e"
			"whisper": color = "c44a8a"
			_: color = "ffffff"
		var name: String = _name_for(int(entry.get("peer_id", 0)))
		out += "[color=#%s]%s:[/color] %s\n" % [color, name, String(entry.get("text", ""))]
	_history_label.text = out


func _name_for(peer_id: int) -> String:
	if peer_id == 0:
		return "System"
	if NetSystem == null:
		return "P%d" % peer_id
	var prof: Dictionary = NetSystem.profile_for(peer_id)
	return String(prof.get("name", "P%d" % peer_id))
