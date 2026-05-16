extends Node

## Phase 12 — consolidated helpers autoload.
##
## Hosts the cross-cutting systems for the endgame Final Spiral + the three
## endings:
##   12.3  — Mote Tide event (swarm-spawn of Pure Hollowling Motes)
##   12.4  — Vacancy follower state (silent follower; appears once)
##   12.5  — Elision-Script puzzle progress (collected fragments)
##   12.6  — Diadem manifestos read tracker (8 inscriptions along the descent)
##   12.7  — Resonance Loom's Twin discovered flag
##   12.11 — Ending C unlock-condition validator
##   12.14 — Manifesto reader unlocked-tab tracker
##   12.15 — Ending-taken per save slot (also persisted in unlocked_compendium)
##   12.16 — Final-Spiral hostile density curve (depth-based modifier)
##   12.17 — Three-doors path choice locked-in flag
##   12.18 — Validator entries for Ending C
##   12.19 — Aphelion-shard reagent stockpile counter (cosmetic; inventory is truth)
##   12.21 — Material conversion success counter (telemetry)
##   12.22 — Aphelion-Beat synchronised wave spawn timer
##   12.24 — "Lamp before the lamp" tablet reveal
##   12.25 — Footstep echo shader gating flag
##   12.26 — Diadem-Bearer self-shatter event flag
##   12.27 — Aphelion translated apology phrase reveal
##   12.28 — Listener-Below mask-reveal completed flag
##   12.29 — Vacancy final-corridor encounter completed
##   12.30 — Elided name spelling progress (4 syllables of Vael-Iorrion)
##   12.31 — Final-act NPC commentary already-spoken set
##   12.32 — Bearer pre-Diadem child memory tablet read
##   12.33 — Compendium completion reward granted
##   12.34 — Cross-ending shared-world flag
##   12.35 — Sovereign-Naming progress preview cached
##   12.36 — Joren-of-the-Lattice signed-name revealed
##   12.37 — Mira-Bearer sibling-thread post-fight scene played
##   12.38 — Walker silent-emote per-ending played flag

signal mote_tide_started
signal mote_tide_ended
signal vacancy_appeared
signal manifesto_read(index: int)
signal elision_fragment_collected(count: int, total: int)
signal ending_committed(ending_id: StringName)
signal aphelion_apology_revealed
signal listener_mask_revealed
signal elided_name_progress(filled: int, total: int)


# ---------------------------------------------------------------------------
# 12.3 — Mote Tide event. Triggered roughly every 6 Aphelion Beats while the
# player is inside the Final Spiral; spawns 8 Pure Hollowling Motes around
# the player; resolves on kill-all or after MOTE_TIDE_DURATION.
# ---------------------------------------------------------------------------
const MOTE_TIDE_COOLDOWN_BEATS: int = 6
const MOTE_TIDE_SWARM_SIZE: int = 8
const MOTE_TIDE_DURATION: float = 24.0

var mote_tide_active: bool = false
var _beats_since_last_tide: int = 0
var _tide_accum: float = 0.0


# ---------------------------------------------------------------------------
# 12.4 + 12.29 — Vacancy creature follower. Appears once, in the final
# corridor, follows the player silently, cannot reliably be attacked, never
# harms the player. The encounter is "completed" when the player passes the
# last manifesto OR engages the Diadem-Bearer.
# ---------------------------------------------------------------------------
var vacancy_appeared_flag: bool = false
var vacancy_encounter_completed: bool = false


# ---------------------------------------------------------------------------
# 12.5 + 12.30 — Elision-Script puzzle. The Walker collects 4 fragments
# scattered across the Final Spiral; each unscratched portion reveals one
# syllable of the elided figure's name: VAEL · IOR · RI · ON.
# ---------------------------------------------------------------------------
const ELISION_SYLLABLES: Array = [&"VAEL", &"IOR", &"RI", &"ON"]
const ELISION_TOTAL: int = 4

var elision_fragments_collected: int = 0
var elided_name_revealed: bool = false


# ---------------------------------------------------------------------------
# 12.6 + 12.14 — Manifesto corridor. 8 illuminated wall texts. Reading the
# final one (signed in Joren-of-the-Lattice) unlocks the Diadem-Bearer
# antechamber.
# ---------------------------------------------------------------------------
const MANIFESTO_TOTAL: int = 8
var manifestos_read: Dictionary = {}   # int index -> bool


