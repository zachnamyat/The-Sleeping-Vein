extends Node
class_name DamageType

## Damage type registry. Used as StringName tags throughout combat code.
## See docs/reference/core-keeper-mechanics.md §3.1 — Void & Voltage list:
## physical, fire, poison, cold, magic, summon, explosive, lightning, void.
## Phase 6.19 adds BLEED for HP-scaling DoT.

const PHYSICAL: StringName = &"physical"
const AXE: StringName = &"axe"  ## Tree-felling damage; trees resist all other types.
const FIRE: StringName = &"fire"
const POISON: StringName = &"poison"
const COLD: StringName = &"cold"
const MAGIC: StringName = &"magic"
const SUMMON: StringName = &"summon"
const EXPLOSIVE: StringName = &"explosive"
const LIGHTNING: StringName = &"lightning"
const VOID: StringName = &"void"
const BLEED: StringName = &"bleed"

const ALL_TYPES: Array[StringName] = [
	PHYSICAL, AXE, FIRE, POISON, COLD, MAGIC, SUMMON, EXPLOSIVE, LIGHTNING, VOID, BLEED,
]

## Phase 6.40 — color used by the floating damage number / icon strip per type.
const COLOR_BY_TYPE: Dictionary = {
	&"physical":  Color(1.00, 1.00, 1.00),
	&"axe":       Color(0.80, 0.65, 0.45),
	&"fire":      Color(1.00, 0.55, 0.18),
	&"poison":    Color(0.55, 0.95, 0.35),
	&"cold":      Color(0.55, 0.85, 1.00),
	&"magic":     Color(0.78, 0.55, 1.00),
	&"summon":    Color(0.95, 0.85, 0.50),
	&"explosive": Color(1.00, 0.42, 0.30),
	&"lightning": Color(0.92, 0.95, 1.00),
	&"void":      Color(0.55, 0.30, 0.90),
	&"bleed":     Color(0.90, 0.20, 0.30),
}

## Phase 2.42 — distinct hit SFX cue per damage family. AudioBus.play_sfx routes
## any unknown id through the procedural-tone fallback so missing WAVs are still
## audible. Crush vs slash vs pierce derives from weapon class (sword/axe/spear),
## handled in player_combat once the weapon resolves.
const HIT_SFX_BY_TYPE: Dictionary = {
	&"physical":  &"hit_physical",
	&"axe":       &"hit_chop",
	&"fire":      &"hit_fire",
	&"poison":    &"hit_poison",
	&"cold":      &"hit_cold",
	&"magic":     &"hit_magic",
	&"summon":    &"hit_summon",
	&"explosive": &"hit_explosion",
	&"lightning": &"hit_zap",
	&"void":      &"hit_void",
	&"bleed":     &"hit_slash",
}


static func is_valid(type: StringName) -> bool:
	return type in ALL_TYPES


static func color_for(type: StringName) -> Color:
	return COLOR_BY_TYPE.get(type, Color.WHITE)


static func hit_sfx_for(type: StringName) -> StringName:
	return HIT_SFX_BY_TYPE.get(type, &"hit_mob")
