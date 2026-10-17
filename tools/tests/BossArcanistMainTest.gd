extends Node

# The main (S10) Arcanist: the S5 committed controller with phases at 65% /
# 30%, a Pylon Pair per threshold that holds fire through major patterns, the
# Split Fan's deliberate gap, the rebuilt Arc Sweep (announced start and end
# lanes, physics clock), the Convergence Sequence, a four-node mine arc and a
# neutral beat between patterns.
const MAGE := preload("res://scenes/world/bosses/BossArcanist.tscn")
const BRAIN := preload("res://scenes/world/bosses/BossArcanistBrain.gd")
const ORACLE := preload("res://scenes/world/bosses/BossEscapeOracle.gd")
var _passes := 0
var _failures := 0
var _world: Node2D
var _mage: EnemyActor
var _brain: Node
var _player: Target
var _phases: Array = []

class Target:
	extends CharacterBody2D
	var hits: Array[float] = []
	func take_damage(amount: float, _source: Node = null) -> void:
		hits.append(amount)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _fixture() -> void:
	_world = Node2D.new()
	_world.position = Vector2(360, -210)
	get_tree().root.add_child(_world)
	get_tree().current_scene = _world
	_player = Target.new()
	_player.collision_layer = 4
	_player.collision_mask = 1795
	_player.add_to_group(&"player")
	var body := CollisionShape2D.new()
	body.name = "CollisionShape2D"
	var capsule := CapsuleShape2D.new()
	capsule.radius = 25.0
	capsule.height = 58.0
	body.shape = capsule
	_player.add_child(body)
	var hurtbox := Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.add_to_group(&"player_hurtbox")
	var hurt := CollisionShape2D.new()
	hurt.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(70, 70)
	hurt.shape = rectangle
	hurtbox.add_child(hurt)
	_player.add_child(hurtbox)
	_world.add_child(_player)
	_player.global_position = Vector2(1800, 1100)
	_mage = MAGE.instantiate() as EnemyActor
	_mage.add_to_group(&"boss")
	_mage.add_to_group(&"boss_like")
	_mage.set_meta(&"boss_home_pos", Vector2(1500, 1100))
	_mage.set_meta(&"boss_leash_radius", 900.0)
	_mage.set_meta(&"boss_disengage_radius", 1200.0)
	_mage.position = _world.to_local(Vector2(1500, 1100))
	_world.add_child(_mage)
	_mage.set_process(false)
	_mage.set_physics_process(false)
	_mage.player = _player
	_brain = _mage.get_node("BossBrain")
	_brain.set_process(false)
	_brain.set_physics_process(false)
	for key in [&"_fan_cd", &"_mines_cd", &"_blink_cd", &"_split_cd", &"_sweep_cd", &"_convergence_cd"]:
		_brain.set(key, 99.0)
	_brain.call("_ensure_teaching")
	_phases.clear()


func _finish_fixture() -> void:
	get_tree().paused = false
	get_tree().current_scene = self
	_world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _children(predicate: Callable) -> Array:
	return _world.get_children().filter(func(child: Node) -> bool: return not child.is_queued_for_deletion() and predicate.call(child))


func _shots() -> Array:
	return _children(func(child: Node) -> bool: return child is EnemyProjectile and child.shooter == _mage)


func _pylons() -> Array:
	return _children(func(child: Node) -> bool: return child is BossPylon and not child.dead)


func _beams() -> Array:
	return _children(func(child: Node) -> bool: return child is BossBeamSweep)


func _mines() -> Array:
	return _children(func(child: Node) -> bool: return child is BossMine and child.source == _mage)


func _state() -> StringName:
	return StringName(_mage.get_meta(&"boss_teaching_state", &""))


func _on_phase(boss: Node, phase: int) -> void:
	_phases.append([boss, phase])


