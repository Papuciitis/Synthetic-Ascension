extends Node

# Covers the EnemyIndex spatial-query radius clamp, swap-remove bucket
# maintenance, and live elite population tracking.

const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const WorldTypes = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")

class DummyEnemy:
	extends Node2D
	var dead := false
	var is_elite := false

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


func _spawn_dummy(index: Node, pos: Vector2, elite: bool = false) -> DummyEnemy:
	var e := DummyEnemy.new()
	e.is_elite = elite
	add_child(e)
	e.global_position = pos
	index.call("register", e)
	return e


func _run() -> void:
	var index := get_node_or_null("/root/EnemyIndex")
	var world := get_node_or_null("/root/EnemyWorld")
	_check(index != null, "enemy index autoload exists")
	_check(world != null, "enemy world autoload exists")
	if index == null or world == null:
		_finish()
		return
	var world_baseline := int(world.call("active_count"))

	var near := _spawn_dummy(index, Vector2(40.0, 0.0))
	var mid := _spawn_dummy(index, Vector2(400.0, 0.0))
	var far := _spawn_dummy(index, Vector2(3000.0, 0.0))
	_check(int(world.call("active_count")) == world_baseline + 3, "index registration mirrors logical records")
	var near_handle := int(world.call("handle_for_actor", near))
	_check(near_handle != 0, "registered enemy receives a stable handle")
	near.global_position = Vector2(96.0, 12.0)
	index.call("update_enemy", near)
	_check(world.call("get_position", near_handle) == near.global_position, "index movement synchronizes logical position")

	# --- Radius clamp: huge radii must degrade to an occupied-bucket scan ---
	var started := Time.get_ticks_usec()
	var found := index.call("nearest_enemy", Vector2.ZERO, 50000.0, null) as Node2D
	var elapsed := Time.get_ticks_usec() - started
	_check(found == near, "huge-radius nearest_enemy still finds the closest enemy")
	_check(elapsed < 250_000, "huge-radius nearest_enemy completes without scanning the full cell window (took %d usec)" % elapsed)

	started = Time.get_ticks_usec()
	var gathered: Array = []
	index.call("gather_in_radius", Vector2.ZERO, 50000.0, gathered)
	elapsed = Time.get_ticks_usec() - started
	_check(gathered.size() == 3, "huge-radius gather_in_radius returns every live enemy")
	_check(elapsed < 250_000, "huge-radius gather_in_radius completes without scanning the full cell window (took %d usec)" % elapsed)

	started = Time.get_ticks_usec()
	var in_radius := index.call("first_in_radius", Vector2(2990.0, 0.0), 40000.0, null) as Node2D
	elapsed = Time.get_ticks_usec() - started
	_check(in_radius != null, "huge-radius first_in_radius finds an enemy")
	_check(elapsed < 250_000, "huge-radius first_in_radius completes without scanning the full cell window (took %d usec)" % elapsed)

	started = Time.get_ticks_usec()
	var allies := int(index.call("count_allies", near, 50000.0, 999))
	elapsed = Time.get_ticks_usec() - started
	_check(allies == 2, "huge-radius count_allies counts the other live enemies")
	_check(elapsed < 250_000, "huge-radius count_allies completes without scanning the full cell window (took %d usec)" % elapsed)

	# Bounded radii keep exclusion semantics.
	_check(index.call("nearest_enemy", Vector2.ZERO, 100.0, null) == near, "bounded nearest_enemy respects max_dist")
	_check(index.call("nearest_enemy", Vector2(10000.0, 0.0), 100.0, null) == null, "bounded nearest_enemy returns null when nothing is in range")
	_check(index.call("nearest_enemy", Vector2.ZERO, 50000.0, near) == mid, "huge-radius nearest_enemy honors the exclude argument")

	# Dead enemies never surface.
	mid.dead = true
	gathered.clear()
	index.call("gather_in_radius", Vector2.ZERO, 50000.0, gathered)
	_check(gathered.size() == 2, "dead enemies are filtered from huge-radius gathers")
	mid.dead = false

	# --- Bucket maintenance survives unregistering a mid-bucket enemy ---
	var same_cell_a := _spawn_dummy(index, Vector2(41.0, 1.0))
	var same_cell_b := _spawn_dummy(index, Vector2(42.0, 2.0))
	index.call("unregister", same_cell_a)
	var still_found := index.call("nearest_enemy", Vector2(40.0, 0.0), 100.0, null) as Node2D
	_check(still_found == near or still_found == same_cell_b, "bucket removal keeps remaining same-cell enemies queryable")
	index.call("unregister", same_cell_b)
	same_cell_a.queue_free()
	same_cell_b.queue_free()

	# --- Live elite population tracking ---
	_check(index.has_method("elite_alive_count"), "index exposes live elite count")
	if index.has_method("elite_alive_count"):
		var baseline := int(index.call("elite_alive_count"))
		var elite := _spawn_dummy(index, Vector2(800.0, 0.0), true)
		_check(int(index.call("elite_alive_count")) == baseline + 1, "registering an elite increments the live elite count")
		near.is_elite = true
		index.call("note_elite", near)
		_check(int(index.call("elite_alive_count")) == baseline + 2, "promoting a registered enemy increments the live elite count")
		_check(
			WorldTypes.has_flag(int(world.call("get_flags", near_handle)), WorldTypes.Flags.ELITE),
			"elite promotion synchronizes the logical record",
		)
		index.call("note_elite", near)
		_check(int(index.call("elite_alive_count")) == baseline + 2, "double promotion does not double count")
		index.call("mark_dead", elite)
		_check(int(index.call("elite_alive_count")) == baseline + 1, "elite death decrements the live elite count")
		index.call("unregister", near)
		_check(int(index.call("elite_alive_count")) == baseline, "unregistering an elite decrements the live elite count")
		index.call("register", near)
		_check(int(index.call("elite_alive_count")) == baseline + 1, "re-registering a live elite recounts it")
		index.call("unregister", near)
		index.call("unregister", elite)
		elite.queue_free()

	# Maintenance rebuilds only legacy shadow records. Native logical records
	# already owned by EnemyWorld must survive an EnemyIndex repair pass.
	var native_handle := int(world.call(
		"create_enemy",
		SpawnState.new(&"native", "res://native.tscn", Vector2(9000.0, 0.0), 10.0, 10.0, 5.0, 0),
	))
	var stale := _spawn_dummy(index, Vector2(1200.0, 0.0))
	stale.queue_free()
	var externally_freed := _spawn_dummy(index, Vector2(1300.0, 0.0))
	externally_freed.free()
	_check(int(index.call("prune_invalid")) == 2, "index maintenance prunes queued and externally freed actors")
	_check(bool(world.call("is_valid_handle", native_handle)), "index rebuild preserves native logical records")
	_check(
		int(world.call("active_count")) == int(index.call("alive_count")) + 1,
		"world mirrors valid index actors without duplicating them",
	)

	index.call("unregister", mid)
	index.call("unregister", far)
	world.call("remove_enemy", native_handle, &"test_cleanup")
	near.queue_free()
	mid.queue_free()
	far.queue_free()
	_check(int(world.call("active_count")) == world_baseline, "index cleanup returns world count to baseline")
	_finish()


func _finish() -> void:
	print("EnemyIndexTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
