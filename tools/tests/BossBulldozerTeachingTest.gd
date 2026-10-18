extends Node

# Real boss, movement module, player contact ledger and damage circles. The
# fixture stops autonomous selection only; acceptance/release paths stay real.
const TANK := preload("res://scenes/world/bosses/BossBulldozer.tscn")
const PLAYER := preload("res://core/actors/player/player.tscn")
const SCOPE := preload("res://scenes/world/bosses/BossAttackScope.gd")
const WARNING := preload("res://scenes/world/bosses/BossGroundWarning.gd")
const RUNNER_PATH := "res://scenes/world/enemies/EnemyRunner.tscn"
const ARRIVAL_PATH := "res://scenes/world/bosses/BossArrivalSprites.gd"
var _passes := 0
var _failures := 0
var _world: Node2D
var _player: CharacterBody2D
var _events: Array[Dictionary] = []
var _kills := 0


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


func _tank(at: Vector2 = Vector2(1500, 1100), main_boss: bool = false) -> EnemyActor:
	var actor := TANK.instantiate() as EnemyActor
	actor.position = _world.to_local(at)
	_world.add_child(actor)
	actor.add_to_group(&"boss" if main_boss else &"miniboss")
	actor.add_to_group(&"boss_like")
	actor.set_process(false)
	actor.set_physics_process(false)
	var brain := actor.get_node("BossBrain")
	brain.set_process(false)
	brain.set_physics_process(false)
	return actor


func _clear() -> void:
	get_tree().paused = false
	get_tree().current_scene = self
	_world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _circles() -> Array[DamageCircle]:
	var result: Array[DamageCircle] = []
	for child in _world.get_children():
		if child is DamageCircle and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _runners() -> Array[EnemyActor]:
	var result: Array[EnemyActor] = []
	for child in _world.get_children():
		if child is EnemyActor and child.scene_file_path == RUNNER_PATH and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _markers(script: Script) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for child in _world.get_children():
		if child is Node2D and child.get_script() == script and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _test_planted_slam() -> void:
	_fixture()
	var tank := _tank()
	var brain := tank.get_node("BossBrain")
	brain.call("_do_slam")
	_check(tank.get_meta(&"boss_teaching_state", &"") == &"slam", "S5 exposes its accepted planted-impact state")
	brain.call("_tick_cast", 1.29)
	_check(_circles().is_empty(), "S5 planted impact grants at least1.3s of anticipation at baseline walking speed")
	brain.call("_tick_cast", 0.02)
	var circles := _circles()
	_check(circles.size() == 1 and circles[0].global_position == Vector2(1500, 1100), "planted impact releases once at the captured non-origin world point")
	_check(tank.get_meta(&"boss_teaching_state", &"") == &"recovery" and bool(tank.get_meta(&"boss_cast_locked", false)), "released slam enters a real locked recovery opening")
	var before := tank.global_position
	tank.call("_run_simulation_step", 1.0 / 60.0)
	brain.call("_do_shockwave")
	_check(tank.global_position.is_equal_approx(before) and _markers(WARNING).is_empty(), "recovery prevents normal movement, a charge start and another major cast")
	var hp_before := tank.hp
	tank.take_damage(1.0, _player)
	_check(tank.hp < hp_before, "recovery leaves the boss damageable to the player's opening")
	brain.call("_tick_cast", 0.88)
	_check(tank.get_meta(&"boss_teaching_state", &"") == &"recovery", "slam recovery lasts its full0.9s")
	brain.call("_tick_cast", 0.03)
	_check(tank.get_meta(&"boss_teaching_state", &"") == &"idle" and not bool(tank.get_meta(&"boss_cast_locked", false)), "completed recovery releases movement without another attack")
	await _clear()


