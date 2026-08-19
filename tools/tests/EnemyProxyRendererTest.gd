extends Node

const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const WorldScript = preload("res://core/systems/enemy_world/EnemyWorld.gd")
const RendererScript = preload("res://core/systems/enemy_world/EnemyProxyRenderer.gd")

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


func _spawn(
	world: EnemyWorldService,
	id: StringName,
	position: Vector2,
	flags: int = 0,
	cold_state: Dictionary = {},
) -> int:
	return world.create_enemy(SpawnState.new(
		id,
		"res://%s.tscn" % String(id),
		position,
		20.0,
		100.0,
		8.0,
		0,
		flags,
		cold_state,
	))


func _run() -> void:
	var world := WorldScript.new()
	add_child(world)
	var renderer := RendererScript.new()
	renderer.setup(world)
	add_child(renderer)

	var ordinary := _spawn(world, &"ordinary", Vector2.ZERO, 0, {
		"proxy_visual_key": &"grunt",
		"proxy_color": Color(0.2, 0.7, 1.0, 1.0),
		"proxy_size": Vector2(18.0, 14.0),
	})
	var materialized := _spawn(world, &"materialized", Vector2(50.0, 0.0))
	world.set_representation(materialized, Types.Representation.MATERIALIZED)
	var elite := _spawn(world, &"elite", Vector2(80.0, 0.0), Types.Flags.ELITE, {
		"proxy_visual_key": &"elite",
		"proxy_color": Color(1.0, 0.35, 0.1, 1.0),
	})
	renderer.publish(1.0)
	_check(renderer.visible_count() == 2, "only data-only records publish proxy instances")
	_check(renderer.has_visible_handle(ordinary), "ordinary data-only handle is visible")
	_check(not renderer.has_visible_handle(materialized), "materialized handle is excluded from proxy batches")
	_check(renderer.has_visible_handle(elite), "data-only elite remains visible during a representation shortage")
	_check(renderer.batch_count() == 2, "visual keys are published as separate shared batches")
	var elite_color := renderer.debug_instance_color(elite)
	_check(elite_color.is_equal_approx(Color(1.0, 0.35, 0.1, 1.0)), "per-record elite color metadata reaches the batch buffer (got %s)" % elite_color)

	world.set_position(ordinary, Vector2(20.0, 0.0))
	renderer.publish(0.25)
	var interpolated := renderer.debug_instance_transform(ordinary).origin
	_check(interpolated.is_equal_approx(Vector2(5.0, 0.0)), "renderer interpolates authoritative previous and current positions (got %s)" % interpolated)

	world.set_representation(ordinary, Types.Representation.MATERIALIZED)
	renderer.publish(1.0)
	_check(not renderer.has_visible_handle(ordinary), "materialization handoff removes the proxy in the same publish")
	_check(renderer.visible_count() == 1, "materialization handoff leaves no duplicate visual")
	world.set_representation(ordinary, Types.Representation.DATA_ONLY)
	renderer.publish(1.0)
	_check(renderer.has_visible_handle(ordinary), "dematerialization handoff restores the proxy")

	var stale := ordinary
	world.remove_enemy(stale, &"renderer_generation_test")
	var replacement := _spawn(world, &"replacement", Vector2(120.0, 4.0), 0, {
		"proxy_visual_key": &"grunt",
		"proxy_color": Color(0.4, 1.0, 0.3, 1.0),
	})
	renderer.publish(1.0)
	_check(replacement != stale, "slot reuse produces a different generation handle")
	_check(not renderer.has_visible_handle(stale), "removed generation cannot survive in a proxy batch")
	_check(renderer.has_visible_handle(replacement), "reused slot publishes only the current generation")
	var replacement_position := renderer.debug_instance_transform(replacement).origin
	_check(replacement_position.is_equal_approx(Vector2(120.0, 4.0)), "reused slot does not inherit a ghost transform (got %s)" % replacement_position)

	world.remove_enemy(elite, &"renderer_removal")
	world.remove_enemy(replacement, &"renderer_removal")
	renderer.publish(1.0)
	_check(renderer.visible_count() == 0, "removed handles clear every visible proxy instance")
	_check(renderer.debug_all_batches_hidden(), "empty cached batches have zero visible instances")

	var diagnostic := _spawn(world, &"metadata_missing", Vector2(7.0, 9.0))
	renderer.publish(1.0)
	_check(renderer.has_visible_handle(diagnostic), "missing visual metadata uses a visible diagnostic proxy")
	_check(renderer.debug_instance_color(diagnostic).a > 0.0, "diagnostic proxy is never transparent")
	_check(renderer.last_upload_usec() >= 0, "renderer exposes batch upload timing for the flight recorder")

	world.clear_world()
	for index in range(600):
		_spawn(world, StringName("bulk_%d" % index), Vector2(float(index % 30), float(index / 30)), 0, {
			"proxy_visual_key": &"bulk",
			"proxy_color": Color(0.5, 0.8, 1.0, 1.0),
		})
	renderer.publish(1.0)
	var started := Time.get_ticks_usec()
	for _frame in range(120):
		renderer.publish(0.5)
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	_check(renderer.visible_count() == 600, "one batched renderer publication keeps all 600 proxies visible")
	_check(elapsed_ms < 3000.0, "120 publications of 600 proxies stay within the headless regression budget")
	_check(renderer.last_upload_usec() < 50000, "one cached 600-proxy upload avoids a long main-thread stall")
	print("EnemyProxyRendererBenchmark records=600 frames=120 elapsed_ms=", snapped(elapsed_ms, 0.001), " last_upload_usec=", renderer.last_upload_usec())

	renderer.queue_free()
	world.queue_free()
	await get_tree().process_frame
	print("EnemyProxyRendererTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
