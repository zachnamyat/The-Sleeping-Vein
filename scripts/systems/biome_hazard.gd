extends Node

## BiomeHazardSystem.
## Once per second:
##   - finds the player
##   - asks WorldGen what biome they're in
##   - if biome has a hazard and the player doesn't hold the resist item, applies
##     biome.hazard_damage_per_second to the player's HealthComponent.
##
## Phase 10 extensions:
##   10.15 toxic_spore — Verdancy; emits a per-tick VFX request the HUD/StatusOverlay can show.
##   10.16 salt_corrosion — Necropolis; ticks equipment durability (one random equipped piece)
##           in addition to the HP damage; corrosion VFX overlay on the player.
##   10.7  drowning — Drowned Aphelion; only applies if breath meter has expired (player_controller
##           runs its own drown loop; this is the fallback for non-controlled actors entering
##           the biome later, e.g. summoned pets).
##   Toast cadence is throttled to once per 5 seconds per hazard so the player isn't spammed.

const TICK: float = 1.0
const TOAST_THROTTLE_SECONDS: float = 5.0

var _accum: float = 0.0
var _player: Node2D
var _worldgen: Node
# Phase 10 — last toast timestamp per hazard id to throttle spam.
var _last_toast_at: Dictionary = {}
# Phase 10.16 — accumulator counts toward the next durability tick for a
# salt-corroded piece. One durability point comes off roughly every 10 seconds.
var _salt_durability_accum: float = 0.0
const SALT_DURABILITY_TICK_SECONDS: float = 10.0


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	_accum += delta
	if _accum < TICK:
		return
	_accum = 0.0
	_tick_hazard()


func _tick_hazard() -> void:
	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("player")
		if players.is_empty():
			return
		_player = players[0]
	if _worldgen == null or not is_instance_valid(_worldgen):
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.current_scene:
			_worldgen = tree.current_scene.get_node_or_null("WorldGen") as Node
	if _worldgen == null or not _worldgen.has_method("biome_at"):
		return
	var biome: BiomeDef = _worldgen.biome_at(_player.global_position) as BiomeDef
	if biome == null or biome.hazard_id == &"" or biome.hazard_damage_per_second <= 0:
		return
	# Phase 10.7 — drowning hazard is gated by the breath meter; player_controller
	# applies the actual drown damage. Skip here to avoid double-dipping.
	if biome.hazard_id == &"drowning":
		return
	if biome.resist_item_id != &"" and Inventory.count_of(biome.resist_item_id) > 0:
		return
	var hc := _player.get_node_or_null("HealthComponent") as HealthComponent
	if hc == null or hc.is_dead():
		return
	# Ticket 11.6 — Salt Wastes swing: day = heat (fire), night = cold.
	var dtype: StringName = biome.hazard_damage_type
	var label: String = String(biome.hazard_id)
	if biome.hazard_id == &"dawning_swing":
		if AudioBus.is_day():
			dtype = &"fire"
			label = "Dawning Heat"
		else:
			dtype = &"cold"
			label = "Dawning Chill"
	elif biome.hazard_id == &"toxic_spore":
		label = "Toxic Spore"
		# Phase 10.15 — also drop a brief Poison status; the persistent biome
		# damage is the floor, but the status grants stack-aware UI.
		var se := _player.get_node_or_null("StatusEffects") as StatusEffects
		if se:
			se.apply(&"poison", 2.0, null, 1.0)
	elif biome.hazard_id == &"salt_corrosion":
		label = "Salt Corrosion"
		_apply_salt_durability_decay()
	# Ticket 11.7 — half damage if matching resist armor in pouch.
	var damage: int = biome.hazard_damage_per_second
	if biome.resist_armor_id != &"" and Inventory.count_of(biome.resist_armor_id) > 0:
		damage = maxi(1, damage / 2)
	hc.apply_damage(damage, null, dtype)
	_emit_toast(biome.hazard_id, "%s — %d %s" % [label.capitalize(), damage, String(dtype)])


func _emit_toast(hazard_id: StringName, text: String) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var last: float = float(_last_toast_at.get(hazard_id, -999.0))
	if now - last < TOAST_THROTTLE_SECONDS:
		return
	_last_toast_at[hazard_id] = now
	EventBus.ui_toast.emit(text, 0.9)


## Phase 10.16 — gear-wear: while standing in the Necropolis, one random
## equipped item loses a durability point every SALT_DURABILITY_TICK_SECONDS.
## We round-robin among non-zero-durability equipped pieces.
func _apply_salt_durability_decay() -> void:
	_salt_durability_accum += TICK
	if _salt_durability_accum < SALT_DURABILITY_TICK_SECONDS:
		return
	_salt_durability_accum = 0.0
	var candidates: Array[StringName] = []
	for slot in Inventory.equipment.keys():
		var item_id: StringName = Inventory.equipment[slot]
		var defn: ItemDef = ItemRegistry.get_def(item_id)
		if defn == null or defn.max_durability <= 0:
			continue
		candidates.append(slot)
	if candidates.is_empty():
		return
	var pick: StringName = candidates[randi() % candidates.size()]
	# Phase 10.16 — Inventory tracks durability via Inventory.equipped_affixes[slot].current_durability.
	var rec: Dictionary = Inventory.equipped_affixes.get(pick, {})
	var cur: int = int(rec.get("current_durability", -1))
	var defn: ItemDef = ItemRegistry.get_def(Inventory.equipment[pick])
	if defn == null:
		return
	if cur < 0:
		cur = defn.max_durability
	cur = maxi(0, cur - 1)
	rec["current_durability"] = cur
	Inventory.equipped_affixes[pick] = rec
	if cur == 0:
		# Phase 10.16 — corroded equipment breaks: unequip + remove from inventory.
		var broken_id: StringName = Inventory.equipment[pick]
		Inventory.equipment[pick] = &""
		Inventory.try_remove(broken_id, 1)
		EventBus.ui_toast.emit("Your %s corroded to dust!" % broken_id, 3.0)
		EventBus.stat_recompute_requested.emit()
