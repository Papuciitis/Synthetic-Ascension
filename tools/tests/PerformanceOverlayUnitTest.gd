extends SceneTree

var _passes := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var scene := load("res://ui/widgets/PerformanceOverlay.tscn") as PackedScene
	_check(scene != null, "overlay scene loads")
	if scene == null:
		_finish()
		return
	var overlay := scene.instantiate()
	root.add_child(overlay)
	await process_frame
	_check(overlay.has_method("format_compact"), "overlay provides compact output")
	_check(overlay.has_method("format_details"), "overlay provides detailed output")
	var snapshot := {
		"fps": 60.0, "process_ms": 4.0, "physics_ms": 3.0,
		"indexed_enemies": 180, "tiers": {"near": 40, "mid": 60, "far": 80},
		"projectiles": 500, "projectile_ms": 1.2,
		"flow": {"last_request_reason": &"nav_revision", "completed": 2, "last_cpu_us": 850},
	}
	var compact := String(overlay.call("format_compact", snapshot))
	_check(compact.contains("FPS") and compact.contains("FLOW"), "compact output prioritizes FPS and flow")
	_check(not compact.contains("{"), "compact output contains no raw dictionaries")
	var safe := overlay.call("default_safe_rect", Vector2(1920, 1080)) as Rect2
	_check(safe.position.x >= 8.0 and safe.end.x <= 1912.0, "console fits the viewport horizontally")
	_check(safe.position.y >= 8.0 and safe.end.y <= 1072.0, "console fits the viewport vertically")
	_check(overlay.has_node("Margin/Root/Tabs/Performance/Content/RecorderTitle"), "console includes flight recorder title")
	_check(overlay.has_node("Margin/Root/Tabs/Performance/Content/RecorderControls/Enabled"), "console includes recorder enable control")
	_check(overlay.has_node("Margin/Root/Tabs/Performance/Content/RecorderActions/Mark"), "console includes manual incident control")
	_check(overlay.has_node("Margin/Root/Tabs/Performance/Content/RecorderStatus"), "console includes recorder status")
	var spawn_filter := root.get_node_or_null("/root/DebugEnemySpawnFilter")
	_check(spawn_filter != null, "spawn filter autoload is available")
	if spawn_filter != null:
		spawn_filter.set("cap_mode", 0)
		overlay.call("_set_total_cap", 360.0)
		_check(
			int(spawn_filter.get("cap_mode")) == 1 and int(spawn_filter.get("custom_total_cap")) == 360,
			"typing a total cap applies it by switching to custom mode"
		)
		spawn_filter.set("cap_mode", 0)
		spawn_filter.set("custom_total_cap", 180)
	overlay.queue_free()
	_finish()


func _finish() -> void:
	print("PerformanceOverlayUnitTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
