extends CanvasLayer
class_name BossIntroCrawl

## Phase 5.39 — boss intro voice-over text crawl. When the boss is first
## engaged a short lore-flavored line crawls horizontally across the bottom
## of the screen for a few seconds, then dissolves. Reads the line from a
## static table keyed by boss_id.

const CRAWL_LINES: Dictionary = {
	&"boss_glaurem": "He grew and grew, and the stone tried to hold him.",
	&"boss_vorrkell": "The wyrm tasted your warmth before it saw you.",
	&"boss_spawnmother": "She is hungry. She has been hungry since the Aphelion dimmed.",
	&"boss_sythrenn": "Petals fall, even when no wind passes.",
	&"boss_auriax": "The Verdancy speaks. Listen, or be silenced.",
	&"boss_volthaar": "Choose: a name remembered, or a name spoken.",
	&"boss_drowned_crown": "Salt remembers what tides forget.",
	&"boss_skoldur": "The forge welcomes the one who returned.",
	&"boss_naeren": "Some debts are paid in mercy. Others in tide.",
	&"boss_veyl_aurora": "Seven spires sing one collapsing chord.",
	&"boss_diadem_bearer": "The diadem has waited longer than even the Aphelion.",
}

@onready var _root: Control = $Root
@onready var _label: Label = $Root/Crawl

var _hide_t: float = 0.0


func _ready() -> void:
	visible = false
	EventBus.boss_engaged.connect(_on_boss_engaged)
	set_process(true)


func _process(delta: float) -> void:
	if not visible:
		return
	_hide_t -= delta
	if _hide_t <= 0.0:
		visible = false


func _on_boss_engaged(boss_id: StringName) -> void:
	var line: String = CRAWL_LINES.get(boss_id, "")
	if line == "":
		return
	if _label:
		_label.text = line
	visible = true
	_hide_t = 6.0
	if _root:
		_root.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(_root, "modulate:a", 1.0, 0.6)
		t.tween_interval(4.0)
		t.tween_property(_root, "modulate:a", 0.0, 1.0)
