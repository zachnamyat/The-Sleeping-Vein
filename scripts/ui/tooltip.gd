extends Control
class_name Tooltip

## Single tooltip overlay. Owns its own Panel + Label, positioned below mouse.
## Callers: `Tooltip.show_for_item(item_id)` / `hide_tooltip()`.

@onready var panel: Control = $Panel
@onready var name_label: Label = $Panel/VBox/Name
@onready var detail_label: Label = $Panel/VBox/Detail


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	top_level = true


func _process(_delta: float) -> void:
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
	var defn: ItemDef = ItemRegistry.get_def(item_id)
	if defn == null:
		visible = false
		return
	name_label.text = defn.display_name
	var detail: String = defn.description
	if defn.base_damage > 0:
		detail += "\nDamage: %d" % defn.base_damage
	if defn.pickaxe_tier > 0:
		detail += "\nMining tier: %d" % defn.pickaxe_tier
	if defn.armor_value > 0:
		detail += "\nArmor: %d" % defn.armor_value
	if defn.heal_amount > 0:
		detail += "\nHeals: %d HP" % defn.heal_amount
	if defn.tier > 0:
		detail += "\nTier %d" % defn.tier
	detail_label.text = detail
	visible = true


func hide_tooltip() -> void:
	visible = false
