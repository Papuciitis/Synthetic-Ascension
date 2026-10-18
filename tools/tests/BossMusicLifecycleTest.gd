extends Node

class Boss extends Node2D:
	var dead := false

var passes := 0
var failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func tick(seconds := 0.01) -> Dictionary:
	AudioManager.call("_process", seconds)
	return AudioManager.call("boss_music_state")

func _run() -> void:
	for phase in range(1, 4):
		var path := "res://assets/audio/music/s10/main_phase_%d.wav" % phase
		var stream := load(path) as AudioStreamWAV
		check(stream != null and is_equal_approx(stream.get_length(), 16.0), "phase %d has its own sample-aligned sixteen-second recording" % phase)
	var release := load("res://assets/audio/music/s10/defeat_release.wav") as AudioStreamWAV
	check(release != null and is_equal_approx(release.get_length(), 3.2), "defeat has its own finite release recording")
	check(AudioManager.has_method("boss_music_state"), "AudioManager exposes main-boss lifecycle decisions in headless runs")
	if not AudioManager.has_method("boss_music_state"):
		finish()
		return
	AudioManager.to_game(true)
	var boss := Boss.new()
	add_child(boss)
	RunEvents.boss_spawned.emit(boss, 0, null, "Teaching")
	check(not tick()["active"], "S5 leaves ordinary adaptive music in charge")
	RunEvents.boss_spawned.emit(boss, 1, null, "Main")
	var state := tick()
	check(state["active"] and state["phase"] == 0 and state["route"] == &"boss", "S10 entrance starts the original first-phase arrangement")
	var serial := int(state["transitions"])
	RunEvents.boss_spawned.emit(boss, 1, null, "Main")
	RunEvents.boss_phase_changed.emit(boss, 1)
	state = tick()
	check(state["phase"] == 1 and int(state["transitions"]) == serial + 1, "duplicate spawn does not restart; phase two changes arrangement once")
	RunEvents.boss_phase_changed.emit(boss, 1)
	RunEvents.boss_phase_changed.emit(boss, 0)
	check(int(tick()["transitions"]) == serial + 1, "healing and repeated phase events never retrigger or reduce music")
	RunEvents.boss_phase_changed.emit(boss, 2)
	check(tick()["phase"] == 2, "phase three selects the final arrangement")
	var stranger := Boss.new()
	add_child(stranger)
	RunEvents.boss_phase_changed.emit(stranger, 2)
	RunEvents.boss_cleared.emit(stranger, 1)
	check(tick()["active"] and tick()["releases"] == 0, "unrelated actors cannot change or clear the owned music encounter")
	stranger.queue_free()
	boss.set_meta(&"boss_returning", true)
	state = tick()
	check(not state["active"] and state["route"] == &"game" and state["phase"] == 2, "disengage restores normal music while retaining reached phase")
	boss.set_meta(&"boss_returning", false)
	check(tick()["active"] and tick()["phase"] == 2, "re-engagement resumes the reached arrangement without farming phases")
	RunEvents.player_life_event.emit(self, &"death")
	state = tick()
	check(not state["active"] and state["route"] == &"game" and state["releases"] == 0, "player death releases combat music without a boss victory sting")
	RunEvents.player_life_event.emit(self, &"respawn")
	check(tick()["active"] and tick()["phase"] == 2, "reconstruction resumes the existing fight at its reached phase")
	get_tree().paused = true
	state = tick(1.0)
	check(state["paused"], "boss music suspends on pause")
	get_tree().paused = false
	check(not tick()["paused"], "boss music resumes after pause")
	SfxManager.play_2d(&"boss_warning", Vector2.ZERO)
	state = tick()
	check(float(state["warning_duck_db"]) <= -6.0, "major warnings immediately duck Music independently of the SFX voices")
	tick(1.2)
	check(is_zero_approx(float(tick()["warning_duck_db"])), "warning duck recovers without an accumulating attenuation")
	RunEvents.boss_cleared.emit(boss, 1)
	state = tick()
	check(not state["active"] and state["route"] == &"release" and state["releases"] == 1, "defeat enters a distinct finite release cue exactly once")
	RunEvents.boss_cleared.emit(boss, 1)
	check(tick()["releases"] == 1, "duplicate clear cannot replay the release")
	get_tree().paused = true
	tick(8.0)
	check(tick()["route"] == &"release", "pause cannot consume the release and jump to normal music")
	get_tree().paused = false
	tick(8.0)
	check(tick()["route"] == &"game", "release ends in ordinary game music")
	RunEvents.boss_spawned.emit(boss, 1, null, "Replacement")
	AudioManager.to_menu(true)
	check(tick()["route"] == &"menu" and not tick()["active"], "menu/context change clears encounter ownership and restores menu music")
	AudioManager.to_game(true)
	RunEvents.boss_spawned.emit(boss, 1, null, "Replacement")
	boss.queue_free()
	await get_tree().process_frame
	check(tick()["route"] == &"game" and not tick()["active"], "scene/actor removal restores the ordinary route without a defeat cue")
	var second := Boss.new()
	add_child(second)
	RunEvents.boss_spawned.emit(second, 1, null, "Second")
	AudioManager.stop_all(true)
	check(tick()["route"] == &"none" and not tick()["active"], "explicit stop cannot be undone by a lingering boss")
	second.queue_free()
	await test_playback()
	finish()

