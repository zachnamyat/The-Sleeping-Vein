extends Node2D
class_name HiddenDoor

## Phase 5.23 — hidden door. Looks like wall until a player walks within
## `reveal_radius_px`; then fades the wall sprite to translucent and clears
## the collision shape, letting them pass. Stays revealed for the session.

@export var reveal_radius_px: float = 28.0
@export var fade_seconds: float = 0.5

@onready var _wall_sprite: Sprite2D = $WallSprite
@onready var _passage_sprite: Sprite2D = $PassageSprite
@onready var _body: StaticBody2D = $WallBody
@onready var _detect: Area2D = $RevealArea

var _revealed: bool = false


func _ready() -> void:
	add_to_group("hidden_door")
	if _passage_sprite:
		_passage_sprite.visible = false
	if _detect:
		_detect.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _revealed:
		return
	if not body.is_in_group("player"):
		return
	_revealed = true
	if _body:
		_body.collision_layer = 0
	var t := create_tween()
	if _wall_sprite:
		t.tween_property(_wall_sprite, "modulate:a", 0.0, fade_seconds)
	if _passage_sprite:
		_passage_sprite.modulate.a = 0.0
		_passage_sprite.visible = true
		t.parallel().tween_property(_passage_sprite, "modulate:a", 0.85, fade_seconds)
	EventBus.ui_toast.emit("The wall sighs and opens.", 2.0)
	if AudioBus:
		AudioBus.play_sfx(&"hidden_door_reveal")