# ---------------------------------------------------------------------------
# 12.7 — Resonance Loom's Twin discovery. Set when the player interacts with
# LoomTwin in the Final Spiral; reveals the foreshadowing of Ending C.
# ---------------------------------------------------------------------------
var loom_twin_discovered: bool = false


# ---------------------------------------------------------------------------
# 12.9-12.11 + 12.15 + 12.34 — Endings.
# Selected_ending is the ending the *current run* committed to. shared_world
# state means the next NG+ run sees the carved choice in the Aphelion chamber.
# ---------------------------------------------------------------------------
const ENDING_RESTORE: StringName = &"ending_restore"
const ENDING_BREAK: StringName = &"ending_break"
const ENDING_BECOME: StringName = &"ending_become"

var selected_ending: StringName = &""
var endings_taken_history: Array[StringName] = []   # 12.15
var aphelion_chamber_path_locked_in: bool = false   # 12.17


# ---------------------------------------------------------------------------
# 12.11 + 12.18 — Ending C unlock validator. All conditions must be true:
#   - 9 Sovereign threads accumulated
#   - Wormbound peace (collected_relics["naeren_peace"] OR covenant scroll held)
#   - Vol'thaar release (collected_relics["volthaar_promise"])
#   - Sythrenn mercy-kill (collected_relics["sythrenn_mercy"])
#   - Elided name revealed (12.30)
#   - Loom's Twin discovered (12.7)
# ---------------------------------------------------------------------------
const ENDING_C_REQUIRED_THREADS: int = 9


func ending_c_unlock_breakdown() -> Dictionary:
	# Returns a Dictionary describing each requirement and its current truth value.
	var breakdown: Dictionary = {}
	breakdown[&"threads"] = {
		"label": "9 Sovereign threads gathered (%d/9)" % GameState.sovereign_threads,
		"met": GameState.sovereign_threads >= ENDING_C_REQUIRED_THREADS,
	}
	breakdown[&"wormbound_peace"] = {
		"label": "Wormbound peace path completed",
		"met": bool(GameState.collected_relics.get(&"naeren_peace", false)) or Inventory.count_of(&"wormbound_covenant_scroll") > 0,
	}
	breakdown[&"volthaar_release"] = {
		"label": "Vol'thaar's Promise honoured",
		"met": Inventory.count_of(&"volthaar_promise") > 0 or bool(GameState.collected_relics.get(&"volthaar_released", false)),
	}
	breakdown[&"sythrenn_mercy"] = {
		"label": "Sythrenn mercy-kill performed",
		"met": bool(GameState.collected_relics.get(&"sythrenn_mercy", false)) or Inventory.count_of(&"sythrenn_last_petal") > 0,
	}
	breakdown[&"elided_name"] = {
		"label": "The elided name pieced together",
		"met": elided_name_revealed,
	}
	breakdown[&"loom_twin"] = {
		"label": "The Resonance Loom's Twin discovered",
		"met": loom_twin_discovered,
	}
	return breakdown


func ending_c_unlocked() -> bool:
	for key in ending_c_unlock_breakdown().keys():
		if not ending_c_unlock_breakdown()[key]["met"]:
			return false
	return true


# ---------------------------------------------------------------------------
# 12.16 — Final-Spiral hostile density curve. As the player descends deeper
# into the spiral (lower stratum, farther from Anchor) the spawn budget per
# chunk increases. The world_gen reads this multiplier when populating chunks.
# ---------------------------------------------------------------------------
const DENSITY_BASE: float = 1.0
const DENSITY_PER_RING: float = 0.25
const DENSITY_MAX: float = 3.0


func density_multiplier_for_distance(distance_tiles: float) -> float:
	# 12.16 — multiplier grows linearly past 640t (Final Spiral edge) capped at 3x.
	if distance_tiles < 640.0:
		return DENSITY_BASE
	var rings: float = (distance_tiles - 640.0) / 16.0
	return clampf(DENSITY_BASE + rings * DENSITY_PER_RING, 1.0, DENSITY_MAX)


