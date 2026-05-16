extends Node2D
class_name MobFarmBlock

## Phase 14.19 — Mob farm. Defines an AABB kill-zone around itself; mobs that
## die inside the box drop their loot at the block's position so the player
## doesn't have to chase items across the room.

@export var aabb_half_extent: Vector2 = Vector2(64, 64)

var _farm_id: int = -1


func _ready() -> void:
	add_to_group("mob_farm")
	add_to_group("demolishable")
	var mn: Vector2 = global_position - aabb_half_extent
	var mx: Vector2 = global_position + aabb_half_extent
	_farm_id = Phase14Helpers.register_mob_farm(mn, mx, global_position)
	# Hook entity_killed to route drops.
	if EventBus and not EventBus.entity_killed.is_connected(_on_entity_killed):
		EventBus.entity_killed.connect(_on_entity_killed)


func _on_entity_killed(entity: Node, _killer: Node) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	var pos: Vector2 = (entity as Node2D).global_position if entity is Node2D else Vector2.ZERO
	var fid: int = Phase14Helpers.farm_for_position(pos)
	if fid != _farm_id:
		return
	# Tag the entity so MobDef.spawn_drops can read the override sink.
	entity.set_meta("mob_farm_drop_pos", global_position)
	Phase14Helpers.mob_farm_triggered.emit(_farm_id, StringName(entity.get("mob_id") if "mob_id" in entity else ""))


func get_refund_meta() -> Dictionary:
	return { "item_id": "mob_farm_block_placeable", "count": 1 }
