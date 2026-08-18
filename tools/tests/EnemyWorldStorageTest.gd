extends Node

const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

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
	var handle: int = Types.make_handle(17, 9)
	_check(handle != Types.INVALID_HANDLE, "constructed handle is valid")
	_check(Types.slot_from_handle(handle) == 17, "handle preserves slot")
	_check(Types.generation_from_handle(handle) == 9, "handle preserves generation")
	_check(Types.slot_from_handle(Types.INVALID_HANDLE) == -1, "zero handle has no slot")

	var state := SpawnState.new(
		&"grunt",
		"res://scenes/world/enemies/EnemyGrunt.tscn",
		Vector2(12.0, 34.0),
		50.0,
		150.0,
		24.0,
		0,
	)
	_check(state.spec_id == &"grunt", "spawn state preserves spec id")
	_check(state.position == Vector2(12.0, 34.0), "spawn state preserves position")
	_check(
		state.health == 50.0 and state.max_health == 50.0,
		"spawn state starts at max health",
	)

	print("EnemyWorldStorageTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
