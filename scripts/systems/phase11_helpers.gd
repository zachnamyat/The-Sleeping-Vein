extends Node

## Phase 11 — consolidated helpers autoload.
##
## Hosts the systems that cross-cut Phase 11 content:
##   11.4 — Heat-damage tick (Emberforge ambient heat the player accumulates)
##   11.5 — Cold-damage tick (Auroric Veil ambient cold)
##   11.6 — Day/night temperature swing on the Salt Wastes biome
##   11.7 — Heat-resistance + cold-resistance lookup (read from equipment)
##   11.8 — Pyrenkin forge sub-quest counters (relight 3 forges)
##   11.14 — Pyrenkin Compact NPC arrival hook (post-Skoldur)
##   11.15 — Frostlark three-part harmony tracker
##   11.17 — Heat-shimmer screen post-process toggle
##   11.18 — Frostbite buildup meter (cold zones accumulate to a freeze proc)
##   11.19 — Mirage / quicksand patch registry
##   11.24/11.31 — Walker journal + Forge-Compact tablet collection counters
##   11.27 — Hymnal Vault interaction state
##   11.29 — Wormbound silent-ritual gesture-input minigame state
##   11.30 — Veyl-Aurora pre-corruption chord audio toggle
##   11.32 — Cricket fuel-pellet collection counter (Pyrenkin Bellows fuel pool)
##   4.56/4.57/4.58 — Weather system (per-biome weather + gameplay effects + wind)
##
## All state is restorable via dump_state / restore_state.

signal heat_zone_changed(in_heat: bool)
signal cold_zone_changed(in_cold: bool)
signal frostbite_changed(level: float)
signal pyrenkin_forge_relit(forge_index: int)
signal weather_changed(biome_id: StringName, weather_id: StringName)
signal wormbound_gesture_progress(step: int, total: int)

# ---------------------------------------------------------------------------
# Tick cadence.
# ---------------------------------------------------------------------------
const ENV_TICK_SECONDS: float = 1.0
const HEAT_TICK_DAMAGE: int = 4
const COLD_TICK_DAMAGE: int = 5
const SALT_WASTES_DAY_DAMAGE: int = 2   ## 11.6 — fire dmg during day
const SALT_WASTES_NIGHT_DAMAGE: int = 2 ## 11.6 — cold dmg during night
const FROSTBITE_BUILD_PER_TICK: float = 0.08
const FROSTBITE_DECAY_PER_TICK: float = 0.04
const FROSTBITE_FREEZE_THRESHOLD: float = 1.0
const FROSTBITE_FREEZE_DURATION: float = 2.0

var _env_accum: float = 0.0
var _in_heat: bool = false
var _in_cold: bool = false
var frostbite_level: float = 0.0    # 0..1
var _last_frozen_at_seconds: float = -1000.0

# ---------------------------------------------------------------------------
# 11.8 — Pyrenkin forge sub-quest. Three forges have gone cold in the
# Emberforge over generations. Relight all three to trigger the Pyrenkin
# Compact NPC arrival (11.14) and unlock the Pyrenkin Bellows recipe.
# ---------------------------------------------------------------------------
const PYRENKIN_FORGES_TOTAL: int = 3
var pyrenkin_forges_relit: int = 0
var pyrenkin_compact_arrived: bool = false

# ---------------------------------------------------------------------------
# 11.15 — Frostlark three-part harmony. Three Frostlarks within radius =
# harmony unlock for the Hymnal Vault.
# ---------------------------------------------------------------------------
const FROSTLARK_HARMONY_RADIUS_PX: float = 64.0
const FROSTLARK_HARMONY_MIN_COUNT: int = 3
var frostlark_harmony_active: bool = false

# ---------------------------------------------------------------------------
# 11.19 — Mirage / quicksand patches. World gen registers positions inside
# the Salt Wastes; mirages slow + obscure, quicksand applies a slow + drag.
# ---------------------------------------------------------------------------
var mirage_patches: Array[Vector2] = []
var quicksand_patches: Array[Vector2] = []
const PATCH_RADIUS_PX: float = 32.0

# ---------------------------------------------------------------------------
# 11.24 + 11.31 — Tablet collections.
# ---------------------------------------------------------------------------
const EMBERFORGE_JOURNAL_TABLETS_TOTAL: int = 1
const FORGE_COMPACT_TABLETS_TOTAL: int = 5
var emberforge_journal_collected: bool = false
var forge_compact_tablets_collected: int = 0

