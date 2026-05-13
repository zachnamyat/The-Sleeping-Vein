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
@onready var sliver_label: Label = $TopRight/Slivers
@onready var toast_label: Label = $Center/Toast
@onready var skill_toast: Label = $Center/SkillToast

var _toast_timer: float = 0.0
var _skill_toast_timer: float = 0.0
var _player_health: HealthComponent
var _player_mana: ManaComponent


func _ready() -> void:
	add_to_group("hud")
	_apply_pixel_sizes()
	EventBus.player_spawned.connect(_on_player_spawned)
	EventBus.aphelion_dimmed.connect(_on_slivers_changed)
	EventBus.ui_toast.connect(_on_ui_toast)
	EventBus.skill_leveled_up.connect(_on_skill_leveled_up)
	EventBus.item_picked_up.connect(_on_item_picked_up)
	_refresh_sliver_label(GameState.aphelion_slivers_remaining)


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
		sliver_label.position = Vector2(0, 0)
		sliver_label.size = Vector2(68, 8)
		sliver_label.add_theme_font_size_override("font_size", 6)
	# Top-right container — pin to right edge of viewport.
	var top_right := $TopRight as Control
	if top_right:
		top_right.anchor_left = 1.0
		top_right.anchor_right = 1.0
		top_right.offset_left = -72.0
		top_right.offset_top = 4.0
		top_right.offset_right = -4.0
		top_right.offset_bottom = 60.0
	# Compass distance label
	var compass_distance := $TopRight/CompassDistance as Label
	if compass_distance:
		compass_distance.position = Vector2(0, 38)
		compass_distance.size = Vector2(68, 8)
		compass_distance.add_theme_font_size_override("font_size", 5)
	var compass := $TopRight/Compass as Control
	if compass:
		compass.position = Vector2(46, 10)
		compass.size = Vector2(22, 22)
		if compass.has_method("set"):
			compass.set("radius_pixels", 9.0)
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
	if _player_health:
		_player_health.health_changed.connect(_on_player_hp_changed)
		_on_player_hp_changed(_player_health.current_health, _player_health.max_health)
	if _player_mana:
		_player_mana.mana_changed.connect(_on_player_mp_changed)
		_on_player_mp_changed(int(_player_mana.current_mana), _player_mana.max_mana)


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
	skill_toast.text = "%s → Lv %d" % [String(skill_id).replace("skill_", "").capitalize(), new_level]
	skill_toast.visible = true
	_skill_toast_timer = 2.0


func _on_item_picked_up(item_id: StringName, count: int) -> void:
	var defn: ItemDef = ItemRegistry.get_def(item_id)
	var name: String = defn.display_name if defn else String(item_id)
	_on_ui_toast("+%d %s" % [count, name], 1.2)
