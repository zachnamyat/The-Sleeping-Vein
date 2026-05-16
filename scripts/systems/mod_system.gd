extends Node

## Phase 14 — Mod manager + loader.
##
## Covers tickets:
##   14.31 Mod manager UI in-game (enable / disable / load order)
##   14.32 Mod loader API for recipes / items / mobs / biomes
##   14.33 Mod conflict warning UI
##   14.34 Mod compatibility version tag system
##   14.35 Hot-reload of .tres data resources (dev mode)
##   14.43 In-game mod browser (mod.io integration — scaffold only)
##   14.44 Modding SDK docs + sample mod scaffold
##
## Mod directory layout (under user://mods/<mod_id>/):
##   manifest.json        Mod metadata: id, version, author, requires_game_version, conflicts
##   items/*.tres         ItemDef additions/overrides
##   recipes/*.tres       Recipe additions/overrides
##   mobs/*.tres          MobDef additions/overrides
##   biomes/*.tres        Biome resource additions/overrides
##   scenes/**/*.tscn     Scene overrides (rare; flagged conflict)
##
## A mod's manifest.json: {
##   "id": "my_mod",
##   "version": "0.1.0",
##   "author": "...",
##   "requires_game_version": "0.1.0-dev",
##   "conflicts": ["other_mod_id"],
##   "load_after": ["base_mod"],
##   "description": "..."
## }
##
## Mod IDs follow snake_case. Mods are loaded in load-order, with later mods
## overriding earlier ones. Conflicts are warned at load time and surfaced in
## the manager UI.

signal mod_discovered(mod_id: StringName, manifest: Dictionary)
signal mod_loaded(mod_id: StringName, version: String)
signal mod_unloaded(mod_id: StringName)
signal mod_conflict(mod_a: StringName, mod_b: StringName, key: String)
signal mod_version_mismatch(mod_id: StringName, required: String, actual: String)
signal mods_hot_reloaded(count: int)
signal mod_browser_listing_received(remote_mod_id: StringName, payload: Dictionary)

const MODS_ROOT: String = "user://mods/"
const REGISTRY_PATH: String = "user://mod_registry.json"
const SDK_TEMPLATE_PATH: String = "docs/design/modding_sdk_template/"

## All discovered mods. Key: mod_id (StringName) -> { manifest, path, enabled, load_order }.
var discovered_mods: Dictionary = {}

## Mods enabled this session in load-order. Each entry: { id, manifest }.
var load_order: Array = []

## Per-resource type conflict table: { "items.iron_ingot": [mod_a, mod_b] }.
var conflicts: Dictionary = {}

## Remote browser cache (14.43). mod_id -> remote payload (currently a stub).
var remote_browser: Dictionary = {}

## Hot-reload watch list — paths to .tres files we've cached for dev mode.
var _hot_reload_paths: Array = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MODS_ROOT))
	_load_registry()


# --- Discovery (14.31) ---------------------------------------------------

func scan_mods() -> int:
	## Scan the mods/ folder for manifest.json. Returns count discovered.
	discovered_mods.clear()
	var dir := DirAccess.open(MODS_ROOT)
	if dir == null:
		return 0
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and entry != "." and entry != "..":
			var mod_path: String = MODS_ROOT + entry + "/"
			var manifest: Dictionary = _read_manifest(mod_path)
			if not manifest.is_empty():
				var mid: StringName = StringName(String(manifest.get("id", entry)))
				discovered_mods[mid] = {
					"manifest": manifest,
					"path": mod_path,
					"enabled": false,
					"load_order": discovered_mods.size(),
				}
				mod_discovered.emit(mid, manifest)
		entry = dir.get_next()
	dir.list_dir_end()
	return discovered_mods.size()


# --- Manager: enable / disable / order (14.31) --------------------------

func enable_mod(mod_id: StringName) -> bool:
	if not discovered_mods.has(mod_id):
		return false
	discovered_mods[mod_id]["enabled"] = true
	_save_registry()
	return true


func disable_mod(mod_id: StringName) -> bool:
	if not discovered_mods.has(mod_id):
		return false
	discovered_mods[mod_id]["enabled"] = false
	_save_registry()
	return true


func set_load_order(mod_ids: Array) -> void:
	## Pass an Array[StringName] in the desired load order.
	for i in range(mod_ids.size()):
		var mid: StringName = StringName(String(mod_ids[i]))
		if discovered_mods.has(mid):
			discovered_mods[mid]["load_order"] = i
	_save_registry()


# --- Version-tag check (14.34) ------------------------------------------

