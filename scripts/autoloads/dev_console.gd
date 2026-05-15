extends Node

## Dev console / cheat menu. Press F1 (or backtick) to toggle.
##
## Type `help` to list commands, `help <cmd>` for usage on one. All commands
## fail gracefully if their prerequisites aren't met (e.g. no player in the
## scene yet). Designed for solo playtesting in Phases 5+.

const TOGGLE_KEYCODES: Array[int] = [KEY_F1, KEY_QUOTELEFT]
const HISTORY_LIMIT: int = 100
const DEFAULT_SAVE_SLOT: String = "dev_quicksave"
const CHUNK_TILES: int = 64
const TILE_PX: int = 16

const SKILL_ALIASES: Dictionary = {
	"mining": &"skill_mining",
	"running": &"skill_running",
	"melee": &"skill_melee",
	"ranged": &"skill_ranged",
	"vitality": &"skill_vitality",
	"crafting": &"skill_crafting",
	"gardening": &"skill_gardening",
	"fishing": &"skill_fishing",
	"cooking": &"skill_cooking",
	"magic": &"skill_magic",
	"summoning": &"skill_summoning",
	"explosives": &"skill_explosives",
}

const PHASE_TO_FRACTION: Dictionary = {
	"dawn":  0.00,
	"day":   0.22,
	"dusk":  0.66,
	"night": 0.86,
}

## Dev flags consulted by gameplay (PlayerController multiplies its velocity by
## dev_speed_mult, etc.). Mutated from command handlers.
var dev_speed_mult: float = 1.0
var noclip_active: bool = false
var godmode_active: bool = false

var _layer: CanvasLayer
var _panel: PanelContainer
var _output: RichTextLabel
var _input_line: LineEdit
var _open: bool = false
var _history: Array[String] = []
var _history_idx: int = -1

## Stored once when noclip turns on so we can restore the original mask. Sentinel
## -1 means "noclip is currently off (nothing stashed)".
var _saved_player_mask: int = -1

var _commands: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_commands()
	_build_ui()


# ============================================================
# UI construction (no .tscn — keeps the console fully autoload)
# ============================================================

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100  # above HUD (CanvasLayer default 1)
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	_panel = PanelContainer.new()
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = 4
	_panel.offset_right = -4
	_panel.offset_top = 4
	_panel.offset_bottom = 156
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.06, 0.92)
	sb.border_color = Color(0.55, 0.50, 0.35, 1.0)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	_panel.add_theme_stylebox_override("panel", sb)
	_layer.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	_panel.add_child(vbox)

	_output = RichTextLabel.new()
	_output.bbcode_enabled = true
	_output.scroll_following = true
	_output.fit_content = false
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.custom_minimum_size = Vector2(0, 124)
	_output.add_theme_font_size_override("normal_font_size", 8)
	_output.add_theme_font_size_override("bold_font_size", 8)
	_output.add_theme_font_size_override("italics_font_size", 8)
	_output.add_theme_font_size_override("mono_font_size", 8)
	_output.add_theme_color_override("default_color", Color(0.92, 0.88, 0.74))
	vbox.add_child(_output)
	_output.append_text("[color=#888]Dev Console — F1 or ` to close. Type [b]help[/b] for commands.[/color]\n")

	_input_line = LineEdit.new()
	_input_line.process_mode = Node.PROCESS_MODE_ALWAYS
	_input_line.placeholder_text = "> command"
	_input_line.custom_minimum_size = Vector2(0, 14)
	_input_line.add_theme_font_size_override("font_size", 8)
	_input_line.text_submitted.connect(_on_submitted)
	_input_line.gui_input.connect(_on_input_gui)
	vbox.add_child(_input_line)


# ============================================================
# Input
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = (event as InputEventKey).keycode
		if k in TOGGLE_KEYCODES:
			toggle()
			get_viewport().set_input_as_handled()


