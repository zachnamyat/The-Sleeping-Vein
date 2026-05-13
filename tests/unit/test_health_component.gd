extends GutTest

## GUT test for HealthComponent. Verifies damage/heal/resistance/death.

var hc: HealthComponent


func before_each() -> void:
	hc = HealthComponent.new()
	hc.max_health = 100
	add_child_autofree(hc)
	hc._ready()


func test_starts_at_full_health() -> void:
	assert_eq(hc.current_health, 100)


func test_apply_damage_reduces_health() -> void:
	var dealt := hc.apply_damage(30)
	assert_eq(dealt, 30)
	assert_eq(hc.current_health, 70)


func test_resistance_reduces_damage() -> void:
	hc.set_resistance(DamageType.FIRE, 0.5)
	var dealt := hc.apply_damage(40, null, DamageType.FIRE)
	assert_eq(dealt, 20)
	assert_eq(hc.current_health, 80)


func test_death_at_zero_health() -> void:
	hc.apply_damage(100)
	assert_true(hc.is_dead())


func test_heal_caps_at_max() -> void:
	hc.apply_damage(50)
	var healed := hc.heal(999)
	assert_eq(healed, 50)
	assert_eq(hc.current_health, 100)


func test_invulnerable_takes_no_damage() -> void:
	hc.is_invulnerable = true
	var dealt := hc.apply_damage(50)
	assert_eq(dealt, 0)
	assert_eq(hc.current_health, 100)
