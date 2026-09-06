extends Node

# Focused late-wave pressure benchmark. It deliberately exercises the costly
# mix that a pure grunt horde misses: ordinary smart actors that retain physics
# in the mid tier, plus protected snipers that must stay fully simulated.

const ENEMY_COUNT := 120
const BuildInfoScript = preload("res://core/systems/telemetry/BuildInfo.gd")
const RING_RADII: Array[float] = [900.0, 1500.0, 1820.0, 2280.0, 2740.0, 3200.0]
const WARMUP_SEC := 4.0
const BASELINE_IMPROVEMENT_GATE := 0.20
# Default arm: a controlled pressure override (above emergency_pressure_ms) so
# the scheduler engages its emergency tier during warm-up and the sample
# measures the TIER POLICY's effect: how many ordinary bodies keep physics. At 120 stationary
# enemies this workload never crosses the pressure threshold by itself, so
# without the override baseline and candidate were identical by construction.
# BENCHMARK_PRESSURE_NATURAL=1 runs without the override (measurement only).
const PRESSURE_OVERRIDE_MS := 25.0
const SAMPLE_SEC := 20.0
const ORDINARY_SCENES: Array[String] = [
	"res://scenes/world/enemies/EnemyOrbiter.tscn",
	"res://scenes/world/enemies/EnemySpitter.tscn",
	"res://scenes/world/enemies/EnemyCharger.tscn",
	"res://scenes/world/enemies/EnemyBomber.tscn",
]
const SNIPER_SCENE := "res://scenes/world/enemies/EnemySniper.tscn"

class StationaryPlayer:
	extends Node2D
	var hp := 100.0
	var max_hp := 100.0
	var run_inventory: Variant = null

	func take_damage(_amount: float, _source: Node = null) -> void:
		pass

	func hurt(_amount: float, _source: Node = null) -> void:
		pass

var _player: Node2D
var _enemies: Array[EnemyActor] = []
var _frame_ms: Array[float] = []
var _process_ms: Array[float] = []
var _physics_ms: Array[float] = []
var _step_ms: Array[float] = []
var _sample_count := 0
var _pressure_override := true
var _sampling := false
var _phase_started_usec := 0
var _legacy_pressure_contract := false
var _recorder_enabled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_setup")


func _setup() -> void:
	var scheduler := get_node_or_null("/root/EnemySimulationScheduler")
	var recorder := get_node_or_null("/root/PerformanceFlightRecorder")
	_legacy_pressure_contract = OS.get_environment("BENCHMARK_LEGACY_PRESSURE") == "1"
	_pressure_override = OS.get_environment("BENCHMARK_PRESSURE_NATURAL") != "1"
	_recorder_enabled = OS.get_environment("BENCHMARK_RECORDER_ENABLED") == "1"
	if recorder != null:
		recorder.call("configure", {"automatic_capture": false, "write_reports": false})
		recorder.call("set_enabled", _recorder_enabled)
		recorder.call("clear_session")
	if _legacy_pressure_contract and scheduler != null:
		# Reproduce the pre-change scaled boundaries on the same immutable
		# workload, so baseline and candidate differ only by scheduler policy.
		scheduler.set("pressure_smart_release_distance", 1950.0)
		scheduler.set("pressure_smart_reacquire_distance", 1725.0)
		scheduler.set("emergency_smart_release_distance", 1560.0)
		scheduler.set("emergency_smart_reacquire_distance", 1380.0)
	_player = StationaryPlayer.new()
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
		# Preserve the six-ring workload for the whole sample. Zero movement still
		# executes the real AI, scheduler, collision-role and move-and-slide paths,
		# but prevents the benchmark from degrading into contact deaths, drops and
		# pickup scripts whose cost depends on random path convergence.
		if enemy.spec != null:
			enemy.spec = enemy.spec.duplicate(true) as EnemySpec
			enemy.spec.speed = 0.0
			enemy.spec.projectile_damage = 0.0
		if is_protected_sniper:
			enemy.set_meta("sniper_combat_committed", true)
		add_child(enemy)
		_enemies.append(enemy)

	if _enemies.size() != ENEMY_COUNT:
		_fail("expected %d enemies, got %d" % [ENEMY_COUNT, _enemies.size()])
		return
	if _pressure_override and scheduler != null and scheduler.has_method("set_physics_pressure_override"):
		scheduler.call("set_physics_pressure_override", PRESSURE_OVERRIDE_MS)
	_phase_started_usec = Time.get_ticks_usec()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _enemies.size() != ENEMY_COUNT:
		return
	if not _sampling:
		if float(Time.get_ticks_usec() - _phase_started_usec) / 1_000_000.0 >= WARMUP_SEC:
			_sampling = true
			_phase_started_usec = Time.get_ticks_usec()
		return

	_frame_ms.append(delta * 1000.0)
	_process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	# TIME_PHYSICS_PROCESS is the max step of the previous second, published
	# once a second; the scheduler's own per-step sample is what the gate uses.
	_physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	var scheduler := get_node_or_null("/root/EnemySimulationScheduler")
	if scheduler != null and scheduler.has_method("last_step_sample_ms"):
		_step_ms.append(float(scheduler.call("last_step_sample_ms")))
	_sample_count += 1
	if float(Time.get_ticks_usec() - _phase_started_usec) / 1_000_000.0 >= SAMPLE_SEC:
		_finish()


