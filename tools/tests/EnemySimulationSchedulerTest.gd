extends Node

class ScheduledProbe:
	extends Node2D
	var dead := false
	var assigned_tier := 0
	var scheduled_deltas: Array[float] = []

	func set_scheduler_tier(tier: int) -> void:
		assigned_tier = tier

	func simulation_tier() -> int:
		return assigned_tier

	func run_scheduled_simulation(delta: float) -> void:
		scheduled_deltas.append(delta)

class PhysicsHog:
	extends Node

	func _physics_process(_delta: float) -> void:
		var until := Time.get_ticks_usec() + 5000
		while Time.get_ticks_usec() < until:
			pass


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
	var live_scheduler := get_node_or_null("/root/EnemySimulationScheduler")
	if live_scheduler != null:
		live_scheduler.set_physics_process(false)
	var scheduler_script := load("res://autoload/EnemySimulationScheduler.gd") as Script
	_check(scheduler_script != null, "enemy simulation scheduler script exists")
	if scheduler_script == null:
		_finish()
		return
	var scheduler := scheduler_script.new() as Node
	add_child(scheduler)
	# Deterministic budgets: never let real headless physics timing engage the
	# adaptive pressure fallback mid-test.
	scheduler.call("set_physics_pressure_override", false)
	_test_500_actor_budget(scheduler)
	_test_protected_actors_do_not_consume_ambient_budget(scheduler)
	_test_previous_full_actor_wins_equal_priority_tie(scheduler)
	await _test_enemy_tier_transitions()
	await _test_ambient_elites_and_smart_enemies_remain_budgeted(scheduler)
	await _test_eligible_ambient_still_reaches_far(scheduler)
	await _test_max_scheduler_tier_contract()
	await _test_smart_enemy_releases_far_physics()
	await _test_emergency_noncontact_smart_release(scheduler_script)
	_test_spatial_bands_cap_distant_fidelity(scheduler)
	_test_spatial_hysteresis_prevents_flapping(scheduler)
	_test_pressure_budget_fallback(scheduler_script)
	_test_smart_physics_boundaries(scheduler_script)
	_test_full_incumbent_rank_hysteresis(scheduler_script)
	_test_emergency_pressure_tier(scheduler_script)
	_test_severe_pressure_fast_path(scheduler_script)
	_test_pressure_release_survives_single_frame_spikes(scheduler_script)
	await _test_pressure_uses_per_step_samples(scheduler_script)
	await _test_same_frame_recycle_then_obtain_keeps_collision()
	await _test_unchanged_tier_preserves_stagger()
	_test_rotating_reduced_tick_groups(scheduler_script)
	_test_pooled_actor_stale_group_is_ignored(scheduler_script)
	_test_freed_actor_stale_group_is_ignored(scheduler_script)
	scheduler.queue_free()
	if live_scheduler != null:
		live_scheduler.set_physics_process(true)
	_finish()


func _test_500_actor_budget(scheduler: Node) -> void:
	scheduler.set("full_budget", 32)
	scheduler.set("mid_budget", 48)
	var enemies: Array = []
	for index in range(500):
		var enemy := Node2D.new()
		enemy.position = Vector2(float(index + 1), 0.0)
		add_child(enemy)
		enemies.append(enemy)
	var assignment := scheduler.call("compute_assignment", enemies, Vector2.ZERO) as Dictionary
	_check(assignment.size() == 500, "500-actor assignment loses no enemies")
	_check(_tier_count(assignment, 0) == 32, "full tier obeys hard ambient budget")
	_check(_tier_count(assignment, 1) == 48, "mid tier obeys hard ambient budget")
	_check(_tier_count(assignment, 2) == 420, "remaining actors become far proxies")
	_free_nodes(enemies)


func _test_protected_actors_do_not_consume_ambient_budget(scheduler: Node) -> void:
	scheduler.set("full_budget", 2)
	scheduler.set("mid_budget", 1)
	var enemies: Array = []
	for index in range(6):
		var enemy := Node2D.new()
		enemy.position = Vector2(float(index + 1) * 10.0, 0.0)
		add_child(enemy)
		enemies.append(enemy)
	(enemies[4] as Node).set_meta(&"objective_required", true)
	(enemies[5] as Node).add_to_group(&"boss_like")
	var assignment := scheduler.call("compute_assignment", enemies, Vector2.ZERO) as Dictionary
	var ordinary_full := 0
	for index in range(4):
		if int(assignment.get((enemies[index] as Node).get_instance_id(), -1)) == 0:
			ordinary_full += 1
	_check(ordinary_full == 2, "protected actors do not consume ordinary full budget")
	_check(int(assignment.get((enemies[4] as Node).get_instance_id(), -1)) == 0, "objective actor remains full")
	_check(int(assignment.get((enemies[5] as Node).get_instance_id(), -1)) == 0, "boss actor remains full")
	_check(assignment.size() == 6, "protected assignment keeps every actor")
	_free_nodes(enemies)


