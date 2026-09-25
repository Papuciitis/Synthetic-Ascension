extends Node

# The projectile overflow policy (handoff finding E): at capacity a player
# attack queues instead of vanishing, drains as slots free, keeps its damage
# and provenance, and only the bounded queue's overrun counts as a real drop.
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
	var capacity: int = ProjectileManager.capacity
	var counters: Dictionary = ProjectileManager.get_debug_counters()
	var base_dropped := int(counters["dropped"])

	# Fill the pool to capacity with player spawns.
	var accepted := 0
	for i in range(capacity):
		if ProjectileManager.spawn_player(Vector2(i % 64, i / 64.0), Vector2.RIGHT, _profile(1.0, AscensionTags.native("ranged", "bullet")), source):
			accepted += 1
	_check(accepted == capacity and ProjectileManager.active_count() == capacity, "the pool fills to its %d capacity" % capacity)

	# Requests past capacity queue instead of dropping.
	var over := 100
	var retained := 0
	var tags := AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "BR05", "fragment", 1, 0.4)
	for i in range(over):
		if ProjectileManager.spawn_player(Vector2.ZERO, Vector2.RIGHT, _profile(2.5, tags), source):
			retained += 1
	counters = ProjectileManager.get_debug_counters()
	_check(retained == over, "every over-capacity player attack is retained (%d/%d)" % [retained, over])
	_check(int(counters["overflow_queue"]) == over, "the queue holds them (%d)" % int(counters["overflow_queue"]))
	_check(int(counters["dropped"]) == base_dropped, "nothing was silently dropped")

	# Accounting: requested == simulated + queued.
	_check(ProjectileManager.active_count() + int(counters["overflow_queue"]) == capacity + over, "requested = simulated + queued")

	# Free slots; the queue drains with damage and provenance intact.
	var pooled: Array = []
	ProjectileManager.player_projectiles_in_radius(Vector2(32, 32), 200.0, pooled)
	for i in range(over):
		ProjectileManager.remove_projectile(int(pooled[i]["id"]))
	ProjectileManager._drain_overflow()
	counters = ProjectileManager.get_debug_counters()
	_check(int(counters["overflow_queue"]) == 0, "the queue drains once slots free")
	_check(int(counters["overflow_released"]) == over, "every queued attack was released (%d)" % int(counters["overflow_released"]))
	_check(ProjectileManager.active_count() == capacity, "the pool is full again with the released attacks")

	# A released attack still lands as real damage with its tags.
	ProjectileManager.clear_for_run_end()
	for i in range(capacity):
		ProjectileManager.spawn_player(Vector2(-2000, -2000), Vector2.LEFT, _profile(1.0, AscensionTags.native("ranged", "bullet")), source)
	var enemy := EnemyWorld.create_enemy(SpawnState.new(&"overflow_prey", "res://overflow_prey.tscn", Vector2(300, 0), 100.0, 0.0, 10.0, 0, 0))
	ProjectileManager.spawn_player(Vector2(250, 0), Vector2.RIGHT, _profile(37.0, tags), source)
	var far_pool: Array = []
	ProjectileManager.player_projectiles_in_radius(Vector2(-2000, -2000), 400.0, far_pool)
	ProjectileManager.remove_projectile(int(far_pool[0]["id"]))
	ProjectileManager._drain_overflow()
	for _i in range(30):
		await get_tree().process_frame
		if EnemyWorld.is_valid_handle(enemy) and EnemyWorld.get_health(enemy) < 100.0:
			break
	var hp := EnemyWorld.get_health(enemy) if EnemyWorld.is_valid_handle(enemy) else 100.0
	_check(is_equal_approx(hp, 63.0), "the released attack dealt its exact 37 damage (hp %.1f)" % hp)
	if EnemyWorld.is_valid_handle(enemy):
		EnemyWorld.remove_enemy(enemy, &"test")
	ProjectileManager.clear_for_run_end()

	# The bound: past OVERFLOW_QUEUE_MAX a request is a counted, real drop.
	for i in range(capacity):
		ProjectileManager.spawn_player(Vector2.ZERO, Vector2.RIGHT, _profile(1.0, tags), source)
	var queue_max: int = ProjectileManager.OVERFLOW_QUEUE_MAX
	for i in range(queue_max + 5):
		ProjectileManager.spawn_player(Vector2.ZERO, Vector2.RIGHT, _profile(1.0, tags), source)
	counters = ProjectileManager.get_debug_counters()
	_check(int(counters["overflow_queue"]) == queue_max, "the queue respects its bound")
	_check(int(counters["overflow_dropped"]) == 5, "overrun past the bound is a counted drop (%d)" % int(counters["overflow_dropped"]))
	ProjectileManager.clear_for_run_end()

	print("ProjectileOverflowTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