func _finish() -> void:
	set_physics_process(false)
	var scheduler := get_node_or_null("/root/EnemySimulationScheduler")
	var recorder := get_node_or_null("/root/PerformanceFlightRecorder")
	var counters := (
		scheduler.call("get_debug_counters") as Dictionary
		if scheduler != null and scheduler.has_method("get_debug_counters")
		else {}
	)
	if _pressure_override and scheduler != null and scheduler.has_method("set_physics_pressure_override"):
		scheduler.call("set_physics_pressure_override", null)
		if int(counters.get("pressure_level", 0)) < 2:
			_fail("pressure override did not engage the emergency tier (level %s)" % counters.get("pressure_level", "?"))
			return
	var source_sha := OS.get_environment("BENCHMARK_SOURCE_SHA")
	if source_sha.is_empty():
		source_sha = BuildInfoScript.git_commit()
	var report := {
		"schema": 2,
		"benchmark": "enemy-pressure",
		"pressure_contract": "legacy-scaled" if _legacy_pressure_contract else "explicit-bands",
		"pressure_mode": "override" if _pressure_override else "natural",
		"pressure_override_ms": PRESSURE_OVERRIDE_MS if _pressure_override else 0.0,
		"pressure_level": int(counters.get("pressure_level", 0)),
		"source_sha": source_sha,
		"build": BuildInfoScript.describe(),
		"enemy_count": ENEMY_COUNT,
		"protected_snipers": ENEMY_COUNT / 20,
		"ring_radii": RING_RADII,
		"warmup_seconds": WARMUP_SEC,
		"sample_seconds": SAMPLE_SEC,
		"sample_frames": _sample_count,
		"recorder_enabled": _recorder_enabled,
		"recorder": recorder.call("get_status_snapshot") if recorder != null else {},
		"frame_ms": _summary(_frame_ms),
		"process_ms": _summary(_process_ms),
		"physics_ms": _summary(_physics_ms),
		"physics_step_ms": _summary(_step_ms),
		"scheduler": counters,
		"ordinary_physics_enabled": maxi(
			0,
			int(counters.get("physics_enabled", 0)) - int(counters.get("protected", 0))
		),
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
	# Acceptance gate: with BENCHMARK_BASELINE_PATH pointing at a report from
	# the legacy arm (BENCHMARK_LEGACY_PRESSURE=1), the candidate must cut
	# physics p95 by at least BASELINE_IMPROVEMENT_GATE. Without a baseline
	# the run is a measurement only.
	var baseline_path := OS.get_environment("BENCHMARK_BASELINE_PATH")
	if not baseline_path.is_empty():
		var baseline_file := FileAccess.open(baseline_path, FileAccess.READ)
		var baseline: Variant = null
		if baseline_file != null:
			baseline = JSON.parse_string(baseline_file.get_as_text())
			baseline_file.close()
		if not (baseline is Dictionary):
			_fail("baseline report unreadable: %s" % baseline_path)
			return
		# The tier policy's DIRECT effect is how many ordinary bodies keep
		# physics under pressure; step time only follows once bodies are the
		# bottleneck (the 500+ horde), not at this 120-actor workload. Gate on
		# the body reduction; report the per-step time delta alongside it.
		var baseline_bodies := float((baseline as Dictionary).get("ordinary_physics_enabled", 0.0))
		if baseline_bodies <= 0.0:
			_fail("baseline report has no ordinary_physics_enabled (wrong file?): %s" % baseline_path)
			return
		var candidate_bodies := float(report["ordinary_physics_enabled"])
		var improvement := 1.0 - candidate_bodies / baseline_bodies
		var metric := "physics_step_ms" if (baseline as Dictionary).has("physics_step_ms") else "physics_ms"
		var baseline_physics: Variant = (baseline as Dictionary).get(metric)
		var baseline_p95 := (
			float((baseline_physics as Dictionary).get("p95", 0.0)) if baseline_physics is Dictionary else 0.0
		)
		var candidate_p95 := float((report[metric] as Dictionary)["p95"])
		print(
			"EnemyPressureBenchmark: baseline ordinary bodies %d -> candidate %d (%.1f%% fewer, gate %.0f%%); %s p95 %.2f -> %.2f"
			% [int(baseline_bodies), int(candidate_bodies), improvement * 100.0, BASELINE_IMPROVEMENT_GATE * 100.0, metric, baseline_p95, candidate_p95]
		)
		if improvement < BASELINE_IMPROVEMENT_GATE:
			_fail("GATE FAILED: ordinary physics bodies reduced %.1f%% < %.0f%%" % [improvement * 100.0, BASELINE_IMPROVEMENT_GATE * 100.0])
			return
	print(
		"EnemyPressureBenchmark: enemies=%d mode=%s pressure_level=%s recorder=%s step_p95=%.2f physics_p95=%.2f frame_p95=%.2f physics_enabled=%s ordinary_physics=%s report=%s"
		% [
			ENEMY_COUNT,
			report["pressure_mode"],
			report["pressure_level"],
			"on" if _recorder_enabled else "off",
			float((report["physics_step_ms"] as Dictionary)["p95"]),
			float((report["physics_ms"] as Dictionary)["p95"]),
			float((report["frame_ms"] as Dictionary)["p95"]),
			counters.get("physics_enabled", "?"),
			report.get("ordinary_physics_enabled", "?"),
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