func _test_previous_full_actor_wins_equal_priority_tie(scheduler: Node) -> void:
	scheduler.set("full_budget", 1)
	scheduler.set("mid_budget", 0)
	var incumbent := Node2D.new()
	var challenger := Node2D.new()
	incumbent.position = Vector2(10.0, 0.0)
	challenger.position = Vector2(20.0, 0.0)
	add_child(incumbent)
	add_child(challenger)
	var first := scheduler.call("compute_assignment", [incumbent, challenger], Vector2.ZERO) as Dictionary
	_check(int(first.get(incumbent.get_instance_id(), -1)) == 0, "closest actor initially receives full simulation")
	challenger.position = incumbent.position
	var second := scheduler.call("compute_assignment", [incumbent, challenger], Vector2.ZERO) as Dictionary
	_check(int(second.get(incumbent.get_instance_id(), -1)) == 0, "previous full actor wins an equal-priority tie")
	incumbent.queue_free()
	challenger.queue_free()


func _test_enemy_tier_transitions() -> void:
	var enemy_scene := load("res://core/actors/enemy/enemy.tscn") as PackedScene
	var enemy := enemy_scene.instantiate() as EnemyActor
	add_child(enemy)
	await get_tree().process_frame
	_check(enemy.has_method("set_scheduler_tier"), "enemy exposes atomic scheduler tier transitions")
	_check(enemy.has_method("run_scheduled_simulation"), "enemy exposes manager-driven simulation")
	_check(enemy.has_method("is_body_physics_enabled"), "enemy exposes observable body physics state")
	_check(enemy.has_method("hitbox_roles"), "enemy exposes independent hitbox roles")
	if not enemy.has_method("set_scheduler_tier"):
		enemy.queue_free()
		return
	enemy.call("set_scheduler_tier", 2)
	await get_tree().physics_frame
	_check(not enemy.is_physics_processing(), "far actor has no individual physics callback")
	_check(not bool(enemy.call("is_body_physics_enabled")), "far actor leaves body physics")
	_check(enemy.call("hitbox_roles") == {"monitoring": false, "monitorable": false}, "far hitbox leaves broadphase")
	enemy.call("set_scheduler_tier", 1)
	await get_tree().physics_frame
	var mid_roles := enemy.call("hitbox_roles") as Dictionary
	_check(not enemy.is_physics_processing(), "mid actor is manager scheduled")
	_check(bool(enemy.call("is_body_physics_enabled")), "mid actor retains reduced world collision")
	_check(bool(mid_roles.get("monitorable", false)), "mid actor remains hittable")
	_check(not bool(mid_roles.get("monitoring", true)), "ordinary mid actor does not actively monitor")
	enemy.call("set_scheduler_tier", 0)
	await get_tree().physics_frame
	_check(enemy.is_physics_processing(), "full actor restores individual physics callback")
	_check(not bool((enemy.call("hitbox_roles") as Dictionary).get("monitoring", true)), "ordinary full actor avoids active monitoring")
	_check(enemy.has_method("is_simulation_protected"), "enemy exposes scheduler protection policy")
	enemy.set_meta(&"objective_required", true)
	if enemy.has_method("is_simulation_protected"):
		_check(bool(enemy.call("is_simulation_protected", 5000.0)), "objective actor is protected from reduced simulation")
	enemy.queue_free()

	var leech := enemy_scene.instantiate() as EnemyActor
	var leech_spec := EnemySpec.new()
	leech_spec.ai = EnemySpec.AI.LEECH
	leech.spec = leech_spec
	add_child(leech)
	await get_tree().process_frame
	if leech.has_method("set_scheduler_tier"):
		leech.call("set_scheduler_tier", 1)
		await get_tree().physics_frame
		_check(bool((leech.call("hitbox_roles") as Dictionary).get("monitoring", false)), "leech keeps active contact monitoring in mid tier")
	leech.queue_free()


func _test_rotating_reduced_tick_groups(scheduler_script: Script) -> void:
	var index := get_node("/root/EnemyIndex")
	var scheduler := scheduler_script.new() as Node
	scheduler.set("full_budget", 0)
	scheduler.set("mid_budget", 1)
	scheduler.set("assignment_interval", 0.20)
	scheduler.set("mid_group_count", 2)
	scheduler.set("far_group_count", 6)
	add_child(scheduler)
	var mid_probe := ScheduledProbe.new()
	var far_probe := ScheduledProbe.new()
	mid_probe.position = Vector2(10.0, 0.0)
	far_probe.position = Vector2(100.0, 0.0)
	add_child(mid_probe)
	add_child(far_probe)
	index.call("register", mid_probe)
	index.call("register", far_probe)
	for _frame in range(12):
		scheduler.call("_physics_process", 1.0 / 60.0)
	_check(mid_probe.assigned_tier == 1, "closest budgeted probe is assigned mid tier")
	_check(far_probe.assigned_tier == 2, "remaining probe is assigned far tier")
	_check(mid_probe.scheduled_deltas.size() == 6, "mid group runs six times across twelve physics frames")
	_check(far_probe.scheduled_deltas.size() == 2, "far group runs twice across twelve physics frames")
	if not mid_probe.scheduled_deltas.is_empty():
		_check(is_equal_approx(mid_probe.scheduled_deltas[0], 2.0 / 60.0), "mid step receives accumulated fixed delta")
	if not far_probe.scheduled_deltas.is_empty():
		_check(is_equal_approx(far_probe.scheduled_deltas[0], 6.0 / 60.0), "far step receives accumulated fixed delta")
	index.call("unregister", mid_probe)
	index.call("unregister", far_probe)
	mid_probe.queue_free()
	far_probe.queue_free()
	scheduler.queue_free()


