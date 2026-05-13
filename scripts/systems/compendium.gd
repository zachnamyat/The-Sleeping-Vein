extends Node

## Compendium tracking. Bestiary entries unlock on first kill or first encounter.
## Tablet entries unlock on pickup. Lore tablet text is loaded from
## resources/compendium/.

const ENTRIES_ROOT: String = "res://resources/compendium/"

var _entries: Dictionary = {}


func _ready() -> void:
	_scan_directory(ENTRIES_ROOT)
	EventBus.entity_killed.connect(_on_entity_killed)
	EventBus.item_picked_up.connect(_on_item_picked_up)


func _scan_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full := path.path_join(entry)
		if dir.current_is_dir():
			_scan_directory(full)
		elif entry.ends_with(".tres"):
			var res := load(full) as Resource
			if res != null:
				_entries[StringName(res.get("id"))] = res
		entry = dir.get_next()
	dir.list_dir_end()


func unlock(entry_id: StringName) -> void:
	if GameState.unlocked_compendium.get(entry_id, false):
		return
	GameState.unlocked_compendium[entry_id] = true
	EventBus.ui_compendium_entry_unlocked.emit(entry_id)


func is_unlocked(entry_id: StringName) -> bool:
	return GameState.unlocked_compendium.get(entry_id, false)


func get_entry(entry_id: StringName) -> Resource:
	return _entries.get(entry_id)


func all_entries() -> Array:
	return _entries.values()


func _on_entity_killed(entity: Node, _killer: Node) -> void:
	# Phase 5: unlock bestiary entries for mobs by mob_def.id.
	var mob := entity as Mob
	if mob and mob.mob_def:
		unlock(StringName("bestiary_%s" % mob.mob_def.id))
	var boss := entity as Boss
	if boss:
		unlock(StringName("bestiary_%s" % boss.boss_id))


func _on_item_picked_up(item_id: StringName, _count: int) -> void:
	# Tablet shards are special: every pickup unlocks a new tablet entry.
	if item_id == &"tablet_shard":
		var idx: int = int(GameState.unlocked_compendium.get(&"_tablet_count", 0)) + 1
		GameState.unlocked_compendium[&"_tablet_count"] = idx
		unlock(StringName("tablet_%d" % idx))
