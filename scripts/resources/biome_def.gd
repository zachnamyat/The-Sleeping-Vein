extends Resource
class_name BiomeDef

## Data-driven biome definition. One per stratum.
## Generator reads these to paint chunks and place ore + mob spawns.

@export var id: StringName = &""
@export var display_name: String = ""
@export var stratum_index: int = 1   ## 1..9
@export var distance_from_anchor_tiles: float = 0.0  ## Center radius
@export var ring_thickness_tiles: float = 256.0      ## How thick the ring is

# Tilemap source IDs in the shared TileSet
@export var floor_source_id: int = 0
@export var wall_source_id: int = 1
@export var ore_source_id: int = 2

@export var ore_id: StringName = &"shaleseed"
@export var ore_required_pickaxe_tier: int = 1
@export var ore_density_per_chunk: int = 6
@export var wall_density_per_chunk: int = 18

# Ambient
@export_color_no_alpha var ambient_high_color: Color = Color(1.0, 0.92, 0.75)
@export_color_no_alpha var ambient_low_color: Color = Color(0.40, 0.36, 0.28)
@export var ambient_track_id: StringName = &""

# Mobs that can spawn in this biome (mob_def ids)
@export var mob_spawn_table: Array[StringName] = []
@export var mobs_per_chunk: int = 1

# Environmental hazard — ticked by BiomeHazardSystem while the player stands in this biome.
# Hazard ids: "" (none) / "toxic_spore" / "salt_corrosion" / "heat" / "cold" / "void".
# Damage applies once per second. resist_item_id is consumed (or just held) to negate the hazard.
@export var hazard_id: StringName = &""
@export var hazard_damage_per_second: int = 0
@export var hazard_damage_type: StringName = &"physical"
@export var resist_item_id: StringName = &""           ## In inventory = immune
@export var resist_armor_id: StringName = &""          ## In inventory = 50% reduction

@export var lore_ref: String = ""
