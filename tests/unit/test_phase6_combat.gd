extends GutTest

## Phase 6 — combat-depth test bundle. Verifies damage-type taxonomy, status
## effect lifecycle, weakness multiplier, mob stagger, attack-pattern cycler,
## and the new ItemDef fields.


func before_each() -> void:
	GameState.allocated_talents.clear()
	if Inventory:
		Inventory.equipment.clear()
		for s in Inventory.EQUIPMENT_SLOTS:
			Inventory.equipment[s] = &""


# --- 6.5 — Damage-type registry ----------------------------------------------


func test_damage_type_includes_phase6_types() -> void:
	assert_true(DamageType.is_valid(DamageType.LIGHTNING))
	assert_true(DamageType.is_valid(DamageType.VOID))
	assert_true(DamageType.is_valid(DamageType.BLEED))


func test_damage_type_color_lookup_returns_meaningful_color() -> void:
	var c_fire: Color = DamageType.color_for(DamageType.FIRE)
	assert_almost_eq(c_fire.r, 1.0, 0.01)
	# Unknown type falls back to white.
	var c_unknown: Color = DamageType.color_for(&"nonexistent")
	assert_eq(c_unknown, Color.WHITE)


func test_hit_sfx_lookup_per_type() -> void:
	# Every type has a registered SFX id (no &"" surprises).
	for type in DamageType.ALL_TYPES:
		assert_ne(String(DamageType.hit_sfx_for(type)), "", "Missing SFX for type %s" % type)


# --- 6.6 / 6.7 — DoT mechanics -----------------------------------------------


func test_burn_dot_ticks_and_expires() -> void:
	var entity := _build_test_entity(40)
	var status: StatusEffects = entity.get_node("StatusEffects")
	var hc: HealthComponent = entity.get_node("HealthComponent")
	status.apply(&"burn", 1.5, null)
	assert_true(status.has_effect(&"burn"))
	# Manually invoke the DoT tick to bypass the 0.5s gating.
	status._apply_dot_ticks(0.5)
	assert_lt(hc.current_health, 40)
	# Sufficient time advances run the duration to expiry.
	for _i in range(5):
		status._advance_durations(0.5)
	assert_false(status.has_effect(&"burn"))
	entity.free()


func test_poison_reduces_healing() -> void:
	var entity := _build_test_entity(40)
	var status: StatusEffects = entity.get_node("StatusEffects")
	var hc: HealthComponent = entity.get_node("HealthComponent")
	hc.apply_damage(20, null)  # bring HP to 20
	# Without poison: heal 10 -> 30
	hc.heal(10, null)
	assert_eq(hc.current_health, 30)
	# With poison: heal_multiplier = 0.25, so heal 10 -> +3 (rounded).
	status.apply(&"poison", 5.0, null)
	hc.heal(10, null)
	assert_lt(hc.current_health, 40)  # not back to full
	entity.free()


# --- 6.8 / 6.9 / 6.30 — speed multipliers ------------------------------------


func test_cold_halves_speed_freeze_zeroes_it() -> void:
	var entity := _build_test_entity(40)
	var status: StatusEffects = entity.get_node("StatusEffects")
	assert_almost_eq(status.current_speed_multiplier(), 1.0, 0.01)
	status.apply(&"cold", 2.0, null)
	assert_almost_eq(status.current_speed_multiplier(), 0.5, 0.01)
	status.apply(&"freeze", 2.0, null)
	assert_almost_eq(status.current_speed_multiplier(), 0.0, 0.01)
	entity.free()


func test_slow_stacks_with_cold_below_one() -> void:
	var entity := _build_test_entity(40)
	var status: StatusEffects = entity.get_node("StatusEffects")
	status.apply(&"slow", 2.0, null)
	assert_almost_eq(status.current_speed_multiplier(), 0.65, 0.01)
	status.apply(&"cold", 2.0, null)
	# 0.5 * 0.65 = 0.325
	assert_almost_eq(status.current_speed_multiplier(), 0.325, 0.01)
	entity.free()


# --- 6.10 — weakness multiplier on HealthComponent ----------------------------


func test_weakness_multiplier_increases_damage() -> void:
	var hc := HealthComponent.new()
	hc.max_health = 100
	hc._ready()
	hc.set_weakness(DamageType.FIRE, 1.5)
	hc.apply_damage(20, null, DamageType.FIRE)
	assert_eq(hc.current_health, 70)  # 100 - 30
	hc.free()


func test_weakness_combines_with_resistance() -> void:
	var hc := HealthComponent.new()
	hc.max_health = 100
	hc._ready()
	hc.set_weakness(DamageType.COLD, 1.5)
	hc.set_resistance(DamageType.COLD, 0.5)
	hc.apply_damage(20, null, DamageType.COLD)
	# 20 * 1.5 * (1 - 0.5) = 15
	assert_eq(hc.current_health, 85)
	hc.free()