func _test_fault_line() -> void:
	_fixture()
	var tank := _tank()
	_player.global_position = tank.global_position + Vector2(400, 0)
	var brain := tank.get_node("BossBrain")
	brain.call("_do_shockwave")
	var warnings := _markers(WARNING)
	var preview_ok := warnings.size() == 3
	for index in range(warnings.size()):
		preview_ok = preview_ok and warnings[index].global_position.is_equal_approx(Vector2(1640 + index * 140, 1100))
	_check(preview_ok, "Fault Line previews all three committed nodes before its first release")
	_player.global_position += Vector2(0, 200)
	brain.call("_tick_cast", 1.34)
	_check(_circles().is_empty(), "Fault Line holds its full1.35s introductory tell")
	brain.call("_tick_cast", 0.02)
	_check(_circles().size() == 1 and _circles()[0].global_position == Vector2(1640, 1100), "Fault Line first release preserves its captured direction")
	brain.call("_tick_cast", 0.30)
	_check(_circles().size() == 1, "Fault Line gives0.32s between the first and second release")
	brain.call("_tick_cast", 0.02)
	_check(_circles().size() == 2, "Fault Line advances to its second marked node")
	brain.call("_tick_cast", 0.32)
	_check(_circles().size() == 3 and tank.get_meta(&"boss_teaching_state", &"") == &"recovery", "third Fault Line release starts the advertised recovery")
	await _clear()


func _test_slow_player_slam() -> void:
	_fixture()
	var tank := _tank()
	tank.player = _player
	_player.speed = 80.0
	_player.global_position = tank.global_position + Vector2(100, 0)
	var brain := tank.get_node("BossBrain")
	brain.call("_do_slam")
	brain.call("_tick_cast", 1.31)
	_check(_circles().is_empty() and tank.get_meta(&"boss_teaching_state", &"") == &"slam", "the S5 slam extends its warning for an 80 px/s walk instead of trapping a slow race")
	# A speed change after commitment cannot silently shorten the warning.
	_player.speed = 160.0
	brain.call("_tick_cast", 0.30)
	_check(_circles().is_empty(), "the committed slow-player warning keeps its captured duration after a speed change")
	brain.call("_tick_cast", 0.03)
	_check(_circles().size() == 1, "the extended S5 slam still releases once after its full warning")
	await _clear()


func _test_rush_cosmetic_pressure() -> void:
	for main_boss in [false, true]:
		_fixture()
		var tank := _tank(Vector2(1500, 1100), main_boss)
		var brain := tank.get_node("BossBrain")
		tank._charge._time_left = 0.36
		brain.call("_track_charge", 0.016)
		tank.global_position += Vector2(90, 0)
		brain.call("_track_charge", 0.016)
		_check(_circles().is_empty(), "%s rush trail is cosmetic and leaves no damaging crumbs" % ("S10" if main_boss else "S5"))
		tank._charge._time_left = 0.0
		brain.call("_track_charge", 0.016)
		_check(_circles().is_empty(), "%s rush endpoint wave cannot add an unannounced damage circle" % ("S10" if main_boss else "S5"))
		await _clear()


func _test_rush_commitment_and_contact() -> void:
	_fixture()
	var tank := _tank()
	var brain := tank.get_node("BossBrain")
	_player.global_position = tank.global_position + Vector2(160, 0)
	var supports_rush := brain.has_method("_begin_teaching_rush")
	_check(supports_rush, "S5 controller exposes the same committed rush acceptance used by actual AI")
	if not supports_rush:
		await _clear()
		return
	brain.call("_begin_teaching_rush")
	_check(tank.get_meta(&"boss_teaching_state", &"") == &"rush_tell", "accepted rush visibly holds its teaching anticipation")
	_player.global_position = tank.global_position + Vector2(160, 120)
	brain.call("_tick_cast", 0.84)
	_check(tank._charge._time_left <= 0.0 and tank.global_position == Vector2(1500, 1100), "rush cannot move before its full0.85s tell")
	brain.call("_tick_cast", 0.02)
	_check(tank._charge._dir.is_equal_approx(Vector2.RIGHT), "rush direction stays locked when the player moves during anticipation")
	_player.global_position = tank.global_position + Vector2(160, 0)
	await get_tree().physics_frame
	_events.clear()
	for step in range(24):
		tank.call("_run_simulation_step", 1.0 / 60.0)
		brain.call("_physics_process", 1.0 / 60.0)
		await get_tree().physics_frame
	var rush_events := _events.filter(func(event: Dictionary) -> bool: return event.source == tank)
	var stacked_contact := _events.filter(func(event: Dictionary) -> bool: return event.kind == &"contact_swarm")
	_check(rush_events.size() == 1, "actual physical rush intersection resolves one explicit hit per commitment")
	_check(stacked_contact.is_empty(), "rush overlap does not stack the boss's ordinary contact tick")
	_check(tank.get_meta(&"boss_teaching_state", &"") == &"recovery", "completed physical rush enters endpoint recovery")
	_check(_circles().is_empty(), "actual S5 rush still creates no damaging trail or endpoint")
	await _clear()


