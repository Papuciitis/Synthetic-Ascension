extends Node

# The main (S10) Bulldozer: the committed state machine S5 established, now
# with phases at 65% / 30%, the Sweeping Cleave and one Runner call in phase
# 2, the Breach Sequence and a Fault Line follow-up in phase 3, and a
# walk-out check (BossEscapeOracle) in front of every commitment. Real boss,
# real hazards; the fixture only stops autonomous selection between steps.
const TANK := preload("res://scenes/world/bosses/BossBulldozer.tscn")
const PLAYER := preload("res://core/actors/player/player.tscn")
const WARNING := preload("res://scenes/world/bosses/BossGroundWarning.gd")
const SECTOR_WARNING := preload("res://scenes/world/bosses/BossSectorWarning.gd")
const ORACLE := preload("res://scenes/world/bosses/BossEscapeOracle.gd")
const ARRIVAL := preload("res://scenes/world/bosses/BossArrivalSprites.gd")
const RUNNER_PATH := "res://scenes/world/enemies/EnemyRunner.tscn"
const BRAIN := preload("res://scenes/world/bosses/BossBulldozerBrain.gd")
const ARENA := preload("res://scenes/world/events/BossArena.tscn")
var _passes := 0
var _failures := 0
var _world: Node2D
var _player: CharacterBody2D
var _events: Array[Dictionary] = []
var _phases: Array = []


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
	_world.position = Vector2(200, -100)
	get_tree().root.add_child(_world)
	get_tree().current_scene = _world
	_player = PLAYER.instantiate() as CharacterBody2D
	_world.add_child(_player)
	_player.set_process(false)
	_player.set_physics_process(false)
	_player.global_position = Vector2(2200, 1100)
	_player.set("big_hit_protection", false)
	_player.set("invulnerable_time", 0.0)
	_player.set("max_hp", 1000.0)
	_player.set("hp", 1000.0)
	var stats = _player.get("stats")
	if stats != null:
		stats.armor = 0.0
	_events.clear()
	_phases.clear()


func _tank(at: Vector2 = Vector2(1500, 1100)) -> EnemyActor:
	var actor := TANK.instantiate() as EnemyActor
	actor.position = _world.to_local(at)
	_world.add_child(actor)
	actor.add_to_group(&"boss")
	actor.add_to_group(&"boss_like")
	actor.set_process(false)
	actor.set_physics_process(false)
	var brain := actor.get_node("BossBrain")
	brain.set_process(false)
	brain.set_physics_process(false)
	brain.call("_sync_tier")
	return actor


func _clear() -> void:
	get_tree().paused = false
	get_tree().current_scene = self
	_world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _children(predicate: Callable) -> Array:
	return _world.get_children().filter(func(child: Node) -> bool: return not child.is_queued_for_deletion() and predicate.call(child))


func _circles() -> Array:
	return _children(func(child: Node) -> bool: return child is DamageCircle)


func _strikes() -> Array:
	return _children(func(child: Node) -> bool: return child is BossSectorStrike)


func _with_script(script: Script) -> Array:
	return _children(func(child: Node) -> bool: return child.get_script() == script)


func _runners() -> Array:
	return _children(func(child: Node) -> bool: return child is EnemyActor and child.scene_file_path == RUNNER_PATH)


func _state(tank: EnemyActor) -> StringName:
	return tank.get_meta(&"boss_teaching_state", &"")


func _on_damage(player: Node, raw: float, _adjusted: float, _applied: float, source: Node, kind: StringName, _outcome: StringName) -> void:
	if player == _player:
		_events.append({"raw": raw, "source": source, "kind": kind})


func _on_phase(boss: Node, phase: int) -> void:
	_phases.append([boss, phase])


