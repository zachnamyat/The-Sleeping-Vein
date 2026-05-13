extends Node
class_name DamageFlash

## Phase 15 polish — flashes the parent's first Sprite2D to white briefly when
## the parent's HealthComponent takes damage. Attach as a child of any sprite-
## bearing entity that also has a HealthComponent sibling.

@export var flash_color: Color = Color(1, 1, 1, 1)
@export var flash_seconds: float = 0.08
@export var hp_path: NodePath = NodePath("../HealthComponent")
@export var sprite_path: NodePath = NodePath("../Sprite2D")

var _t: float = 0.0
var _sprite: CanvasItem
var _original_modulate: Color = Color(1, 1, 1, 1)


func _ready() -> void:
	_sprite = get_node_or_null(sprite_path) as CanvasItem
	if _sprite:
		_original_modulate = _sprite.modulate
	var hp := get_node_or_null(hp_path) as HealthComponent
	if hp:
		hp.damaged.connect(_on_damaged)


func _process(delta: float) -> void:
	if _t <= 0.0:
		return
	_t -= delta
	if _t <= 0.0 and _sprite:
		_sprite.modulate = _original_modulate


func _on_damaged(_amount: int, _source: Node, _type: StringName) -> void:
	if _sprite == null:
		return
	_sprite.modulate = flash_color
	_t = flash_seconds
