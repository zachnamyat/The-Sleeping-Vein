extends CanvasLayer
class_name TalentPanel

## Phase 7 MVP: a visibility-only skills panel. Lists all 12 skills with current
## level + XP progress to next level. Allocate buttons are stubbed for now.
## Toggle: press K. Phase 7 polish will add per-skill talent trees.

const SKILL_LABELS: Dictionary = {
	&"skill_mining":     "Stratabreaking",
	&"skill_running":    "Walking",
	&"skill_melee":      "Hand-Strike",
	&"skill_ranged":     "Hand-Throw",
	&"skill_vitality":   "Anchoring",
	&"skill_crafting":   "Form-Making",
	&"skill_gardening":  "Tending",
	&"skill_fishing":    "Listening",
	&"skill_cooking":    "Hearth",
	&"skill_magic":      "Resonance",
	&"skill_summoning":  "Calling",
	&"skill_explosives": "Bursting",
}

@onready var grid: GridContainer = $Root/Grid


func _ready() -> void:
	add_to_group("talent_panel")
	visible = false
	EventBus.skill_leveled_up.connect(_on_level_up)
	EventBus.skill_xp_gained.connect(_on_xp_gained)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		toggle()
		return
	if visible and event.is_action_pressed("ui_cancel"):
		visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		_rebuild()


func _on_level_up(_skill_id: StringName, _new_level: int) -> void:
	if visible:
		_rebuild()


func _on_xp_gained(_skill_id: StringName, _amount: int) -> void:
	if visible:
		_rebuild()


func _rebuild() -> void:
	if grid == null:
		return
	_rebuild_header()
	for child in grid.get_children():
		child.queue_free()
	for skill in SkillSystem.ALL_SKILLS:
		var row := _build_row(skill)
		grid.add_child(row)


func _rebuild_header() -> void:
	var hdr := $Root/Header as Label
	if hdr:
		hdr.text = "Unallocated talent points: %d" % GameState.unallocated_talent_points


func _build_row(skill_id: StringName) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(150, 50)
	var label := Label.new()
	var lv: int = SkillSystem.get_level(skill_id)
	var xp: int = SkillSystem.get_xp(skill_id)
	var allocated: int = int(GameState.allocated_talents.get(skill_id, 0))
	var lore_name: String = SKILL_LABELS.get(skill_id, String(skill_id))
	label.text = "%s — Lv %d   (talents: %d)" % [lore_name, lv, allocated]
	label.modulate = Color(0.97, 0.85, 0.5, 1) if lv > 0 else Color(0.7, 0.6, 0.4, 1)
	col.add_child(label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(140, 8)
	var need_next: int = SkillSystem.xp_required_for_level(lv + 1) if lv < SkillSystem.SKILL_CAP_LEVEL else 1
	var prev_need: int = SkillSystem.xp_required_for_level(lv)
	bar.max_value = float(maxi(1, need_next - prev_need))
	bar.value = float(clampi(xp - prev_need, 0, int(bar.max_value)))
	bar.show_percentage = false
	bar.modulate = Color(0.85, 0.66, 0.34, 1)
	col.add_child(bar)
	var btn := Button.new()
	btn.text = "+ Allocate"
	btn.custom_minimum_size = Vector2(140, 14)
	btn.disabled = GameState.unallocated_talent_points <= 0
	btn.pressed.connect(func() -> void:
		if GameState.allocate_talent(skill_id):
			_rebuild()
	)
	col.add_child(btn)
	return col
