extends Node

const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

class MirrorActor:
	extends Node2D
	var health := 20.0
	var deaths := 0

	func _apply_enemy_world_health(current_health: float, _maximum_health: float) -> void:
		health = current_health

	func _apply_enemy_world_damage_feedback(_damage: float, _source: Node, _payload: Variant) -> void:
		pass

	func _apply_enemy_world_death(_context: RefCounted) -> void:
		deaths += 1

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _spawn_record(id: StringName, position: Vector2, health: float = 20.0) -> int:
	return EnemyWorld.create_enemy(SpawnState.new(id, "res://%s.tscn" % String(id), position, health, 0.0, 5.0, 0))


func _profile(damage: float = 10.0, pierce: int = 0) -> HitProfileAdapter:
	var profile := HitProfileAdapter.new()
	profile.speed = 100.0
	profile.max_range = 200.0
	profile.damage = damage
	profile.collision_radius = 1.0
	profile.pierce = pierce
	return profile


func _run() -> void:
	var manager_script := load("res://core/combat/projectile/ProjectileSimulationManager.gd") as Script
	var manager := manager_script.new() as Node2D
	add_child(manager)
	manager.set_physics_process(false)
	manager.call("_sync_scene_refs")
	var source := Node.new()
	add_child(source)

	var data_only := _spawn_record(&"data_only", Vector2(50.0, 0.0))
	var status_profile := _profile()
	status_profile.knockback = 4.0
	status_profile.set_meta("burn_stacks", 2)
	status_profile.set_meta("burn_duration", 2.0)
	status_profile.set_meta("burn_tick", 0.5)
	status_profile.set_meta("burn_tick_mult", 0.1)
	_check(manager.call("spawn_player", Vector2.ZERO, Vector2.RIGHT, status_profile, source), "managed projectile spawns for data-only target")
	manager.call("_simulate_one", 0, 0.60)
	manager.call("_flush_hit_ledgers")
	_check(EnemyWorld.get_health(data_only) == 10.0, "managed projectile damages data-only record")
	_check(EnemyWorld.get_knockback_velocity(data_only) == Vector2(4.0, 0.0), "managed projectile applies knockback to data-only record")
	_check(EnemyStatus.has_status(data_only, &"burn"), "managed projectile schedules burn on data-only record")
	_check(int(manager.call("active_count")) == 0, "non-piercing projectile retires after data-only hit")

	EnemyWorld.remove_enemy(data_only, &"test_reset")
	var materialized := _spawn_record(&"materialized", Vector2(30.0, 0.0))
	var actor := MirrorActor.new()
	actor.position = Vector2(30.0, 0.0)
	add_child(actor)
	EnemyWorld.bind_actor(materialized, actor)
	var second := _spawn_record(&"second", Vector2(70.0, 0.0))
	_check(manager.call("spawn_player", Vector2.ZERO, Vector2.RIGHT, _profile(10.0, 1), source), "piercing projectile spawns for mixed representations")
	manager.call("_simulate_one", 0, 0.35)
	manager.call("_flush_hit_ledgers")
	_check(EnemyWorld.get_health(materialized) == 10.0 and actor.health == 10.0, "first piercing hit updates materialized record and mirror")
	_check(int(manager.call("active_count")) == 1, "piercing projectile survives first handle hit")
	manager.call("_simulate_one", 0, 0.40)
	manager.call("_flush_hit_ledgers")
	_check(EnemyWorld.get_health(second) == 10.0, "piercing projectile next damages data-only handle")
	_check(int(manager.call("active_count")) == 0, "piercing projectile retires after its final hit")

	EnemyWorld.remove_enemy(materialized, &"test_reset")
	EnemyWorld.remove_enemy(second, &"test_reset")
	var stale_target := _spawn_record(&"stale_target", Vector2(30.0, 0.0))
	manager.call("spawn_player", Vector2.ZERO, Vector2.RIGHT, _profile(), source)
	manager.call("_simulate_one", 0, 0.35)
	_check((manager.get("_pending_ledgers") as Dictionary).has(stale_target), "pending ledger is keyed by stable handle")
	EnemyWorld.remove_enemy(stale_target, &"before_flush")
	var replacement := _spawn_record(&"replacement", Vector2(30.0, 0.0))
	manager.call("_flush_hit_ledgers")
	_check(EnemyWorld.get_health(replacement) == 20.0, "stale queued hit cannot damage slot replacement")

	manager.call("_clear_all")
	EnemyWorld.remove_enemy(replacement, &"test_cleanup")

	# A piercing bullet whose single step crosses two enemies must hit both:
	# the sweep continues from the first contact instead of skipping the rest
	# of the segment (at 60 fps a 1800 px/s bullet covers 30 px per step).
	var near := _spawn_record(&"near", Vector2(30.0, 0.0))
	var far := _spawn_record(&"far", Vector2(60.0, 0.0))
	manager.call("spawn_player", Vector2.ZERO, Vector2.RIGHT, _profile(10.0, 1), source)
	manager.call("_simulate_one", 0, 0.90)
	manager.call("_flush_hit_ledgers")
	_check(EnemyWorld.get_health(near) == 10.0, "pierce sweep damages the first enemy on the segment")
	_check(EnemyWorld.get_health(far) == 10.0, "pierce sweep also damages the second enemy crossed in the same step")
	_check(int(manager.call("active_count")) == 0, "pierce budget exhausted inside one step retires the bullet")
	manager.call("_clear_all")
	EnemyWorld.remove_enemy(near, &"test_cleanup")
	EnemyWorld.remove_enemy(far, &"test_cleanup")

	# Anchor Rite bullets carry pierce 12-14: a whole line of enemies crossed
	# in one step must all be hit, with no cap below the pierce budget.
	var line: Array[int] = []
	for i in range(10):
		line.append(_spawn_record(StringName("line_%d" % i), Vector2(20.0 + float(i) * 8.0, 0.0)))
	manager.call("spawn_player", Vector2.ZERO, Vector2.RIGHT, _profile(10.0, 12), source)
	manager.call("_simulate_one", 0, 1.2)
	manager.call("_flush_hit_ledgers")
	var line_hits := 0
	for handle in line:
		if EnemyWorld.get_health(handle) == 10.0:
			line_hits += 1
	_check(line_hits == 10, "a pierce-12 bullet hits all ten enemies crossed in one step (hit %d)" % line_hits)
	_check(int(manager.call("active_count")) == 1, "the bullet survives with pierce budget to spare")
	manager.call("_clear_all")
	for handle in line:
		EnemyWorld.remove_enemy(handle, &"test_cleanup")

	# Touching enemies (circles overlap): each is hit exactly once per step.
	# The sweep must not re-find an already-hit enemy whose circle still
	# contains the contact point (t = 0) and ping-pong between the pair.
	var touch_a := _spawn_record(&"touch_a", Vector2(30.0, 0.0))
	var touch_b := _spawn_record(&"touch_b", Vector2(33.0, 0.0))
	manager.call("spawn_player", Vector2.ZERO, Vector2.RIGHT, _profile(10.0, 3), source)
	manager.set("_hits_this_frame", 0)
	manager.call("_simulate_one", 0, 0.90)
	manager.call("_flush_hit_ledgers")
	_check(EnemyWorld.get_health(touch_a) == 10.0, "touching enemy A is hit exactly once (health %.1f)" % EnemyWorld.get_health(touch_a))
	_check(EnemyWorld.get_health(touch_b) == 10.0, "touching enemy B is hit exactly once (health %.1f)" % EnemyWorld.get_health(touch_b))
	_check(int(manager.call("active_count")) == 1, "two hits spend two pierce, the pierce-3 bullet survives")
	_check(int(manager.get("_hits_this_frame")) == 2, "exactly two hits are queued for the touching pair (got %d)" % int(manager.get("_hits_this_frame")))
	manager.call("_clear_all")
	EnemyWorld.remove_enemy(touch_a, &"test_cleanup")
	EnemyWorld.remove_enemy(touch_b, &"test_cleanup")

	# Bullets step every rendered frame (smooth at any refresh rate) but stay
	# within one physics tick of banked physics time: under the
	# max_physics_steps_per_frame cap the world clock dilates and bullets
	# dilate with it instead of outrunning their targets.
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	manager.call("spawn_player", Vector2.ZERO, Vector2.RIGHT, _profile(), source)
	manager.call("_process", 0.5)
	var credit_pos: Vector2 = (manager.get("_positions") as PackedVector2Array)[0]
	_check(
		absf(credit_pos.x - 100.0 * tick) < 0.01,
		"a render frame with no banked physics time advances at most one tick of credit (got %.3f px)" % credit_pos.x
	)
	manager.call("_process", 0.5)
	var starved_pos: Vector2 = (manager.get("_positions") as PackedVector2Array)[0]
	_check(starved_pos.is_equal_approx(credit_pos), "with the credit spent, bullets wait for physics (got %.3f px)" % starved_pos.x)
	manager.call("_physics_process", tick)
	manager.call("_process", 0.5)
	var one_tick_pos: Vector2 = (manager.get("_positions") as PackedVector2Array)[0]
	_check(
		absf(one_tick_pos.x - 100.0 * tick * 2.0) < 0.01,
		"each physics tick releases exactly one tick of bullet time (got %.3f px)" % one_tick_pos.x
	)
	manager.call("_physics_process", tick)
	manager.call("_physics_process", tick)
	manager.call("_process", tick * 0.5)
	var partial_pos: Vector2 = (manager.get("_positions") as PackedVector2Array)[0]
	_check(
		absf(partial_pos.x - 100.0 * tick * 2.5) < 0.01,
		"a short render frame consumes only its own delta from the bank (got %.3f px)" % partial_pos.x
	)
	manager.call("_clear_all")
	actor.queue_free()
	manager.queue_free()
	await get_tree().process_frame
	print("ProjectileHandleCombatTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
