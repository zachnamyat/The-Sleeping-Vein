extends Node

## Loads all ItemDef .tres files from resources/items/ at startup and indexes by id.
## Provides `get_def(id)` for fast lookup.

const ITEMS_ROOT: String = "res://resources/items/"

var _defs: Dictionary = {}


func _ready() -> void:
	_scan_directory(ITEMS_ROOT)


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
			var res := load(full) as ItemDef
			if res != null and res.id != &"":
				_defs[res.id] = res
		entry = dir.get_next()
	dir.list_dir_end()


func get_def(item_id: StringName) -> ItemDef:
	return _defs.get(item_id)


func has(item_id: StringName) -> bool:
	return _defs.has(item_id)


func all_ids() -> Array:
	return _defs.keys()
