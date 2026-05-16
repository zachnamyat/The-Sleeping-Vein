extends CanvasLayer
class_name SpectatorCam

## Phase 13.23 / 13.38 — Spectator mode + ghost cam while waiting to respawn.
## Activates automatically when the local player's awaiting_respawn timer is
## non-zero. Allows arrow-key cycling between alive party members; shows a
## countdown banner with seconds-to-respawn.

const HUD_W: float = 240.0
const HUD_H: float = 40.0


var _root: Panel
var _label: Label
var _countdown_label: Label
var _camera_target_peer: int = -1


func _ready() -> void:
	add_to_group("spectator_cam")
	layer = 70
	visible = false
	_root = Panel.new()
	_root.size = Vector2(HUD_W, HUD_H)
	_root.anchor_left = 0.5
	_root.anchor_right = 0.5
	_root.anchor_top = 0.0
	_root.anchor_bottom = 0.0
	_root.offset_left = -HUD_W / 2
	_root.offset_right = HUD_W / 2
	_root.offset_top = 18.0
	_root.offset_bottom = 18.0 + HUD_H
	add_child(_root)
	_label = Label.new()
	_label.text = "Spectating: —"
	_label.position = Vector2(8, 4)
	_root.add_child(_label)
	_countdown_label = Label.new()
	_countdown_label.text = ""
	_countdown_label.position = Vector2(8, 22)
	_root.add_child(_countdown_label)
	set_process(true)


func _process(_delta: float) -> void:
	if Phase13Helpers == null or NetSystem == null:
		visible = false
		return
	var local: int = NetSystem.local_peer_id()
	if not Phase13Helpers.is_awaiting_respawn(local):
		visible = false
		return
	visible = true
	var seconds: float = Phase13Helpers.respawn_seconds_for(local)
	_countdown_label.text = "Respawn in %.1fs" % seconds
	if _camera_target_peer < 0 or Phase13Helpers.is_awaiting_respawn(_camera_target_peer):
		_camera_target_peer = Phase13Helpers._first_live_peer(local)
	if _camera_target_peer >= 0:
		var prof: Dictionary = NetSystem.profile_for(_camera_target_peer)
		_label.text = "Spectating: %s" % String(prof.get("name", "P%d" % _camera_target_peer))
	else:
		_label.text = "Spectating: —"


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("move_right") or event.is_action_pressed("move_left"):
		_cycle_target(1 if event.is_action_pressed("move_right") else -1)


func _cycle_target(direction: int) -> void:
	if NetSystem == null:
		return
	var peers: Array = NetSystem.player_profiles.keys()
	peers.sort()
	if peers.is_empty():
		return
	var idx: int = peers.find(_camera_target_peer)
	idx = wrapi(idx + direction, 0, peers.size())
	_camera_target_peer = int(peers[idx])