func test_playback() -> void:
	# Exercise real production players/streams/tweens even under headless Dummy
	# audio. This proves routing and playback state; it cannot approve a mix.
	var sfx_bus := AudioServer.get_bus_index(&"SFX")
	var sfx_effect_count := AudioServer.get_bus_effect_count(sfx_bus)
	AudioManager.set("_headless", false)
	AudioManager.call("_initialize_playback")
	var music_bus := AudioServer.get_bus_index(&"Music")
	var warning_on_music := false
	for index in AudioServer.get_bus_effect_count(music_bus):
		warning_on_music = warning_on_music or AudioServer.get_bus_effect(music_bus, index) == AudioManager.get("_warning_gain")
	check(warning_on_music and AudioServer.get_bus_effect_count(sfx_bus) == sfx_effect_count, "warning duck is installed only on Music and leaves the SFX bus intact")
	AudioManager.to_game(true)
	var boss := Boss.new()
	add_child(boss)
	RunEvents.boss_spawned.emit(boss, 1, null, "Playback")
	await get_tree().create_timer(.75).timeout
	var active: AudioStreamPlayer = AudioManager.get("_active")
	check(active.playing and active.bus == &"Music" and is_equal_approx(active.pitch_scale, 1.0), "real boss playback uses Music at unchanged pitch/speed")
	check(is_equal_approx(active.volume_db, AudioManager.music_volume_db - 5.0), "boss score stays five dB below the ordinary music gain")
	var stream := active.stream as AudioStreamWAV
	check(stream != null and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end == 352800, "phase loop is sample-exact with no frame-delayed finished restart")
	var previous_time := active.get_playback_position()
	RunEvents.boss_phase_changed.emit(boss, 1)
	active = AudioManager.get("_active")
	var arrangements: Array = AudioManager.get("_boss_streams")
	check(active.stream == arrangements[1] and absf(active.get_playback_position() - previous_time) < .12, "real phase crossfade switches musical parts at the existing beat")
	get_tree().paused = true
	tick()
	check(active.stream_paused and not (AudioManager.get("_tween") as Tween).is_running(), "pause suspends the actual audio voice and its crossfade")
	RunEvents.boss_phase_changed.emit(boss, 2)
	active = AudioManager.get("_active")
	check(active.stream_paused and not (AudioManager.get("_tween") as Tween).is_running(), "a phase event received while paused cannot start a new voice or fade")
	get_tree().paused = false
	tick()
	SfxManager.play_2d(&"boss_cast_warning", Vector2.ZERO)
	check(is_equal_approx((AudioManager.get("_warning_gain") as AudioEffectAmplify).volume_db, -7.0), "warning duck reaches the actual Music bus effect immediately")
	RunEvents.boss_cleared.emit(boss, 1)
	active = AudioManager.get("_active")
	check(active.stream == AudioManager.get("_release_stream") and (active.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED, "real release uses the separate non-looping recording")
	active.stop()
	AudioManager.call("_on_player_finished", active)
	check(not active.playing, "finished callback cannot loop the release recording")
	tick(4.0)
	active = AudioManager.get("_active")
	check(active.stream == AudioManager.get("_game_stream") and active.playing, "release restores the actual ordinary game stream")
	AudioManager.stop_all(false)
	await get_tree().create_timer(.75).timeout
	check(not (AudioManager.get("_a") as AudioStreamPlayer).playing and not (AudioManager.get("_b") as AudioStreamPlayer).playing, "stop during an interrupted crossfade silences both actual voices")
	boss.queue_free()

func finish() -> void:
	print("BossMusicLifecycleTest: %d passed, %d failed" % [passes, failures])
	get_tree().quit(1 if failures > 0 else 0)