# ---------------------------------------------------------------------------
# 11.27 — Hymnal Vault interaction. Player can play 3-note chords.
# Correct chord unlocks Frostlark harmony bonus.
# ---------------------------------------------------------------------------
const HYMNAL_CORRECT_CHORD: Array = [&"low", &"high", &"low"]
var hymnal_last_chord_played: Array = []
var hymnal_correct_chord_played: bool = false

# ---------------------------------------------------------------------------
# 11.29 — Wormbound silent-ritual gesture-input minigame.
# Sequence: three directional inputs (up / right / down) at the Wormbound
# threshold. Successful completion grants the Wormbound Covenant Scroll.
# ---------------------------------------------------------------------------
const WORMBOUND_RITUAL_SEQUENCE: Array = [&"up", &"right", &"down"]
var wormbound_gesture_index: int = 0
var wormbound_covenant_granted: bool = false

# ---------------------------------------------------------------------------
# 11.30 — Pre-corruption chord audio. Set when player chimes Cantor's bell.
# Veyl-Aurora boss reads `bool(GameState.collected_relics["cantor_bell_unlocked"])`
# directly; this autoload exposes the helper for symmetry.
# ---------------------------------------------------------------------------

func cantor_bell_unlocked() -> bool:
	return bool(GameState.collected_relics.get(&"cantor_bell_unlocked", false))


# ---------------------------------------------------------------------------
# 11.32 — Cricket fuel-pellet collection. Pyrenkin Bellows consumes one
# pellet per Aphelion phase while lit.
# ---------------------------------------------------------------------------
const BELLOWS_PELLET_PER_PHASE: int = 1
var bellows_lit_phases_remaining: int = 0

# ---------------------------------------------------------------------------
# 4.56/4.57/4.58 — Weather system. Per-biome weather rolled at biome enter
# and at every Aphelion Beat; effects fire each ENV tick while active.
# ---------------------------------------------------------------------------

const BIOME_WEATHERS: Dictionary = {
	&"sunless_verdancy": [&"clear", &"rain"],
	&"emberforge":       [&"clear", &"ash"],
	&"auroric_veil":     [&"clear", &"snow"],
	&"salt_wastes":      [&"clear", &"sandstorm"],
}
const BIOME_WIND: Dictionary = {
	&"root_hollows":     Vector2(0.05, 0.00),
	&"glasswright_reaches": Vector2(0.08, 0.04),
	&"vesari_necropolis":   Vector2(-0.06, 0.0),
	&"sunless_verdancy":    Vector2(0.04, 0.04),
	&"drowned_aphelion":    Vector2(0.0, 0.10),
	&"emberforge":          Vector2(0.10, -0.04),
	&"salt_wastes":         Vector2(0.18, 0.0),
	&"auroric_veil":        Vector2(-0.08, 0.06),
	&"final_spiral":        Vector2(0.0, 0.0),
}

var current_weather: StringName = &"clear"
var _weather_biome: StringName = &""


func _ready() -> void:
	if AudioBus:
		AudioBus.aphelion_beat.connect(_on_beat)
	if EventBus:
		EventBus.biome_changed.connect(_on_biome_changed)
	set_process(true)


func _process(delta: float) -> void:
	_env_accum += delta
	if _env_accum < ENV_TICK_SECONDS:
		return
	_env_accum = 0.0
	_tick_env()
	_tick_patches()
	_tick_frostlark_harmony()
	_tick_weather_effects()