func _test_ambient_elites_and_smart_enemies_remain_budgeted(scheduler: Node) -> void:
	scheduler.set("full_budget", 3)
	scheduler.set("mid_budget", 4)
	var enemy_scene := load("res://core/actors/enemy/enemy.tscn") as PackedScene
	var enemies: Array = []
	for index in range(6):
		var elite := enemy_scene.instantiate() as EnemyActor
		elite.position = Vector2(float(index + 1) * 10.0, 0.0)
		add_child(elite)
		elite.is_elite = true
		enemies.append(elite)
	for index in range(6):
		var ranged := enemy_scene.instantiate() as EnemyActor
		var ranged_spec := EnemySpec.new()
		ranged_spec.ai = EnemySpec.AI.RANGED
		ranged.spec = ranged_spec
		ranged.position = Vector2(float(index + 7) * 10.0, 0.0)
		add_child(ranged)
		enemies.append(ranged)
	await get_tree().process_frame
	var assignment := scheduler.call("compute_assignment", enemies, Vector2.ZERO) as Dictionary
	var counters := scheduler.call("get_debug_counters") as Dictionary
	_check(int(counters.get("protected", -1)) == 0, "ambient elites and smart archetypes do not bypass the hard budget")
	_check(_tier_count(assignment, 0) == 3, "mixed ambient horde still obeys full budget")
	# Far tier disables body collision and broadphase presence. Elites and smart
	# archetypes must never become unshootable, so their overflow clamps to mid.
	_check(_tier_count(assignment, 2) == 0, "ineligible archetypes are never demoted to collisionless far tier")
	_check(_tier_count(assignment, 1) == 9, "ineligible overflow clamps to mid simulation")
	_free_nodes(enemies)


func _test_eligible_ambient_still_reaches_far(scheduler: Node) -> void:
	scheduler.set("full_budget", 1)
	scheduler.set("mid_budget", 1)
	var enemy_scene := load("res://core/actors/enemy/enemy.tscn") as PackedScene
	var enemies: Array = []
	for index in range(5):
		var plain := enemy_scene.instantiate() as EnemyActor
		plain.position = Vector2(float(index + 1) * 10.0, 0.0)
		add_child(plain)
		enemies.append(plain)
	await get_tree().process_frame
	var assignment := scheduler.call("compute_assignment", enemies, Vector2.ZERO) as Dictionary
	_check(_tier_count(assignment, 2) == 3, "eligible ambient overflow still reaches far tier")
	_free_nodes(enemies)


func _test_max_scheduler_tier_contract() -> void:
	var enemy_scene := load("res://core/actors/enemy/enemy.tscn") as PackedScene
	var plain := enemy_scene.instantiate() as EnemyActor
	add_child(plain)
	await get_tree().process_frame
	_check(plain.has_method("max_scheduler_tier"), "enemy exposes maximum demotion tier")
	if not plain.has_method("max_scheduler_tier"):
		plain.queue_free()
		return
	_check(int(plain.call("max_scheduler_tier")) == 2, "eligible ambient enemy may be demoted to far tier")
	plain.is_elite = true
	_check(int(plain.call("max_scheduler_tier")) == 1, "elite keeps world collision at any distance")
	plain.is_elite = false
	var sniper_spec := EnemySpec.new()
	sniper_spec.ai = EnemySpec.AI.SNIPER
	plain.spec = sniper_spec
	_check(int(plain.call("max_scheduler_tier")) == 1, "sniper keeps world collision at any distance")
	_check(int(plain.call("max_scheduler_tier", 5000.0)) == 1, "distant sniper still keeps world collision")
	plain.queue_free()


func _test_unchanged_tier_preserves_stagger() -> void:
	var enemy_scene := load("res://core/actors/enemy/enemy.tscn") as PackedScene
	var enemy := enemy_scene.instantiate() as EnemyActor
	add_child(enemy)
	await get_tree().process_frame
	enemy.call("set_scheduler_tier", 1)
	enemy.set("_lod_force_refresh", false)
	enemy.set("_lod_steer_left", 5.0)
	enemy.call("set_scheduler_tier", 1)
	_check(not bool(enemy.get("_lod_force_refresh")), "reassigning an unchanged tier keeps the steering cache")
	_check(float(enemy.get("_lod_steer_left")) == 5.0, "reassigning an unchanged tier keeps the steering stagger")
	enemy.call("set_scheduler_tier", 2)
	_check(bool(enemy.get("_lod_force_refresh")), "an actual tier change still forces a steering refresh")
	enemy.queue_free()