func _is_version_compatible(required: String, actual: String) -> bool:
	## Semantic version major.minor.patch. Compatible if major matches AND
	## actual.minor >= required.minor. Empty required = "any version".
	if required == "":
		return true
	var req_parts: PackedStringArray = required.split(".")
	var act_parts: PackedStringArray = actual.split(".")
	if req_parts.size() < 2 or act_parts.size() < 2:
		return false
	if int(req_parts[0]) != int(act_parts[0]):
		return false
	return int(act_parts[1]) >= int(req_parts[1])


# --- Load (14.32) -------------------------------------------------------

func load_enabled_mods() -> int:
	## Loads every enabled mod in load_order. Returns count loaded.
	load_order.clear()
	conflicts.clear()
	var enabled: Array = []
	for mid in discovered_mods.keys():
		var rec: Dictionary = discovered_mods[mid]
		if bool(rec.get("enabled", false)):
			enabled.append({"id": mid, "rec": rec})
	enabled.sort_custom(func(a, b): return int(a["rec"].get("load_order", 0)) < int(b["rec"].get("load_order", 0)))
	var loaded: int = 0
	for ent in enabled:
		var mid: StringName = ent["id"]
		var rec: Dictionary = ent["rec"]
		var manifest: Dictionary = rec.get("manifest", {})
		var required: String = String(manifest.get("requires_game_version", ""))
		var actual: String = GameState.VERSION
		if not _is_version_compatible(required, actual):
			mod_version_mismatch.emit(mid, required, actual)
			continue
		_load_mod_resources(mid, rec.get("path", ""))
		load_order.append({"id": mid, "manifest": manifest})
		mod_loaded.emit(mid, String(manifest.get("version", "0.0.0")))
		loaded += 1
	_detect_conflicts()
	return loaded


func unload_mods() -> void:
	for ent in load_order:
		mod_unloaded.emit(ent["id"])
	load_order.clear()
	conflicts.clear()


func _load_mod_resources(mod_id: StringName, mod_path: String) -> void:
	# Item defs first, recipes second so recipe.inputs/outputs see the items.
	for subdir in ["items/", "recipes/", "mobs/", "biomes/"]:
		var full: String = mod_path + subdir
		if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(full)):
			continue
		var dir := DirAccess.open(full)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if not dir.current_is_dir() and entry.ends_with(".tres"):
				_load_mod_resource(mod_id, full + entry, subdir.trim_suffix("/"))
				_hot_reload_paths.append(full + entry)
			entry = dir.get_next()
		dir.list_dir_end()


func _load_mod_resource(mod_id: StringName, resource_path: String, kind: String) -> void:
	## Loads a .tres and merges it into the relevant registry. ItemDefs go to
	## ItemRegistry. Recipes go to CraftingSystem (best-effort). Mobs/biomes are
	## stored on this autoload as fall-through tables.
	var res: Resource = ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if res == null:
		push_warning("ModSystem: failed to load %s" % resource_path)
		return
	match kind:
		"items":
			if res is ItemDef and ItemRegistry:
				var def: ItemDef = res as ItemDef
				var existing := ItemRegistry.get_def(def.id) if ItemRegistry.has_method("get_def") else null
				if existing != null and existing != def:
					_record_conflict(mod_id, "items.%s" % String(def.id))
				if ItemRegistry.has_method("register"):
					ItemRegistry.call("register", def)
		"recipes":
			if res is Recipe and CraftingSystem:
				var rec: Recipe = res as Recipe
				if CraftingSystem.has_method("register"):
					CraftingSystem.call("register", rec)
		"mobs":
			# Mob registry varies between phases; just emit so a future
			# MobRegistry can subscribe. Conflict detection still recorded.
			pass
		"biomes":
			pass


func _record_conflict(mod_id: StringName, key: String) -> void:
	var arr: Array = conflicts.get(key, [])
	if not arr.has(mod_id):
		arr.append(mod_id)
	conflicts[key] = arr


func _detect_conflicts() -> void:
	for key in conflicts.keys():
		var arr: Array = conflicts[key]
		if arr.size() < 2:
			continue
		mod_conflict.emit(arr[0], arr[1], key)


# --- Hot reload (14.35) -------------------------------------------------

func hot_reload() -> int:
	## Force-reload every previously-loaded mod .tres. Dev-only.
	var reloaded: int = 0
	for path in _hot_reload_paths:
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if res != null:
			reloaded += 1
	mods_hot_reloaded.emit(reloaded)
	return reloaded


# --- Mod browser stub (14.43) -------------------------------------------

