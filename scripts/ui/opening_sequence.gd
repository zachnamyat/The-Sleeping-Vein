extends CanvasLayer
class_name OpeningSequence

## Phase 5.40 — game-open opening sequence. Plays once on every fresh world.
## Sequence (~9 seconds total, fully skippable with Esc):
##   1. Black frame, single faint Loom hum (AudioBus sting).
##   2. "AETHERDEEP" fades in centered.
##   3. Subtitle "The Sunken Aeon" fades in below.
##   4. The Aphelion beats once (sting).
##   5. Aelstren's silhouette settles at the Anchor (toast).
##   6. Curtain raises, player gains control.
##
## Skippable any time with Esc / Space / Enter; falls back to immediate
## control if the autoload is disabled in Settings.

@onready var _root: Control = $Root
@onready var _bg: ColorRect = $Root/Bg
@onready var _title_lbl: Label = $Root/Title
@onready var _subtitle_lbl: Label = $Root/Subtitle

var _active: bool = false
var _skipped: bool = false


func _ready() -> void:
	visible = false
	add_to_group("opening_sequence")
	# Wait one frame so all autoloads + player exist.
	call_deferred("_maybe_play")


func _maybe_play() -> void:
	if Settings:
		var enabled: Variant = Settings.get_value("opening_sequence_seen", false)
		if enabled is bool and enabled == true:
			return
		Settings.set_value("opening_sequence_seen", true)
	_active = true
	visible = true
	_run_sequence()


func _unhandled_input(event: InputEvent) -> void:
	if not _active or _skipped:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_skip()


func _run_sequence() -> void:
	if _title_lbl: _title_lbl.modulate.a = 0.0
	if _subtitle_lbl: _subtitle_lbl.modulate.a = 0.0
	if _bg: _bg.modulate.a = 1.0
	if AudioBus:
		AudioBus.play_sfx(&"loom_hum")
	var t := create_tween()
	t.tween_interval(0.6)
	if _title_lbl:
		t.tween_property(_title_lbl, "modulate:a", 1.0, 1.0)
	t.tween_interval(0.6)
	if _subtitle_lbl:
		t.tween_property(_subtitle_lbl, "modulate:a", 1.0, 1.0)
	t.tween_interval(1.4)
	t.tween_callback(func() -> void:
		if AudioBus:
			AudioBus.play_sfx(&"aphelion_beat")
		EventBus.screen_pulse_requested.emit(0.6, 0.5)
	)
	t.tween_interval(1.0)
	t.tween_callback(func() -> void:
		EventBus.ui_toast.emit("Aelstren waits at the Anchor.", 3.0)
	)
	t.tween_interval(1.4)
	if _bg:
		t.tween_property(_bg, "modulate:a", 0.0, 1.0)
	if _title_lbl:
		t.parallel().tween_property(_title_lbl, "modulate:a", 0.0, 1.0)
	if _subtitle_lbl:
		t.parallel().tween_property(_subtitle_lbl, "modulate:a", 0.0, 1.0)
	t.tween_callback(_finish)


func _skip() -> void:
	_skipped = true
	_finish()


func _finish() -> void:
	_active = false
	visible = false
	# Phase 5.15 tie-in — push the first-step tutorial hint now.
	if Engine.has_singleton("TutorialDirector"):
		var td = Engine.get_singleton("TutorialDirector")
		if td and td.has_method("fire_named"):
			td.call("fire_named", &"first_step")
