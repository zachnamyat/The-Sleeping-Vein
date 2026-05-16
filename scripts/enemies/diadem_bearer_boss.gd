extends Boss
class_name DiademBearerBoss

## Phase 12.8 + 12.26 + 12.36 — The Diadem-Bearer.
##
## A mortal antagonist, not a Sovereign. Four phases:
##   Phase 1 (100% → 66%): solo. Sword arcs + Aphelion-shard projectiles.
##   Phase 2 ( 66% → 33%): summons First & Second Readers as adds (3v1).
##   Phase 3 ( 33% →  5%): solo again, faster and more desperate.
##   Phase 4 (  5% →  0%): the Bearer KNEELS. They speak. They shatter the
##                          diadem themselves. The player does NOT strike
##                          the killing blow — `_player_did_not_strike` is
##                          tracked and the cinematic blocks attacks.
##
## Pre-fight, the player will have read 0-8 manifestos; the final one is
## signed in Joren-of-the-Lattice. If 12.32 (Bearer child tablet) is also
## read, the kneel cinematic reveals the full name in dialogue (12.36).
##
## Drops on kneel: Shattered Diadem (drives the endings UI), Bearer's pre-
## Diadem name lore item, Diadem-gold ingots × 5, Bearer's Sword, ancient coin.

const KNEEL_DIALOG: Array = [
	"You are a tool. I was a tool. We are the same.",
	"The light is a cage. The cage is the kindness.",
	"Choose better than I did.",
]
const KNEEL_LINE_INTERVAL: float = 3.0
const KNEEL_FINAL_PAUSE: float = 2.4

var _readers_spawned: bool = false
var _kneel_started: bool = false
var _kneel_accum: float = 0.0
var _kneel_line_index: int = 0
var _kneel_done: bool = false
var _player_did_not_strike: bool = true


func _ready() -> void:
	boss_id = &"boss_diadem_bearer"
	boss_music_id = &"boss_diadem_bearer_theme"
	trinket_item_id = &"diadem_bearer_sword"
	shell_item_id = &"diadem_gold_ingot"
	shell_drop_count = 5
	fragment_item_id = &"sovereign_name_fragment_11"
	pulse_item_id = &"shattered_diadem"
	phase_thresholds = [1.0, 0.66, 0.33, 0.05]
	telegraph_radius_px = 72.0
	enrage_after_seconds = 600.0
	minion_def_path = "res://resources/mobs/diadem_reader.tres"
	minion_spawn_period = 0.0   ## spawning happens explicitly via phase 2 entry
	minion_max_alive = 2
	super._ready()


func _apply_phase() -> void:
	super._apply_phase()
	# Phase 2 — summon First + Second Reader adds (3v1).
	if current_phase == 1 and not _readers_spawned:
		_summon_readers()
	# Phase 4 — kneel cinematic. Stop attacks; play three lines; shatter.
	if current_phase == 3 and not _kneel_started:
		_begin_kneel_cinematic()


func _summon_readers() -> void:
	_readers_spawned = true
	EventBus.ui_toast.emit("First Reader, Second Reader — to me.", 3.0)
	for i in range(2):
		_spawn_minion()


func _begin_kneel_cinematic() -> void:
	_kneel_started = true
	if _attack_cycler:
		_attack_cycler.stop()
	if contact_hitbox:
		contact_hitbox.base_damage = 0
	if hurtbox:
		hurtbox.set_process(false)
	# Sprite goes pale and dims.
	if sprite:
		sprite.modulate = Color(0.85, 0.83, 0.7, 1.0)
	EventBus.letterbox_requested.emit(true, 0.6)
	EventBus.hit_pause_requested.emit(0.3)
	EventBus.ui_toast.emit("The Bearer kneels.", 3.0)
	if AudioBus:
		AudioBus.play_sfx(&"diadem_bearer_kneel")
	if Phase12Helpers:
		Phase12Helpers.bearer_self_shatter_played = true


func _physics_process(delta: float) -> void:
	if _kneel_started and not _kneel_done:
		velocity = Vector2.ZERO
		move_and_slide()
		_tick_kneel_cinematic(delta)
		return
	super._physics_process(delta)


func _tick_kneel_cinematic(delta: float) -> void:
	_kneel_accum += delta
	if _kneel_line_index < KNEEL_DIALOG.size():
		var next_line_at: float = float(_kneel_line_index + 1) * KNEEL_LINE_INTERVAL
		if _kneel_accum >= next_line_at:
			var line: String = KNEEL_DIALOG[_kneel_line_index]
			EventBus.ui_toast.emit("Bearer: \"" + line + "\"", KNEEL_LINE_INTERVAL)
			if AudioBus:
				AudioBus.play_sfx(&"diadem_bearer_voice")
			_kneel_line_index += 1
	var total: float = KNEEL_DIALOG.size() * KNEEL_LINE_INTERVAL + KNEEL_FINAL_PAUSE
	if _kneel_accum >= total:
		_self_shatter()


func _self_shatter() -> void:
	if _kneel_done:
		return
	_kneel_done = true
	# 12.36 — Joren-of-the-Lattice reveal if the child tablet has been read.
	if Phase12Helpers and Phase12Helpers.bearer_child_tablet_read:
		Phase12Helpers.reveal_joren_name()
	# 12.26 — the Bearer kills themselves. No player strike.
	if AudioBus:
		AudioBus.play_sfx(&"diadem_shatter")
	EventBus.screen_pulse_requested.emit(0.85, 1.2)
	EventBus.camera_shake_requested.emit(6.0, 1.4)
	EventBus.letterbox_requested.emit(false, 1.0)
	# Honour the no-player-strike rule by zeroing HP via the boss's own hand.
	if health:
		health.current_health = 0
		health.died.emit(self)


func _on_died(killer: Node) -> void:
	if _player_did_not_strike and not _kneel_done:
		# If the player somehow killed the Bearer before the cinematic fired
		# (e.g. burn DOT crossing the 5% line), still play it.
		_begin_kneel_cinematic()
		_self_shatter()
	super._on_died(killer)


func _drop_boss_loot() -> void:
	super._drop_boss_loot()
	# 12.8 — Bearer's pre-Diadem name + Bearer's Sword as world drops.
	var scn := load("res://scenes/items/item_drop.tscn") as PackedScene
	if scn == null:
		return
	for entry in [{&"id": &"bearers_pre_diadem_name", &"count": 1}, {&"id": &"diadem_bearer_sword", &"count": 1}, {&"id": &"aphelion_shard", &"count": 3}]:
		var drop := scn.instantiate() as ItemDrop
		if drop == null:
			continue
		drop.item_id = entry[&"id"]
		drop.count = int(entry[&"count"])
		drop.global_position = global_position + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
		get_tree().current_scene.add_child(drop)
	# 12.37 — Mira-Bearer sibling scene attempt (post-fight scene at Anchor).
	if Phase12Helpers:
		Phase12Helpers.try_play_mira_sibling_scene()
