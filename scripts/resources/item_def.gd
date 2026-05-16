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

# ============================================================================
# Phase 6 — Combat depth additions
# ============================================================================

## Phase 6.6/6.7/6.8/6.9/6.19/6.30 — status effect this weapon attempts to apply
## on hit, plus its duration in seconds. 0 chance => no effect.
@export var on_hit_status: StringName = &""
@export var on_hit_status_chance: float = 0.0
@export var on_hit_status_duration: float = 0.0

## Phase 6.11 — bonus crit chance / crit damage from this item (sums across
## equipment). Stored as fractions: 0.05 == +5% crit chance.
@export var crit_chance_bonus: float = 0.0
@export var crit_damage_bonus: float = 0.0

## Phase 6.17 — per-element resistance % when equipped. Same units as the
## HealthComponent.set_resistance value. e.g. {"fire": 0.25} = -25% fire damage
## taken. Equipment values stack additively, capped at 0.95.
@export var status_resists: Dictionary = {}

## Phase 6.28 — lifesteal & manasteel as fractions of post-mitigation damage.
@export var lifesteal_fraction: float = 0.0
@export var manasteel_fraction: float = 0.0

## Phase 6.29 — thorns: damage reflected back to melee attacker per hit.
@export var thorns_damage: int = 0

## Phase 6.32 — accuracy / aim cone (degrees of scatter; 0 = perfect aim).
@export var aim_cone_degrees: float = 0.0

## Phase 6.33 — knockback resistance % when equipped (0..1).
@export var knockback_resistance_bonus: float = 0.0

## Phase 6.40 — flat mana regen-per-second granted by item.
@export var mana_regen_bonus: float = 0.0

## Phase 6.41 — multiplicative cooldown reduction. 0.10 = 10% faster cycles.
@export var cooldown_reduction: float = 0.0

## Phase 3.54 / 3.55 / 3.78 / 6.45 — projectile / weapon affixes & class hints.
@export var projectile_count: int = 1   ## bow multi-shot
@export var projectile_pierce: int = 0  ## arrow pierce-target count
@export var projectile_arc_degrees: float = 6.0  ## fan width when count>1

## Phase 6.36 — distinct ranged-weapon class names: ranged_bow / ranged_gun /
## ranged_crossbow. Crossbow has a longer reload window.
@export var reload_seconds: float = 0.0

## Phase 6.37 — charge attack: ramp damage to charge_max_multiplier over
## charge_max_seconds while attack_primary held. Bow / heavy-crossbow / spear use this.
@export var chargeable: bool = false
@export var charge_max_seconds: float = 0.8
@export var charge_max_multiplier: float = 2.0

## Phase 6.38 — heavy attack: secondary action that costs more cooldown for a
## big-damage swing.  Set heavy_damage_multiplier > 1 to enable.
@export var heavy_damage_multiplier: float = 1.0
@export var heavy_cooldown_multiplier: float = 1.6

## Phase 6.16 / 6.18 / 6.31 — special action per weapon class (bound to RMB
## while a melee weapon is held).  "" = none. "spin", "thrust", "boomerang_throw",
## "whip_pull", "shield_bash" etc. Resolved in player_combat._try_special.
@export var special_attack: StringName = &""

## Phase 6.46 — mana burst on enemy kill (mana refunded). Used by tomes.
@export var mana_on_kill: int = 0

## Phase 6.55 — mining swing speed bonus (negative subtracts from cooldown
## seconds). Enchanted pickaxes / Crafting talent items.
@export var mining_speed_bonus: float = 0.0

## Phase 6.56 — mining penetration: break N tiles in a straight line per swing.
@export var mining_pierce: int = 0

## Phase 6.34 — when held, % of full move speed the player retains while
## attack_primary is pressed (1.0 = no penalty, 0.4 = 40% speed).
@export var move_while_attack_factor: float = 1.0

## Phase 2.49 — light source intensity / radius for placeable lighting items.
## 0 = not a light source.
@export var light_radius_pixels: float = 0.0
@export var light_color: Color = Color(1.0, 0.78, 0.45)
@export var light_energy: float = 0.0

## Phase 6.5 — primary class flag for status / weapon UI groupings.
## "" / "melee" / "ranged_bow" / "ranged_gun" / "ranged_crossbow" / "magic" /
## "summon" / "fishing" / "bomb" / "shield" / "lantern" / "tome" / "throwable" /
## "boomerang" / "whip" / "spear"
## Rather than touch every existing weapon's `weapon_class`, additional class
## hints land in `weapon_subclass` so existing tooling (player_combat dispatch)
## continues to work unchanged.
@export var weapon_subclass: StringName = &""

## Phase 6.14 — shields: block fraction (0.4 == 40% of incoming damage absorbed
## while RMB held) and parry window (seconds after activation that a perfect
## parry is rewarded with riposte).
@export var block_fraction: float = 0.0
@export var parry_window_seconds: float = 0.0

## Phase 3.47 — dual-wield: when off-hand also has weapon_class, swings
## alternate hands. The off-hand weapon's damage is scaled by this multiplier
## on the off-swing.
@export var off_hand_damage_multiplier: float = 0.6

@export var lore_ref: String = ""

# ============================================================================
# Phase 7 — Accessories, set bonuses, Luck stat (tickets 3.20, 3.83, 7.11, 7.19)
# ============================================================================

## Phase 3.20 — set id: equipping >= 2 pieces with the same set_id triggers a
## set bonus from SetBonuses.bonus_for(set_id, piece_count).
@export var set_id: StringName = &""

## Phase 7.11 — accessory items can grant +N levels to a skill. Maps StringName
## skill_id -> int bonus. E.g. {"skill_mining": 2} = +2 effective Mining level.
@export var skill_level_bonuses: Dictionary = {}

## Phase 7.19 — Luck stat directly granted by an accessory. Each point of luck
## bumps drop rolls / fishing rolls / treasure-chest rolls by 1%.
@export var luck_bonus: float = 0.0

## Phase 2.22 — loot magnet radius bonus. 0.5 = +50% pickup radius.
@export var loot_magnet_radius_bonus: float = 0.0

## Phase 7 — direct max-HP / max-mana bonus from accessories (e.g. amulets).
@export var max_hp_bonus: int = 0
@export var max_mana_bonus: int = 0

## Phase 3.29 — reforge metadata. Anvil station applies one random affix to an
## item; the affix is stored on the player's inventory entry, not on the
## ItemDef. The boolean flag on the def says "this item type is reforgeable".
@export var reforgeable: bool = false

## Phase 9.63 — Resonance-bound items don't spoil and aren't dropped on death.
## Walker-only; multiplayer-marked. UI tooltip prints the tag.
@export var resonance_bound: bool = false

## Phase 9.26 — Light-source brightness tier. 0 = no light; 1..3 = dim/medium/bright.
## Players can right-click a light source to step through dim levels (saves power
## in the wider world model, lowers NPC light-pollution penalty).
@export var light_brightness_levels: int = 0
