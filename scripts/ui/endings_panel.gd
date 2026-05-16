extends CanvasLayer
class_name EndingsPanel

## Phase 12.9-12.13 + 12.15-12.18 + 12.34 — Endings selector + path-choice UI.
##
## Opens when the Diadem-Bearer is defeated. Replaces the Phase-5 placeholder
## with a richer three-doors UI driven by Phase12Helpers:
##   12.9   — Ending A Restore sequence
##   12.10  — Ending B Break + optional Aphelion fight prompt
##   12.11  — Ending C Become + unlock conditions
##   12.13  — New Game+ from credits ([N])
##   12.15  — endings_taken_history tracked per save slot
##   12.17  — Three diegetic doors UI; lore-flavored
##   12.18  — Ending C unlock-gate validator with per-condition breakdown
##   12.34  — Multi-ending shared-save state (no full reset between endings)

@onready var title: Label = $Root/Title
@onready var subtitle: RichTextLabel = $Root/Sub
@onready var btn_restore: Button = $Root/Choices/Restore
@onready var btn_break: Button = $Root/Choices/Break
@onready var btn_become: Button = $Root/Choices/Become
@onready var credits_lbl: RichTextLabel = $Root/Credits
@onready var validator_panel: VBoxContainer = $Root/Validator
@onready var validator_label: Label = $Root/Validator/Header
@onready var validator_list: VBoxContainer = $Root/Validator/Conditions
@onready var history_label: RichTextLabel = $Root/History
@onready var sovereign_preview: RichTextLabel = $Root/SovereignPreview


func _ready() -> void:
	add_to_group("endings_ui")
	visible = false
	if EventBus:
		EventBus.boss_defeated.connect(_on_boss_defeated)
	btn_restore.pressed.connect(_choose_restore)
	btn_break.pressed.connect(_choose_break)
	btn_become.pressed.connect(_choose_become)


func _on_boss_defeated(boss_id: StringName) -> void:
	if boss_id != &"boss_diadem_bearer":
		return
	# Brief delay to let the Bearer's self-shatter cinematic finish.
	await get_tree().create_timer(1.5).timeout
	open()


func open() -> void:
	visible = true
	title.text = "The Aphelion's chamber. Three paths."
	subtitle.text = "[i]The Aphelion's last sliver hangs in the air. The chamber's three doors carry their own light. Choose deliberately.[/i]"
	credits_lbl.text = ""
	_refresh_validator()
	_refresh_history()
	_refresh_sovereign_preview()
	btn_restore.disabled = false
	btn_break.disabled = false
	btn_become.disabled = not _ending_c_unlocked()


func _refresh_validator() -> void:
	# Clear children.
	for c in validator_list.get_children():
		c.queue_free()
	validator_label.text = "Ending C — unlock conditions:"
	if Phase12Helpers == null:
		var l := Label.new()
		l.text = "[Phase12Helpers offline]"
		validator_list.add_child(l)
		return
	var breakdown: Dictionary = Phase12Helpers.ending_c_unlock_breakdown()
	for key in breakdown.keys():
		var entry: Dictionary = breakdown[key]
		var l := Label.new()
		var prefix: String = "[✓] " if entry["met"] else "[ ] "
		l.text = prefix + str(entry["label"])
		l.modulate = Color(0.7, 1.0, 0.7, 1.0) if entry["met"] else Color(0.9, 0.7, 0.7, 1.0)
		validator_list.add_child(l)


func _refresh_history() -> void:
	if Phase12Helpers == null:
		history_label.text = "[i]No prior runs recorded.[/i]"
		return
	var carved: Array = Phase12Helpers.carved_endings()
	if carved.is_empty():
		history_label.text = "[i]No prior endings carved in the chamber walls.[/i]"
		return
	var parts: Array = []
	for ending in carved:
		var name: String = ""
		match String(ending):
			"ending_restore": name = "Restore"
			"ending_break": name = "Break"
			"ending_become": name = "Become"
			_: name = String(ending)
		parts.append("[" + name + "]")
	history_label.text = "[b]Carved in the chamber wall:[/b] " + " ".join(parts)


func _refresh_sovereign_preview() -> void:
	if Phase12Helpers == null:
		sovereign_preview.text = ""
		return
	var preview: Dictionary = Phase12Helpers.sovereign_naming_preview()
	var bell_state: String = "the Cantor's Compass sings" if preview.get("cantor_compass_unlocked", false) else "the Cantor's Compass remains unstrung"
	sovereign_preview.text = "[i]Sovereign threads gathered: %d / %d. %s.[/i]" % [
		int(preview.get("fragments_held", 0)),
		int(preview.get("fragments_needed", 9)),
		bell_state,
	]


