extends Node

## Farming autoload. Routes "use seed/can" calls from PlayerCombat to spawn
## PlantedCrop or water existing crops.

const SEED_MAP: Dictionary = {
	&"pale_cap_seed":    { "crop_id": &"pale_cap",    "harvest_item_id": &"pale_cap",    "growth_seconds": 60.0 },
	&"memory_root_seed": { "crop_id": &"memory_root", "harvest_item_id": &"memory_root", "growth_seconds": 90.0 },
}


func is_seed(item_id: StringName) -> bool:
	return SEED_MAP.has(item_id)


func is_watering_can(item_id: StringName) -> bool:
	return item_id == &"watering_can"


func plant_seed(item_id: StringName, world_pos: Vector2) -> bool:
	if not is_seed(item_id):
		return false
	if Inventory.try_remove(item_id, 1) <= 0:
		return false
	var scn := load("res://scenes/farming/planted_crop.tscn") as PackedScene
	if scn == null:
		return false
	var crop := scn.instantiate() as PlantedCrop
	if crop == null:
		return false
	var data: Dictionary = SEED_MAP[item_id]
	crop.crop_id = data.crop_id
	crop.harvest_item_id = data.harvest_item_id
	crop.growth_seconds = float(data.growth_seconds)
	crop.global_position = world_pos
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene:
		tree.current_scene.add_child(crop)
	EventBus.ui_toast.emit("Planted.", 1.0)
	return true


func water_at(world_pos: Vector2) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var crops := tree.get_nodes_in_group("planted_crop")
	for c in crops:
		var crop: PlantedCrop = c
		if crop.global_position.distance_to(world_pos) < 14.0:
			crop.water()
			EventBus.skill_xp_gained.emit(&"skill_gardening", 1)
			return true
	return false
