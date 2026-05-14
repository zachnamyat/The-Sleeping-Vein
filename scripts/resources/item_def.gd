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
@export var axe_tier: int = 0       ## > 0 if this is a tree-felling axe
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

## Phase 3.4 — which equipment slot this item occupies when equipped.
## Empty StringName means "not equippable" (most weapons, tools, materials).
## Values match Inventory.EQUIPMENT_SLOTS: helmet / chest / legs / boots / off_hand /
## necklace / ring_1 / ring_2 / bracelet / belt / pet.
@export var equipment_slot: StringName = &""

## Phase 3.59 — short flavor text shown under the item description on tooltip
## for relics, key items, and rare drops. Optional; falls back to nothing.
@export var lore_text: String = ""

## Phase 3.74 — tool durability. 0 = unbreakable. Above 0, each use decrements;
## hits 0 = breaks. Decrement logic in player_combat once a per-instance
## durability tracker lands (Phase 16+); the field exists now so resource files
## are forward-compatible.
@export var max_durability: int = 0

## Phase 3.46 — two-handed weapons occupy the off_hand slot when equipped, so
## arrows / shields can't fit alongside. UI checks this when rendering tooltips.
@export var two_handed: bool = false

@export var lore_ref: String = ""
