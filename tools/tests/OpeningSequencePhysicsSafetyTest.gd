extends Node2D

const CONTROLLER_SCENE := preload("res://core/systems/world/opening/OpeningSequenceController.tscn")

var _controller: OpeningSequenceController
var _spawned: OpeningActor
var _callback_finished: bool = false
var _entered_count: int = 0
var _failures: int = 0


func _ready() -> void:
	_controller = CONTROLLER_SCENE.instantiate() as OpeningSequenceController
	add_child(_controller)

	var receiver := _collision_area("Receiver")
	receiver.area_entered.connect(_on_area_entered)
	add_child(receiver)

	var intruder := _collision_area("Intruder")
	add_child(intruder)

	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame

	_check(_entered_count == 1, "the overlap enters exactly once")
	_check(_callback_finished, "opening actor creation completes after the physics callback")
	_check(_spawned != null and is_instance_valid(_spawned), "the callback returns an opening actor")
	_check(_spawned != null and _spawned.is_inside_tree(), "the returned opening actor is inside the scene tree")
	_check(_spawned != null and _spawned.is_node_ready(), "the returned opening actor is ready")

	print("OpeningSequencePhysicsSafetyTest: %d passed, %d failed" % [5 - _failures, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _collision_area(area_name: String) -> Area2D:
	var area := Area2D.new()
	area.name = area_name
	area.collision_layer = 1
	area.collision_mask = 1
	area.monitoring = true
	area.monitorable = true
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	collision.shape = circle
	area.add_child(collision)
	return area


func _on_area_entered(_other: Area2D) -> void:
	_entered_count += 1
	if _entered_count > 1:
		return
	_spawned = await _controller._spawn_actor(&"physics_test", Vector2(80.0, 0.0), null, false, 8.0)
	_callback_finished = true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)
