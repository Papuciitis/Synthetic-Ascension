extends Node

# Simple music manager with crossfade.
# Two contexts: menu + game.

const MENU_MUSIC_PATH := "res://assets/audio/music/main_menu.mp3"
const GAME_MUSIC_PATH := "res://assets/audio/music/in_game.mp3"

# Default music loudness (dB). Tune later or wire to settings.
var music_volume_db: float = -10.0

# Fade time for transitions.
var fade_time: float = 0.65

var _menu_stream: AudioStream
var _game_stream: AudioStream

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _inactive: AudioStreamPlayer

var _current_key: StringName = &"none"
var _tween: Tween


var _headless := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Same convention as SfxManager: nothing is audible in headless runs, so
	# skip decoding and playing music entirely. This also stops every headless
	# test run from decoding the menu mp3 and leaking its playback at exit.
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		return

	_menu_stream = load(MENU_MUSIC_PATH)
	_game_stream = load(GAME_MUSIC_PATH)

	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	_a.name = "MusicA"
	_b.name = "MusicB"

	_a.bus = "Music"
	_b.bus = "Music"

	_a.volume_db = -80.0
	_b.volume_db = -80.0

	add_child(_a)
	add_child(_b)

	# Ensure loop (works even if stream loop flags are ignored).
	_a.finished.connect(_on_player_finished.bind(_a))
	_b.finished.connect(_on_player_finished.bind(_b))

	_active = _a
	_inactive = _b

	# Start in menu by default if we boot into MainMenu.
	to_menu(true)


func to_menu(immediate: bool = false) -> void:
	_play_context(&"menu", _menu_stream, immediate)


func to_game(immediate: bool = false) -> void:
	_play_context(&"game", _game_stream, immediate)


func stop_all(immediate: bool = false) -> void:
	if _headless:
		return
	_current_key = &"none"
	_kill_tween()
	if immediate:
		_a.stop()
		_b.stop()
		_a.volume_db = -80.0
		_b.volume_db = -80.0
	else:
		# Fade out whichever is active.
		if _active.playing:
			_tween = create_tween()
			_tween.tween_property(_active, "volume_db", -80.0, fade_time)
			_tween.tween_callback(func() -> void: _active.stop())


func _exit_tree() -> void:
	# Release the mp3 streams and their playback objects before engine
	# teardown; otherwise every clean exit (and every headless test run)
	# reports two leaked AudioStreamMP3/AudioStreamPlaybackMP3 instances.
	_kill_tween()
	for player in [_a, _b]:
		if player != null and is_instance_valid(player):
			player.stop()
			player.stream = null
	_menu_stream = null
	_game_stream = null


# ------------------------------------------------------------
# Internals
# ------------------------------------------------------------
func _play_context(key: StringName, stream: AudioStream, immediate: bool) -> void:
	if stream == null:
		return

	if _current_key == key and _active.playing and _active.stream == stream:
		return

	_current_key = key
	_kill_tween()

	# If immediate, just cut.
	if immediate:
		_active.stop()
		_inactive.stop()
		_active.stream = stream
		_active.volume_db = music_volume_db
		_active.play()
		_inactive.volume_db = -80.0
		return

	# Crossfade: swap active/inactive.
	var prev := _active
	var next := _inactive
	_active = next
	_inactive = prev

	next.stop()
	next.stream = stream
	next.volume_db = -80.0
	next.play()

	_tween = create_tween()
	_tween.tween_property(next, "volume_db", music_volume_db, fade_time)
	if prev.playing:
		_tween.parallel().tween_property(prev, "volume_db", -80.0, fade_time)
		_tween.tween_callback(func() -> void:
			prev.stop()
		)
	else:
		prev.volume_db = -80.0


func _on_player_finished(p: AudioStreamPlayer) -> void:
	# Loop only the currently intended context music.
	if p == _active and _current_key != &"none":
		p.play()


func _kill_tween() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null
