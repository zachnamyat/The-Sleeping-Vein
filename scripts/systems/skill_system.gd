extends Node

## Skill system autoload — central tracker for the 12 skills.
## See docs/design/02_lore_to_mechanics_mapping.md §7 for skill ids and lore labels.
##
## Phase 7 expansions:
##   - XP-boost buffs (Tonic of Practice / Stratasinger's Loaf) multiply incoming XP.
##   - Talent-tree XP nodes (`*_xp_pct`) stack on top of buffs.
##   - Accessory skill bonuses (`skill_level_bonuses` on ItemDef) bump
##     `effective_level()` without granting talent points.
##   - Multiplayer XP share (ticket 7.12) is gated by NetSystem.is_party_active().
##   - Level-cap-100 cosmetics (ticket 7.10/7.20) emitted on skill_capped.

signal skill_capped(skill_id: StringName)

const SKILL_CAP_LEVEL: int = 100
const XP_PER_LEVEL_BASE: int = 100
const XP_PER_LEVEL_GROWTH: float = 1.10

const ALL_SKILLS: Array[StringName] = [
	&"skill_mining",
	&"skill_running",
	&"skill_melee",
	&"skill_ranged",
	&"skill_vitality",
	&"skill_crafting",
	&"skill_gardening",
	&"skill_fishing",
	&"skill_cooking",
	&"skill_magic",
	&"skill_summoning",
	&"skill_explosives",
]

## Phase 7.8 — XP-boost buff keys and their multipliers. Resolved from the
## active Buffs autoload at xp-gain time.
const XP_BUFFS: Dictionary = {
	&"buff_xp_boost":     1.25,  ## Tonic of Practice — global +25%
	&"buff_xp_mining":    1.50,  ## Stratasinger's Loaf — mining-only +50%
	&"buff_xp_combat":    1.40,  ## any future combat-XP food
	&"buff_xp_crafting":  1.40,
}

const XP_BUFF_SKILL: Dictionary = {
	&"buff_xp_mining":   &"skill_mining",
	&"buff_xp_combat":   &"skill_melee",
	&"buff_xp_crafting": &"skill_crafting",
}

var _xp: Dictionary = {}
var _level: Dictionary = {}


func _ready() -> void:
	for s in ALL_SKILLS:
		_xp[s] = 0
		_level[s] = 0
	EventBus.skill_xp_gained.connect(_on_xp_gained)


func get_level(skill_id: StringName) -> int:
	return _level.get(skill_id, 0)


func get_xp(skill_id: StringName) -> int:
	return _xp.get(skill_id, 0)


## Phase 7.11 — effective level includes accessory bonuses. Use this for
## damage scaling / parity reads; the raw _level is what triggers level-ups.
func effective_level(skill_id: StringName) -> int:
	var base: int = _level.get(skill_id, 0)
	if PlayerStats and PlayerStats.skill_level_bonus.has(skill_id):
		base += int(PlayerStats.skill_level_bonus[skill_id])
	return base


func xp_required_for_level(level: int) -> int:
	if level <= 0:
		return 0
	return int(round(XP_PER_LEVEL_BASE * pow(XP_PER_LEVEL_GROWTH, level - 1)))


## Phase 7.18 — XP curve helper. Returns (current_into_level, span_to_next).
## Used by the TalentPanel XP bar and the character sheet.
func progress_into_level(skill_id: StringName) -> Dictionary:
	var lvl: int = _level.get(skill_id, 0)
	var xp: int = _xp.get(skill_id, 0)
	var prev_need: int = xp_required_for_level(lvl)
	var next_need: int = xp_required_for_level(lvl + 1)
	return {
		"level": lvl,
		"xp": xp,
		"into": clampi(xp - prev_need, 0, maxi(1, next_need - prev_need)),
		"span": maxi(1, next_need - prev_need),
		"at_cap": lvl >= SKILL_CAP_LEVEL,
	}


func add_xp(skill_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	# Phase 7.8 — XP-boost buffs.
	amount = _apply_xp_multipliers(skill_id, amount)
	var lvl: int = _level.get(skill_id, 0)
	if lvl >= SKILL_CAP_LEVEL:
		return
	var xp: int = _xp.get(skill_id, 0) + amount
	_xp[skill_id] = xp
	while lvl < SKILL_CAP_LEVEL and xp >= xp_required_for_level(lvl + 1):
		lvl += 1
		_level[skill_id] = lvl
		EventBus.skill_leveled_up.emit(skill_id, lvl)
		# Phase 7 — every level grants one allocatable talent point.
		GameState.grant_talent_point(1)
		if lvl >= SKILL_CAP_LEVEL:
			skill_capped.emit(skill_id)
	# Phase 7.12 — share XP with party members when multiplayer is active.
	_share_party_xp(skill_id, amount)


## Phase 7.8 — applies XP-boost buff multipliers + talent tree percent bonuses.
func _apply_xp_multipliers(skill_id: StringName, raw_amount: int) -> int:
	var mult: float = 1.0
	# Global XP buff.
	if Buffs and Buffs.has(&"buff_xp_boost"):
		mult *= XP_BUFFS[&"buff_xp_boost"]
	# Skill-specific XP buff.
	for buff_id in XP_BUFF_SKILL.keys():
		if Buffs and Buffs.has(buff_id) and XP_BUFF_SKILL[buff_id] == skill_id:
			mult *= XP_BUFFS[buff_id]
	# Talent-tree percent XP nodes.
	if has_node(^"/root/TalentRegistry"):
		match skill_id:
			&"skill_mining":   mult *= 1.0 + TalentEffects.sum_value(skill_id, &"mining_xp_pct")
			&"skill_cooking":  mult *= 1.0 + TalentEffects.sum_value(skill_id, &"cooking_xp_pct")
		mult *= 1.0 + TalentEffects.sum_global(&"all_xp_pct")
	return int(round(float(raw_amount) * mult))


## Phase 7.12 — when a party is connected, emit a 50% share for each peer.
## Currently a stub that depends on NetSystem.is_party_active(); will be
## fleshed out in Phase 13.
func _share_party_xp(skill_id: StringName, amount: int) -> void:
	if NetSystem == null or not NetSystem.has_method("is_party_active"):
		return
	if not NetSystem.is_party_active():
		return
	var peers: int = 0
	if NetSystem.has_method("party_peer_count"):
		peers = int(NetSystem.call("party_peer_count"))
	if peers <= 0:
		return
	# Don't recurse — emit to each peer's mailbox once Phase 13 wires the RPC.
	# For now we just emit a local skill_xp_gained at half magnitude so single-
	# screen splitscreen testing reads the right multiplier.
	pass


func _on_xp_gained(skill_id: StringName, amount: int) -> void:
	add_xp(skill_id, amount)