func _test_contact_ledger_keeps_ambient() -> void:
	_fixture()
	var tank := _tank()
	tank.set_meta(&"boss_contact_suppressed", true)
	_player.set("_damage_loop_running", true)
	_player.call("_register_contact_source", tank)
	_player.call("_register_contact_source", tank)
	var ambient := CharacterBody2D.new()
	ambient.add_to_group(&"enemies")
	_world.add_child(ambient)
	_player.call("_register_contact_source", ambient)
	_player.set("_damage_loop_running", false)
	_events.clear()
	_player.call("_start_contact_loop")
	var contact_events := _events.filter(func(event: Dictionary) -> bool: return event.kind == &"contact_swarm")
	_check(contact_events.size() == 1 and is_equal_approx(float(contact_events[0].raw), 10.0 * float(ThreatDirector.enemy_damage_mul)), "suppressed boss contributes no extra swarm weight while the ambient enemy still deals contact")
	var records: Dictionary = _player.get("_contact_sources")
	_check(records.size() == 2 and int(records[tank.get_instance_id()].overlap_count) == 2, "rush suppression preserves balanced Body/Area ledger entries")
	_player.call("_unregister_contact_source", tank)
	_player.call("_unregister_contact_source", tank)
	_player.call("_unregister_contact_source", ambient)
	_check((_player.get("_contact_sources") as Dictionary).is_empty(), "ordinary exits still balance every suppressed and ambient contact")
	await _clear()


func _test_coarse_rush_respects_committed_length() -> void:
	for step_seconds in [1.0 / 60.0, 0.1]:
		_fixture()
		var tank := _tank()
		var brain := tank.get_node("BossBrain")
		var start := tank.global_position
		var promised_length := tank.spec.charge_duration * tank.spec.charge_speed
		brain.call("_begin_teaching_rush")
		brain.call("_tick_cast", 0.86)
		await get_tree().physics_frame
		for step in range(int(ceil(tank.spec.charge_duration / step_seconds))):
			tank.call("_run_simulation_step", step_seconds)
			brain.call("_tick_teaching", step_seconds)
		var traveled := tank.global_position.distance_to(start)
		_check(traveled <= promised_length + 0.05 and traveled >= promised_length - 0.05,
			"committed rush at %.3fs physics steps travels exactly its %.1fpx warned lane (actual %.2fpx)" % [step_seconds, promised_length, traveled])
		await _clear()


func _test_cleanup_cannot_add_stale_contact_weight() -> void:
	_fixture()
	var tank := _tank()
	var brain := tank.get_node("BossBrain")
	brain.call("_do_slam")
	_player.set("_damage_loop_running", true)
	_player.call("_register_contact_source", tank)
	var ambient := CharacterBody2D.new()
	ambient.add_to_group(&"enemies")
	_world.add_child(ambient)
	_player.call("_register_contact_source", ambient)
	# The actual cancellation path restores boss metadata before deferred
	# deletion. A contact timer waking in this interval must count only ambient.
	(tank.get_meta(SCOPE.SCOPE_META) as WeakRef).get_ref().call("cancel")
	tank.despawn(&"boss_cleanup")
	_check(tank.is_queued_for_deletion() and not bool(tank.get_meta(&"boss_contact_suppressed", false)), "cleanup fixture reaches real queued-deletion contact window after source cancellation")
	_player.set("_damage_loop_running", false)
	_events.clear()
	_player.call("_start_contact_loop")
	var contacts := _events.filter(func(event: Dictionary) -> bool: return event.kind == &"contact_swarm")
	_check(contacts.size() == 1 and is_equal_approx(float(contacts[0].raw), 10.0 * float(ThreatDirector.enemy_damage_mul)), "queued boss cleanup contributes no stale swarm weight while ambient contact remains active")
	_player.call("_unregister_contact_source", ambient)
	await _clear()


