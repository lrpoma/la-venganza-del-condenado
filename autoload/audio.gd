# ===== audio.gd (Autoload) =====
# Reproduce SFX (pool de reproductores), música de fondo y bucles (viento del remolino).
# Los archivos viven en res://assets/audio/ como sfx_<nombre>.ogg / music_<nombre>.ogg
extends Node

const DIR := "res://assets/audio/"
const POOL_SIZE := 10

var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _loops: Dictionary = {}
var _cache: Dictionary = {}
var _last_played: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -9.0
	add_child(_music)


func _get_stream(file: String) -> AudioStream:
	if _cache.has(file):
		return _cache[file]
	var path := DIR + file + ".ogg"
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_cache[file] = stream
	return stream


func play(sfx: String, volume_db: float = 0.0, pitch: float = 1.0, min_gap: float = 0.0) -> void:
	# min_gap evita que el mismo efecto se dispare en cada frame (p. ej. chisporroteo continuo)
	var now := Time.get_ticks_msec() / 1000.0
	if min_gap > 0.0 and now - _last_played.get(sfx, -99.0) < min_gap:
		return
	_last_played[sfx] = now
	var stream := _get_stream("sfx_" + sfx)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return


func click() -> void:
	play("click", -4.0)


func play_music(track: String) -> void:
	var stream := _get_stream("music_" + track)
	if stream == null or (_music.stream == stream and _music.playing):
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = track != "victory"
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music.stop()


func start_loop(sfx: String, volume_db: float = -6.0) -> void:
	if _loops.has(sfx):
		return
	var stream := _get_stream("sfx_" + sfx)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	p.play()
	_loops[sfx] = p


func stop_loop(sfx: String) -> void:
	if _loops.has(sfx):
		_loops[sfx].queue_free()
		_loops.erase(sfx)


func stop_all_loops() -> void:
	for k in _loops.keys():
		stop_loop(k)
