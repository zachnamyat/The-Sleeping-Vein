extends CPUParticles2D
class_name PickupSparkle

## Phase 1 ticket 1.26. Brief sparkle burst spawned over an item drop when its
## rarity is above Common. One-shot; auto-frees when done.

@export var rarity_color: Color = Color(0.85, 0.85, 1.0, 1.0)


func _ready() -> void:
	z_index = 8
	one_shot = true
	emitting = true
	lifetime = 0.9
	amount = 18
	explosiveness = 0.6
	direction = Vector2(0, -1)
	spread = 180.0
	initial_velocity_min = 18.0
	initial_velocity_max = 32.0
	gravity = Vector2(0, -28)
	scale_amount_min = 1.0
	scale_amount_max = 2.0
	color = rarity_color
	# Free after particle lifetime + small buffer
	var t := get_tree().create_timer(lifetime + 0.2)
	t.timeout.connect(queue_free)


static func spawn(world_pos: Vector2, parent: Node, color: Color = Color(0.85, 0.85, 1.0, 1.0)) -> PickupSparkle:
	var s := PickupSparkle.new()
	s.position = world_pos
	s.rarity_color = color
	parent.add_child(s)
	return s
