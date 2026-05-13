extends Control
class_name DialoguePanel

## Tree-driven dialogue UI. Shows NPC name, current node text, and clickable responses.
## Walker is mute — the player only chooses gesture-responses.

@onready var name_label: Label = $Panel/Name
@onready var text_label: RichTextLabel = $Panel/Body
@onready var responses_box: VBoxContainer = $Panel/Responses

var _current_npc: NPC
var _current_node_id: String = ""


func _ready() -> void:
	add_to_group("dialogue_ui")
	visible = false


func open_for_npc(npc: NPC) -> void:
	_current_npc = npc
	if npc.dialogue == null:
		return
	visible = true
	_show_node(npc.dialogue.entry_node_id)


func close_if_for(npc: NPC) -> void:
	if _current_npc == npc:
		visible = false


func _show_node(node_id: String) -> void:
	_current_node_id = node_id
	if _current_npc == null:
		return
	var data: Dictionary = _current_npc.dialogue.get_node_data(node_id)
	if data.is_empty():
		visible = false
		return
	name_label.text = data.get("speaker", _current_npc.display_name)
	text_label.text = data.get("text", "...")
	for child in responses_box.get_children():
		child.queue_free()
	var responses: Array = data.get("responses", [])
	if responses.is_empty():
		_add_response("(silently nod)", "")
	else:
		for r in responses:
			_add_response(r.get("label", "..."), r.get("goto", ""))


func _add_response(label: String, goto: String) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(220, 18)
	b.pressed.connect(func() -> void:
		if goto == "" or goto == "end":
			visible = false
		else:
			_show_node(goto)
	)
	responses_box.add_child(b)
