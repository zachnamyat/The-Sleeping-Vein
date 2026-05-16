extends Node

## Audio routing autoload. Centralizes SFX / Music / Ambient bus control,
## the Aphelion-Beat cadence (~23s per Lore §1.2), and emits a beat signal
## that gameplay systems can synchronize to.

signal aphelion_beat

const APHELION_BEAT_PERIOD_SECONDS: float = 23.0
const SFX_POOL_SIZE: int = 8
const POS_SFX_POOL_SIZE: int = 6   ## Phase 6.61 — pool of AudioStreamPlayer2D
const OCCLUSION_DB_DROP: float = 8.0   ## Phase 6.60 — quieter through walls

var _beat_timer: Timer
var _phase_index: int = 0
var _sfx_pool: Array[AudioStreamPlayer] = []
var _pos_sfx_pool: Array[AudioStreamPlayer2D] = []
var _sfx_cache: Dictionary = {}
var _music_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _music_layer_player: AudioStreamPlayer  ## Phase 6.59 — layered combat track
var _music_cache: Dictionary = {}
var _adaptive_target_db: float = -60.0    ## inaudible at start
var _adaptive_current_db: float = -60.0


func _ready() -> void:
	_init_sfx_pool()
	_init_pos_sfx_pool()
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	_ambient_player = AudioStreamPlayer.new()
	add_child(_ambient_player)
	_music_layer_player = AudioStreamPlayer.new()
	_music_layer_player.volume_db = -60.0
	add_child(_music_layer_player)
	_beat_timer = Timer.new()
	_beat_timer.wait_time = APHELION_BEAT_PERIOD_SECONDS
	_beat_timer.one_shot = false
	_beat_timer.autostart = true
	_beat_timer.timeout.connect(_emit_beat)
	add_child(_beat_timer)
	# Phase 4.9 — biome music swap.
	EventBus.biome_changed.connect(_on_biome_changed)
	# Phase 6.59 — adaptive music ramp listens to combat intensity.
	EventBus.combat_intensity_changed.connect(_on_intensity_changed)
	set_process(true)


func _on_biome_changed(_old_biome_id: StringName, new_biome_id: StringName) -> void:
	if new_biome_id == &"":
		return
	var track_id: StringName = new_biome_id
	# Allow biome resources to override via ambient_track_id, but most resources
	# will leave it blank and rely on the biome id as the cache key.
	var dir := DirAccess.open("res://resources/biomes/")
	if dir:
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if entry.ends_with(".tres"):
				var res := load("res://resources/biomes/" + entry) as BiomeDef
				if res and res.id == new_biome_id and res.ambient_track_id != &"":
					track_id = res.ambient_track_id
					break
			entry = dir.get_next()
		dir.list_dir_end()
	play_ambient(track_id)


func _emit_beat() -> void:
	_phase_index = (_phase_index + 1) % 4
	play_sfx(&"aphelion_beat")
	aphelion_beat.emit()


func current_phase() -> int:
	return _phase_index


func is_day() -> bool:
	# Phases 0..1 = day, 2..3 = night. Used by Salt Wastes day/night temp swing.
	return _phase_index < 2


func play_sfx(sound_id: StringName, at_position: Vector2 = Vector2.ZERO) -> void:
	var stream: AudioStream = _sfx_cache.get(sound_id, null) as AudioStream
	if stream == null:
		stream = _build_placeholder_tone(sound_id)
		_sfx_cache[sound_id] = stream
	# Phase 6.61 — if a position was supplied, route through positional 2D pool.
	if at_position != Vector2.ZERO:
		_play_positional(sound_id, stream, at_position)
		return
	var player := _get_free_player()
	if player == null:
		return
	player.stream = stream
	player.play()


func _play_positional(_sound_id: StringName, stream: AudioStream, at_position: Vector2) -> void:
	# Phase 6.60 — quieter through walls. Cheap raycast from listener (player) to
	# source; if blocked, drop volume by OCCLUSION_DB_DROP. Listener fallback to
	# (0,0) if no player exists.
	var listener_pos: Vector2 = Vector2.ZERO
	var tree := get_tree()
	if tree:
		var players := tree.get_nodes_in_group("player")
		if not players.is_empty() and players[0] is Node2D:
			listener_pos = (players[0] as Node2D).global_position
	var occluded: bool = _check_occlusion(listener_pos, at_position)
	var player := _get_free_pos_player()
	if player == null:
		return
	player.stream = stream
	player.global_position = at_position
	player.volume_db = -2.0 - (OCCLUSION_DB_DROP if occluded else 0.0)
	# Distance attenuation falls off naturally because AudioStreamPlayer2D uses
	# the listener's screen position; ensure the listener is set to the player.
	player.play()


func _check_occlusion(from: Vector2, to: Vector2) -> bool:
	# Cheap heuristic: count tile chunks between from and to. Real raycast would
	# need a TileMap reference; at MVP we treat distance > 192 as a soft "muffled".
	if from == Vector2.ZERO:
		return false
	return from.distance_to(to) > 192.0