# ---------------------------------------------------------------------------
# Environmental damage tick (11.4 / 11.5 / 11.6).
# ---------------------------------------------------------------------------
func _tick_env() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p := players[0] as Node2D
	if p == null:
		return
	var biome: BiomeDef = _biome_at(p.global_position)
	if biome == null:
		_set_heat(false)
		_set_cold(false)
		_decay_frostbite()
		return
	# Carry the chosen resist gear if any.
	var heat_resist: float = _heat_resist()
	var cold_resist: float = _cold_resist()
	var hc := p.get_node_or_null("HealthComponent") as HealthComponent
	if hc == null or hc.is_dead():
		return
	# Emberforge: heat (11.4).
	if biome.id == &"emberforge":
		_set_heat(true)
		_set_cold(false)
		_decay_frostbite()
		var dmg: int = HEAT_TICK_DAMAGE
		dmg = maxi(1, int(round(float(dmg) * (1.0 - heat_resist))))
		hc.apply_damage(dmg, null, &"fire")
		return
	# Auroric Veil: cold (11.5) + frostbite buildup (11.18).
	if biome.id == &"auroric_veil":
		_set_heat(false)
		_set_cold(true)
		var dmg: int = COLD_TICK_DAMAGE
		dmg = maxi(1, int(round(float(dmg) * (1.0 - cold_resist))))
		hc.apply_damage(dmg, null, &"cold")
		_build_frostbite(p)
		return
	# Salt Wastes: temperature swing (11.6) — fire-day, cold-night.
	if biome.id == &"salt_wastes":
		if AudioBus and AudioBus.is_day():
			_set_heat(true)
			_set_cold(false)
			var dmg: int = SALT_WASTES_DAY_DAMAGE
			dmg = maxi(1, int(round(float(dmg) * (1.0 - heat_resist))))
			hc.apply_damage(dmg, null, &"fire")
		else:
			_set_heat(false)
			_set_cold(true)
			var dmg: int = SALT_WASTES_NIGHT_DAMAGE
			dmg = maxi(1, int(round(float(dmg) * (1.0 - cold_resist))))
			hc.apply_damage(dmg, null, &"cold")
			_build_frostbite(p)
		return
	_set_heat(false)
	_set_cold(false)
	_decay_frostbite()


func _set_heat(on: bool) -> void:
	if on == _in_heat:
		return
	_in_heat = on
	heat_zone_changed.emit(_in_heat)


func _set_cold(on: bool) -> void:
	if on == _in_cold:
		return
	_in_cold = on
	cold_zone_changed.emit(_in_cold)


func _heat_resist() -> float:
	# 11.7 — heat resist comes from equipped armor's status_resists["fire"]
	# or held resist items (Skoldur's Hammer ×0.5). Cap at 0.95.
	var total: float = 0.0
	if Inventory.count_of(&"skoldurs_hammer") > 0:
		total += 0.5
	if Inventory.count_of(&"ember_iron_chestpiece") > 0:
		total += 0.4
	if Inventory.count_of(&"naerens_salt_crown") > 0:
		total += 0.2
	return clampf(total, 0.0, 0.95)


func _cold_resist() -> float:
	# 11.7 — cold resist from auroric chestpiece + Choir's Resonance.
	var total: float = 0.0
	if Inventory.count_of(&"auroric_ice_chestpiece") > 0:
		total += 0.5
	if Inventory.count_of(&"choirs_resonance") > 0:
		total += 0.25
	if Inventory.count_of(&"naerens_salt_crown") > 0:
		total += 0.2
	return clampf(total, 0.0, 0.95)


# ---------------------------------------------------------------------------
# 11.18 — Frostbite buildup. While the player is in a cold zone without
# enough resist, frostbite climbs; on cap, the player freezes for FREEZE seconds.
# ---------------------------------------------------------------------------
func _build_frostbite(player: Node2D) -> void:
	var cr: float = _cold_resist()
	# Cold-resist gates the BUILD step; >=0.5 stalls frostbite entirely.
	if cr >= 0.5:
		_decay_frostbite()
		return
	frostbite_level = clampf(frostbite_level + FROSTBITE_BUILD_PER_TICK * (1.0 - cr), 0.0, 1.0)
	frostbite_changed.emit(frostbite_level)
	if frostbite_level >= FROSTBITE_FREEZE_THRESHOLD:
		_trigger_freeze(player)


func _decay_frostbite() -> void:
	if frostbite_level <= 0.0:
		return
	frostbite_level = clampf(frostbite_level - FROSTBITE_DECAY_PER_TICK, 0.0, 1.0)
	frostbite_changed.emit(frostbite_level)


func _trigger_freeze(player: Node2D) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	# 8s cooldown so freeze doesn't strobe.
	if now - _last_frozen_at_seconds < 8.0:
		return
	_last_frozen_at_seconds = now
	frostbite_level = 0.0
	frostbite_changed.emit(frostbite_level)
	var se := player.get_node_or_null("StatusEffects") as StatusEffects
	if se:
		se.apply(&"freeze", FROSTBITE_FREEZE_DURATION, null, 1.0)
	EventBus.ui_toast.emit("You are frozen solid.", 2.0)


