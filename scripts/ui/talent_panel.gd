extends CanvasLayer
class_name TalentPanel

## Phase 7.2 — Per-skill talent tree UI with tabs.
##
## - 12 skill tabs (one per SkillSystem.ALL_SKILLS), each showing that skill's
##   TalentTree as a 5-tier grid of clickable nodes.
## - Node states: locked (prerequisites missing), allocatable (point available),
##   maxed (rank == max_ranks), affordable (eligible to spend).
## - Header: unallocated points, current skill level + XP bar (ticket 7.18).
## - Preset dropdown (Save 1/2/3, Load 1/2/3) — ticket 7.16.
## - Right-click to refund a single rank (free until the Respec Scroll feature
##   forces the player to pay — currently free for design ergonomics).
## - Toggle: press K.

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

@onready var root_panel: Panel = $Root
@onready var title_label: Label = $Root/Title
@onready var header_label: Label = $Root/Header
@onready var content_scroll: ScrollContainer = $Root/Scroll
@onready var content_list: VBoxContainer = $Root/Scroll/List

var _tabs: TabBar = null
var _tree_container: GridContainer = null
var _xp_label: Label = null
var _xp_bar: ProgressBar = null
var _preset_buttons: HBoxContainer = null
var _current_skill: StringName = &"skill_mining"
var _node_buttons: Dictionary = {}  ## node_id -> Button


func _ready() -> void:
	add_to_group("talent_panel")
	visible = false
	EventBus.skill_leveled_up.connect(_on_level_up)
	EventBus.skill_xp_gained.connect(_on_xp_gained)
	EventBus.talent_unlocked.connect(_on_talent_unlocked)
	_build_layout()


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


func _build_layout() -> void:
	# Larger panel so the per-skill grid fits.
	root_panel.offset_left = -320.0
	root_panel.offset_top  = -180.0
	root_panel.offset_right =  320.0
	root_panel.offset_bottom =  180.0
	title_label.text = "Skills & Talents  [K to toggle]"
	# Remove the placeholder VBox from the scroll container — we replace its
	# children every refresh.
	if content_list:
		for c in content_list.get_children():
			c.queue_free()
	# Tabs.
	_tabs = TabBar.new()
	for s in SkillSystem.ALL_SKILLS:
		_tabs.add_tab(String(SKILL_LABELS.get(s, String(s))))
	_tabs.tab_changed.connect(_on_tab_changed)
	_tabs.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_tabs.offset_left  = 12.0
	_tabs.offset_right = -12.0
	_tabs.offset_top   = 38.0
	_tabs.offset_bottom = 60.0
	_tabs.add_theme_color_override("font_color", Color(0.86, 0.78, 0.55, 1.0))
	_tabs.add_theme_color_override("font_selected_color", Color(0.97, 0.92, 0.55, 1.0))
	root_panel.add_child(_tabs)
	# XP bar row below the tabs.
	_xp_label = Label.new()
	_xp_label.offset_left  = 12.0
	_xp_label.offset_right = 308.0
	_xp_label.offset_top   = 66.0
	_xp_label.offset_bottom = 80.0
	_xp_label.modulate = Color(0.86, 0.82, 0.70, 1.0)
	root_panel.add_child(_xp_label)
	_xp_bar = ProgressBar.new()
	_xp_bar.offset_left  = 312.0
	_xp_bar.offset_right = -120.0
	_xp_bar.offset_top   = 70.0
	_xp_bar.offset_bottom = 78.0
	_xp_bar.show_percentage = false
	_xp_bar.modulate = Color(0.85, 0.66, 0.34, 1.0)
	root_panel.add_child(_xp_bar)
	# Preset buttons row.
	_preset_buttons = HBoxContainer.new()
	_preset_buttons.offset_left  = -118.0
	_preset_buttons.offset_right = -12.0
	_preset_buttons.offset_top   = 66.0
	_preset_buttons.offset_bottom = 82.0
	_preset_buttons.add_theme_constant_override("separation", 4)
	root_panel.add_child(_preset_buttons)
	# Tree grid container (under the XP / preset row).
	_tree_container = GridContainer.new()
	_tree_container.columns = 3
	_tree_container.offset_left   = 12.0
	_tree_container.offset_right  = -12.0
	_tree_container.offset_top    = 88.0
	_tree_container.offset_bottom = -32.0
	_tree_container.add_theme_constant_override("h_separation", 18)
	_tree_container.add_theme_constant_override("v_separation", 12)
	root_panel.add_child(_tree_container)
	# Footer row: respec button + refund hint.
	var foot := HBoxContainer.new()
	foot.offset_left  = 12.0
	foot.offset_right = -12.0
	foot.offset_top   = -28.0
	foot.offset_bottom = -8.0
	foot.add_theme_constant_override("separation", 16)
	root_panel.add_child(foot)
	var respec_btn := Button.new()
	respec_btn.text = "Respec all (consume Respec Scroll)"
	respec_btn.pressed.connect(_on_respec_pressed)
	foot.add_child(respec_btn)
	var hint := Label.new()
	hint.text = "Right-click a node to refund one rank."
	hint.modulate = Color(0.7, 0.7, 0.55, 1.0)
	foot.add_child(hint)


