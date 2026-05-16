extends CanvasLayer
class_name CreditsPanel

## Phase 12.12 — Credits + run-stats screen. Surfaces after an ending is
## chosen and just before NG+. Shows:
##   - run time (Aphelion-beats elapsed)
##   - bosses defeated count
##   - compendium % unlocked
##   - sovereign threads gathered
##   - which ending was taken
##   - per-ending epilogue mood image (text-only at MVP)
##   - the team credits list

@onready var root: Panel = $Root
@onready var ending_label: Label = $Root/EndingLabel
@onready var stats_label: RichTextLabel = $Root/Stats
@onready var credits_label: RichTextLabel = $Root/Credits
@onready var continue_button: Button = $Root/Continue


func _ready() -> void:
	add_to_group("credits_panel")
	visible = false
	continue_button.pressed.connect(_on_continue)


func open_for_ending(ending_id: StringName) -> void:
	visible = true
	get_tree().paused = true
	ending_label.text = _ending_title(ending_id)
	stats_label.text = _build_stats_text()
	credits_label.text = _build_credits_text()


func _ending_title(ending_id: StringName) -> String:
	match String(ending_id):
		"ending_restore":
			return "Ending A — Restore"
		"ending_break":
			return "Ending B — Break"
		"ending_become":
			return "Ending C — Become"
		_:
			return "The Walker's run."


func _build_stats_text() -> String:
	var bosses: int = GameState.defeated_bosses.size()
	var compendium_unlocked: int = GameState.unlocked_compendium.size()
	var threads: int = GameState.sovereign_threads
	var ngp: int = GameState.ng_plus_cycles
	var slivers_left: int = GameState.aphelion_slivers_remaining
	var slivers_spent: int = max(0, GameState.APHELION_STARTING_SLIVERS - slivers_left)
	var titles_unlocked: int = 0
	for k in GameState.unlocked_compendium.keys():
		if String(k).begins_with("title_"):
			titles_unlocked += 1
	var endings_taken: int = 0
	if Phase12Helpers:
		endings_taken = Phase12Helpers.endings_taken_history.size()
	return ("[b]Run stats[/b]\n"
		+ "Bosses defeated: %d\n" % bosses
		+ "Compendium entries: %d\n" % compendium_unlocked
		+ "Titles earned: %d\n" % titles_unlocked
		+ "Sovereign threads: %d / 9\n" % threads
		+ "Slivers spent: %d\n" % slivers_spent
		+ "Endings taken (this slot): %d / 3\n" % endings_taken
		+ "NG+ cycle: %d\n" % ngp)


func _build_credits_text() -> String:
	return ("[b]THE SLEEPING VEIN — AETHERDEEP: The Sunken Aeon[/b]\n\n"
		+ "[i]A 2D top-down survival / mining / exploration game.[/i]\n\n"
		+ "Code, design, lore, art-direction: the user.\n"
		+ "Boss design, mob design, biome design: the user.\n"
		+ "Sprite generation: Gemini 2.5 Flash via gemini-image MCP.\n"
		+ "Boss arena prep, attack-pattern tuning, save-system migration: Claude (Anthropic).\n\n"
		+ "Made with Godot 4.6.\n"
		+ "Made with respect for Core Keeper.\n"
		+ "Made with the long quiet of the Hollow.\n\n"
		+ "[i]The Hollow continues. So do you, in some other form.[/i]\n\n"
		+ "Press [b]Continue[/b] to begin New Game+.")


func _on_continue() -> void:
	visible = false
	get_tree().paused = false