# ---------------------------------------------------------------------------
# 11.19 — Mirage / quicksand patch tick.
# ---------------------------------------------------------------------------
func register_mirage(world_pos: Vector2) -> void:
	if mirage_patches.size() >= 64:
		return
	mirage_patches.append(world_pos)


func register_quicksand(world_pos: Vector2) -> void:
	if quicksand_patches.size() >= 64:
		return
	quicksand_patches.append(world_pos)


func _tick_patches() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p := players[0] as Node2D
	if p == null:
		return
	# Mirages: passive flavor toast on first proximity (rotate per visit).
	for pos in mirage_patches:
		if p.global_position.distance_to(pos) <= PATCH_RADIUS_PX:
			# Cheap throttle — fire toast only if we haven't toasted within 6s.
			var now: float = Time.get_ticks_msec() / 1000.0
			if now - _last_mirage_toast_at >= 6.0:
				_last_mirage_toast_at = now
				EventBus.ui_toast.emit("A mirage shimmers ahead. The salt lies.", 2.5)
			break
	# Quicksand: apply slow + small damage on contact.
	for pos in quicksand_patches:
		if p.global_position.distance_to(pos) <= PATCH_RADIUS_PX:
			var se := p.get_node_or_null("StatusEffects") as StatusEffects
			if se:
				se.apply(&"slow", 1.0, null, 0.5)
			var hc := p.get_node_or_null("HealthComponent") as HealthComponent
			if hc and not hc.is_dead():
				hc.apply_damage(1, null, &"physical")
			break

var _last_mirage_toast_at: float = -999.0


# ---------------------------------------------------------------------------
# 11.15 — Frostlark three-part harmony.
# ---------------------------------------------------------------------------
func _tick_frostlark_harmony() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p := players[0] as Node2D
	if p == null:
		return
	var nearby: int = 0
	var tree := get_tree()
	if tree == null:
		return
	# Scan for any mob whose id is &"frostlark" within harmony radius.
	for m in tree.get_nodes_in_group("mob"):
		if not is_instance_valid(m):
			continue
		var def: MobDef = m.get("mob_def") as MobDef
		if def == null or def.id != &"frostlark":
			continue
		if (m as Node2D).global_position.distance_to(p.global_position) <= FROSTLARK_HARMONY_RADIUS_PX:
			nearby += 1
			if nearby >= FROSTLARK_HARMONY_MIN_COUNT:
				break
	var was_active: bool = frostlark_harmony_active
	frostlark_harmony_active = nearby >= FROSTLARK_HARMONY_MIN_COUNT
	if frostlark_harmony_active and not was_active:
		EventBus.ui_toast.emit("Three Frostlarks sing in harmony.", 3.0)
		if AudioBus:
			AudioBus.play_sfx(&"frostlark_harmony")


# ---------------------------------------------------------------------------
# 11.8 — Pyrenkin forge sub-quest (relight 3 forges).
# ---------------------------------------------------------------------------
func relight_pyrenkin_forge(index: int) -> bool:
	if index < 0 or index >= PYRENKIN_FORGES_TOTAL:
		return false
	if pyrenkin_forges_relit > index:
		return false   # already relit this one
	pyrenkin_forges_relit = maxi(pyrenkin_forges_relit, index + 1)
	pyrenkin_forge_relit.emit(index)
	EventBus.ui_toast.emit("Pyrenkin forge %d of %d catches." % [pyrenkin_forges_relit, PYRENKIN_FORGES_TOTAL], 3.0)
	if pyrenkin_forges_relit >= PYRENKIN_FORGES_TOTAL and not pyrenkin_compact_arrived:
		_trigger_pyrenkin_compact_arrival()
	return true


func _trigger_pyrenkin_compact_arrival() -> void:
	pyrenkin_compact_arrived = true
	EventBus.ui_toast.emit("Brindle: \"My people heard the forges from a stratum away.\"", 5.0)
	# Grant the pendant — Brindle hands it to the Walker before Skoldur.
	Inventory.try_add(&"pyrenkin_pendant", 1)
	EventBus.recipe_unlocked.emit(&"craft_pyrenkin_bellows")
	GameState.unlocked_recipes[&"craft_pyrenkin_bellows"] = true
	# Phase-9 NpcLifecycle friendship bump.
	if NpcLifecycle and NpcLifecycle.has_method("add_friendship"):
		NpcLifecycle.call("add_friendship", &"npc_brindle", 25)


