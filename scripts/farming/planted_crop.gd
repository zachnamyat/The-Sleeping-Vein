extends Area2D
class_name PlantedCrop

## A growing crop entity. Walks through 4 growth stages and on full maturity
## becomes harvestable.
##
## Phase 8 expansions:
##   - regrow_after > 0: multi-harvest (ticket 8.19). Harvest snaps to stage 2
##     and counts down regrow_after seconds before maturing again.
##   - on_harvest_place: when set, harvest places a structure of that id at
##     the crop position (Glow Cap → glow_shroom, ticket 8.46).
##   - explode_on_walkover: Bomb Pepper goes off when stepped on (ticket 8.45).
##   - fertilizer + greenhouse modifiers apply on top of the watered 2× speed.

signal harvested

@export var crop_id: StringName = &"pale_cap"
@export var harvest_item_id: StringName = &"pale_cap"
@export var harvest_min: int = 1
@export var harvest_max: int = 2
@export var growth_seconds: float = 60.0   ## Phase 8 MVP: 60s; Phase 15 polish: 10 min/600s

## Phase 8 multi-harvest. 0 = single-harvest (despawn on pick).
@export var regrow_after: float = 0.0

## Phase 8 chained-placement (Glow Cap → glow_shroom_placeable etc.).
@export var on_harvest_place: StringName = &""

## Phase 8 Bomb Pepper: ignites on player step.
@export var explode_on_walkover: bool = false

var _growth: float = 0.0
var _mature: bool = false
var _watered: bool = false
## Phase 8 — fertilizer growth multiplier applied by the underlying soil.
var _fert_speed: float = 1.0
## Phase 8 — bonus yield chance from fertilizer.
var _fert_bonus_chance: float = 0.0


func _ready() -> void:
	add_to_group("planted_crop")
	collision_layer = 0
	collision_mask = 2  # player
	body_entered.connect(_on_body_entered)
	_update_visual()


func _process(delta: float) -> void:
	if _mature:
		return
	var mult: float = 1.0
	if _watered:
		mult *= 2.0
	mult *= _fert_speed
	mult *= FarmingSystem.greenhouse_multiplier_at(global_position)
	_growth += delta * mult
	if _growth >= growth_seconds:
		_mature = true
		_update_visual()


func water() -> void:
	_watered = true
	if has_node("Sprite2D"):
		($Sprite2D as Sprite2D).modulate = Color(0.85, 1.0, 1.0)


## Called by TilledSoil when fertilizer is applied to the soil tile.
func set_fertilizer_bonus(speed_mult: float, bonus_chance: float) -> void:
	_fert_speed = maxf(1.0, speed_mult)
	_fert_bonus_chance = clampf(bonus_chance, 0.0, 1.0)


func _update_visual() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	# Phase 8 — 4-stage scale ramp so the player can read growth progress at
	# a glance: seedling → sprout → bud → mature.
	var stage: float = clampf(_growth / growth_seconds, 0.0, 1.0)
	sprite.scale = Vector2(0.35 + 0.65 * stage, 0.35 + 0.65 * stage)
	if _mature:
		sprite.modulate = Color(1.0, 1.0, 0.6)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	# Phase 8.45 — Bomb Pepper: walks-into = boom regardless of maturity.
	if explode_on_walkover:
		_explode_at_self()
		return
	if not _mature:
		return
	_do_harvest()


func _do_harvest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count: int = rng.randi_range(harvest_min, harvest_max)
	# Fertilizer bonus yield.
	if _fert_bonus_chance > 0.0 and rng.randf() < _fert_bonus_chance:
		count += 1
	Inventory.try_add(harvest_item_id, count)
	EventBus.skill_xp_gained.emit(&"skill_gardening", 4)
	FarmingSystem.crop_harvested.emit(crop_id, count)
	harvested.emit()
	# Place a structure if requested (Glow Cap ticket 8.46).
	if on_harvest_place != &"":
		_place_chained_structure()
	# Multi-harvest (ticket 8.19): rewind to stage 2 instead of despawning.
	if regrow_after > 0.0:
		_mature = false
		_growth = growth_seconds - regrow_after
		_update_visual()
		var sprite := get_node_or_null("Sprite2D") as Sprite2D
		if sprite:
			sprite.modulate = Color(0.6, 0.9, 0.5)
		_watered = false
		return
	queue_free()


func _place_chained_structure() -> void:
	# Use the same scene table the player_combat placement path uses.
	const SCENES := {
		&"glow_cap_placeable": "res://scenes/structures/glow_shroom.tscn",
	}
	var path: String = String(SCENES.get(on_harvest_place, ""))
	if path == "":
		return
	var scn := load(path) as PackedScene
	if scn == null:
		return
	var node := scn.instantiate() as Node2D
	if node == null:
		return
	node.global_position = global_position
	var tree := get_tree()
	if tree and tree.current_scene:
		tree.current_scene.add_child(node)


func _explode_at_self() -> void:
	# Spawn an AOE damage zone analogous to a Bomb.
	var tree := get_tree()
	if tree == null:
		queue_free()
		return
	EventBus.aoe_indicator_requested.emit(global_position, 24.0, 0.4, Color(1.0, 0.4, 0.2, 0.6))
	EventBus.camera_shake_requested.emit(2.0, 0.18)
	for n in tree.get_nodes_in_group("mob"):
		var m := n as Node2D
		if m and m.global_position.distance_to(global_position) <= 24.0:
			var hb := m.get_node_or_null("Hurtbox") as HurtboxComponent
			if hb:
				hb.receive_hit_full(self, 22, &"explosive", &"player", false)
	# Damage the player too — Core Keeper Bomb Pepper hurts you if you step on it.
	for p in tree.get_nodes_in_group("player"):
		var pn := p as Node2D
		if pn and pn.global_position.distance_to(global_position) <= 22.0:
			var hb := pn.get_node_or_null("Hurtbox") as HurtboxComponent
			if hb:
				hb.receive_hit_full(self, 8, &"explosive", &"enemy", false)
	if AudioBus:
		AudioBus.play_sfx(&"bomb_explode", global_position)
	queue_free()
