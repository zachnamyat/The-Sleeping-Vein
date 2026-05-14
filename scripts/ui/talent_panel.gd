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

@onready var list: VBoxContainer = $Root/Scroll/List


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
	if list == null:
		return
	_rebuild_header()
	for child in list.get_children():
		child.queue_free()
	for skill in SkillSystem.ALL_SKILLS:
		var row := _build_row(skill)
		list.add_child(row)


func _rebuild_header() -> void:
	var hdr := $Root/Header as Label
	if hdr:
		hdr.text = "Unallocated talent points: %d" % GameState.unallocated_talent_points


func _build_row(skill_id: StringName) -> Control:
	# Single-line row: name | Lv N | T:k | progress bar | + Allocate button.
	# Previous grid layout overflowed both axes — content wider than its
	# column on the X, and only 3 of 4 rows visible on the Y. The new layout
	# uses ScrollContainer + VBoxContainer so any number of skills fits.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(430, 16)
	var lv: int = SkillSystem.get_level(skill_id)
	var xp: int = SkillSystem.get_xp(skill_id)
	var allocated: int = int(GameState.allocated_talents.get(skill_id, 0))
	var lore_name: String = SKILL_LABELS.get(skill_id, String(skill_id))
	var name_lbl := Label.new()
	name_lbl.text = lore_name
	name_lbl.custom_minimum_size = Vector2(120, 14)
	name_lbl.clip_text = true
	name_lbl.modulate = Color(0.97, 0.85, 0.5, 1) if lv > 0 else Color(0.78, 0.68, 0.45, 1)
	row.add_child(name_lbl)
	var lv_lbl := Label.new()
	lv_lbl.text = "Lv %d" % lv
	lv_lbl.custom_minimum_size = Vector2(38, 14)
	lv_lbl.modulate = Color(0.86, 0.82, 0.70, 1)
	row.add_child(lv_lbl)
	var tal_lbl := Label.new()
	tal_lbl.text = "T:%d" % allocated
	tal_lbl.custom_minimum_size = Vector2(32, 14)
	tal_lbl.modulate = Color(0.70, 0.95, 0.65, 1) if allocated > 0 else Color(0.55, 0.55, 0.45, 1)
	row.add_child(tal_lbl)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(120, 8)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var need_next: int = SkillSystem.xp_required_for_level(lv + 1) if lv < SkillSystem.SKILL_CAP_LEVEL else 1
	var prev_need: int = SkillSystem.xp_required_for_level(lv)
	bar.max_value = float(maxi(1, need_next - prev_need))
	bar.value = float(clampi(xp - prev_need, 0, int(bar.max_value)))
	bar.show_percentage = false
	bar.modulate = Color(0.85, 0.66, 0.34, 1)
	row.add_child(bar)
	var btn := Button.new()
	btn.text = "+ Allocate"
	btn.custom_minimum_size = Vector2(72, 14)
	btn.disabled = GameState.unallocated_talent_points <= 0
	btn.pressed.connect(func() -> void:
		if GameState.allocate_talent(skill_id):
			_rebuild()
	)
	row.add_child(btn)
	return row
