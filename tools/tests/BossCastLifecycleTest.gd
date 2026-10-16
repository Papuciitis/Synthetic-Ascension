extends Node

const TANK = preload("res://scenes/world/bosses/BossBulldozer.tscn")
const MAGE = preload("res://scenes/world/bosses/BossArcanist.tscn")
var _passes := 0
var _failures := 0

class Target:
	extends Node2D
	var hits: Array[float] = []
	func take_damage(amount: float, _source: Node = null) -> void:
		hits.append(amount)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")

func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)

func _spawn(scene: PackedScene, pos: Vector2) -> EnemyActor:
	var actor := scene.instantiate() as EnemyActor
	actor.process_mode = Node.PROCESS_MODE_PAUSABLE
	actor.position = pos
	add_child(actor)
	actor.set_physics_process(false)
	actor.set_process(false)
	var brain := actor.get_node("BossBrain")
	brain.set_process(false)
	return actor

func _count_projectiles() -> int:
	return get_tree().get_nodes_in_group(&"enemy_projectile").size()

func _clear_members() -> void:
	for child in get_children():
		if child is EnemyActor or child is EnemyProjectile or child is DamageCircle or child is BossMine or child is BossBeamSweep:
			child.queue_free()

func _run() -> void:
	SaveManager.current_save = null
	SaveManager.save_dir = "user://boss_cast_lifecycle_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	Global.debug_disable_autosave = true
	var target := Target.new()
	target.position = Vector2(1700, 1100)
	target.add_to_group(&"player")
	var hurtbox := Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.add_to_group(&"player_hurtbox")
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	collider.shape = circle
	hurtbox.add_child(collider)
	target.add_child(hurtbox)
	add_child(target)
	var mage := _spawn(MAGE, Vector2(1500, 1100))
	var brain := mage.get_node("BossBrain")
	brain.set("fan_telegraph", 0.18)
	brain.call("_fan_shot")
	brain.set_process(true)
	await get_tree().create_timer(0.05, true).timeout
	get_tree().paused = true
	await get_tree().create_timer(0.20, true).timeout
	_check(_count_projectiles() == 0, "fan anticipation cannot release while paused")
	get_tree().paused = false
	await get_tree().create_timer(0.04, true).timeout
	_check(_count_projectiles() == 0, "resuming preserves the unspent anticipation instead of firing immediately")
	await get_tree().create_timer(0.18, true).timeout
	_check(_count_projectiles() == 9, "fan resumes remaining anticipation and releases once")
	_clear_members()
	await get_tree().process_frame

	mage = _spawn(MAGE, Vector2(1500, 1100))
	brain = mage.get_node("BossBrain")
	brain.set("fan_telegraph", 0.12)
	brain.call("_fan_shot")
	mage.set_meta(&"boss_returning", true)
	brain.set_process(true)
	await get_tree().create_timer(0.20, true).timeout
	_check(_count_projectiles() == 0, "returning cancels a pending fan instead of releasing stale bullets")
	_clear_members()
	await get_tree().process_frame

	mage = _spawn(MAGE, Vector2(1500, 1100))
	brain = mage.get_node("BossBrain")
	brain.set("fan_telegraph", 0.12)
	brain.call("_fan_shot")
	mage.call("_apply_enemy_world_stun", 0.01)
	mage.stun_time = 0.0
	brain.set_process(true)
	await get_tree().create_timer(0.20, true).timeout
	_check(_count_projectiles() == 0, "a brief expired stun cannot revive the interrupted fan")
	_clear_members()
	await get_tree().process_frame
	mage = _spawn(MAGE, Vector2(1500, 1100))
	brain = mage.get_node("BossBrain")
	brain.set("fan_telegraph", 0.12)
	brain.call("_fan_shot")
	var runner := preload("res://scenes/world/enemies/EnemyRunner.tscn").instantiate() as EnemyActor
	preload("res://scenes/world/bosses/BossAttackScope.gd").bind(runner, mage)
	runner.position = Vector2(1300, 1100)
	add_child(runner)
	runner.set_physics_process(false)
	runner.call("_apply_enemy_world_stun", 0.2)
	brain.set_process(true)
	await get_tree().create_timer(0.20, true).timeout
	_check(_count_projectiles() == 9, "stunning a summoned Runner cannot interrupt its owner's cast")
	_clear_members()
	await get_tree().process_frame

	mage = _spawn(MAGE, Vector2(1500, 1100))
	brain = mage.get_node("BossBrain")
	brain.set("fan_telegraph", 0.08)
	brain.call("_fan_shot")
	brain.set_process(true)
	await get_tree().create_timer(0.12, true).timeout
	_check(_count_projectiles() == 9, "released fan has nine live projectiles before cleanup")
	mage.call("_apply_enemy_world_stun", 0.01)
	mage.stun_time = 0.0
	_check(_count_projectiles() == 9, "a brief owner stun preserves autonomous projectiles already released")
	var unrelated := preload("res://core/combat/projectile/EnemyProjectile.tscn").instantiate() as EnemyProjectile
	unrelated.position = Vector2(3000, 1000)
	unrelated.setup(Vector2.RIGHT, 0.0, 1.0, 20.0)
	add_child(unrelated)
	mage.dead = true
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_count_projectiles() == 1 and is_instance_valid(unrelated), "boss death clears its released fan while preserving unrelated projectiles")
	_clear_members()
	await get_tree().process_frame
	mage = _spawn(MAGE, Vector2(1500, 1100))
	brain = mage.get_node("BossBrain")
	brain.call("_beam_sweep")
	var channel: BossBeamSweep
	for child in get_children():
		if child is BossBeamSweep:
			channel = child
	_check(channel != null, "beam channel fixture starts a real sweep")
	if channel != null:
		channel.call("_process", channel.telegraph_time + 0.01)
		mage.call("_apply_enemy_world_stun", 0.01)
		_check(channel.is_queued_for_deletion(), "stun interrupts the actively sustained beam channel")
	_clear_members()
	await get_tree().process_frame

	var tank := _spawn(TANK, Vector2(1500, 1100))
	target.position = Vector2(1500, 1100)
	brain = tank.get_node("BossBrain")
	brain.set("slam_windup", 0.12)
	brain.call("_do_slam")
	_check(bool(tank.get_meta(&"boss_cast_locked", false)), "slam commitment locks normal movement and charge starts")
	tank.call("_run_simulation_step", 0.016)
	_check(tank.global_position == Vector2(1500, 1100) and not tank._charge.step_override(0.01), "a real actor step cannot move or start a charge during slam anticipation")
	tank.position += Vector2(300, 0)
	var wrong_target := Target.new()
	wrong_target.position = tank.position
	var wrong_hurtbox := hurtbox.duplicate() as Area2D
	wrong_target.add_child(wrong_hurtbox)
	add_child(wrong_target)
	brain.set_process(true)
	await get_tree().create_timer(0.18, true).timeout
	_check(target.hits.size() == 1 and target.hits[0] == 18.0, "slam releases its unchanged18damage at the warned origin")
	_check(wrong_target.hits.is_empty(), "slam cannot relocate from its preview to the boss's new position")
	_clear_members()
	await get_tree().process_frame
	tank = _spawn(TANK, Vector2(1500, 1100))
	tank._charge._windup_left = 0.40
	tank._charge._time_left = 0.36
	tank.call("_apply_enemy_world_stun", 0.01)
	tank.stun_time = 0.0
	_check(not tank._charge.step_override(0.05), "an interrupted charge cannot resume later without a new warning")
	_clear_members()
	await get_tree().process_frame
	target.queue_free()
	wrong_target.queue_free()
	print("BossCastLifecycleTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