# ---------------------------------------------------------------------------
# 12.19 + 12.20 + 12.21 — Aphelion-shard reagent & Reliquary station.
# The Diadem Reliquary converts lower-tier ores into higher-tier ones at a
# 4:1 ratio with one Aphelion shard as a catalyst. Tracker is for telemetry;
# inventory is the truth-source.
# ---------------------------------------------------------------------------
const RELIQUARY_CONVERSION_RATIO: int = 4
const RELIQUARY_CATALYST_ID: StringName = &"aphelion_shard"

var reliquary_conversions_performed: int = 0


func can_reliquary_convert(lower_id: StringName, count: int) -> bool:
	if Inventory.count_of(lower_id) < count * RELIQUARY_CONVERSION_RATIO:
		return false
	if Inventory.count_of(RELIQUARY_CATALYST_ID) < 1:
		return false
	return true


func reliquary_convert(lower_id: StringName, higher_id: StringName, batches: int = 1) -> int:
	# Returns the number of higher_id units produced.
	var produced: int = 0
	for _i in range(batches):
		if not can_reliquary_convert(lower_id, 1):
			break
		Inventory.try_remove(lower_id, RELIQUARY_CONVERSION_RATIO)
		Inventory.try_remove(RELIQUARY_CATALYST_ID, 1)
		Inventory.try_add(higher_id, 1)
		produced += 1
		reliquary_conversions_performed += 1
	return produced


# ---------------------------------------------------------------------------
# 12.22 — Aphelion-Beat-synchronised wave spawn. Every other Aphelion Beat
# inside the Final Spiral fires a wave of 3-4 mobs around the player.
# ---------------------------------------------------------------------------
const WAVE_BEAT_INTERVAL: int = 2
const WAVE_MIN_SIZE: int = 3
const WAVE_MAX_SIZE: int = 4

var _wave_beats: int = 0
var wave_spawn_total: int = 0


# ---------------------------------------------------------------------------
# 12.24 — "Lamp before the lamp" tablet. Reveals the Aphelion was preceded
# by an earlier intelligence; surfaced in Hall of First Names when conditions
# (12.18 elided name) are met.
# ---------------------------------------------------------------------------
var lamp_before_lamp_revealed: bool = false


# ---------------------------------------------------------------------------
# 12.25 — Footstep-echo shader. The Final Spiral plays the player's footsteps
# with an abnormal delay & pitch shift. Audio-bus reads `footstep_echo_active`.
# ---------------------------------------------------------------------------
var footstep_echo_active: bool = false


# ---------------------------------------------------------------------------
# 12.26 — Diadem-Bearer self-shatter cinematic flag. Locked-in once the boss
# enters phase 4 and the no-player-strike rule fires.
# ---------------------------------------------------------------------------
var bearer_self_shatter_played: bool = false


# ---------------------------------------------------------------------------
# 12.27 — Aphelion translated-apology phrase. Revealed only on Ending B (Break)
# resolution. The phrase is "I am sorry. I tried."
# ---------------------------------------------------------------------------
const APHELION_APOLOGY_PHRASE: String = "I am sorry. I tried."
var aphelion_apology_revealed_flag: bool = false


# ---------------------------------------------------------------------------
# 12.28 — Listeners-Below mask reveal. Second Listener in the Final Spiral
# removes their mask; their face is the Walker's. Flagged once per save slot.
# ---------------------------------------------------------------------------
var listener_mask_revealed_flag: bool = false


# ---------------------------------------------------------------------------
# 12.31 — Final-act NPC commentary. As the Aphelion dims (Final Spiral
# slivers < 1000), Aelstren / Brindle / Mira / Cantor each broadcast one
# unique line. The set tracks which lines have already fired so they don't
# repeat.
# ---------------------------------------------------------------------------
var final_act_commentary_spoken: Dictionary = {}   # npc_id -> bool


# ---------------------------------------------------------------------------
# 12.32 — Bearer pre-Diadem child memory tablet (RH-08 equivalent). Reading
# unlocks the second-half of 12.36 (Joren-of-the-Lattice name reveal).
# ---------------------------------------------------------------------------
var bearer_child_tablet_read: bool = false