func _test_pooled_actor_stale_group_is_ignored(scheduler_script: Script) -> void:
	var index := get_node("/root/EnemyIndex")
	var scheduler := scheduler_script.new() as Node
	scheduler.set("full_budget", 0)
	scheduler.set("mid_budget", 1)
	scheduler.set("mid_group_count", 1)
	add_child(scheduler)
	var probe := ScheduledProbe.new()
	add_child(probe)
	index.call("register", probe)
	scheduler.call("_physics_process", 1.0 / 60.0)
	var calls_before_pooling := probe.scheduled_deltas.size()
	probe.set_meta("__in_pool", true)
	probe.process_mode = Node.PROCESS_MODE_DISABLED
	scheduler.call("_physics_process", 1.0 / 60.0)
	_check(probe.scheduled_deltas.size() == calls_before_pooling, "stale reduced group never simulates an inactive pooled actor")
	index.call("unregister", probe)
	probe.queue_free()
	scheduler.queue_free()


func _test_freed_actor_stale_group_is_ignored(scheduler_script: Script) -> void:
	var index := get_node("/root/EnemyIndex")
	var scheduler := scheduler_script.new() as Node
	scheduler.set("full_budget", 0)
	scheduler.set("mid_budget", 1)
	scheduler.set("mid_group_count", 1)
	add_child(scheduler)
	var probe := ScheduledProbe.new()
	add_child(probe)
	index.call("register", probe)
	scheduler.call("_physics_process", 1.0 / 60.0)
	index.call("unregister", probe)
	probe.free()
	scheduler.call("_physics_process", 1.0 / 60.0)
	var counters := scheduler.call("get_debug_counters") as Dictionary
	_check(int(counters.get("stale_entries", 0)) == 1, "freed actor is discarded from a stale reduced group without casting it")
	scheduler.queue_free()


func _test_smart_enemy_releases_far_physics() -> void:
	var enemy_scene := load("res://core/actors/enemy/enemy.tscn") as PackedScene
	var ranged := enemy_scene.instantiate() as EnemyActor
	var ranged_spec := EnemySpec.new()
	ranged_spec.ai = EnemySpec.AI.RANGED
	ranged.spec = ranged_spec
	add_child(ranged)
	await get_tree().process_frame
	_check(int(ranged.call("max_scheduler_tier")) == 1, "smart archetype keeps collision when distance is unknown")
	_check(int(ranged.call("max_scheduler_tier", 1000.0)) == 1, "near smart archetype keeps world collision")
	_check(int(ranged.call("max_scheduler_tier", 3000.0)) == 2, "distant smart archetype may release physics")
	ranged.call("set_scheduler_tier", 2)
	_check(int(ranged.call("max_scheduler_tier", 2400.0)) == 2, "released smart archetype holds far physics until the re-acquire bound")
	_check(int(ranged.call("max_scheduler_tier", 2200.0)) == 1, "released smart archetype re-acquires collision when close again")
	ranged.call("set_scheduler_tier", 1)
	_check(int(ranged.call("max_scheduler_tier", 2400.0)) == 1, "mid smart archetype does not release before the release bound")
	var live_scheduler := get_node_or_null("/root/EnemySimulationScheduler")
	_check(live_scheduler != null, "live scheduler autoload exists for pressure-scale checks")
	if live_scheduler != null:
		live_scheduler.call("set_physics_pressure_override", true)
		live_scheduler.call("_update_pressure_state", 0.6)
		_check(int(ranged.call("max_scheduler_tier", 2000.0)) == 2, "sustained pressure pulls the release boundary inward")
		live_scheduler.call("set_physics_pressure_override", false)
		live_scheduler.call("_update_pressure_state", 2.1)
		_check(int(ranged.call("max_scheduler_tier", 2000.0)) == 1, "release boundary restores once pressure clears")
		live_scheduler.call("set_physics_pressure_override", null)
	ranged.is_elite = true
	_check(int(ranged.call("max_scheduler_tier", 3000.0)) == 1, "distant elite keeps world collision")
	ranged.queue_free()