func _test_tier_and_phases() -> void:
	_fixture()
	# Arm every legacy clock with the player in range: the timer kit would
	# cast at once if it still drove a grouped boss.
	for key in [&"_fan_cd", &"_mines_cd", &"_blink_cd", &"_beam_cd", &"_pylons_cd"]:
		_brain.set(key, 0.0)
	_player.global_position = _mage.global_position + Vector2(140, 0)
	_brain.call("_process", 1.0)
	_check(_state() == &"idle" and StringName(_brain.get("_cast_kind")) == &"" and _mines().is_empty() and _beams().is_empty() and _pylons().is_empty(), "the legacy timer kit never drives the main boss")
	for key in [&"_fan_cd", &"_mines_cd", &"_blink_cd", &"_beam_cd", &"_pylons_cd"]:
		_brain.set(key, 99.0)
	_player.global_position = Vector2(1800, 1100)
	_mage.hp = _mage.max_hp * 0.64
	_brain.call("_tick_teaching", 1.0 / 60.0)
	_check(_state() == &"phase_shift" and int(_brain.call("main_phase")) == 1, "crossing 65% begins one phase beat")
	_check(_phases.size() == 1 and _phases[0] == [_mage, 1], "the HUD hears phase 1 once")
	_brain.call("_tick_teaching", 0.81)
	_check(_state() == &"idle", "the beat ends in neutral")
	_brain.call("_tick_teaching", 1.0 / 60.0)
	var pylons := _pylons()
	var paired := pylons.size() == 2
	if paired:
		var a: Vector2 = (pylons[0] as Node2D).global_position - _player.global_position
		var b: Vector2 = (pylons[1] as Node2D).global_position - _player.global_position
		paired = absf(a.length() - BRAIN.PYLON_RING) < 0.5 and absf(b.length() - BRAIN.PYLON_RING) < 0.5 and (a + b).length() < 0.5
	_check(paired, "phase 2 raises one Pylon Pair on opposite sides of the player")
	_mage.hp = _mage.max_hp
	_brain.call("_tick_teaching", 1.0 / 60.0)
	_check(int(_brain.call("main_phase")) == 1 and _phases.size() == 1 and _pylons().size() == 2, "return healing neither re-opens the phase nor raises more pylons")
	_mage.hp = _mage.max_hp * 0.2
	_brain.call("_tick_teaching", 1.0 / 60.0)
	_check(int(_brain.call("main_phase")) == 2 and _phases.size() == 2 and _phases[1][1] == 2, "crossing 30% enters phase 3")
	_check(_pylons().is_empty(), "phase 2's pair expires with its phase")
	_brain.call("_tick_teaching", 0.81)
	_brain.call("_tick_teaching", 1.0 / 60.0)
	var fresh := _pylons()
	_check(fresh.size() == 2 and not pylons.any(func(old: Node) -> bool: return fresh.has(old)), "phase 3's pair replaces phase 2's: never more than two live")
	await _finish_fixture()