func _test_controller_owns_main_tier() -> void:
	_fixture()
	var tank := _tank()
	var brain := tank.get_node("BossBrain")
	_check(bool(tank.get_meta(&"boss_controller_owns_charge", false)), "the main brain owns its rushes like S5")
	_player.global_position = tank.global_position + Vector2(200, 0)
	var chase: Vector2 = tank._charge.brain(Vector2.RIGHT, 200.0)
	_check(tank._charge._windup_left <= 0.0 and tank._charge._time_left <= 0.0 and chase.x > 0.0, "the legacy charge brain can no longer start an independent main-boss rush")
	_check(not brain.has_method("_process") and not brain.is_processing(), "no render-time timers drive the main kit")
	brain.set("_rush_cd", 0.0)
	brain.set("_slam_cd", 0.0)
	brain.set("_shock_cd", 0.0)
	brain.call("_tick_main_selection", 1.0 / 60.0)
	var first := _state(tank)
	_check(first in [&"slam", &"rush_tell", &"shock"], "phase 1 commits one of its three established attacks (%s)" % first)
	brain.call("_tick_main_selection", 1.0 / 60.0)
	_check(_state(tank) == first, "a committed attack cannot overlap another selection")
	await _clear()


func _test_phases() -> void:
	_fixture()
	var tank := _tank()
	var brain := tank.get_node("BossBrain")
	_player.global_position = tank.global_position + Vector2(700, 0)
	for property in ["_rush_cd", "_slam_cd", "_shock_cd", "_cleave_cd", "_breach_cd"]:
		brain.set(property, 100.0)
	tank.hp = tank.max_hp * 0.64
	brain.call("_tick_main_selection", 1.0 / 60.0)
	_check(_state(tank) == &"phase_shift" and int(brain.call("main_phase")) == 1, "crossing 65% begins one visible phase beat")
	_check(_phases.size() == 1 and _phases[0][0] == tank and _phases[0][1] == 1, "the HUD hears phase 1 once")
	_check(bool(tank.get_meta(&"boss_cast_locked", false)), "the beat plants the boss")
	# Health lives on the boss's world record; the fixture only staged hp.
	var handle := EnemyWorld.handle_for_actor(tank)
	var health_before := EnemyWorld.get_health(handle)
	tank.take_damage(1.0, _player)
	_check(EnemyWorld.get_health(handle) < health_before, "the boss stays damageable through its phase beat")
	brain.call("_tick_cast", 0.79)
	_check(_state(tank) == &"phase_shift", "the beat lasts its full 0.8 s")
	brain.call("_tick_cast", 0.02)
	_check(_state(tank) == &"idle", "the beat returns to neutral without an attack")
	brain.call("_tick_main_selection", 1.0 / 60.0)
	_check(_state(tank) == &"summon" and _with_script(ARRIVAL).size() == 3, "phase 2's one Runner call follows the beat with its warned arrivals")
	brain.call("_tick_cast", 0.99)
	_check(_runners().is_empty(), "the call releases nothing during its 1.0 s tell")
	brain.call("_tick_cast", 0.02)
	_check(_runners().size() == 3, "the call releases three Runners after its full tell")
	for runner in _runners():
		runner.set_physics_process(false)
		runner.set_process(false)
	brain.call("_tick_cast", 0.95)
	tank.hp = tank.max_hp
	brain.call("_tick_main_selection", 1.0 / 60.0)
	_check(int(brain.call("main_phase")) == 1 and _phases.size() == 1, "return healing never re-opens a phase")
	_check(_state(tank) == &"idle" and _with_script(ARRIVAL).is_empty(), "and never calls a second wave")
	await _clear()

	_fixture()
	tank = _tank()
	brain = tank.get_node("BossBrain")
	_player.global_position = tank.global_position + Vector2(700, 0)
	for property in ["_rush_cd", "_slam_cd", "_shock_cd", "_cleave_cd", "_breach_cd"]:
		brain.set(property, 100.0)
	tank.hp = tank.max_hp * 0.2
	brain.call("_tick_main_selection", 1.0 / 60.0)
	_check(int(brain.call("main_phase")) == 2 and _phases.size() == 1 and _phases[0][1] == 2, "both thresholds crossed at once make one transition to phase 3")
	brain.call("_tick_cast", 0.81)
	brain.call("_tick_main_selection", 1.0 / 60.0)
	_check(_state(tank) == &"summon", "the skipped phase still owes exactly one Runner call")
	await _clear()


