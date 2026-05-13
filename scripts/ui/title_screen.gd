extends Control
class_name TitleScreen

## Title menu with Single-Player + Host + Join + Quit.

@onready var join_input: LineEdit = $Menu/JoinInput
@onready var status: Label = $Menu/Status


func _ready() -> void:
	$Menu/SinglePlayer.pressed.connect(_play_single)
	$Menu/Host.pressed.connect(_host)
	$Menu/Join.pressed.connect(_join)
	$Menu/Quit.pressed.connect(_quit)


func _play_single() -> void:
	get_tree().change_scene_to_file("res://scenes/world/main.tscn")


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