func _test_finite_warned_call() -> void:
	_fixture()
	var tank := _tank()
	tank.hp = tank.max_hp * 0.49
	var brain := tank.get_node("BossBrain")
	brain.set("_slam_cd", 100.0)
	brain.set("_shock_cd", 100.0)
	brain.set("_summon_cd", 0.0)
	brain.call("_summon_blockers")
	_check(_runners().is_empty(), "Runner reinforcements are warned rather than arriving instantly")
	var arrival_script := load(ARRIVAL_PATH) as Script if ResourceLoader.exists(ARRIVAL_PATH) else null
	_check(arrival_script != null and _markers(arrival_script).size() == 3, "one call advertises its three finite arrival positions with raster cues")
	brain.call("_tick_cast", 0.99)
	_check(_runners().is_empty(), "Runner call preserves its entire one-second arrival tell")
	brain.call("_tick_cast", 0.02)
	var runners := _runners()
	_check(runners.size() == 3, "one completed below-half-health call releases exactly three Runners")
	for runner in runners:
		runner.set_physics_process(false)
		runner.set_process(false)
	brain.call("_summon_blockers")
	brain.call("_tick_cast", 20.0)
	_check(_runners().size() <= 3, "repeated low-health call callbacks cannot replenish the finite wave")
	var before_kills := _kills
	brain.call("_tick_teaching", 15.1)
	_check(_runners().is_empty() and _kills == before_kills, "unclaimed Runners expire after15 gameplay seconds without kill rewards")
	_check(int(EnemyIndex.get_debug_counters().get("reserved", 0)) == 0, "finite arrival and expiry leave no population reservations")
	await _clear()


func _on_damage(player: Node, raw: float, _adjusted: float, _applied: float, source: Node, kind: StringName, _outcome: StringName) -> void:
	if player == _player:
		_events.append({"raw": raw, "source": source, "kind": kind})


func _test_call_interruption_and_blocked_arrival() -> void:
	_fixture()
	var tank := _tank()
	tank.hp = tank.max_hp * 0.49
	var brain := tank.get_node("BossBrain")
	brain.call("_summon_blockers")
	tank.call("_apply_enemy_world_stun", 0.01)
	tank.stun_time = 0.0
	brain.call("_tick_cast", 2.0)
	_check(_runners().is_empty(), "stunning a pending reinforcement call releases no stale Runners")
	brain.call("_summon_blockers")
	brain.call("_tick_cast", 2.0)
	_check(_runners().is_empty(), "the one consumed call cannot be replenished after an interruption")
	_check(int(EnemyIndex.get_debug_counters().get("reserved", 0)) == 0, "interrupted arrival warnings leak no population reservations")
	await _clear()
	_fixture()
	tank = _tank()
	tank.hp = tank.max_hp * 0.49
	brain = tank.get_node("BossBrain")
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 650.0
	collider.shape = shape
	wall.add_child(collider)
	wall.position = _world.to_local(tank.global_position)
	_world.add_child(wall)
	await get_tree().physics_frame
	brain.call("_summon_blockers")
	brain.call("_tick_cast", 1.1)
	_check(_runners().is_empty(), "full-body blocked arrival locations are skipped instead of spawning Runners inside a wall")
	_check(int(EnemyIndex.get_debug_counters().get("reserved", 0)) == 0, "failed body validation leaves no population reservations")
	await _clear()


func _test_pause_keeps_recovery() -> void:
	_fixture()
	var tank := _tank()
	var brain := tank.get_node("BossBrain")
	brain.call("_do_slam")
	brain.call("_tick_cast", 1.31)
	get_tree().paused = true
	brain.set_process(true)
	brain.set_physics_process(true)
	await get_tree().create_timer(0.2, true).timeout
	brain.set_process(false)
	brain.set_physics_process(false)
	_check(tank.get_meta(&"boss_teaching_state", &"") == &"recovery", "actual scene pause cannot consume the post-slam melee opening")
	get_tree().paused = false
	brain.call("_tick_cast", 0.88)
	_check(tank.get_meta(&"boss_teaching_state", &"") == &"recovery", "resuming retains the unspent recovery duration")
	brain.call("_tick_cast", 0.03)
	_check(tank.get_meta(&"boss_teaching_state", &"") == &"idle", "remaining recovery completes once after resuming")
	await _clear()


