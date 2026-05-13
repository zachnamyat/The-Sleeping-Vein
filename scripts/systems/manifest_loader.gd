extends Node
class_name ManifestLoader

## Asset manifest loader.
## Reads assets/manifest.json, indexes entries by id, and returns either the final
## texture or a magenta placeholder for any entry whose status != "final".
## The placeholder is the manifest contract per docs/design/01_asset_pipeline.md §Stage 5.

const MANIFEST_PATH: String = "res://assets/manifest.json"

const PLACEHOLDER_SIZE: int = 16
const PLACEHOLDER_COLOR: Color = Color(1.0, 0.0, 1.0, 1.0)

static var _entries: Dictionary = {}
static var _placeholder_texture: Texture2D = null
static var _loaded: bool = false


static func load_manifest() -> void:
	if _loaded:
		return
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_error("ManifestLoader: cannot open %s" % MANIFEST_PATH)
		_loaded = true
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("ManifestLoader: JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		_loaded = true
		return
	var data: Dictionary = json.data
	for entry in data.get("assets", []):
		var id: String = entry.get("id", "")
		if id == "":
			continue
		_entries[id] = entry
	_loaded = true


static func get_entry(id: StringName) -> Dictionary:
	load_manifest()
	return _entries.get(String(id), {})


static func has_entry(id: StringName) -> bool:
	load_manifest()
	return _entries.has(String(id))


static func is_final(id: StringName) -> bool:
	var e := get_entry(id)
	return e.get("status", "needed") == "final"


static func get_texture(id: StringName) -> Texture2D:
	var e := get_entry(id)
	var status: String = e.get("status", "needed")
	if status != "final":
		return _get_placeholder()
	var path: String = e.get("path", "")
	if path == "":
		return _get_placeholder()
	var godot_path := "res://" + path if not path.begins_with("res://") else path
	if not ResourceLoader.exists(godot_path):
		push_warning("ManifestLoader: asset %s marked final but path %s missing on disk" % [id, godot_path])
		return _get_placeholder()
	var tex: Texture2D = load(godot_path) as Texture2D
	if tex == null:
		return _get_placeholder()
	return tex


static func _get_placeholder() -> Texture2D:
	if _placeholder_texture != null:
		return _placeholder_texture
	var img := Image.create(PLACEHOLDER_SIZE, PLACEHOLDER_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(PLACEHOLDER_COLOR)
	_placeholder_texture = ImageTexture.create_from_image(img)
	return _placeholder_texture


static func list_ids() -> PackedStringArray:
	load_manifest()
	var ids := PackedStringArray()
	for k in _entries.keys():
		ids.append(k)
	return ids


static func entries_by_status(status: String) -> Array:
	load_manifest()
	var out: Array = []
	for k in _entries.keys():
		if _entries[k].get("status", "needed") == status:
			out.append(_entries[k])
	return out


static func reload() -> void:
	_entries.clear()
	_placeholder_texture = null
	_loaded = false
	load_manifest()
