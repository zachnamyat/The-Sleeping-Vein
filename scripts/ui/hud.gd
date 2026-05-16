extends CanvasLayer
class_name HUD

## Top-level HUD. Owns:
##   - health bar (top-left)
##   - mana bar (under health)
##   - aphelion-sliver readout (top-right)
##   - hotbar (bottom-center; instantiated separately)
##   - status flash texts ("Pickaxe too weak", "+1 Loambeetle")

@onready var hp_bar: ProgressBar = $TopLeft/HealthBar
@onready var mp_bar: ProgressBar = $TopLeft/ManaBar
@onready var st_bar: ProgressBar = $TopLeft/StaminaBar
@onready var regen_label: Label = $TopLeft/RegenLabel
@onready var sliver_label: Label = $TopRight/Slivers
@onready var time_label: Label = $TopRight/TimeLabel
@onready var toast_label: Label = $Center/Toast
@onready var skill_toast: Label = $Center/SkillToast
## Phase 4.31 — coord readout under the time label. Updates every 0.25s with
## the player's chunk + tile coordinates. Building this as a Label child of
## the existing TopRight container means the rest of the HUD layout is unchanged.
var coord_label: Label = null
var _coord_accum: float = 0.0

const PHASE_DISPLAY: Dictionary = {
	0: "High Light",
	1: "Falling",
	2: "Low Light",
	3: "Rising",
}

var _toast_timer: float = 0.0
var _skill_toast_timer: float = 0.0
var _player_health: HealthComponent
var _player_mana: ManaComponent
var _player_stamina: StaminaComponent
var _hud_visible: bool = true


func _ready() -> void:
	add_to_group("hud")
	_apply_pixel_sizes()
	EventBus.player_spawned.connect(_on_player_spawned)
	EventBus.aphelion_dimmed.connect(_on_slivers_changed)
	EventBus.ui_toast.connect(_on_ui_toast)
	EventBus.skill_leveled_up.connect(_on_skill_leveled_up)
	EventBus.skill_xp_gained.connect(_on_skill_xp_gained)
	EventBus.item_picked_up.connect(_on_item_picked_up)
	if AudioBus:
		AudioBus.aphelion_beat.connect(_refresh_time_label)
	_refresh_sliver_label(GameState.aphelion_slivers_remaining)
	_refresh_time_label()
	_apply_hud_scale_opacity()
	if Settings:
		Settings.value_changed.connect(_on_settings_value_changed)
	# Phase 6.57 / 2.46 — wire AmmoLabel to the active hotbar so it can listen
	# for selection changes. Done at end of frame so the hotbar group is filled.
	call_deferred("_wire_ammo_label")


func _wire_ammo_label() -> void:
	var hotbar_nodes := get_tree().get_nodes_in_group("hotbar")
	if hotbar_nodes.is_empty():
		return
	var ammo := get_node_or_null("AmmoLabel")
	if ammo == null:
		return
	ammo.set("hotbar_path", ammo.get_path_to(hotbar_nodes[0]))
	if ammo.has_method("_refresh"):
		ammo.call("_refresh")


func _on_settings_value_changed(key: String, _value: Variant) -> void:
	if key == "hud_scale" or key == "hud_opacity":
		_apply_hud_scale_opacity()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_hud"):
		_hud_visible = not _hud_visible
		visible = _hud_visible


func _apply_hud_scale_opacity() -> void:
	# Ticket 1.32 — settings-driven HUD scale + opacity. Read at startup and
	# whenever Settings emits a value change.
	if Settings == null:
		return
	var scale_factor: float = float(Settings.get_value("hud_scale", 1.0))
	var opacity: float = float(Settings.get_value("hud_opacity", 1.0))
	scale_factor = clampf(scale_factor, 0.5, 2.0)
	opacity = clampf(opacity, 0.2, 1.0)
	# Apply to each top-level container the HUD owns.
	var top_left := $TopLeft as Control
	var top_right := $TopRight as Control
	var center := $Center as Control
	for c in [top_left, top_right, center]:
		if c == null:
			continue
		c.scale = Vector2(scale_factor, scale_factor)
		c.modulate.a = opacity