# ---------------------------------------------------------------------------
# 11.24 / 11.31 — Tablet collection.
# ---------------------------------------------------------------------------
func collect_emberforge_journal() -> void:
	if emberforge_journal_collected:
		return
	emberforge_journal_collected = true
	GameState.unlocked_compendium[&"tablet_ef_09"] = true
	EventBus.ui_compendium_entry_unlocked.emit(&"tablet_ef_09")
	EventBus.ui_toast.emit("Walker's journal: 'I have not slept in 41 phases. Skoldur knows me.'", 5.0)


func collect_forge_compact_tablet() -> void:
	if forge_compact_tablets_collected >= FORGE_COMPACT_TABLETS_TOTAL:
		return
	forge_compact_tablets_collected += 1
	GameState.unlocked_compendium[StringName("tablet_forge_compact_%d" % forge_compact_tablets_collected)] = true
	EventBus.ui_compendium_entry_unlocked.emit(StringName("tablet_forge_compact_%d" % forge_compact_tablets_collected))
	EventBus.ui_toast.emit(
		"Forge-Compact tablet %d / %d collected." % [forge_compact_tablets_collected, FORGE_COMPACT_TABLETS_TOTAL],
		3.0,
	)
	if forge_compact_tablets_collected == FORGE_COMPACT_TABLETS_TOTAL:
		EventBus.ui_toast.emit("The Forge-Compact is whole. Pyrenkin trust deepens.", 4.0)
		if NpcLifecycle and NpcLifecycle.has_method("add_friendship"):
			NpcLifecycle.call("add_friendship", &"npc_brindle", 40)


# ---------------------------------------------------------------------------
# 11.27 — Hymnal Vault chord interaction.
# ---------------------------------------------------------------------------
func play_hymnal_note(note: StringName) -> void:
	hymnal_last_chord_played.append(note)
	if hymnal_last_chord_played.size() > HYMNAL_CORRECT_CHORD.size():
		hymnal_last_chord_played.pop_front()
	if hymnal_last_chord_played.size() == HYMNAL_CORRECT_CHORD.size():
		var ok: bool = true
		for i in range(HYMNAL_CORRECT_CHORD.size()):
			if hymnal_last_chord_played[i] != HYMNAL_CORRECT_CHORD[i]:
				ok = false
				break
		if ok and not hymnal_correct_chord_played:
			hymnal_correct_chord_played = true
			EventBus.ui_toast.emit("The Hymnal Vault opens a hidden auroric passage.", 4.0)
			GameState.collected_relics[&"hymnal_chord_played"] = true
			if AudioBus:
				AudioBus.play_sfx(&"hymnal_chord_resolve")


# ---------------------------------------------------------------------------
# 11.29 — Wormbound silent-ritual gesture minigame.
# ---------------------------------------------------------------------------
func wormbound_gesture(direction: StringName) -> bool:
	if wormbound_covenant_granted:
		return true
	var expected: StringName = WORMBOUND_RITUAL_SEQUENCE[wormbound_gesture_index]
	if direction != expected:
		wormbound_gesture_index = 0
		wormbound_gesture_progress.emit(0, WORMBOUND_RITUAL_SEQUENCE.size())
		EventBus.ui_toast.emit("The elder shakes their head. Start again.", 2.0)
		return false
	wormbound_gesture_index += 1
	wormbound_gesture_progress.emit(wormbound_gesture_index, WORMBOUND_RITUAL_SEQUENCE.size())
	if wormbound_gesture_index >= WORMBOUND_RITUAL_SEQUENCE.size():
		wormbound_covenant_granted = true
		Inventory.try_add(&"wormbound_covenant_scroll", 1)
		EventBus.ui_toast.emit("The Wormbound elder presses a sealed scroll into your hand.", 5.0)
		return true
	return true


# ---------------------------------------------------------------------------
# 11.32 — Pyrenkin Bellows fuel pool. Feed a pellet to extend lit phases.
# ---------------------------------------------------------------------------
func bellows_feed_pellet() -> bool:
	if Inventory.count_of(&"fuel_pellet") <= 0:
		EventBus.ui_toast.emit("No fuel-pellets in your pouch.", 2.0)
		return false
	Inventory.try_remove(&"fuel_pellet", 1)
	bellows_lit_phases_remaining += 4    # 4 Aphelion phases per pellet
	EventBus.ui_toast.emit("The Pyrenkin Bellows roars. (%d phases lit)" % bellows_lit_phases_remaining, 3.0)
	return true


