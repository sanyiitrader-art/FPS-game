extends Node
## Audio manager (autoload name: Audio).
##
## - Creates the "Music" and "SFX" buses so music and effects have separate switches.
## - Plays music with fades; finds the menu music file in assets/audio/music if one exists.
## - Plays effects through a small pool of players (no players are created during play).
## - UI sounds are synthesized in code, so menus have sound before any audio assets exist.

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const SFX_POOL_SIZE := 10
const MUSIC_VOLUME_DB := -10.0
const SILENT_DB := -60.0
const UI_VOLUME_DB := -8.0
const SAMPLE_RATE := 22050
const AUDIO_EXTENSIONS: PackedStringArray = ["ogg", "mp3", "wav"]

var _music_player: AudioStreamPlayer
var _music_tween: Tween
var _music_wanted := false
var _menu_music_path := ""
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _ui_sounds: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	_music_player.volume_db = SILENT_DB
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_sfx_players.append(player)

	_build_ui_sounds()
	_apply_switches()
	Settings.changed.connect(_on_setting_changed)


# ---- Buses and switches ---------------------------------------------------------------

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func _apply_switches() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MUSIC_BUS), not Settings.get_bool(Settings.K_MUSIC))
	AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX_BUS), not Settings.get_bool(Settings.K_SFX))


func _on_setting_changed(key: String) -> void:
	if key == Settings.K_MUSIC or key == Settings.K_SFX:
		_apply_switches()


# ---- UI sounds ----------------------------------------------------------------------------

func _build_ui_sounds() -> void:
	_ui_sounds = {
		"click": _make_tone(900.0, 700.0, 0.05, 0.30),
		"back": _make_tone(620.0, 440.0, 0.07, 0.28),
		"toggle": _make_tone(760.0, 980.0, 0.06, 0.28),
		"confirm": _make_tone(700.0, 1040.0, 0.12, 0.30),
		"notify": _make_tone(660.0, 880.0, 0.16, 0.26),
		"error": _make_tone(320.0, 220.0, 0.14, 0.30),
		"tick": _make_tone(1000.0, 1000.0, 0.04, 0.28),
	}


## Builds a short, soft, decaying tone as a 16-bit mono sample.
func _make_tone(freq_start: float, freq_end: float, duration: float, volume: float) -> AudioStreamWAV:
	var count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var attack_samples := maxf(1.0, 0.004 * SAMPLE_RATE)
	for i in count:
		var t := float(i) / float(count)
		var freq := lerpf(freq_start, freq_end, t)
		phase += TAU * freq / SAMPLE_RATE
		var envelope := exp(-5.0 * t) * minf(1.0, float(i) / attack_samples)
		var sample := clampf(sin(phase) * envelope * volume, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream


func play_ui(sound_name: String) -> void:
	var stream: AudioStream = _ui_sounds.get(sound_name)
	if stream != null:
		play_sfx(stream, UI_VOLUME_DB)


# ---- Effects (pooled) ---------------------------------------------------------------------

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var player := _free_sfx_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


func _free_sfx_player() -> AudioStreamPlayer:
	for i in SFX_POOL_SIZE:
		var candidate := _sfx_players[(_sfx_next + i) % SFX_POOL_SIZE]
		if not candidate.playing:
			_sfx_next = (_sfx_next + i + 1) % SFX_POOL_SIZE
			return candidate
	# Every player is busy: take over the oldest one.
	var oldest := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % SFX_POOL_SIZE
	return oldest


# ---- Music ------------------------------------------------------------------------------------

## Plays the first music file whose name contains "menu" (or the first music file found).
## Does nothing if no music has been added yet.
func play_menu_music() -> void:
	if _menu_music_path == "":
		_menu_music_path = Config.find_asset("res://assets/audio/music", AUDIO_EXTENSIONS, "menu")
		if _menu_music_path == "":
			return
	if _music_wanted and _music_player.playing:
		return
	var stream := Config.load_optional(_menu_music_path) as AudioStream
	if stream != null:
		play_music(stream)


func play_music(stream: AudioStream, fade: float = 1.5) -> void:
	if stream == null:
		return
	_enable_loop(stream)
	_music_wanted = true
	_kill_music_tween()
	if _music_player.playing:
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", SILENT_DB, 0.4)
		_music_tween.tween_callback(_start_music.bind(stream, fade))
	else:
		_start_music(stream, fade)


func stop_music(fade: float = 1.0) -> void:
	_music_wanted = false
	_kill_music_tween()
	if not _music_player.playing:
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", SILENT_DB, fade)
	_music_tween.tween_callback(_music_player.stop)


func _start_music(stream: AudioStream, fade: float) -> void:
	_music_player.stream = stream
	_music_player.volume_db = SILENT_DB
	_music_player.play()
	_kill_music_tween()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", MUSIC_VOLUME_DB, fade)


func _kill_music_tween() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null


func _enable_loop(stream: AudioStream) -> void:
	if "loop" in stream:
		stream.set("loop", true)


func _on_music_finished() -> void:
	# Fallback for formats that cannot loop themselves.
	if _music_wanted:
		_music_player.play()