func _test_stun_cannot_shorten_recovery() -> void:
	_fixture()
	var tank := _tank()
	var brain := tank.get_node("BossBrain")
	brain.call("_do_slam")
	brain.call("_tick_cast", 1.31)
	tank.call("_apply_enemy_world_stun", 0.01)
	tank.stun_time = 0.0
	_check(tank.get_meta(&"boss_teaching_state", &"") == &"recovery" and bool(tank.get_meta(&"boss_cast_locked", false)), "a brief stun cannot remove an already earned post-impact melee opening")
	(tank.get_meta(SCOPE.SCOPE_META) as WeakRef).get_ref().call("cancel")
	_check(tank.get_meta(&"boss_teaching_state", &"") == &"idle" and not bool(tank.get_meta(&"boss_cast_locked", false)), "full source cancellation still clears recovery while its owner remains alive")
	await _clear()


func _test_render_time_cannot_spend_physics_tells() -> void:
	_fixture()
	var tank := _tank()
	var brain := tank.get_node("BossBrain")
	brain.call("_do_slam")
	var warnings := _markers(WARNING)
	var windup = brain.get("_windup")
	# A slow render frame can contain much less accepted physics time. Only
	# actual simulation ticks may spend the player's walking reaction window:
	# with its render callback allowed and physics held, a whole tell's worth
	# of real frames must spend nothing.
	brain.set_process(true)
	await get_tree().create_timer(brain.slam_windup + 0.2).timeout
	brain.set_process(false)
	_check(_circles().is_empty() and tank.get_meta(&"boss_teaching_state", &"") == &"slam" and is_zero_approx(float(brain.get("_cast_elapsed"))), "render time alone cannot consume the physics-clock slam anticipation")
	if not warnings.is_empty():
		warnings[0].call("_process", 5.0)
		_check(not warnings[0].is_queued_for_deletion(), "the persistent S5 footprint cannot expire ahead of its controller's physics clock")
	if is_instance_valid(windup):
		windup.call("_process", 5.0)
		_check(not windup.is_queued_for_deletion() and windup.visible, "the casting sprite cannot disappear while accepted physics time still owes its tell")
	await _clear()
	_fixture()
	tank = _tank()
	tank.hp = tank.max_hp * 0.49
	brain = tank.get_node("BossBrain")
	brain.call("_summon_blockers")
	brain.call("_tick_cast", 1.01)
	var lives_before: Array = (brain.get("_runner_lives") as Array).map(func(entry: Dictionary) -> float: return float(entry["remaining"]))
	brain.set_process(true)
	await get_tree().create_timer(0.3).timeout
	brain.set_process(false)
	var lives_after: Array = (brain.get("_runner_lives") as Array).map(func(entry: Dictionary) -> float: return float(entry["remaining"]))
	_check(_runners().size() == 3 and lives_before.size() == 3 and lives_after == lives_before, "render time alone cannot age the finite Runner wave ahead of gameplay time")
	await _clear()


func _on_kill(_source: Node, _enemy: Node, _where: Vector2) -> void:
	_kills += 1


func _run() -> void:
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://boss_bulldozer_teaching_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	Global.debug_disable_autosave = true
	Global.debug_player_god_mode = false
	Global.run_luck = 0.0
	RunEvents.player_damage_resolved.connect(_on_damage)
	RunEvents.enemy_killed.connect(_on_kill)
	await _test_planted_slam()
	await _test_fault_line()
	await _test_slow_player_slam()
	await _test_rush_cosmetic_pressure()
	await _test_rush_commitment_and_contact()
	await _test_coarse_rush_respects_committed_length()
	await _test_contact_ledger_keeps_ambient()
	await _test_cleanup_cannot_add_stale_contact_weight()
	await _test_finite_warned_call()
	await _test_call_interruption_and_blocked_arrival()
	await _test_pause_keeps_recovery()
	await _test_stun_cannot_shorten_recovery()
	await _test_render_time_cannot_spend_physics_tells()
	RunEvents.player_damage_resolved.disconnect(_on_damage)
	RunEvents.enemy_killed.disconnect(_on_kill)
	print("BossBulldozerTeachingTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