# ---------------------------------------------------------------------------
# 12.33 — Endgame compendium completion reward. When all bestiary / tablets /
# titles entries are unlocked, the Cantor of Five Bells grants the
# Cantor's Compass (lore/05 sidequest).
# ---------------------------------------------------------------------------
var compendium_reward_granted: bool = false


# ---------------------------------------------------------------------------
# 12.34 — Multi-ending shared world. NG+ runs see a small "carved" mural in
# the Aphelion chamber showing which endings have already been taken.
# ---------------------------------------------------------------------------
func carved_endings() -> Array[StringName]:
	return endings_taken_history.duplicate()


# ---------------------------------------------------------------------------
# 12.35 — Sovereign-Naming progress preview. Cached fragment count, surfaced
# in the EndingsPanel for transparency.
# ---------------------------------------------------------------------------
func sovereign_naming_preview() -> Dictionary:
	return {
		"fragments_held": GameState.sovereign_threads,
		"fragments_needed": 9,
		"cantor_compass_unlocked": bool(GameState.collected_relics.get(&"cantor_compass", false)),
	}


# ---------------------------------------------------------------------------
# 12.36 — Joren-of-the-Lattice reveal. The Bearer's pre-Diadem name is
# Joren-of-the-Lattice; surfaced on the final manifesto + at the 5%-HP
# kneel cinematic if 12.32 has been read.
# ---------------------------------------------------------------------------
const BEARER_PRE_DIADEM_NAME: String = "Joren-of-the-Lattice"
var joren_name_revealed: bool = false


# ---------------------------------------------------------------------------
# 12.37 — Mira-Bearer sibling thread. If Mira friendship >= 80 AND Bearer
# fight is won AND 12.32 + 12.36 are revealed, plays a post-fight scene at
# the Anchor where Mira finds the diadem and weeps. One-shot flag.
# ---------------------------------------------------------------------------
var mira_sibling_scene_played: bool = false


# ---------------------------------------------------------------------------
# 12.38 — Walker silent epilogue emote (one per ending).
# ---------------------------------------------------------------------------
var walker_epilogue_emote_played: bool = false


# ===========================================================================
# Lifecycle.
# ===========================================================================

const FINAL_ACT_SLIVER_THRESHOLD: int = 1000

var _final_act_fired: bool = false

const FINAL_ACT_NPC_LINES: Dictionary = {
	&"npc_aelstren": "Aelstren: \"The mapfolds are flickering. The Aphelion is forgetting how to be solid.\"",
	&"npc_brindle":  "Brindle: \"Forge runs hotter than it should. I keep cooling it. It keeps lighting itself.\"",
	&"npc_mira":     "Mira: \"I dreamed about my brother again. He was wearing gold. He was smiling. I don't want to go back to sleep.\"",
	&"npc_cantor":   "The Cantor: \"The fifth bell is breaking by itself. I don't ring it. It rings.\"",
	&"npc_hask":     "Hask: \"The deep nets are coming back full of teeth. We're past the worst of it now. Or we're entering it.\"",
}


func _ready() -> void:
	if AudioBus:
		AudioBus.aphelion_beat.connect(_on_beat)
	if EventBus:
		EventBus.boss_defeated.connect(_on_boss_defeated)
		EventBus.aphelion_dimmed.connect(_on_aphelion_dimmed)
		EventBus.ui_compendium_entry_unlocked.connect(_on_compendium_unlocked)
	set_process(true)


func _on_compendium_unlocked(_entry_id: StringName) -> void:
	# 12.33 — try to grant the Cantor's Compass when the compendium fills up.
	try_grant_compendium_reward()


func _on_aphelion_dimmed(slivers_remaining: int) -> void:
	# 12.31 — once slivers drop under the threshold, fire each NPC's unique
	# final-act commentary line (one per NPC, persisted).
	if _final_act_fired:
		return
	if slivers_remaining > FINAL_ACT_SLIVER_THRESHOLD:
		return
	_final_act_fired = true
	var delay: float = 1.0
	for npc_id in FINAL_ACT_NPC_LINES.keys():
		if not GameState.arrived_npcs.get(npc_id, false):
			continue
		var line: String = FINAL_ACT_NPC_LINES[npc_id]
		var local_id: StringName = npc_id
		var local_line: String = line
		var t := get_tree().create_timer(delay)
		t.timeout.connect(func() -> void:
			try_speak_final_act_line(local_id, local_line)
		)
		delay += 2.5


