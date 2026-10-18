extends Node

# Menu/game crossfades, adaptive ordinary music and the boss score.

const MENU_MUSIC_PATH := "res://assets/audio/music/main_menu.mp3"
const GAME_MUSIC_PATH := "res://assets/audio/music/in_game.mp3"
const BOSS_MUSIC_PATHS := [
	"res://assets/audio/music/s10/main_phase_1.wav",
	"res://assets/audio/music/s10/main_phase_2.wav",
	"res://assets/audio/music/s10/main_phase_3.wav",
]
const BOSS_RELEASE_PATH := "res://assets/audio/music/s10/defeat_release.wav"
# These quiet, high-crest-factor recordings need arrangement gain before the
# user's Music bus. Their measured RMS is -23.9/-21.1/-18.9 dBFS; the old
# shared -5 dB left phase one near -49 dBFS at the default Music setting.
# Result: roughly -30/-29/-28 dBFS at that setting, preserving escalation.
const BOSS_PHASE_GAIN_DB := [14.0, 12.0, 11.0]
const BOSS_RELEASE_GAIN_DB := 8.0
const WARNING_DUCK_DB := -3.0
const WARNING_DUCK_SECONDS := 0.48
const RELEASE_SECONDS := 3.2

var _boss_streams: Array[AudioStream] = []
var _release_stream: AudioStream
var _boss_ref: WeakRef
var _boss_phase := 0
var _boss_tier := -1
var _boss_active := false
var _boss_player_down := false
var _boss_route: StringName = &"menu"
var _boss_paused := false
var _release_left := 0.0
var _warning_left := 0.0
var _warning_gain: AudioEffectAmplify
var _boss_transitions := 0
var _boss_releases := 0

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

## Ordinary adaptive music (audit 2026-10-04, intensity): the
## low-pass on the Music bus has a cutoff that
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
	_hook_boss_events.call_deferred()

	# Same convention as SfxManager: nothing is audible in headless runs, so
	# skip decoding and playing music entirely. This also stops every headless
	# test run from decoding the menu mp3 and leaking its playback at exit.
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		set_process(false)
		return
	_initialize_playback()


func _initialize_playback() -> void:
	_install_intensity_filter()

	_menu_stream = load(MENU_MUSIC_PATH)
	_game_stream = load(GAME_MUSIC_PATH)
	for path in BOSS_MUSIC_PATHS:
		var stream := (load(path) as AudioStreamWAV).duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		_boss_streams.append(stream)
	_release_stream = load(BOSS_RELEASE_PATH)

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
	_clear_boss_music()
	_boss_route = &"menu"
	_play_context(&"menu", _menu_stream, immediate)


func to_game(immediate: bool = false) -> void:
	_clear_boss_music()
	_boss_route = &"game"
	_play_context(&"game", _game_stream, immediate)


func stop_all(immediate: bool = false) -> void:
	_clear_boss_music()
	_boss_route = &"none"
	_current_key = &"none"
	if _headless:
		return
	_kill_tween()
	if immediate:
		_a.stop()
		_b.stop()
		_a.volume_db = -80.0
		_b.volume_db = -80.0
	else:
		# A stop may arrive halfway through a crossfade: fade both voices.
		_tween = create_tween().set_parallel(true)
		for player in [_a, _b]:
			_tween.tween_property(player, "volume_db", -80.0, fade_time)
		_tween.chain().tween_callback(func() -> void:
			_a.stop()
			_b.stop()
		)


