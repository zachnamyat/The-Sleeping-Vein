extends Node

## Phase 6 — central aggregator for player combat stats. Reads equipped gear via
## Inventory.equipment + talents via GameState.allocated_talents and exposes the
## summed values. Recomputes on inventory_changed / equipment_changed / settings
## changes, then emits `stats_changed` so the HUD and components can refresh.
##
## All other systems should ask PlayerStats for derived stats:
##   PlayerStats.crit_chance(), PlayerStats.crit_bonus(), PlayerStats.armor_total(),
##   PlayerStats.lifesteal_fraction(), PlayerStats.thorns_damage(),
##   PlayerStats.cooldown_reduction(), PlayerStats.mana_regen_bonus(), etc.
##
## Exists as autoload "PlayerStats" so callers don't need a player ref.

signal stats_changed

# --- Cached aggregate values --------------------------------------------------

var armor_bonus: int = 0
var crit_chance_bonus: float = 0.0
var crit_damage_bonus: float = 0.0
var lifesteal: float = 0.0
var manasteel: float = 0.0
var thorns: int = 0
var knockback_resistance_bonus: float = 0.0
var aim_cone_degrees: float = 0.0  ## from off-hand / talent
var cooldown_reduction: float = 0.0
var mana_regen_bonus: float = 0.0
var mining_speed_bonus: float = 0.0
var mining_pierce: int = 0
var resists: Dictionary = {}    ## type -> additive resist

## Phase 7 — additional fields aggregated from talent trees + accessory items.
var max_hp_bonus: int = 0
var max_mana_bonus: int = 0
var regen_per_second: float = 0.0
var loot_magnet_radius_bonus: float = 0.0  ## fraction; 0.5 = +50% pickup radius
var luck: float = 0.0                       ## 0.01 per point. Used by LootTable + LuckSystem.
var skill_level_bonus: Dictionary = {}      ## skill_id -> int (from accessory items)
var set_bonus_active: Dictionary = {}       ## set_id -> int piece count active


func _ready() -> void:
	if Inventory:
		Inventory.equipment_changed.connect(_on_equipment_changed)
	# inventory_changed lives on EventBus, not on the Inventory autoload.
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.skill_leveled_up.connect(_on_skill_leveled_up)
	EventBus.stat_recompute_requested.connect(recompute)
	# Defer first computation so ItemRegistry has time to scan items first.
	call_deferred("recompute")


func _on_equipment_changed(_slot: StringName, _item_id: StringName) -> void:
	recompute()


func _on_inventory_changed() -> void:
	# Inventory changes can include unequip; keep cheap by just deferring.
	recompute()


func _on_skill_leveled_up(_skill_id: StringName, _new_level: int) -> void:
	recompute()


func recompute() -> void:
	armor_bonus = CombatMath.talent_armor_bonus()
	crit_chance_bonus = 0.0
	crit_damage_bonus = 0.0
	lifesteal = 0.0
	manasteel = 0.0
	thorns = 0
	knockback_resistance_bonus = 0.0
	aim_cone_degrees = 0.0
	cooldown_reduction = 0.0
	mana_regen_bonus = 0.0
	mining_speed_bonus = 0.0
	mining_pierce = 0
	resists.clear()
	max_hp_bonus = CombatMath.talent_max_hp_bonus()
	max_mana_bonus = 0
	regen_per_second = 0.0
	loot_magnet_radius_bonus = 0.0
	luck = 0.0
	skill_level_bonus.clear()
	set_bonus_active.clear()
	if Inventory == null or ItemRegistry == null:
		stats_changed.emit()
		return
	# Equipment aggregation.
	for slot in Inventory.equipment.keys():
		var iid: StringName = StringName(Inventory.equipment.get(slot, &""))
		if iid == &"":
			continue
		var defn: ItemDef = ItemRegistry.get_def(iid)
		if defn == null:
			continue
		armor_bonus += defn.armor_value
		crit_chance_bonus += defn.crit_chance_bonus
		crit_damage_bonus += defn.crit_damage_bonus
		lifesteal += defn.lifesteal_fraction
		manasteel += defn.manasteel_fraction
		thorns += defn.thorns_damage
		knockback_resistance_bonus += defn.knockback_resistance_bonus
		aim_cone_degrees = max(aim_cone_degrees, defn.aim_cone_degrees)
		cooldown_reduction += defn.cooldown_reduction
		mana_regen_bonus += defn.mana_regen_bonus
		mining_speed_bonus += defn.mining_speed_bonus
		mining_pierce = maxi(mining_pierce, defn.mining_pierce)
		for k in defn.status_resists.keys():
			var current: float = float(resists.get(StringName(k), 0.0))
			resists[StringName(k)] = clampf(current + float(defn.status_resists[k]), -1.0, 0.95)
		# Phase 7.11 — accessory items grant +N to a skill level.
		max_hp_bonus += int(defn.max_hp_bonus)
		max_mana_bonus += int(defn.max_mana_bonus)
		luck += float(defn.luck_bonus)
		loot_magnet_radius_bonus += float(defn.loot_magnet_radius_bonus)
		for k in defn.skill_level_bonuses.keys():
			var sname := StringName(k)
			skill_level_bonus[sname] = int(skill_level_bonus.get(sname, 0)) + int(defn.skill_level_bonuses[k])
		# Phase 3.20 — accumulate set-id presence; resolve bonuses below.
		if defn.set_id != &"":
			set_bonus_active[defn.set_id] = int(set_bonus_active.get(defn.set_id, 0)) + 1
	# Phase 3.20 — apply set bonuses based on how many pieces are worn.
	_apply_set_bonuses()
	# Phase 3.29 — fold reforge affixes from equipped items.
	_apply_reforge_affixes()
	# Phase 7 — fold talent-tree effects.
	_apply_talent_effects()
	# Apply to player components.
	_apply_to_player()
	stats_changed.emit()


