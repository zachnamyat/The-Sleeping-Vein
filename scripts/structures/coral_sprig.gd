extends Node2D
class_name CoralSprig

## Phase 8.34 — Coral propagation (Drowned Aphelion). Grows into a "coral
## bush" after grow_beats beats. Only thrives in Drowned Aphelion; elsewhere
## takes 3× as long.

@export var grow_beats: int = 32
var _beats: int = 0


func _ready() -> void:
	add_to_group("coral_sprig")
	if AudioBus:
		AudioBus.aphelion_beat.connect(_on_beat)


func _on_beat() -> void:
	_beats += 1
	var ratio: float = float(_beats) / float(maxi(1, _adjusted_grow_beats()))
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.scale = Vector2(0.5 + 0.5 * ratio, 0.5 + 0.5 * ratio)
		sprite.modulate = Color(0.95, 0.55, 0.6).lerp(Color(0.65, 0.95, 0.85), ratio)
	if _beats >= _adjusted_grow_beats():
		_mature()


func _adjusted_grow_beats() -> int:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return grow_beats
	var wg := tree.current_scene.get_node_or_null("WorldGen")
	if wg and wg.has_method("biome_at"):
		var b: BiomeDef = wg.biome_at(global_position) as BiomeDef
		if b and b.id == &"drowned_aphelion":
			return grow_beats
	return grow_beats * 3


func _mature() -> void:
	# Mature coral lets the player harvest 1-3 coral fragments by walking over.
	monitorable = true
	# We replace ourselves with a pickup script that drops the loot.
	var pickup := Area2D.new()
	pickup.global_position = global_position
	pickup.add_to_group("coral_pickup")
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = Color(0.5, 0.95, 0.85)
	pickup.add_child(sprite)
	var hit_collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	hit_collision.shape = shape
	pickup.add_child(hit_collision)
	pickup.collision_layer = 0
	pickup.collision_mask = 2
	pickup.body_entered.connect(func(body: Node) -> void:
		if body.is_in_group("player"):
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			Inventory.try_add(&"coral_fragment", rng.randi_range(1, 3))
			pickup.queue_free()
	)
	var tree := get_tree()
	if tree and tree.current_scene:
		tree.current_scene.add_child(pickup)
	queue_free()