func _test_emergency_noncontact_smart_release(scheduler_script: Script) -> void:
	var scheduler := scheduler_script.new() as Node
	add_child(scheduler)
	scheduler.call("set_physics_pressure_override", 45.0)
	scheduler.call("_update_pressure_state", 0.15)
	var floor_distance := float(scheduler.get("noncontact_release_min_distance"))
	_check(floor_distance > 0.0, "emergency noncontact release has a distance floor")
	_check(
		bool(scheduler.call("should_release_noncontact_smart", EnemySpec.AI.RANGED, floor_distance + 1.0)),
		"emergency pressure may release ordinary ranged body physics beyond the floor"
	)
	_check(
		bool(scheduler.call("should_release_noncontact_smart", EnemySpec.AI.ORBIT, floor_distance + 1.0)),
		"emergency pressure may release ordinary orbiter body physics beyond the floor"
	)
	_check(
		not bool(scheduler.call("should_release_noncontact_smart", EnemySpec.AI.RANGED, floor_distance - 1.0)),
		"emergency pressure keeps close ranged actors collidable (melee/contact must still land)"
	)
	_check(
		not bool(scheduler.call("should_release_noncontact_smart", EnemySpec.AI.CHARGE, floor_distance + 1.0)),
		"emergency pressure keeps charger collision exact"
	)
	_check(
		not bool(scheduler.call("should_release_noncontact_smart", EnemySpec.AI.BOMBER, floor_distance + 1.0)),
		"emergency pressure keeps bomber collision exact"
	)
	_check(
		not bool(scheduler.call("should_release_noncontact_smart", EnemySpec.AI.SNIPER, floor_distance + 1.0)),
		"emergency pressure keeps sniper collision exact"
	)
	var enemy_scene := load("res://core/actors/enemy/enemy.tscn") as PackedScene
	var ranged := enemy_scene.instantiate() as EnemyActor
	var ranged_spec := EnemySpec.new()
	ranged_spec.ai = EnemySpec.AI.RANGED
	ranged.spec = ranged_spec
	add_child(ranged)
	await get_tree().process_frame
	ranged.set("_sim_scheduler", scheduler)
	_check(
		int(ranged.call("max_scheduler_tier", floor_distance - 100.0)) == 1,
		"close ordinary ranged actor stays collidable under emergency pressure"
	)
	_check(
		int(ranged.call("max_scheduler_tier", floor_distance + 100.0)) == 2,
		"distant ordinary ranged actor integrates with emergency physics release"
	)
	ranged.set_meta(&"objective_required", true)
	_check(
		bool(ranged.call("is_simulation_protected", 500.0)),
		"objective ranged actor remains protected from emergency demotion"
	)
	ranged.queue_free()
	scheduler.queue_free()


func _test_pressure_release_survives_single_frame_spikes(scheduler_script: Script) -> void:
	var scheduler := scheduler_script.new() as Node
	scheduler.call("set_physics_pressure_override", 16.0)
	scheduler.call("_update_pressure_state", 0.6)
	_check(int((scheduler.call("get_debug_counters") as Dictionary).get("pressure_level", -1)) == 1, "sustained budget pressure engages level 1")
	var release_window := float(scheduler.get("pressure_release_sec"))
	# Calm frames with one slow frame every 12 (a 5 Hz refresh at 60 fps).
	# Total calm time is 3x the release window; isolated spikes - at the
	# current level or one above it - must not keep the level engaged.
	var frames := int(ceil(release_window * 3.0 / (1.0 / 60.0)))
	for i in range(frames):
		scheduler.call("set_physics_pressure_override", 16.0 if i % 12 == 0 else 5.0)
		scheduler.call("_update_pressure_state", 1.0 / 60.0)
	_check(
		int((scheduler.call("get_debug_counters") as Dictionary).get("pressure_level", -1)) == 0,
		"periodic single-frame spikes cannot pin pressure engaged"
	)
	scheduler.call("set_physics_pressure_override", 16.0)
	scheduler.call("_update_pressure_state", 0.6)
	for i in range(frames):
		scheduler.call("set_physics_pressure_override", 21.0 if i % 12 == 0 else 5.0)
		scheduler.call("_update_pressure_state", 1.0 / 60.0)
	_check(
		int((scheduler.call("get_debug_counters") as Dictionary).get("pressure_level", -1)) == 0,
		"periodic single-frame spikes above the next threshold cannot pin pressure either"
	)
	# A genuine return to pressure (0.3 s well over budget) between two calm
	# runs that together exceed the window must restart it.
	scheduler.call("set_physics_pressure_override", 16.0)
	scheduler.call("_update_pressure_state", 0.6)
	var calm_frames := int(release_window * 0.65 * 60.0)
	scheduler.call("set_physics_pressure_override", 5.0)
	for i in range(calm_frames):
		scheduler.call("_update_pressure_state", 1.0 / 60.0)
	scheduler.call("set_physics_pressure_override", 30.0)
	scheduler.call("_update_pressure_state", 0.3)
	scheduler.call("set_physics_pressure_override", 5.0)
	for i in range(calm_frames):
		scheduler.call("_update_pressure_state", 1.0 / 60.0)
	_check(
		int((scheduler.call("get_debug_counters") as Dictionary).get("pressure_level", -1)) == 1,
		"a sustained (0.3 s) return to pressure still restarts the release window"
	)
	# An oscillating load that is over budget most of the time stays engaged:
	# five frames at 15 ms then one at 13.5 ms, for 8 s.
	scheduler.call("set_physics_pressure_override", 16.0)
	scheduler.call("_update_pressure_state", 0.6)
	for i in range(480):
		scheduler.call("set_physics_pressure_override", 13.5 if i % 6 == 5 else 15.0)
		scheduler.call("_update_pressure_state", 1.0 / 60.0)
	_check(
		int((scheduler.call("get_debug_counters") as Dictionary).get("pressure_level", -1)) == 1,
		"a load over budget 5 frames in 6 stays engaged (dips do not accumulate into a release)"
	)
	scheduler.free()