func _process(delta: float) -> void:
	_sync_boss_music(delta)
	_poll_left -= delta
	if _poll_left <= 0.0:
		_poll_left = INTENSITY_POLL_SECONDS
		var target := intensity_target()
		_target_cutoff_hz = float(target["cutoff_hz"])
		_target_duck_db = float(target["duck_db"])
	var blend_weight := 1.0 - exp(-delta / CUTOFF_TAU)
	var log_cutoff := log(_cutoff_hz) + (log(_target_cutoff_hz) - log(_cutoff_hz)) * blend_weight
	_cutoff_hz = clampf(exp(log_cutoff), CUTOFF_LOW_HP_HZ * 0.5, CUTOFF_OPEN_HZ)
	_duck_db = lerpf(_duck_db, _target_duck_db, blend_weight)
	if _lowpass != null:
		_lowpass.cutoff_hz = _cutoff_hz
	if _duck != null:
		_duck.volume_db = _duck_db
	if _warning_gain != null:
		_warning_gain.volume_db = WARNING_DUCK_DB if _warning_left > 0.0 else 0.0


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
	_warning_gain = AudioEffectAmplify.new()
	AudioServer.add_bus_effect(bus, _warning_gain)


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
	_boss_streams.clear()
	_release_stream = null
	_boss_ref = null


# ------------------------------------------------------------
# Internals
# ------------------------------------------------------------
func _play_context(key: StringName, stream: AudioStream, immediate: bool, gain_db: float = 0.0, seek_seconds: float = 0.0) -> void:
	if _headless:
		_current_key = key
		return
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
		_active.volume_db = music_volume_db + gain_db
		_active.play(seek_seconds)
		_active.stream_paused = _boss_paused
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
	next.play(seek_seconds)
	next.stream_paused = _boss_paused

	_tween = create_tween()
	_tween.tween_property(next, "volume_db", music_volume_db + gain_db, fade_time)
	if prev.playing:
		_tween.parallel().tween_property(prev, "volume_db", -80.0, fade_time)
		_tween.tween_callback(func() -> void:
			prev.stop()
		)
	else:
		prev.volume_db = -80.0
	if _boss_paused:
		_tween.pause()


func _on_player_finished(p: AudioStreamPlayer) -> void:
	# Loop only the currently intended context music.
	if p == _active and _current_key != &"none" and _boss_route != &"release":
		p.play()


func _remove_intensity_filter() -> void:
	var bus := AudioServer.get_bus_index("Music")
	if bus < 0:
		return
	for i in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
		var effect := AudioServer.get_bus_effect(bus, i)
		if effect == _lowpass or effect == _duck or effect == _warning_gain:
			AudioServer.remove_bus_effect(bus, i)
	_lowpass = null
	_duck = null
	_warning_gain = null


func _hook_boss_events() -> void:
	var events := get_node_or_null(^"/root/RunEvents")
	if events != null:
		events.boss_spawned.connect(_on_boss_spawned)
		events.boss_phase_changed.connect(_on_boss_phase_changed)
		events.boss_cleared.connect(_on_boss_cleared)
		events.player_life_event.connect(_on_player_life_event)
	var sfx := get_node_or_null(^"/root/SfxManager")
	if sfx != null:
		sfx.sound_requested.connect(_on_sound_requested)


func _owned_boss() -> Node:
	return _boss_ref.get_ref() as Node if _boss_ref != null else null


func _on_boss_spawned(boss: Node, tier: int, _portrait: Texture2D, _title: String) -> void:
	if tier not in [0, 1] or boss == null or boss == _owned_boss() or _current_key != &"game":
		return
	_clear_boss_music()
	_boss_ref = weakref(boss)
	_boss_tier = tier
	_boss_phase = 0
	var on_exit := _on_boss_exiting.bind(boss.get_instance_id())
	if not boss.tree_exiting.is_connected(on_exit):
		boss.tree_exiting.connect(on_exit, CONNECT_ONE_SHOT)
	_resume_boss_music()


func _on_boss_phase_changed(boss: Node, phase: int) -> void:
	if _boss_tier != 1 or boss != _owned_boss() or phase <= _boss_phase:
		return
	_boss_phase = clampi(phase, 0, BOSS_MUSIC_PATHS.size() - 1)
	if _boss_active:
		_resume_boss_music()