func _process(delta: float) -> void:
	if mote_tide_active:
		_tide_accum += delta
		if _tide_accum >= MOTE_TIDE_DURATION:
			end_mote_tide()


# Each Aphelion Beat: increment counters + potentially trigger a wave or tide.
func _on_beat() -> void:
	_beats_since_last_tide += 1
	_wave_beats += 1
	# 12.3 — every 6th Beat, attempt a Mote Tide.
	if _beats_since_last_tide >= MOTE_TIDE_COOLDOWN_BEATS:
		if _player_in_final_spiral():
			start_mote_tide()
		_beats_since_last_tide = 0
	# 12.22 — every 2nd Beat, fire a wave of Diadem agents around the player.
	if _wave_beats >= WAVE_BEAT_INTERVAL:
		_wave_beats = 0
		if _player_in_final_spiral():
			_spawn_diadem_wave()


func _on_boss_defeated(boss_id: StringName) -> void:
	if boss_id == &"boss_diadem_bearer":
		bearer_self_shatter_played = true
	elif boss_id == &"boss_aphelion":
		reveal_aphelion_apology()


## Spawn a 3-4 mob wave around the player. Pulled from the Final Spiral
## mob_spawn_table; the Diadem-Bearer's adds (Readers / Censers / Wardens)
## are the typical choices, but a Pure Hollowling Mote can sneak in too.
func _spawn_diadem_wave() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p := players[0] as Node2D
	if p == null:
		return
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var entities: Node = current_scene.get_node_or_null("WorldGen/YSortRoot/Entities")
	if entities == null:
		entities = current_scene
	var pool: Array[StringName] = [&"diadem_reader", &"diadem_censer", &"diadem_warden", &"pure_hollowling_mote"]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count: int = rng.randi_range(WAVE_MIN_SIZE, WAVE_MAX_SIZE)
	for i in range(count):
		var angle: float = TAU * float(i) / float(count) + rng.randf() * 0.6
		var dist: float = 96.0 + rng.randf() * 48.0
		var pos: Vector2 = p.global_position + Vector2(cos(angle), sin(angle)) * dist
		var mob_id: StringName = pool[rng.randi() % pool.size()]
		var mob: Node2D = _spawn_one_mob(mob_id, pos)
		if mob != null:
			entities.add_child(mob)
	wave_spawn_total += 1


func _spawn_one_mob(mob_id: StringName, pos: Vector2) -> Node2D:
	var def: MobDef = load("res://resources/mobs/" + String(mob_id) + ".tres") as MobDef
	if def == null:
		return null
	var scn := load("res://scenes/enemies/phase10_mob.tscn") as PackedScene
	if scn == null:
		return null
	var instance: Mob = scn.instantiate() as Mob
	if instance == null:
		return null
	instance.mob_def = def
	instance.position = pos
	return instance


# ===========================================================================
# 12.3 — Mote Tide event API.
# ===========================================================================
func start_mote_tide() -> void:
	if mote_tide_active:
		return
	mote_tide_active = true
	_tide_accum = 0.0
	EventBus.ui_toast.emit("Mote Tide rising — the light churns.", 3.0)
	if AudioBus:
		AudioBus.play_sfx(&"mote_tide_start")
	# Spawn the swarm of Pure Hollowling Motes around the player.
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p := players[0] as Node2D
		var entities: Node = get_tree().current_scene.get_node_or_null("WorldGen/YSortRoot/Entities") if get_tree().current_scene else null
		if entities == null:
			entities = get_tree().current_scene
		for i in range(MOTE_TIDE_SWARM_SIZE):
			var angle: float = TAU * float(i) / float(MOTE_TIDE_SWARM_SIZE)
			var dist: float = 120.0 + randf() * 32.0
			var pos: Vector2 = p.global_position + Vector2(cos(angle), sin(angle)) * dist
			var mob: Node2D = _spawn_one_mob(&"pure_hollowling_mote", pos)
			if mob != null:
				entities.add_child(mob)
	mote_tide_started.emit()


