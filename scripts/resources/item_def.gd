extends Resource
class_name ItemDef

## Data-driven item definition. Saved as a .tres in resources/items/.
## See docs/design/02_lore_to_mechanics_mapping.md for tier/lore alignment.

enum ItemType { MATERIAL, TOOL, WEAPON, ARMOR, CONSUMABLE, PLACEABLE, AMMO, KEY }

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var max_stack: int = 99
@export var item_type: ItemType = ItemType.MATERIAL
@export var tier: int = 0
@export var rarity: int = 0  ## 0 = white, 1 = green, 2 = blue, 3 = purple, 4 = gold

# Tool / weapon stats
@export var pickaxe_tier: int = 0   ## > 0 if this is a pickaxe
@export var base_damage: int = 0
@export var damage_type: StringName = &"physical"
@export var attack_cooldown_seconds: float = 0.5
@export var melee_range_pixels: int = 18
@export var mana_cost: int = 0
@export var weapon_class: StringName = &""   ## "" / "melee" / "ranged_bow" / "ranged_gun" / "magic" / "summon"
@export var ammo_id: StringName = &""        ## consumed per shot (bow/gun)
@export var projectile_speed: float = 240.0
@export var summon_mob_path: String = ""     ## resources/mobs/*.tres summoned on use

# Placeable
@export var placeable_tile_source_id: int = -1  ## TileSet source id when placed
@export var placeable_atlas_coord: Vector2i = Vector2i.ZERO
@export var placeable_layer: StringName = &"floor"

# Consumable / Equipment effects
@export var heal_amount: int = 0
@export var mana_restore: int = 0
@export var hunger_restore: int = 0
@export var buff_id: StringName = &""
@export var buff_duration_seconds: float = 0.0
@export var armor_value: int = 0

@export var lore_ref: String = ""
