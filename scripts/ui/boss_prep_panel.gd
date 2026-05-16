extends CanvasLayer
class_name BossPrepPanel

## Phase 5.38 — pre-boss tactical-prep panel. When the player approaches a
## boss arena perimeter (uses `boss_engaged` proximity from BossDirector via
## a soft trigger) we surface a recommended-gear hint. Player can dismiss
## with Esc or by walking away.
##
## The panel is opt-in; it surfaces *once per boss* per session and only if
## the player has neither already engaged nor defeated it.

const RECOMMENDATIONS: Dictionary = {
	&"boss_glaurem": {
		"name": "Glaur-em the Stone-Father",
		"weapon": "Stone-cleaving melee weapon (Shaleseed Sword or better)",
		"armor":  "Stoneproof helmet recommended",
		"buff":   "Vigil shrine offering before approach",
	},
	&"boss_vorrkell": {
		"name": "Vorr'kell the Tunnel-Wyrm",
		"weapon": "Ranged weapon (Wood Bow / Lead Gun)",
		"armor":  "Heat-resistant chestpiece",
		"buff":   "Mining-speed buff (mine an escape route)",
	},
}

@onready var _root: Control = $Root
@onready var _name_lbl: Label = $Root/Panel/NameLabel
@onready var _weapon_lbl: Label = $Root/Panel/Weapon
@onready var _armor_lbl: Label = $Root/Panel/Armor
@onready var _buff_lbl: Label = $Root/Panel/Buff
@onready var _dismiss_btn: Button = $Root/Panel/Dismiss

var _seen_this_session: Dictionary = {}
var _open_for_boss: StringName = &""


func _ready() -> void:
	visible = false
	add_to_group("boss_prep_panel")
	if _dismiss_btn:
		_dismiss_btn.pressed.connect(_close)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_close()


func show_for(boss_id: StringName) -> void:
	var rec: Dictionary = RECOMMENDATIONS.get(boss_id, {})
	if rec.is_empty():
		return
	if _seen_this_session.get(boss_id, false):
		return
	if GameState.has_defeated_boss(boss_id):
		return
	_seen_this_session[boss_id] = true
	_open_for_boss = boss_id
	if _name_lbl: _name_lbl.text = String(rec.get("name", String(boss_id)))
	if _weapon_lbl: _weapon_lbl.text = "Weapon: %s" % rec.get("weapon", "—")
	if _armor_lbl: _armor_lbl.text = "Armor:  %s" % rec.get("armor", "—")
	if _buff_lbl: _buff_lbl.text = "Tip:    %s" % rec.get("buff", "—")
	visible = true


func _close() -> void:
	visible = false
	_open_for_boss = &""
