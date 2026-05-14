extends Control
class_name CraftingPanel

## Crafting UI. When a Workstation emits `interacted`, this panel opens with
## a recipe list filtered by station_id. Player clicks a recipe to craft it
## (if they have the inputs). Multi-craft via shift-click (3.18). Favorites
## via star button (3.16). Listens for `chest_ui` group; reuses container_ui.

@export var slot_size: Vector2 = Vector2(20, 20)

@onready var title: Label = $Panel/Title
@onready var list: VBoxContainer = $Panel/Scroll/RecipeList
@onready var search_box: LineEdit = $Panel/SearchBox
@onready var favorites_toggle: CheckButton = $Panel/FavoritesOnly

var _current_station: StringName = &""
var _adjacent_stations: Array[StringName] = []
var _search_filter: String = ""
var _favorites_only: bool = false

## Phase 3.19 / 3.42 — sequential crafting queue. Each entry is
## {recipe_id: StringName, remaining: int}. CraftingPanel ticks one craft per
## CRAFT_TICK_SECONDS until empty. Right-click on a queued row cancels and
## refunds reserved inputs (the queue reserves nothing — Inventory.try_craft
## consumes per-iter, so cancel just stops further ticks).
const CRAFT_TICK_SECONDS: float = 0.4
var _queue: Array = []
var _queue_timer: float = 0.0

const FAVORITES_KEY: String = "crafting_favorites"


func _ready() -> void:
	add_to_group("crafting_ui")
	visible = false
	if search_box:
		search_box.text_changed.connect(_on_search_changed)
	if favorites_toggle:
		favorites_toggle.toggled.connect(_on_favorites_toggled)
	if EventBus.recipe_unlocked.is_connected(_on_recipe_unlocked):
		pass
	else:
		EventBus.recipe_unlocked.connect(_on_recipe_unlocked)


func open_for(station_id: StringName, display_name: String) -> void:
	_current_station = station_id
	_adjacent_stations = [station_id]
	if title:
		title.text = "Station: %s" % display_name
	visible = true
	_hide_inventory_panel()
	_refresh_list()


## Phase 3.32 — Workstation calls this with its own id + every adjacent
## workstation's id. The panel concatenates recipes from all of them so a
## player at the bench-furnace junction sees both menus in one list.
func open_for_adjacent(station_id: StringName, display_name: String, adjacent_ids: Array) -> void:
	_current_station = station_id
	_adjacent_stations = []
	for sid in adjacent_ids:
		_adjacent_stations.append(StringName(sid))
	if not (_current_station in _adjacent_stations):
		_adjacent_stations.append(_current_station)
	if title:
		if _adjacent_stations.size() > 1:
			title.text = "Stations: %s (+%d nearby)" % [display_name, _adjacent_stations.size() - 1]
		else:
			title.text = "Station: %s" % display_name
	visible = true
	_hide_inventory_panel()
	_refresh_list()


## 480×270 viewport can't fit inventory + crafting + equipment side-by-side
## without all three squashing. Closing the inventory when crafting opens (and
## vice-versa, in inventory_panel.gd) keeps each panel readable. Player can
## still toggle between them with I/Tab and walking back into the workstation.
func _hide_inventory_panel() -> void:
	for n in get_tree().get_nodes_in_group("inventory_ui"):
		n.visible = false


func close_if_for(station_id: StringName) -> void:
	if _current_station == station_id:
		visible = false
		_queue.clear()
		_queue_timer = 0.0


func _on_search_changed(text: String) -> void:
	_search_filter = text.strip_edges().to_lower()
	_refresh_list()


func _on_favorites_toggled(pressed: bool) -> void:
	_favorites_only = pressed
	_refresh_list()


func _on_recipe_unlocked(recipe_id: StringName) -> void:
	# A small celebratory toast. Avoid double-toast on bulk starter unlocks
	# during initial CraftingSystem _ready().
	if not visible:
		return
	var rec: Recipe = CraftingSystem.get_recipe(recipe_id)
	if rec == null:
		return
	EventBus.ui_toast.emit("New recipe: %s" % rec.display_name, 1.5)
	_refresh_list()


func _is_favorite(recipe_id: StringName) -> bool:
	if Settings == null:
		return false
	var saved: Dictionary = Settings.get_value(FAVORITES_KEY, {})
	return bool(saved.get(String(recipe_id), false))