func end_mote_tide() -> void:
	if not mote_tide_active:
		return
	mote_tide_active = false
	_tide_accum = 0.0
	mote_tide_ended.emit()


# ===========================================================================
# 12.4 / 12.29 — Vacancy follower.
# ===========================================================================
func make_vacancy_appear() -> void:
	if vacancy_appeared_flag:
		return
	vacancy_appeared_flag = true
	vacancy_appeared.emit()
	EventBus.ui_toast.emit("Something silent walks beside you.", 4.0)


func complete_vacancy_encounter() -> void:
	if vacancy_encounter_completed:
		return
	vacancy_encounter_completed = true
	GameState.collected_relics[&"vacancy_encounter"] = true


# ===========================================================================
# 12.5 / 12.30 — Elision-Script puzzle.
# ===========================================================================
func collect_elision_fragment() -> void:
	if elided_name_revealed:
		return
	elision_fragments_collected = mini(elision_fragments_collected + 1, ELISION_TOTAL)
	elision_fragment_collected.emit(elision_fragments_collected, ELISION_TOTAL)
	elided_name_progress.emit(elision_fragments_collected, ELISION_TOTAL)
	if elision_fragments_collected >= ELISION_TOTAL:
		_reveal_elided_name()


func _reveal_elided_name() -> void:
	elided_name_revealed = true
	GameState.collected_relics[&"elided_name"] = true
	EventBus.ui_toast.emit("The name forms: " + elided_name_string(), 6.0)
	if AudioBus:
		AudioBus.play_sfx(&"elision_revealed")
	if Compendium and Compendium.has_method("unlock"):
		Compendium.unlock(&"elided_name_vael_iorrion")


func elided_name_string() -> String:
	# Returns "VAEL-IOR-RI-ON" until all four are gathered, hyphenating empties.
	var parts: Array = []
	for i in range(ELISION_TOTAL):
		if i < elision_fragments_collected:
			parts.append(String(ELISION_SYLLABLES[i]))
		else:
			parts.append("___")
	return "-".join(parts)


# ===========================================================================
# 12.6 / 12.14 — Manifestos.
# ===========================================================================
func mark_manifesto_read(index: int) -> void:
	if index < 0 or index >= MANIFESTO_TOTAL:
		return
	if manifestos_read.get(index, false):
		return
	manifestos_read[index] = true
	manifesto_read.emit(index)
	# 12.36 — final manifesto reveals Joren-of-the-Lattice if the child tablet is read.
	if index == MANIFESTO_TOTAL - 1 and bearer_child_tablet_read:
		reveal_joren_name()


func manifestos_read_count() -> int:
	return manifestos_read.size()


func all_manifestos_read() -> bool:
	return manifestos_read_count() >= MANIFESTO_TOTAL


# ===========================================================================
# 12.7 — Loom's Twin.
# ===========================================================================
func discover_loom_twin() -> void:
	if loom_twin_discovered:
		return
	loom_twin_discovered = true
	GameState.collected_relics[&"loom_twin"] = true
	EventBus.ui_toast.emit("A second Loom — broken. Pre-Inversion construction.", 5.0)
	if Compendium and Compendium.has_method("unlock"):
		Compendium.unlock(&"loom_twin_discovery")


# ===========================================================================
# 12.9-12.11 / 12.15 / 12.17 / 12.34 — Endings.
# ===========================================================================
func commit_ending(ending_id: StringName) -> bool:
	if aphelion_chamber_path_locked_in:
		return false
	if ending_id == ENDING_BECOME and not ending_c_unlocked():
		EventBus.ui_toast.emit("The Aphelion's gold path refuses you. Conditions unmet.", 4.0)
		return false
	selected_ending = ending_id
	aphelion_chamber_path_locked_in = true
	GameState.unlocked_compendium[ending_id] = true
	if not endings_taken_history.has(ending_id):
		endings_taken_history.append(ending_id)
	ending_committed.emit(ending_id)
	return true


func has_taken_ending(ending_id: StringName) -> bool:
	return endings_taken_history.has(ending_id)


