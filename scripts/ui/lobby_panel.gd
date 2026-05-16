extends CanvasLayer
class_name LobbyPanel

## Phase 13.51 / 13.52 — Pre-game multiplayer lobby. Lists connected peers,
## shows world toggles (PvP / shared XP / loot mode), surfaces the world
## password field, and runs the ready-check that gates world load.
##
## Single-player path: the panel is opened from the title screen's "Multiplayer"
## button. The host clicks "Host", clients click "Join". Once all peers are
## ready, "Start World" finalizes the lobby and triggers the world scene swap.

const PANEL_W: float = 480.0
const PANEL_H: float = 340.0


var _root: Panel
var _peers_list: VBoxContainer
var _ready_btn: Button
var _start_btn: Button
var _host_btn: Button
var _join_btn: Button
var _direct_ip: LineEdit
var _password: LineEdit
var _pvp_toggle: CheckButton
var _xp_toggle: CheckButton
var _loot_option: OptionButton
var _color_option: OptionButton


func _ready() -> void:
	add_to_group("lobby_panel")
	layer = 100
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
	title.text = "Lobby — The Sleeping Vein"
	title.position = Vector2(12, 4)
	_root.add_child(title)
	# Connection row.
	_direct_ip = LineEdit.new()
	_direct_ip.placeholder_text = "Direct IP (e.g. 192.168.1.50)"
	_direct_ip.position = Vector2(12, 28)
	_direct_ip.size = Vector2(180, 22)
	_root.add_child(_direct_ip)
	_password = LineEdit.new()
	_password.placeholder_text = "World password (optional)"
	_password.position = Vector2(198, 28)
	_password.size = Vector2(140, 22)
	_password.secret = true
	_root.add_child(_password)
	_host_btn = Button.new()
	_host_btn.text = "Host"
	_host_btn.position = Vector2(344, 28)
	_host_btn.size = Vector2(60, 22)
	_host_btn.pressed.connect(_on_host)
	_root.add_child(_host_btn)
	_join_btn = Button.new()
	_join_btn.text = "Join"
	_join_btn.position = Vector2(410, 28)
	_join_btn.size = Vector2(60, 22)
	_join_btn.pressed.connect(_on_join)
	_root.add_child(_join_btn)
	# Toggles.
	_pvp_toggle = CheckButton.new()
	_pvp_toggle.text = "PvP enabled"
	_pvp_toggle.position = Vector2(12, 60)
	_pvp_toggle.toggled.connect(_on_pvp_toggled)
	_root.add_child(_pvp_toggle)
	_xp_toggle = CheckButton.new()
	_xp_toggle.text = "Shared XP"
	_xp_toggle.position = Vector2(150, 60)
	_xp_toggle.button_pressed = true
	_xp_toggle.toggled.connect(_on_xp_toggled)
	_root.add_child(_xp_toggle)
	_loot_option = OptionButton.new()
	_loot_option.position = Vector2(280, 60)
	_loot_option.size = Vector2(180, 22)
	_loot_option.add_item("Loot: Free-for-all", 0)
	_loot_option.add_item("Loot: Round-robin", 1)
	_loot_option.add_item("Loot: Need/Greed", 2)
	_loot_option.item_selected.connect(_on_loot_changed)
	_root.add_child(_loot_option)
	# Color picker.
	var color_label := Label.new()
	color_label.text = "Slot color:"
	color_label.position = Vector2(12, 96)
	_root.add_child(color_label)
	_color_option = OptionButton.new()
	_color_option.position = Vector2(96, 92)
	_color_option.size = Vector2(180, 22)
	for i in range(8):
		_color_option.add_item("Slot %d" % (i + 1), i)
	_color_option.item_selected.connect(_on_color_changed)
	_root.add_child(_color_option)
	# Peers list.
	var peers_label := Label.new()
	peers_label.text = "Players:"
	peers_label.position = Vector2(12, 124)
	_root.add_child(peers_label)
	_peers_list = VBoxContainer.new()
	_peers_list.position = Vector2(12, 144)
	_peers_list.size = Vector2(PANEL_W - 24, PANEL_H - 200)
	_root.add_child(_peers_list)
	_ready_btn = Button.new()
	_ready_btn.text = "Mark Ready"
	_ready_btn.position = Vector2(12, PANEL_H - 36)
	_ready_btn.size = Vector2(120, 28)
	_ready_btn.pressed.connect(_on_ready)
	_root.add_child(_ready_btn)
	_start_btn = Button.new()
	_start_btn.text = "Start World"
	_start_btn.position = Vector2(PANEL_W - 132, PANEL_H - 36)
	_start_btn.size = Vector2(120, 28)
	_start_btn.pressed.connect(_on_start)
	_root.add_child(_start_btn)
	if Phase13Helpers:
		Phase13Helpers.lobby_ready_changed.connect(_on_lobby_changed)
		Phase13Helpers.lobby_finalized.connect(_on_lobby_finalized)
	if NetSystem:
		NetSystem.peer_connected.connect(_on_peer_connected)
		NetSystem.peer_disconnected.connect(_on_peer_disconnected)


