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

## Adaptive music without new assets (audit 2026-10-04, intensity): one
## in-game track, so the intensity is a low-pass on the Music bus whose cutoff
## follows the segment - recon muffled, disturbance warmer, ascension nearly
## open, collapse and a live exit encounter fully open - and closes right down
## at or below 30% health, with a small duck, like hearing through a ringing
## head. Menus and the hub stay open. The effects are added to the bus at
## runtime (default_bus_layout.tres is untouched) and eased in log-frequency
## so a change takes about two seconds.
const CUTOFF_OPEN_HZ := 20000.0
const CUTOFF_RECON_HZ := 3500.0
const CUTOFF_DISTURBANCE_HZ := 6000.0
const CUTOFF_ASCENSION_HZ := 10000.0
const CUTOFF_LOW_HP_HZ := 1200.0
const LOW_HP_RATIO := 0.30
const LOW_HP_DUCK_DB := -3.0
## Easing time constant: ~95% of a change lands in 3 tau.
const CUTOFF_TAU := 0.65
## The target is re-read a few times a second; the easing runs every frame.
const INTENSITY_POLL_SECONDS := 0.25
var _lowpass: AudioEffectLowPassFilter = null
var _duck: AudioEffectAmplify = null
var _cutoff_hz := CUTOFF_OPEN_HZ
var _duck_db := 0.0
var _target_cutoff_hz := CUTOFF_OPEN_HZ
var _target_duck_db := 0.0
var _poll_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Same convention as SfxManager: nothing is audible in headless runs, so
	# skip decoding and playing music entirely. This also stops every headless
	# test run from decoding the menu mp3 and leaking its playback at exit.
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		set_process(false)
		return
	_install_intensity_filter()

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


func _process(delta: float) -> void:
	_poll_left -= delta
	if _poll_left <= 0.0:
		_poll_left = INTENSITY_POLL_SECONDS
		var target := intensity_target()
		_target_cutoff_hz = float(target["cutoff_hz"])
		_target_duck_db = float(target["duck_db"])
	var ease := 1.0 - exp(-delta / CUTOFF_TAU)
	var log_cutoff := log(_cutoff_hz) + (log(_target_cutoff_hz) - log(_cutoff_hz)) * ease
	_cutoff_hz = clampf(exp(log_cutoff), CUTOFF_LOW_HP_HZ * 0.5, CUTOFF_OPEN_HZ)
	_duck_db = lerpf(_duck_db, _target_duck_db, ease)
	if _lowpass != null:
		_lowpass.cutoff_hz = _cutoff_hz
	if _duck != null:
		_duck.volume_db = _duck_db


## What the music should sound like right now: {cutoff_hz, duck_db}. Reads
## the live game; works headless (only the audio itself is skipped there).
func intensity_target() -> Dictionary:
	var tree := get_tree()
	var in_combat := _current_key == &"game" and tree != null and not tree.get_nodes_in_group(&"enemy_spawner").is_empty()
	var phase: StringName = &"recon"
	var rite_active := false
	var director := get_node_or_null(^"/root/ThreatDirector")
	if director != null:
		phase = StringName(director.get("segment_phase"))
		rite_active = bool(director.get("rite_channel_active"))
	var low_hp := false
	var player := tree.get_first_node_in_group(&"player") if tree != null else null
	if in_combat and player != null:
		var hp_raw: Variant = player.get("hp")
		var max_raw: Variant = player.get("max_hp")
		if (hp_raw is float or hp_raw is int) and (max_raw is float or max_raw is int) and float(max_raw) > 0.0:
			var ratio := float(hp_raw) / float(max_raw)
			low_hp = ratio > 0.0 and ratio <= LOW_HP_RATIO and player.get("is_dead") != true
	return {
		"cutoff_hz": intensity_cutoff(in_combat, phase, rite_active, low_hp),
		"duck_db": LOW_HP_DUCK_DB if low_hp else 0.0,
	}


## The low-pass cutoff for a game state: open outside combat, then by phase,
## open for a live exit encounter, closed down at low health.
static func intensity_cutoff(in_combat: bool, phase: StringName, rite_active: bool, low_hp: bool) -> float:
	if not in_combat:
		return CUTOFF_OPEN_HZ
	if low_hp:
		return CUTOFF_LOW_HP_HZ
	if rite_active:
		return CUTOFF_OPEN_HZ
	match phase:
		&"disturbance":
			return CUTOFF_DISTURBANCE_HZ
		&"ascension":
			return CUTOFF_ASCENSION_HZ
		&"collapse":
			return CUTOFF_OPEN_HZ
	return CUTOFF_RECON_HZ


func current_cutoff_hz() -> float:
	return _cutoff_hz


func _install_intensity_filter() -> void:
	var bus := AudioServer.get_bus_index("Music")
	if bus < 0:
		return
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = _cutoff_hz
	_duck = AudioEffectAmplify.new()
	_duck.volume_db = 0.0
	AudioServer.add_bus_effect(bus, _lowpass)
	AudioServer.add_bus_effect(bus, _duck)


func _exit_tree() -> void:
	# Release the mp3 streams and their playback objects before engine
	# teardown; otherwise every clean exit (and every headless test run)
	# reports two leaked AudioStreamMP3/AudioStreamPlaybackMP3 instances.
	_kill_tween()
	_remove_intensity_filter()
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


func _remove_intensity_filter() -> void:
	var bus := AudioServer.get_bus_index("Music")
	if bus < 0:
		return
	for i in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
		var effect := AudioServer.get_bus_effect(bus, i)
		if effect == _lowpass or effect == _duck:
			AudioServer.remove_bus_effect(bus, i)
	_lowpass = null
	_duck = null


func _kill_tween() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null
