extends Area2D
class_name ItemDrop

## A pickable item entity on the ground. Holds (item_id, count). When the player
## enters the pickup radius, adds to Inventory and frees itself.

@export var item_id: StringName = &""
@export var count: int = 1
@export var rarity: int = 0

const POP_DURATION: float = 0.35
const POP_RANGE: float = 12.0
const MAGNET_RADIUS: float = 36.0
const MAGNET_SPEED: float = 220.0

var _spawn_position: Vector2
var _spawn_time: float = 0.0


func _ready() -> void:
	add_to_group("item_drop")
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(5, true)
	set_collision_mask_value(2, true)
	_spawn_position = global_position
	_spawn_time = float(Time.get_ticks_msec()) / 1000.0
	body_entered.connect(_on_body_entered)
	_apply_rarity_modulate()


func _process(delta: float) -> void:
	var t: float = float(Time.get_ticks_msec()) / 1000.0 - _spawn_time
	if t < POP_DURATION:
		var fraction: float = t / POP_DURATION
		var arc: float = sin(fraction * PI) * POP_RANGE
		global_position = _spawn_position + Vector2(0, -arc)
		return
	var player := _nearest_player()
	if player != null:
		var to_player: Vector2 = player.global_position - global_position
		if to_player.length() < MAGNET_RADIUS:
			global_position += to_player.normalized() * MAGNET_SPEED * delta


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if Inventory.try_add(item_id, count):
		EventBus.item_picked_up.emit(item_id, count)
		queue_free()


func _nearest_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]


func _apply_rarity_modulate() -> void:
	# Phase 2.12: white / green / blue / purple / yellow ramp
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var defn: ItemDef = ItemRegistry.get_def(item_id)
	if defn and defn.icon:
		sprite.texture = defn.icon
	var color: Color = _color_for_rarity(rarity)
	if sprite:
		sprite.modulate = color


static func _color_for_rarity(r: int) -> Color:
	match r:
		0: return Color(1, 1, 1)
		1: return Color(0.7, 1.0, 0.6)
		2: return Color(0.55, 0.78, 1.0)
		3: return Color(0.85, 0.55, 1.0)
		_: return Color(1.0, 0.95, 0.5)
