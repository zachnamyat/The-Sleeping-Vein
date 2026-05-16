extends Node

## Phase 8 farming. Owns the seed/crop registry, hoe → TilledSoil routing,
## moisture state, sprinkler propagation, multi-harvest regrow timing, and
## fertilizer-bonus resolution.
##
## Critical-path tickets: 8.1 hoe-till, 8.2 watering can, 8.3 seed plant +
## growth, 8.4 first 6 crops, 8.13 sprinkler automation.
## Backlog tickets owned here: 8.16 composter (yields fertilizer via this
## autoload), 8.17 greenhouse buff, 8.19 multi-harvest regrow, 8.22 pot planter
## (reuses TilledSoil with `indoor=true`), 8.31 fertilizer variants, 8.32
## trellis (reuses TilledSoil with `trellis=true`), 8.33 sapling, 8.34
## crystal/coral propagation, 8.45 Bomb Pepper, 8.46 Glow Cap, 8.47 Heart
## Berry.

signal soil_tilled(world_pos: Vector2)
signal soil_watered(world_pos: Vector2)
signal crop_harvested(crop_id: StringName, count: int)

const TILE_SIZE: float = 16.0

## Per-seed crop data. growth_seconds is the *base* time at neutral moisture +
## no fertilizer + no greenhouse. The crop scene scales it by these modifiers
## at runtime.
##
## yield_min/max are how many harvest items roll on full maturity. regrow_after
## > 0 = multi-harvest (ticket 8.19): on harvest, the plant snaps back to stage
## 2 and counts down regrow_after seconds before maturing again, no need to
## replant. on_harvest_place places a structure (Glow Cap → glow_shroom).
## explode_on_walkover = Bomb Pepper steps on it.
const SEED_MAP: Dictionary = {
	&"pale_cap_seed": {
		"crop_id": &"pale_cap",
		"harvest_item_id": &"pale_cap",
		"growth_seconds": 60.0,
		"yield_min": 1, "yield_max": 2,
	},
	&"memory_root_seed": {
		"crop_id": &"memory_root",
		"harvest_item_id": &"memory_root",
		"growth_seconds": 90.0,
		"yield_min": 1, "yield_max": 2,
	},
	&"bloat_oat_seed": {
		"crop_id": &"bloat_oat",
		"harvest_item_id": &"bloat_oat",
		"growth_seconds": 120.0,
		"yield_min": 2, "yield_max": 3,
		"regrow_after": 80.0,  # ticket 8.19 multi-harvest
	},
	&"heart_berry_seed": {
		"crop_id": &"heart_berry",
		"harvest_item_id": &"heart_berry",
		"growth_seconds": 90.0,
		"yield_min": 1, "yield_max": 2,
		"regrow_after": 60.0,  # ticket 8.47 — multi-harvest berry
	},
	&"glow_cap_seed": {
		"crop_id": &"glow_cap",
		"harvest_item_id": &"glow_cap",
		"growth_seconds": 120.0,
		"yield_min": 1, "yield_max": 1,
		"on_harvest_place": &"glow_cap_placeable",  # ticket 8.46
	},
	&"bomb_pepper_seed": {
		"crop_id": &"bomb_pepper",
		"harvest_item_id": &"bomb_pepper",
		"growth_seconds": 90.0,
		"yield_min": 1, "yield_max": 2,
		"explode_on_walkover": true,  # ticket 8.45 — boom when stepped on
	},
}

## Ticket 8.31 — fertilizer variants. Each fertilizer multiplies growth speed
## and rolls a bonus yield chance on harvest. Loam compost is the base; per-
## biome variants land alongside their biome (Verdant in Phase 10, Salt-fert
## in Phase 11). Stored here so a recipe in resources/recipes/ can just point
## at a key.
const FERTILIZER_MAP: Dictionary = {
	&"fertilizer":         { "speed_mult": 1.5, "bonus_yield_chance": 0.20 },
	&"fertilizer_verdant": { "speed_mult": 1.8, "bonus_yield_chance": 0.35 },
	&"fertilizer_salt":    { "speed_mult": 1.3, "bonus_yield_chance": 0.30 },
}

## Ticket 8.20 — bait crafting. Off-hand slot reads this dict.
const BAIT_BONUS: Dictionary = {
	&"bait_basic":   { "weight_mult": 1.0, "rarity_bias": 0.0 },
	&"bait_glow":    { "weight_mult": 1.0, "rarity_bias": 0.15 },
	&"bait_meat":    { "weight_mult": 1.3, "rarity_bias": 0.05 },
}


func is_seed(item_id: StringName) -> bool:
	return SEED_MAP.has(item_id)


func is_hoe(item_id: StringName) -> bool:
	return item_id == &"hoe"


func is_watering_can(item_id: StringName) -> bool:
	return item_id == &"watering_can"


func is_fertilizer(item_id: StringName) -> bool:
	return FERTILIZER_MAP.has(item_id)


func seed_data(item_id: StringName) -> Dictionary:
	return SEED_MAP.get(item_id, {})


