extends Node

const ENEMY_ACTOR_SCRIPT := preload("res://core/actors/enemy/enemy.gd")

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_tooltip_input_and_placement()
	await _test_enemy_retirement_policy()
	await _test_canonical_enemy_retirement()
	_test_far_simulation_scheduler()
	await _test_performance_diagnostics()
	print("PerformanceLifecycleTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _test_tooltip_input_and_placement() -> void:
	var scene := load("res://ui/widgets/ItemTooltip.tscn") as PackedScene
	var tooltip := scene.instantiate() as ItemTooltip
	add_child(tooltip)
	await get_tree().process_frame
	_check(
		tooltip.has_method("make_subtree_mouse_transparent"),
		"tooltip exposes recursive input transparency"
	)
	_check(
		tooltip.has_method("place_beside"),
		"tooltip exposes source-aware placement"
	)
	if tooltip.has_method("make_subtree_mouse_transparent"):
		tooltip.call("make_subtree_mouse_transparent")
		_check(_all_controls_ignore_mouse(tooltip), "tooltip descendants ignore mouse input")
	if tooltip.has_method("place_beside"):
		tooltip.size = Vector2(460, 300)
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(1920, 1080))
		var source_left := Rect2(Vector2(100, 100), Vector2(44, 44))
		var right_pos: Vector2 = tooltip.call("place_beside", source_left, viewport_rect, 12.0)
		_check(right_pos.x >= source_left.end.x + 12.0, "tooltip prefers the source right side")
		_check(
			not Rect2(right_pos, tooltip.size).intersects(source_left),
			"tooltip does not cover a left-side hovered slot"
		)
		var source_right := Rect2(Vector2(1850, 1020), Vector2(44, 44))
		var left_pos: Vector2 = tooltip.call("place_beside", source_right, viewport_rect, 12.0)
		_check(left_pos.x + tooltip.size.x <= source_right.position.x - 12.0, "tooltip flips left at viewport edge")
		_check(
			left_pos.y >= viewport_rect.position.y + 8.0
			and left_pos.y + tooltip.size.y <= viewport_rect.end.y - 8.0,
			"tooltip remains vertically inside the viewport"
		)
	tooltip.queue_free()


func _all_controls_ignore_mouse(node: Node) -> bool:
	if node is Control and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in node.get_children():
		if not _all_controls_ignore_mouse(child):
			return false
	return true


func _policy_enemy(kind: StringName = &"") -> Node2D:
	var enemy := Node2D.new()
	if kind != &"":
		enemy.set_meta("special_spawn_kind", kind)
	add_child(enemy)
	return enemy


func _test_enemy_retirement_policy() -> void:
	var spawner := EnemySpawner.new()
	add_child(spawner)
	await get_tree().process_frame
	_check(
		spawner.has_method("is_enemy_cull_eligible"),
		"spawner exposes responsibility-aware culling policy"
	)
	if not spawner.has_method("is_enemy_cull_eligible"):
		spawner.queue_free()
		return
	var player_pos := Vector2.ZERO
	var ambient := _policy_enemy()
	ambient.position = Vector2(5000, 0)
	_check(spawner.call("is_enemy_cull_eligible", ambient, player_pos), "distant ambient enemy is cullable")
	var split := _policy_enemy(&"split")
	split.position = Vector2(5000, 0)
	_check(spawner.call("is_enemy_cull_eligible", split, player_pos), "distant splitter descendant is cullable")
	var interior := _policy_enemy(&"interior")
	interior.position = Vector2(5000, 0)
	interior.set_meta("interior_active", true)
	_check(not spawner.call("is_enemy_cull_eligible", interior, player_pos), "active interior enemy is protected")
	interior.set_meta("interior_active", false)
	_check(spawner.call("is_enemy_cull_eligible", interior, player_pos), "expired interior enemy is cullable")
	var boss := _policy_enemy()
	boss.add_to_group(&"boss_like")
	_check(not spawner.call("is_enemy_cull_eligible", boss, player_pos), "boss is protected")
	var summon := _policy_enemy(&"summon")
	_check(not spawner.call("is_enemy_cull_eligible", summon, player_pos), "lifetime-owned summon is protected")
	var sniper := _policy_enemy()
	sniper.set_meta("sniper_engagement_range", 1400.0)
	sniper.position = Vector2(1200, 0)
	_check(not spawner.call("is_enemy_cull_eligible", sniper, player_pos), "offscreen sniper in engagement range is protected")
	sniper.position = Vector2(3000, 0)
	sniper.set_meta("sniper_combat_committed", true)
	_check(not spawner.call("is_enemy_cull_eligible", sniper, player_pos), "committed sniper is protected at long range")
	sniper.set_meta("sniper_combat_committed", false)
	_check(spawner.call("is_enemy_cull_eligible", sniper, player_pos), "idle sniper beyond engagement range is cullable")
	for enemy in [ambient, split, interior, boss, summon, sniper]:
		enemy.queue_free()
	spawner.queue_free()


