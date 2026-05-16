extends Area2D
class_name LiquidTile

## Phase 3.35 / 14.24 — A patch of liquid placed by the player (or via the
## procedural world). Carries `liquid_id` (water/lava/slime/acid). When a
## different liquid touches it, Phase14Helpers.liquid_mix_result resolves the
## new tile id. Mob-proof when `is_mob_barrier` is true (the "defensive tile"
## variant).

@export var liquid_id: StringName = &"water"
@export var is_mob_barrier: bool = false


func _ready() -> void:
	add_to_group("liquid_tile")
	add_to_group("demolishable")
	collision_layer = 0
	collision_mask = 4   # mobs
	if is_mob_barrier:
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	# Lava-tile defensive variant: damage a mob that walks in.
	if liquid_id == &"lava" and body.has_method("apply_damage"):
		body.call("apply_damage", 12, &"fire")


func attempt_mix_with(other_liquid: StringName) -> StringName:
	## Returns the new tile id the world_gen should swap us to, or "" if no
	## reaction. Caller queues_free this tile + paints the new one.
	return Phase14Helpers.liquid_mix_result(liquid_id, other_liquid)


func get_refund_meta() -> Dictionary:
	return { "item_id": "bucket_empty", "count": 1 }