func _apply_pixel_sizes() -> void:
	# Force pixel-art sizes regardless of .tscn (Godot's editor auto-saves can revert).
	# All units below are 480x270 viewport pixels.
	var top_left := $TopLeft as Control
	if top_left:
		top_left.position = Vector2(4, 4)
		top_left.size = Vector2(64, 24)
	if hp_bar:
		hp_bar.position = Vector2(0, 0)
		hp_bar.size = Vector2(56, 6)
		hp_bar.custom_minimum_size = Vector2(56, 6)
		hp_bar.show_percentage = false
	if mp_bar:
		mp_bar.position = Vector2(0, 8)
		mp_bar.size = Vector2(56, 5)
		mp_bar.custom_minimum_size = Vector2(56, 5)
		mp_bar.show_percentage = false
	if sliver_label:
		# Width holds "Slivers: 70000" at m5x7 size 16. Widened from the legacy
		# 116×10 to 140×18 so the new font doesn't clip the trailing digit.
		sliver_label.position = Vector2(0, 0)
		sliver_label.size = Vector2(140, 18)
		sliver_label.add_theme_font_size_override("font_size", 16)
		sliver_label.clip_text = false
	# Top-right container — pin to right edge of viewport. Layout strip:
	#   y=0..18    Slivers
	#   y=24..50   Compass widget (small dial)
	#   (y=32..88  Minimap, anchored independently to the right edge)
	#   y=92..110  CompassDistance — sits BELOW the minimap so no overlap
	#   y=112..130 TimeLabel       — Aphelion-phase readout
	var top_right := $TopRight as Control
	if top_right:
		top_right.anchor_left = 1.0
		top_right.anchor_right = 1.0
		top_right.offset_left = -144.0
		top_right.offset_top = 4.0
		top_right.offset_right = -4.0
		top_right.offset_bottom = 140.0
	# Compass widget — pinned to the LEFT of the strip so it doesn't sit
	# under the minimap. Small enough to read but not dominate.
	var compass := $TopRight/Compass as Control
	if compass:
		compass.position = Vector2(0, 24)
		compass.size = Vector2(22, 22)
		if compass.has_method("set"):
			compass.set("radius_pixels", 9.0)
	# Compass distance label sits below the 56-tall minimap (which starts at
	# y=32 within the strip → ends at y=88). Push the label to y=92 so the
	# Aphelion-gold text never overlaps the chunk dots.
	var compass_distance := $TopRight/CompassDistance as Label
	if compass_distance:
		compass_distance.position = Vector2(0, 92)
		compass_distance.size = Vector2(140, 18)
		compass_distance.add_theme_font_size_override("font_size", 16)
	# Time-of-day phase label sits one line under CompassDistance.
	if time_label:
		time_label.position = Vector2(0, 112)
		time_label.size = Vector2(140, 18)
		time_label.add_theme_font_size_override("font_size", 16)
	# Phase 4.31 — coord readout. Anchored bottom-right of the viewport so the
	# 96-tall minimap widget at top-right doesn't overlap it. Kept as a
	# top-level HUD child (not inside TopRight) for that reason.
	if coord_label == null:
		coord_label = Label.new()
		coord_label.name = "CoordLabel"
		coord_label.anchor_left = 1.0
		coord_label.anchor_right = 1.0
		coord_label.anchor_top = 1.0
		coord_label.anchor_bottom = 1.0
		coord_label.offset_left = -160.0
		coord_label.offset_right = -4.0
		coord_label.offset_top = -56.0
		coord_label.offset_bottom = -38.0
		coord_label.add_theme_font_size_override("font_size", 16)
		coord_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		coord_label.modulate = Color(0.7, 0.65, 0.55, 0.9)
		coord_label.text = "@ 0,0 (0,0)"
		add_child(coord_label)
	# Center toast labels — body-size so they read cleanly at the m5x7 design grid.
	if toast_label:
		toast_label.add_theme_font_size_override("font_size", 16)
	if skill_toast:
		skill_toast.add_theme_font_size_override("font_size", 16)


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			toast_label.visible = false
	if _skill_toast_timer > 0.0:
		_skill_toast_timer -= delta
		if _skill_toast_timer <= 0.0:
			skill_toast.visible = false
	# Phase 4.31 — refresh coords throttled to 0.25s. Keeps the label readable
	# without thrashing the layout on every tick.
	_coord_accum += delta
	if _coord_accum >= 0.25 and coord_label:
		_coord_accum = 0.0
		_refresh_coords()


func _refresh_coords() -> void:
	if coord_label == null:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p := players[0] as Node2D
	if p == null:
		return
	var tile_x: int = int(p.global_position.x / 16.0)
	var tile_y: int = int(p.global_position.y / 16.0)
	var chunk_x: int = floori(float(tile_x) / 64.0)
	var chunk_y: int = floori(float(tile_y) / 64.0)
	coord_label.text = "@ %d,%d  (%d,%d)" % [tile_x, tile_y, chunk_x, chunk_y]


func _on_player_spawned(player: Node) -> void:
	_player_health = player.get_node_or_null("HealthComponent") as HealthComponent
	_player_mana = player.get_node_or_null("ManaComponent") as ManaComponent
	_player_stamina = player.get_node_or_null("StaminaComponent") as StaminaComponent
	if _player_health:
		_player_health.health_changed.connect(_on_player_hp_changed)
		_on_player_hp_changed(_player_health.current_health, _player_health.max_health)
		_refresh_regen_label()
	if _player_mana:
		_player_mana.mana_changed.connect(_on_player_mp_changed)
		_on_player_mp_changed(int(_player_mana.current_mana), _player_mana.max_mana)
	if _player_stamina:
		_player_stamina.stamina_changed.connect(_on_player_st_changed)
		_on_player_st_changed(_player_stamina.current, _player_stamina.max_stamina)