# --- 6.12 — armor formula sanity ---------------------------------------------


func test_armor_floor_one_tenth_base() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var r := CombatMath.resolve_damage(50, 0.0, 0.0, 0.0, 100000, rng)
	assert_gte(r["final_damage"], 5)  # 10% floor of 50


# --- 6.39 — stagger meter -----------------------------------------------------


func test_stagger_meter_emits_when_filled() -> void:
	var hc := HealthComponent.new()
	hc.max_health = 200
	hc.stagger_threshold = 30
	hc._ready()
	var triggered := [false]
	hc.staggered.connect(func(_s: float) -> void:
		triggered[0] = true
	)
	hc.apply_damage(35, null, DamageType.PHYSICAL, true)
	assert_true(triggered[0])
	# Meter resets after firing.
	assert_eq(hc.stagger_meter, 0)
	hc.free()


func test_stagger_does_not_fire_for_light_hits() -> void:
	var hc := HealthComponent.new()
	hc.max_health = 200
	hc.stagger_threshold = 30
	hc._ready()
	var triggered := [false]
	hc.staggered.connect(func(_s: float) -> void:
		triggered[0] = true
	)
	hc.apply_damage(20, null, DamageType.PHYSICAL, false)
	assert_false(triggered[0])
	hc.free()


# --- 6.48 — boss attack-pattern cycler ---------------------------------------


func test_attack_pattern_entry_helper_packs_dictionary() -> void:
	var ent: Dictionary = AttackPattern.entry(&"slam", &"slam", 0.5, 1.0, 32.0, 8, &"physical", 0.0)
	assert_eq(StringName(ent["id"]), &"slam")
	assert_eq(int(ent["damage"]), 8)
	assert_almost_eq(float(ent["telegraph_seconds"]), 0.5, 0.01)


func test_attack_cycler_advances_through_pattern() -> void:
	var pattern := AttackPattern.new()
	pattern.entries = [
		AttackPattern.entry(&"a", &"slam", 0.1, 0.1),
		AttackPattern.entry(&"b", &"slam", 0.1, 0.1),
		AttackPattern.entry(&"c", &"slam", 0.1, 0.1),
	]
	pattern.loop = true
	var cycler := BossAttackCycler.new()
	cycler.pattern = pattern
	cycler.attached_boss = Node2D.new()
	add_child_autofree(cycler.attached_boss)
	add_child_autofree(cycler)
	cycler.start()
	assert_eq(cycler.current_index(), 0)
	cycler._cursor = 1
	assert_eq(StringName(pattern.entries[1].get("id")), &"b")
	# Peek wraps when looping.
	cycler._cursor = 2
	assert_eq(cycler.peek_next(), &"a")


# --- 6.11 — PlayerStats crit aggregation -------------------------------------


func test_player_stats_crit_aggregates_equipment() -> void:
	var ring := ItemDef.new()
	ring.id = &"test_ring_crit"
	ring.crit_chance_bonus = 0.10
	ring.equipment_slot = &"ring_1"
	# Inject directly so the autoload can find it.
	ItemRegistry._defs[ring.id] = ring
	Inventory.equipment[&"ring_1"] = ring.id
	PlayerStats.recompute()
	var base_crit: float = CombatMath.player_crit_chance()
	assert_almost_eq(PlayerStats.crit_chance(), base_crit + 0.10, 0.001)
	Inventory.equipment[&"ring_1"] = &""
	ItemRegistry._defs.erase(ring.id)


# --- 6.55 — mining speed multiplier --------------------------------------------


func test_mining_speed_multiplier_scales_with_crafting_talent() -> void:
	GameState.allocated_talents.clear()
	assert_almost_eq(PlayerStats.mining_speed_multiplier(), 1.0, 0.01)
	GameState.allocated_talents[&"skill_crafting"] = 4
	# 4 points * 5% = +20% mining speed.
	PlayerStats.recompute()
	assert_almost_eq(PlayerStats.mining_speed_multiplier(), 1.20, 0.01)
	GameState.allocated_talents.clear()


# --- Helpers -----------------------------------------------------------------


func _build_test_entity(hp: int) -> Node2D:
	var entity := Node2D.new()
	var hc := HealthComponent.new()
	hc.name = "HealthComponent"
	hc.max_health = hp
	entity.add_child(hc)
	hc._ready()
	var status := StatusEffects.new()
	status.name = "StatusEffects"
	status.health_component_path = NodePath("../HealthComponent")
	entity.add_child(status)
	add_child_autofree(entity)
	return entity
