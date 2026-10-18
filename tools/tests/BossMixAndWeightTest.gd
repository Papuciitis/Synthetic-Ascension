extends Node
## Regression for the first-boss silence report: real playback, saturated
## combat voices and the actual S5 visual follower, independent of HP/damage.
const APPEARANCE := preload("res://scenes/world/bosses/BossAppearance.gd")
const TANK := preload("res://scenes/world/bosses/BossBulldozer.tscn")
var passes := 0
var failures := 0

class Boss extends Node2D:
	var dead := false

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	var music := AudioServer.get_bus_index(&"Music")
	var sfx := AudioServer.get_bus_index(&"SFX")
	AudioServer.set_bus_volume_db(music, -11.0)
	AudioServer.set_bus_mute(sfx, true)
	AudioManager.set("_headless", false)
	AudioManager.call("_initialize_playback")
	AudioManager.to_game(true)
	var boss := Boss.new()
	add_child(boss)
	RunEvents.boss_spawned.emit(boss, 0, null, "Teaching")
	AudioManager.call("_process", 0.01)
	check(AudioManager.boss_music_state()["active"], "S5 immediately owns an audible boss arrangement")
	await get_tree().create_timer(0.8).timeout
	var active: AudioStreamPlayer = AudioManager.get("_active")
	var arrangements: Array = AudioManager.get("_boss_streams")
	check(active.playing and active.stream == arrangements[0], "S5 starts a real score voice rather than a silent lifecycle decision")
	# Asset RMS is -23.9 dBFS. At the default -9.9 dB user bus, >=+2 dB
	# voice yields >=-32 dBFS: clearly above the previous -49 dBFS score.
	check(active.volume_db >= 2.0, "phase-one arrangement has compensated internal gain before the user's Music setting")
	SfxManager.play_2d(&"boss_warning", Vector2.ZERO)
	var duck := float(AudioManager.boss_music_state()["warning_duck_db"])
	check(duck >= -4.0 and duck <= -2.0, "major warning leaves audible score headroom instead of seven dB suppression")
	check(is_equal_approx(AudioServer.get_bus_volume_db(music), -11.0) and AudioServer.is_bus_mute(sfx), "encounter changes never rewrite user bus gain or mute")
	RunEvents.boss_cleared.emit(boss, 0)
	check(AudioManager.boss_music_state()["route"] == &"release", "first-boss defeat also has a finite musical release")
	boss.queue_free()
	AudioManager.stop_all(true)
	SfxManager.set("_headless", false)
	for voice: AudioStreamPlayer2D in SfxManager.get("_pool"):
		voice.stop()
	# One boss warning must survive a swarm filling and overflowing all 24
	# ordinary slots with different short combat sounds.
	SfxManager.play_2d(&"boss_warning", Vector2.ZERO)
	for id: StringName in [&"enemy_death", &"player_ranged_shot", &"enemy_hurt", &"player_melee_hit", &"player_magic_cast", &"pickup"]:
		for iteration in 6:
			SfxManager.play_2d(id, Vector2.ZERO)
	var warnings := 0
	for child in SfxManager.get_children():
		if child is AudioStreamPlayer2D and child.playing and child.get_meta(&"sfx_id", &"") == &"boss_warning":
			warnings += 1
	check(warnings == 1, "dense ordinary combat cannot steal the live boss warning voice")
	for voice: AudioStreamPlayer2D in SfxManager.get("_boss_pool"):
		voice.stop()
	for iteration in 6:
		SfxManager.play_2d(&"boss_warning", Vector2.ZERO)
	for iteration in 2:
		SfxManager.play_2d(&"boss_cast_warning", Vector2.ZERO)
	SfxManager.play_2d(&"boss_pylon_shot", Vector2.ZERO)
	var major_voices := 0
	var pylon_voices := 0
	for voice: AudioStreamPlayer2D in SfxManager.get("_boss_pool"):
		if voice.playing:
			if voice.get_meta(&"sfx_id", &"") == &"boss_pylon_shot":
				pylon_voices += 1
			else:
				major_voices += 1
	check(major_voices == 8 and pylon_voices == 0, "a saturated boss pool keeps all major warnings instead of stealing one for a pylon shot")
	SfxManager.set("_headless", true)
	for child in SfxManager.get_children():
		if child is AudioStreamPlayer2D:
			child.stop()
	var actor := TANK.instantiate() as EnemyActor
	add_child(actor)
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	APPEARANCE.apply(actor, 0)
	var acting := actor.get_node_or_null("BossActing")
	check(acting != null, "first-boss world form has the committed anticipation/release follower")
	if acting != null:
		var sprite := actor.get_node("Sprite2D") as Sprite2D
		var rest := sprite.transform
		actor.set_meta(&"boss_teaching_state", &"slam")
		acting.call("_physics_process", 0.2)
		check(absf(sprite.rotation - rest.get_rotation()) >= 0.065, "planted slam anticipation has a readable body brace")
		actor.set_meta(&"boss_teaching_state", &"recovery")
		acting.call("_physics_process", 0.03)
		check(sprite.rotation > rest.get_rotation(), "real release reverses the brace into a clear follow-through")
		SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
		acting.call("_physics_process", 0.2)
		check(sprite.transform.is_equal_approx(rest), "Reduced Motion keeps the first boss in its exact authored pose")
		SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
		actor.set_meta(&"boss_teaching_state", &"idle")
		acting.call("_physics_process", 1.0)
		var handle := EnemyWorld.handle_for_actor(actor)
		EnemyCombat.apply_damage(handle, actor.max_hp * 0.04)
		acting.call("_physics_process", 0.02)
		check(absf(sprite.rotation - rest.get_rotation()) > 0.01, "actual HP loss earns a bounded boss body response without camera effects")
		SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
		for hit in 100:
			if not EnemyWorld.is_valid_handle(handle) or actor.hp <= 0.0:
				break
			EnemyCombat.apply_damage(handle, actor.max_hp)
		check(get_tree().get_nodes_in_group(&"boss_defeat_afterimage").size() == 1, "real boss death leaves exactly one finite raster defeat response")
		var aftermath := get_tree().get_first_node_in_group(&"boss_defeat_afterimage") as Node2D
		if aftermath != null:
			var snapshot := aftermath.global_transform
			aftermath.call("_process", 0.2)
			check(aftermath.global_transform.is_equal_approx(snapshot) and aftermath.get_child_count() == 0, "Reduced Motion defeat only fades the raster and adds no moving body or collider")
		await get_tree().create_timer(1.1).timeout
		check(get_tree().get_nodes_in_group(&"boss_defeat_afterimage").is_empty(), "defeat response cleans itself up independently of the removed actor")
	if is_instance_valid(actor):
		actor.queue_free()
	await get_tree().process_frame
	print("BossMixAndWeightTest: %d passed, %d failed" % [passes, failures])
	get_tree().quit(1 if failures else 0)