func _test_pressure_uses_per_step_samples(scheduler_script: Script) -> void:
	# Performance.TIME_PHYSICS_PROCESS is the MAX step time of the previous
	# second, published once per second; per-frame reasoning needs a per-step
	# sample the scheduler measures itself, minus its own refresh cost.
	var scheduler := scheduler_script.new() as Node
	scheduler.call("_ingest_step_sample", 25.0, 12.0)
	_check(
		is_equal_approx(float(scheduler.call("_measured_physics_ms")), 13.0),
		"the refresh's own cost is subtracted from the step it ran in"
	)
	scheduler.call("_update_pressure_state", 0.6)
	_check(
		int((scheduler.call("get_debug_counters") as Dictionary).get("pressure_level", -1)) == 0,
		"a 13 ms horde under a 14 ms budget stays unpressured despite a 25 ms refresh step"
	)
	scheduler.call("_ingest_step_sample", 25.0, 0.0)
	scheduler.call("_update_pressure_state", 0.6)
	_check(
		int((scheduler.call("get_debug_counters") as Dictionary).get("pressure_level", -1)) == 1,
		"a 25 ms step with no refresh in it engages pressure"
	)
	scheduler.free()

	# Live measurement: the scheduler stamps the start of the physics step and
	# closes the sample at its next physics/process callback, so a 5 ms physics
	# callback anywhere in the scene shows up in the sample.
	var live := scheduler_script.new() as Node
	add_child(live)
	var hog := PhysicsHog.new()
	add_child(hog)
	for i in range(4):
		await get_tree().physics_frame
	var sample := float(live.call("last_step_sample_ms"))
	_check(sample >= 4.0, "per-step measurement captures scene physics callbacks (%.2f ms)" % sample)
	hog.queue_free()
	live.queue_free()
	await get_tree().process_frame


func _test_same_frame_recycle_then_obtain_keeps_collision() -> void:
	var enemy_scene := load("res://core/actors/enemy/enemy.tscn") as PackedScene
	var enemy := enemy_scene.instantiate() as EnemyActor
	enemy.spec = EnemySpec.new()
	add_child(enemy)
	await get_tree().process_frame
	# Pool recycle defers "disabled = true"; a same-frame obtain must still end
	# with a collidable, monitorable enemy once the deferred writes land.
	enemy.call("_on_pool_recycle")
	enemy.call("_reset_for_pool_obtain", false)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(bool(enemy.call("is_body_physics_enabled")), "same-frame recycle->obtain leaves body collision enabled")
	_check(bool((enemy.call("hitbox_roles") as Dictionary).get("monitorable", false)), "same-frame recycle->obtain leaves the hitbox monitorable")
	enemy.queue_free()


func _test_spatial_bands_cap_distant_fidelity(scheduler: Node) -> void:
	scheduler.set("full_budget", 32)
	scheduler.set("mid_budget", 32)
	scheduler.set("use_spatial_bands", true)
	var enemies: Array = []
	for index in range(5):
		enemies.append(_add_probe(Vector2(100.0 + float(index), 0.0)))
	for index in range(5):
		enemies.append(_add_probe(Vector2(1600.0 + float(index), 0.0)))
	for index in range(5):
		enemies.append(_add_probe(Vector2(2500.0 + float(index), 0.0)))
	var assignment := scheduler.call("compute_assignment", enemies, Vector2.ZERO) as Dictionary
	_check(_tier_count(assignment, 0) == 5, "free full budget does not keep mid-band actors in full simulation")
	_check(_tier_count(assignment, 1) == 5, "mid band actors settle at mid fidelity")
	_check(_tier_count(assignment, 2) == 5, "actors beyond the mid band demote to far despite free budget")
	var counters := scheduler.call("get_debug_counters") as Dictionary
	_check(int(counters.get("spatial_demotions", -1)) == 10, "spatial demotions are counted for telemetry")
	_free_nodes(enemies)


