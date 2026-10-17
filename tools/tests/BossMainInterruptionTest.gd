extends Node

# Boss overhaul acceptance check 2 for the main (S10) kits: death, stun,
# disengage and pause cannot release a stale cast at anticipation, release or
# recovery. Real bosses, real hazards and the production player; the fixture
# only stops autonomous selection and steps the controllers' physics clock.
const TANK := preload("res://scenes/world/bosses/BossBulldozer.tscn")
const MAGE := preload("res://scenes/world/bosses/BossArcanist.tscn")
const PLAYER := preload("res://core/actors/player/player.tscn")
const WARNING := preload("res://scenes/world/bosses/BossGroundWarning.gd")
const SECTOR_WARNING := preload("res://scenes/world/bosses/BossSectorWarning.gd")
const TANK_BRAIN := preload("res://scenes/world/bosses/BossBulldozerBrain.gd")
const MAGE_BRAIN := preload("res://scenes/world/bosses/BossArcanistBrain.gd")
const PARKED_CLOCKS: Array[String] = ["_slam_cd", "_shock_cd", "_rush_cd", "_cleave_cd", "_breach_cd", "_fan_cd", "_mines_cd", "_blink_cd", "_split_cd", "_sweep_cd", "_convergence_cd"]
var _passes := 0
var _failures := 0
var _world: Node2D
var _player: CharacterBody2D
var _events: Array[Dictionary] = []
## What the world gains, tagged on entry, so a release that cancels and
## frees itself at once is still caught.
var _spawned: Array[StringName] = []


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
	_events.clear()
	_spawned.clear()
	_world.child_entered_tree.connect(func(child: Node) -> void: _spawned.append(_tag(child)))


func _boss(scene: PackedScene, at: Vector2 = Vector2(1500, 1100)) -> EnemyActor:
	var actor := scene.instantiate() as EnemyActor
	actor.position = _world.to_local(at)
	_world.add_child(actor)
	actor.add_to_group(&"boss")
	actor.add_to_group(&"boss_like")
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.player = _player
	var brain := actor.get_node("BossBrain")
	brain.set_process(false)
	brain.set_physics_process(false)
	if brain.has_method("_sync_tier"):
		brain.call("_sync_tier")
	if brain.has_method("_ensure_teaching"):
		brain.call("_ensure_teaching")
	for property in PARKED_CLOCKS:
		if property in brain:
			brain.set(property, 100.0)
	return actor


func _clear() -> void:
	get_tree().paused = false
	get_tree().current_scene = self
	_world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _frames(count: int = 2) -> void:
	for _frame in range(count):
		await get_tree().process_frame


func _children(predicate: Callable) -> Array:
	return _world.get_children().filter(func(child: Node) -> bool: return not child.is_queued_for_deletion() and predicate.call(child))


func _with_script(script: Script) -> Array:
	return _children(func(child: Node) -> bool: return child.get_script() == script)


func _circles(boss: Node) -> Array:
	return _children(func(child: Node) -> bool: return child is DamageCircle and child.source == boss)


func _strikes() -> Array:
	return _children(func(child: Node) -> bool: return child is BossSectorStrike)


func _bolts(boss: Node) -> Array:
	return _children(func(child: Node) -> bool: return child is EnemyProjectile and child.shooter == boss)


func _beams() -> Array:
	return _children(func(child: Node) -> bool: return child is BossBeamSweep)


func _pylons() -> Array:
	return _children(func(child: Node) -> bool: return child is BossPylon and not child.dead)


func _tag(child: Node) -> StringName:
	if child is DamageCircle:
		return &"circle"
	if child is BossSectorStrike:
		return &"strike"
	if child is EnemyProjectile:
		return &"bolt"
	if child is BossBeamSweep:
		return &"beam"
	return &""


func _released_since(mark: int, tag: StringName) -> int:
	return _spawned.slice(mark).count(tag)


func _state(boss: EnemyActor) -> StringName:
	return boss.get_meta(&"boss_teaching_state", &"")


func _boss_hits(boss: Node) -> int:
	return _events.filter(func(event: Dictionary) -> bool: return event["source"] == boss or (event["source"] is EnemyProjectile and event["source"].shooter == boss)).size()


