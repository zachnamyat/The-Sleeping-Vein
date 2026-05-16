extends Boss
class_name DrownedCrownBoss

## Phase 10.14 — Drowned Crown optional boss. NOT Hollowling-corrupted (pure
## grief-given-form). At 0 HP, instead of dying with a fanfare, the Crown
## lays its sword down and walks into the water, dropping the Diadem + Sword.

func _ready() -> void:
	boss_id = &"boss_drowned_crown"
	boss_music_id = &"boss_drowned_crown_theme"
	trinket_item_id = &""
	shell_item_id = &"coral_fragment"
	shell_drop_count = 3
	fragment_item_id = &""
	pulse_item_id = &""
	phase_thresholds = [1.0, 0.6, 0.25]
	telegraph_radius_px = 48.0
	enrage_after_seconds = 480.0
	super._ready()


func _drop_boss_loot() -> void:
	var scn := load("res://scenes/items/item_drop.tscn") as PackedScene
	if scn == null:
		return
	# 10.14 lore: the Crown lays down its sword. Drops:
	#   - Drowned Diadem (vanity helm)
	#   - Sword of the Last Threnos King (tier-5+ weapon)
	#   - coral_fragment x3
	#   - ancient_coin x40-60
	var drops: Array[Dictionary] = [
		{"id": &"drowned_diadem", "count": 1},
		{"id": &"sword_threnos_king", "count": 1},
		{"id": &"coral_fragment", "count": 3},
		{"id": &"ancient_coin", "count": int(round(randf_range(40.0, 60.0)))},
	]
	for d in drops:
		var drop := scn.instantiate() as ItemDrop
		drop.item_id = d["id"]
		drop.count = int(d["count"])
		drop.global_position = global_position + Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 8.0))
		get_tree().current_scene.add_child(drop)


func _play_defeat_fanfare() -> void:
	# 10.14 — silent walk into the water; no fanfare.
	if AudioBus:
		AudioBus.play_sfx(&"drowned_crown_farewell")
	EventBus.ui_toast.emit("The Drowned Crown lays down the sword and walks into the deep.", 5.0)
	EventBus.letterbox_requested.emit(true, 0.5)
	var t := get_tree().create_timer(3.0, true, false, false)
	t.timeout.connect(func() -> void: EventBus.letterbox_requested.emit(false, 0.5))
