extends Area2D
class_name Projectile

## Generic projectile (arrow, bullet, staff bolt). Travels in `direction`, deals
## damage on hit, may apply a status effect via `on_hit_status`.

@export var speed: float = 240.0
@export var lifetime: float = 1.2
@export var base_damage: int = 5
@export var damage_type: StringName = &"physical"
@export var team: StringName = &"player"
@export var pierce_count: int = 0
@export var on_hit_status: StringName = &""
@export var status_duration: float = 0.0

var direction: Vector2 = Vector2.RIGHT
var _alive_time: float = 0.0
var _hits: int = 0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4 | 1  # hurtboxes + walls
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_alive_time += delta
	if _alive_time >= lifetime:
		queue_free()


func _on_body_entered(_body: Node) -> void:
	# Hit a wall: die.
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	var hurt := area as HurtboxComponent
	if hurt == null:
		return
	var dealt: int = hurt.receive_hit(self, base_damage, damage_type, team)
	if dealt > 0 and on_hit_status != &"":
		var sef := hurt.get_parent().get_node_or_null("StatusEffects") as StatusEffects
		if sef:
			sef.apply(on_hit_status, status_duration, self)
	_hits += 1
	if _hits > pierce_count:
		queue_free()
