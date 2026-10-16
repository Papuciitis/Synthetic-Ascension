extends Node

# Actual attack decisions must request the registered recordings once at their
# boundary. SfxManager records before its headless guard; no audible output is
# required, and test doubles do not stand in for the attack implementations.

const TANK = preload("res://scenes/world/bosses/BossBulldozer.tscn")
const MAGE = preload("res://scenes/world/bosses/BossArcanist.tscn")
const MINE = preload("res://scenes/world/bosses/BossMine.tscn")
const BEAM = preload("res://scenes/world/bosses/BossBeamSweep.tscn")
const PYLON = preload("res://scenes/world/bosses/BossPylon.tscn")
const SCOPE = preload("res://scenes/world/bosses/BossAttackScope.gd")
const AUDIO_IDS: Array[StringName] = [&"boss_warning", &"boss_cast_warning", &"boss_slam_impact", &"boss_beam_release", &"boss_pylon_shot", &"boss_mine_burst"]

class Target:
	extends Node2D
	func take_damage(_amount: float, _source: Node = null) -> void:
		pass

var _passes := 0
var _failures := 0
var _world: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)


func _requests(id: StringName) -> Array:
	return SfxManager.debug_requests.filter(func(request: Dictionary) -> bool: return request["id"] == id)


func _clear_requests() -> void:
	SfxManager.debug_requests.clear()
	for id in AUDIO_IDS:
		SfxManager._last_limited_ms.erase(id)
	SfxManager._last_limited_ms.erase(&"multikill_thump")


func _check_one_at(id: StringName, pos: Vector2, label: String) -> void:
	var requests := _requests(id)
	_check(requests.size() == 1 and requests[0]["kind"] == &"2d" and (requests[0]["position"] as Vector2).is_equal_approx(pos), label)


func _fixture() -> void:
	_world = Node2D.new()
	_world.name = "BossAudioFixture"
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().root.add_child(_world)
	get_tree().current_scene = _world
	var target := Target.new()
	target.position = Vector2(1900, 1100)
	target.add_to_group(&"player")
	_world.add_child(target)


func _actor(scene: PackedScene) -> EnemyActor:
	var actor := scene.instantiate() as EnemyActor
	actor.process_mode = Node.PROCESS_MODE_PAUSABLE
	actor.position = Vector2(1500, 1100)
	_world.add_child(actor)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.get_node("BossBrain").set_process(false)
	actor.get_node("BossBrain").set_physics_process(false)
	return actor


func _invalidate(actor: EnemyActor) -> void:
	actor.dead = true
	var scope_ref := actor.get_meta(SCOPE.SCOPE_META) as WeakRef
	var scope: Node = scope_ref.get_ref()
	scope.call("cancel")


func _end_fixture() -> void:
	get_tree().paused = false
	get_tree().current_scene = self
	_world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _test_definitions() -> void:
	var definitions := [
		[&"boss_warning", -8.0, 0.480000, "res://assets/audio/sfx/bosses/candidates_v3/warning_weighted_brace.wav"],
		[&"boss_cast_warning", -15.0, 0.196871, "res://assets/audio/sfx/bosses/candidates_v2/cast_air_swish.wav"],
		[&"boss_slam_impact", -8.0, 0.720000, "res://assets/audio/sfx/bosses/candidates_v3/slam_weighted_thud.wav"],
		[&"boss_beam_release", -14.0, 0.666312, "res://assets/audio/sfx/bosses/candidates_v2/beam_electric_crackle.wav"],
		[&"boss_pylon_shot", -18.0, 0.196871, "res://assets/audio/sfx/bosses/candidates_v2/cast_air_swish.wav"],
		[&"boss_mine_burst", -10.0, 0.660000, "res://assets/audio/sfx/bosses/candidates_v3/mine_compact_blast.wav"],
	]
	for row in definitions:
		var id: StringName = row[0]
		var definition = SfxManager._defs.get(id)
		_check(definition != null, "%s has a real loaded sound definition" % id)
		if definition == null:
			continue
		var stream := definition.stream as AudioStreamWAV
		_check(stream != null and stream.resource_path == row[3] and absf(stream.get_length() - float(row[2])) < 0.002, "%s resolves the chosen replacement WAV and its delivered duration" % id)
		_check(definition.bus == &"SFX" and is_equal_approx(definition.vol_db, float(row[1])) and is_zero_approx(definition.pitch_jitter), "%s uses the intended SFX bus, gain and stable pitch" % id)
		_check(not definition.loop and stream != null and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "%s is a one-shot in both definition and stream" % id)


