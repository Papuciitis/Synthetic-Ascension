extends Node

# The projectile capacity policy (handoff finding E, tightened by the
# 2026-09-26 integration pass): gameplay events are never deleted OR DELAYED
# by renderer capacity. The simulation grows on demand up to SIM_CAPACITY_MAX
# with no queueing; the renderer draws at most RENDER_BUDGET instances and
# leaves the rest undrawn but fully real. Only beyond the simulation maximum
# does the bounded queue retain attacks, and only its overrun is a real,
# counted drop.
#
# Run: <godot> --headless --path . res://tools/tests/ProjectileOverflowTest.tscn

const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

var _passes := 0
var _failures := 0


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _ready() -> void:
	call_deferred(&"_run")


func _profile(damage: float, tags: PackedStringArray) -> HitProfileAdapter:
	var profile := HitProfileAdapter.new()
	profile.damage = damage
	profile.speed = 900.0
	profile.max_range = 500.0
	profile.collision_radius = 6.0
	profile.set_meta("asc_tags", tags)
	return profile


func _run() -> void:
	# Let the manager's scene sync settle first, or its first _process wipes
	# the pool the moment the current scene id changes.
	await get_tree().process_frame
	await get_tree().process_frame
	ProjectileManager.clear_for_run_end()
	var source := Node2D.new()
	add_child(source)
	var start_capacity: int = ProjectileManager.capacity
	var budget: int = ProjectileManager.RENDER_BUDGET
	var sim_max: int = ProjectileManager.SIM_CAPACITY_MAX
	var counters: Dictionary = ProjectileManager.get_debug_counters()
	var base_dropped := int(counters["dropped"])
	var tags := AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "BR05", "fragment", 1, 0.4)

	# --- Elastic simulation: filling past the starting capacity grows it,
	# with zero queueing and zero delay. The attack exists THIS frame.
	var accepted := 0
	for i in range(start_capacity):
		if ProjectileManager.spawn_player(Vector2(i % 64, i / 64.0), Vector2.RIGHT, _profile(1.0, AscensionTags.native("ranged", "bullet")), source):
			accepted += 1
	_check(accepted == start_capacity and ProjectileManager.active_count() == start_capacity, "the pool fills to its starting %d capacity" % start_capacity)
	var over := 100
	accepted = 0
	for i in range(over):
		if ProjectileManager.spawn_player(Vector2.ZERO, Vector2.RIGHT, _profile(2.5, tags), source):
			accepted += 1
	counters = ProjectileManager.get_debug_counters()
	_check(accepted == over and ProjectileManager.active_count() == start_capacity + over, "over-capacity attacks are simulated immediately (%d/%d), never delayed" % [accepted, over])
	_check(int(counters["overflow_queue"]) == 0, "nothing was queued below the simulation maximum")
	_check(int(counters["dropped"]) == base_dropped, "nothing was silently dropped")
	_check(int(counters["capacity"]) == start_capacity * 2, "the simulation grew (%d -> %d)" % [start_capacity, int(counters["capacity"])])

	# --- Renderer honesty: past the render budget the excess is undrawn but
	# fully real, and the counters say exactly how much.
	_check(int(counters["undrawn"]) == maxi(0, ProjectileManager.active_count() - budget), "the undrawn excess is counted (%d over a %d budget)" % [int(counters["undrawn"]), budget])
	_check(int(counters["visuals"]) <= budget, "no more than the render budget is drawn (%d <= %d)" % [int(counters["visuals"]), budget])
	await get_tree().process_frame
	var multimesh: MultiMesh = ProjectileManager.get("_multimesh")
	if multimesh != null:
		_check(multimesh.visible_instance_count <= budget, "the MultiMesh never draws past the budget (%d)" % multimesh.visible_instance_count)
	else:
		_check(true, "no renderer in this headless run; the counters carry the clamp")

	# --- An attack beyond the render budget still lands its exact damage:
	# undrawn is a visual state, not a gameplay state.
	ProjectileManager.clear_for_run_end()
	for i in range(budget + 50):
		ProjectileManager.spawn_player(Vector2(-4000, -4000), Vector2.LEFT, _profile(1.0, AscensionTags.native("ranged", "bullet")), source)
	var enemy := EnemyWorld.create_enemy(SpawnState.new(&"overflow_prey", "res://overflow_prey.tscn", Vector2(300, 0), 100.0, 0.0, 10.0, 0, 0))
	ProjectileManager.spawn_player(Vector2(250, 0), Vector2.RIGHT, _profile(37.0, tags), source)
	_check(ProjectileManager.active_count() == budget + 51, "the striking attack simulates beyond the render budget")
	for _i in range(30):
		await get_tree().process_frame
		if EnemyWorld.is_valid_handle(enemy) and EnemyWorld.get_health(enemy) < 100.0:
			break
	var hp := EnemyWorld.get_health(enemy) if EnemyWorld.is_valid_handle(enemy) else 100.0
	_check(is_equal_approx(hp, 63.0), "the undrawn attack dealt its exact 37 damage (hp %.1f)" % hp)
	if EnemyWorld.is_valid_handle(enemy):
		EnemyWorld.remove_enemy(enemy, &"test")
	ProjectileManager.clear_for_run_end()

	# --- Only past SIM_CAPACITY_MAX does the queue retain attacks; they keep
	# damage and provenance and drain the moment slots free.
	accepted = 0
	for i in range(sim_max):
		if ProjectileManager.spawn_player(Vector2(i % 128, i / 128.0), Vector2.RIGHT, _profile(1.0, tags), source):
			accepted += 1
	_check(accepted == sim_max and ProjectileManager.active_count() == sim_max, "the simulation reaches its %d maximum" % sim_max)
	for i in range(5):
		ProjectileManager.spawn_player(Vector2.ZERO, Vector2.RIGHT, _profile(2.5, tags), source)
	counters = ProjectileManager.get_debug_counters()
	_check(int(counters["overflow_queue"]) == 5, "past the simulation maximum the queue retains attacks (%d)" % int(counters["overflow_queue"]))
	_check(int(counters["dropped"]) == base_dropped, "retention is not a drop")
	var pooled: Array = []
	ProjectileManager.player_projectiles_in_radius(Vector2(64, 64), 400.0, pooled)
	for i in range(5):
		ProjectileManager.remove_projectile(int(pooled[i]["id"]))
	ProjectileManager._drain_overflow()
	counters = ProjectileManager.get_debug_counters()
	_check(int(counters["overflow_queue"]) == 0 and int(counters["overflow_released"]) == 5, "the queue drains once slots free (%d released)" % int(counters["overflow_released"]))
	_check(ProjectileManager.active_count() == sim_max, "the pool is full again with the released attacks")

	# --- The final bound: past OVERFLOW_QUEUE_MAX a request is a counted,
	# real drop — loud, never silent.
	var queue_max: int = ProjectileManager.OVERFLOW_QUEUE_MAX
	for i in range(queue_max + 5):
		ProjectileManager.spawn_player(Vector2.ZERO, Vector2.RIGHT, _profile(1.0, tags), source)
	counters = ProjectileManager.get_debug_counters()
	_check(int(counters["overflow_queue"]) == queue_max, "the queue respects its bound")
	_check(int(counters["overflow_dropped"]) == 5, "overrun past the bound is a counted drop (%d)" % int(counters["overflow_dropped"]))
	ProjectileManager.clear_for_run_end()

	print("ProjectileOverflowTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
