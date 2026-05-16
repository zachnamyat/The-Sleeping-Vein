extends Node

## Ticket 2.43 — Mob death SFX per species (data-driven).
## Reads each MobDef's `death_sfx_path` and plays it through AudioBus on
## EventBus.entity_killed. Defaults to a generic squish if the def doesn't
## specify one.

const FALLBACK_DEATH_SFX: String = "res://assets/audio/sfx/mob_death_generic.ogg"

const DEFAULT_PER_CLASS: Dictionary = {
	&"melee":   "res://assets/audio/sfx/mob_death_melee.ogg",
	&"ranged":  "res://assets/audio/sfx/mob_death_ranged.ogg",
	&"caster":  "res://assets/audio/sfx/mob_death_caster.ogg",
	&"tank":    "res://assets/audio/sfx/mob_death_tank.ogg",
	&"critter": "res://assets/audio/sfx/mob_death_critter.ogg",
}


func _ready() -> void:
	EventBus.entity_killed.connect(_on_entity_killed)


func _on_entity_killed(entity: Node, _killer: Node) -> void:
	if entity is Boss:
		# Bosses have their own defeat fanfare; nothing to do here.
		return
	if not (entity is Mob):
		return
	var mob := entity as Mob
	if mob.mob_def == null:
		return
	var path: String = ""
	if mob.mob_def.get("death_sfx_path") and String(mob.mob_def.get("death_sfx_path")) != "":
		path = String(mob.mob_def.get("death_sfx_path"))
	elif mob.mob_def.get("mob_class") != null:
		var cls: StringName = mob.mob_def.get("mob_class")
		path = String(DEFAULT_PER_CLASS.get(cls, FALLBACK_DEATH_SFX))
	else:
		path = FALLBACK_DEATH_SFX
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream and AudioBus and AudioBus.has_method("play_positional_2d"):
		AudioBus.call("play_positional_2d", stream, mob.global_position, &"sfx", 0.0)