func _test_spatial_hysteresis_prevents_flapping(scheduler: Node) -> void:
	scheduler.set("full_budget", 32)
	scheduler.set("mid_budget", 32)
	scheduler.set("use_spatial_bands", true)
	var probe := _add_probe(Vector2(1300.0, 0.0))
	var enemies: Array = [probe]
	_check(_assigned_tier(scheduler, enemies, probe) == 1, "fresh actor between full enter and exit starts at mid")
	probe.position = Vector2(1150.0, 0.0)
	_check(_assigned_tier(scheduler, enemies, probe) == 0, "actor promotes to full inside the enter bound")
	probe.position = Vector2(1350.0, 0.0)
	_check(_assigned_tier(scheduler, enemies, probe) == 0, "full actor keeps its tier until the exit bound")
	probe.position = Vector2(1450.0, 0.0)
	_check(_assigned_tier(scheduler, enemies, probe) == 1, "full actor demotes past the exit bound")
	probe.position = Vector2(2050.0, 0.0)
	_check(_assigned_tier(scheduler, enemies, probe) == 1, "mid actor keeps its tier until the mid exit bound")
	probe.position = Vector2(2150.0, 0.0)
	_check(_assigned_tier(scheduler, enemies, probe) == 2, "mid actor demotes to far past the mid exit bound")
	probe.position = Vector2(1900.0, 0.0)
	_check(_assigned_tier(scheduler, enemies, probe) == 2, "far actor stays far until the mid enter bound")
	probe.position = Vector2(1750.0, 0.0)
	_check(_assigned_tier(scheduler, enemies, probe) == 1, "far actor promotes to mid inside the enter bound")
	_free_nodes(enemies)


func _test_pressure_budget_fallback(scheduler_script: Script) -> void:
	var scheduler := scheduler_script.new() as Node
	scheduler.set("full_budget", 32)
	scheduler.set("mid_budget", 32)
	scheduler.set("use_spatial_bands", false)
	scheduler.set("pressure_mid_budget", 24)
	scheduler.set("pressure_engage_sec", 0.5)
	scheduler.set("pressure_release_sec", 2.0)
	var enemies: Array = []
	for index in range(100):
		enemies.append(_add_probe(Vector2(float(index + 1), 0.0)))
	scheduler.call("set_physics_pressure_override", true)
	scheduler.call("_update_pressure_state", 0.3)
	var assignment := scheduler.call("compute_assignment", enemies, Vector2.ZERO) as Dictionary
	_check(_tier_count(assignment, 0) == 32, "brief physics spikes do not shrink the budgets")
	scheduler.call("_update_pressure_state", 0.3)
	assignment = scheduler.call("compute_assignment", enemies, Vector2.ZERO) as Dictionary
	_check(_tier_count(assignment, 0) == 12, "sustained physics pressure shrinks the full budget")
	_check(_tier_count(assignment, 1) == 24, "sustained physics pressure shrinks the mid budget")
	var counters := scheduler.call("get_debug_counters") as Dictionary
	_check(int(counters.get("pressure_active", 0)) == 1, "pressure fallback is visible in the debug counters")
	scheduler.call("set_physics_pressure_override", false)
	scheduler.call("_update_pressure_state", 0.5)
	assignment = scheduler.call("compute_assignment", enemies, Vector2.ZERO) as Dictionary
	_check(_tier_count(assignment, 0) == 12, "budgets recover only after sustained relief")
	scheduler.call("_update_pressure_state", 2.1)
	assignment = scheduler.call("compute_assignment", enemies, Vector2.ZERO) as Dictionary
	_check(_tier_count(assignment, 0) == 32, "budgets restore once physics stays calm")
	_free_nodes(enemies)
	scheduler.free()


func _test_smart_physics_boundaries(scheduler_script: Script) -> void:
	var scheduler := scheduler_script.new() as Node
	scheduler.call("set_physics_pressure_override", false)
	_check(
		is_equal_approx(float(scheduler.call("smart_physics_boundary", false)), 2600.0),
		"normal smart actors release body physics at 2600px"
	)
	_check(
		is_equal_approx(float(scheduler.call("smart_physics_boundary", true)), 2300.0),
		"normal far smart actors re-acquire body physics at 2300px"
	)
	scheduler.call("set_physics_pressure_override", 16.0)
	scheduler.call("_update_pressure_state", 0.6)
	_check(
		is_equal_approx(float(scheduler.call("smart_physics_boundary", false)), 1600.0),
		"pressure releases ordinary smart physics at 1600px"
	)
	_check(
		is_equal_approx(float(scheduler.call("smart_physics_boundary", true)), 1400.0),
		"pressure re-acquires ordinary smart physics at 1400px"
	)
	scheduler.call("set_physics_pressure_override", 25.0)
	scheduler.call("_update_pressure_state", 0.6)
	_check(
		is_equal_approx(float(scheduler.call("smart_physics_boundary", false)), 1450.0),
		"emergency pressure releases ordinary smart physics at 1450px"
	)
	_check(
		is_equal_approx(float(scheduler.call("smart_physics_boundary", true)), 1250.0),
		"emergency pressure re-acquires ordinary smart physics at 1250px"
	)
	var protected := _add_probe(Vector2(5000.0, 0.0))
	protected.set_meta(&"objective_required", true)
	var assignment := scheduler.call("compute_assignment", [protected], Vector2.ZERO) as Dictionary
	_check(
		int(assignment.get(protected.get_instance_id(), -1)) == 0,
		"protected actors retain exact collision under emergency pressure"
	)
	protected.queue_free()
	scheduler.free()


