extends StaticBody2D
class_name GlassBlock

## Phase 14.25 — Mob-proof glass / placeable transparent barrier. Solid to
## mobs (collision_mask 4) and projectiles (mask 8), but light + sight pass
## through. Player can walk around it like any other wall.


func _ready() -> void:
	add_to_group("glass_block")
	add_to_group("placed_decor")
	add_to_group("demolishable")
	collision_layer = 1
	collision_mask = 0


func get_refund_meta() -> Dictionary:
	return { "item_id": "glass_block_placeable", "count": 1 }
