extends Node

## Phase 15 — Cosmetics + visual-equip manager.
## Owns:
##   3.36 item dyeing — per-slot hue overrides for the rendered visual.
##   3.37 wardrobe / outfit save slots — up to 6 named outfits, snapshot of all
##        cosmetic slots, switch costs 0 coins (purely cosmetic).
##   3.62 helmet rendered on player head
##   3.63 cape / cloak animation slot (back-layer)
##   3.64 off-hand item rendered on player (shield / lantern)
##   3.65 backpack visual (visible bag on back-layer)
##   3.68 cosmetic-only hat slot (separate from helmet armor)
##   3.69 pet collar / cosmetic accessory customization
##
## The actual rendering lives in PlayerVisualLayers (see scripts/player/);
## this autoload is the data store + signal broadcaster.

const WARDROBE_SLOTS: int = 6

# Visual layers we expose.
const LAYERS: Array[StringName] = [
	&"helmet", &"chest", &"legs", &"boots", &"back", &"off_hand",
	&"cosmetic_hat", &"cape", &"backpack", &"pet_collar",
]

signal dye_applied(slot: StringName, color: Color)
signal outfit_saved(index: int, label: String)
signal outfit_loaded(index: int)
signal visual_layer_set(layer: StringName, item_id: StringName)


# Per-layer current item_id (display only — actual stat-bearing item lives in
# Inventory.equipment). Distinct so a player can show one helmet on the head
# while wearing a different actual helmet for stats. Or hide visuals.
var visual_layers: Dictionary = {}      # layer StringName -> item_id StringName
var visual_layers_hidden: Dictionary = {}  # layer -> bool (true = render nothing)

# Per-layer dye color override. Multiplied into the sprite modulate.
var dye_colors: Dictionary = {}         # layer StringName -> Color

# Wardrobe — array of dicts, each: { label, layers: { layer -> item_id }, dyes: { layer -> color } }.
var wardrobe: Array[Dictionary] = []
var active_wardrobe_index: int = -1


func _ready() -> void:
	# Initialize empty outfits.
	wardrobe.clear()
	for i in WARDROBE_SLOTS:
		wardrobe.append({"label": "Outfit %d" % (i + 1), "layers": {}, "dyes": {}})
	for l in LAYERS:
		visual_layers[l] = &""
		visual_layers_hidden[l] = false
		dye_colors[l] = Color(1, 1, 1, 1)


# ---------- Dye (3.36) ----------

func apply_dye(layer: StringName, color: Color) -> bool:
	if layer not in LAYERS:
		return false
	dye_colors[layer] = color
	dye_applied.emit(layer, color)
	EventBus.phase15_cosmetic_dye_applied.emit(layer, color)
	return true


func reset_dye(layer: StringName) -> void:
	if layer in LAYERS:
		dye_colors[layer] = Color(1, 1, 1, 1)
		dye_applied.emit(layer, dye_colors[layer])


func get_dye(layer: StringName) -> Color:
	return Color(dye_colors.get(layer, Color(1, 1, 1, 1)))


# ---------- Layer visuals (3.62-3.65 + 3.68 / 3.69) ----------

func set_visual_layer(layer: StringName, item_id: StringName) -> bool:
	if layer not in LAYERS:
		return false
	visual_layers[layer] = item_id
	visual_layer_set.emit(layer, item_id)
	EventBus.phase15_visual_layer_changed.emit(layer, item_id)
	return true


func get_visual_layer(layer: StringName) -> StringName:
	return StringName(String(visual_layers.get(layer, "")))


func set_layer_hidden(layer: StringName, hidden: bool) -> void:
	if layer in LAYERS:
		visual_layers_hidden[layer] = hidden
		EventBus.phase15_visual_layer_changed.emit(layer, &"")


func is_layer_hidden(layer: StringName) -> bool:
	return bool(visual_layers_hidden.get(layer, false))


# ---------- Wardrobe (3.37) ----------

func save_outfit(index: int, label: String = "") -> bool:
	if index < 0 or index >= WARDROBE_SLOTS:
		return false
	var rec_label: String = label if label != "" else "Outfit %d" % (index + 1)
	var layers_copy: Dictionary = {}
	for k in visual_layers.keys():
		layers_copy[String(k)] = String(visual_layers[k])
	var dyes_copy: Dictionary = {}
	for k in dye_colors.keys():
		var c: Color = dye_colors[k]
		dyes_copy[String(k)] = [c.r, c.g, c.b, c.a]
	wardrobe[index] = {"label": rec_label, "layers": layers_copy, "dyes": dyes_copy}
	outfit_saved.emit(index, rec_label)
	return true


func load_outfit(index: int) -> bool:
	if index < 0 or index >= WARDROBE_SLOTS:
		return false
	var rec: Dictionary = wardrobe[index]
	if rec.is_empty():
		return false
	var layers_in: Dictionary = rec.get("layers", {})
	for k in layers_in.keys():
		visual_layers[StringName(String(k))] = StringName(String(layers_in[k]))
	var dyes_in: Dictionary = rec.get("dyes", {})
	for k in dyes_in.keys():
		var c_arr: Array = dyes_in[k]
		if c_arr.size() >= 4:
			dye_colors[StringName(String(k))] = Color(float(c_arr[0]), float(c_arr[1]), float(c_arr[2]), float(c_arr[3]))
	active_wardrobe_index = index
	outfit_loaded.emit(index)
	EventBus.phase15_wardrobe_outfit_changed.emit(index)
	# Re-broadcast every layer so any visual rebuilds.
	for l in LAYERS:
		EventBus.phase15_visual_layer_changed.emit(l, get_visual_layer(l))
	return true


func rename_outfit(index: int, label: String) -> bool:
	if index < 0 or index >= WARDROBE_SLOTS:
		return false
	wardrobe[index]["label"] = label
	return true


# ---------- Save round-trip ----------

func dump_state() -> Dictionary:
	var out: Dictionary = {"layers": {}, "dyes": {}, "hidden": {}, "wardrobe": [], "active_index": active_wardrobe_index}
	for k in visual_layers.keys():
		out["layers"][String(k)] = String(visual_layers[k])
	for k in dye_colors.keys():
		var c: Color = dye_colors[k]
		out["dyes"][String(k)] = [c.r, c.g, c.b, c.a]
	for k in visual_layers_hidden.keys():
		out["hidden"][String(k)] = bool(visual_layers_hidden[k])
	for entry in wardrobe:
		out["wardrobe"].append(entry.duplicate(true))
	return out


func restore_state(d: Dictionary) -> void:
	if d.is_empty():
		return
	var layers_in: Dictionary = d.get("layers", {})
	for k in layers_in.keys():
		visual_layers[StringName(String(k))] = StringName(String(layers_in[k]))
	var dyes_in: Dictionary = d.get("dyes", {})
	for k in dyes_in.keys():
		var arr: Array = dyes_in[k]
		if arr.size() >= 4:
			dye_colors[StringName(String(k))] = Color(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
	var hidden_in: Dictionary = d.get("hidden", {})
	for k in hidden_in.keys():
		visual_layers_hidden[StringName(String(k))] = bool(hidden_in[k])
	var wardrobe_in: Array = d.get("wardrobe", [])
	wardrobe.clear()
	for entry in wardrobe_in:
		wardrobe.append((entry as Dictionary).duplicate(true))
	while wardrobe.size() < WARDROBE_SLOTS:
		wardrobe.append({"label": "Outfit %d" % (wardrobe.size() + 1), "layers": {}, "dyes": {}})
	active_wardrobe_index = int(d.get("active_index", -1))
