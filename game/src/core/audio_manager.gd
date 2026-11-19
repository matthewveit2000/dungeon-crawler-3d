extends Node
## Tier 1 Autoload: Graceful open-source procedural WAV SFX & dungeon ambience manager.
## Fails safely with a warning if audio files are missing or running headlessly.

const AUDIO_DIR := "res://assets/audio/"

var _streams: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _ambience_player: AudioStreamPlayer = null
var _next_player_idx: int = 0
var _enabled: bool = true


func _ready() -> void:
	_enabled = DisplayServer.get_name() != "headless"
	for i in range(6):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.volume_db = -14.0
	add_child(_ambience_player)

	if EventBus != null and not EventBus.sfx_requested.is_connected(play_sfx):
		EventBus.sfx_requested.connect(play_sfx)


func play_sfx(sfx_name: String, volume_db: float = -4.0) -> void:
	if not _enabled:
		return
	var stream := _get_wav_stream(sfx_name)
	if stream == null:
		return
	var player := _sfx_players[_next_player_idx]
	_next_player_idx = (_next_player_idx + 1) % _sfx_players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func start_ambience(ambience_name: String = "dungeon_ambience") -> void:
	if not _enabled or _ambience_player == null:
		return
	var stream := _get_wav_stream(ambience_name)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_ambience_player.stream = stream
	if not _ambience_player.playing:
		_ambience_player.play()


func _get_wav_stream(sfx_name: String) -> AudioStream:
	if _streams.has(sfx_name):
		return _streams[sfx_name]
	var res_path := AUDIO_DIR + sfx_name + ".wav"
	if ResourceLoader.exists(res_path):
		var loaded := ResourceLoader.load(res_path)
		if loaded is AudioStream:
			_streams[sfx_name] = loaded
			return loaded
	var global_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(global_path):
		var wav := AudioStreamWAV.load_from_file(global_path)
		if wav != null:
			_streams[sfx_name] = wav
			return wav
	push_warning("AudioManager: Missing audio file '%s' (continuing silently)." % res_path)
	return null
