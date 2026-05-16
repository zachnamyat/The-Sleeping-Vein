extends Boss
class_name VeylAuroraBoss

## Phase 11.12 — Veyl-Aurora the Singing Choir.
## Composite 7-spire boss. The collective only has one health bar; we model
## the 7 spires as `spire_count` (saved persistently) — each phase-2 attack
## destroys one spire and the boss weakens commensurately.
## Phase 3 (~10% HP) ends with a Perfect Chord — a long telegraphed pulse that
## resolves the fight (11.30 pre-corruption chord audio). 7 Aurora-Shards drop.
## Phase thresholds: 1.0 / 0.6 / 0.1.

const SPIRES_TOTAL: int = 7

var spires_remaining: int = SPIRES_TOTAL
var _chord_started: bool = false


func _ready() -> void:
	boss_id = &"boss_veyl_aurora"
	boss_music_id = &"boss_veyl_aurora_theme"
	trinket_item_id = &"veyl_aurora_trinket"
	shell_item_id = &"aurora_shard"
	shell_drop_count = SPIRES_TOTAL
	fragment_item_id = &"sovereign_name_fragment_9"
	pulse_item_id = &"choirs_resonance"
	phase_thresholds = [1.0, 0.6, 0.1]
	telegraph_radius_px = 80.0
	enrage_after_seconds = 480.0
	super._ready()


func break_spire() -> void:
	if spires_remaining <= 0:
		return
	spires_remaining = maxi(0, spires_remaining - 1)
	EventBus.ui_toast.emit("Spire %d falls silent." % (SPIRES_TOTAL - spires_remaining), 2.5)
	EventBus.screen_pulse_requested.emit(0.25, 0.4)
	if AudioBus:
		AudioBus.play_sfx(&"veyl_spire_break")


func _apply_phase() -> void:
	super._apply_phase()
	if current_phase >= 1 and spires_remaining > 3:
		# Phase 2 starts breaking spires one per phase-step.
		break_spire()
	if current_phase >= 2 and not _chord_started:
		_play_perfect_chord()


func _play_perfect_chord() -> void:
	# 11.30 — perfect chord audio plays once. If the player has spoken to
	# Cantor and chimed the bell, audio is the recorded pre-corruption chord;
	# otherwise it's a single tone surrogate.
	_chord_started = true
	var has_bell: bool = bool(GameState.collected_relics.get(&"cantor_bell_unlocked", false))
	var chord_id: StringName = &"veyl_perfect_chord" if has_bell else &"veyl_perfect_chord_simple"
	if AudioBus:
		AudioBus.play_sfx(chord_id)
	EventBus.ui_toast.emit("A perfect chord. The Veil holds its breath.", 4.0)
	EventBus.letterbox_requested.emit(true, 0.6)


func _drop_boss_loot() -> void:
	super._drop_boss_loot()
	# 11.12 — extra aurora-shards stacked into the world rather than the inventory
	# so the player has to pick them up individually (visual moment).
	var scn := load("res://scenes/items/item_drop.tscn") as PackedScene
	if scn == null:
		return
	for i in range(SPIRES_TOTAL):
		var drop := scn.instantiate() as ItemDrop
		if drop == null:
			continue
		drop.item_id = &"aurora_shard"
		drop.count = 1
		var angle: float = TAU * float(i) / float(SPIRES_TOTAL)
		drop.global_position = global_position + Vector2(cos(angle), sin(angle)) * 24.0
		get_tree().current_scene.add_child(drop)
