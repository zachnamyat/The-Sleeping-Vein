extends CanvasLayer
class_name ResurrectionAltarPanel

## Phase 13.24 — Resurrection altar. Lists all awaiting-respawn peers within
## REVIVAL_RANGE_PX. Clicking "Revive" collapses the target's respawn timer
## to 0.1 s and emits player_revival_requested.
##
## Triggered by interacting with a ResurrectionAltar placeable (or via the
## PartyHUD's "revive" button when standing close enough).

const PANEL_W: float = 240.0
const PANEL_H: float = 200.0


var _root: Panel
var _list: VBoxContainer


func _ready() -> void:
	add_to_group("resurrection_altar_ui")
	layer = 75
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
	title.text = "Resurrection Altar"
	title.position = Vector2(10, 6)
	_root.add_child(title)
	_list = VBoxContainer.new()
	_list.position = Vector2(10, 28)
	_list.size = Vector2(PANEL_W - 20, PANEL_H - 60)
	_root.add_child(_list)
	var close := Button.new()
	close.text = "Close"
	close.position = Vector2(PANEL_W - 70, PANEL_H - 26)
	close.size = Vector2(60, 22)
	close.pressed.connect(_on_close)
	_root.add_child(close)


func open() -> void:
	_rebuild()
	visible = true


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	if Phase13Helpers == null or NetSystem == null:
		return
	for k in NetSystem.player_profiles.keys():
		var peer_id: int = int(k)
		if peer_id == NetSystem.local_peer_id():
			continue
		if not Phase13Helpers.is_awaiting_respawn(peer_id):
			continue
		var row := HBoxContainer.new()
		var prof: Dictionary = NetSystem.profile_for(peer_id)
		var name_label := Label.new()
		name_label.text = String(prof.get("name", "P%d" % peer_id))
		name_label.custom_minimum_size = Vector2(120, 16)
		row.add_child(name_label)
		var btn := Button.new()
		btn.text = "Revive"
		btn.pressed.connect(_on_revive.bind(peer_id))
		row.add_child(btn)
		_list.add_child(row)


func _on_revive(peer_id: int) -> void:
	if Phase13Helpers and Phase13Helpers.request_revival(peer_id):
		EventBus.ui_toast.emit("Revival pulse sent.", 2.0)
		_rebuild()


func _on_close() -> void:
	visible = false
