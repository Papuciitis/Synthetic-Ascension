extends Node

# Damage-over-time nodes must not run their own 60 Hz idle _process per enemy.
# They register with their EnemyActor and are ticked from its simulation step,
# so DoT cost follows the enemy's scheduler tier.

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

	var burn := BurnDot.new()
	burn.name = "BurnDot"
	enemy.add_child(burn)
	burn.setup(enemy, null, 2, 5.0, 0.5, 1.0)
	_check(not burn.is_processing(), "burn dot on an enemy does not self-process every idle frame")

	var hp_before: float = enemy.hp
	enemy.call("_run_simulation_step", 0.6)
	_check(is_equal_approx(enemy.hp, hp_before - 2.0), "enemy simulation step ticks the burn dot (2 stacks x 1.0)")

	var bleed := BleedDot.new()
	bleed.name = "BleedDot"
	enemy.add_child(bleed)
	bleed.setup(enemy, null, 1, 5.0, 0.5, 1.0)
	_check(not bleed.is_processing(), "bleed dot on an enemy does not self-process every idle frame")
	hp_before = enemy.hp
	enemy.call("_run_simulation_step", 0.6)
	_check(is_equal_approx(enemy.hp, hp_before - 3.0), "one step ticks both dots (burn 2.0 + bleed 1.0)")

	# Expiry still frees the node through the enemy-driven path.
	var short := BurnDot.new()
	short.name = "ShortBurn"
	enemy.add_child(short)
	short.setup(enemy, null, 1, 0.2, 0.5, 1.0)
	enemy.call("_run_simulation_step", 0.6)
	await get_tree().process_frame
	_check(enemy.get_node_or_null("ShortBurn") == null, "expired dot frees itself when ticked by the enemy")

	# A dot attached to a non-enemy target still works standalone.
	var dummy := Node2D.new()
	add_child(dummy)
	var standalone := BurnDot.new()
	dummy.add_child(standalone)
	standalone.setup(dummy, null, 1, 5.0, 0.5, 1.0)
	_check(standalone.is_processing(), "dot on a non-enemy target keeps its standalone processing")

	enemy.queue_free()
	dummy.queue_free()
	print("DotSchedulingTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
