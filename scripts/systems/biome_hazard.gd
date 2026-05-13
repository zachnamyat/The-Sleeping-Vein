extends Node

## BiomeHazardSystem.
## Once per second:
##   - finds the player
##   - asks WorldGen what biome they're in
##   - if biome has a hazard and the player doesn't hold the resist item, applies
##     biome.hazard_damage_per_second to the player's HealthComponent.

const TICK: float = 1.0

var _accum: float = 0.0
var _player: Node2D
var _worldgen: Node


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	_accum += delta
	if _accum < TICK:
		return
	_accum = 0.0
	_tick_hazard()


func _tick_hazard() -> void:
	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("player")
		if players.is_empty():
			return
		_player = players[0]
	if _worldgen == null or not is_instance_valid(_worldgen):
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.current_scene:
			_worldgen = tree.current_scene.get_node_or_null("WorldGen") as Node
	if _worldgen == null or not _worldgen.has_method("biome_at"):
		return
	var biome: BiomeDef = _worldgen.biome_at(_player.global_position) as BiomeDef
	if biome == null or biome.hazard_id == &"" or biome.hazard_damage_per_second <= 0:
		return
	if biome.resist_item_id != &"" and Inventory.count_of(biome.resist_item_id) > 0:
		return
	var hc := _player.get_node_or_null("HealthComponent") as HealthComponent
	if hc == null or hc.is_dead():
		return
	# Ticket 11.6 — Salt Wastes swing: day = heat (fire), night = cold.
	var dtype: StringName = biome.hazard_damage_type
	var label: String = String(biome.hazard_id)
	if biome.hazard_id == &"dawning_swing":
		if AudioBus.is_day():
			dtype = &"fire"
			label = "Dawning Heat"
		else:
			dtype = &"cold"
			label = "Dawning Chill"
	# Ticket 11.7 — half damage if matching resist armor in pouch.
	var damage: int = biome.hazard_damage_per_second
	if biome.resist_armor_id != &"" and Inventory.count_of(biome.resist_armor_id) > 0:
		damage = maxi(1, damage / 2)
	hc.apply_damage(damage, null, dtype)
	EventBus.ui_toast.emit("%s — %d %s" % [label.capitalize(), damage, String(dtype)], 0.9)