func _test_cleave() -> void:
	_fixture()
	var tank := _tank()
	var brain := tank.get_node("BossBrain")
	brain.set("_boss_phase", 1)
	var origin := tank.global_position
	_player.global_position = origin + Vector2(120, 0)
	_check(bool(brain.call("_try_main_attack", &"cleave")), "a frontal player inside the cleave's reach is cleaved")
	var sectors := _with_script(SECTOR_WARNING)
	_check(sectors.size() == 1 and (sectors[0] as Node2D).global_position.is_equal_approx(origin) and is_zero_approx((sectors[0] as Node2D).rotation), "the cleave's raster bound faces its captured direction from the planted origin")
	_player.global_position = origin + Vector2(120, 160)
	brain.call("_tick_cast", BRAIN.CLEAVE_TELL - 0.01)
	_check(_strikes().is_empty(), "the cleave holds its full 1.1 s tell")
	_player.global_position = origin + Vector2(120, 0)
	brain.call("_tick_cast", 0.02)
	var strikes := _strikes()
	_check(strikes.size() == 1, "the cleave releases one sector strike")
	if strikes.size() == 1:
		var polygon := ((strikes[0] as BossSectorStrike).get_child(0) as CollisionShape2D).shape as ConvexPolygonShape2D
		var expected := ORACLE.sector_polygon(Vector2.ZERO, 0.0, BRAIN.CLEAVE_RADIUS, BRAIN.CLEAVE_HALF_ANGLE)
		_check(polygon != null and polygon.points == expected, "the strike's polygon is the warned and walk-checked sector")
	_events.clear()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var cleave_hits := _events.filter(func(event: Dictionary) -> bool: return event.source == tank)
	_check(cleave_hits.size() == 1 and is_equal_approx(float(cleave_hits[0].raw), BRAIN.CLEAVE_DAMAGE), "a player in the sector takes one cleave")
	_check(_state(tank) == &"recovery" and bool(tank.get_meta(&"boss_cast_locked", false)), "the cleave opens a planted recovery")
	brain.call("_tick_cast", BRAIN.CLEAVE_RECOVERY - 0.02)
	_check(_state(tank) == &"recovery", "the cleave's opening lasts 1.0 s")
	brain.call("_tick_cast", 0.04)
	_check(_state(tank) != &"recovery", "and no longer")
	await _clear()

	_fixture()
	tank = _tank()
	brain = tank.get_node("BossBrain")
	brain.set("_boss_phase", 1)
	origin = tank.global_position
	_player.global_position = origin + Vector2(120, 0)
	brain.call("_try_main_attack", &"cleave")
	# The facing is captured at commitment; stepping behind escapes it.
	_player.global_position = origin + Vector2(-130, 0)
	brain.call("_tick_cast", BRAIN.CLEAVE_TELL + 0.01)
	_events.clear()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(_events.is_empty(), "behind the cleave's facing nothing is struck")
	await _clear()

	# Off the axis the warning, the strike and the blow all turn with the
	# captured facing: at 0 rad a dropped or negated facing looks the same.
	_fixture()
	tank = _tank()
	brain = tank.get_node("BossBrain")
	brain.set("_boss_phase", 1)
	origin = tank.global_position
	var facing := deg_to_rad(-110.0)
	_player.global_position = origin + Vector2(120, 0).rotated(facing)
	_check(bool(brain.call("_try_main_attack", &"cleave")), "fixture: an off-axis cleave commits")
	sectors = _with_script(SECTOR_WARNING)
	_check(sectors.size() == 1 and absf(angle_difference((sectors[0] as Node2D).rotation, facing)) < 0.001, "the cleave's warning turns to its captured facing")
	brain.call("_tick_cast", BRAIN.CLEAVE_TELL + 0.01)
	strikes = _strikes()
	var turned_ok := strikes.size() == 1
	if turned_ok:
		var turned := ((strikes[0] as BossSectorStrike).get_child(0) as CollisionShape2D).shape as ConvexPolygonShape2D
		var turned_expected := ORACLE.sector_polygon(Vector2.ZERO, facing, BRAIN.CLEAVE_RADIUS, BRAIN.CLEAVE_HALF_ANGLE)
		turned_ok = turned != null and turned.points.size() == turned_expected.size()
		for index in range(turned_expected.size() if turned_ok else 0):
			# The facing comes from float32 world positions: within 0.01 px.
			turned_ok = turned_ok and turned.points[index].distance_to(turned_expected[index]) < 0.01
	_check(turned_ok, "the strike's sector turns with it")
	_events.clear()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(_events.filter(func(event: Dictionary) -> bool: return event.source == tank).size() == 1, "and strikes the player standing in it")
	await _clear()


