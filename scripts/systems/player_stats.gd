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
	if Inventory == null or ItemRegistry == null:
		stats_changed.emit()
		return
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
	# Apply to player components.
	_apply_to_player()
	stats_changed.emit()


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
	var mc := p.get_node_or_null("ManaComponent") as ManaComponent
	if mc:
		mc.equipment_regen_bonus = mana_regen_bonus


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