func _test_brain_warnings() -> void:
	_fixture()
	var tank := _actor(TANK)
	var brain := tank.get_node("BossBrain")
	_clear_requests()
	brain.call("_do_slam")
	brain.call("_do_slam")
	_check_one_at(&"boss_warning", tank.global_position, "accepted slam warns once at the committed origin; rejected overlap is silent")
	_invalidate(tank)
	brain.call("_do_slam")
	_check(_requests(&"boss_warning").size() == 1, "dead boss cannot replay a slam warning")
	await _end_fixture()

	_fixture()
	var mage := _actor(MAGE)
	brain = mage.get_node("BossBrain")
	_clear_requests()
	brain.call("_fan_shot")
	brain.call("_fan_shot")
	_check_one_at(&"boss_cast_warning", mage.global_position, "accepted fan uses its caster warning once at the committed origin; rejected overlap is silent")
	_check(_requests(&"boss_warning").is_empty(), "Arcanist fan cannot borrow the physical bracing warning")
	_invalidate(mage)
	brain.call("_fan_shot")
	_check(_requests(&"boss_cast_warning").size() == 1, "dead boss cannot replay a fan warning")
	await _end_fixture()


func _test_physical_impact_boundaries() -> void:
	_fixture()
	var tank := _actor(TANK)
	var brain := tank.get_node("BossBrain")
	brain.set("slam_windup", 0.20)
	var origin := tank.global_position
	_clear_requests()
	brain.call("_do_slam")
	brain.set_process(true)
	brain.set_physics_process(true)
	await get_tree().create_timer(0.05, true).timeout
	get_tree().paused = true
	await get_tree().create_timer(0.25, true).timeout
	_check(_requests(&"boss_slam_impact").is_empty() and _requests(&"multikill_thump").is_empty(), "pausing slam anticipation releases neither the new impact recording nor the old procedural thump")
	tank.global_position += Vector2(100, 0)
	get_tree().paused = false
	await get_tree().create_timer(0.25, true).timeout
	brain.set_process(false)
	brain.set_physics_process(false)
	_check_one_at(&"boss_slam_impact", origin, "real slam release requests one dedicated impact at the committed origin after resuming")
	_check(_requests(&"multikill_thump").is_empty(), "boss slam no longer requests the rejected procedural multikill recording")
	brain.call("_tick_cast", 1.0)
	_check(_requests(&"boss_slam_impact").size() == 1, "completed slam callbacks cannot duplicate the dedicated impact cue")
	_clear_requests()
	brain.call("_do_slam")
	tank.call("_apply_enemy_world_stun", 0.01)
	tank.stun_time = 0.0
	brain.call("_tick_cast", 1.0)
	_check(_requests(&"boss_slam_impact").is_empty(), "brief stun cancels pending slam audio with its damage and visual cast")
	_invalidate(tank)
	brain.call("_do_slam")
	brain.call("_tick_cast", 1.0)
	_check(_requests(&"boss_slam_impact").is_empty(), "dead source cannot revive a canceled physical impact cue")
	await _end_fixture()

	_fixture()
	tank = _actor(TANK)
	brain = tank.get_node("BossBrain")
	origin = tank.global_position
	_clear_requests()
	brain.call("_do_shockwave")
	brain.call("_tick_cast", float(brain.call("_shock_time", 0)) + 0.01)
	_check_one_at(&"boss_slam_impact", origin + Vector2(140, 0), "first real ground shock requests the physical impact recording at its own committed position")
	_check(_requests(&"multikill_thump").is_empty(), "ground shock also avoids the old procedural multikill sound")
	await _end_fixture()


func _mine(actor: EnemyActor, pos: Vector2) -> BossMine:
	var mine := MINE.instantiate() as BossMine
	mine.setup(pos, actor, 100.0, 95.0, 15.0)
	SCOPE.bind(mine, actor)
	_world.add_child(mine)
	mine.set_process(false)
	return mine


func _test_mine_boundaries() -> void:
	_fixture()
	var mage := _actor(MAGE)
	var mine := _mine(mage, Vector2(1600, 1250))
	_clear_requests()
	mine.call("_explode")
	mine.call("_explode")
	_check_one_at(&"boss_mine_burst", Vector2(1600, 1250), "mine detonation requests one burst at the impact, never one per duplicate call")

	mine = _mine(mage, Vector2(1700, 1250))
	_clear_requests()
	get_tree().paused = true
	mine.call("_explode")
	_check(_requests(&"boss_mine_burst").is_empty(), "paused mine detonation guard requests no release audio")
	get_tree().paused = false
	mine.call("_explode")
	_check_one_at(&"boss_mine_burst", Vector2(1700, 1250), "mine requests its burst once when an accepted detonation resumes")

	mine = _mine(mage, Vector2(1800, 1250))
	_clear_requests()
	_invalidate(mage)
	mine.call("_explode")
	_check(_requests(&"boss_mine_burst").is_empty(), "canceled boss mine cannot request stale detonation audio")
	await _end_fixture()