## Phase 7.3-7.6 — pull each talent-tree effect into the cached stat fields.
func _apply_talent_effects() -> void:
	if not has_node(^"/root/TalentRegistry"):
		return
	crit_chance_bonus += TalentEffects.sum_value(&"skill_melee", &"crit_chance_flat")
	crit_damage_bonus += TalentEffects.sum_value(&"skill_melee", &"crit_damage_flat")
	lifesteal += TalentEffects.sum_value(&"skill_melee", &"lifesteal_flat")
	armor_bonus += int(round(TalentEffects.sum_value(&"skill_vitality", &"armor_flat")))
	thorns += int(round(TalentEffects.sum_value(&"skill_vitality", &"thorns_flat")))
	knockback_resistance_bonus += TalentEffects.sum_value(&"skill_vitality", &"knockback_resistance_flat")
	mana_regen_bonus += TalentEffects.sum_value(&"skill_magic", &"mana_regen_flat")
	max_hp_bonus += int(round(TalentEffects.sum_value(&"skill_vitality", &"max_hp_flat")))
	max_mana_bonus += int(round(TalentEffects.sum_value(&"skill_magic", &"mana_max_flat")))
	regen_per_second += TalentEffects.sum_value(&"skill_vitality", &"regen_per_second")
	# Mining speed picks up Stratabreaking talents on top of the Crafting bonus.
	mining_speed_bonus += TalentEffects.sum_value(&"skill_mining", &"mining_speed_pct")
	mining_speed_bonus += TalentEffects.sum_value(&"skill_crafting", &"mining_speed_pct")
	# Universal Luck stat from any tree that defines a `luck_flat` node.
	luck += TalentEffects.sum_global(&"luck_flat")
	# Aim cone reduction (multiplicative; clamp at 0).
	var cone_red: float = TalentEffects.sum_value(&"skill_ranged", &"aim_cone_reduction")
	aim_cone_degrees = maxf(0.0, aim_cone_degrees * (1.0 - clampf(cone_red, 0.0, 0.95)))


func _apply_reforge_affixes() -> void:
	var bonus: Dictionary = Reforge.equipped_bonus_sum()
	if bonus.is_empty():
		return
	armor_bonus += int(bonus.get("armor_value", 0))
	crit_chance_bonus += float(bonus.get("crit_chance_bonus", 0.0))
	crit_damage_bonus += float(bonus.get("crit_damage_bonus", 0.0))
	cooldown_reduction += float(bonus.get("cooldown_reduction", 0.0))
	luck += float(bonus.get("luck_bonus", 0.0))
	max_hp_bonus += int(bonus.get("max_hp_bonus", 0))


func _apply_set_bonuses() -> void:
	# Iterate every active set and apply a fixed bonus per piece count tier.
	# Set bonus values are defined per item type via SetBonuses.thresholds().
	for set_id in set_bonus_active.keys():
		var pieces: int = int(set_bonus_active[set_id])
		var bonus := SetBonuses.bonus_for(set_id, pieces)
		armor_bonus += int(bonus.get("armor", 0))
		crit_chance_bonus += float(bonus.get("crit_chance", 0.0))
		crit_damage_bonus += float(bonus.get("crit_damage", 0.0))
		max_hp_bonus += int(bonus.get("max_hp", 0))
		luck += float(bonus.get("luck", 0.0))


func _apply_to_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p := players[0]
	var hb := p.get_node_or_null("Hurtbox") as HurtboxComponent
	if hb:
		hb.thorns_damage = thorns
		hb.knockback_resistance = clampf(knockback_resistance_bonus, 0.0, 1.0)
	var hc := p.get_node_or_null("HealthComponent") as HealthComponent
	if hc:
		for k in resists.keys():
			hc.set_resistance(StringName(k), float(resists[k]))
		hc.bonus_max_health = max_hp_bonus
		hc.regen_per_second = regen_per_second
	var mc := p.get_node_or_null("ManaComponent") as ManaComponent
	if mc:
		mc.equipment_regen_bonus = mana_regen_bonus
		mc.bonus_max_mana = max_mana_bonus


# --- Aggregated reads (used by player_combat / projectiles / HUD) ------------

func crit_chance() -> float:
	return CombatMath.player_crit_chance() + crit_chance_bonus


func crit_bonus() -> float:
	return CombatMath.player_crit_bonus() + crit_damage_bonus


func armor_total() -> int:
	return armor_bonus


func lifesteal_fraction() -> float:
	return lifesteal


func manasteel_fraction() -> float:
	return manasteel


func thorns_damage() -> int:
	return thorns


func mining_speed_multiplier() -> float:
	# Talent-derived: +5% per allocated Crafting talent point. Add equipment bonus.
	var talent_pct: float = 0.05 * float(GameState.allocated_talents.get(&"skill_crafting", 0))
	return 1.0 + talent_pct + mining_speed_bonus


func cooldown_multiplier() -> float:
	return clampf(1.0 - cooldown_reduction, 0.25, 1.5)