func _test_canonical_enemy_retirement() -> void:
	var index := get_node("/root/EnemyIndex")
	_check(index.has_method("retire_enemy"), "EnemyIndex exposes canonical retirement")
	if not index.has_method("retire_enemy"):
		return
	var enemy := Node2D.new()
	enemy.add_to_group(&"enemies")
	add_child(enemy)
	index.call("register", enemy)
	var before := int(index.call("alive_count"))
	var first := bool(index.call("retire_enemy", enemy, &"test"))
	var after := int(index.call("alive_count"))
	var second := bool(index.call("retire_enemy", enemy, &"test_repeat"))
	_check(first, "first enemy retirement succeeds")
	_check(after == before - 1, "retirement removes enemy from index immediately")
	_check(not second, "repeated retirement is idempotent")
	await get_tree().process_frame
	_check(not is_instance_valid(enemy), "retired enemy leaves the scene tree")


func _test_far_simulation_scheduler() -> void:
	# The self-driven far-step layer was dead code that tests kept alive while the
	# EnemySimulationScheduler group cadence did the real throttling. Assert it is
	# gone and the manager-driven contract is what remains.
	var enemy := ENEMY_ACTOR_SCRIPT.new.call() as EnemyActor
	_check(enemy.has_method("simulation_tier"), "enemy exposes simulation tier")
	_check(not enemy.has_method("should_run_far_step"), "legacy self-driven far-step scheduler is removed")
	_check(not enemy.has_method("consume_simulation_delta"), "legacy accumulated-delta API is removed")
	_check(enemy.has_method("run_scheduled_simulation"), "enemy exposes manager-driven simulation")
	_check(enemy.has_method("max_scheduler_tier"), "enemy exposes maximum demotion tier")
	enemy.free()


func _test_performance_diagnostics() -> void:
	var index := get_node("/root/EnemyIndex")
	_check(index.has_method("get_debug_counters"), "EnemyIndex exposes diagnostics")
	var spawner := EnemySpawner.new()
	add_child(spawner)
	_check(spawner.has_method("get_cull_counters"), "spawner exposes retirement counters")
	var chunk_manager := ChunkManager.new()
	add_child(chunk_manager)
	_check(chunk_manager.has_method("loaded_chunk_count"), "chunk manager exposes loaded count")
	var overlay_scene := load("res://ui/widgets/PerformanceOverlay.tscn") as PackedScene
	_check(overlay_scene != null, "performance overlay scene exists")
	if overlay_scene != null:
		var overlay := overlay_scene.instantiate()
		add_child(overlay)
		await get_tree().process_frame
		_check(overlay.has_method("collect_snapshot"), "performance overlay exposes snapshots")
		_check(overlay.has_method("format_compact"), "performance overlay exposes compact formatting")
		_check(overlay.has_method("format_details"), "performance overlay exposes detailed formatting")
		_check(overlay.has_method("default_safe_rect"), "performance overlay exposes safe default placement")
		if overlay.has_method("collect_snapshot"):
			var snapshot := overlay.call("collect_snapshot") as Dictionary
			for key in ["fps", "nodes", "physics_objects", "indexed_enemies", "projectiles", "loaded_chunks"]:
				_check(snapshot.has(key), "performance snapshot includes %s" % key)
			if overlay.has_method("format_compact"):
				var compact := String(overlay.call("format_compact", snapshot))
				_check(compact.contains("FPS") and compact.contains("FLOW"), "compact overlay prioritizes frame and flow state")
				_check(not compact.contains("{"), "compact overlay does not render raw dictionaries")
			if overlay.has_method("default_safe_rect"):
				var safe_rect := overlay.call("default_safe_rect", Vector2(1920, 1080)) as Rect2
				_check(safe_rect.position.x >= 8.0, "default console stays inside the left viewport edge")
				_check(safe_rect.end.x <= 1912.0, "default console stays inside the right viewport edge")
		overlay.queue_free()
	chunk_manager.queue_free()
	spawner.queue_free()
