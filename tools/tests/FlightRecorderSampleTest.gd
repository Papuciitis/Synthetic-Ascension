extends Node

# The flight recorder distinguishes wall-clock spacing from the engine's
# capped delta and from its windowed process/physics monitors, and carries
# the advancement tree's per-frame costs so a stall can be attributed.
#
# Run: <godot> --headless --path . res://tools/tests/FlightRecorderSampleTest.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")

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
	var player: Node2D = PLAYER_SCENE.instantiate()
	add_child(player)
	await get_tree().process_frame
	var was_enabled: bool = PerformanceFlightRecorder.enabled
	PerformanceFlightRecorder.enabled = true
	PerformanceFlightRecorder._process(0.016)
	await get_tree().create_timer(0.1).timeout
	PerformanceFlightRecorder._process(0.016)
	var history: Array = PerformanceFlightRecorder.get("_history")
	_check(history.size() >= 2, "two samples were ingested")
	var sample: Dictionary = history[history.size() - 1]
	var previous: Dictionary = history[history.size() - 2]
	_check(sample.has("wall_ms") and sample.has("delta_ms") and sample.has("frame_ms"), "a sample carries wall_ms, delta_ms and frame_ms")
	# The recorder also samples on its own each frame, so compare wall_ms with
	# the real spacing to the previous ingested sample rather than a fixed gap.
	var spacing_ms := float(int(sample["t_usec"]) - int(previous["t_usec"])) / 1000.0
	_check(absf(float(sample["wall_ms"]) - spacing_ms) < 1.0 and is_equal_approx(float(sample["delta_ms"]), 16.0), "wall spacing (%.2f ms) equals the real sample spacing (%.2f ms), not the 16 ms delta" % [float(sample["wall_ms"]), spacing_ms])
	_check(sample.has("ascension") and (sample["ascension"] as Dictionary).has("queued_attacks") and (sample["ascension"] as Dictionary).has("tick_usec"), "the tree's queue backlog and tick cost ride the sample")
	_check(sample.has("projectile_ms") and sample.has("chunk_stream"), "projectile time and chunk stream stats ride the sample")
	var summary: Dictionary = PerformanceFlightRecorder._build_summary(history, [])
	_check(summary.has("p95_wall_ms") and summary.has("monitor_note") and summary.has("peak_ascension_usec"), "the summary reports wall percentiles, the monitor caveat and the tree's peak cost")
	PerformanceFlightRecorder.enabled = was_enabled
	player.queue_free()
	print("FlightRecorderSampleTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
