extends Node

const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const EchoScript = preload("res://effects/lattice/scenes/LatticeEchoBuffer.gd")

class TestPlayer:
	extends Node2D
	var base_weapon_damage := 20.0
	var stats: Object = null

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


func _spawn(id: StringName, position: Vector2) -> int:
	return EnemyWorld.create_enemy(SpawnState.new(
		id,
		"res://%s.tscn" % String(id),
		position,
		20.0,
		0.0,
		4.0,
		0,
	))


func _run() -> void:
	var player := TestPlayer.new()
	add_child(player)

	var near_handle := _spawn(&"tesla_near", Vector2(20.0, 0.0))
	var far_handle := _spawn(&"tesla_far", Vector2(50.0, 0.0))
	var tesla := TeslaAuraEffect.new()
	tesla.radius = 80.0
	tesla.tick_interval = 0.1
	tesla.max_targets = 1
	tesla.damage_mult = 0.5
	tesla.setup(player)
	add_child(tesla)
	tesla.call("_process", 0.2)
	_check(EnemyWorld.get_health(near_handle) == 10.0, "Tesla aura damages the nearest data-only enemy")
	_check(EnemyWorld.get_health(far_handle) == 20.0, "Tesla aura preserves its maximum target count")
	tesla.queue_free()
	EnemyWorld.remove_enemy(near_handle, &"effect_reset")
	EnemyWorld.remove_enemy(far_handle, &"effect_reset")

	var controlled_handle := _spawn(&"area_controlled", Vector2(30.0, 0.0))
	var echo := EchoScript.new()
	echo.setup(player)
	add_child(echo)
	echo.call("_damage_radius", Vector2.ZERO, 60.0, 5.0, 100.0, 0.3)
	_check(EnemyWorld.get_health(controlled_handle) == 15.0, "set-effect radius damage reaches a data-only enemy")
	_check(
		EnemyWorld.get_knockback_velocity(controlled_handle).is_equal_approx(Vector2(100.0, 0.0)),
		"set-effect knockback persists without an enemy Node",
	)
	_check(is_equal_approx(EnemyWorld.get_stun_time(controlled_handle), 0.3), "set-effect stun persists without an enemy Node")

	EnemyWorld.remove_enemy(controlled_handle, &"effect_cleanup")
	echo.queue_free()
	player.queue_free()
	await get_tree().process_frame
	print("EnemyAreaEffectTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
