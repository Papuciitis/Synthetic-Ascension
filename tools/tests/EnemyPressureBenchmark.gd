extends Node

# Focused late-wave pressure benchmark. It deliberately exercises the costly
# mix that a pure grunt horde misses: ordinary smart actors that retain physics
# in the mid tier, plus protected snipers that must stay fully simulated.

const ENEMY_COUNT := 120
const RING_RADII: Array[float] = [900.0, 1360.0, 1820.0, 2280.0, 2740.0, 3200.0]
const WARMUP_FRAMES := 4 * 60
const SAMPLE_FRAMES := 20 * 60
const ORDINARY_SCENES: Array[String] = [
	"res://scenes/world/enemies/EnemyOrbiter.tscn",
	"res://scenes/world/enemies/EnemySpitter.tscn",
	"res://scenes/world/enemies/EnemyCharger.tscn",
	"res://scenes/world/enemies/EnemyBomber.tscn",
]
const SNIPER_SCENE := "res://scenes/world/enemies/EnemySniper.tscn"

var _player: Node2D
var _enemies: Array[EnemyActor] = []
var _frame_ms: Array[float] = []
var _process_ms: Array[float] = []
var _physics_ms: Array[float] = []
var _sample_count := 0
var _warmup_count := 0
var _sampling := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_setup")


func _setup() -> void:
	_player = Node2D.new()
	_player.name = "StationaryBenchmarkPlayer"
	_player.add_to_group(&"player")
	add_child(_player)

	var ordinary_scenes: Array[PackedScene] = []
	for path in ORDINARY_SCENES:
		var packed := load(path) as PackedScene
		if packed == null:
			_fail("ordinary enemy scene did not load: %s" % path)
			return
		ordinary_scenes.append(packed)
	var sniper_scene := load(SNIPER_SCENE) as PackedScene
	if sniper_scene == null:
		_fail("sniper scene did not load")
		return

	for index in range(ENEMY_COUNT):
		var is_protected_sniper := index % 20 == 0
		var packed := (
			sniper_scene
			if is_protected_sniper
			else ordinary_scenes[index % ordinary_scenes.size()]
		)
		var enemy := packed.instantiate() as EnemyActor
		if enemy == null:
			_fail("enemy %d did not instantiate" % index)
			return
		var ring_index := index % RING_RADII.size()
		var slot_index := index / RING_RADII.size()
		var slots_per_ring := ENEMY_COUNT / RING_RADII.size()
		var angle := TAU * float(slot_index) / float(slots_per_ring)
		enemy.global_position = Vector2.RIGHT.rotated(angle) * RING_RADII[ring_index]
		if is_protected_sniper:
			enemy.set_meta("sniper_combat_committed", true)
		add_child(enemy)
		_enemies.append(enemy)

	if _enemies.size() != ENEMY_COUNT:
		_fail("expected %d enemies, got %d" % [ENEMY_COUNT, _enemies.size()])
		return
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _enemies.size() != ENEMY_COUNT:
		return
	if not _sampling:
		_warmup_count += 1
		if _warmup_count >= WARMUP_FRAMES:
			_sampling = true
		return

	_frame_ms.append(delta * 1000.0)
	_process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_sample_count += 1
	if _sample_count >= SAMPLE_FRAMES:
		_finish()


func _finish() -> void:
	set_physics_process(false)
	var scheduler := get_node_or_null("/root/EnemySimulationScheduler")
	var counters := (
		scheduler.call("get_debug_counters") as Dictionary
		if scheduler != null and scheduler.has_method("get_debug_counters")
		else {}
	)
	var report := {
		"schema": 1,
		"benchmark": "enemy-pressure",
		"source_sha": OS.get_environment("BENCHMARK_SOURCE_SHA"),
		"enemy_count": ENEMY_COUNT,
		"protected_snipers": ENEMY_COUNT / 20,
		"ring_radii": RING_RADII,
		"warmup_frames": WARMUP_FRAMES,
		"sample_frames": _sample_count,
		"frame_ms": _summary(_frame_ms),
		"process_ms": _summary(_process_ms),
		"physics_ms": _summary(_physics_ms),
		"scheduler": counters,
	}
	var report_path := OS.get_environment("BENCHMARK_REPORT_PATH")
	if report_path.is_empty():
		report_path = "res://performance_results/benchmarks/enemy-pressure.json"
	var absolute_path := (
		ProjectSettings.globalize_path(report_path)
		if report_path.begins_with("res://")
		else report_path
	)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		_fail("could not open report path: %s" % absolute_path)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print(
		"EnemyPressureBenchmark: enemies=%d physics_p95=%.2f frame_p95=%.2f physics_enabled=%s report=%s"
		% [
			ENEMY_COUNT,
			float((report["physics_ms"] as Dictionary)["p95"]),
			float((report["frame_ms"] as Dictionary)["p95"]),
			counters.get("physics_enabled", "?"),
			absolute_path,
		]
	)
	get_tree().quit(0)


func _summary(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"mean": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
	var ordered := values.duplicate()
	ordered.sort()
	var total := 0.0
	for value in ordered:
		total += value
	return {
		"mean": total / float(ordered.size()),
		"p50": _percentile(ordered, 0.50),
		"p95": _percentile(ordered, 0.95),
		"p99": _percentile(ordered, 0.99),
		"max": ordered[-1],
	}


func _percentile(ordered: Array[float], fraction: float) -> float:
	return ordered[clampi(int(float(ordered.size() - 1) * fraction), 0, ordered.size() - 1)]


func _fail(message: String) -> void:
	push_error("EnemyPressureBenchmark: %s" % message)
	get_tree().quit(1)
