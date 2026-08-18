extends Node

const ENEMY_COUNT := 180
const WARMUP_FRAMES := 30
const SAMPLE_FRAMES := 120

var _player: Node2D
var _enemies: Array[EnemyActor] = []
var _initial_positions: Array[Vector2] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_player = Node2D.new()
	_player.name = "BenchmarkPlayer"
	_player.add_to_group(&"player")
	add_child(_player)

	var scene := load("res://scenes/world/enemies/EnemyGrunt.tscn") as PackedScene
	if scene == null:
		push_error("EnemySimulationBenchmark: grunt scene did not load")
		get_tree().quit(1)
		return

	for i in range(ENEMY_COUNT):
		var enemy := scene.instantiate() as EnemyActor
		var angle := TAU * float(i) / float(ENEMY_COUNT)
		var ring := 260.0 + float(i % 6) * 70.0
		enemy.position = Vector2.RIGHT.rotated(angle) * ring
		add_child(enemy)
		_enemies.append(enemy)
		_initial_positions.append(enemy.position)

	for _i in range(WARMUP_FRAMES):
		await get_tree().physics_frame

	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.set_physics_process(false)
	_reset_enemy_state()
	var adaptive_usec := _measure_manual(SAMPLE_FRAMES)
	for enemy in _enemies:
		if not is_instance_valid(enemy):
			continue
		# The population LOD layer is gone; pinning tier 0 is all the "legacy"
		# full-simulation comparison needs now.
		enemy.set("_lod_tier", 0)
	_reset_enemy_state()
	var legacy_usec := _measure_manual(SAMPLE_FRAMES)
	for enemy in _enemies:
		if not is_instance_valid(enemy):
			continue
		enemy.dumb_pathing_enabled = false
		enemy.flow_for_swarm_ai = false
		enemy.wall_slide_enabled = false
		enemy.stuck_nudge_enabled = false
	var movement_only_usec := _measure_manual(SAMPLE_FRAMES)
	var steering_usec := maxi(0, legacy_usec - movement_only_usec)
	print(
		"EnemySimulationBenchmark: enemies=%d frames=%d adaptive_ms=%.2f legacy_ms=%.2f adaptive_speedup=%.2fx movement_only_ms=%.2f steering_ms=%.2f adaptive_ms_per_frame=%.3f"
		% [
			ENEMY_COUNT,
			SAMPLE_FRAMES,
			float(adaptive_usec) / 1000.0,
			float(legacy_usec) / 1000.0,
			float(legacy_usec) / maxf(1.0, float(adaptive_usec)),
			float(movement_only_usec) / 1000.0,
			float(steering_usec) / 1000.0,
			float(adaptive_usec) / 1000.0 / float(SAMPLE_FRAMES),
		]
	)
	get_tree().quit(0)


func _measure_manual(frame_count: int) -> int:
	var started := Time.get_ticks_usec()
	for _i in range(frame_count):
		for enemy in _enemies:
			if is_instance_valid(enemy):
				enemy._physics_process(1.0 / 60.0)
	return Time.get_ticks_usec() - started


func _reset_enemy_state() -> void:
	for i in range(_enemies.size()):
		var enemy := _enemies[i]
		if not is_instance_valid(enemy):
			continue
		enemy.position = _initial_positions[i]
		enemy.velocity = Vector2.ZERO
		enemy.set("_far_step_left", 0.0)
		enemy.set("_far_delta_accum", 0.0)
		enemy.set("_lod_steer_left", 0.0)
		enemy.set("_lod_steer_accum", 0.0)
		enemy.set("_lod_force_refresh", true)
