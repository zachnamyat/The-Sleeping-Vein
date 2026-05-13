extends StaticBody2D
class_name WorldTree

## Phase 2.14 / 2.15 — placeable, axe-fellable tree. Has a HealthComponent +
## HurtboxComponent so it lives in the same combat pipeline as mobs. Only
## damage of type `axe` actually reduces HP (sword swings bounce off).
## On death, drops Wood + a weighted chance of Heartwood.

const WOOD_DROP_MIN: int = 1
const WOOD_DROP_MAX: int = 4
const HEARTWOOD_CHANCE: float = 0.25

@export var max_hp: int = 30
@export var tree_tier: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox

var _is_falling: bool = false


func _ready() -> void:
	add_to_group("tree")
	if health:
		health.max_health = max_hp
		health.current_health = max_hp
		# Only axe-type damage actually chips a tree. Sword/pickaxe land 0.
		health.set_resistance(DamageType.PHYSICAL, 1.0)
		health.set_resistance(&"axe", 0.0)
		health.died.connect(_on_died)
	if hurtbox:
		hurtbox.team = &"world"
		hurtbox.health_component = health
		hurtbox.knockback_resistance = 1.0
	# Procedural placeholder sprite — a tall green diamond. Real tree art lands
	# with the Root Hollows asset pass.
	if sprite and sprite.texture == null:
		sprite.texture = _placeholder_tree_texture()


static func _placeholder_tree_texture() -> Texture2D:
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Trunk
	for y in range(16, 24):
		for x in range(7, 9):
			img.set_pixel(x, y, Color(0.32, 0.20, 0.10))
	# Leaves — diamond
	for y in range(0, 16):
		var half: int = mini(y + 1, 16 - y) * 8 / 16
		for x in range(8 - half - 2, 8 + half + 2):
			if x < 0 or x >= 16:
				continue
			img.set_pixel(x, y, Color(0.20, 0.42, 0.18))
	# Highlight
	for y in range(2, 8):
		img.set_pixel(6, y, Color(0.35, 0.60, 0.30))
	return ImageTexture.create_from_image(img)


func _on_died(_killer: Node) -> void:
	if _is_falling:
		return
	_is_falling = true
	_drop_loot()
	# Visual fall: rotate + slide down, then queue_free.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation", deg_to_rad(75.0), 0.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(queue_free)


func _drop_loot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var wood_count: int = rng.randi_range(WOOD_DROP_MIN, WOOD_DROP_MAX)
	_spawn_drop(&"wood", wood_count)
	if rng.randf() < HEARTWOOD_CHANCE:
		_spawn_drop(&"heartwood", 1)


func _spawn_drop(item_id: StringName, count: int) -> void:
	var scn := load("res://scenes/items/item_drop.tscn") as PackedScene
	if scn == null:
		return
	var drop := scn.instantiate() as ItemDrop
	if drop == null:
		return
	drop.item_id = item_id
	drop.count = count
	drop.global_position = global_position
	get_tree().current_scene.add_child(drop)
