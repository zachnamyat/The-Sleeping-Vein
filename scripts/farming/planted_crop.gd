extends Area2D
class_name PlantedCrop

## A growing crop entity. Walks through 4 growth stages and on full maturity
## becomes harvestable. Tier-0 Pale Cap / Memory Root MVP — no soil/moisture
## tile state required.

signal harvested

@export var crop_id: StringName = &"pale_cap"
@export var harvest_item_id: StringName = &"pale_cap"
@export var harvest_min: int = 1
@export var harvest_max: int = 2
@export var growth_seconds: float = 60.0   ## Phase 8 MVP: 60s; Phase 15 polish: 10 min/600s

var _growth: float = 0.0
var _mature: bool = false
var _watered: bool = false


func _ready() -> void:
	add_to_group("planted_crop")
	collision_layer = 0
	collision_mask = 2  # player
	body_entered.connect(_on_body_entered)
	_update_visual()


func _process(delta: float) -> void:
	if _mature:
		return
	var mult: float = 2.0 if _watered else 1.0
	_growth += delta * mult
	if _growth >= growth_seconds:
		_mature = true
		_update_visual()


func water() -> void:
	_watered = true
	if has_node("Sprite2D"):
		($Sprite2D as Sprite2D).modulate = Color(0.85, 1.0, 1.0)


func _update_visual() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var stage: float = clampf(_growth / growth_seconds, 0.0, 1.0)
	sprite.scale = Vector2(0.4 + 0.6 * stage, 0.4 + 0.6 * stage)
	if _mature:
		sprite.modulate = Color(1.0, 1.0, 0.6)


func _on_body_entered(body: Node) -> void:
	if not _mature:
		return
	if not body.is_in_group("player"):
		return
	_do_harvest()


func _do_harvest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count: int = rng.randi_range(harvest_min, harvest_max)
	Inventory.try_add(harvest_item_id, count)
	EventBus.skill_xp_gained.emit(&"skill_gardening", 4)
	harvested.emit()
	queue_free()
