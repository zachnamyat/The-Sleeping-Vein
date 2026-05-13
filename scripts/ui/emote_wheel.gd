extends Control
class_name EmoteWheel

## Phase 1 ticket 1.37 placeholder. 5-slot radial menu with text emotes
## (wave / dance / sit / point / sleep). Hold the emote key to open, click a
## slot to fire. Real emote sprites/animations swap in after the player
## animation rig lands.

const EMOTES: Array[Dictionary] = [
	{"id": &"wave",   "label": "Wave"},
	{"id": &"dance",  "label": "Dance"},
	{"id": &"sit",    "label": "Sit"},
	{"id": &"point",  "label": "Point"},
	{"id": &"sleep",  "label": "Sleep"},
]
const RADIUS: float = 64.0

signal emote_chosen(emote_id: StringName)


func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -80.0
	offset_top = -80.0
	offset_right = 80.0
	offset_bottom = 80.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_slots()


func _build_slots() -> void:
	var center := Vector2(80, 80)
	for i in EMOTES.size():
		var angle: float = (float(i) / float(EMOTES.size())) * TAU - PI * 0.5
		var slot_pos := center + Vector2(cos(angle), sin(angle)) * RADIUS
		var btn := Button.new()
		btn.text = String(EMOTES[i]["label"])
		btn.size = Vector2(48, 16)
		btn.position = slot_pos - btn.size * 0.5
		var id: StringName = EMOTES[i]["id"]
		btn.pressed.connect(_on_emote.bind(id))
		add_child(btn)


func open() -> void:
	visible = true
	UIAudio.play_panel_open()


func close() -> void:
	visible = false
	UIAudio.play_panel_close()


func _on_emote(id: StringName) -> void:
	emote_chosen.emit(id)
	close()
