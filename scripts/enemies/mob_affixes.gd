extends Node
class_name MobAffixes

## Phase 2.32 / 2.33 / 2.47 — Elite + Champion affix system.
##
## When a Mob spawns from WorldGen / MobSpawner, we roll a chance to mutate it
## into an Elite (one affix, ~6% chance) or a Champion (two affixes + name +
## guaranteed extra loot, ~1.5% chance per spawn).
##
## The affix is applied to the spawned Mob instance — it scales the mob's
## `max_health` and `contact_damage`, sets a tint, and stashes the affix
## metadata so the loot drop pass knows to roll extras.

const ELITE_HP_MULT: float = 1.6
const ELITE_DAMAGE_MULT: float = 1.4
const CHAMPION_HP_MULT: float = 3.0
const CHAMPION_DAMAGE_MULT: float = 1.9
const ELITE_TINT: Color = Color(1.1, 0.9, 0.65)
const CHAMPION_TINT: Color = Color(1.3, 0.65, 0.65)

const AFFIX_DEFS: Array[Dictionary] = [
	{"id": &"affix_swift",   "name": "Swift",    "speed_mult": 1.45, "hp_mult": 1.0,  "dmg_mult": 1.0},
	{"id": &"affix_brood",   "name": "Brood",    "speed_mult": 0.9,  "hp_mult": 1.3,  "dmg_mult": 1.0},
	{"id": &"affix_jagged",  "name": "Jagged",   "speed_mult": 1.0,  "hp_mult": 1.0,  "dmg_mult": 1.5},
	{"id": &"affix_warded",  "name": "Warded",   "speed_mult": 1.0,  "hp_mult": 1.8,  "dmg_mult": 1.0},
	{"id": &"affix_blazing", "name": "Blazing",  "speed_mult": 1.1,  "hp_mult": 1.0,  "dmg_mult": 1.1, "on_hit_status": &"burn"},
	{"id": &"affix_chilled", "name": "Chilled",  "speed_mult": 0.8,  "hp_mult": 1.2,  "dmg_mult": 1.0, "on_hit_status": &"cold"},
]

const ELITE_SPAWN_CHANCE: float = 0.06
const CHAMPION_SPAWN_CHANCE: float = 0.015


## Roll Mob affixes. Returns one of: {tier:"normal"} / {tier:"elite", affix:..} /
## {tier:"champion", affix1:.., affix2:..}.
static func roll_for_spawn(rng: RandomNumberGenerator) -> Dictionary:
	var r: float = rng.randf()
	if r < CHAMPION_SPAWN_CHANCE:
		return {
			"tier": "champion",
			"affix1": AFFIX_DEFS[rng.randi() % AFFIX_DEFS.size()],
			"affix2": AFFIX_DEFS[rng.randi() % AFFIX_DEFS.size()],
		}
	if r < CHAMPION_SPAWN_CHANCE + ELITE_SPAWN_CHANCE:
		return {
			"tier": "elite",
			"affix": AFFIX_DEFS[rng.randi() % AFFIX_DEFS.size()],
		}
	return {"tier": "normal"}


## Apply the affix roll to a Mob instance. Idempotent — repeat calls won't
## stack. Caller should invoke immediately after instantiation, BEFORE Mob._ready.
static func apply(mob: Node, affix_roll: Dictionary) -> void:
	if mob == null or affix_roll.is_empty():
		return
	if mob.has_meta(&"affix_tier"):
		return  # already applied
	mob.set_meta(&"affix_tier", String(affix_roll.get("tier", "normal")))
	var tier: String = affix_roll.get("tier", "normal")
	if tier == "normal":
		return
	# Collect all affixes to apply.
	var affixes: Array = []
	if affix_roll.has("affix"):
		affixes.append(affix_roll["affix"])
	if affix_roll.has("affix1"):
		affixes.append(affix_roll["affix1"])
	if affix_roll.has("affix2"):
		affixes.append(affix_roll["affix2"])
	# Tier base multipliers.
	var hp_mult: float = ELITE_HP_MULT if tier == "elite" else CHAMPION_HP_MULT
	var dmg_mult: float = ELITE_DAMAGE_MULT if tier == "elite" else CHAMPION_DAMAGE_MULT
	for a in affixes:
		hp_mult *= float(a.get("hp_mult", 1.0))
		dmg_mult *= float(a.get("dmg_mult", 1.0))
	# Scale stats post-_ready by setting a deferred call. Simpler: rewrite the
	# mob_def reference with a clone carrying multiplied stats.
	mob.set_meta(&"affix_hp_mult", hp_mult)
	mob.set_meta(&"affix_dmg_mult", dmg_mult)
	mob.set_meta(&"affix_list", affixes)
	# Tint applied next frame via deferred call on the sprite (mob may still be
	# instantiating).
	mob.call_deferred("set_meta", &"affix_apply_pending", true)
	# Champion gets a small name decal floating above its HP bar (handled by
	# mob.gd reading affix_list/_tier in _ready post-customise).


## Phase 2.32 — bonus drop roll for elite / champion mobs. Returns up to 2
## extra (item_id, count) entries pulled from the same loot table, plus a
## guaranteed Ancient Coin for Champions.
static func bonus_loot(mob: Node, rng: RandomNumberGenerator) -> Array:
	var tier: String = String(mob.get_meta(&"affix_tier", "normal"))
	if tier == "normal":
		return []
	var extras: Array = []
	var mob_def: Resource = mob.get("mob_def")
	var base_table: LootTable = null
	if mob_def and mob_def is Resource and mob_def.get("loot_table"):
		base_table = mob_def.get("loot_table") as LootTable
	if base_table:
		var rolls: int = 1 if tier == "elite" else 2
		for _i in range(rolls):
			extras.append_array(base_table.roll(rng, false))
	if tier == "champion":
		extras.append({"item_id": &"ancient_coin", "count": rng.randi_range(2, 5)})
	return extras


static func tint_for(tier: String) -> Color:
	match tier:
		"elite":    return ELITE_TINT
		"champion": return CHAMPION_TINT
		_:          return Color.WHITE