func _resume_boss_music() -> void:
	# Shared sample-exact loop lengths retain harmony and beat across a phase
	# change. Each arrangement adds composed parts at unchanged playback speed.
	var position := _active.get_playback_position() if not _headless and _boss_active and _active != null else 0.0
	_boss_active = true
	_boss_route = &"boss"
	_boss_transitions += 1
	var stream: AudioStream = _boss_streams[_boss_phase] if not _boss_streams.is_empty() else null
	_play_context(&"game", stream, false, BOSS_PHASE_GAIN_DB[_boss_phase], fmod(position, 16.0))
	_set_boss_paused(get_tree().paused)
	_poll_left = 0.0


func _on_boss_cleared(boss: Node, tier: int) -> void:
	if tier != _boss_tier or boss == null or boss != _owned_boss():
		return
	_clear_boss_music()
	_boss_route = &"release"
	_release_left = RELEASE_SECONDS
	_boss_releases += 1
	_play_context(&"game", _release_stream, false, BOSS_RELEASE_GAIN_DB)
	_set_boss_paused(get_tree().paused)


func _on_boss_exiting(id: int) -> void:
	var boss := _owned_boss()
	if boss == null or boss.get_instance_id() != id:
		return
	_clear_boss_music()
	_boss_route = &"game"
	_play_context(&"game", _game_stream, false)


func _clear_boss_music() -> void:
	_boss_ref = null
	_boss_tier = -1
	_boss_active = false
	_boss_player_down = false
	_release_left = 0.0
	_warning_left = 0.0
	if _warning_gain != null:
		_warning_gain.volume_db = 0.0
	_set_boss_paused(false)


func _set_boss_paused(value: bool) -> void:
	if value == _boss_paused:
		return
	_boss_paused = value
	for player in [_a, _b]:
		if player != null:
			player.stream_paused = value
	if _tween != null and _tween.is_valid():
		if value:
			_tween.pause()
		else:
			_tween.play()


func _sync_boss_music(delta: float) -> void:
	var suspended := get_tree().paused and (_boss_ref != null or _release_left > 0.0)
	_set_boss_paused(suspended)
	if suspended:
		return
	_warning_left = maxf(0.0, _warning_left - delta)
	if _release_left > 0.0:
		_release_left = maxf(0.0, _release_left - delta)
		if _release_left <= 0.0:
			_boss_route = &"game"
			_play_context(&"game", _game_stream, false)
		return
	if _boss_ref == null:
		return
	var boss := _owned_boss()
	if boss == null or not boss.is_inside_tree() or boss.get("dead") == true:
		_clear_boss_music()
		_boss_route = &"game"
		_play_context(&"game", _game_stream, false)
		return
	var returning := _boss_player_down or bool(boss.get_meta(&"boss_returning", false))
	if returning and _boss_active:
		_boss_active = false
		_boss_route = &"game"
		_warning_left = 0.0
		_play_context(&"game", _game_stream, false)
	elif not returning and not _boss_active:
		_resume_boss_music()


func _on_sound_requested(id: StringName) -> void:
	if _boss_active and id in [&"boss_warning", &"boss_cast_warning"]:
		_warning_left = WARNING_DUCK_SECONDS
		if _warning_gain != null:
			_warning_gain.volume_db = WARNING_DUCK_DB


func _on_player_life_event(_player: Node, kind: StringName) -> void:
	if _boss_ref != null:
		if kind == &"death":
			_boss_player_down = true
		elif kind == &"respawn":
			_boss_player_down = false


## Decisions remain observable without decoding/starting voices in headless.
func boss_music_state() -> Dictionary:
	return {"active": _boss_active, "phase": _boss_phase, "tier": _boss_tier, "route": _boss_route,
		"paused": _boss_paused, "transitions": _boss_transitions, "releases": _boss_releases,
		"warning_duck_db": WARNING_DUCK_DB if _warning_left > 0.0 else 0.0}


func _kill_tween() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null
