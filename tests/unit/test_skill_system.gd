extends GutTest


func before_each() -> void:
	for s in SkillSystem.ALL_SKILLS:
		SkillSystem._xp[s] = 0
		SkillSystem._level[s] = 0


func test_starts_at_level_zero() -> void:
	assert_eq(SkillSystem.get_level(&"skill_mining"), 0)


func test_xp_threshold_levels_up() -> void:
	SkillSystem.add_xp(&"skill_mining", 100)
	assert_eq(SkillSystem.get_level(&"skill_mining"), 1)


func test_multiple_levels_in_one_grant() -> void:
	SkillSystem.add_xp(&"skill_mining", 5000)
	assert_true(SkillSystem.get_level(&"skill_mining") > 1)


func test_cap_at_100() -> void:
	SkillSystem.add_xp(&"skill_mining", 9999999999)
	assert_eq(SkillSystem.get_level(&"skill_mining"), SkillSystem.SKILL_CAP_LEVEL)