func _toggle_favorite(recipe_id: StringName) -> void:
	if Settings == null:
		return
	var saved: Dictionary = Settings.get_value(FAVORITES_KEY, {})
	var key := String(recipe_id)
	if saved.get(key, false):
		saved.erase(key)
	else:
		saved[key] = true
	Settings.set_value(FAVORITES_KEY, saved)
	_refresh_list()


func _process(delta: float) -> void:
	# Phase 3.19 — drain the craft queue one item per CRAFT_TICK_SECONDS.
	if _queue.is_empty():
		return
	_queue_timer -= delta
	if _queue_timer > 0.0:
		return
	_queue_timer = CRAFT_TICK_SECONDS
	var head = _queue[0]
	if not CraftingSystem.try_craft(StringName(head["recipe_id"])):
		# Out of materials — abort this entry; continue with the next.
		EventBus.ui_toast.emit("Queue stalled (missing materials).", 1.5)
		_queue.pop_front()
		_refresh_list()
		return
	head["remaining"] = int(head["remaining"]) - 1
	if head["remaining"] <= 0:
		_queue.pop_front()
	_refresh_list()


func _refresh_list() -> void:
	if list == null:
		return
	for child in list.get_children():
		child.queue_free()
	# Phase 3.32 — pull recipes from every adjacent station, then de-dup by id.
	var seen_ids: Dictionary = {}
	var recipes: Array = []
	var station_pool: Array = _adjacent_stations if not _adjacent_stations.is_empty() else [_current_station]
	for sid in station_pool:
		for r in CraftingSystem.recipes_for_station(sid):
			if seen_ids.has(r.id):
				continue
			seen_ids[r.id] = true
			recipes.append(r)
	# Render the queue strip first so the player can see / cancel pending crafts.
	if not _queue.is_empty():
		var queue_box := HBoxContainer.new()
		queue_box.custom_minimum_size = Vector2(360, 14)
		var qlbl := Label.new()
		qlbl.text = "Queue:"
		qlbl.modulate = Color(0.85, 0.66, 0.34, 1)
		qlbl.custom_minimum_size = Vector2(40, 14)
		queue_box.add_child(qlbl)
		for entry in _queue:
			var rec: Recipe = CraftingSystem.get_recipe(StringName(entry["recipe_id"]))
			var name: String = rec.display_name if rec else String(entry["recipe_id"])
			var cancel_btn := Button.new()
			cancel_btn.text = "%s x%d X" % [name, int(entry["remaining"])]
			cancel_btn.tooltip_text = "Click to cancel this queued batch."
			cancel_btn.custom_minimum_size = Vector2(80, 14)
			var rid := StringName(entry["recipe_id"])
			cancel_btn.pressed.connect(func() -> void: _cancel_queued(rid))
			queue_box.add_child(cancel_btn)
		list.add_child(queue_box)
	# Sort: favorites first, then alphabetical.
	recipes.sort_custom(func(a, b) -> bool:
		var fa: bool = _is_favorite(a.id)
		var fb: bool = _is_favorite(b.id)
		if fa != fb:
			return fa
		return a.display_name < b.display_name
	)
	for r in recipes:
		var rec: Recipe = r
		if _favorites_only and not _is_favorite(rec.id):
			continue
		if _search_filter != "" and rec.display_name.to_lower().find(_search_filter) < 0:
			continue
		var row := _make_row(rec)
		list.add_child(row)