func _run_charge(tank: EnemyActor, brain: Node, steps: int) -> void:
	for _step in range(steps):
		tank.call("_run_simulation_step", 1.0 / 60.0)
		brain.call("_physics_process", 1.0 / 60.0)
		await get_tree().physics_frame


func _test_breach() -> void:
	_fixture()
	var tank := _tank()
	var brain := tank.get_node("BossBrain")
	brain.set("_boss_phase", 2)
	var origin := tank.global_position
	_player.global_position = origin + Vector2(150, 0)
	_check(bool(brain.call("_try_main_attack", &"breach")), "phase 3 commits the Breach Sequence when a walk out exists")
	var travel: float = tank.spec.charge_speed * tank.spec.charge_duration
	var target := origin + Vector2.RIGHT * travel
	var announced := _with_script(WARNING).filter(func(node: Node2D) -> bool: return node.global_position.is_equal_approx(target))
	_check(announced.size() == 1, "the planted follow-up is announced at the lane's end before the rush moves")
	_check(_state(tank) == &"breach_tell", "the breach opens with its rush tell")
	_player.global_position = origin + Vector2(150, 260)
	brain.call("_tick_cast", BRAIN.BREACH_RUSH_TELL - 0.01)
	_check(tank._charge._time_left <= 0.0, "the breach rush waits for its 0.95 s tell")
	brain.call("_tick_cast", 0.02)
	_check(_state(tank) == &"breach_rush", "the rush commits along the announced lane")
	await get_tree().physics_frame
	await _run_charge(tank, brain, 24)
	_check(tank.global_position.distance_to(target) <= BRAIN.BREACH_ARRIVAL_TOLERANCE, "the rush plants at the announced end")
	_check(_state(tank) == &"breach_beat" and _circles().is_empty(), "an explicit beat separates the rush from the impact")
	# The charge loop's last steps already spent part of the beat.
	var spent: float = brain.get("_cast_elapsed")
	brain.call("_tick_cast", BRAIN.BREACH_BEAT - 0.01 - spent)
	_check(_circles().is_empty(), "the beat lasts its 0.5 s")
	brain.call("_tick_cast", 0.02)
	var circles := _circles()
	_check(circles.size() == 1 and (circles[0] as Node2D).global_position.is_equal_approx(target) and is_equal_approx(float((circles[0] as DamageCircle).radius), BRAIN.BREACH_IMPACT_RADIUS), "the impact lands exactly where it was announced")
	_check(_state(tank) == &"recovery", "the breach ends in its longest recovery")
	brain.call("_tick_cast", BRAIN.BREACH_RECOVERY - 0.02)
	_check(_state(tank) == &"recovery", "that recovery lasts 1.2 s")
	brain.call("_tick_cast", 0.04)
	_check(_state(tank) != &"recovery", "and no longer")
	await _clear()

	_fixture()
	tank = _tank()
	brain = tank.get_node("BossBrain")
	brain.set("_boss_phase", 2)
	origin = tank.global_position
	_player.global_position = origin + Vector2(150, 0)
	brain.call("_try_main_attack", &"breach")
	var wall := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(40, 400)
	collider.shape = box
	wall.add_child(collider)
	_world.add_child(wall)
	wall.global_position = origin + Vector2(170, 0)
	_player.global_position = origin + Vector2(150, 300)
	brain.call("_tick_cast", BRAIN.BREACH_RUSH_TELL + 0.01)
	await get_tree().physics_frame
	await _run_charge(tank, brain, 30)
	_check(tank.global_position.distance_to(origin + Vector2.RIGHT * travel) > BRAIN.BREACH_ARRIVAL_TOLERANCE, "a wall stops the rush short")
	_check(_circles().is_empty() and _with_script(WARNING).is_empty(), "the announced impact is withdrawn, never moved to where the rush stopped")
	_check(_state(tank) == &"recovery", "a stopped breach still ends in recovery")
	await _clear()


