extends Control
class_name TitleScreen

## Title menu with Single-Player + Host + Join + Quit.

@onready var join_input: LineEdit = $Menu/JoinInput
@onready var status: Label = $Menu/Status

# Animated Aphelion-pulse background state (ticket 1.33).
var _bg_t: float = 0.0


func _ready() -> void:
	$Menu/SinglePlayer.pressed.connect(_play_single)
	$Menu/Load.pressed.connect(open_load_panel)
	$Menu/Host.pressed.connect(_host)
	$Menu/Join.pressed.connect(_join)
	$Menu/Settings.pressed.connect(_open_settings)
	$Menu/Quit.pressed.connect(_quit)
	UIAudio.wire_button_sfx(self)
	if AudioBus:
		AudioBus.play_music(&"title_theme")
	set_process(true)


func _process(delta: float) -> void:
	_bg_t += delta
	var bg := $BG as ColorRect
	if bg == null:
		return
	var pulse: float = 0.5 + 0.5 * sin(_bg_t * 0.45)
	var base := Color(0.03, 0.02, 0.02)
	var peak := Color(0.07, 0.05, 0.04)
	bg.color = base.lerp(peak, pulse)


func _open_settings() -> void:
	var panel := $SettingsPanel as SettingsPanel
	if panel:
		panel.open()


func _play_single() -> void:
	# Tickets 1.16 + 1.18 — route New Game through character creation, then
	# world creation. CharacterCreationPanel hands off to WorldCreationPanel
	# on confirm.
	var cc := get_node_or_null("CharacterCreationPanel") as CharacterCreationPanel
	if cc:
		cc.open()
		return
	var wc := get_node_or_null("WorldCreationPanel") as WorldCreationPanel
	if wc:
		wc.open()
	else:
		get_tree().change_scene_to_file("res://scenes/world/main.tscn")


func open_load_panel() -> void:
	# Ticket 1.19 — Save-slot select. Wired to a "Load Game" button if present.
	var ss := get_node_or_null("SaveSlotPanel") as SaveSlotPanel
	if ss:
		ss.open()


func _host() -> void:
	var err := NetSystem.host_world()
	if err != OK:
		status.text = "Host failed: %s" % error_string(err)
		return
	status.text = "Hosting on :4242 — share IP with friends."
	get_tree().change_scene_to_file("res://scenes/world/main.tscn")


func _join() -> void:
	var host_str := join_input.text.strip_edges()
	if host_str == "":
		host_str = "127.0.0.1"
	var err := NetSystem.join_world(host_str)
	if err != OK:
		status.text = "Join failed: %s" % error_string(err)
		return
	status.text = "Connecting to %s..." % host_str
	get_tree().change_scene_to_file("res://scenes/world/main.tscn")


func _quit() -> void:
	get_tree().quit()
