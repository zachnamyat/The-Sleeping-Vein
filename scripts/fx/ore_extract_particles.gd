extends Node2D
class_name OreExtractParticles

## Ticket 2.24 — Ore-extract particle VFX (per-ore color).
## Spawned by player_combat / world_gen on tile_changed where the new tile
## is a mined-out floor. Each ore drops particles in its biome ramp:
##   shaleseed   → grey-brown
##   clearstone  → cyan-blue
##   ember_iron  → orange-red
##   saltbound   → pale-yellow
##   auroric_ice → pale-blue
##   diadem_gold → warm-gold

const LIFETIME: float = 0.6
const PARTICLE_COUNT: int = 8

const ORE_COLORS: Dictionary = {
	&"shaleseed":         Color(0.55, 0.50, 0.40),
	&"clearstone":        Color(0.45, 0.78, 0.92),
	&"ember_iron":        Color(0.92, 0.45, 0.18),
	&"saltbound_steel":   Color(0.95, 0.92, 0.78),
	&"auroric_ice":       Color(0.75, 0.92, 0.96),
	&"diadem_gold":       Color(0.97, 0.85, 0.40),
	&"aphelion_shard":    Color(0.97, 0.92, 0.50),
	&"copper":            Color(0.92, 0.55, 0.35),
	&"iron":              Color(0.7, 0.7, 0.75),
}

var ore_id: StringName = &"shaleseed"
var _t: float = 0.0
var _particles: Array[Dictionary] = []


func _ready() -> void:
	z_index = 12
	set_process(true)
	for i in PARTICLE_COUNT:
		_particles.append({
			"offset": Vector2.ZERO,
			"velocity": Vector2(randf_range(-32.0, 32.0), randf_range(-48.0, -16.0)),
			"size": randf_range(1.0, 2.0),
		})


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		queue_free()
		return
	for p in _particles:
		p["offset"] = p["offset"] + p["velocity"] * delta
		p["velocity"] = p["velocity"] + Vector2(0, 80.0) * delta   # gravity
	queue_redraw()


func _draw() -> void:
	var t: float = _t / LIFETIME
	var alpha: float = 1.0 - t
	var color: Color = ORE_COLORS.get(ore_id, Color(0.7, 0.7, 0.7))
	color.a = alpha
	for p in _particles:
		var pos: Vector2 = p["offset"]
		var s: float = float(p["size"])
		draw_rect(Rect2(pos - Vector2(s * 0.5, s * 0.5), Vector2(s, s)), color, true)