func _test_rush_keeps_its_lane() -> void:
	_fixture()
	var tank := _tank()
	var brain := tank.get_node("BossBrain")
	var origin := tank.global_position
	_player.global_position = origin + Vector2(200, 0)
	_check(bool(brain.call("_begin_teaching_rush")), "fixture: a rush commits along +x")
	_player.global_position = origin + Vector2(150, 320)
	# A wall at 30 degrees across the lane: sliding along it would carry the
	# body off the drawn lane, toward a player who stood clear of it.
	var wall := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(30, 600)
	collider.shape = box
	wall.add_child(collider)
	_world.add_child(wall)
	wall.global_position = origin + Vector2(190, 0)
	wall.rotation = deg_to_rad(30.0)
	brain.call("_tick_cast", BRAIN.TEACHING_RUSH_TELL + 0.01)
	_check(_state(tank) == &"rush", "fixture: the rush released")
	# A shove mid-rush must not drift it either.
	tank.knockback_vel = Vector2(0, 400)
	await get_tree().physics_frame
	await _run_charge(tank, brain, 30)
	var offset := tank.global_position - origin
	_check(absf(offset.y) < 0.5, "the rush stays on its drawn lane against an oblique wall and a shove (off by %.2f px)" % offset.y)
	_check(offset.x < tank.spec.charge_speed * tank.spec.charge_duration - 10.0, "the wall stops it short where it stands")
	_check(_state(tank) == &"recovery", "and the stopped rush still ends in recovery")
	await _clear()


## The drawn lane starts at the body's centre and runs forward: a player
## touching the boss's back at release is outside it and is never struck by
## a body charging away; one touching its front is struck once.
func _test_rush_spares_the_back() -> void:
	for side in [-1.0, 1.0]:
		_fixture()
		var tank := _tank()
		var brain := tank.get_node("BossBrain")
		var origin := tank.global_position
		_player.global_position = origin + Vector2(200, 0)
		_check(bool(brain.call("_begin_teaching_rush")), "fixture: a rush commits along +x")
		# Body to body: the boss's circle and the player's capsule radius. The
		# physics space learns a moved body's place at its next step; in play
		# the player has stood there for many.
		_player.global_position = origin + Vector2(side * (float(brain.call("_body_radius")) + 25.0), 0)
		await get_tree().physics_frame
		await get_tree().physics_frame
		brain.call("_tick_cast", BRAIN.TEACHING_RUSH_TELL + 0.01)
		_events.clear()
		await get_tree().physics_frame
		await _run_charge(tank, brain, 6)
		var struck := _events.filter(func(event: Dictionary) -> bool: return event.source == tank).size()
		if side < 0.0:
			_check(struck == 0, "a player touching the boss's back is outside the lane and never struck")
		else:
			_check(struck == 1, "a player touching its front is struck once (%d)" % struck)
		await _clear()