func _make_row(rec: Recipe) -> Control:
	# Two-line card: top row is the recipe name with fav star + Craft button;
	# bottom row lists input materials with have/need counts. Single-line layout
	# kept crashing into the 8x8 font — names like "Auroric Ice Chestpiece" were
	# wider than any column we could fit on a 480-px viewport.
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 0)
	card.custom_minimum_size = Vector2(360, 28)
	# --- Top line: star + name + Craft button ---
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	top.custom_minimum_size = Vector2(360, 16)
	var fav_btn := Button.new()
	fav_btn.toggle_mode = true
	fav_btn.button_pressed = _is_favorite(rec.id)
	fav_btn.text = "*" if fav_btn.button_pressed else "."
	fav_btn.custom_minimum_size = Vector2(14, 14)
	fav_btn.tooltip_text = "Favorite"
	fav_btn.pressed.connect(func() -> void: _toggle_favorite(rec.id))
	top.add_child(fav_btn)
	var name_lbl := Label.new()
	name_lbl.text = rec.display_name
	name_lbl.modulate = Color(0.96, 0.90, 0.72, 1)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	top.add_child(name_lbl)
	var ok_to_craft: bool = _has_all_inputs(rec)
	var btn := Button.new()
	btn.text = "Craft"
	btn.custom_minimum_size = Vector2(52, 14)
	btn.tooltip_text = "Shift-click to craft as many as you can afford."
	btn.disabled = not ok_to_craft
	btn.pressed.connect(func() -> void: _on_craft_pressed(rec))
	top.add_child(btn)
	card.add_child(top)
	# --- Bottom line: input materials, indented so the eye groups them under
	# the recipe name they belong to.
	var inputs_lbl := Label.new()
	inputs_lbl.text = "  " + _format_inputs(rec)
	inputs_lbl.modulate = Color(0.80, 0.78, 0.65, 1) if ok_to_craft else Color(0.78, 0.45, 0.42, 1)
	inputs_lbl.custom_minimum_size = Vector2(360, 12)
	inputs_lbl.clip_text = true
	card.add_child(inputs_lbl)
	return card


func _has_all_inputs(rec: Recipe) -> bool:
	for inp in rec.inputs:
		var iid: StringName = StringName(inp.get("item_id", ""))
		var need: int = int(inp.get("count", 1))
		if Inventory.count_of(iid) < need:
			return false
	return true


func _format_inputs(rec: Recipe) -> String:
	var parts: PackedStringArray = []
	for inp in rec.inputs:
		var iid: StringName = StringName(inp.get("item_id", ""))
		var need: int = int(inp.get("count", 1))
		var defn: ItemDef = ItemRegistry.get_def(iid)
		var iname: String = defn.display_name if defn else String(iid)
		var have: int = Inventory.count_of(iid)
		parts.append("%s %d/%d" % [iname, have, need])
	return "  ".join(parts)


func _on_craft_pressed(rec: Recipe) -> void:
	# Phase 3.18 — multi-craft when Shift held. Crafts as many copies as the
	# player can afford in one click. Otherwise single craft.
	# Phase 3.19 — Ctrl-click queues 5 of the recipe to drain over time.
	var shift_held: bool = Input.is_key_pressed(KEY_SHIFT)
	var ctrl_held: bool = Input.is_key_pressed(KEY_CTRL)
	if ctrl_held:
		_queue.append({"recipe_id": rec.id, "remaining": 5})
		_queue_timer = CRAFT_TICK_SECONDS
		EventBus.ui_toast.emit("Queued 5x %s" % rec.display_name, 1.5)
		_refresh_list()
		return
	var max_n: int = 1 if not shift_held else _max_craftable(rec)
	var made: int = 0
	for _i in range(max_n):
		if not CraftingSystem.try_craft(rec.id):
			break
		made += 1
	# Phase 3.71 — single SFX cue regardless of bulk count, so multi-craft
	# doesn't blast the speakers.
	if made > 0 and AudioBus:
		AudioBus.play_sfx(&"craft_complete")
	if made == 0:
		EventBus.ui_toast.emit("Missing materials.", 1.5)
	elif made == 1:
		EventBus.ui_toast.emit("Crafted %s" % rec.display_name, 1.5)
	else:
		EventBus.ui_toast.emit("Crafted %s x%d" % [rec.display_name, made], 1.8)
	_refresh_list()


## Phase 3.42 — cancel a queued recipe entry (no resources to refund since
## queue ticks consume per-iter rather than reserving up front).
func _cancel_queued(recipe_id: StringName) -> void:
	for i in range(_queue.size()):
		if StringName(_queue[i].get("recipe_id", "")) == recipe_id:
			_queue.remove_at(i)
			EventBus.ui_toast.emit("Removed from queue.", 1.0)
			_refresh_list()
			return


func _max_craftable(rec: Recipe) -> int:
	var max_n: int = 99
	for inp in rec.inputs:
		var iid: StringName = StringName(inp.get("item_id", ""))
		var need: int = int(inp.get("count", 1))
		if need <= 0:
			continue
		var have: int = Inventory.count_of(iid)
		var per_item: int = have / need
		if per_item < max_n:
			max_n = per_item
	return max(0, max_n)
