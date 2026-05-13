extends CharacterBody2D
class_name NPC

## Base NPC. Stands at a position, faces the player when interacted, plays a
## DialogueTree, can offer merchant inventories (Phase 9).
## Phase 5 minimal: dialogue + npc_arrival event.

@export var npc_id: StringName = &""
@export var display_name: String = ""
@export var sprite_tex: Texture2D
@export var dialogue: DialogueTree
@export var arrival_lore_ref: String = ""

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt_label: Label = $InteractPrompt

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("npc")
	if sprite and sprite_tex:
		sprite.texture = sprite_tex
	$InteractArea.body_entered.connect(_on_body_entered)
	$InteractArea.body_exited.connect(_on_body_exited)
	if prompt_label:
		prompt_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("interact"):
		_open_dialogue()


func _open_dialogue() -> void:
	if dialogue == null:
		return
	var ui_nodes := get_tree().get_nodes_in_group("dialogue_ui")
	if ui_nodes.is_empty():
		return
	(ui_nodes[0]).open_for_npc(self)
	EventBus.npc_dialogue_opened.emit(npc_id)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if prompt_label:
			prompt_label.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		if prompt_label:
			prompt_label.visible = false
		var ui_nodes := get_tree().get_nodes_in_group("dialogue_ui")
		if not ui_nodes.is_empty():
			(ui_nodes[0]).close_if_for(self)