func _test_pylons_hold_fire() -> void:
	_fixture()
	_brain.set("_boss_phase", 1)
	_brain.call("_spawn_main_pylons")
	var pylons := _pylons()
	_check(pylons.size() == 2, "a pair stands ready")
	_player.global_position = _mage.global_position + Vector2(300, 0)
	_check(bool(_brain.call("_try_main_pattern", &"split")), "a Split Fan commits")
	_brain.call("_tick_teaching", 1.0 / 60.0)
	_check(bool(pylons[0].call("_holds_fire")) and bool(pylons[1].call("_holds_fire")), "pylons hold fire through the major pattern's tell")
	_brain.call("_tick_teaching", BRAIN.SPLIT_TELL)
	_brain.call("_tick_teaching", 1.0 / 60.0)
	_check(_state() == &"recovery" and not _shots().is_empty() and bool(pylons[0].call("_holds_fire")), "and through the recovery while its bolts are in the air")
	for shot in _shots():
		shot.queue_free()
	await get_tree().process_frame
	_brain.call("_tick_teaching", 0.95)
	_brain.call("_tick_teaching", 1.0 / 60.0)
	_check(_state() == &"idle" and not bool(pylons[0].call("_holds_fire")), "they fire again once the pattern has resolved")

	# A windup already charging when a major pattern commits waits instead
	# of joining it.
	var pylon := pylons[0] as BossPylon
	pylon._cd = 0.0
	pylon._process(0.0)
	_check(pylon._windup_left > 0.0, "fixture: a pylon is charging a shot in the gap")
	_check(bool(_brain.call("_try_main_pattern", &"sweep")), "an Arc Sweep commits during that windup")
	var pylon_shots := func() -> Array: return _children(func(child: Node) -> bool: return child is EnemyProjectile and child.shooter == pylon)
	pylon._process(pylon.shot_windup + 0.01)
	_check(is_zero_approx(pylon._windup_left) and pylon_shots.call().is_empty(), "the charging shot is withheld, not fired into the sweep")
	# The sweep's recovery has no bolts in the air, and still holds them.
	_brain.call("_tick_teaching", BRAIN.SWEEP_TELL + BRAIN.SWEEP_TIME + 0.01)
	_check(_state() == &"recovery" and _shots().is_empty() and bool(pylon.call("_holds_fire")), "the recovery after a major pattern holds them too")
	_brain.call("_tick_teaching", BRAIN.SWEEP_RECOVERY)
	_check(_state() == &"idle" and not bool(pylon.call("_holds_fire")), "neutral releases them")
	await _finish_fixture()


func _test_neutral_beat() -> void:
	_fixture()
	_brain.set("_boss_phase", 1)
	_player.global_position = _mage.global_position + Vector2(300, 0)
	_check(bool(_brain.call("_try_main_pattern", &"split")), "a pattern commits")
	_brain.call("_tick_teaching", BRAIN.SPLIT_TELL + 0.01)
	_brain.call("_tick_teaching", 1.0 / 60.0)
	_brain.set("_fan_cd", 0.0)
	_brain.set("_split_cd", 99.0)
	_brain.call("_tick_teaching", 0.5)
	_check(_state() == &"recovery", "its bolts are still in the air through the recovery")
	_brain.call("_tick_teaching", 0.45)
	_check(_state() == &"idle", "the recovery ends")
	_brain.call("_tick_teaching", 1.0)
	_check(_state() == &"idle", "no new pattern while the last one is in the air")
	for shot in _shots():
		shot.queue_free()
	await get_tree().process_frame
	var neutral: float = BRAIN.MAIN_NEUTRAL_SECONDS * BRAIN.MAIN_PHASE_TEMPO[1]
	_brain.call("_tick_teaching", neutral - 0.05)
	_check(_state() == &"idle", "a neutral beat follows once the field is clear")
	_brain.call("_tick_teaching", 0.1)
	_check(_state() == &"fan", "then the next pattern commits")
	await _finish_fixture()