func _ending_c_unlocked() -> bool:
	if Phase12Helpers == null:
		return GameState.sovereign_threads >= 9
	return Phase12Helpers.ending_c_unlocked()


func _choose_restore() -> void:
	if Phase12Helpers and not Phase12Helpers.commit_ending(Phase12Helpers.ENDING_RESTORE):
		return
	GameState.unlocked_compendium[&"ending_restore"] = true
	credits_lbl.text = "[b]ENDING A — Restore.[/b]\n[i]The Walker offers their gold threads to the Aphelion. The captive sun brightens. The Hollow remembers how to breathe. The strata stabilise. The Wormbound continue their quiet generations; the Lattice Survivors plant new groves; the Cantor's bell rings true for centuries.\n\nThe Walker, having served the Aphelion's original purpose, returns to the Anchor and is unmade by the Loom — gently, as designed. The peace is real. The lie is preserved.[/i]\n\nNew Game+ unlocked. Press [b]N[/b] to begin a new cycle."
	_finish()


func _choose_break() -> void:
	if Phase12Helpers and not Phase12Helpers.commit_ending(Phase12Helpers.ENDING_BREAK):
		return
	GameState.unlocked_compendium[&"ending_break"] = true
	credits_lbl.text = "[b]ENDING B — Break.[/b]\n[i]The Walker raises the Shattered Diadem. The Aphelion does not resist; not really. It cracks like a thrown vase. The seal fails. The strata begin to unfold. Light from elsewhere arrives.\n\nThe thing the Inversion was meant to hide from is encountered, at last. It is not what the Vesari feared. It is something stranger, and possibly not hostile, and the world will spend a long morning learning to meet it.\n\nThe Walker steps out into the open, Aphelion-bound no longer.[/i]\n\nThe Aphelion's voice, translated: \"%s\"\n\nNew Game+ unlocked. Press [b]N[/b] to begin a new cycle." % "I am sorry. I tried."
	# 12.10 — open the optional Aphelion fight prompt.
	_offer_aphelion_fight()
	_finish()


func _choose_become() -> void:
	if not _ending_c_unlocked():
		EventBus.ui_toast.emit("The gold path refuses. Some thread is still missing.", 4.0)
		return
	if Phase12Helpers and not Phase12Helpers.commit_ending(Phase12Helpers.ENDING_BECOME):
		return
	GameState.unlocked_compendium[&"ending_become"] = true
	credits_lbl.text = "[b]ENDING C — Become.[/b]\n[i]The Walker, woven by nine threads, steps onto the chamber floor and offers themselves. The Aphelion accepts. The Walker is unmade and remade as the new anchor — quieter, smaller, kept.\n\nThe Sovereigns who remain become advisors. Vol'thaar speaks now without sorrow; Naeren, peace already promised, listens. The Listeners-Below remove their masks. They are all the Walker, looped through this descent across millennia. The loop is broken.\n\nThe new sun decides: the seal is no longer needed. The world will open in its own time, gently. The thing outside will be met when it is met.[/i]\n\nNew Game+ unlocked. Press [b]N[/b] to begin a new cycle."
	_finish()


func _offer_aphelion_fight() -> void:
	# 12.10 — surface a tutorial line + open the optional encounter via toast.
	EventBus.ui_toast.emit("A door opens at the chamber's far wall. The Aphelion waits.", 6.0)
	GameState.unlocked_recipes[&"unlock_aphelion_door"] = true


func _finish() -> void:
	btn_restore.disabled = true
	btn_break.disabled = true
	btn_become.disabled = true
	get_tree().paused = false
	_refresh_history()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N:
		if btn_restore.disabled:  # an ending was chosen
			_open_credits_then_ng_plus()


func _open_credits_then_ng_plus() -> void:
	# 12.12 — surface the credits / run-stats screen if available, then NG+.
	var credits_panels := get_tree().get_nodes_in_group("credits_panel")
	if credits_panels.size() > 0 and credits_panels[0].has_method("open_for_ending"):
		credits_panels[0].open_for_ending(Phase12Helpers.selected_ending if Phase12Helpers else &"")
	GameState.start_new_game_plus()
	get_tree().change_scene_to_file("res://scenes/world/main.tscn")