func _on_damage(player: Node, raw: float, _adjusted: float, _applied: float, source: Node, kind: StringName, _outcome: StringName) -> void:
	if player == _player:
		_events.append({"raw": raw, "source": source, "kind": kind})


## Stun through the actor's real seam; the boss's scope sees it on its frame.
func _stun(boss: EnemyActor, seconds: float) -> void:
	boss.call("_apply_enemy_world_stun", seconds)
	await _frames(1)


func _test_cleave_death() -> void:
	_fixture()
	var tank := _boss(TANK)
	var brain := tank.get_node("BossBrain")
	brain.set("_boss_phase", 1)
	_player.global_position = tank.global_position + Vector2(120, 0)
	_check(bool(brain.call("_try_main_attack", &"cleave")), "cleave fixture commits")
	brain.call("_physics_process", 0.5)
	var mark := _spawned.size()
	tank.dead = true
	await _frames()
	brain.call("_physics_process", 1.0)
	await _frames()
	_check(_released_since(mark, &"strike") == 0 and _boss_hits(tank) == 0, "death during the cleave's anticipation releases no strike")
	_check(_with_script(SECTOR_WARNING).is_empty(), "and its sector warning leaves with it")
	await _clear()


func _test_cleave_stun_and_pause() -> void:
	_fixture()
	var tank := _boss(TANK)
	var brain := tank.get_node("BossBrain")
	brain.set("_boss_phase", 1)
	_player.global_position = tank.global_position + Vector2(120, 0)
	brain.call("_try_main_attack", &"cleave")
	brain.call("_physics_process", 0.5)
	var mark := _spawned.size()
	await _stun(tank, 0.3)
	_check(_state(tank) == &"idle" and _with_script(SECTOR_WARNING).is_empty(), "a stun interrupts the cleave and clears its warning")
	tank.stun_time = 0.0
	brain.call("_physics_process", 1.0)
	await _frames()
	_check(_released_since(mark, &"strike") == 0, "an expired stun cannot revive the interrupted cleave")
	await _clear()

	_fixture()
	tank = _boss(TANK)
	brain = tank.get_node("BossBrain")
	brain.set("_boss_phase", 1)
	_player.global_position = tank.global_position + Vector2(120, 0)
	brain.call("_try_main_attack", &"cleave")
	get_tree().paused = true
	brain.call("_physics_process", 2.0)
	_check(_strikes().is_empty() and _state(tank) == &"cleave", "a paused tree spends none of the cleave's tell")
	get_tree().paused = false
	brain.call("_physics_process", TANK_BRAIN.CLEAVE_TELL - 0.01)
	_check(_strikes().is_empty(), "resuming keeps the whole remaining tell")
	brain.call("_physics_process", 0.02)
	_check(_strikes().size() == 1 and _state(tank) == &"recovery", "then the strike releases once, into recovery")
	await _stun(tank, 0.05)
	_check(_state(tank) == &"recovery", "a brief stun cannot erase the earned recovery")
	await _clear()


func _test_breach() -> void:
	_fixture()
	var tank := _boss(TANK)
	var brain := tank.get_node("BossBrain")
	brain.set("_boss_phase", 2)
	_player.global_position = tank.global_position + Vector2(150, 0)
	_check(bool(brain.call("_try_main_attack", &"breach")), "breach fixture commits")
	brain.call("_physics_process", 0.4)
	var mark := _spawned.size()
	tank.set_meta(&"boss_returning", true)
	await _frames()
	brain.call("_physics_process", 3.0)
	await _frames()
	_check(tank._charge._time_left <= 0.0 and _released_since(mark, &"circle") == 0, "disengaging during the breach tell releases neither rush nor impact")
	_check(_with_script(WARNING).is_empty(), "and the announced impact is withdrawn")
	await _clear()

	_fixture()
	tank = _boss(TANK)
	brain = tank.get_node("BossBrain")
	brain.set("_boss_phase", 2)
	var origin := tank.global_position
	_player.global_position = origin + Vector2(150, 0)
	brain.call("_try_main_attack", &"breach")
	_player.global_position = origin + Vector2(150, 300)
	brain.call("_tick_cast", TANK_BRAIN.BREACH_RUSH_TELL + 0.01)
	await get_tree().physics_frame
	for _step in range(30):
		if _state(tank) == &"breach_beat":
			break
		tank.call("_run_simulation_step", 1.0 / 60.0)
		brain.call("_physics_process", 1.0 / 60.0)
		await get_tree().physics_frame
	_check(_state(tank) == &"breach_beat", "fixture: the rush arrived and the beat began")
	mark = _spawned.size()
	tank.dead = true
	await _frames()
	brain.call("_physics_process", 1.0)
	await _frames()
	_check(_released_since(mark, &"circle") == 0 and _with_script(WARNING).is_empty(), "death during the beat releases no impact and clears its warning")
	await _clear()


