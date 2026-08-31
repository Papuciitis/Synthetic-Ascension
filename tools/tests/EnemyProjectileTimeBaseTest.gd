extends Node

# Enemy node projectiles must travel in PHYSICS time like everything else in
# the world. They used to integrate raw render delta, so when the world clock
# dilated under max_physics_steps_per_frame catch-up, enemy fire kept
# real-time speed while the enemies that fired it, the player, and every
# player bullet slowed down with the world.
#
# The model is ProjectileSimulationManager's, documented there: bank physics
# time in _physics_process, spend it once per RENDERED frame in _process,
# with one tick of headroom so high-refresh frames between physics ticks stay
# full-length. Godot hygiene audit 2026-08-28 §7 MED, top-10 #3.

const PROJECTILE_SCENE = preload("res://core/combat/projectile/EnemyProjectile.tscn")

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


func _tick() -> float:
	return 1.0 / float(maxi(Engine.physics_ticks_per_second, 1))


func _spawn(speed: float) -> EnemyProjectile:
	var p: EnemyProjectile = PROJECTILE_SCENE.instantiate() as EnemyProjectile
	add_child(p)
	p.global_position = Vector2.ZERO
	p.setup(Vector2.RIGHT, speed, 1.0, 999.0, null)
	return p


func _run() -> void:
	var tick := _tick()
	var speed := 1000.0

	# A render frame with NO banked physics time may still advance, but only
	# by the one-tick headroom - never by the full render delta.
	var starved := _spawn(speed)
	starved.call("_process", 1.0) # a comically long frame
	var starved_x := starved.global_position.x
	_check(
		starved_x <= speed * tick + 0.001,
		"an unbanked frame advances at most one tick of headroom (%.1f px, tick = %.1f px)" % [starved_x, speed * tick]
	)
	starved.queue_free()

	# Banked time is what gets spent. Three ticks - deliberately under the
	# catch-up cap, which the next case covers - then one render frame long
	# enough to spend all of it.
	var banked := _spawn(speed)
	for _i in range(3):
		banked.call("_physics_process", tick)
	banked.call("_process", 10.0)
	var banked_x := banked.global_position.x
	var expected := speed * (3.0 * tick + tick) # bank + headroom
	_check(
		absf(banked_x - expected) <= speed * tick * 0.5,
		"a frame spends the banked physics time, not the render delta (%.1f px, expected ~%.1f)" % [banked_x, expected]
	)
	banked.queue_free()

	# The bank is capped at what one main-loop iteration can deliver, so a
	# long stall cannot be converted into a burst of travel later.
	var stalled := _spawn(speed)
	for _i in range(600): # ten seconds of physics
		stalled.call("_physics_process", tick)
	stalled.call("_process", 100.0)
	var cap := tick * float(maxi(Engine.max_physics_steps_per_frame, 1))
	var stalled_x := stalled.global_position.x
	_check(
		stalled_x <= speed * (cap + tick) + 0.001,
		"a long stall cannot bank more than the catch-up cap (%.1f px, cap+headroom = %.1f)" % [stalled_x, speed * (cap + tick)]
	)
	stalled.queue_free()

	# Equal physics time spent must produce equal travel regardless of how
	# many render frames it was split across - this is the whole point.
	var few := _spawn(speed)
	var many := _spawn(speed)
	for _i in range(8):
		few.call("_physics_process", tick)
		many.call("_physics_process", tick)
	few.call("_process", 8.0 * tick)
	for _i in range(8):
		many.call("_process", tick)
	_check(
		absf(few.global_position.x - many.global_position.x) <= speed * tick * 0.75,
		"the same physics time travels the same distance in 1 frame or 8 (%.1f vs %.1f)"
			% [few.global_position.x, many.global_position.x]
	)
	few.queue_free()
	many.queue_free()

	print("EnemyProjectileTimeBaseTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
