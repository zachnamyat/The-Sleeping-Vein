extends CanvasLayer
class_name CharacterSheetPanel

## Phase 7.14 / 7.17 / 7.18 — Character sheet.
##
## Three columns:
##   1. Core stats: HP, mana, armor, crit %, crit dmg, lifesteal, mana regen,
##      thorns, knockback resist, cooldown reduction.
##   2. Skill XP table: per-skill (effective_level / xp_into / xp_to_next).
##   3. Active talents: per-skill talent count + capstone status.
##
## Plus a footer with active buffs and accessory grants.
## Toggle: press C.

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


func _ready() -> void:
	add_to_group("character_sheet")
	visible = false
	EventBus.skill_leveled_up.connect(_on_change)
	EventBus.skill_xp_gained.connect(_on_change)
	EventBus.inventory_changed.connect(_on_change)
	EventBus.talent_unlocked.connect(_on_change)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		toggle()
		return
	if visible and event.is_action_pressed("ui_cancel"):
		visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		_rebuild()


func _on_change(_a = null, _b = null) -> void:
	if visible:
		_rebuild()


func _rebuild() -> void:
	var root: Panel = $Root
	for c in root.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "Character Sheet  [C to toggle]"
	title.offset_left = 8.0
	title.offset_top = 4.0
	title.offset_right = -8.0
	title.offset_bottom = 18.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(0.97, 0.85, 0.5, 1)
	root.add_child(title)
	var hbox := HBoxContainer.new()
	hbox.offset_left = 12.0
	hbox.offset_top = 26.0
	hbox.offset_right = -12.0
	hbox.offset_bottom = -32.0
	hbox.add_theme_constant_override("separation", 10)
	root.add_child(hbox)
	hbox.add_child(_build_stat_column())
	hbox.add_child(_build_skill_column())
	hbox.add_child(_build_talent_column())
	var foot := Label.new()
	foot.offset_left = 12.0
	foot.offset_bottom = -8.0
	foot.offset_top = -26.0
	foot.offset_right = -12.0
	foot.text = _footer_text()
	foot.modulate = Color(0.78, 0.78, 0.55)
	root.add_child(foot)


func _build_stat_column() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(200, 0)
	var hdr := Label.new()
	hdr.text = "Stats"
	hdr.modulate = Color(0.92, 0.82, 0.45)
	box.add_child(hdr)
	var lines: Array = [
		"Armor          %d" % PlayerStats.armor_total(),
		"Crit chance    %.0f%%" % (PlayerStats.crit_chance() * 100.0),
		"Crit damage    +%.0f%%" % (PlayerStats.crit_bonus() * 100.0),
		"Lifesteal      %.1f%%" % (PlayerStats.lifesteal * 100.0),
		"Manasteel      %.1f%%" % (PlayerStats.manasteel * 100.0),
		"Thorns         %d" % PlayerStats.thorns,
		"Knockback res  %.0f%%" % (PlayerStats.knockback_resistance_bonus * 100.0),
		"Cooldown red.  %.0f%%" % (PlayerStats.cooldown_reduction * 100.0),
		"Mining speed   %.0fx" % PlayerStats.mining_speed_multiplier(),
		"Mining pierce  +%d" % PlayerStats.mining_pierce,
		"Max-HP bonus   +%d" % PlayerStats.max_hp_bonus,
		"Max-mana bonus +%d" % PlayerStats.max_mana_bonus,
		"Regen / sec    %.1f" % PlayerStats.regen_per_second,
		"Luck           %d" % int(round(PlayerStats.luck)),
		"Pickup radius  +%.0f%%" % (PlayerStats.loot_magnet_radius_bonus * 100.0),
	]
	for ln in lines:
		var l := Label.new()
		l.text = ln
		l.modulate = Color(0.86, 0.82, 0.70)
		box.add_child(l)
	return box


func _build_skill_column() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(200, 0)
	var hdr := Label.new()
	hdr.text = "Skill XP"
	hdr.modulate = Color(0.92, 0.82, 0.45)
	box.add_child(hdr)
	for s in SkillSystem.ALL_SKILLS:
		var prog: Dictionary = SkillSystem.progress_into_level(s)
		var lvl: int = int(prog["level"])
		var eff: int = SkillSystem.effective_level(s)
		var into: int = int(prog["into"])
		var span: int = int(prog["span"])
		var lore: String = SKILL_LABELS.get(s, String(s))
		var line := Label.new()
		if bool(prog["at_cap"]):
			line.text = "%s Lv %d MAX" % [lore, lvl]
			line.modulate = Color(1.0, 0.95, 0.55)
		else:
			if eff > lvl:
				line.text = "%s Lv %d (+%d) %d/%d" % [lore, lvl, eff - lvl, into, span]
			else:
				line.text = "%s Lv %d %d/%d" % [lore, lvl, into, span]
			line.modulate = Color(0.86, 0.82, 0.70)
		box.add_child(line)
	return box


func _build_talent_column() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(220, 0)
	var hdr := Label.new()
	hdr.text = "Talents (%d unspent)" % GameState.unallocated_talent_points
	hdr.modulate = Color(0.92, 0.82, 0.45)
	box.add_child(hdr)
	for s in SkillSystem.ALL_SKILLS:
		var allocated: int = int(GameState.allocated_talents.get(s, 0))
		var by_node: Dictionary = GameState.allocated_talent_nodes.get(s, {})
		var capstone_done: bool = false
		var tree: TalentTree = TalentRegistry.tree_for(s) if has_node(^"/root/TalentRegistry") else null
		if tree:
			for n in tree.nodes:
				if int(n.get("tier", 1)) == 5 and int(by_node.get(StringName(n.get("id", "")), 0)) > 0:
					capstone_done = true
					break
		var line := Label.new()
		var lore: String = SKILL_LABELS.get(s, String(s))
		if capstone_done:
			line.text = "%s  %d pts  ★capstone" % [lore, allocated]
			line.modulate = Color(1.0, 0.85, 0.45)
		elif allocated > 0:
			line.text = "%s  %d pts" % [lore, allocated]
			line.modulate = Color(0.70, 0.95, 0.65)
		else:
			line.text = "%s  —" % lore
			line.modulate = Color(0.55, 0.55, 0.45)
		box.add_child(line)
	return box


func _footer_text() -> String:
	var parts: PackedStringArray = []
	if Buffs:
		var active_buffs: Array = []
		for buff_id in [&"buff_xp_boost", &"buff_xp_mining", &"buff_xp_combat", &"buff_xp_crafting", &"buff_loam_loaf"]:
			if Buffs.has(buff_id):
				active_buffs.append("%s (%ds)" % [String(buff_id).replace("buff_", ""), int(Buffs.remaining(buff_id))])
		if not active_buffs.is_empty():
			parts.append("Buffs: " + ", ".join(active_buffs))
	if not PlayerStats.skill_level_bonus.is_empty():
		var sk_lines: Array = []
		for k in PlayerStats.skill_level_bonus.keys():
			sk_lines.append("+%d %s" % [int(PlayerStats.skill_level_bonus[k]), String(k).replace("skill_", "")])
		parts.append("Accessory skills: " + ", ".join(sk_lines))
	if not PlayerStats.set_bonus_active.is_empty():
		var set_lines: Array = []
		for sid in PlayerStats.set_bonus_active.keys():
			set_lines.append("%s (%d/4)" % [SetBonuses.display_name_for(sid), int(PlayerStats.set_bonus_active[sid])])
		parts.append("Set bonuses: " + ", ".join(set_lines))
	if parts.is_empty():
		return "No buffs, sets, or accessory bonuses active."
	return " • ".join(parts)
