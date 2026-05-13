extends GutTest

## Phase 2.7 — LootTable behaviour. Guaranteed drops always roll; weighted
## drops are deterministic with a seeded RNG.

func _make_table() -> LootTable:
	var lt := LootTable.new()
	lt.guaranteed_drops = [{"item_id": "loambeetle", "min": 1, "max": 2}]
	lt.weighted_drops = [
		{"item_id": "loam", "min": 1, "max": 1, "weight": 4.0},
		{"item_id": "shaleseed", "min": 1, "max": 1, "weight": 1.0},
	]
	lt.max_rolls = 1
	return lt


func test_guaranteed_drop_always_present() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var result := _make_table().roll(rng)
	var ids: Array = []
	for d in result:
		ids.append(StringName(d["item_id"]))
	assert_true(&"loambeetle" in ids, "guaranteed loambeetle should always drop")


func test_weighted_drop_selects_one_per_roll() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var lt := _make_table()
	# 1 guaranteed + 1 weighted = 2 drops total per roll
	var result := lt.roll(rng)
	assert_eq(result.size(), 2)


func test_weighted_drop_seeded_deterministic() -> void:
	var lt := _make_table()
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 99
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 99
	var a := lt.roll(rng_a)
	var b := lt.roll(rng_b)
	assert_eq(a.size(), b.size())
	for i in range(a.size()):
		assert_eq(StringName(a[i]["item_id"]), StringName(b[i]["item_id"]))


func test_count_range_respected() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var result := _make_table().roll(rng)
	for d in result:
		if StringName(d["item_id"]) == &"loambeetle":
			var c: int = int(d["count"])
			assert_true(c >= 1 and c <= 2, "loambeetle count %d outside [1,2]" % c)


func test_empty_table_returns_empty() -> void:
	var lt := LootTable.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var result := lt.roll(rng)
	assert_eq(result.size(), 0)