func _test_fault_followup_stun() -> void:
	_fixture()
	var tank := _boss(TANK)
	var brain := tank.get_node("BossBrain")
	brain.set("_boss_phase", 2)
	_player.global_position = tank.global_position + Vector2(300, 0)
	brain.set("_followup_dir", Vector2.RIGHT.rotated(TANK_BRAIN.FOLLOWUP_TURN))
	brain.call("_do_shockwave")
	_player.global_position = tank.global_position + Vector2(-400, 0)
	brain.call("_tick_cast", 2.1)
	_check(_circles(tank).size() == 3, "fixture: the first line has released")
	var mark := _spawned.size()
	await _stun(tank, 0.3)
	_check(_state(tank) == &"idle", "the stun interrupts the sequence between its lines")
	tank.stun_time = 0.0
	brain.call("_physics_process", 2.0)
	await _frames()
	_check(_released_since(mark, &"circle") == 0 and _with_script(WARNING).is_empty(), "the follow-up line's three nodes never release and their warnings are cleared")
	await _clear()


func _test_phase_beat_holds() -> void:
	_fixture()
	var tank := _boss(TANK)
	var brain := tank.get_node("BossBrain")
	tank.hp = tank.max_hp * 0.6
	brain.call("_tick_main_selection", 1.0 / 60.0)
	_check(_state(tank) == &"phase_shift", "fixture: the Bulldozer's phase beat began")
	await _stun(tank, 0.3)
	_check(int(brain.call("main_phase")) == 1 and bool(brain.get("_call_pending")), "an interrupted phase beat keeps its phase and its owed Runner call")
	await _clear()

	_fixture()
	var mage := _boss(MAGE)
	brain = mage.get_node("BossBrain")
	mage.hp = mage.max_hp * 0.6
	_player.global_position = mage.global_position + Vector2(300, 0)
	brain.call("_tick_teaching", 1.0 / 60.0)
	_check(_state(mage) == &"phase_shift", "fixture: the Arcanist's phase beat began")
	await _stun(mage, 0.3)
	mage.stun_time = 0.0
	_check(int(brain.call("main_phase")) == 1 and bool(brain.get("_pylons_pending")), "an interrupted phase beat keeps its phase and its owed Pylon Pair")
	brain.call("_tick_teaching", 1.0 / 60.0)
	_check(_pylons().size() == 2, "the pair still arrives once the boss is free")
	await _clear()


func _test_split_death_and_disengage() -> void:
	_fixture()
	var mage := _boss(MAGE)
	var brain := mage.get_node("BossBrain")
	brain.set("_boss_phase", 1)
	_player.global_position = mage.global_position + Vector2(300, 0)
	_check(bool(brain.call("_try_main_pattern", &"split")), "split fixture commits")
	brain.call("_tick_teaching", 0.5)
	var mark := _spawned.size()
	mage.dead = true
	await _frames()
	brain.call("_tick_teaching", 1.0)
	await _frames()
	_check(_released_since(mark, &"bolt") == 0 and _children(func(child: Node) -> bool: return child.name == "SplitFanRayWarnings").is_empty(), "death during the Split Fan's tell releases no bolt and clears its lanes")
	await _clear()

	_fixture()
	mage = _boss(MAGE)
	brain = mage.get_node("BossBrain")
	brain.set("_boss_phase", 1)
	_player.global_position = mage.global_position + Vector2(300, 0)
	brain.call("_try_main_pattern", &"split")
	brain.call("_tick_teaching", 0.5)
	mark = _spawned.size()
	mage.set_meta(&"boss_returning", true)
	await _frames()
	brain.call("_tick_teaching", 1.0)
	await _frames()
	_check(_released_since(mark, &"bolt") == 0 and _state(mage) == &"idle", "disengaging during the tell releases no bolt")
	await _clear()


