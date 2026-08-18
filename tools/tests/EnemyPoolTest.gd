extends Node

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


func _run() -> void:
	var scene := load("res://core/actors/enemy/enemy.tscn") as PackedScene
	var pool := get_node_or_null("/root/PoolManager")
	_check(scene != null, "ordinary enemy scene loads")
	_check(pool != null and pool.has_method("set_limit_for_scene"), "pool exposes per-scene limits")
	_check(pool != null and pool.has_method("pool_size_for_scene"), "pool exposes retained size")
	_check(pool != null and pool.has_method("get_debug_counters"), "pool exposes reuse diagnostics")
	if scene == null or pool == null or not pool.has_method("set_limit_for_scene"):
		_finish()
		return

	pool.call("set_limit_for_scene", scene, 2)
	var enemy := pool.call("obtain", scene, self) as EnemyActor
	_check(enemy != null and enemy.has_method("despawn"), "enemy exposes pooled despawn contract")
	_check(enemy != null and enemy.has_method("can_pool_as_ambient"), "enemy exposes fail-closed pooling eligibility")
	if enemy == null or not enemy.has_method("despawn"):
		_finish()
		return
	var original_id := enemy.get_instance_id()
	enemy.hp = 1.0
	enemy.dead = true
	enemy.is_elite = true
	enemy.velocity = Vector2(300.0, 40.0)
	enemy.stun_time = 4.0
	enemy.knockback_vel = Vector2.ONE * 99.0
	enemy.set_meta("culled", true)
	enemy.set_meta("cull_reason", &"test")
	enemy.set_scheduler_tier(2)
	var burn := BurnDot.new()
	burn.name = "BurnDot"
	enemy.add_child(burn)
	# Eligibility is evaluated before mutations in real gameplay; this test removes
	# elite state so the same ordinary instance exercises the reset path.
	enemy.is_elite = false
	enemy.dead = false
	enemy.call("despawn", &"test")
	var reused := pool.call("obtain", scene, self) as EnemyActor
	_check(reused != null and reused.get_instance_id() == original_id, "eligible ordinary enemy instance is reused")
	if reused != null:
		_check(reused.hp == reused.max_hp and not reused.dead, "pooled enemy restores health and life state")
		_check(reused.velocity == Vector2.ZERO and reused.knockback_vel == Vector2.ZERO and reused.stun_time == 0.0, "pooled enemy clears motion and control state")
		_check(not reused.has_meta("culled") and not reused.has_meta("cull_reason"), "pooled enemy clears retirement metadata")
		_check(reused.get_node_or_null("BurnDot") == null, "pooled enemy removes dynamic damage-over-time nodes")
		_check(reused.simulation_tier() == 0 and reused.visible, "pooled enemy returns active and fully simulated")
		var indexed_matches := 0
		for candidate in (get_node("/root/EnemyIndex").call("get_all") as Array):
			if candidate == reused:
				indexed_matches += 1
		_check(indexed_matches == 1, "reused enemy is registered exactly once")

	var held: Array[EnemyActor] = []
	if reused != null:
		held.append(reused)
	for _index in range(2):
		held.append(pool.call("obtain", scene, self) as EnemyActor)
	for candidate in held:
		candidate.call("despawn", &"capacity")
	await get_tree().process_frame
	_check(int(pool.call("pool_size_for_scene", scene)) == 2, "enemy pool retains no more than its configured limit")

	# A retained node can still be freed by a late cleanup callback after recycle.
	# The pool must discard that stale Object Variant instead of casting it.
	var stale := pool.call("obtain", scene, self) as EnemyActor
	_check(stale != null, "stale-entry fixture obtains an enemy")
	if stale != null:
		stale.call("despawn", &"stale_fixture")
		stale.queue_free()
	await get_tree().process_frame
	var after_stale := pool.call("obtain", scene, self) as EnemyActor
	_check(after_stale != null and is_instance_valid(after_stale), "obtain skips an externally freed retained enemy")
	if after_stale != null:
		after_stale.call("despawn", &"stale_fixture_cleanup")

	# A Node already queued for deletion must never enter the retained pool.
	var queued := pool.call("obtain", scene, self) as EnemyActor
	_check(queued != null, "queued-deletion fixture obtains an enemy")
	if queued != null:
		var pool_size_before_queued_recycle := int(pool.call("pool_size_for_scene", scene))
		queued.queue_free()
		pool.call("recycle", queued)
		_check(
			int(pool.call("pool_size_for_scene", scene)) == pool_size_before_queued_recycle,
			"pool rejects an enemy already queued for deletion"
		)
	await get_tree().process_frame

	# Elites must recycle: at high threat most spawns are promoted, and excluding
	# them from the pool collapses reuse exactly when spawn pressure peaks.
	var elite := pool.call("obtain", scene, self) as EnemyActor
	var elite_spec := EnemySpec.new()
	elite_spec.ai = EnemySpec.AI.CHASE
	elite.spec = elite_spec
	var elite_base_slides := elite.max_slides
	elite.call("make_elite")
	_check(elite.is_elite and elite.max_slides == 8, "make_elite promotes the live actor")
	var elite_id := elite.get_instance_id()
	elite.dead = true
	elite.call("despawn", &"elite")
	await get_tree().process_frame
	_check(is_instance_id_valid(elite_id), "dead elite recycles into the ambient pool instead of freeing")
	var former_elite := pool.call("obtain", scene, self) as EnemyActor
	_check(former_elite != null and former_elite.get_instance_id() == elite_id, "recycled elite instance is reused")
	if former_elite != null:
		_check(not former_elite.is_elite, "reused elite clears elite status")
		_check(former_elite.max_slides == elite_base_slides, "reused elite restores ordinary solver slides")
		var former_sprite := former_elite.get_node_or_null("Sprite2D") as CanvasItem
		if former_sprite != null and former_elite.spec != null:
			_check(former_sprite.modulate == former_elite.spec.sprite_modulate, "reused elite restores base sprite tint")
		_check(not former_elite.dead and former_elite.hp == former_elite.max_hp, "reused elite is alive at full health")
		former_elite.call("despawn", &"cleanup")
		await get_tree().process_frame

	var special := pool.call("obtain", scene, self) as EnemyActor
	special.set_meta("special_spawn_kind", &"summon")
	var special_id := special.get_instance_id()
	special.call("despawn", &"special")
	await get_tree().process_frame
	_check(not is_instance_id_valid(special_id), "special actor fails closed to freeing instead of pooling")

	var counters := pool.call("get_debug_counters") as Dictionary
	_check(int(counters.get("reuse_hits", 0)) > 0, "pool records reuse hits")
	_check(int(counters.get("releases", 0)) >= 3, "pool records retained releases")
	_finish()


func _finish() -> void:
	print("EnemyPoolTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
