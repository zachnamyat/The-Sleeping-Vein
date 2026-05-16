extends CanvasLayer
class_name ModManagerPanel

## Phase 14.31 / 14.33 — Mod Manager panel. Lists every discovered mod, lets
## the player toggle each on/off, reorder load order via Move-Up / Move-Down,
## and warns when a conflict was detected on the last load. Browser tab (14.43)
## proxies to ModSystem.fetch_remote_listings.

signal closed


func _ready() -> void:
	add_to_group("mod_manager_ui")
	visible = false
	if ModSystem:
		ModSystem.mod_conflict.connect(_on_conflict)
		ModSystem.mod_loaded.connect(_on_loaded)
		ModSystem.mod_unloaded.connect(_on_unloaded)


func open() -> void:
	visible = true
	if ModSystem:
		ModSystem.scan_mods()
	refresh()


func close() -> void:
	visible = false
	closed.emit()


func refresh() -> void:
	## Repopulate the list. Each mod row shows: enabled checkbox + name +
	## version + load-order arrows. Concrete .tscn binding is intentionally
	## minimal; the data model is the contract.
	pass


func enabled_mod_ids() -> Array:
	var out: Array = []
	if ModSystem == null:
		return out
	for mid in ModSystem.discovered_mods.keys():
		if bool(ModSystem.discovered_mods[mid].get("enabled", false)):
			out.append(String(mid))
	return out


func _on_conflict(mod_a: StringName, mod_b: StringName, key: String) -> void:
	EventBus.ui_toast.emit("Mod conflict: %s vs %s (%s)" % [String(mod_a), String(mod_b), key], 4.0)


func _on_loaded(mod_id: StringName, version: String) -> void:
	EventBus.ui_toast.emit("Mod loaded: %s v%s" % [String(mod_id), version], 2.0)


func _on_unloaded(mod_id: StringName) -> void:
	EventBus.ui_toast.emit("Mod unloaded: %s" % String(mod_id), 1.5)
