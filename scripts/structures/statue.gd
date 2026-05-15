extends Node2D
class_name Statue

## Phase 4.37 — placeable commemorative statue. Hovering shows the inscription
## (boss id) via tooltip. Purely cosmetic.

@export var inscription: String = ""

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("statue")
	var area := $InteractArea as Area2D
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and inscription != "":
		_player_in_range = true
		EventBus.ui_toast.emit(inscription, 3.0)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
