extends StaticBody2D
class_name LockedDoor

## Phase 4.60 — locked dungeon door. Solid until the player interacts holding a
## `skeleton_key`. Key is consumed, door opens (becomes passable + plays open
## anim). After opening, stays open for the session.

@export var key_item_id: StringName = &"skeleton_key"

var _opened: bool = false
var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("locked_door")
	collision_layer = 1
	collision_mask = 0
	var area := $InteractArea as Area2D
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or _opened:
		return
	if event.is_action_pressed("interact"):
		_try_unlock()


func _try_unlock() -> void:
	if Inventory.count_of(key_item_id) <= 0:
		EventBus.ui_toast.emit("Locked. You feel a keyhole.", 1.5)
		if AudioBus:
			AudioBus.play_sfx(&"door_locked")
		return
	Inventory.try_remove(key_item_id, 1)
	_opened = true
	collision_layer = 0
	var sprite := $Sprite2D as Sprite2D
	if sprite:
		sprite.modulate = Color(0.85, 0.85, 0.85, 0.55)
	EventBus.ui_toast.emit("The door creaks open.", 2.0)
	if AudioBus:
		AudioBus.play_sfx(&"door_open")


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if not _opened:
			EventBus.ui_toast.emit("[E] Use key", 1.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