func toggle() -> void:
	_open = not _open
	_panel.visible = _open
	get_tree().paused = _open
	if _open:
		_input_line.clear()
		_input_line.grab_focus()
	else:
		_input_line.release_focus()


func _on_input_gui(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = (event as InputEventKey).keycode
	if k == KEY_UP:
		_history_nav(-1)
		_input_line.accept_event()
	elif k == KEY_DOWN:
		_history_nav(1)
		_input_line.accept_event()
	elif k == KEY_ESCAPE or k in TOGGLE_KEYCODES:
		toggle()
		_input_line.accept_event()


func _history_nav(delta: int) -> void:
	if _history.is_empty():
		return
	if _history_idx == -1:
		_history_idx = _history.size()
	_history_idx = clampi(_history_idx + delta, 0, _history.size())
	if _history_idx >= _history.size():
		_input_line.text = ""
	else:
		_input_line.text = _history[_history_idx]
	_input_line.caret_column = _input_line.text.length()


func _on_submitted(text: String) -> void:
	var stripped: String = text.strip_edges()
	_input_line.clear()
	if stripped == "":
		return
	_history.append(stripped)
	if _history.size() > HISTORY_LIMIT:
		_history.remove_at(0)
	_history_idx = -1
	log_line("[color=#888]> %s[/color]" % stripped)
	var parts: PackedStringArray = stripped.split(" ", false)
	if parts.is_empty():
		return
	var name: String = parts[0].to_lower()
	var args: PackedStringArray = parts.slice(1)
	if not _commands.has(name):
		err("unknown command '%s'. Type [b]help[/b] for the list." % name)
		return
	var entry: Dictionary = _commands[name]
	var fn: Callable = entry["fn"]
	fn.call(args)


# ============================================================
# Output helpers
# ============================================================

func log_line(msg: String) -> void:
	_output.append_text(msg + "\n")


func ok(msg: String) -> void:
	log_line("[color=#9be07f]%s[/color]" % msg)


func err(msg: String) -> void:
	log_line("[color=#ff8484]%s[/color]" % msg)


func info(msg: String) -> void:
	log_line("[color=#cfc8b0]%s[/color]" % msg)


# ============================================================
# Command registry
# ============================================================

func _register_commands() -> void:
	_commands = {
		# Meta
		"help":         {"fn": Callable(self, "_cmd_help"),         "args": "[cmd]",                  "desc": "List commands; or help for one"},
		"echo":         {"fn": Callable(self, "_cmd_echo"),         "args": "<text...>",              "desc": "Print text"},
		"clear":        {"fn": Callable(self, "_cmd_clear"),        "args": "",                       "desc": "Clear console output"},
		"close":        {"fn": Callable(self, "_cmd_close"),        "args": "",                       "desc": "Close the console"},
		# Inventory / items
		"give":         {"fn": Callable(self, "_cmd_give"),         "args": "<item_id> [count]",      "desc": "Add items to inventory"},
		"take":         {"fn": Callable(self, "_cmd_take"),         "args": "<item_id> [count]",      "desc": "Remove items from inventory"},
		"clear_inv":    {"fn": Callable(self, "_cmd_clear_inv"),    "args": "",                       "desc": "Empty inventory"},
		"items":        {"fn": Callable(self, "_cmd_items"),        "args": "[filter]",               "desc": "List item IDs (optionally filtered)"},
		"equip_best":   {"fn": Callable(self, "_cmd_equip_best"),   "args": "",                       "desc": "Auto-equip best armor in bag"},
		# Player
		"godmode":      {"fn": Callable(self, "_cmd_godmode"),      "args": "[on|off]",               "desc": "Toggle invulnerability"},
		"heal":         {"fn": Callable(self, "_cmd_heal"),         "args": "[amount]",               "desc": "Heal player (default full)"},
		"damage":       {"fn": Callable(self, "_cmd_damage"),       "args": "<amount>",               "desc": "Damage the player"},
		"kill":         {"fn": Callable(self, "_cmd_kill"),         "args": "",                       "desc": "Kill the player"},
		"revive":       {"fn": Callable(self, "_cmd_revive"),       "args": "",                       "desc": "Revive at full HP"},
		"setmaxhp":     {"fn": Callable(self, "_cmd_setmaxhp"),     "args": "<amount>",               "desc": "Set max HP"},
		"noclip":       {"fn": Callable(self, "_cmd_noclip"),       "args": "[on|off]",               "desc": "Walk through walls"},
		"speed":        {"fn": Callable(self, "_cmd_speed"),        "args": "<mult>",                 "desc": "Move-speed multiplier (1.0 = normal)"},
		"pos":          {"fn": Callable(self, "_cmd_pos"),          "args": "",                       "desc": "Print player position"},
		# World
		"tp":           {"fn": Callable(self, "_cmd_tp"),           "args": "<x> <y>",                "desc": "Teleport to world pos"},
		"tp_tile":      {"fn": Callable(self, "_cmd_tp_tile"),      "args": "<tx> <ty>",              "desc": "Teleport to tile coord"},
		"tp_chunk":     {"fn": Callable(self, "_cmd_tp_chunk"),     "args": "<cx> <cy>",              "desc": "Teleport to chunk center"},
		"tp_spawn":     {"fn": Callable(self, "_cmd_tp_spawn"),     "args": "",                       "desc": "Teleport to bound respawn point"},
		"setspawn":     {"fn": Callable(self, "_cmd_setspawn"),     "args": "",                       "desc": "Bind respawn to current pos"},
		"time":         {"fn": Callable(self, "_cmd_time"),         "args": "<dawn|day|dusk|night>",  "desc": "Set world-clock phase"},
		"seed":         {"fn": Callable(self, "_cmd_seed"),         "args": "",                       "desc": "Print world seed"},
		"reveal":       {"fn": Callable(self, "_cmd_reveal"),       "args": "[radius]",               "desc": "Reveal chunks around player"},
		# Progression
		"xp":           {"fn": Callable(self, "_cmd_xp"),           "args": "<skill> <amount>",       "desc": "Grant skill XP"},
		"level":        {"fn": Callable(self, "_cmd_level"),        "args": "<skill> <level>",        "desc": "Force-set skill level"},
		"slivers":      {"fn": Callable(self, "_cmd_slivers"),      "args": "<amount>",               "desc": "Set Aphelion slivers remaining"},
		"defeat":       {"fn": Callable(self, "_cmd_defeat"),       "args": "<boss_id>",              "desc": "Mark boss defeated"},
		"bosses":       {"fn": Callable(self, "_cmd_bosses"),       "args": "",                       "desc": "List defeated bosses"},
		"talents":      {"fn": Callable(self, "_cmd_talents"),      "args": "[amount]",               "desc": "Grant talent points (default 1)"},
		# System
		"save":         {"fn": Callable(self, "_cmd_save"),         "args": "[slot]",                 "desc": "Save (default dev_quicksave)"},
		"load":         {"fn": Callable(self, "_cmd_load"),         "args": "[slot]",                 "desc": "Load (default dev_quicksave)"},
		"reload_scene": {"fn": Callable(self, "_cmd_reload_scene"), "args": "",                       "desc": "Reload current scene"},
		"quit_game":    {"fn": Callable(self, "_cmd_quit_game"),    "args": "",                       "desc": "Exit the application"},
	}


# ============================================================
# Helpers
# ============================================================

func _player() -> Node:
	if get_tree() == null:
		return null
	var nodes: Array = get_tree().get_nodes_in_group("player")
	return nodes[0] if not nodes.is_empty() else null


func _resolve_skill(arg: String) -> StringName:
	var lower: String = arg.to_lower()
	if SKILL_ALIASES.has(lower):
		return SKILL_ALIASES[lower]
	var sn := StringName(lower)
	if sn in SkillSystem.ALL_SKILLS:
		return sn
	return &""


func _parse_int(s: String, default_val: int = 0) -> int:
	return int(s) if s.is_valid_int() else default_val


func _parse_float(s: String, default_val: float = 0.0) -> float:
	return float(s) if s.is_valid_float() else default_val


func _truthy(s: String) -> bool:
	return s.to_lower() in ["on", "1", "true", "yes", "y"]


# ============================================================
# Commands
# ============================================================

func _cmd_help(args: PackedStringArray) -> void:
	if args.is_empty():
		var names: Array = _commands.keys()
		names.sort()
		info("Commands (F1 / ` toggles; Up/Down for history):")
		var line: String = "  "
		for n in names:
			line += "[color=#e3d28b]%s[/color]  " % n
			if line.length() > 96:
				log_line(line)
				line = "  "
		if line.strip_edges() != "":
			log_line(line)
		info("Type [b]help <cmd>[/b] for usage.")
		return
	var n: String = args[0].to_lower()
	if not _commands.has(n):
		err("unknown command '%s'" % n)
		return
	var e: Dictionary = _commands[n]
	info("[b]%s[/b] %s" % [n, String(e["args"])])
	log_line("  %s" % String(e["desc"]))


func _cmd_echo(args: PackedStringArray) -> void:
	log_line(" ".join(args))


func _cmd_clear(_args: PackedStringArray) -> void:
	_output.clear()


func _cmd_close(_args: PackedStringArray) -> void:
	toggle()


# ----- Inventory -----

func _cmd_give(args: PackedStringArray) -> void:
	if args.is_empty():
		err("usage: give <item_id> [count]")
		return
	var item_id := StringName(args[0])
	if not ItemRegistry.has(item_id):
		err("no item '%s'. Try [b]items[/b] to list." % args[0])
		return
	var count: int = _parse_int(args[1], 1) if args.size() > 1 else 1
	if count <= 0:
		err("count must be positive")
		return
	var success: bool = Inventory.try_add(item_id, count)
	if success:
		ok("+%d %s" % [count, String(item_id)])
	else:
		err("inventory full (some items may still have been added)")


func _cmd_take(args: PackedStringArray) -> void:
	if args.is_empty():
		err("usage: take <item_id> [count]")
		return
	var item_id := StringName(args[0])
	var count: int = _parse_int(args[1], 99999) if args.size() > 1 else 99999
	var removed: int = Inventory.try_remove(item_id, count)
	ok("removed %d × %s" % [removed, String(item_id)])


func _cmd_clear_inv(_args: PackedStringArray) -> void:
	Inventory.clear()
	ok("inventory cleared")


func _cmd_items(args: PackedStringArray) -> void:
	var filter: String = args[0].to_lower() if not args.is_empty() else ""
	var ids: Array = ItemRegistry.all_ids()
	ids.sort_custom(func(a, b): return String(a) < String(b))
	var matches: Array = []
	for id in ids:
		var s: String = String(id)
		if filter == "" or s.to_lower().contains(filter):
			matches.append(s)
	if filter == "":
		info("%d items:" % matches.size())
	else:
		info("%d items matching '%s':" % [matches.size(), filter])
	var line: String = "  "
	for s in matches:
		line += s + "  "
		if line.length() > 96:
			log_line(line)
			line = "  "
	if line.strip_edges() != "":
		log_line(line)


func _cmd_equip_best(_args: PackedStringArray) -> void:
	var n: int = Inventory.auto_equip_best()
	ok("equipped %d items" % n)


# ----- Player -----

func _cmd_godmode(args: PackedStringArray) -> void:
	var p := _player()
	if p == null:
		err("no player in scene")
		return
	var hp := p.get_node_or_null("HealthComponent") as HealthComponent
	if hp == null:
		err("player has no HealthComponent")
		return
	var target: bool = not hp.is_invulnerable if args.is_empty() else _truthy(args[0])
	hp.is_invulnerable = target
	godmode_active = target
	ok("godmode %s" % ("on" if target else "off"))


func _cmd_heal(args: PackedStringArray) -> void:
	var p := _player()
	if p == null:
		err("no player in scene")
		return
	var hp := p.get_node_or_null("HealthComponent") as HealthComponent
	if hp == null:
		err("player has no HealthComponent")
		return
	if args.is_empty():
		hp.heal(hp.max_health - hp.current_health)
	else:
		hp.heal(_parse_int(args[0], 0))
	ok("HP: %d / %d" % [hp.current_health, hp.max_health])


func _cmd_damage(args: PackedStringArray) -> void:
	if args.is_empty():
		err("usage: damage <amount>")
		return
	var p := _player()
	if p == null:
		err("no player in scene")
		return
	var hp := p.get_node_or_null("HealthComponent") as HealthComponent
	if hp == null:
		return
	var amt: int = _parse_int(args[0], 0)
	# Bypass godmode for this command — let the user inspect i-frame visuals etc.
	var was_invuln: bool = hp.is_invulnerable
	hp.is_invulnerable = false
	hp.apply_damage(amt, null)
	hp.is_invulnerable = was_invuln
	ok("HP: %d / %d" % [hp.current_health, hp.max_health])


func _cmd_kill(_args: PackedStringArray) -> void:
	var p := _player()
	if p == null:
		err("no player in scene")
		return
	var hp := p.get_node_or_null("HealthComponent") as HealthComponent
	if hp == null:
		return
	var was_invuln: bool = hp.is_invulnerable
	hp.is_invulnerable = false
	hp.apply_damage(hp.current_health + 1, null)
	hp.is_invulnerable = was_invuln
	ok("player killed")


func _cmd_revive(_args: PackedStringArray) -> void:
	var p := _player()
	if p == null:
		return
	var hp := p.get_node_or_null("HealthComponent") as HealthComponent
	if hp == null:
		return
	hp.revive(1.0)
	if p is PlayerController:
		(p as PlayerController).is_dead = false
	ok("revived (HP %d)" % hp.current_health)


func _cmd_setmaxhp(args: PackedStringArray) -> void:
	if args.is_empty():
		err("usage: setmaxhp <amount>")
		return
	var p := _player()
	if p == null:
		return
	var hp := p.get_node_or_null("HealthComponent") as HealthComponent
	if hp == null:
		return
	hp.set_max_health(maxi(1, _parse_int(args[0], 100)), true)
	ok("max HP = %d" % hp.max_health)


func _cmd_noclip(args: PackedStringArray) -> void:
	var p := _player()
	if p == null:
		err("no player in scene")
		return
	var col := p as CollisionObject2D
	if col == null:
		err("player is not a CollisionObject2D")
		return
	var target: bool = not noclip_active if args.is_empty() else _truthy(args[0])
	if target == noclip_active:
		ok("noclip already %s" % ("on" if target else "off"))
		return
	noclip_active = target
	if target:
		_saved_player_mask = col.collision_mask
		col.collision_mask = 0
	else:
		if _saved_player_mask >= 0:
			col.collision_mask = _saved_player_mask
		_saved_player_mask = -1
	ok("noclip %s" % ("on" if target else "off"))


func _cmd_speed(args: PackedStringArray) -> void:
	if args.is_empty():
		err("usage: speed <mult>   (1.0 = normal; e.g. 3 for fast roam)")
		return
	dev_speed_mult = maxf(0.05, _parse_float(args[0], 1.0))
	ok("speed multiplier = %.2f×" % dev_speed_mult)


func _cmd_pos(_args: PackedStringArray) -> void:
	var p := _player()
	if p == null:
		err("no player in scene")
		return
	var pos: Vector2 = (p as Node2D).global_position
	var tx: int = int(floor(pos.x / float(TILE_PX)))
	var ty: int = int(floor(pos.y / float(TILE_PX)))
	var cx: int = int(floor(float(tx) / float(CHUNK_TILES)))
	var cy: int = int(floor(float(ty) / float(CHUNK_TILES)))
	info("world (%.1f, %.1f)  ·  tile (%d, %d)  ·  chunk (%d, %d)" % [pos.x, pos.y, tx, ty, cx, cy])


# ----- World -----

func _cmd_tp(args: PackedStringArray) -> void:
	if args.size() < 2:
		err("usage: tp <x> <y>")
		return
	var p := _player()
	if p == null:
		return
	(p as Node2D).global_position = Vector2(_parse_float(args[0]), _parse_float(args[1]))
	ok("teleported to (%.1f, %.1f)" % [(p as Node2D).global_position.x, (p as Node2D).global_position.y])


func _cmd_tp_tile(args: PackedStringArray) -> void:
	if args.size() < 2:
		err("usage: tp_tile <tx> <ty>")
		return
	var p := _player()
	if p == null:
		return
	var tx: int = _parse_int(args[0])
	var ty: int = _parse_int(args[1])
	(p as Node2D).global_position = Vector2(tx * TILE_PX + TILE_PX / 2, ty * TILE_PX + TILE_PX / 2)
	ok("teleported to tile (%d, %d)" % [tx, ty])


func _cmd_tp_chunk(args: PackedStringArray) -> void:
	if args.size() < 2:
		err("usage: tp_chunk <cx> <cy>")
		return
	var p := _player()
	if p == null:
		return
	var cx: int = _parse_int(args[0])
	var cy: int = _parse_int(args[1])
	var tx: int = cx * CHUNK_TILES + CHUNK_TILES / 2
	var ty: int = cy * CHUNK_TILES + CHUNK_TILES / 2
	(p as Node2D).global_position = Vector2(tx * TILE_PX, ty * TILE_PX)
	ok("teleported to chunk (%d, %d) centre" % [cx, cy])


func _cmd_tp_spawn(_args: PackedStringArray) -> void:
	var p := _player()
	if p == null:
		return
	(p as Node2D).global_position = GameState.respawn_point
	ok("teleported to respawn %s" % str(GameState.respawn_point))


func _cmd_setspawn(_args: PackedStringArray) -> void:
	var p := _player()
	if p == null:
		return
	var pos: Vector2 = (p as Node2D).global_position
	GameState.set_respawn_point(pos)
	if p is PlayerController:
		(p as PlayerController).set_respawn_position(pos)
	ok("respawn bound to %s" % str(pos))


func _cmd_time(args: PackedStringArray) -> void:
	if args.is_empty():
		err("usage: time <dawn|day|dusk|night>")
		return
	var phase: String = args[0].to_lower()
	if not PHASE_TO_FRACTION.has(phase):
		err("unknown phase '%s' — pick dawn/day/dusk/night" % phase)
		return
	var dnc := _find_dnc()
	if dnc == null:
		err("no DayNightCycle in scene")
		return
	var frac: float = PHASE_TO_FRACTION[phase]
	var target_seconds: float = frac * DayNightCycle.WORLD_DAY_SECONDS
	var current: float = float(dnc.get("_world_clock_seconds"))
	var delta: float = target_seconds - current
	if delta < 0.0:
		delta += DayNightCycle.WORLD_DAY_SECONDS
	dnc.call("skip_time", delta)
	ok("time set to %s" % phase)


func _find_dnc() -> Node:
	if get_tree() == null or get_tree().current_scene == null:
		return null
	return get_tree().current_scene.get_node_or_null("DayNightCycle")


func _cmd_seed(_args: PackedStringArray) -> void:
	info("world_seed = %d" % GameState.world_seed)


func _cmd_reveal(args: PackedStringArray) -> void:
	var radius: int = _parse_int(args[0], 5) if not args.is_empty() else 5
	radius = clampi(radius, 0, 64)
	var p := _player()
	if p == null:
		err("no player in scene")
		return
	var pos: Vector2 = (p as Node2D).global_position
	var cx0: int = int(floor(pos.x / float(CHUNK_TILES * TILE_PX)))
	var cy0: int = int(floor(pos.y / float(CHUNK_TILES * TILE_PX)))
	var n: int = 0
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var c := Vector2i(cx0 + dx, cy0 + dy)
			if not GameState.has_visited_chunk(c):
				GameState.mark_chunk_visited(c, &"unknown")
				n += 1
	ok("revealed %d new chunks (radius %d)" % [n, radius])


# ----- Progression -----

func _cmd_xp(args: PackedStringArray) -> void:
	if args.size() < 2:
		err("usage: xp <skill> <amount>")
		return
	var s := _resolve_skill(args[0])
	if s == &"":
		err("unknown skill '%s' (try: mining, running, melee, ...)" % args[0])
		return
	var amt: int = _parse_int(args[1], 0)
	SkillSystem.add_xp(s, amt)
	ok("granted %d XP → %s (now lv %d)" % [amt, String(s), SkillSystem.get_level(s)])


func _cmd_level(args: PackedStringArray) -> void:
	if args.size() < 2:
		err("usage: level <skill> <target_level>")
		return
	var s := _resolve_skill(args[0])
	if s == &"":
		err("unknown skill '%s'" % args[0])
		return
	var target: int = clampi(_parse_int(args[1], 0), 0, SkillSystem.SKILL_CAP_LEVEL)
	# XP needed to reach target = XP threshold of `target` itself.
	var needed_xp: int = SkillSystem.xp_required_for_level(target)
	var current_xp: int = SkillSystem.get_xp(s)
	if needed_xp > current_xp:
		SkillSystem.add_xp(s, needed_xp - current_xp)
	else:
		# Force-set (no public setter). Mirrors how SkillSystem internally tracks state.
		SkillSystem._xp[s] = needed_xp
		SkillSystem._level[s] = target
		EventBus.skill_leveled_up.emit(s, target)
	ok("%s → level %d" % [String(s), SkillSystem.get_level(s)])


func _cmd_slivers(args: PackedStringArray) -> void:
	if args.is_empty():
		err("usage: slivers <amount>")
		return
	var amt: int = maxi(0, _parse_int(args[0], 0))
	GameState.aphelion_slivers_remaining = amt
	EventBus.aphelion_dimmed.emit(amt)
	ok("slivers = %d" % amt)


func _cmd_defeat(args: PackedStringArray) -> void:
	if args.is_empty():
		err("usage: defeat <boss_id>")
		return
	var id := StringName(args[0])
	GameState.mark_boss_defeated(id)
	ok("marked %s defeated" % String(id))


func _cmd_bosses(_args: PackedStringArray) -> void:
	info("defeated bosses (%d):" % GameState.defeated_bosses.size())
	for k in GameState.defeated_bosses.keys():
		log_line("  [color=#9be07f]%s[/color]" % String(k))


func _cmd_talents(args: PackedStringArray) -> void:
	var amt: int = _parse_int(args[0], 1) if not args.is_empty() else 1
	GameState.grant_talent_point(amt)
	ok("granted %d talent point(s) — unallocated: %d" % [amt, GameState.unallocated_talent_points])


# ----- System -----

func _cmd_save(args: PackedStringArray) -> void:
	var slot: String = args[0] if not args.is_empty() else DEFAULT_SAVE_SLOT
	var e: int = SaveSystem.save_to_slot(slot)
	if e == OK:
		ok("saved → slot '%s'" % slot)
	else:
		err("save failed: %s" % error_string(e))


func _cmd_load(args: PackedStringArray) -> void:
	var slot: String = args[0] if not args.is_empty() else DEFAULT_SAVE_SLOT
	var e: int = SaveSystem.load_from_slot(slot)
	if e == OK:
		ok("loaded ← slot '%s'" % slot)
	else:
		err("load failed: %s" % error_string(e))


func _cmd_reload_scene(_args: PackedStringArray) -> void:
	# Close first so the new scene starts un-paused with no overlay over it.
	toggle()
	get_tree().reload_current_scene()


func _cmd_quit_game(_args: PackedStringArray) -> void:
	get_tree().quit()
