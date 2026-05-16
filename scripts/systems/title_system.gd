extends Node

## Phase 5.19 — title / honorific tracker. Each Sovereign kill grants a title
## that the player can wear cosmetically. Implementation: GameState keeps a
## `titles` set and `equipped_title`. The Settings panel (Phase 9 polish) will
## eventually let the player switch them; for MVP the most-recently-earned
## title auto-equips.

const TITLES_BY_BOSS: Dictionary = {
	&"boss_glaurem": "Hunter's Crown",
	&"boss_vorrkell": "Tunnel-Walker",
	&"boss_spawnmother": "Brood-Snuffer",
	&"boss_sythrenn": "Mercy-Spoken",
	&"boss_auriax": "Verdant-Quieter",
	&"boss_volthaar": "Coral-Cleaver",
	&"boss_drowned_crown": "Tide-Crowned",
	&"boss_skoldur": "Forge-Reborn",
	&"boss_naeren": "Salt-Forgiven",
	&"boss_veyl_aurora": "Chord-Breaker",
	&"boss_diadem_bearer": "Diadem-Undone",
}

var titles_earned: Array[StringName] = []
var equipped_title: StringName = &""


func _ready() -> void:
	EventBus.boss_defeated.connect(_on_boss_defeated)


func _on_boss_defeated(boss_id: StringName) -> void:
	var label: String = TITLES_BY_BOSS.get(boss_id, "")
	if label == "":
		return
	var key: StringName = StringName(label)
	if key in titles_earned:
		return
	titles_earned.append(key)
	equipped_title = key
	if not GameState.has_method("get"):
		return
	# Save through GameState so the SaveSystem round-trip can persist them.
	# Existing Dictionary field reused: titles tagged as compendium entries
	# of category "title_*" mirror the unlock pattern.
	GameState.unlocked_compendium[StringName("title_%s" % String(key).to_lower().replace(" ", "_"))] = true
	EventBus.ui_toast.emit("Title earned: %s" % label, 3.5)


func get_equipped_title() -> StringName:
	return equipped_title


func set_equipped_title(title: StringName) -> bool:
	if title not in titles_earned:
		return false
	equipped_title = title
	return true
