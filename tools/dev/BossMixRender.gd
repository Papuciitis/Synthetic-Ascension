extends Node2D
## Native offline evidence: records the actually mixed Master output, after
## the Music/SFX buses. The previous gain reenactment changes a voice only;
## user settings and bus gain/mute are never rewritten by production code.
class Boss extends Node2D:
	var dead := false

var _record: AudioEffectRecord
var _directory: String
var _boss: Boss
var _dense_left := 0.0
var _dense_serial := 0
var _energy_mix := false

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	_directory = OS.get_environment("BOSS_MIX_OUTPUT")
	if _directory.is_empty():
		_directory = ProjectSettings.globalize_path("user://boss_mix_render")
	DirAccess.make_dir_recursive_absolute(_directory)
	var camera := Camera2D.new()
	add_child(camera)
	camera.make_current()
	_record = AudioEffectRecord.new()
	_record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(AudioServer.get_bus_index(&"Master"), _record)
	print("BOSS_MIX_ENGINE driver=", AudioServer.get_driver_name(), " output=", AudioServer.output_device, " display=", DisplayServer.get_name(), " mix-rate=", AudioServer.get_mix_rate())
	print("BOSS_MIX_SETTINGS Music=", AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")), "dB mute=", AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), " SFX=", AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX")))
	# This tool must render audio; headless production deliberately skips it.
	if AudioManager.get("_headless"):
		AudioManager.set("_headless", false)
		AudioManager.call("_initialize_playback")
	SfxManager.set("_headless", false)
	AudioManager.to_game(true)
	_boss = Boss.new()
	add_child(_boss)
	var releases_only := OS.get_environment("BOSS_MIX_RELEASES_ONLY") == "1"
	RunEvents.boss_spawned.emit(_boss, 1 if releases_only else 0, null, "Boss mix evidence")
	if releases_only:
		RunEvents.boss_phase_changed.emit(_boss, 2)
		await get_tree().create_timer(0.8).timeout
		_energy_mix = true
		_dense_left = 0.05
		await _capture("dense-energy-and-rush-releases", 6.0)
		_record.set_recording_active(false)
		AudioManager.stop_all(true)
		print("BOSS_MIX_RENDER_COMPLETE ", _directory)
		get_tree().quit()
		return
	await get_tree().create_timer(0.8).timeout
	var active: AudioStreamPlayer = AudioManager.get("_active")
	# Reenact the delivered pre-feedback -15 dB voice, same score and bus.
	active.volume_db = -15.0
	active.play(0.0)
	await get_tree().create_timer(0.1).timeout
	await _capture("previous-phase1-gain-reenactment", 16.0)
	active.volume_db = AudioManager.music_volume_db + AudioManager.BOSS_PHASE_GAIN_DB[0]
	active.play(0.0)
	await get_tree().create_timer(0.1).timeout
	await _capture("s5-phase1-fixed", 16.0)
	AudioManager.to_game(true)
	RunEvents.boss_spawned.emit(_boss, 1, null, "S10 mix evidence")
	for phase in [1, 2]:
		RunEvents.boss_phase_changed.emit(_boss, phase)
		await get_tree().create_timer(0.8).timeout
		await _capture("s10-phase%d-fixed" % (phase + 1), 8.0)
	_dense_left = 0.05
	_dense_serial = 0
	set_process(true)
	await _capture("dense-combat-warnings-and-release", 6.0)
	set_process(false)
	for child in SfxManager.get_children():
		if child is AudioStreamPlayer2D:
			child.stop()
	RunEvents.boss_cleared.emit(_boss, 1)
	await _capture("boss-defeat-release", 3.2)
	_record.set_recording_active(false)
	AudioManager.stop_all(true)
	print("BOSS_MIX_RENDER_COMPLETE ", _directory)
	get_tree().quit()

func _capture(label: String, seconds: float) -> void:
	_record.set_recording_active(true)
	await get_tree().create_timer(seconds).timeout
	_record.set_recording_active(false)
	var wave := _record.get_recording()
	var result := wave.save_to_wav(_directory.path_join(label + ".wav")) if wave != null else ERR_INVALID_DATA
	print("BOSS_MIX_CAPTURE ", label, " result=", result, " frames=", wave.data.size() / 4 if wave != null else 0)
	if result != OK:
		get_tree().quit(1)

func _process(delta: float) -> void:
	if _dense_left <= 0.0:
		return
	_dense_left -= delta
	if _dense_left <= 0.0:
		_dense_left = 0.12
		var ids := [&"player_ranged_shot", &"enemy_death", &"player_melee_hit", &"enemy_hurt", &"player_magic_cast"]
		SfxManager.play_2d(ids[_dense_serial % ids.size()], Vector2.ZERO, -3.0)
		_dense_serial += 1
		if _energy_mix:
			if _dense_serial in [8, 25, 42]:
				SfxManager.play_2d(&"boss_cast_warning", Vector2.ZERO)
			elif _dense_serial in [12, 29, 46]:
				SfxManager.play_2d(&"boss_fan_release", Vector2.ZERO, 0.0, 1.1)
			elif _dense_serial == 16:
				SfxManager.play_2d(&"boss_beam_release", Vector2.ZERO)
			elif _dense_serial == 35:
				SfxManager.play_2d(&"boss_rush_release", Vector2.ZERO, 0.0, 0.95)
		elif _dense_serial in [8, 25, 42]:
			SfxManager.play_2d(&"boss_warning", Vector2.ZERO)
		elif _dense_serial in [12, 29, 46]:
			SfxManager.play_2d(&"boss_slam_impact", Vector2.ZERO)