func _beam(actor: EnemyActor) -> BossBeamSweep:
	var beam := BEAM.instantiate() as BossBeamSweep
	beam.telegraph_time = 0.08
	beam.sweep_time = 0.4
	beam.damage_tick = 1.0
	beam.setup(Vector2(1600, 1300), 0.3, 1.1, actor)
	SCOPE.bind(beam, actor)
	_world.add_child(beam)
	beam.set_process(false)
	return beam


func _test_beam_boundaries() -> void:
	_fixture()
	var mage := _actor(MAGE)
	_clear_requests()
	var beam := _beam(mage)
	beam.call("_process", 0.04)
	_check(_requests(&"boss_beam_release").is_empty(), "beam creation and incomplete anticipation are silent at the release boundary")
	get_tree().paused = true
	beam.call("_process", 0.2)
	_check(_requests(&"boss_beam_release").is_empty(), "paused beam anticipation cannot request release audio")
	get_tree().paused = false
	beam.call("_process", 0.05)
	beam.call("_process", 0.02)
	_check_one_at(&"boss_beam_release", Vector2(1600, 1300), "beam transition requests one positional release, not one per sweep frame")

	beam = _beam(mage)
	_clear_requests()
	_invalidate(mage)
	beam.call("_process", 0.2)
	_check(_requests(&"boss_beam_release").is_empty(), "canceled beam cannot request stale transition audio")
	await _end_fixture()


func _test_pylon_boundaries() -> void:
	_fixture()
	var mage := _actor(MAGE)
	var pylon := PYLON.instantiate() as BossPylon
	pylon.setup(Vector2(1700, 1250), mage)
	_world.add_child(pylon)
	pylon.set_process(false)
	pylon.set("_cd", 0.0)
	_clear_requests()
	pylon.call("_process", 0.01)
	_check(_requests(&"boss_pylon_shot").is_empty(), "pylon aim and windup do not play projectile release early")
	pylon.call("_process", pylon.shot_windup + 0.01)
	pylon.call("_process", 0.01)
	_check_one_at(&"boss_pylon_shot", pylon.global_position + Vector2(0, -34), "pylon projectile release requests one cue at its muzzle")

	_clear_requests()
	_invalidate(mage)
	pylon.call("_fire_shot")
	_check(_requests(&"boss_pylon_shot").is_empty(), "canceled pylon cannot request stale projectile release audio")
	await _end_fixture()


func _test_stunned_beam_cannot_finish_anticipation() -> void:
	_fixture()
	var mage := _actor(MAGE)
	var brain := mage.get_node("BossBrain")
	brain.call("_beam_sweep")
	var beam: BossBeamSweep
	for child in _world.get_children():
		if child is BossBeamSweep:
			beam = child
	_check(beam != null, "stun cancellation fixture creates the arcanist's actual beam channel")
	if beam != null:
		beam.set_process(false)
		beam.call("_process", beam.telegraph_time * 0.5)
		var warning := beam.get_node("SweepWarning")
		var fill := warning.get_node("Fill") as Sprite2D
		var anticipation_color := fill.modulate
		var anticipation_rotation := beam.rotation
		_clear_requests()
		mage.call("_apply_enemy_world_stun", 0.01)
		_check(beam.is_queued_for_deletion(), "brief stun queues the sustained channel for cancellation")
		# Deferred deletion leaves the node accessible until this frame ends.
		# Its remaining callback must not turn anticipation into a release.
		beam.call("_process", beam.telegraph_time)
		_check(_requests(&"boss_beam_release").is_empty(), "a stunned beam awaiting deletion cannot request stale release audio")
		_check(fill.modulate == anticipation_color and is_equal_approx(beam.rotation, anticipation_rotation), "a stunned beam awaiting deletion cannot display the active sweep")
	await _end_fixture()


func _run() -> void:
	SaveManager.current_save = null
	SaveManager.save_dir = "user://boss_attack_audio_test_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	Global.debug_disable_autosave = true
	SfxManager.debug_record = true
	_test_definitions()
	await _test_brain_warnings()
	await _test_physical_impact_boundaries()
	await _test_mine_boundaries()
	await _test_beam_boundaries()
	await _test_stunned_beam_cannot_finish_anticipation()
	await _test_pylon_boundaries()
	SfxManager.debug_record = false
	SfxManager.debug_requests.clear()
	print("BossAttackAudioTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
