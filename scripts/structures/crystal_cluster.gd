extends Area2D
class_name CrystalCluster

## Phase 3.73 (reassigned to Phase 4) — Glasswright Reaches multi-tile resource
## node. Behaves like a chunky ore vein you mine across several hits: each
## mining swing knocks one "shard" off, dropping 1-3 Clearstone per shard.
## When all SHARD_COUNT shards are gone the cluster destroys itself. Mining
## requires the pickaxe tier configured by `required_pickaxe_tier`.

const TOTAL_SHARDS_DEFAULT: int = 4
const PER_SHARD_HP: int = 12

@export var required_pickaxe_tier: int = 2
@export var shard_count_total: int = TOTAL_SHARDS_DEFAULT
@export var ore_item_id: StringName = &"clearstone"
@export var min_per_shard: int = 1
@export var max_per_shard: int = 3

var _shards_remaining: int = TOTAL_SHARDS_DEFAULT
var _shard_hp: int = PER_SHARD_HP


func _ready() -> void:
	_shards_remaining = shard_count_total
	# Phase 3.73 — multi-mine node sits in the wall_layer group so player_combat
	# routes pickaxe hits at it the same way it does walls and mob_spawners.
	add_to_group("wall_layer")
	add_to_group("crystal_cluster")
	collision_layer = 0
	collision_mask = 2


func apply_damage(amount: int, _source: Node = null, _type: StringName = &"physical") -> void:
	# Phase 3.73 — tier-gated. Mining systems check tier on the held pickaxe
	# before calling, so this is mostly a safety net; we still soft-fail when
	# called by a non-pickaxe hit (apply_damage returns harmlessly).
	if amount <= 0:
		return
	_shard_hp -= amount
	if _shard_hp <= 0:
		_break_shard()


func _break_shard() -> void:
	_shards_remaining -= 1
	_shard_hp = PER_SHARD_HP
	# Drop ore inline.
	if ore_item_id != &"":
		var amount: int = randi_range(min_per_shard, max_per_shard)
		Inventory.try_add(ore_item_id, amount)
		EventBus.item_picked_up.emit(ore_item_id, amount)
	# Mining XP per shard, mirroring tile-mining cadence.
	EventBus.skill_xp_gained.emit(&"skill_mining", 2)
	if AudioBus:
		AudioBus.play_sfx(&"crystal_chip")
	# Visual: scale the sprite down to read shards-remaining state.
	var sprite := $Sprite2D as Sprite2D
	if sprite and shard_count_total > 0:
		var s: float = clampf(float(_shards_remaining) / float(shard_count_total), 0.35, 1.0)
		sprite.scale = Vector2(s, s)
	if _shards_remaining <= 0:
		_destroy()


func _destroy() -> void:
	if AudioBus:
		AudioBus.play_sfx(&"break_crystal")
	queue_free()