func _test_full_incumbent_rank_hysteresis(scheduler_script: Script) -> void:
	var scheduler := scheduler_script.new() as Node
	scheduler.set("full_budget", 1)
	scheduler.set("mid_budget", 8)
	scheduler.set("use_spatial_bands", false)
	scheduler.set("rank_incumbent_bias", 0.90)
	scheduler.call("set_physics_pressure_override", false)
	var incumbent := _add_probe(Vector2(1000.0, 0.0))
	var challenger := _add_probe(Vector2(1200.0, 0.0))
	var enemies: Array = [incumbent, challenger]
	_check(_assigned_tier(scheduler, enemies, incumbent) == 0, "closest actor takes the full slot initially")
	challenger.position = Vector2(960.0, 0.0)
	_check(_assigned_tier(scheduler, enemies, incumbent) == 0, "marginally closer challenger does not steal the full slot")
	challenger.position = Vector2(850.0, 0.0)
	_check(_assigned_tier(scheduler, enemies, challenger) == 0, "clearly closer challenger still takes the full slot")
	_free_nodes(enemies)
	scheduler.free()


func _test_emergency_pressure_tier(scheduler_script: Script) -> void:
	var scheduler := scheduler_script.new() as Node
	scheduler.set("full_budget", 32)
	scheduler.set("mid_budget", 32)
	scheduler.set("use_spatial_bands", false)
	var enemies: Array = []
	for index in range(80):
		enemies.append(_add_probe(Vector2(float(index + 1), 0.0)))
	# Numeric override = measured physics ms; 25 exceeds the emergency bound.
	scheduler.call("set_physics_pressure_override", 25.0)
	scheduler.call("_update_pressure_state", 0.6)
	var assignment := scheduler.call("compute_assignment", enemies, Vector2.ZERO) as Dictionary
	_check(_tier_count(assignment, 0) == 12, "first sustained step engages the ordinary pressure budgets")
	scheduler.call("_update_pressure_state", 0.6)
	assignment = scheduler.call("compute_assignment", enemies, Vector2.ZERO) as Dictionary
	_check(_tier_count(assignment, 0) == 8, "sustained emergency pressure shrinks the full budget to 8")
	_check(_tier_count(assignment, 1) == 16, "sustained emergency pressure keeps the mid budget at 16")
	_check(
		absf(float(scheduler.call("physics_release_distance_scale")) - 0.6) < 0.001,
		"emergency pressure pulls the release boundary hardest"
	)
	scheduler.call("set_physics_pressure_override", 5.0)
	scheduler.call("_update_pressure_state", 5.1)
	scheduler.call("_update_pressure_state", 2.1)
	assignment = scheduler.call("compute_assignment", enemies, Vector2.ZERO) as Dictionary
	_check(_tier_count(assignment, 0) == 32, "budgets restore fully after sustained calm")
	_free_nodes(enemies)
	scheduler.free()


func _test_severe_pressure_fast_path(scheduler_script: Script) -> void:
	var scheduler := scheduler_script.new() as Node
	scheduler.call("set_physics_pressure_override", 45.0)
	scheduler.call("_update_pressure_state", 0.10)
	_check(
		int((scheduler.call("get_debug_counters") as Dictionary).get("pressure_level", -1)) == 0,
		"a sub-150ms severe sample does not trip the emergency tier"
	)
	scheduler.call("_update_pressure_state", 0.05)
	var counters := scheduler.call("get_debug_counters") as Dictionary
	_check(int(counters.get("pressure_level", -1)) == 2, "150ms above 40ms physics jumps directly to emergency")
	_check(int(counters.get("severe_engagements", 0)) == 1, "severe fast-path engagements are counted")
	scheduler.call("set_physics_pressure_override", 5.0)
	scheduler.call("_update_pressure_state", 4.9)
	_check(
		int((scheduler.call("get_debug_counters") as Dictionary).get("pressure_level", -1)) == 2,
		"severe pressure holds the emergency tier through a short calm interval"
	)
	scheduler.call("_update_pressure_state", 0.2)
	_check(
		int((scheduler.call("get_debug_counters") as Dictionary).get("pressure_level", -1)) == 1,
		"severe pressure recovers one tier at a time"
	)
	scheduler.call("_update_pressure_state", 2.1)
	_check(
		int((scheduler.call("get_debug_counters") as Dictionary).get("pressure_level", -1)) == 0,
		"severe pressure returns to normal only after a second calm window"
	)
	scheduler.free()


func _add_probe(at: Vector2) -> Node2D:
	var probe := Node2D.new()
	probe.position = at
	add_child(probe)
	return probe


func _assigned_tier(scheduler: Node, enemies: Array, probe: Node) -> int:
	var assignment := scheduler.call("compute_assignment", enemies, Vector2.ZERO) as Dictionary
	return int(assignment.get(probe.get_instance_id(), -1))


func _tier_count(assignment: Dictionary, tier: int) -> int:
	var count := 0
	for value in assignment.values():
		if int(value) == tier:
			count += 1
	return count


func _free_nodes(nodes: Array) -> void:
	for node_variant in nodes:
		var node := node_variant as Node
		if node != null:
			node.queue_free()


func _finish() -> void:
	print("EnemySimulationSchedulerTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