func open() -> void:
	visible = true
	if Phase13Helpers:
		Phase13Helpers.open_lobby()
	_rebuild_peer_list()


func close() -> void:
	visible = false


func _on_host() -> void:
	if NetSystem == null:
		return
	var err := NetSystem.host_world(NetSystem.DEFAULT_PORT, _password.text)
	if err == OK:
		EventBus.ui_toast.emit("Hosting on %d." % NetSystem.DEFAULT_PORT, 3.0)
		_rebuild_peer_list()
	else:
		EventBus.ui_toast.emit("Host failed: %s" % error_string(err), 3.0)


func _on_join() -> void:
	if NetSystem == null:
		return
	var addr: String = _direct_ip.text.strip_edges()
	if addr.is_empty():
		EventBus.ui_toast.emit("Enter an IP to join.", 2.0)
		return
	var err := NetSystem.join_world(addr, NetSystem.DEFAULT_PORT, _password.text)
	if err == OK:
		EventBus.ui_toast.emit("Joining %s…" % addr, 3.0)
	else:
		EventBus.ui_toast.emit("Join failed: %s" % error_string(err), 3.0)


func _on_pvp_toggled(pressed: bool) -> void:
	if NetSystem:
		NetSystem.pvp_enabled = pressed
		GameState.net_pvp_enabled = pressed


func _on_xp_toggled(pressed: bool) -> void:
	if NetSystem:
		NetSystem.shared_xp_enabled = pressed
		GameState.net_shared_xp_enabled = pressed


func _on_loot_changed(index: int) -> void:
	if NetSystem:
		NetSystem.loot_mode = index
		GameState.net_loot_mode = index


func _on_color_changed(index: int) -> void:
	GameState.net_player_slot_index = index
	if NetSystem:
		NetSystem.set_profile_field(NetSystem.local_peer_id(), &"slot_index", index)
		var color: Color = NetSystem.SLOT_COLORS[index]
		NetSystem.set_profile_field(NetSystem.local_peer_id(), &"color", color)
		GameState.net_player_color_hex = "#%02x%02x%02x" % [int(color.r * 255), int(color.g * 255), int(color.b * 255)]


func _on_ready() -> void:
	if Phase13Helpers == null or NetSystem == null:
		return
	var pid: int = NetSystem.local_peer_id()
	var was_ready: bool = bool(Phase13Helpers.lobby_ready.get(pid, false))
	Phase13Helpers.mark_ready(pid, not was_ready)
	_ready_btn.text = "Cancel Ready" if not was_ready else "Mark Ready"


func _on_start() -> void:
	if Phase13Helpers == null:
		return
	if Phase13Helpers.finalize_lobby():
		EventBus.ui_toast.emit("Lobby finalized — entering world.", 3.0)
		visible = false
	else:
		EventBus.ui_toast.emit("Not all players are ready.", 2.0)


func _on_peer_connected(_peer_id: int) -> void:
	_rebuild_peer_list()


func _on_peer_disconnected(_peer_id: int) -> void:
	_rebuild_peer_list()


func _on_lobby_changed(_peer_id: int, _ready: bool) -> void:
	_rebuild_peer_list()


func _on_lobby_finalized() -> void:
	visible = false


func _rebuild_peer_list() -> void:
	for c in _peers_list.get_children():
		c.queue_free()
	if NetSystem == null:
		return
	for k in NetSystem.player_profiles.keys():
		var pid: int = int(k)
		var prof: Dictionary = NetSystem.profile_for(pid)
		var row := HBoxContainer.new()
		var swatch := ColorRect.new()
		swatch.color = prof.get("color", Color.WHITE)
		swatch.custom_minimum_size = Vector2(12, 12)
		row.add_child(swatch)
		var l := Label.new()
		l.text = "%s (slot %d) ping %dms" % [
			String(prof.get("name", "P%d" % pid)),
			int(prof.get("slot_index", 0)),
			int(prof.get("ping_ms", 0)),
		]
		row.add_child(l)
		var ready_lbl := Label.new()
		var is_ready: bool = bool(Phase13Helpers.lobby_ready.get(pid, false)) if Phase13Helpers else false
		ready_lbl.text = "  ✓ Ready" if is_ready else "  …"
		ready_lbl.modulate = Color(0.6, 0.95, 0.6, 1.0) if is_ready else Color.WHITE
		row.add_child(ready_lbl)
		_peers_list.add_child(row)