func _on_player_st_changed(current: float, maximum: float) -> void:
	if st_bar:
		st_bar.max_value = maximum
		st_bar.value = current


func _refresh_regen_label() -> void:
	if regen_label == null:
		return
	# Ticket 1.29 — show passive regen tick rate when > 0. HealthComponent has
	# no passive regen yet; we mirror the player's ManaComponent regen so the
	# readout is non-empty until a Vitality-skill passive lands.
	var rate: float = 0.0
	if _player_mana and _player_mana.regen_per_second > 0.0:
		rate = _player_mana.regen_per_second
	if rate > 0.0:
		regen_label.text = "+%.0f/s" % rate
	else:
		regen_label.text = ""


func _refresh_time_label() -> void:
	if time_label == null or AudioBus == null:
		return
	var phase: int = AudioBus.current_phase()
	var name: String = PHASE_DISPLAY.get(phase, "?")
	time_label.text = name


func _on_player_hp_changed(current: int, maximum: int) -> void:
	if hp_bar:
		hp_bar.max_value = maximum
		hp_bar.value = current


func _on_player_mp_changed(current: int, maximum: int) -> void:
	if mp_bar:
		mp_bar.max_value = maximum
		mp_bar.value = current


func _on_slivers_changed(slivers: int) -> void:
	_refresh_sliver_label(slivers)


func _refresh_sliver_label(slivers: int) -> void:
	if sliver_label:
		sliver_label.text = "Slivers: %d" % slivers


func _on_ui_toast(text: String, duration: float) -> void:
	if toast_label == null:
		return
	toast_label.text = text
	toast_label.visible = true
	_toast_timer = duration


func _on_skill_leveled_up(skill_id: StringName, new_level: int) -> void:
	if skill_toast == null:
		return
	# Phase 7.9 — louder level-up cue: toast + SFX + camera pulse. The TalentPanel
	# already shows the new total; this is the in-world feedback.
	skill_toast.text = "%s reaches Lv %d  •  +1 talent point" % [_skill_display_name(skill_id), new_level]
	skill_toast.visible = true
	_skill_toast_timer = 2.5
	if AudioBus:
		AudioBus.play_sfx(&"skill_level_up")
	EventBus.screen_pulse_requested.emit(0.35, 0.18)
	# Phase 7.10 — capstone fanfare when a skill hits 100. SkillSystem also emits
	# skill_capped; we already see the level-up so re-using this hook keeps the
	# wiring shallow.
	if new_level >= SkillSystem.SKILL_CAP_LEVEL:
		EventBus.ui_toast.emit("%s MASTERED. Cosmetic unlocked." % _skill_display_name(skill_id), 4.0)
		if AudioBus:
			AudioBus.play_sfx(&"sovereign_fanfare")


func _on_skill_xp_gained(skill_id: StringName, amount: int) -> void:
	if skill_toast == null or amount <= 0:
		return
	# Skip if a level-up toast is currently displayed so we don't overwrite it
	# with a smaller "+XP" message.
	if _skill_toast_timer > 1.5:
		return
	var lvl: int = SkillSystem.get_level(skill_id)
	var into_level: int = SkillSystem.get_xp(skill_id) - SkillSystem.xp_required_for_level(lvl)
	var to_next: int = SkillSystem.xp_required_for_level(lvl + 1) - SkillSystem.xp_required_for_level(lvl)
	skill_toast.text = "%s +%d  (Lv %d  %d/%d)" % [_skill_display_name(skill_id), amount, lvl, into_level, to_next]
	skill_toast.visible = true
	_skill_toast_timer = 1.0


func _skill_display_name(skill_id: StringName) -> String:
	return String(skill_id).replace("skill_", "").capitalize()


func _on_item_picked_up(item_id: StringName, count: int) -> void:
	var defn: ItemDef = ItemRegistry.get_def(item_id)
	var name: String = defn.display_name if defn else String(item_id)
	_on_ui_toast("+%d %s" % [count, name], 1.2)
	# Ticket 2.25 — rarity-keyed pickup tone so the player can hear "ooh, blue"
	# without looking at the toast.
	if AudioBus and defn:
		var sfx: StringName = &"pickup_common"
		match defn.rarity:
			1: sfx = &"pickup_uncommon"
			2: sfx = &"pickup_rare"
			3: sfx = &"pickup_epic"
			4: sfx = &"pickup_legendary"
			_: sfx = &"pickup_common"
		AudioBus.play_sfx(sfx)
