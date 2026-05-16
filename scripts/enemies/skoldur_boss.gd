extends Boss
class_name SkoldurBoss

## Phase 11.10 — Skoldur the Forge-Forsaken. 4-phase boss with a phase-4
## recognition pause: if the player carries `pyrenkin_pendant` (Brindle gave
## you one before the fight), the boss intones "You came back" before resuming.
## On defeat, ticket 11.28 stitches the fused pendant detail — Brindle's twin
## drops at the player's feet alongside the standard relics.
##
## Phase thresholds: 1.0 / 0.7 / 0.45 / 0.2. The recognition pause fires once on
## phase-4 entry.

const RECOGNITION_PAUSE_SECONDS: float = 2.5

var recognized: bool = false
var _recog_window_open: bool = false
var _recog_accum: float = 0.0


func _ready() -> void:
	boss_id = &"boss_skoldur"
	boss_music_id = &"boss_skoldur_theme"
	trinket_item_id = &"skoldur_trinket"
	shell_item_id = &"ember_iron_ore"
	shell_drop_count = 10
	fragment_item_id = &"sovereign_name_fragment_7"
	pulse_item_id = &"skoldurs_hammer"
	phase_thresholds = [1.0, 0.7, 0.45, 0.2]
	telegraph_radius_px = 64.0
	enrage_after_seconds = 360.0
	super._ready()


func _apply_phase() -> void:
	super._apply_phase()
	if current_phase == 3 and not _recog_window_open:
		_open_recognition_pause()


func _open_recognition_pause() -> void:
	_recog_window_open = true
	var holds_pendant: bool = Inventory.count_of(&"pyrenkin_pendant") > 0
	if holds_pendant:
		recognized = true
		EventBus.ui_toast.emit("Skoldur: \"You came back.\"", 4.0)
		GameState.collected_relics[&"skoldur_recognized"] = true
	else:
		EventBus.ui_toast.emit("Skoldur stops mid-swing. Then continues.", 3.0)
	EventBus.screen_pulse_requested.emit(0.4, 0.8)
	if AudioBus:
		AudioBus.play_sfx(&"skoldur_voice" if recognized else &"skoldur_grunt")
	if _attack_cycler:
		_attack_cycler.stop()


func _physics_process(delta: float) -> void:
	if _recog_window_open and _recog_accum < RECOGNITION_PAUSE_SECONDS:
		_recog_accum += delta
		velocity = Vector2.ZERO
		move_and_slide()
		if _recog_accum >= RECOGNITION_PAUSE_SECONDS:
			_recog_window_open = false
			if _attack_cycler:
				_attack_cycler.start()
		return
	super._physics_process(delta)


func _drop_boss_loot() -> void:
	super._drop_boss_loot()
	# 11.28 — pendant-fused-to-chest detail. Drops the matching Pyrenkin Pendant
	# regardless of whether the player brought their twin to the fight.
	var scn := load("res://scenes/items/item_drop.tscn") as PackedScene
	if scn == null:
		return
	var drop := scn.instantiate() as ItemDrop
	if drop == null:
		return
	drop.item_id = &"pyrenkin_pendant"
	drop.count = 1
	drop.global_position = global_position + Vector2(0, 4)
	get_tree().current_scene.add_child(drop)
	EventBus.ui_toast.emit("The twin pendant comes loose from his breastplate.", 4.5)