func _on_tab_changed(idx: int) -> void:
	if idx < 0 or idx >= SkillSystem.ALL_SKILLS.size():
		return
	_current_skill = SkillSystem.ALL_SKILLS[idx]
	_rebuild()


func _on_level_up(_skill_id: StringName, _new_level: int) -> void:
	if visible:
		_rebuild()


func _on_xp_gained(_skill_id: StringName, _amount: int) -> void:
	if visible:
		_rebuild()


func _on_talent_unlocked(_skill_id: StringName, _node_id: StringName) -> void:
	if visible:
		_rebuild()


func _rebuild() -> void:
	if _tree_container == null:
		return
	_rebuild_header()
	_rebuild_xp_bar()
	_rebuild_preset_buttons()
	_rebuild_tree()


func _rebuild_header() -> void:
	if header_label:
		var label_text := "Unallocated points: %d  •  Total earned: %d  •  Luck: %d" % [
			GameState.unallocated_talent_points,
			GameState.total_talent_points_earned(),
			int(round(PlayerStats.luck)),
		]
		header_label.text = label_text


func _rebuild_xp_bar() -> void:
	if _xp_label == null or _xp_bar == null:
		return
	var lvl: int = SkillSystem.get_level(_current_skill)
	var xp: int = SkillSystem.get_xp(_current_skill)
	var lore: String = SKILL_LABELS.get(_current_skill, String(_current_skill))
	if lvl >= SkillSystem.SKILL_CAP_LEVEL:
		_xp_label.text = "%s — Lv %d (MAX)" % [lore, lvl]
		_xp_bar.max_value = 1.0
		_xp_bar.value = 1.0
		return
	var prev_need: int = SkillSystem.xp_required_for_level(lvl)
	var next_need: int = SkillSystem.xp_required_for_level(lvl + 1)
	var span: int = maxi(1, next_need - prev_need)
	var into: int = clampi(xp - prev_need, 0, span)
	_xp_label.text = "%s — Lv %d  (%d / %d xp to next)" % [lore, lvl, into, span]
	_xp_bar.max_value = float(span)
	_xp_bar.value = float(into)


func _rebuild_preset_buttons() -> void:
	if _preset_buttons == null:
		return
	for c in _preset_buttons.get_children():
		c.queue_free()
	for i in range(GameState.PRESET_COUNT):
		var idx: int = i
		var pts: int = GameState.talent_preset_point_total(idx)
		var save_btn := Button.new()
		save_btn.text = "S%d" % (idx + 1)
		save_btn.custom_minimum_size = Vector2(24, 16)
		save_btn.tooltip_text = "Save current build to preset %d." % (idx + 1)
		save_btn.pressed.connect(func() -> void:
			GameState.save_talent_preset(idx)
			EventBus.ui_toast.emit("Preset %d saved." % (idx + 1), 1.5)
			_rebuild()
		)
		_preset_buttons.add_child(save_btn)
		var load_btn := Button.new()
		load_btn.text = "L%d (%dpt)" % [idx + 1, pts]
		load_btn.custom_minimum_size = Vector2(34, 16)
		load_btn.disabled = pts <= 0
		load_btn.tooltip_text = "Load preset %d." % (idx + 1)
		load_btn.pressed.connect(func() -> void:
			GameState.load_talent_preset(idx)
			_rebuild()
		)
		_preset_buttons.add_child(load_btn)