# ===========================================================================
# 12.24 — Lamp before the lamp.
# ===========================================================================
func reveal_lamp_before_lamp() -> void:
	if lamp_before_lamp_revealed:
		return
	lamp_before_lamp_revealed = true
	GameState.collected_relics[&"lamp_before_lamp"] = true
	EventBus.ui_toast.emit("\"A lamp before the lamp.\" Before the Aphelion, there was something else.", 6.0)


# ===========================================================================
# 12.25 — Footstep echo shader.
# ===========================================================================
func set_footstep_echo(active: bool) -> void:
	footstep_echo_active = active


# ===========================================================================
# 12.27 — Aphelion apology.
# ===========================================================================
func reveal_aphelion_apology() -> void:
	if aphelion_apology_revealed_flag:
		return
	aphelion_apology_revealed_flag = true
	GameState.collected_relics[&"aphelion_apology"] = true
	aphelion_apology_revealed.emit()
	EventBus.ui_toast.emit("The Aphelion's voice, translated: \"" + APHELION_APOLOGY_PHRASE + "\"", 8.0)


# ===========================================================================
# 12.28 — Listener mask reveal.
# ===========================================================================
func reveal_listener_mask() -> void:
	if listener_mask_revealed_flag:
		return
	listener_mask_revealed_flag = true
	GameState.collected_relics[&"listener_mask_revealed"] = true
	listener_mask_revealed.emit()
	EventBus.ui_toast.emit("The Listener removes her mask. Her face is yours.", 6.0)


# ===========================================================================
# 12.31 — Final-act NPC commentary.
# ===========================================================================
func try_speak_final_act_line(npc_id: StringName, line: String) -> bool:
	if final_act_commentary_spoken.get(npc_id, false):
		return false
	final_act_commentary_spoken[npc_id] = true
	EventBus.ui_toast.emit(line, 5.0)
	return true


# ===========================================================================
# 12.32 — Bearer child memory tablet.
# ===========================================================================
func read_bearer_child_tablet() -> void:
	if bearer_child_tablet_read:
		return
	bearer_child_tablet_read = true
	GameState.collected_relics[&"bearer_child_tablet"] = true
	if Compendium and Compendium.has_method("unlock"):
		Compendium.unlock(&"bearer_child_memory")


# ===========================================================================
# 12.33 — Compendium completion reward.
# ===========================================================================
func try_grant_compendium_reward() -> bool:
	if compendium_reward_granted:
		return false
	if Compendium == null:
		return false
	# Heuristic: when all known compendium entries flagged unlocked.
	var entries: Array = GameState.unlocked_compendium.keys()
	# At Phase-12 close, we expect at least ~40 entries. Conservative gate: 40+.
	if entries.size() < 40:
		return false
	compendium_reward_granted = true
	GameState.collected_relics[&"cantor_compass"] = true
	Inventory.try_add(&"cantors_compass", 1)
	EventBus.ui_toast.emit("The Cantor offers the Cantor's Compass. The song completes.", 6.0)
	return true


# ===========================================================================
# 12.36 — Joren-of-the-Lattice reveal.
# ===========================================================================
func reveal_joren_name() -> void:
	if joren_name_revealed:
		return
	joren_name_revealed = true
	GameState.collected_relics[&"joren_name_revealed"] = true
	EventBus.ui_toast.emit("\"Forgive me. — %s\"" % BEARER_PRE_DIADEM_NAME, 7.0)


# ===========================================================================
# 12.37 — Mira-Bearer sibling scene.
# ===========================================================================
func try_play_mira_sibling_scene() -> bool:
	if mira_sibling_scene_played:
		return false
	if not joren_name_revealed:
		return false
	if not bearer_child_tablet_read:
		return false
	var mira_friendship: int = 0
	if NpcLifecycle and NpcLifecycle.has_method("get_friendship"):
		mira_friendship = int(NpcLifecycle.get_friendship(&"mira"))
	if mira_friendship < 80:
		return false
	mira_sibling_scene_played = true
	EventBus.ui_toast.emit("Mira holds the diadem. She does not weep. She does not speak. She stands.", 8.0)
	if AudioBus:
		AudioBus.play_sfx(&"mira_sibling_scene")
	return true


# ===========================================================================
# 12.38 — Walker silent emote.
# ===========================================================================
func play_walker_epilogue_emote() -> void:
	walker_epilogue_emote_played = true