func _test_split_fan() -> void:
	_fixture()
	_brain.set("_boss_phase", 1)
	var origin := _mage.global_position
	# Aimed off the axis, so a lane drawn without the aim, or mirrored, cannot
	# line up with the bolts by construction.
	var bearing := deg_to_rad(-57.0)
	_player.global_position = origin + Vector2(300, 0).rotated(bearing)
	_check(bool(_brain.call("_try_main_pattern", &"split")), "phase 2 commits a Split Fan with a walk out")
	var side: float = _brain.get("_split_side")
	var angles: Array[float] = _brain.call("_split_angles", side)
	var lanes_ok := angles.size() == BRAIN.SPLIT_BOLTS - 3
	var widest := 0.0
	for index in range(angles.size()):
		lanes_ok = lanes_ok and absf(angles[index]) <= deg_to_rad(48.0) + 0.0001
		if index > 0:
			widest = maxf(widest, angles[index] - angles[index - 1])
	var mirrored: Array[float] = _brain.call("_split_angles", -side)
	for index in range(mirrored.size()):
		lanes_ok = lanes_ok and is_equal_approx(mirrored[index], -angles[angles.size() - 1 - index])
	_check(lanes_ok and is_equal_approx(widest, deg_to_rad(32.0)), "ten lanes, symmetric about the aim, leave one 32-degree gap")
	var lanes := _children(func(child: Node) -> bool: return child.name == "SplitFanRayWarnings")
	_check(lanes.size() == 1 and (lanes[0] as Node).get_child_count() == angles.size(), "every bolt's lane is drawn before the release")
	# The lanes as drawn: each sprite's direction from the boss.
	var drawn: Array[float] = []
	var drawn_ok := lanes.size() == 1
	for index in range(angles.size()):
		var lane: Sprite2D = null
		if lanes.size() == 1:
			lane = (lanes[0] as Node).get_node_or_null("BoltLane%d" % index) as Sprite2D
		if lane == null:
			drawn_ok = false
			drawn.append(INF)
			continue
		drawn.append(lane.rotation)
		drawn_ok = drawn_ok and absf(angle_difference(lane.position.angle(), lane.rotation)) < 0.001 and absf(angle_difference(lane.rotation, bearing + angles[index])) < 0.001
	_check(drawn_ok, "the lanes are drawn about the aim at the player, the gap on the committed side")
	_brain.call("_tick_teaching", BRAIN.SPLIT_TELL - 0.01)
	_check(_shots().is_empty(), "the Split Fan holds its 1.1 s tell")
	_brain.call("_tick_teaching", 0.02)
	var shots := _shots()
	var directions_ok := shots.size() == drawn.size()
	for index in range(mini(shots.size(), drawn.size())):
		directions_ok = directions_ok and absf(angle_difference((shots[index] as EnemyProjectile).velocity.angle(), drawn[index])) < 0.001 and absf((shots[index] as EnemyProjectile).velocity.length() - BRAIN.SPLIT_SPEED) < 0.01
	_check(directions_ok, "the released bolts follow exactly their drawn lanes")
	_check(_state() == &"recovery", "the Split Fan ends in recovery")
	await _finish_fixture()


func _test_sweep() -> void:
	_fixture()
	_brain.set("_boss_phase", 1)
	var origin := _mage.global_position
	_player.global_position = origin + Vector2(300, 0)
	_check(bool(_brain.call("_try_main_pattern", &"sweep")), "phase 2 commits the rebuilt Arc Sweep")
	var beams := _beams()
	_check(beams.size() == 1, "one beam channels")
	if beams.size() == 1:
		var beam := beams[0] as BossBeamSweep
		_check(beam.physics_clock and not beam.is_processing() and beam.is_physics_processing(), "the sweep advances on the physics clock")
		_check(is_equal_approx(beam.telegraph_time, BRAIN.SWEEP_TELL) and is_equal_approx(beam.sweep_time, BRAIN.SWEEP_TIME) and is_equal_approx(beam.length, BRAIN.SWEEP_LENGTH), "its tell, sweep and reach are the walk-checked ones")
		_check(beam.get_node_or_null("SweepEndWarning") != null, "the end of the sweep is announced with its start")
		_check(is_equal_approx(absf(angle_difference(beam.rotation, 0.0)), BRAIN.SWEEP_HALF_ARC), "the sweep starts one half-arc to one side of the player")
	_check(_state() == &"sweep" and bool(_mage.get_meta(&"boss_cast_locked", false)), "the channel roots the Arcanist")
	_brain.call("_tick_teaching", BRAIN.SWEEP_TELL + BRAIN.SWEEP_TIME - 0.02)
	_check(_state() == &"sweep", "the channel lasts through the whole sweep")
	_brain.call("_tick_teaching", 0.03)
	_check(_state() == &"recovery", "a recovery follows the sweep")
	await _finish_fixture()