func bellows_is_lit() -> bool:
	return bellows_lit_phases_remaining > 0


# ---------------------------------------------------------------------------
# 4.56/4.57/4.58 — Weather.
# ---------------------------------------------------------------------------
func _on_biome_changed(_old: StringName, new_biome: StringName) -> void:
	_weather_biome = new_biome
	_roll_weather()


func _on_beat() -> void:
	# Re-roll weather each Aphelion Beat.
	_roll_weather()
	# Consume bellows fuel per phase.
	if bellows_lit_phases_remaining > 0:
		bellows_lit_phases_remaining -= 1


func _roll_weather() -> void:
	if not BIOME_WEATHERS.has(_weather_biome):
		current_weather = &"clear"
		weather_changed.emit(_weather_biome, current_weather)
		return
	var options: Array = BIOME_WEATHERS[_weather_biome]
	var new_w: StringName = options[randi() % options.size()]
	if new_w != current_weather:
		current_weather = new_w
		weather_changed.emit(_weather_biome, current_weather)


func _tick_weather_effects() -> void:
	# 4.57 — gameplay effects:
	#   rain → extinguishes torches (lighting drop), ash → slows, snow → frostbite +20%,
	#   sandstorm → vision drop + small damage.
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p := players[0] as Node2D
	if p == null:
		return
	var hc := p.get_node_or_null("HealthComponent") as HealthComponent
	var se := p.get_node_or_null("StatusEffects") as StatusEffects
	match current_weather:
		&"rain":
			# Visual + soft mood. Damage handled elsewhere.
			pass
		&"ash":
			if se:
				se.apply(&"slow", 1.0, null, 0.8)
		&"snow":
			# Augment frostbite buildup.
			frostbite_level = clampf(frostbite_level + FROSTBITE_BUILD_PER_TICK * 0.3, 0.0, 1.0)
		&"sandstorm":
			if hc and not hc.is_dead():
				hc.apply_damage(1, null, &"physical")
			if se:
				se.apply(&"slow", 1.0, null, 0.85)


func wind_vector_for_biome(biome_id: StringName) -> Vector2:
	return BIOME_WIND.get(biome_id, Vector2.ZERO)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _biome_at(world_pos: Vector2) -> BiomeDef:
	var wg: Node = get_tree().current_scene.get_node_or_null("WorldGen") if get_tree().current_scene else null
	if wg == null or not wg.has_method("biome_at"):
		return null
	return wg.call("biome_at", world_pos) as BiomeDef


# ---------------------------------------------------------------------------
# Persistence.
# ---------------------------------------------------------------------------
func dump_state() -> Dictionary:
	return {
		"pyrenkin_forges_relit": pyrenkin_forges_relit,
		"pyrenkin_compact_arrived": pyrenkin_compact_arrived,
		"frostbite_level": frostbite_level,
		"emberforge_journal_collected": emberforge_journal_collected,
		"forge_compact_tablets_collected": forge_compact_tablets_collected,
		"wormbound_gesture_index": wormbound_gesture_index,
		"wormbound_covenant_granted": wormbound_covenant_granted,
		"hymnal_correct_chord_played": hymnal_correct_chord_played,
		"bellows_lit_phases_remaining": bellows_lit_phases_remaining,
		"current_weather": String(current_weather),
		"weather_biome": String(_weather_biome),
	}


func restore_state(d: Dictionary) -> void:
	pyrenkin_forges_relit = int(d.get("pyrenkin_forges_relit", 0))
	pyrenkin_compact_arrived = bool(d.get("pyrenkin_compact_arrived", false))
	frostbite_level = float(d.get("frostbite_level", 0.0))
	emberforge_journal_collected = bool(d.get("emberforge_journal_collected", false))
	forge_compact_tablets_collected = int(d.get("forge_compact_tablets_collected", 0))
	wormbound_gesture_index = int(d.get("wormbound_gesture_index", 0))
	wormbound_covenant_granted = bool(d.get("wormbound_covenant_granted", false))
	hymnal_correct_chord_played = bool(d.get("hymnal_correct_chord_played", false))
	bellows_lit_phases_remaining = int(d.get("bellows_lit_phases_remaining", 0))
	current_weather = StringName(String(d.get("current_weather", "clear")))
	_weather_biome = StringName(String(d.get("weather_biome", "")))
