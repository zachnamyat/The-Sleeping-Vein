extends RefCounted
class_name UIAudio

## Static helpers for wiring UI sound effects to common control events.
## Recurses through a panel's child tree once at _ready and connects every
## Button's `pressed` and `mouse_entered` signals to AudioBus.play_sfx().
## Procedural placeholder tones live in AudioBus until real audio assets land.

const CLICK_SOUND: StringName = &"ui_click"
const HOVER_SOUND: StringName = &"ui_hover"
const PANEL_OPEN_SOUND: StringName = &"ui_panel_open"
const PANEL_CLOSE_SOUND: StringName = &"ui_panel_close"
const PAGE_FLIP_SOUND: StringName = &"ui_page_flip"
const UNLOCK_SOUND: StringName = &"ui_unlock"


static func wire_button_sfx(root: Node) -> void:
	if root == null:
		return
	_walk_and_wire(root)


static func _walk_and_wire(node: Node) -> void:
	if node is Button:
		var btn := node as Button
		if not btn.pressed.is_connected(_play_click):
			btn.pressed.connect(_play_click)
		if not btn.mouse_entered.is_connected(_play_hover):
			btn.mouse_entered.connect(_play_hover)
	for child in node.get_children():
		_walk_and_wire(child)


static func _play_click() -> void:
	if AudioBus:
		AudioBus.play_sfx(CLICK_SOUND)


static func _play_hover() -> void:
	if AudioBus:
		AudioBus.play_sfx(HOVER_SOUND)


static func play_panel_open() -> void:
	if AudioBus:
		AudioBus.play_sfx(PANEL_OPEN_SOUND)


static func play_panel_close() -> void:
	if AudioBus:
		AudioBus.play_sfx(PANEL_CLOSE_SOUND)


static func play_page_flip() -> void:
	if AudioBus:
		AudioBus.play_sfx(PAGE_FLIP_SOUND)


static func play_unlock() -> void:
	if AudioBus:
		AudioBus.play_sfx(UNLOCK_SOUND)
