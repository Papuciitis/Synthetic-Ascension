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

	# Warm-up must never create live gameplay population: warmed nodes sit
	# disabled in the pool, so registering them would fill the spawn cap with
	# invisible frozen ghosts that survive scene changes.
	var index := get_node("/root/EnemyIndex")
	var world := get_node_or_null("/root/EnemyWorld")
	var alive_before := int(index.call("alive_count"))
	var world_before := int(world.call("active_count")) if world != null else 0
	pool.call("set_limit_for_scene", scene, 8)
	pool.call("warm", scene, 3)
	await get_tree().process_frame
	_check(int(index.call("alive_count")) == alive_before, "warmed pool nodes do not register as live enemies")
	if world != null:
		_check(int(world.call("active_count")) == world_before, "warmed pool nodes do not create logical world records")
	var warm_ghosts := 0
	for group_member in get_tree().get_nodes_in_group("enemies"):
		var member := group_member as Node
		if member != null and bool(member.get_meta("__in_pool", false)):
			warm_ghosts += 1
	_check(warm_ghosts == 0, "warmed pool nodes stay out of the enemies group")

	var warmed := pool.call("obtain", scene, self) as EnemyActor
	await get_tree().process_frame
	_check(warmed != null and int(index.call("alive_count")) == alive_before + 1, "obtaining a warmed node registers it exactly once")
	if warmed != null:
		_check(warmed.is_in_group("enemies"), "obtained warmed node joins the enemies group")
		_check(warmed.is_physics_processing(), "obtained warmed node simulates")
		warmed.call("despawn", &"cleanup")
		await get_tree().process_frame
	_check(int(index.call("alive_count")) == alive_before, "warm test leaves population balanced")

	# A RECYCLED node must leave the group too, not only a warmed one: the
	# opening-phase restore sweeps get_nodes_in_group(&"enemies") and frees
	# what it finds, which used to take the whole warm pool with it, and the
	# herald/separation/tactical passes counted parked bodies as neighbours.
	# Godot hygiene audit 2026-08-28 §3 MED, top-10 #5.
	var recycled_probe := pool.call("obtain", scene, self) as EnemyActor
	await get_tree().process_frame
	_check(recycled_probe != null and recycled_probe.is_in_group("enemies"), "a live pooled enemy is in the group")
	if recycled_probe != null:
		recycled_probe.call("despawn", &"cleanup")
		await get_tree().process_frame
		_check(not recycled_probe.is_in_group("enemies"), "a recycled enemy leaves the enemies group")
		var reobtained := pool.call("obtain", scene, self) as EnemyActor
		await get_tree().process_frame
		_check(reobtained != null and reobtained.is_in_group("enemies"), "and rejoins it on the next obtain")
		if reobtained != null:
			reobtained.call("despawn", &"cleanup")
			await get_tree().process_frame

	# A representation-lease failure fires once per pooled obtain, so a starved
	# EnemyWorld used to push one context-free error per spawn. The report is
	# now rate-limited and each emitted line states how many failures it stands
	# for. Logging audit 2026-08-28 §3 #11.
	var lease_probe := pool.call("obtain", scene, self) as EnemyActor
	_check(lease_probe != null, "lease-limiter fixture obtains an enemy")
	if lease_probe != null:
		_check(lease_probe.has_method("_claim_lease_error"), "representation-lease failures are rate-limited")
		if lease_probe.has_method("_claim_lease_error"):
			var constants: Dictionary = lease_probe.get_script().get_script_constant_map()
			_check(constants.has("LEASE_ERROR_WINDOW_MS"), "the lease-error window is a named constant")
			var window: int = int(constants.get("LEASE_ERROR_WINDOW_MS", 0))
			# Far past anything this suite could already have logged, so the
			# first claim always opens a fresh window.
			var base_ms: int = Time.get_ticks_msec() + 1000000
			_check(
				int(lease_probe.call("_claim_lease_error", base_ms)) >= 1,
				"the first lease failure in a window is reported"
			)
			_check(int(lease_probe.call("_claim_lease_error", base_ms + 1)) == 0, "a burst inside the window is suppressed")
			_check(int(lease_probe.call("_claim_lease_error", base_ms + 2)) == 0, "and stays suppressed")
			_check(
				int(lease_probe.call("_claim_lease_error", base_ms + window)) == 3,
				"the next report stands for the failures it suppressed"
			)
		lease_probe.call("despawn", &"cleanup")
		await get_tree().process_frame

	# A sceneless frame (mid scene-transition) has nowhere legitimate to put a
	# live node. Obtaining used to fall back to the PoolManager autoload,
	# which is PROCESS_MODE_ALWAYS and outlives the scene: the node kept
	# processing while paused and survived the transition. It now refuses.
	# Godot hygiene audit 2026-08-28 §3 MED, top-10 #6.
	var saved_scene := get_tree().current_scene
	get_tree().current_scene = null
	var refused: Variant = pool.call("obtain", scene, null)
	get_tree().current_scene = saved_scene
	_check(refused == null, "obtaining on a sceneless frame refuses instead of parenting under the autoload")
	var stranded := 0
	for child in pool.get_children():
		if child != null and not bool(child.get_meta("__in_pool", false)):
			stranded += 1
	_check(stranded == 0, "and leaves no live node stranded under PoolManager (%d)" % stranded)

	_finish()


func _finish() -> void:
	print("EnemyPoolTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
