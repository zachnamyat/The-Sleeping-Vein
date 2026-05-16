extends Node

## Phase 15 — Localization scaffolding manager.
## Augments the I18n autoload with:
##   15.9 — locale scaffolding (per-locale JSON discovery + missing-key audit)
##   15.72 — RTL text rendering hint for Old Vesari (right-to-left layout flag)
##   15.74 — translation editor / community pipeline (export + import CSV)
##   15.75 — locale auto-detect on first launch
##
## The actual string lookup stays in I18n; this autoload owns the *meta*
## (available locales, RTL flag, fallback chain, missing-key tracking).

const SUPPORTED_LOCALES: Array[StringName] = [
	&"en", &"vesari", &"de", &"fr", &"es", &"pt-br", &"ja", &"zh-cn", &"ko", &"ru",
]

## Locales rendered right-to-left.
const RTL_LOCALES: Array[StringName] = [
	&"vesari", &"ar", &"he",
]

signal locale_auto_detected(locale: StringName)
signal missing_key_logged(key: String, locale: StringName)
signal csv_exported(path: String, rows: int)
signal csv_imported(path: String, rows: int)


var auto_detected_locale: StringName = &"en"
var missing_keys: Dictionary = {}   # locale -> { key -> count }
var fallback_chain: Array[StringName] = [&"en"]


func _ready() -> void:
	# 15.75 — auto-detect on first launch.
	if Settings and Settings.get_value("loc.first_launch_done", false) == false:
		_autodetect()
		Settings.set_value("loc.first_launch_done", true)


# ---------- Auto-detect (15.75) ----------

func _autodetect() -> void:
	var sys_locale: String = OS.get_locale()  # "en_US.UTF-8"
	var first: String = sys_locale.get_slice("_", 0).to_lower()
	var detected: StringName = &"en"
	for s in SUPPORTED_LOCALES:
		if String(s) == first or String(s).begins_with(first + "-"):
			detected = s
			break
	auto_detected_locale = detected
	locale_auto_detected.emit(detected)
	# Don't auto-apply — the first-run wizard offers the user the choice.


# ---------- RTL (15.72) ----------

func is_rtl_locale(locale: StringName) -> bool:
	return locale in RTL_LOCALES


func apply_rtl_to_control(c: Control) -> void:
	if c == null:
		return
	if is_rtl_locale(I18n.current_locale()):
		c.layout_direction = Control.LAYOUT_DIRECTION_RTL
	else:
		c.layout_direction = Control.LAYOUT_DIRECTION_LTR


# ---------- Missing-key tracking (15.74) ----------

func note_missing_key(key: String) -> void:
	var locale: StringName = I18n.current_locale()
	var inner: Dictionary = missing_keys.get(locale, {})
	inner[key] = int(inner.get(key, 0)) + 1
	missing_keys[locale] = inner
	missing_key_logged.emit(key, locale)


func missing_key_count(locale: StringName) -> int:
	var inner: Dictionary = missing_keys.get(locale, {})
	return inner.size()


# ---------- Translation pipeline (15.74) ----------

## Export every key/value pair of the given locale as a CSV file.
## Format: key,en,locale  — for translators to fill the third column.
func export_csv(locale: StringName, out_path: String) -> bool:
	if I18n == null:
		return false
	var en_path: String = "res://assets/i18n/en.json"
	var loc_path: String = "res://assets/i18n/" + String(locale) + ".json"
	var en_dict: Dictionary = _read_json(en_path)
	var loc_dict: Dictionary = _read_json(loc_path)
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string("key,en,%s\n" % String(locale))
	var rows: int = 0
	for k in en_dict.keys():
		var key_str: String = String(k)
		if key_str.begins_with("_"):
			continue
		var en_val: String = String(en_dict[k]).replace("\"", "\"\"")
		var loc_val: String = String(loc_dict.get(k, "")).replace("\"", "\"\"")
		file.store_string("\"%s\",\"%s\",\"%s\"\n" % [key_str, en_val, loc_val])
		rows += 1
	file.close()
	csv_exported.emit(out_path, rows)
	return true


## Import a CSV back into a locale JSON. The third column wins.
func import_csv(locale: StringName, csv_path: String) -> bool:
	if not FileAccess.file_exists(csv_path):
		return false
	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return false
	var out: Dictionary = {}
	# Skip header.
	var first_line: String = file.get_line()
	if first_line == "":
		file.close()
		return false
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.strip_edges() == "":
			continue
		var parts: PackedStringArray = _parse_csv_line(line)
		if parts.size() < 3:
			continue
		var key: String = parts[0]
		var val: String = parts[2]
		out[key] = val
	file.close()
	var out_path: String = "res://assets/i18n/" + String(locale) + ".json"
	var w := FileAccess.open(out_path, FileAccess.WRITE)
	if w == null:
		# res:// may be read-only at runtime; export to user:// fallback.
		out_path = "user://i18n/" + String(locale) + ".json"
		DirAccess.make_dir_recursive_absolute("user://i18n/")
		w = FileAccess.open(out_path, FileAccess.WRITE)
		if w == null:
			return false
	w.store_string(JSON.stringify(out, "\t"))
	w.close()
	csv_imported.emit(csv_path, out.size())
	return true


func _parse_csv_line(line: String) -> PackedStringArray:
	# Minimal CSV parser: handles "..." quoted, "" escaped quote, comma separators.
	var out := PackedStringArray()
	var cur := ""
	var in_q := false
	var i := 0
	while i < line.length():
		var c: String = line.substr(i, 1)
		if in_q:
			if c == "\"":
				if i + 1 < line.length() and line.substr(i + 1, 1) == "\"":
					cur += "\""
					i += 2
					continue
				in_q = false
				i += 1
				continue
			cur += c
			i += 1
		else:
			if c == "\"":
				in_q = true
				i += 1
			elif c == ",":
				out.append(cur)
				cur = ""
				i += 1
			else:
				cur += c
				i += 1
	out.append(cur)
	return out


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


# ---------- Apply ----------

func apply_locale(locale: StringName) -> bool:
	if not (locale in SUPPORTED_LOCALES):
		return false
	if I18n.set_locale(locale):
		EventBus.phase15_locale_changed.emit(locale)
		return true
	return false
