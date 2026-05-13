extends CPUParticles2D
class_name WaterSplash

## Phase 1 ticket 1.39 placeholder. Spawned when the player enters a water tile.
## No water biome ships in Phase 1 yet, so callsites land with the Drowned
## Aphelion biome (Phase 10). One-shot CPUParticles2D, auto-frees.


func _ready() -> void:
	z_index = 8
	one_shot = true
	emitting = true
	lifetime = 0.55
	amount = 14
	explosiveness = 0.85
	direction = Vector2(0, -1)
	spread = 60.0
	initial_velocity_min = 28.0
	initial_velocity_max = 60.0
	gravity = Vector2(0, 240)
	scale_amount_min = 0.6
	scale_amount_max = 1.6
	color = Color(0.55, 0.78, 0.95, 1.0)
	var t := get_tree().create_timer(lifetime + 0.2)
	t.timeout.connect(queue_free)


static func spawn(world_pos: Vector2, parent: Node) -> WaterSplash:
	var s := WaterSplash.new()
	s.position = world_pos
	parent.add_child(s)
	return s