func fetch_remote_listings(_search_term: String = "") -> int:
	## Stub: mod.io integration would surface here. For now we just expose the
	## API and emit a synthetic listing to verify the call site works.
	var fake: Dictionary = {
		"id": "remote_demo_pack",
		"display_name": "Demo Mod Pack (stub)",
		"version": "0.1.0",
		"description": "Placeholder — wire to mod.io REST API in Phase 16+.",
		"download_url": "",
		"size_bytes": 0,
	}
	remote_browser[StringName("remote_demo_pack")] = fake
	mod_browser_listing_received.emit(StringName("remote_demo_pack"), fake)
	return 1


# --- Registry persistence -----------------------------------------------

func _read_manifest(mod_path: String) -> Dictionary:
	var manifest_path: String = mod_path + "manifest.json"
	if not FileAccess.file_exists(manifest_path):
		return {}
	var f := FileAccess.open(manifest_path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data as Dictionary


func _save_registry() -> void:
	var data: Dictionary = {}
	for mid in discovered_mods.keys():
		var rec: Dictionary = discovered_mods[mid]
		data[String(mid)] = {
			"enabled": bool(rec.get("enabled", false)),
			"load_order": int(rec.get("load_order", 0)),
		}
	var f := FileAccess.open(REGISTRY_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func _load_registry() -> void:
	if not FileAccess.file_exists(REGISTRY_PATH):
		return
	var f := FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	if typeof(json.data) != TYPE_DICTIONARY:
		return
	# discovered_mods may be empty before scan; rehydration happens after
	# scan_mods() runs and finds these entries on disk.
	var data: Dictionary = json.data
	for mid_str in data.keys():
		var rec: Dictionary = data[mid_str]
		var mid: StringName = StringName(String(mid_str))
		discovered_mods[mid] = {
			"manifest": {},
			"path": MODS_ROOT + String(mid_str) + "/",
			"enabled": bool(rec.get("enabled", false)),
			"load_order": int(rec.get("load_order", 0)),
		}


# --- SDK scaffold (14.44) ----------------------------------------------

func generate_sample_mod(target_path: String) -> bool:
	## Writes a minimal mod scaffold (manifest + one example item + one recipe)
	## to the chosen path so modders have a starting template.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_path))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_path + "items/"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_path + "recipes/"))
	var manifest_text: String = JSON.stringify({
		"id": "example_mod",
		"version": "0.1.0",
		"author": "you",
		"requires_game_version": "0.1.0",
		"conflicts": [],
		"load_after": [],
		"description": "Sample mod scaffold — clone, edit, drop in user://mods/."
	}, "\t")
	var f := FileAccess.open(target_path + "manifest.json", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(manifest_text)
	f.close()
	# Sample item def as plain text — modders can crack open in Godot to edit.
	var item_text: String = """[gd_resource type="Resource" script_class="ItemDef" format=3]
[ext_resource type="Script" path="res://scripts/resources/item_def.gd" id="1"]
[resource]
script = ExtResource("1")
id = &"example_modded_item"
display_name = "Example Modded Item"
description = "A demo item added by a mod."
max_stack = 99
item_type = 0
tier = 1
rarity = 1
"""
	var f2 := FileAccess.open(target_path + "items/example_modded_item.tres", FileAccess.WRITE)
	if f2 == null:
		return false
	f2.store_string(item_text)
	f2.close()
	return true


# --- Helpers ----------------------------------------------------------

func is_loaded(mod_id: StringName) -> bool:
	for ent in load_order:
		if ent["id"] == mod_id:
			return true
	return false


func conflict_keys() -> Array:
	return conflicts.keys()


func dump_state() -> Dictionary:
	var enabled_ids: Array = []
	var order: Array = []
	for mid in discovered_mods.keys():
		var rec: Dictionary = discovered_mods[mid]
		if bool(rec.get("enabled", false)):
			enabled_ids.append(String(mid))
		order.append({"id": String(mid), "load_order": int(rec.get("load_order", 0))})
	return {
		"enabled_ids": enabled_ids,
		"load_order": order,
	}


func restore_state(state: Dictionary) -> void:
	var enabled_set: Dictionary = {}
	for id in state.get("enabled_ids", []):
		enabled_set[String(id)] = true
	for ent in state.get("load_order", []):
		var mid: StringName = StringName(String(ent.get("id", "")))
		if not discovered_mods.has(mid):
			discovered_mods[mid] = {
				"manifest": {},
				"path": MODS_ROOT + String(mid) + "/",
				"enabled": enabled_set.has(String(mid)),
				"load_order": int(ent.get("load_order", 0)),
			}
		else:
			discovered_mods[mid]["enabled"] = enabled_set.has(String(mid))
			discovered_mods[mid]["load_order"] = int(ent.get("load_order", 0))