func _test_sweep_interruptions() -> void:
	_fixture()
	var mage := _boss(MAGE)
	var brain := mage.get_node("BossBrain")
	brain.set("_boss_phase", 1)
	_player.global_position = mage.global_position + Vector2(300, 0)
	brain.call("_spawn_main_pylons")
	var pylon := _pylons()[0] as BossPylon
	_check(bool(brain.call("_try_main_pattern", &"sweep")), "sweep fixture commits")
	_check(bool(pylon.call("_holds_fire")), "fixture: the sweep holds the pair's fire")
	var beam := _beams()[0] as BossBeamSweep
	beam.call("_advance", 0.5)
	brain.call("_tick_teaching", 0.5)
	await _stun(mage, 0.3)
	await _frames()
	_check(not is_instance_valid(beam) or beam.is_queued_for_deletion(), "a stun during the telegraph cancels the channel")
	_check(_beams().is_empty() and _state(mage) == &"idle", "no beam survives the interrupted sweep")
	_check(not bool(pylon.call("_holds_fire")), "and the cancelled pattern releases the pair at once")
	await _clear()

	_fixture()
	mage = _boss(MAGE)
	brain = mage.get_node("BossBrain")
	brain.set("_boss_phase", 1)
	_player.global_position = mage.global_position + Vector2(300, 0)
	brain.call("_try_main_pattern", &"sweep")
	beam = _beams()[0] as BossBeamSweep
	beam.call("_advance", MAGE_BRAIN.SWEEP_TELL + 0.2)
	_check(int(beam.get("_phase")) == 1, "fixture: the beam is sweeping")
	mage.dead = true
	var hits_before := _boss_hits(mage)
	beam.call("_advance", 0.25)
	await _frames()
	_check(not is_instance_valid(beam) or beam.is_queued_for_deletion(), "the caster's death ends an active sweep at once")
	_check(_boss_hits(mage) == hits_before, "and the dying channel deals nothing more")
	await _clear()


func _test_convergence_stun_after_fan() -> void:
	_fixture()
	var mage := _boss(MAGE)
	var brain := mage.get_node("BossBrain")
	brain.set("_boss_phase", 2)
	_player.global_position = mage.global_position + Vector2(300, 0)
	_check(bool(brain.call("_try_main_pattern", &"convergence")), "convergence fixture commits")
	brain.call("_tick_teaching", MAGE_BRAIN.SPLIT_TELL + 0.01)
	var released := _bolts(mage).size()
	_check(released > 0 and _state(mage) == &"convergence_beam", "fixture: the split resolved and the sweep is pending")
	var mark := _spawned.size()
	await _stun(mage, 0.05)
	await _frames()
	brain.call("_tick_teaching", 3.0)
	_check(_beams().is_empty() and _released_since(mark, &"beam") == 0, "a stun between the two beats cancels the pending sweep")
	_check(_bolts(mage).size() == released, "while the bolts already released fly on (a brief stun is not death)")
	_check(_state(mage) == &"idle", "the sequence does not resume after the stun")
	await _clear()


func _test_pylons_leave_with_their_boss() -> void:
	_fixture()
	var mage := _boss(MAGE)
	var brain := mage.get_node("BossBrain")
	_player.global_position = mage.global_position + Vector2(300, 0)
	brain.set("_boss_phase", 1)
	brain.call("_spawn_main_pylons")
	var pylons := _pylons()
	_check(pylons.size() == 2, "fixture: a pair stands")
	mage.dead = true
	await _frames(3)
	_check(_pylons().is_empty(), "the pair leaves with its boss, without a kill credit")
	await _clear()


func _run() -> void:
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://boss_main_interruption_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	Global.debug_disable_autosave = true
	var previous_seed := Global.attempt_world_seed
	Global.attempt_world_seed = 7341
	RunEvents.player_damage_resolved.connect(_on_damage)
	await _test_cleave_death()
	await _test_cleave_stun_and_pause()
	await _test_breach()
	await _test_fault_followup_stun()
	await _test_phase_beat_holds()
	await _test_split_death_and_disengage()
	await _test_sweep_interruptions()
	await _test_convergence_stun_after_fan()
	await _test_pylons_leave_with_their_boss()
	RunEvents.player_damage_resolved.disconnect(_on_damage)
	Global.attempt_world_seed = previous_seed
	print("BossMainInterruptionTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
