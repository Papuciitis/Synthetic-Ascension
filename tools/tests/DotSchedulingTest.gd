extends Node

# Enemy damage-over-time is scheduled once by EnemyStatus and keyed by stable
# handles. It must not create one processing Node per enemy or disappear when
# an actor representation is pooled.

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
	var enemy := scene.instantiate() as EnemyActor
	add_child(enemy)
	await get_tree().process_frame
	var handle := EnemyWorld.handle_for_actor(enemy)
	EnemyStatus.set_physics_process(false)
	EnemyStatus.clear_handle(handle)

	_check(EnemyStatus.apply_burn(handle, 2, 5.0, 0.5, 1.0), "enemy burn registers with central status service")
	_check(enemy.get_node_or_null("BurnDot") == null, "enemy burn creates no per-enemy processing node")

	var hp_before: float = enemy.hp
	EnemyStatus.advance(0.6)
	_check(is_equal_approx(enemy.hp, hp_before - 2.0), "central status step ticks burn (2 stacks x 1.0)")

	_check(EnemyStatus.apply_bleed(handle, 1, 5.0, 0.5, 1.0), "enemy bleed shares the central status schedule")
	_check(enemy.get_node_or_null("BleedDot") == null, "enemy bleed creates no per-enemy processing node")
	hp_before = enemy.hp
	EnemyStatus.advance(0.6)
	_check(is_equal_approx(enemy.hp, hp_before - 3.0), "one central step ticks both statuses (burn 2.0 + bleed 1.0)")

	EnemyStatus.clear_handle(handle)
	hp_before = enemy.hp
	EnemyStatus.apply_burn(handle, 1, 0.2, 0.5, 10.0)
	EnemyStatus.advance(0.6)
	_check(is_equal_approx(enemy.hp, hp_before) and not EnemyStatus.has_status(handle, &"burn"), "expired central status is removed without a late tick")

	# A dot attached to a non-enemy target still works standalone.
	var dummy := Node2D.new()
	add_child(dummy)
	var standalone := BurnDot.new()
	dummy.add_child(standalone)
	standalone.setup(dummy, null, 1, 5.0, 0.5, 1.0)
	_check(standalone.is_processing(), "dot on a non-enemy target keeps its standalone processing")

	EnemyStatus.clear_handle(handle)
	enemy.queue_free()
	dummy.queue_free()
	print("DotSchedulingTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