func _rebuild_tree() -> void:
	for c in _tree_container.get_children():
		c.queue_free()
	_node_buttons.clear()
	var tree: TalentTree = TalentRegistry.tree_for(_current_skill)
	if tree == null:
		var miss := Label.new()
		miss.text = "Tree pending."
		_tree_container.add_child(miss)
		return
	# Group nodes by tier; sort each tier by column.
	var by_tier: Dictionary = {}
	for n in tree.nodes:
		var t: int = int(n.get("tier", 1))
		var arr: Array = by_tier.get(t, [])
		arr.append(n)
		by_tier[t] = arr
	var tiers: Array = by_tier.keys()
	tiers.sort()
	for tier in tiers:
		var arr: Array = by_tier[tier]
		arr.sort_custom(func(a, b) -> bool: return int(a.get("column", 0)) < int(b.get("column", 0)))
		# Pad columns 0..2 so the grid is rectangular.
		var by_col: Dictionary = {}
		for n in arr:
			by_col[int(n.get("column", 1))] = n
		for col in range(3):
			if by_col.has(col):
				var btn := _build_node_button(by_col[col], int(tier))
				_tree_container.add_child(btn)
			else:
				var spacer := Control.new()
				spacer.custom_minimum_size = Vector2(180, 36)
				_tree_container.add_child(spacer)


func _build_node_button(node_def: Dictionary, _tier: int) -> Button:
	var nid := StringName(node_def.get("id", ""))
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(180, 36)
	var by_node: Dictionary = GameState.allocated_talent_nodes.get(_current_skill, {})
	var rank: int = int(by_node.get(nid, 0))
	var max_ranks: int = int(node_def.get("max_ranks", 1))
	var prereqs_ok: bool = TalentRegistry.prerequisites_met(_current_skill, nid)
	var can_spend: bool = GameState.unallocated_talent_points > 0 and prereqs_ok and rank < max_ranks
	btn.text = "%s  (%d/%d)" % [String(node_def.get("display_name", "")), rank, max_ranks]
	btn.tooltip_text = "%s\n%s\nEffect: %s × %s" % [
		String(node_def.get("display_name", "")),
		String(node_def.get("description", "")),
		String(node_def.get("effect_id", "")),
		String(node_def.get("effect_value", 0.0)),
	]
	# Color cues: locked = grey, maxed = gold, allocatable = green, partial = white.
	if rank >= max_ranks:
		btn.modulate = Color(1.0, 0.9, 0.45)
		btn.disabled = true
	elif not prereqs_ok:
		btn.modulate = Color(0.45, 0.45, 0.45)
		btn.disabled = true
	elif can_spend:
		btn.modulate = Color(0.7, 1.0, 0.7)
	elif rank > 0:
		btn.modulate = Color(0.92, 0.92, 0.78)
	else:
		btn.modulate = Color(0.78, 0.78, 0.78)
		btn.disabled = GameState.unallocated_talent_points <= 0
	btn.pressed.connect(func() -> void:
		if GameState.allocate_talent_node(_current_skill, nid):
			_rebuild()
	)
	# Right-click to refund a single rank. Wired through GUI input so we don't
	# eat the button's normal `pressed` flow.
	btn.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			if rank > 0:
				_refund_one_rank(nid)
	)
	_node_buttons[nid] = btn
	return btn


func _refund_one_rank(node_id: StringName) -> void:
	var by_node: Dictionary = GameState.allocated_talent_nodes.get(_current_skill, {})
	var rank: int = int(by_node.get(node_id, 0))
	if rank <= 0:
		return
	by_node[node_id] = rank - 1
	if int(by_node[node_id]) <= 0:
		by_node.erase(node_id)
	GameState.allocated_talent_nodes[_current_skill] = by_node
	GameState.allocated_talents[_current_skill] = int(GameState.allocated_talents.get(_current_skill, 0)) - 1
	GameState.unallocated_talent_points += 1
	EventBus.stat_recompute_requested.emit()
	_rebuild()


func _on_respec_pressed() -> void:
	if Inventory.count_of(&"respec_scroll") <= 0:
		EventBus.ui_toast.emit("Respec Scroll required.", 2.0)
		return
	Inventory.try_remove(&"respec_scroll", 1)
	GameState.refund_all_talents()
	EventBus.ui_toast.emit("Talents refunded.", 2.0)
	_rebuild()