func _test_convergence() -> void:
	_fixture()
	_brain.set("_boss_phase", 2)
	var origin := _mage.global_position
	_player.global_position = origin + Vector2(300, 0)
	_check(bool(_brain.call("_try_main_pattern", &"convergence")), "phase 3 commits the Convergence Sequence")
	var beams := _beams()
	_check(beams.size() == 1 and is_equal_approx((beams[0] as BossBeamSweep).telegraph_time, BRAIN.SPLIT_TELL + BRAIN.CONVERGENCE_BEAM_DELAY), "the sweep is announced from the start and waits for the fan to resolve")
	_check(_state() == &"convergence_fan", "the split fan comes first")
	_brain.call("_tick_teaching", BRAIN.SPLIT_TELL + 0.01)
	_check(not _shots().is_empty() and _state() == &"convergence_beam", "the split resolves before the sweep begins")
	var windup = _brain.get("_windup")
	_check(is_instance_valid(windup) and not windup.is_queued_for_deletion(), "the staff channels the sweep's beat")
	_brain.call("_tick_teaching", BRAIN.CONVERGENCE_BEAM_DELAY + BRAIN.SWEEP_TIME)
	_check(_state() == &"recovery", "a longer recovery closes the sequence")
	await _finish_fixture()


func _test_mine_arc() -> void:
	_fixture()
	_brain.set("_boss_phase", 2)
	_player.global_position = _mage.global_position + Vector2(260, 0)
	_check(bool(_brain.call("_try_main_pattern", &"mines")), "phase 3 plants a mine arc")
	_brain.call("_tick_teaching", 0.61)
	var mines := _mines()
	_check(mines.size() == 4, "the arc has four nodes")
	_check(mines.size() > 0 and is_equal_approx((mines[0] as BossMine).damage, 15.0 * 1.4), "phase 3 mines hit harder")
	_check(mines.size() > 0 and bool((mines[0] as BossMine).call("_uses_teaching_clock")), "main-boss mines fuse on the physics clock")
	await _finish_fixture()


func _test_sweep_geometry_is_fair() -> void:
	var shape := {}
	var body := [{"center": Vector2.ZERO, "radius": 42.16}]
	var legacy := [{"kind": &"beam", "origin": Vector2.ZERO, "angle_from": deg_to_rad(-55.0), "angle_to": deg_to_rad(55.0), "length": 680.0, "width": 34.0, "from": 0.55, "to": 1.7}]
	var rebuilt := [{"kind": &"beam", "origin": Vector2.ZERO, "angle_from": -BRAIN.SWEEP_HALF_ARC, "angle_to": BRAIN.SWEEP_HALF_ARC, "length": BRAIN.SWEEP_LENGTH, "width": BRAIN.SWEEP_WIDTH, "from": BRAIN.SWEEP_TELL, "to": BRAIN.SWEEP_TELL + BRAIN.SWEEP_TIME}]
	var legacy_escapes := 0
	var rebuilt_escapes := 0
	var samples := 0
	for distance in [120.0, 200.0, 300.0, 400.0, 500.0]:
		for degrees in [0.0, 15.0, 30.0]:
			var at: Vector2 = Vector2.from_angle(deg_to_rad(degrees)) * distance
			samples += 1
			legacy_escapes += 1 if ORACLE.has_escape(at, legacy, shape, body) else 0
			rebuilt_escapes += 1 if ORACLE.has_escape(at, rebuilt, shape, body) else 0
	_check(rebuilt_escapes == samples and legacy_escapes < samples / 3, "the rebuilt sweep keeps a walk out everywhere the legacy one trapped the player (%d/%d vs %d/%d)" % [rebuilt_escapes, samples, legacy_escapes, samples])


func _run() -> void:
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://arcanist_main_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	Global.debug_disable_autosave = true
	var previous_seed := Global.attempt_world_seed
	Global.attempt_world_seed = 7341
	RunEvents.boss_phase_changed.connect(_on_phase)
	await _test_tier_and_phases()
	await _test_pylons_hold_fire()
	await _test_split_fan()
	await _test_neutral_beat()
	await _test_sweep()
	await _test_convergence()
	await _test_mine_arc()
	_test_sweep_geometry_is_fair()
	RunEvents.boss_phase_changed.disconnect(_on_phase)
	Global.attempt_world_seed = previous_seed
	print("BossArcanistMainTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
