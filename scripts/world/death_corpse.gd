extends Area2D
class_name DeathCorpse

## Phase 2.16 — marker at the player's death location holding the inventory
## stash they dropped on death. Walking over it (player_group) restores all
## items to Inventory and frees the corpse. Persists across respawns until
## reclaimed; one corpse per death.

const PICKUP_RADIUS: float = 16.0

@export var stashed_slots: Array = []  ## Each entry: {item_id: String, count: int}

var _t: float = 0.0


func _ready() -> void:
	add_to_group("death_corpse")
	z_index = 4
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(5, true)
	set_collision_mask_value(2, true)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PICKUP_RADIUS
	shape.shape = circle
	add_child(shape)
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_reclaim_stash()
	if AudioBus:
		AudioBus.play_sfx(&"corpse_reclaim")
	EventBus.ui_toast.emit("Stash reclaimed.", 1.5)
	queue_free()


func _reclaim_stash() -> void:
	for entry in stashed_slots:
		var item_id := StringName(String(entry.get("item_id", "")))
		var count: int = int(entry.get("count", 0))
		if item_id == &"" or count <= 0:
			continue
		Inventory.try_add(item_id, count)


func _draw() -> void:
	# Small pulsing rune marker.
	var pulse: float = 0.7 + 0.3 * sin(_t * 3.0)
	draw_circle(Vector2.ZERO, 6.0 * pulse, Color(0.55, 0.35, 0.85, 0.7))
	draw_circle(Vector2.ZERO, 4.0, Color(0.95, 0.85, 0.50, 0.85))
	draw_circle(Vector2.ZERO, 2.0, Color(1.0, 1.0, 1.0, 0.9))
