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
	# Phase 5.16 — first-kill compendium trigger. Mobs unlock by mob_def.id,
	# bosses by boss_id. We surface a toast on the first unlock per session
	# so the player notices the bestiary expanding.
	var mob := entity as Mob
	if mob and mob.mob_def:
		var key: StringName = StringName("bestiary_%s" % mob.mob_def.id)
		var was_unlocked: bool = GameState.unlocked_compendium.get(key, false)
		unlock(key)
		if not was_unlocked:
			EventBus.ui_toast.emit("Compendium: %s recorded." % mob.mob_def.display_name, 2.0)
	var boss := entity as Boss
	if boss:
		var bkey: StringName = StringName("bestiary_%s" % boss.boss_id)
		var was_unlocked_b: bool = GameState.unlocked_compendium.get(bkey, false)
		unlock(bkey)
		if not was_unlocked_b:
			var label: String = boss.mob_def.display_name if boss.mob_def else String(boss.boss_id)
			EventBus.ui_toast.emit("Compendium: SOVEREIGN %s recorded." % label, 3.0)


func _on_item_picked_up(item_id: StringName, count: int) -> void:
	# Phase 5.16 — first-pickup compendium trigger. Tablet shards expand the
	# tablets tab; key items (relics, name fragments) expand a "Relics" tab
	# (entries keyed as `item_<id>` so the panel can filter by prefix).
	if item_id == &"tablet_shard":
		var idx: int = int(GameState.unlocked_compendium.get(&"_tablet_count", 0)) + 1
		GameState.unlocked_compendium[&"_tablet_count"] = idx
		unlock(StringName("tablet_%d" % idx))
		return
	var defn: ItemDef = ItemRegistry.get_def(item_id)
	if defn == null:
		return
	# Surface a compendium entry for KEY-type items (relics, fragments, key
	# tools like photograph). The Compendium panel groups these under
	# "Relics & Tools" through the `item_` prefix filter.
	if defn.item_type == ItemDef.ItemType.KEY:
		var entry_id: StringName = StringName("item_%s" % String(item_id))
		var was_unlocked: bool = GameState.unlocked_compendium.get(entry_id, false)
		unlock(entry_id)
		if not was_unlocked:
			EventBus.ui_toast.emit("Compendium: %s acquired." % defn.display_name, 2.5)