## Ticket 8.1 — Hoe interaction. Snaps the world position to a 16-px tile
## center and spawns a TilledSoil (if no soil already there). Returns true if
## new soil was created.
func till_at(world_pos: Vector2) -> bool:
	var snapped: Vector2 = _snap_to_tile(world_pos)
	# Cheap occupancy probe — any existing soil within 8 px wins.
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	for s in tree.get_nodes_in_group("tilled_soil"):
		var soil := s as Node2D
		if soil and soil.global_position.distance_to(snapped) < 8.0:
			return false
	var scn := load("res://scenes/farming/tilled_soil.tscn") as PackedScene
	if scn == null:
		return false
	var soil := scn.instantiate() as Node2D
	if soil == null:
		return false
	soil.global_position = snapped
	if tree.current_scene:
		tree.current_scene.add_child(soil)
	soil_tilled.emit(snapped)
	EventBus.skill_xp_gained.emit(&"skill_gardening", 1)
	return true


## Ticket 8.3 — Seed planting. Requires either an existing TilledSoil tile, a
## PotPlanter, or a Trellis at the snapped position. Returns true on success.
func plant_seed(item_id: StringName, world_pos: Vector2) -> bool:
	if not is_seed(item_id):
		return false
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var snapped: Vector2 = _snap_to_tile(world_pos)
	# Need tilled soil / planter / trellis to plant. Vanilla CK lets you place
	# crops on any floor; we tighten that to soil for clearer gardening UX.
	var soil: Node2D = _find_soil_near(snapped)
	if soil == null:
		EventBus.ui_toast.emit("Needs tilled soil.", 1.0)
		return false
	if soil.has_method("has_crop") and soil.call("has_crop"):
		EventBus.ui_toast.emit("Already planted.", 1.0)
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
	crop.harvest_min = int(data.get("yield_min", 1))
	crop.harvest_max = int(data.get("yield_max", 2))
	crop.regrow_after = float(data.get("regrow_after", 0.0))
	crop.on_harvest_place = StringName(data.get("on_harvest_place", &""))
	crop.explode_on_walkover = bool(data.get("explode_on_walkover", false))
	crop.global_position = snapped
	if soil.has_method("attach_crop"):
		soil.call("attach_crop", crop)
	if tree.current_scene:
		tree.current_scene.add_child(crop)
	EventBus.ui_toast.emit("Planted.", 1.0)
	EventBus.skill_xp_gained.emit(&"skill_gardening", 1)
	return true


## Ticket 8.2 — Watering. Waters a soil tile + any crop sitting on it. The
## moisture state on the soil applies to *next* seed planted too.
func water_at(world_pos: Vector2) -> bool:
	var snapped: Vector2 = _snap_to_tile(world_pos)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var watered_anything: bool = false
	for s in tree.get_nodes_in_group("tilled_soil"):
		var soil := s as Node2D
		if soil and soil.global_position.distance_to(snapped) < 12.0:
			if soil.has_method("set_moist"):
				soil.call("set_moist", true)
			watered_anything = true
			break
	for c in tree.get_nodes_in_group("planted_crop"):
		var crop: PlantedCrop = c
		if crop.global_position.distance_to(snapped) < 14.0:
			crop.water()
			watered_anything = true
	if watered_anything:
		soil_watered.emit(snapped)
		EventBus.skill_xp_gained.emit(&"skill_gardening", 1)
	return watered_anything


## Ticket 8.13 — Sprinkler pulse. Called by Sprinkler.gd on its beat. Waters
## every TilledSoil within `radius` of `origin`.
func sprinkler_pulse(origin: Vector2, radius: float = 32.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for s in tree.get_nodes_in_group("tilled_soil"):
		var soil := s as Node2D
		if soil == null:
			continue
		if soil.global_position.distance_to(origin) > radius:
			continue
		if soil.has_method("set_moist"):
			soil.call("set_moist", true)
	for c in tree.get_nodes_in_group("planted_crop"):
		var crop: PlantedCrop = c
		if crop.global_position.distance_to(origin) <= radius:
			crop.water()


## Apply a fertilizer item to the soil at `world_pos`. Returns true on success.
func apply_fertilizer(item_id: StringName, world_pos: Vector2) -> bool:
	if not is_fertilizer(item_id):
		return false
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var snapped: Vector2 = _snap_to_tile(world_pos)
	for s in tree.get_nodes_in_group("tilled_soil"):
		var soil := s as Node2D
		if soil and soil.global_position.distance_to(snapped) < 12.0:
			if soil.has_method("set_fertilizer"):
				var data: Dictionary = FERTILIZER_MAP[item_id]
				soil.call("set_fertilizer", item_id, data)
			if Inventory.try_remove(item_id, 1) > 0:
				return true
			return false
	return false


## Ticket 8.17 — Greenhouse buff. Returns a growth-speed multiplier (≥ 1.0)
## for crops at `world_pos`. Greenhouse coverage is 64px radius from any
## Greenhouse placeable in the scene.
func greenhouse_multiplier_at(world_pos: Vector2) -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return 1.0
	var best: float = 1.0
	for g in tree.get_nodes_in_group("greenhouse"):
		var gh := g as Node2D
		if gh == null:
			continue
		if gh.global_position.distance_to(world_pos) <= 64.0:
			best = maxf(best, 1.6)
	return best


func _snap_to_tile(world_pos: Vector2) -> Vector2:
	return Vector2(
		floor(world_pos.x / TILE_SIZE) * TILE_SIZE + TILE_SIZE * 0.5,
		floor(world_pos.y / TILE_SIZE) * TILE_SIZE + TILE_SIZE * 0.5,
	)


func _find_soil_near(snapped: Vector2) -> Node2D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	for group in [&"tilled_soil", &"pot_planter", &"trellis"]:
		for s in tree.get_nodes_in_group(group):
			var soil := s as Node2D
			if soil and soil.global_position.distance_to(snapped) < 10.0:
				return soil
	return null
