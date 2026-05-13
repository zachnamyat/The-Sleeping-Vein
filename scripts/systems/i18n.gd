extends Node

## Ticket 0.18 — i18n string-table loader.
## Loads assets/i18n/<locale>.json on boot and exposes `tr(key, args)` lookup.
## Falls back to the key itself when missing so untranslated strings are visibly broken
## rather than silently empty. Keys use domain.subdomain.snake_case.
##
## Usage from GDScript:
##     I18n.t("pause.saved")                   # -> "Saved."
##     I18n.t("loom.slivers_remaining", [n])   # -> "Slivers remaining: 70000"
##
## Switching locale at runtime:
##     I18n.set_locale("vesari")
##
## Old Vesari (lore §10) goes in assets/i18n/vesari.json when written.

const I18N_DIR: String = "res://assets/i18n/"
const FALLBACK_LOCALE: StringName = &"en"

signal locale_changed(locale: StringName)

var _strings: Dictionary = {}
var _fallback: Dictionary = {}
var _locale: StringName = FALLBACK_LOCALE


func _ready() -> void:
	_fallback = _load_locale_file(FALLBACK_LOCALE)
	_strings = _fallback
	_locale = FALLBACK_LOCALE


func set_locale(locale: StringName) -> bool:
	if locale == _locale:
		return true
	var loaded := _load_locale_file(locale)
	if loaded.is_empty():
		push_warning("I18n: locale '%s' not found, staying on '%s'" % [locale, _locale])
		return false
	_strings = loaded
	_locale = locale
	locale_changed.emit(locale)
	return true


func current_locale() -> StringName:
	return _locale


func t(key: String, args: Array = []) -> String:
	var raw: Variant = _strings.get(key, _fallback.get(key, key))
	var s := String(raw)
	if args.is_empty():
		return s
	return s % args


func has_key(key: String) -> bool:
	return _strings.has(key) or _fallback.has(key)


func _load_locale_file(locale: StringName) -> Dictionary:
	var path: String = I18N_DIR + String(locale) + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("I18n: cannot open %s" % path)
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("I18n: parse error in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("I18n: %s is not a JSON object" % path)
		return {}
	var out: Dictionary = {}
	for k in (json.data as Dictionary).keys():
		var key_str := String(k)
		if key_str.begins_with("_"):
			continue # _doc, _locale, _name metadata keys
		out[key_str] = (json.data as Dictionary)[k]
	return out
