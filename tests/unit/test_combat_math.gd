extends GutTest

## GUT test (ticket 0.3 first test) for CombatMath.
## Verifies the damage formula and the mining tier gate.

func test_resolve_damage_no_modifiers_no_armor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var r := CombatMath.resolve_damage(20, 0.0, 0.0, 0.0, 0, rng)
	assert_eq(r["final_damage"], 20)
	assert_false(r["is_crit"])


func test_pct_modifier_adds_damage() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var r := CombatMath.resolve_damage(100, 0.5, 0.0, 0.0, 0, rng)
	assert_eq(r["final_damage"], 150)


func test_armor_reduces_damage() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var no_armor := CombatMath.resolve_damage(100, 0.0, 0.0, 0.0, 0, rng)
	rng.seed = 1
	var with_armor := CombatMath.resolve_damage(100, 0.0, 0.0, 0.0, 20, rng)
	assert_true(with_armor["final_damage"] < no_armor["final_damage"])


func test_minimum_damage_floor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var r := CombatMath.resolve_damage(10, 0.0, 0.0, 0.0, 10000, rng)
	assert_true(r["final_damage"] >= 1)


func test_mining_below_tier_returns_negative() -> void:
	var dmg := CombatMath.resolve_mining_damage(5, 1, 3, 0)
	assert_eq(dmg, -1)


func test_mining_at_or_above_tier_uses_skill_level() -> void:
	var dmg := CombatMath.resolve_mining_damage(5, 3, 3, 10)
	assert_eq(dmg, 15)


func test_mining_damage_helper_adds_talent_bonus() -> void:
	# Phase 2.1 — the gate-less helper used by player_combat. Sums base + skill +
	# (2 per allocated Mining talent point).
	GameState.allocated_talents.clear()
	assert_eq(CombatMath.mining_damage(4, 0), 4)
	assert_eq(CombatMath.mining_damage(4, 6), 10)
	GameState.allocated_talents[&"skill_mining"] = 3
	assert_eq(CombatMath.mining_damage(4, 6), 16)  # 4 + 6 + 3*2
	GameState.allocated_talents.clear()
