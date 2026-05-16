extends Control
class_name Tooltip

## Single tooltip overlay. Owns its own Panel + Label, positioned below mouse.
## Callers: `Tooltip.show_for_item(item_id)` / `hide_tooltip()`.

@onready var panel: Control = $Panel
@onready var name_label: Label = $Panel/VBox/Name
@onready var detail_label: Label = $Panel/VBox/Detail
@onready var lore_label: Label = $Panel/VBox/Lore

var _pending_item: StringName = &""
var _pending_delay: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	top_level = true


func _process(delta: float) -> void:
	if _pending_delay > 0.0:
		_pending_delay -= delta
		if _pending_delay <= 0.0 and _pending_item != &"":
			_show_now(_pending_item)
	if not visible:
		return
	var pos: Vector2 = get_viewport().get_mouse_position() + Vector2(14, 14)
	var viewport_size: Vector2 = get_viewport_rect().size
	var our_size: Vector2 = panel.size if panel else Vector2(80, 24)
	if pos.x + our_size.x > viewport_size.x:
		pos.x = viewport_size.x - our_size.x - 4
	if pos.y + our_size.y > viewport_size.y:
		pos.y = viewport_size.y - our_size.y - 4
	global_position = pos


func show_for_item(item_id: StringName) -> void:
	# Ticket 1.31 — apply user-configured tooltip delay (instant/0.5s/1s).
	var delay: float = 0.0
	if Settings:
		delay = float(Settings.get_value("tooltip_delay", 0.0))
	if delay <= 0.001:
		_show_now(item_id)
		return
	_pending_item = item_id
	_pending_delay = delay


## Rarity colors keep tooltip name in sync with item-drop / slot border.
const RARITY_NAME_COLORS := [
	Color(1.0, 1.0, 1.0),       # 0 common
	Color(0.7, 1.0, 0.6),       # 1 uncommon
	Color(0.55, 0.78, 1.0),     # 2 rare
	Color(0.85, 0.55, 1.0),     # 3 epic
	Color(1.0, 0.95, 0.5),      # 4 legendary
]


func _show_now(item_id: StringName) -> void:
	_pending_item = &""
	_pending_delay = 0.0
	var defn: ItemDef = ItemRegistry.get_def(item_id)
	if defn == null:
		visible = false
		return
	name_label.text = defn.display_name
	# Phase 3.67 — name color reflects rarity tier.
	var rarity_idx: int = clamp(defn.rarity, 0, RARITY_NAME_COLORS.size() - 1)
	name_label.modulate = RARITY_NAME_COLORS[rarity_idx]
	var detail: String = defn.description
	if defn.base_damage > 0:
		detail += "\nDamage: %d" % defn.base_damage
	if defn.pickaxe_tier > 0:
		detail += "\nMining tier: %d" % defn.pickaxe_tier
	if defn.axe_tier > 0:
		detail += "\nAxe tier: %d" % defn.axe_tier
	if defn.armor_value > 0:
		detail += "\nArmor: %d" % defn.armor_value
	if defn.heal_amount > 0:
		detail += "\nHeals: %d HP" % defn.heal_amount
	if defn.mana_restore > 0:
		detail += "\nRestores: %d Mana" % defn.mana_restore
	if defn.melee_range_pixels > 0 and defn.base_damage > 0:
		detail += "\nReach: %d px" % defn.melee_range_pixels
	if defn.equipment_slot != &"":
		detail += "\nSlot: %s" % String(defn.equipment_slot).capitalize()
	if defn.two_handed:
		detail += "\nTwo-handed (locks off-hand)"
	if defn.tier > 0:
		detail += "\nTier %d" % defn.tier
	# Phase 3.17 — equipped-comparison overlay. If the hovered item is an
	# armor piece, show the +/- delta vs whatever currently sits in that slot.
	if defn.equipment_slot != &"":
		var equipped: StringName = StringName(Inventory.equipment.get(defn.equipment_slot, &""))
		if equipped != &"" and equipped != item_id:
			var ed: ItemDef = ItemRegistry.get_def(equipped)
			if ed:
				var delta: int = defn.armor_value - ed.armor_value
				if delta > 0:
					detail += "\nvs equipped: +%d armor" % delta
				elif delta < 0:
					detail += "\nvs equipped: %d armor" % delta
				else:
					detail += "\nvs equipped: same armor"
	# Phase 3.61 — set-bonus tooltip preview. Hardcoded shaleseed-set tier-1
	# bonus until a data-driven set system lands in Phase 7.
	if String(defn.id).begins_with("shaleseed_") and defn.equipment_slot != &"":
		var pieces: int = _count_equipped_set("shaleseed")
		detail += "\nSet: Shaleseed (%d/4)" % pieces
		if pieces >= 2:
			detail += "\n  (2) +5%% mining speed"
		if pieces >= 4:
			detail += "\n  (4) +10%% loot drops"
	detail_label.text = detail
	# Phase 3.59 — lore-text excerpt rendered in Monogram for flavor.
	if defn.lore_text != "":
		lore_label.text = "\"%s\"" % defn.lore_text
		lore_label.visible = true
	else:
		lore_label.text = ""
		lore_label.visible = false
	visible = true


func _count_equipped_set(prefix: String) -> int:
	var n: int = 0
	for slot in Inventory.equipment.keys():
		var iid: StringName = StringName(Inventory.equipment[slot])
		if iid != &"" and String(iid).begins_with(prefix + "_"):
			n += 1
	return n


func hide_tooltip() -> void:
	_pending_item = &""
	_pending_delay = 0.0
	visible = false
