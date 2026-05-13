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
		# Widen enough for "Slivers: 70000" at the 8x8 BMFont (clip-text default
		# is false but tight bounds would hide the number under the Compass).
		sliver_label.position = Vector2(0, 0)
		sliver_label.size = Vector2(116, 10)
		sliver_label.add_theme_font_size_override("font_size", 8)
		sliver_label.clip_text = false
	# Top-right container — pin to right edge of viewport. Width needs to fit
	# the slivers label plus the compass widget below it.
	var top_right := $TopRight as Control
	if top_right:
		top_right.anchor_left = 1.0
		top_right.anchor_right = 1.0
		top_right.offset_left = -120.0
		top_right.offset_top = 4.0
		top_right.offset_right = -4.0
		top_right.offset_bottom = 80.0
	# Compass distance label
	var compass_distance := $TopRight/CompassDistance as Label
	if compass_distance:
		compass_distance.position = Vector2(0, 46)
		compass_distance.size = Vector2(116, 8)
		compass_distance.add_theme_font_size_override("font_size", 6)
	var compass := $TopRight/Compass as Control
	if compass:
		compass.position = Vector2(94, 12)
		compass.size = Vector2(22, 22)
		if compass.has_method("set"):
			compass.set("radius_pixels", 9.0)
	# Time-of-day phase label sits below the compass distance.
	if time_label:
		time_label.position = Vector2(0, 58)
		time_label.size = Vector2(116, 10)
		time_label.add_theme_font_size_override("font_size", 6)
	# Center toast labels — small, centered horizontally
	if toast_label:
		toast_label.add_theme_font_size_override("font_size", 6)
	if skill_toast:
		skill_toast.add_theme_font_size_override("font_size", 6)


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			toast_label.visible = false
	if _skill_toast_timer > 0.0:
		_skill_toast_timer -= delta
		if _skill_toast_timer <= 0.0:
			skill_toast.visible = false


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
	skill_toast.text = "%s -> Lv %d" % [_skill_display_name(skill_id), new_level]
	skill_toast.visible = true
	_skill_toast_timer = 2.0


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
