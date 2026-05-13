extends Node

## Audio routing autoload. Centralizes SFX / Music / Ambient bus control,
## the Aphelion-Beat cadence (~23s per Lore §1.2), and emits a beat signal
## that gameplay systems can synchronize to.

signal aphelion_beat

const APHELION_BEAT_PERIOD_SECONDS: float = 23.0
const SFX_POOL_SIZE: int = 8

var _beat_timer: Timer
var _phase_index: int = 0
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {}
var _music_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _music_cache: Dictionary = {}


func _ready() -> void:
	_init_sfx_pool()
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	_ambient_player = AudioStreamPlayer.new()
	add_child(_ambient_player)
	_beat_timer = Timer.new()
	_beat_timer.wait_time = APHELION_BEAT_PERIOD_SECONDS
	_beat_timer.one_shot = false
	_beat_timer.autostart = true
	_beat_timer.timeout.connect(_emit_beat)
	add_child(_beat_timer)


func _emit_beat() -> void:
	_phase_index = (_phase_index + 1) % 4
	play_sfx(&"aphelion_beat")
	aphelion_beat.emit()


func current_phase() -> int:
	return _phase_index


func is_day() -> bool:
	# Phases 0..1 = day, 2..3 = night. Used by Salt Wastes day/night temp swing.
	return _phase_index < 2


func play_sfx(sound_id: StringName, _at_position: Vector2 = Vector2.ZERO) -> void:
	var stream: AudioStream = _sfx_cache.get(sound_id, null) as AudioStream
	if stream == null:
		stream = _build_placeholder_tone(sound_id)
		_sfx_cache[sound_id] = stream
	var player := _get_free_player()
	if player == null:
		return
	player.stream = stream
	player.play()


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


func _get_free_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	return _sfx_pool[0] if _sfx_pool.size() > 0 else null


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
