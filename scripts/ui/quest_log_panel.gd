extends CanvasLayer
class_name QuestLogPanel

## Phase 9.17 — Quest log / objective tracker. Press J (rebound from
## toggle_death_compass, share is fine — J is "journal") to open.
## Shows the day-of-Aphelion's three randomly-rolled daily quests, plus any
## currently active static/quest-marker rewards.

@onready var root: Panel = $Root
@onready var title_label: Label = $Root/Title
@onready var list_box: VBoxContainer = $Root/List
@onready var day_label: Label = $Root/DayLabel


func _ready() -> void:
	add_to_group("quest_log_ui")
	visible = false
	if NpcLifecycle:
		NpcLifecycle.daily_reset.connect(_on_daily_reset)
		NpcLifecycle.quest_state_changed.connect(_on_quest_state_changed)


func show_log() -> void:
	visible = true
	_rebuild()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_quest_log"):
		if visible:
			visible = false
		else:
			show_log()
	elif visible and event.is_action_pressed("ui_cancel"):
		visible = false


func _on_daily_reset(_new_day: int) -> void:
	if visible:
		_rebuild()


func _on_quest_state_changed(_qid: StringName, _state: String) -> void:
	if visible:
		_rebuild()


func _rebuild() -> void:
	if list_box == null:
		return
	for child in list_box.get_children():
		child.queue_free()
	if NpcLifecycle == null:
		return
	if day_label:
		day_label.text = "Day %d (%s)" % [NpcLifecycle.day_index, String(NpcLifecycle.seasonal_phase).replace("phase_", "").capitalize()]
	var quests: Array[StringName] = NpcLifecycle.get_today_quests()
	if quests.is_empty():
		var l := Label.new()
		l.text = "No quests today. Sleep to roll new ones."
		list_box.add_child(l)
		return
	for qid in quests:
		var l := Label.new()
		var meta: Dictionary = {}
		for q in NpcLifecycle.DAILY_QUEST_POOL:
			if StringName(q.get("id", &"")) == qid:
				meta = q
				break
		var label_text: String = String(meta.get("label", String(qid)))
		var state := String(NpcLifecycle.quest_states.get(qid, "active"))
		var progress: Dictionary = NpcLifecycle.quest_progress_lookup(qid)
		var cur: int = int(progress.get("current", 0))
		var goal: int = int(progress.get("goal", int(meta.get("goal", 1))))
		var done: String = " ✓" if state == "complete" or state == "claimed" else ""
		l.text = "  %s (%d/%d)%s  reward: %dc" % [label_text, cur, goal, done, int(meta.get("reward_coins", 0))]
		if state == "complete" or state == "claimed":
			l.modulate = Color(0.7, 1.0, 0.7, 1.0)
		list_box.add_child(l)