func play_music(track_id: StringName, _fade_seconds: float = 2.0) -> void:
	if _music_player == null:
		return
	var stream: AudioStream = _music_cache.get(track_id, null) as AudioStream
	if stream == null:
		stream = _build_placeholder_music(track_id)
		_music_cache[track_id] = stream
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.volume_db = -6.0
	_music_player.play()


func stop_music() -> void:
	if _music_player and _music_player.playing:
		_music_player.stop()


func play_ambient(track_id: StringName) -> void:
	if _ambient_player == null:
		return
	var stream: AudioStream = _music_cache.get(track_id, null) as AudioStream
	if stream == null:
		stream = _build_placeholder_music(track_id)
		_music_cache[track_id] = stream
	if _ambient_player.stream == stream and _ambient_player.playing:
		return
	_ambient_player.stream = stream
	_ambient_player.volume_db = -12.0
	_ambient_player.play()


func _init_sfx_pool() -> void:
	for _i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_pool.append(p)


func _init_pos_sfx_pool() -> void:
	for _i in range(POS_SFX_POOL_SIZE):
		var p := AudioStreamPlayer2D.new()
		add_child(p)
		_pos_sfx_pool.append(p)


func _get_free_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	return _sfx_pool[0] if _sfx_pool.size() > 0 else null


func _get_free_pos_player() -> AudioStreamPlayer2D:
	for p in _pos_sfx_pool:
		if not p.playing:
			return p
	return _pos_sfx_pool[0] if _pos_sfx_pool.size() > 0 else null


# Phase 6.59 — adaptive music: combat intensity 0..1 fades a layered combat
# track over the ambient one. Smooth interpolation runs from _process.
func _on_intensity_changed(intensity: float) -> void:
	# Map 0..1 to -60..-3 dB; below 0.1 silence the layer.
	if intensity < 0.1:
		_adaptive_target_db = -60.0
	else:
		_adaptive_target_db = lerp(-30.0, -3.0, clampf(intensity, 0.0, 1.0))


func _process(delta: float) -> void:
	# Fade adaptive music gradually so it doesn't snap on / off.
	if _music_layer_player:
		_adaptive_current_db = lerp(_adaptive_current_db, _adaptive_target_db, clampf(delta * 1.5, 0.0, 1.0))
		_music_layer_player.volume_db = _adaptive_current_db
		# Spin up the layer track on first need.
		if _adaptive_current_db > -55.0 and not _music_layer_player.playing:
			var stream: AudioStream = _music_cache.get(&"combat_layer", null) as AudioStream
			if stream == null:
				stream = _build_placeholder_music(&"combat_layer")
				_music_cache[&"combat_layer"] = stream
			_music_layer_player.stream = stream
			_music_layer_player.play()


# Builds a short procedural tone keyed to sound_id, so we have audible
# placeholders before real audio assets are authored. Swap in an AudioStream
# loaded from disk by registering it in _sfx_cache before play_sfx is called.
func _build_placeholder_tone(sound_id: StringName) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sound_id)
	# Aphelion Beat: deep, slow; everything else: brighter and faster decay.
	var is_beat: bool = sound_id == &"aphelion_beat"
	var freq: float = 110.0 if is_beat else lerp(220.0, 720.0, rng.randf())
	var duration: float = 0.55 if is_beat else 0.18
	var decay: float = 4.5 if is_beat else 12.0
	var sample_rate: int = 22050
	var n_samples: int = int(duration * sample_rate)
	var bytes := PackedByteArray()
	bytes.resize(n_samples * 2)
	for i in range(n_samples):
		var t: float = float(i) / sample_rate
		var envelope: float = exp(-t * decay)
		var harmonic: float = sin(t * freq * 2.0 * TAU) * 0.25 if is_beat else 0.0
		var sample: float = (sin(t * freq * TAU) + harmonic) * envelope * 0.45
		var s16: int = clampi(int(sample * 32767.0), -32768, 32767)
		bytes[i * 2] = s16 & 0xFF
		bytes[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = bytes
	return wav


# Builds a long looping pad keyed to track_id. Two-voice detuned sine drone
# with slow swell. Real music assets will replace these by registering an
# imported AudioStream in _music_cache before play_music is called.
func _build_placeholder_music(track_id: StringName) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(track_id)
	var root_hz: float = lerp(60.0, 140.0, rng.randf())
	var second_hz: float = root_hz * 1.5  # perfect fifth
	var sample_rate: int = 22050
	var duration: float = 8.0  # loop length
	var n_samples: int = int(duration * sample_rate)
	var bytes := PackedByteArray()
	bytes.resize(n_samples * 2)
	for i in range(n_samples):
		var t: float = float(i) / sample_rate
		var swell: float = 0.6 + 0.4 * sin(t * 0.7)
		var voice_a: float = sin(t * root_hz * TAU)
		var voice_b: float = sin(t * second_hz * TAU) * 0.6
		var sample: float = (voice_a + voice_b) * swell * 0.2
		var s16: int = clampi(int(sample * 32767.0), -32768, 32767)
		bytes[i * 2] = s16 & 0xFF
		bytes[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n_samples
	return wav