func _test_fault_followup() -> void:
	_fixture()
	var tank := _tank()
	var brain := tank.get_node("BossBrain")
	brain.set("_boss_phase", 2)
	var origin := tank.global_position
	_player.global_position = origin + Vector2(0, -300)
	var turned := Vector2.RIGHT.rotated(BRAIN.FOLLOWUP_TURN)
	brain.set("_followup_dir", turned)
	_player.global_position = origin + Vector2(300, 0)
	brain.call("_do_shockwave")
	var warnings := _with_script(WARNING)
	var positions_ok := warnings.size() == 6
	for index in range(mini(warnings.size(), 6)):
		var line := Vector2.RIGHT if index < 3 else turned
		positions_ok = positions_ok and (warnings[index] as Node2D).global_position.is_equal_approx(origin + line * 140.0 * float(index % 3 + 1))
	_check(positions_ok, "both lines' six nodes are previewed before the first release")
	_player.global_position = origin + Vector2(-400, 0)
	var expected := [1.35, 1.67, 1.99, 2.59, 2.91, 3.23]
	var timing_ok := true
	var elapsed := 0.0
	for index in range(6):
		brain.call("_tick_cast", expected[index] - 0.01 - elapsed)
		timing_ok = timing_ok and _circles().size() == index
		brain.call("_tick_cast", 0.02)
		elapsed = expected[index] + 0.01
		timing_ok = timing_ok and _circles().size() == index + 1
	_check(timing_ok, "the follow-up line releases 0.6 s after the first, at the same 0.32 s pace")
	_check(_state(tank) == &"recovery", "the six-node pattern ends in one recovery")
	await _clear()


func _test_oracle_guard() -> void:
	_fixture()
	var tank := _tank()
	var brain := tank.get_node("BossBrain")
	var origin := tank.global_position
	# Standing on the first Fault Line node, a Warforged Melee's 90 px/s walk
	# is still 12 px inside its reach at the 1.35 s release, whichever way it
	# goes (at 100 px/s a sidestep would end exactly on the edge).
	_player.global_position = origin + Vector2(140, 0)
	_player.set("speed", 90.0)
	_check(not bool(brain.call("_try_main_attack", &"shock")), "a Fault Line the player could not walk out of is never committed")
	_check(_state(tank) == &"idle" and _with_script(WARNING).is_empty(), "the refused attack leaves no warning or lock")
	for property in ["_rush_cd", "_slam_cd", "_cleave_cd", "_breach_cd"]:
		brain.set(property, 100.0)
	brain.set("_shock_cd", 0.0)
	brain.call("_tick_main_selection", 1.0 / 60.0)
	_check(_state(tank) == &"idle" and float(brain.get("_selection_hold")) > 0.0, "selection waits rather than commit an inescapable attack")
	_player.global_position = origin + Vector2(400, 0)
	brain.set("_selection_hold", 0.0)
	brain.call("_tick_main_selection", 1.0 / 60.0)
	_check(_state(tank) == &"shock", "once a walk out exists the same attack commits")
	await _clear()


func _test_arena_speed() -> void:
	_fixture()
	var tank := _tank()
	var before: float = tank._spd()
	var arena := ARENA.instantiate() as BossArena
	# Only its rules are under test: no trigger or proximity spawn.
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	_world.add_child(arena)
	arena.call("_apply_boss_rewards_and_rules", tank)
	_check(is_equal_approx(tank._spd(), before * arena.speed_mult), "the arena's movement tuning reaches the movement baseline (%.1f -> %.1f)" % [before, tank._spd()])
	tank.apply_speed_buff(1.5, 1.0)
	_check(is_equal_approx(tank._spd(), before * arena.speed_mult * 1.5), "temporary buffs still compose on the tuned baseline")
	await _clear()


func _run() -> void:
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://boss_bulldozer_main_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	Global.debug_disable_autosave = true
	Global.debug_player_god_mode = false
	Global.run_luck = 0.0
	RunEvents.player_damage_resolved.connect(_on_damage)
	RunEvents.boss_phase_changed.connect(_on_phase)
	await _test_controller_owns_main_tier()
	await _test_phases()
	await _test_cleave()
	await _test_breach()
	await _test_rush_keeps_its_lane()
	await _test_rush_spares_the_back()
	await _test_fault_followup()
	await _test_oracle_guard()
	await _test_arena_speed()
	RunEvents.player_damage_resolved.disconnect(_on_damage)
	RunEvents.boss_phase_changed.disconnect(_on_phase)
	print("BossBulldozerMainTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