# ===========================================================================
# Helpers.
# ===========================================================================
func _player_in_final_spiral() -> bool:
	# Heuristic: distance-from-origin >= 640 (the Final Spiral edge) and the
	# player's last-known biome is final_spiral.
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return false
	var p := players[0] as Node2D
	if p == null:
		return false
	return p.global_position.length() >= 640.0 * 16.0  # 16 px per tile


# ===========================================================================
# Persistence.
# ===========================================================================
func dump_state() -> Dictionary:
	return {
		"vacancy_appeared": vacancy_appeared_flag,
		"vacancy_completed": vacancy_encounter_completed,
		"elision_fragments_collected": elision_fragments_collected,
		"elided_name_revealed": elided_name_revealed,
		"manifestos_read": _int_dict_to_str(manifestos_read),
		"loom_twin_discovered": loom_twin_discovered,
		"selected_ending": String(selected_ending),
		"endings_taken_history": _stringnames_to_strings(endings_taken_history),
		"path_locked": aphelion_chamber_path_locked_in,
		"reliquary_conversions": reliquary_conversions_performed,
		"wave_spawn_total": wave_spawn_total,
		"lamp_before_lamp": lamp_before_lamp_revealed,
		"footstep_echo": footstep_echo_active,
		"bearer_self_shatter": bearer_self_shatter_played,
		"aphelion_apology": aphelion_apology_revealed_flag,
		"listener_mask_revealed": listener_mask_revealed_flag,
		"final_act_commentary": _stringname_keys_to_str(final_act_commentary_spoken),
		"bearer_child_tablet_read": bearer_child_tablet_read,
		"compendium_reward": compendium_reward_granted,
		"joren_revealed": joren_name_revealed,
		"mira_sibling_played": mira_sibling_scene_played,
		"walker_epilogue_emote": walker_epilogue_emote_played,
	}


func restore_state(d: Dictionary) -> void:
	vacancy_appeared_flag = bool(d.get("vacancy_appeared", false))
	vacancy_encounter_completed = bool(d.get("vacancy_completed", false))
	elision_fragments_collected = int(d.get("elision_fragments_collected", 0))
	elided_name_revealed = bool(d.get("elided_name_revealed", false))
	manifestos_read = _str_dict_to_int(d.get("manifestos_read", {}))
	loom_twin_discovered = bool(d.get("loom_twin_discovered", false))
	selected_ending = StringName(String(d.get("selected_ending", "")))
	endings_taken_history = _strings_to_stringnames(d.get("endings_taken_history", []))
	aphelion_chamber_path_locked_in = bool(d.get("path_locked", false))
	reliquary_conversions_performed = int(d.get("reliquary_conversions", 0))
	wave_spawn_total = int(d.get("wave_spawn_total", 0))
	lamp_before_lamp_revealed = bool(d.get("lamp_before_lamp", false))
	footstep_echo_active = bool(d.get("footstep_echo", false))
	bearer_self_shatter_played = bool(d.get("bearer_self_shatter", false))
	aphelion_apology_revealed_flag = bool(d.get("aphelion_apology", false))
	listener_mask_revealed_flag = bool(d.get("listener_mask_revealed", false))
	final_act_commentary_spoken = _stringname_keys_from_str(d.get("final_act_commentary", {}))
	bearer_child_tablet_read = bool(d.get("bearer_child_tablet_read", false))
	compendium_reward_granted = bool(d.get("compendium_reward", false))
	joren_name_revealed = bool(d.get("joren_revealed", false))
	mira_sibling_scene_played = bool(d.get("mira_sibling_played", false))
	walker_epilogue_emote_played = bool(d.get("walker_epilogue_emote", false))


func _int_dict_to_str(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		out[str(k)] = bool(d[k])
	return out


func _str_dict_to_int(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		out[int(str(k))] = bool(d[k])
	return out


func _stringnames_to_strings(arr: Array) -> Array:
	var out: Array = []
	for s in arr:
		out.append(String(s))
	return out


func _strings_to_stringnames(arr: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for s in arr:
		out.append(StringName(String(s)))
	return out


func _stringname_keys_to_str(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		out[String(k)] = d[k]
	return out


func _stringname_keys_from_str(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		out[StringName(String(k))] = d[k]
	return out
