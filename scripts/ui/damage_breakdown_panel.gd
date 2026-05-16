extends CanvasLayer
class_name DamageBreakdownPanel

## Phase 15.40 — Damage breakdown screen post-boss.
## Surfaces DPS / dodges / hits taken / crits / highest single hit. Triggered
## by Boss._on_defeated → EventBus.boss_defeated; auto-shows for 8 seconds.

const AUTO_HIDE_SECONDS: float = 8.0

var _root: Control
var _content: VBoxContainer
var _close_btn: Button
var _hide_timer: SceneTreeTimer


func _ready() -> void:
	layer = 25
	add_to_group("damage_breakdown_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	EventBus.boss_defeated.connect(_on_boss_defeated)


func _build_ui() -> void:
	_root = Control.new()
	_root.anchor_left = 0.5
	_root.anchor_right = 0.5
	_root.anchor_top = 0.5
	_root.anchor_bottom = 0.5
	_root.offset_left = -200
	_root.offset_right = 200
	_root.offset_top = -160
	_root.offset_bottom = 160
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.92)
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	_root.add_child(bg)
	var t := Label.new()
	t.text = "Boss Recap"
	t.offset_left = 12
	t.offset_top = 8
	t.add_theme_color_override("font_color", Color(0.85, 0.74, 0.45))
	_root.add_child(t)
	_content = VBoxContainer.new()
	_content.offset_left = 12
	_content.offset_top = 36
	_content.offset_right = -12
	_content.offset_bottom = -48
	_content.anchor_right = 1
	_content.anchor_bottom = 1
	_content.add_theme_constant_override("separation", 2)
	_root.add_child(_content)
	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.offset_left = -64
	_close_btn.offset_top = -36
	_close_btn.offset_right = -12
	_close_btn.offset_bottom = -12
	_close_btn.anchor_top = 1
	_close_btn.anchor_right = 1
	_close_btn.anchor_bottom = 1
	_close_btn.anchor_left = 1
	_close_btn.pressed.connect(func() -> void: visible = false)
	_root.add_child(_close_btn)


func _on_boss_defeated(_boss_id: StringName) -> void:
	# Boss._on_defeated emits before Phase15Helpers finalizes the breakdown;
	# defer one frame so the dict has the duration / dps_avg.
	call_deferred("_show")


func _show() -> void:
	for c in _content.get_children():
		c.queue_free()
	visible = true
	if Phase15Helpers == null:
		return
	var d: Dictionary = Phase15Helpers.damage_breakdown
	_add_row("Damage dealt", str(int(d.get(&"damage_dealt", 0))))
	_add_row("Damage taken", str(int(d.get(&"damage_taken", 0))))
	_add_row("Hits taken", str(int(d.get(&"hits_taken", 0))))
	_add_row("Dodges", str(int(d.get(&"dodges", 0))))
	_add_row("Crits landed", str(int(d.get(&"crits_landed", 0))))
	_add_row("Highest single hit", str(int(d.get(&"highest_single_hit", 0))))
	_add_row("Average DPS", "%.1f" % float(d.get(&"dps_avg", 0.0)))
	_add_row("Peak DPS (1s)", "%.1f" % float(d.get(&"dps_peak", 0.0)))
	_add_row("Duration", "%.1fs" % float(d.get(&"duration_seconds", 0.0)))
	_add_row("Combo max this fight", str(Phase15Helpers.combo_max))
	_hide_timer = get_tree().create_timer(AUTO_HIDE_SECONDS)
	_hide_timer.timeout.connect(func() -> void: visible = false)


func _add_row(label: String, value: String) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(200, 0)
	l.modulate = Color(0.9, 0.86, 0.7)
	h.add_child(l)
	var v := Label.new()
	v.text = value
	v.modulate = Color(0.97, 0.85, 0.5)
	h.add_child(v)
	_content.add_child(h)
