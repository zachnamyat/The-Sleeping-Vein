extends Area2D
class_name ItemDrop

## A pickable item entity on the ground. Holds (item_id, count). When the player
## enters the pickup radius, adds to Inventory and frees itself.

@export var item_id: StringName = &""
@export var count: int = 1
@export var rarity: int = 0
## Phase 3.50 — pickup-immunity window so player-dropped items don't snap back.
@export var pickup_delay: float = 0.0

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
	# Player-dropped items spawn inside the player's body. body_entered fires
	# instantly and gets rejected by pickup_delay, then never re-fires because
	# the drop never exits the area. Don't magnet while the delay is active
	# (so the drop visibly sits in front of the player) and once it expires,
	# poll for direct overlap to trigger pickup.
	if pickup_delay > 0.0 and t < pickup_delay:
		return
	var player := _nearest_player()
	if player != null:
		var to_player: Vector2 = player.global_position - global_position
		if to_player.length() < MAGNET_RADIUS:
			global_position += to_player.normalized() * MAGNET_SPEED * delta
	for b in get_overlapping_bodies():
		if b.is_in_group("player"):
			if Inventory.try_add(item_id, count):
				EventBus.item_picked_up.emit(item_id, count)
				queue_free()
			return


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if pickup_delay > 0.0:
		var age: float = float(Time.get_ticks_msec()) / 1000.0 - _spawn_time
		if age < pickup_delay:
			return
	if Inventory.try_add(item_id, count):
		EventBus.item_picked_up.emit(item_id, count)
		queue_free()


## Phase 3.14 — Loot all: when the player presses the loot key, every drop
## within MAGNET_RADIUS calls this. Returns true if it was successfully picked
## up.
func try_force_pickup() -> bool:
	if Inventory.try_add(item_id, count):
		EventBus.item_picked_up.emit(item_id, count)
		queue_free()
		return true
	return false


func _nearest_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]


func _apply_rarity_modulate() -> void:
	# Phase 2.12: white / green / blue / purple / yellow ramp. The spawner can
	# override `rarity` for boss-rolled rares; otherwise we fall back to the
	# ItemDef's static rarity so common drops still get a consistent tint.
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var defn: ItemDef = ItemRegistry.get_def(item_id)
	if defn and defn.icon:
		sprite.texture = defn.icon
	else:
		# No icon authored yet (most Phase 2 items still need their Gemini pass).
		# Render a small generic gem so the drop is visible on the floor instead
		# of invisible — the rarity tint still distinguishes it.
		sprite.texture = _fallback_drop_texture()
	var effective_rarity: int = rarity if rarity > 0 else (defn.rarity if defn else 0)
	sprite.modulate = _color_for_rarity(effective_rarity)


static var _cached_fallback_texture: Texture2D = null


static func _fallback_drop_texture() -> Texture2D:
	if _cached_fallback_texture != null:
		return _cached_fallback_texture
	# 8x8 diamond pixel art so the drop sits at the right size for 16-tile world.
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fill_color := Color(1, 1, 1, 1)
	var edge_color := Color(0.2, 0.2, 0.2, 1)
	# Filled diamond.
	for y in range(8):
		var half: int = 3 - absi(y - 3)
		for x in range(4 - half - 1, 4 + half + 1):
			if x < 0 or x >= 8:
				continue
			img.set_pixel(x, y, fill_color)
	# Dark edge.
	for y in range(8):
		var half: int = 3 - absi(y - 3)
		var left: int = 4 - half - 1
		var right: int = 4 + half
		if left >= 0 and left < 8:
			img.set_pixel(left, y, edge_color)
		if right >= 0 and right < 8:
			img.set_pixel(right, y, edge_color)
	_cached_fallback_texture = ImageTexture.create_from_image(img)
	return _cached_fallback_texture


static func _color_for_rarity(r: int) -> Color:
	match r:
		0: return Color(1, 1, 1)
		1: return Color(0.7, 1.0, 0.6)
		2: return Color(0.55, 0.78, 1.0)
		3: return Color(0.85, 0.55, 1.0)
		_: return Color(1.0, 0.95, 0.5)
