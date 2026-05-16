extends Node

## Phase 7.19 / 2.47 — Luck stat aggregator.
##
## Reads PlayerStats.luck (sum of accessory + talent + set bonuses) and exposes
## convenience methods for loot rolls. Every 100 Luck points = +100% chance
## boost on any roll; values are typically 1-50.
##
## Consumers:
##   - LootTable.roll() (via `apply_luck` post-pass): bumps each weighted roll's
##     count by `bonus_drop_count()` slots.
##   - FishingSystem: nudges rare-fish chance.
##   - WishingWell / TreasureChest: increases their reward roll count.
##   - ItemDrop: increases pickup-radius (handled by player_combat.MAGNET_RADIUS).

const LUCK_PER_BONUS_DROP: float = 25.0  ## Each 25 luck = +1 guaranteed extra drop slot.
const LUCK_PER_RARE_BUMP: float = 50.0   ## Each 50 luck = +1 rarity tier upgrade chance.


func _ready() -> void:
	pass


func current_luck() -> float:
	if PlayerStats == null:
		return 0.0
	return PlayerStats.luck


## Number of extra weighted-rolls a LootTable should perform thanks to Luck.
## A 0-luck player gets 0 bonus; a 50-luck player gets 2.
func bonus_drop_count() -> int:
	return int(floor(current_luck() / LUCK_PER_BONUS_DROP))


## Probability that a single drop's rarity gets bumped one tier (0..1).
func rarity_upgrade_chance() -> float:
	return clampf(current_luck() / 100.0, 0.0, 0.5)  ## cap at 50% so luck stays diminishing


## Generic multiplier applied to chance rolls (1.0 = no change, 1.5 = +50%).
func roll_multiplier() -> float:
	return 1.0 + clampf(current_luck() / 100.0, 0.0, 1.0)
