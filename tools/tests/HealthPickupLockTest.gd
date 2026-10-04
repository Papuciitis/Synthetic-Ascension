extends Node

# A health pickup touched while healing is sealed used to be consumed and heal
# nothing (HealthPickup._try_pickup vs player.heal's lock; audit 2026-10-04).
# It now stays in the world, does not trail the sealed player, and is taken
# normally once the seal lifts; an exempt source would still heal through it.

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const PICKUP_SCENE = preload("res://scenes/world/pickups/HealthPickup.tscn")

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
	var player: CharacterBody2D = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(player)
	await get_tree().process_frame
	player.set_process(false)
	player.set("hp", float(player.get("max_hp")) * 0.5)
	var pickup := PICKUP_SCENE.instantiate() as HealthPickup
	pickup.pickup_delay = 0.0
	pickup.global_position = player.global_position + Vector2(60.0, 0.0)
	add_child(pickup)
	await get_tree().process_frame
	await get_tree().process_frame

	player.call("lock_healing", 3.0, &"test")
	_check(bool(player.call("is_healing_blocked")), "fixture: healing is sealed")
	var hp_before := float(player.get("hp"))
	var spot := pickup.global_position
	pickup.call("_try_pickup", player)
	await get_tree().process_frame
	_check(is_instance_valid(pickup) and not pickup.is_queued_for_deletion(), "touching it while sealed leaves it in the world")
	_check(is_equal_approx(float(player.get("hp")), hp_before), "and heals nothing")
	for i in range(30):
		pickup.call("_magnet", 1.0 / 60.0)
	_check(pickup.global_position == spot, "a sealed player does not draw it in")

	# Exempt sources are honoured: the pickup heals as "generic".
	player.set("healing_lock_exempt_sources", [&"generic"] as Array[StringName])
	_check(not bool(player.call("is_healing_blocked")), "an exempt source is not blocked")
	player.set("healing_lock_exempt_sources", [] as Array[StringName])

	# The seal lifts: it is taken normally.
	player.call("_process", 3.1)
	_check(not bool(player.call("is_healing_blocked")), "fixture: the seal has lifted")
	pickup.call("_try_pickup", player)
	_check(float(player.get("hp")) > hp_before, "after the seal the same pickup heals (%.1f -> %.1f)" % [hp_before, float(player.get("hp"))])
	await get_tree().process_frame
	_check(not is_instance_valid(pickup), "and is consumed")

	player.queue_free()
	await get_tree().process_frame
	print("HealthPickupLockTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
