extends PanelContainer
class_name PerformanceOverlay

@export var refresh_interval := 0.5

const RESIZE_LEFT := 1
const RESIZE_RIGHT := 2
const RESIZE_TOP := 4
const RESIZE_BOTTOM := 8
const RESIZE_MARGIN := 10.0
const MIN_CONSOLE_SIZE := Vector2(720.0, 480.0)

@onready var _header: Control = $Margin/Root/Header
@onready var _compact_label: Label = $Margin/Root/Tabs/Overview/Content/Compact
@onready var _frame_label: Label = $Margin/Root/Tabs/Overview/Content/Frame
@onready var _world_label: Label = $Margin/Root/Tabs/Overview/Content/World
@onready var _flow_label: Label = $Margin/Root/Tabs/Overview/Content/Flow
@onready var _recorder_enabled: CheckBox = $Margin/Root/Tabs/Performance/Content/RecorderControls/Enabled
@onready var _recorder_automatic: CheckBox = $Margin/Root/Tabs/Performance/Content/RecorderControls/Automatic
@onready var _recorder_threshold: SpinBox = $Margin/Root/Tabs/Performance/Content/RecorderControls/Threshold
@onready var _recorder_relative: SpinBox = $Margin/Root/Tabs/Performance/Content/RecorderControls/Relative
@onready var _recorder_status: Label = $Margin/Root/Tabs/Performance/Content/RecorderStatus
@onready var _projectile_stress: CheckBox = $Margin/Root/Tabs/Performance/Content/ProjectileStress
@onready var _god_mode: CheckBox = $Margin/Root/Tabs/Performance/Content/GodMode
@onready var _batched_sprites: CheckBox = $Margin/Root/Tabs/Performance/Content/BatchedSprites
@onready var _master_spawns: CheckBox = $Margin/Root/Tabs/Enemies/Content/SpawnToolbar/Master
@onready var _protected_filter: CheckBox = $Margin/Root/Tabs/Enemies/Content/SpawnToolbar/Protected
@onready var _force_spawn_result: Label = $Margin/Root/Tabs/Enemies/Content/ForceSpawnRow/Result
@onready var _pause_game: CheckBox = $Margin/Root/Footer/PauseGame
@onready var _cap_mode: OptionButton = $Margin/Root/Tabs/Enemies/Content/CapRow/Mode
@onready var _total_cap: SpinBox = $Margin/Root/Tabs/Enemies/Content/CapRow/TotalCap
@onready var _enemy_list: VBoxContainer = $Margin/Root/Tabs/Enemies/Content/EnemyScroll/EnemyList

var _refresh_left := 0.0
var _dragging := false
var _drag_offset := Vector2.ZERO
var _resizing := false
var _resize_edges := 0
var _resize_start_rect := Rect2()
var _resize_pointer_start := Vector2.ZERO
var _rendered_ids: Array[StringName] = []
var _row_controls: Dictionary = {}
var _updating_controls := false
var _confirm_action: StringName = &""
var _confirm_until_msec := 0


func _ready() -> void:
	add_to_group(&"performance_overlay")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_cap_mode.add_item("Production", 0)
	_cap_mode.add_item("Custom", 1)
	_cap_mode.add_item("Unlimited", 2)
	$Margin/Root/Header/Close.pressed.connect(func() -> void: visible = false)
	$Margin/Root/Footer/Close.pressed.connect(func() -> void: visible = false)
	$Margin/Root/Footer/MainMenu.pressed.connect(request_main_menu)
	$Margin/Root/Footer/ExitGame.pressed.connect(request_exit_game)
	$Margin/Root/Tabs/Enemies/Content/SpawnToolbar/EnableAll.pressed.connect(_enable_all)
	$Margin/Root/Tabs/Enemies/Content/SpawnToolbar/DisableAll.pressed.connect(_disable_all)
	$Margin/Root/Tabs/Enemies/Content/ForceSpawnRow/Spawn1.pressed.connect(_force_spawn.bind(1))
	$Margin/Root/Tabs/Enemies/Content/ForceSpawnRow/Spawn10.pressed.connect(_force_spawn.bind(10))
	$Margin/Root/Tabs/Enemies/Content/ForceSpawnRow/Spawn100.pressed.connect(_force_spawn.bind(100))
	_master_spawns.toggled.connect(_set_master_spawning)
	_protected_filter.toggled.connect(_set_protected_filtering)
	_cap_mode.item_selected.connect(_set_cap_mode)
	_total_cap.value_changed.connect(_set_total_cap)
	_recorder_enabled.toggled.connect(_set_recorder_enabled)
	_recorder_automatic.toggled.connect(_configure_recorder)
	_recorder_threshold.value_changed.connect(func(_value: float) -> void: _configure_recorder())
	_recorder_relative.value_changed.connect(func(_value: float) -> void: _configure_recorder())
	$Margin/Root/Tabs/Performance/Content/RecorderActions/Mark.pressed.connect(_mark_incident)
	$Margin/Root/Tabs/Performance/Content/RecorderActions/Clear.pressed.connect(_clear_recorder)
	_projectile_stress.toggled.connect(_set_projectile_stress)
	_god_mode.toggled.connect(_set_god_mode)
	_batched_sprites.toggled.connect(_set_batched_sprites)
	_pause_game.toggled.connect(_set_game_paused)
	_header.gui_input.connect(_on_header_input)
	_build_tests_tab()
	call_deferred("_place_default")


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_left -= delta
	if _refresh_left > 0.0:
		return
	_refresh_left = maxf(0.1, refresh_interval)
	_render_snapshot(collect_snapshot())


func _input(event: InputEvent) -> void:
	# Dev console (god mode, force spawn, spawn kill-switch): debug builds only.
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_QUOTELEFT:
		toggle_overlay()
		get_viewport().set_input_as_handled()
	elif blocks_wasd_ui_navigation(event):
		# Player movement polls the action state directly, so handling this event
		# prevents Control focus navigation without interrupting gameplay movement.
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed(&"ui_cancel"):
		visible = false
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var edges := resize_edges_at(event.position - global_position, size)
			if edges != 0:
				_resizing = true
				_resize_edges = edges
				_resize_start_rect = Rect2(position, size)
				_resize_pointer_start = event.position
				_dragging = false
				get_viewport().set_input_as_handled()
		elif _resizing:
			_resizing = false
			_resize_edges = 0
			get_viewport().set_input_as_handled()
	elif visible and event is InputEventMouseMotion:
		if _resizing:
			var rect := resized_rect(
				_resize_start_rect,
				_resize_edges,
				event.position - _resize_pointer_start,
				get_viewport_rect().size
			)
			position = rect.position
			size = rect.size
			get_viewport().set_input_as_handled()
		else:
			Input.set_default_cursor_shape(_cursor_for_edges(
				resize_edges_at(event.position - global_position, size)
			))


func blocks_wasd_ui_navigation(event: InputEvent) -> bool:
	if not visible or not event is InputEventKey or not event.pressed:
		return false
	var key_event := event as InputEventKey
	var physical_key := key_event.physical_keycode
	if physical_key == 0:
		physical_key = key_event.keycode
	return physical_key in [KEY_W, KEY_A, KEY_S, KEY_D]


func toggle_overlay() -> void:
	if Global == null or not Global.debug_dev_mode:
		return
	visible = not visible
	_refresh_left = 0.0
	if not visible:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func default_safe_rect(viewport_size: Vector2) -> Rect2:
	var available := Vector2(maxf(320.0, viewport_size.x - 48.0), maxf(260.0, viewport_size.y - 48.0))
	var panel_size := Vector2(
		clampf(viewport_size.x * 0.70, minf(MIN_CONSOLE_SIZE.x, available.x), available.x),
		clampf(viewport_size.y * 0.72, minf(MIN_CONSOLE_SIZE.y, available.y), available.y)
	)
	return Rect2((viewport_size - panel_size) * 0.5, panel_size)


func resize_edges_at(local_position: Vector2, panel_size: Vector2) -> int:
	if local_position.x < -RESIZE_MARGIN or local_position.y < -RESIZE_MARGIN:
		return 0
	if local_position.x > panel_size.x + RESIZE_MARGIN or local_position.y > panel_size.y + RESIZE_MARGIN:
		return 0
	var edges := 0
	if local_position.x <= RESIZE_MARGIN:
		edges |= RESIZE_LEFT
	elif local_position.x >= panel_size.x - RESIZE_MARGIN:
		edges |= RESIZE_RIGHT
	if local_position.y <= RESIZE_MARGIN:
		edges |= RESIZE_TOP
	elif local_position.y >= panel_size.y - RESIZE_MARGIN:
		edges |= RESIZE_BOTTOM
	return edges


func resized_rect(start_rect: Rect2, edge_mask: int, drag_delta: Vector2, viewport_size: Vector2) -> Rect2:
	var left := start_rect.position.x
	var top := start_rect.position.y
	var right := start_rect.end.x
	var bottom := start_rect.end.y
	var min_width := minf(MIN_CONSOLE_SIZE.x, viewport_size.x)
	var min_height := minf(MIN_CONSOLE_SIZE.y, viewport_size.y)
	if edge_mask & RESIZE_LEFT:
		left = clampf(left + drag_delta.x, 0.0, right - min_width)
	if edge_mask & RESIZE_RIGHT:
		right = clampf(right + drag_delta.x, left + min_width, viewport_size.x)
	if edge_mask & RESIZE_TOP:
		top = clampf(top + drag_delta.y, 0.0, bottom - min_height)
	if edge_mask & RESIZE_BOTTOM:
		bottom = clampf(bottom + drag_delta.y, top + min_height, viewport_size.y)
	return Rect2(left, top, right - left, bottom - top)


func _cursor_for_edges(edges: int) -> Input.CursorShape:
	if edges in [RESIZE_LEFT, RESIZE_RIGHT]:
		return Input.CURSOR_HSIZE
	if edges in [RESIZE_TOP, RESIZE_BOTTOM]:
		return Input.CURSOR_VSIZE
	if edges in [RESIZE_LEFT | RESIZE_TOP, RESIZE_RIGHT | RESIZE_BOTTOM]:
		return Input.CURSOR_FDIAGSIZE
	if edges in [RESIZE_RIGHT | RESIZE_TOP, RESIZE_LEFT | RESIZE_BOTTOM]:
		return Input.CURSOR_BDIAGSIZE
	return Input.CURSOR_ARROW


func collect_snapshot() -> Dictionary:
	var enemy_index := get_node_or_null("/root/EnemyIndex")
	var enemy_counters := _call_dict(enemy_index, &"get_debug_counters")
	var projectile_manager := get_node_or_null("/root/ProjectileManager")
	var projectile_counters := _call_dict(projectile_manager, &"get_debug_counters")
	var chunk_manager := get_tree().get_first_node_in_group(&"chunk_manager")
	var chunk_nav := _call_dict(chunk_manager, &"get_nav_debug_counters")
	var loaded_chunks := int(chunk_manager.call("loaded_chunk_count")) if chunk_manager != null and chunk_manager.has_method("loaded_chunk_count") else 0
	var chunk_stream := _call_dict(chunk_manager, &"get_chunk_stream_debug_stats")
	var chunk_blocks := _call_dict(chunk_manager, &"get_block_batch_stats")
	var authored_tiles := _call_dict(chunk_manager, &"get_authored_tiled_render_stats")
	var spawner := get_tree().get_first_node_in_group(&"enemy_spawner")
	var culled := _call_dict(spawner, &"get_cull_counters")
	var flow := get_tree().get_first_node_in_group(&"flow_field_nav")
	var flow_counters := _call_dict(flow, &"get_debug_counters")
	var spawn_filter := get_node_or_null("/root/DebugEnemySpawnFilter")
	var filter_snapshot := _call_dict(spawn_filter, &"get_debug_snapshot")
	var enemy_world := get_node_or_null("/root/EnemyWorld")
	var world_counters := _call_dict(enemy_world, &"get_debug_counters")
	return {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"rendered_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"physics_objects": Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS),
		"scene_enemies": get_tree().get_node_count_in_group(&"enemies"),
		"indexed_enemies": int(enemy_counters.get("indexed", 0)),
		"world_logical": int(world_counters.get("logical", 0)),
		"world_materialized": int(world_counters.get("materialized", 0)),
		"world_data_only": int(world_counters.get("data_only", 0)),
		"ambient": int(enemy_counters.get("ambient", 0)),
		"special": int(enemy_counters.get("special", 0)),
		"special_by_kind": enemy_counters.get("special_by_kind", {}),
		"tiers": enemy_counters.get("tiers", {}),
		"culled": culled,
		"projectiles": int(projectile_counters.get("active", 0)),
		"projectile_ms": float(projectile_counters.get("physics_ms", 0.0)),
		"projectile_hits": int(projectile_counters.get("hits", 0)),
		"loaded_chunks": loaded_chunks,
		"chunk_stream": chunk_stream,
		"chunk_blocks": chunk_blocks,
		"authored_tiles": authored_tiles,
		"flow": flow_counters,
		"chunk_nav": chunk_nav,
		"spawn_filter": filter_snapshot,
	}


func format_compact(snapshot: Dictionary) -> String:
	var tiers := snapshot.get("tiers", {}) as Dictionary
	var flow := snapshot.get("flow", {}) as Dictionary
	return (
		"FPS %3.0f   FRAME %5.2f ms   PHYS %5.2f ms\n"
		+ "ENEMIES %d (%d real + %d proxy)  near/mid/far %d/%d/%d   BULLETS %d (%4.2f ms)\n"
		+ "FLOW %s  rebuilds %d  last %4.2f ms"
	) % [
		float(snapshot.get("fps", 0.0)),
		float(snapshot.get("process_ms", 0.0)),
		float(snapshot.get("physics_ms", 0.0)),
		maxi(int(snapshot.get("world_logical", 0)), int(snapshot.get("indexed_enemies", 0))),
		int(snapshot.get("indexed_enemies", 0)),
		int(snapshot.get("world_data_only", 0)),
		int(tiers.get("near", 0)),
		int(tiers.get("mid", 0)),
		int(tiers.get("far", 0)),
		int(snapshot.get("projectiles", 0)),
		float(snapshot.get("projectile_ms", 0.0)),
		String(flow.get("last_request_reason", &"idle")),
		int(flow.get("completed", 0)),
		float(flow.get("last_cpu_us", 0)) / 1000.0,
	]


func format_details(snapshot: Dictionary) -> Dictionary:
	var flow := snapshot.get("flow", {}) as Dictionary
	var chunk_nav := snapshot.get("chunk_nav", {}) as Dictionary
	var frame := (
		"FRAME\nFPS %.0f  process %.2f ms  physics %.2f ms\n"
		+ "draws %d  rendered %d  nodes %d  physics objects %d"
	) % [
		float(snapshot.get("fps", 0.0)),
		float(snapshot.get("process_ms", 0.0)),
		float(snapshot.get("physics_ms", 0.0)),
		int(snapshot.get("draw_calls", 0)),
		int(snapshot.get("rendered_objects", 0)),
		int(snapshot.get("nodes", 0)),
		int(snapshot.get("physics_objects", 0)),
	]
	var tiers := snapshot.get("tiers", {}) as Dictionary
	var chunk_stream := snapshot.get("chunk_stream", {}) as Dictionary
	var chunk_blocks := snapshot.get("chunk_blocks", {}) as Dictionary
	var authored_tiles := snapshot.get("authored_tiles", {}) as Dictionary
	var world := (
		"WORLD\nEnemies %d (ambient %d, special %d)  tiers %d/%d/%d\n"
		+ "Projectiles %d, %.3f ms, hits %d  chunks %d\n"
		+ "Stream queue %d, oldest %.2f ms, last/median %.2f/%.2f ms, budget %.2f ms\n"
		+ "Chunk blockers %d instances, bodies/shapes %d/%d, batches %d\n"
		+ "Authored tiles %d cells across %d layers"
	) % [
		int(snapshot.get("indexed_enemies", 0)),
		int(snapshot.get("ambient", 0)),
		int(snapshot.get("special", 0)),
		int(tiers.get("near", 0)),
		int(tiers.get("mid", 0)),
		int(tiers.get("far", 0)),
		int(snapshot.get("projectiles", 0)),
		float(snapshot.get("projectile_ms", 0.0)),
		int(snapshot.get("projectile_hits", 0)),
		int(snapshot.get("loaded_chunks", 0)),
		int(chunk_stream.get("queue_length", 0)),
		float(chunk_stream.get("oldest_request_ms", 0.0)),
		float(chunk_stream.get("last_build_ms", 0.0)),
		float(chunk_stream.get("median_build_ms", 0.0)),
		float(chunk_stream.get("activation_budget_ms", 0.0)),
		int(chunk_blocks.get("instances", 0)),
		int(chunk_blocks.get("bodies", 0)),
		int(chunk_blocks.get("shapes", 0)),
		int(chunk_blocks.get("batches", 0)),
		int(authored_tiles.get("cells", 0)),
		int(authored_tiles.get("layers", 0)),
	]
	var flow_text := (
		"FLOW\nreason %s  requested/started/completed %d/%d/%d  superseded %d\n"
		+ "last %d cells, %.3f ms  revision %d (pending %s)\n"
		+ "world invalidations %d requests → %d commits; latest %s\n"
		+ "causes %s"
	) % [
		String(flow.get("last_request_reason", &"idle")),
		int(flow.get("requested", 0)),
		int(flow.get("started", 0)),
		int(flow.get("completed", 0)),
		int(flow.get("superseded", 0)),
		int(flow.get("last_cells", 0)),
		float(flow.get("last_cpu_us", 0)) / 1000.0,
		int(flow.get("last_revision", -1)),
		"yes" if bool(flow.get("pending", false)) else "no",
		int(chunk_nav.get("requests", 0)),
		int(chunk_nav.get("commits", 0)),
		String(chunk_nav.get("last_reason", &"none")),
		_format_counts(chunk_nav.get("reasons", {}) as Dictionary),
	]
	return {"frame": frame, "world": world, "flow": flow_text}


func _render_snapshot(snapshot: Dictionary) -> void:
	_compact_label.text = format_compact(snapshot)
	var detail_text := format_details(snapshot)
	_frame_label.text = String(detail_text.frame)
	_world_label.text = String(detail_text.world)
	_flow_label.text = String(detail_text.flow)
	_sync_recorder_status()
	_sync_spawn_controls(snapshot.get("spawn_filter", {}) as Dictionary)
	if not _updating_controls:
		_updating_controls = true
		_projectile_stress.button_pressed = Global != null and Global.debug_projectile_stress_test
		_god_mode.button_pressed = Global != null and Global.debug_player_god_mode
		_batched_sprites.button_pressed = Global != null and Global.debug_enemy_visual_batching
		_pause_game.button_pressed = get_tree().paused
		_updating_controls = false


func _sync_recorder_status() -> void:
	var recorder := get_node_or_null("/root/PerformanceFlightRecorder")
	if recorder == null or not recorder.has_method("get_status_snapshot"):
		_recorder_status.text = "Recorder unavailable"
		return
	var status := recorder.call("get_status_snapshot") as Dictionary
	_updating_controls = true
	_recorder_enabled.button_pressed = bool(status.get("enabled", false))
	_recorder_automatic.button_pressed = bool(status.get("automatic_capture", true))
	_updating_controls = false
	var summary := status.get("latest_summary", {}) as Dictionary
	var report := String(status.get("latest_report_path", ""))
	var report_display := ProjectSettings.globalize_path(report) if report != "" else "not written yet"
	_recorder_status.text = (
		"State: %s | incidents: %d | baseline: %.2f ms | recorder: %d µs\n"
		+ "Latest worst/p95: %.2f / %.2f ms | report: %s"
	) % [
		String(status.get("state", "disabled")),
		int(status.get("incident_count", 0)),
		float(status.get("baseline_ms", 0.0)),
		int(status.get("sampling_overhead_usec", 0)),
		float(summary.get("worst_frame_ms", 0.0)),
		float(summary.get("p95_frame_ms", 0.0)),
		report_display,
	]
	var error := String(status.get("latest_error", ""))
	if error != "":
		_recorder_status.text += "\nWrite error: " + error


func _set_recorder_enabled(value: bool) -> void:
	if _updating_controls:
		return
	PerformanceFlightRecorder.set_enabled(value)


func _configure_recorder(_unused: Variant = null) -> void:
	if _updating_controls:
		return
	PerformanceFlightRecorder.configure({
		"automatic_capture": _recorder_automatic.button_pressed,
		"absolute_threshold_ms": _recorder_threshold.value,
		"relative_multiplier": _recorder_relative.value,
	})


func _mark_incident() -> void:
	if not PerformanceFlightRecorder.enabled:
		PerformanceFlightRecorder.set_enabled(true)
	PerformanceFlightRecorder.mark_incident(&"manual")


func _clear_recorder() -> void:
	PerformanceFlightRecorder.clear_session()


func _sync_spawn_controls(filter_snapshot: Dictionary) -> void:
	var ids: Array[StringName] = []
	for value: Variant in filter_snapshot.get("known_ids", []):
		ids.append(StringName(value))
	if ids != _rendered_ids:
		_build_enemy_rows(ids)
	var enabled := filter_snapshot.get("enabled", {}) as Dictionary
	var live := filter_snapshot.get("live_counts", {}) as Dictionary
	var spawned := filter_snapshot.get("spawn_counts", {}) as Dictionary
	var type_caps := filter_snapshot.get("custom_type_caps", {}) as Dictionary
	_updating_controls = true
	_cap_mode.select(int(filter_snapshot.get("cap_mode", 0)))
	_total_cap.value = int(filter_snapshot.get("custom_total_cap", 180))
	_protected_filter.button_pressed = bool(filter_snapshot.get("protected_filtering", false))
	_master_spawns.button_pressed = bool(filter_snapshot.get("spawning_enabled", true))
	for enemy_id in ids:
		var row := _row_controls.get(enemy_id, {}) as Dictionary
		(row.get("enabled") as CheckBox).button_pressed = bool(enabled.get(enemy_id, true))
		(row.get("count") as Label).text = "live %d / spawned %d" % [int(live.get(enemy_id, 0)), int(spawned.get(enemy_id, 0))]
		(row.get("cap") as SpinBox).value = int(type_caps.get(enemy_id, 0))
	_updating_controls = false


func _build_enemy_rows(ids: Array[StringName]) -> void:
	for child in _enemy_list.get_children():
		child.queue_free()
	_row_controls.clear()
	_rendered_ids = ids.duplicate()
	for enemy_id in ids:
		var row := HBoxContainer.new()
		var enabled := CheckBox.new()
		enabled.text = String(enemy_id).trim_prefix("enemy_")
		enabled.custom_minimum_size.x = 150.0
		enabled.toggled.connect(func(value: bool) -> void:
			if not _updating_controls:
				DebugEnemySpawnFilter.set_enemy_enabled(enemy_id, value)
		)
		var count := Label.new()
		count.custom_minimum_size.x = 160.0
		var only := Button.new()
		only.text = "Only"
		only.pressed.connect(func() -> void: DebugEnemySpawnFilter.isolate_enemy(enemy_id))
		var cap := SpinBox.new()
		cap.min_value = 0
		cap.max_value = 5000
		cap.custom_minimum_size.x = 82.0
		cap.tooltip_text = "Custom per-type cap; 0 = unlimited"
		cap.value_changed.connect(func(value: float) -> void:
			if not _updating_controls:
				DebugEnemySpawnFilter.set_custom_type_cap(enemy_id, int(value))
		)
		row.add_child(enabled)
		row.add_child(count)
		row.add_child(only)
		row.add_child(cap)
		_enemy_list.add_child(row)
		_row_controls[enemy_id] = {"enabled": enabled, "count": count, "cap": cap}


func _place_default() -> void:
	var rect := default_safe_rect(get_viewport_rect().size)
	position = rect.position
	size = rect.size


func _on_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_drag_offset = get_global_mouse_position() - global_position
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() - _drag_offset
		_clamp_to_viewport()
		accept_event()


func _clamp_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	position.x = clampf(position.x, 8.0, maxf(8.0, viewport_size.x - size.x - 8.0))
	position.y = clampf(position.y, 8.0, maxf(8.0, viewport_size.y - size.y - 8.0))


func _force_spawn(count: int) -> void:
	var spawner := get_tree().get_first_node_in_group(&"enemy_spawner")
	if spawner == null or not spawner.has_method("debug_force_spawn"):
		_force_spawn_result.text = "no spawner in scene"
		return
	var result := spawner.call("debug_force_spawn", count) as Dictionary
	var spawned := int(result.get("spawned", 0))
	var alive := int(result.get("alive", 0))
	var pending := int(result.get("pending", 0))
	var cap := int(result.get("cap", 0))
	if spawned >= count:
		_force_spawn_result.text = "spawned +%d (alive %d)" % [spawned, alive]
	elif cap > 0 and alive + pending >= cap:
		_force_spawn_result.text = (
			"at cap %d/%d — set Population caps to Custom or Unlimited"
			% [alive, cap]
		)
	elif spawned == 0:
		_force_spawn_result.text = "+0 — blocked by spawn filters or no valid spawn position"
	else:
		_force_spawn_result.text = "spawned +%d, then hit cap %d/%d" % [spawned, alive, cap]


func _enable_all() -> void:
	DebugEnemySpawnFilter.enable_all()


func _disable_all() -> void:
	DebugEnemySpawnFilter.disable_all()


func _set_master_spawning(value: bool) -> void:
	if _updating_controls:
		return
	DebugEnemySpawnFilter.spawning_enabled = value
	for spawner in get_tree().get_nodes_in_group(&"enemy_spawner"):
		if spawner.has_method("set_spawning_enabled"):
			spawner.call("set_spawning_enabled", value)


func _set_protected_filtering(value: bool) -> void:
	if not _updating_controls:
		DebugEnemySpawnFilter.filter_protected_actors = value


func _set_cap_mode(index: int) -> void:
	if not _updating_controls:
		DebugEnemySpawnFilter.cap_mode = index as DebugEnemySpawnFilter.CapMode


func _set_total_cap(value: float) -> void:
	if not _updating_controls:
		DebugEnemySpawnFilter.custom_total_cap = int(value)
		# Typing a cap means the user wants it applied: entering a value while
		# Production mode was selected used to be silently ignored.
		if DebugEnemySpawnFilter.cap_mode != DebugEnemySpawnFilter.CapMode.CUSTOM:
			DebugEnemySpawnFilter.cap_mode = DebugEnemySpawnFilter.CapMode.CUSTOM


func _call_dict(target: Node, method: StringName) -> Dictionary:
	if target != null and target.has_method(method):
		return target.call(method) as Dictionary
	return {}


func _format_counts(counts: Dictionary) -> String:
	if counts.is_empty():
		return "none"
	var keys := counts.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for key: Variant in keys:
		parts.append("%s:%d" % [String(key), int(counts[key])])
	return ", ".join(parts)


func _set_projectile_stress(value: bool) -> void:
	if not _updating_controls and Global != null:
		Global.debug_projectile_stress_test = value


func _set_god_mode(value: bool) -> void:
	if not _updating_controls and Global != null:
		Global.debug_player_god_mode = value


func _set_batched_sprites(value: bool) -> void:
	if not _updating_controls and Global != null:
		Global.debug_enemy_visual_batching = value


func _set_game_paused(value: bool) -> void:
	# Dev freeze: everything halts (the scheduler is pausable now), the
	# overlay itself keeps processing, so state can be inspected from the
	# editor remote tree and resumed from here.
	if not _updating_controls:
		get_tree().paused = value


func request_main_menu() -> void:
	if not _confirm(&"menu", $Margin/Root/Footer/MainMenu, "Confirm Main Menu"):
		return
	get_tree().paused = false
	if Global != null:
		Global.debug_projectile_stress_test = false
		Global.save_current_profile()
		Global.call_deferred("goto_main_menu")


func request_exit_game() -> void:
	if not _confirm(&"exit", $Margin/Root/Footer/ExitGame, "Confirm Exit"):
		return
	get_tree().paused = false
	if Global != null:
		Global.save_current_profile()
	get_tree().quit()


func _confirm(action: StringName, button: Button, confirmation_text: String) -> bool:
	var now := Time.get_ticks_msec()
	if _confirm_action == action and now <= _confirm_until_msec:
		_confirm_action = &""
		return true
	_confirm_action = action
	_confirm_until_msec = now + 3000
	button.text = confirmation_text
	get_tree().create_timer(3.1, true, false, true).timeout.connect(func() -> void:
		if _confirm_action == action:
			_confirm_action = &""
			button.text = "Main Menu" if action == &"menu" else "Exit Game"
	)
	return false


# =============================================================================
# The Tests tab
# =============================================================================
#
# This used to be one flat column of about forty buttons in a single scroll -
# sets, combat state, six opening phases, four opening responses, three segment
# jumps and two loose test actions, in one undifferentiated stack. Finding
# anything meant reading every label, and pressing something gave no indication
# that it had worked, so the honest workflow was "click it twice and hope".
#
# Three changes fix all of that:
#
#   1. Sub-tabs by INTENT (Run / Gear / Rules / Story / World), so you go to the
#      part of the game you are testing rather than scanning a list.
#   2. A live state strip. Every one of these buttons exists to change run
#      state, so the run state has to be on screen next to them - otherwise you
#      cannot tell a button that did nothing from a button that did nothing
#      VISIBLE.
#   3. An action log. One line per press, newest first, so a button that fires
#      into a system with no visual output still says so.
#
# Built in code rather than in the scene because these are lists: the
# manifestation picker is generated from the catalog, and a scene file would
# have to be re-authored by hand every time a rule is added.

const _LOG_LINES: int = 6

var _dev_log: Label = null
var _dev_state: Label = null
var _dev_log_entries: PackedStringArray = PackedStringArray()
var _dev_manifest_picker: OptionButton = null
var _dev_item_id: LineEdit = null


func _build_tests_tab() -> void:
	var host := get_node_or_null("Margin/Root/Tabs/Tests") as MarginContainer
	if host == null:
		return
	for child in host.get_children():
		child.queue_free()

	var column := VBoxContainer.new()
	column.name = "DevRoot"
	column.add_theme_constant_override("separation", 6)
	host.add_child(column)

	_dev_state = Label.new()
	_dev_state.name = "StateStrip"
	_dev_state.add_theme_font_size_override("font_size", 15)
	_dev_state.add_theme_color_override("font_color", Color(0.62, 0.86, 0.98))
	_dev_state.text = "—"
	column.add_child(_dev_state)

	var tools := get_node_or_null("/root/DevSetCollisionTools")
	var tabs := TabContainer.new()
	tabs.name = "TestTabs"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)

	_build_run_tab(_tests_page(tabs, "Run"), tools)
	_build_gear_tab(_tests_page(tabs, "Gear"), tools)
	_build_rules_tab(_tests_page(tabs, "Rules"), tools)
	_build_story_tab(_tests_page(tabs, "Story"), tools)
	_build_world_tab(_tests_page(tabs, "World"), tools)

	_dev_log = Label.new()
	_dev_log.name = "ActionLog"
	_dev_log.add_theme_font_size_override("font_size", 13)
	_dev_log.add_theme_color_override("font_color", Color(0.72, 0.72, 0.66))
	_dev_log.custom_minimum_size.y = 92.0
	_dev_log.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_dev_log.text = "Ready."
	column.add_child(_dev_log)

	_refresh_dev_state()


## One scrolling page per sub-tab, so a long list scrolls instead of clipping.
func _tests_page(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 6)
	scroll.add_child(page)
	return page


func _dev_heading(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.95, 0.80, 0.42))
	parent.add_child(label)


func _dev_row(parent: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	return row


## Every dev button logs. A tool that changes state silently is a tool you
## cannot trust, and half of these fire into systems with no on-screen result.
func _dev_button(parent: Control, text: String, note: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void:
		action.call()
		_dev_note(note)
	)
	parent.add_child(button)
	return button


func _dev_note(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	var stamp: float = float(Time.get_ticks_msec()) / 1000.0
	_dev_log_entries.insert(0, "[%6.1fs] %s" % [stamp, text])
	while _dev_log_entries.size() > _LOG_LINES:
		_dev_log_entries.remove_at(_dev_log_entries.size() - 1)
	if _dev_log != null and is_instance_valid(_dev_log):
		_dev_log.text = "\n".join(_dev_log_entries)
	_refresh_dev_state()


## The whole point of the strip: the numbers these buttons move, on screen.
func _refresh_dev_state() -> void:
	if _dev_state == null or not is_instance_valid(_dev_state):
		return
	var parts: PackedStringArray = PackedStringArray()
	if Global != null:
		parts.append("SEG %d" % int(Global.attempt_segment))
		parts.append("FOLLOWERS %d" % int(Global.followers))
		parts.append("LUCK %.2f" % float(Global.run_luck))
	var threat := get_node_or_null("/root/ThreatDirector")
	if threat != null:
		parts.append("THREAT %.1f" % float(threat.get("threat")))
		if bool(threat.get("gate_unsealed")):
			parts.append("OVERTIME %.2f (pay x%.2f)" % [
				float(threat.get("overtime")),
				float(threat.call("overtime_reward_multiplier")),
			])
	var player := get_tree().get_first_node_in_group(&"player")
	if player != null and is_instance_valid(player):
		parts.append("HP %d/%d" % [int(player.get("hp")), int(player.get("max_hp"))])
		var runner := player.get_node_or_null("ManifestationRunner")
		if runner != null:
			parts.append("RULES %d" % int(runner.call("active_count")))
			if runner.has_method("active_pair_count"):
				parts.append("PAIRS %d" % int(runner.call("active_pair_count")))
	_dev_state.text = "  ·  ".join(parts)


# --- Run ---------------------------------------------------------------------

func _build_run_tab(page: VBoxContainer, tools: Node) -> void:
	_dev_heading(page, "PLAYER")
	var vitals := _dev_row(page)
	_dev_button(vitals, "Heal full", "Healed to full", func() -> void:
		var p := get_tree().get_first_node_in_group(&"player")
		if p != null:
			p.call("heal", float(p.get("max_hp")))
	)
	_dev_button(vitals, "Hurt 25%", "Took 25% of max HP", func() -> void:
		var p := get_tree().get_first_node_in_group(&"player")
		if p != null:
			p.call("_take_damage", float(p.get("max_hp")) * 0.25)
	)
	_dev_button(vitals, "Brink (1 HP)", "Dropped to 1 HP - ward rules should light", func() -> void:
		var p := get_tree().get_first_node_in_group(&"player")
		if p != null:
			p.set("hp", 1.0)
			p.emit_signal("hp_changed", 1.0, p.get("max_hp"))
	)
	_dev_button(vitals, "Invulnerable 30s", "30s of i-frames", func() -> void:
		var p := get_tree().get_first_node_in_group(&"player")
		if p != null and p.has_method("grant_invulnerability"):
			p.call("grant_invulnerability", 30.0)
	)

	_dev_heading(page, "ECONOMY")
	var economy := _dev_row(page)
	for amount in [50, 250, 1000]:
		var give: int = amount
		_dev_button(economy, "+%d Followers" % give, "Granted %d Followers" % give, func() -> void:
			if Global != null and Global.has_method("transaction_followers"):
				Global.call("transaction_followers", give, &"dev_grant", {"source": "dev tools"})
		)
	_dev_button(economy, "Luck +5", "Luck +5", func() -> void:
		if Global != null:
			Global.set("run_luck", float(Global.get("run_luck")) + 5.0)
	)
	_dev_button(economy, "Luck 0", "Luck reset to 0", func() -> void:
		if Global != null:
			Global.set("run_luck", 0.0)
	)

	_dev_heading(page, "PRESSURE")
	var pressure := _dev_row(page)
	_dev_button(pressure, "Unseal gate", "Gate unsealed - Overtime starts, belief begins decaying", func() -> void:
		var threat := get_node_or_null("/root/ThreatDirector")
		if threat != null:
			threat.set("gate_unsealed", true)
	)
	for seconds in [30, 120, 300]:
		var s: int = seconds
		_dev_button(pressure, "+%ds Overtime" % s, "Added %ds of Overtime pressure" % s, func() -> void:
			var threat := get_node_or_null("/root/ThreatDirector")
			if threat != null and threat.has_method("add_overtime_pressure"):
				threat.call("add_overtime_pressure", float(s))
		)

	_dev_heading(page, "SEGMENT")
	var segments := _dev_row(page)
	for segment in [2, 5, 10]:
		var n: int = segment
		_dev_button(segments, "Segment %d" % n, "Jumped to segment %d" % n, func() -> void:
			if tools != null:
				tools.call("jump_to_segment", n)
		)


# --- Gear --------------------------------------------------------------------

func _build_gear_tab(page: VBoxContainer, tools: Node) -> void:
	if tools == null:
		return
	_dev_heading(page, "SETS")
	# `set_name` shadows Node.set_name().
	for set_title in ["Conduit", "Gravemarch", "Lattice"]:
		var row := _dev_row(page)
		var label := Label.new()
		label.text = set_title
		label.custom_minimum_size.x = 110.0
		row.add_child(label)
		var id := StringName(set_title.to_lower())
		for pieces in [2, 4, 6]:
			var count: int = pieces
			_dev_button(row, "%dP" % count, "%s set at %d pieces" % [set_title, count], func() -> void:
				tools.call("grant_set", id, count)
			)
	var gear_actions := _dev_row(page)
	_dev_button(gear_actions, "Clear gear", "Cleared every equipped item", func() -> void: tools.call("clear_sets"))
	_dev_button(gear_actions, "Prime conduit", "Conduit primed", func() -> void: tools.call("prime_conduit"))
	_dev_button(gear_actions, "Fill bank", "Gravemarch bank filled", func() -> void: tools.call("fill_gravemarch_bank"))
	_dev_button(gear_actions, "2 marks", "Lattice marks placed", func() -> void: tools.call("place_lattice_marks"))
	_dev_button(gear_actions, "Clear state", "Set combat state cleared", func() -> void: tools.call("clear_combat_state"))

	_dev_heading(page, "GRANT BY ID")
	var grant := _dev_row(page)
	_dev_item_id = LineEdit.new()
	_dev_item_id.placeholder_text = "item id"
	_dev_item_id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grant.add_child(_dev_item_id)
	_dev_button(grant, "Grant", "", func() -> void:
		var id := _dev_item_id.text.strip_edges()
		if id.is_empty():
			_dev_note("No item id entered")
			return
		tools.call("grant_specific_set_item", StringName(id))
		_dev_note("Granted item '%s'" % id)
	)

	_dev_heading(page, "CURSES & BURDEN")
	var curses := _dev_row(page)
	_dev_button(curses, "Deep curses", "Granted the deep-curse wardrobe (concentrated severity)", func() -> void:
		tools.call("grant_deep_curses"))
	_dev_button(curses, "Many mild", "Granted the many-mild wardrobe (count, not depth)", func() -> void:
		tools.call("grant_mild_curses"))
	var augments := _dev_row(page)
	for pair in [
		["Engine", &"augment_corruption_engine", "Corruption Engine - rewards concentrated severity"],
		["Doctrine", &"augment_doctrine_of_burden", "Doctrine of Burden - rewards curse COUNT"],
		["Lens", &"augment_inversion_lens", "Inversion Lens - the suppressed curse pays back"],
	]:
		var id: StringName = pair[1]
		var note: String = pair[2]
		_dev_button(augments, String(pair[0]), note, func() -> void: tools.call("grant_neg_augment", id))


# --- Rules -------------------------------------------------------------------

func _build_rules_tab(page: VBoxContainer, tools: Node) -> void:
	if tools == null:
		return
	_dev_heading(page, "MANIFESTATIONS")
	var pick := _dev_row(page)
	_dev_manifest_picker = OptionButton.new()
	_dev_manifest_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id_value in ManifestationCatalog.all_ids():
		var nouns: Array = ManifestationCatalog.tags_of(id_value)
		var noun_text: String = ""
		if not nouns.is_empty():
			var names: PackedStringArray = PackedStringArray()
			for n in nouns:
				names.append(String(n))
			noun_text = "  (%s)" % ", ".join(names)
		_dev_manifest_picker.add_item("%s%s" % [ManifestationCatalog.display_name(id_value), noun_text])
		_dev_manifest_picker.set_item_metadata(_dev_manifest_picker.item_count - 1, id_value)
	pick.add_child(_dev_manifest_picker)
	_dev_button(pick, "Grant", "", func() -> void:
		if _dev_manifest_picker == null or _dev_manifest_picker.selected < 0:
			return
		var id := StringName(str(_dev_manifest_picker.get_item_metadata(_dev_manifest_picker.selected)))
		tools.call("grant_manifestation", id)
		_dev_note("Granted rule '%s'" % ManifestationCatalog.display_name(id))
	)
	var bulk := _dev_row(page)
	_dev_button(bulk, "Roll every slot", "Rolled a rule into every slot that can carry one", func() -> void:
		tools.call("roll_all_manifestations"))
	_dev_button(bulk, "Clear rules", "Cleared every Manifestation", func() -> void:
		tools.call("clear_manifestations"))

	_dev_heading(page, "PAIR SHORTCUTS")
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.66, 0.66, 0.62))
	hint.text = (
		"A pair lights at two DISTINCT rules of each of its two nouns. "
		+ "Each button below grants exactly that, so the payoff can be tested "
		+ "without fishing for it through the roll."
	)
	page.add_child(hint)
	var row: HBoxContainer = _dev_row(page)
	var placed: int = 0
	for pair_id in ManifestationPairCatalog.all_ids():
		var def := ManifestationPairCatalog.get_def(pair_id)
		if def == null:
			continue
		if placed > 0 and placed % 3 == 0:
			row = _dev_row(page)
		placed += 1
		var id: StringName = pair_id
		var pair_name: String = def.display_name
		_dev_button(row, pair_name, "", func() -> void:
			var granted: int = int(tools.call("grant_pair", id))
			if granted <= 0:
				_dev_note("Could not light '%s' - not enough free slots" % pair_name)
			else:
				_dev_note("Lit '%s' with %d rules" % [pair_name, granted])
		)


# --- Story -------------------------------------------------------------------

func _build_story_tab(page: VBoxContainer, tools: Node) -> void:
	if tools == null:
		return
	_dev_heading(page, "OPENING MODE")
	var modes := _dev_row(page)
	for pair in [["Full", "full"], ["Short", "short"], ["Skip", "skip"]]:
		var mode: String = pair[1]
		_dev_button(modes, String(pair[0]), "Restarted the opening (%s)" % mode, func() -> void:
			tools.call("restart_opening", mode))

	_dev_heading(page, "JUMP TO PHASE")
	# Phase ints follow OpeningSequenceController.Phase (ADMISSION inserted at 2).
	var phases := _dev_row(page)
	for pair in [["Admission", 2], ["Synthesis", 4], ["Target", 5], ["Construct", 6]]:
		var phase: int = pair[1]
		var name_text: String = String(pair[0])
		_dev_button(phases, name_text, "Opening from phase %s" % name_text, func() -> void:
			tools.call("restart_opening", "full", phase))
	var phases_b := _dev_row(page)
	for pair in [["Officer", 7], ["Death", 8], ["Bren", 9]]:
		var phase: int = pair[1]
		var name_text: String = String(pair[0])
		_dev_button(phases_b, name_text, "Opening from phase %s" % name_text, func() -> void:
			tools.call("restart_opening", "full", phase))

	_dev_heading(page, "RESPONSE BRANCH")
	var responses := _dev_row(page)
	for response in ["Analytical", "Decisive", "Protective", "Withdrawn"]:
		var key: String = response.to_lower()
		_dev_button(responses, response, "Opening with the %s response" % key, func() -> void:
			tools.call("restart_opening", "full", 3, key))

	_dev_heading(page, "SAVE STATE")
	var saves := _dev_row(page)
	_dev_button(saves, "Replay next run", "Next run will replay the full opening", func() -> void:
		tools.call("set_next_run_full_replay"))
	_dev_button(saves, "Reset history", "Opening history cleared", func() -> void:
		tools.call("reset_opening_history"))
	_dev_button(saves, "Legacy save", "Simulated a pre-opening save file", func() -> void:
		tools.call("simulate_legacy_opening_save"))


# --- World -------------------------------------------------------------------

func _build_world_tab(page: VBoxContainer, tools: Node) -> void:
	_dev_heading(page, "ENEMIES")
	var enemies := _dev_row(page)
	for count in [5, 20, 60]:
		var n: int = count
		_dev_button(enemies, "Burst %d" % n, "Spawned a burst of %d" % n, func() -> void:
			var spawner := get_tree().get_first_node_in_group(&"enemy_spawner")
			if spawner != null and spawner.has_method("spawn_burst"):
				spawner.call("spawn_burst", n)
		)
	_dev_button(enemies, "Kill all", "Killed every live enemy", func() -> void:
		var world := get_node_or_null("/root/EnemyWorld")
		if world != null and world.has_method("kill_all"):
			world.call("kill_all")
			return
		for e in get_tree().get_nodes_in_group(&"enemies"):
			if is_instance_valid(e) and e.has_method("die"):
				e.call("die")
	)

	_dev_heading(page, "EXIT RITE")
	var rite := _dev_row(page)
	_dev_button(rite, "Unlock rite", "Exit Rite unlocked - the siege can be started", func() -> void:
		for r in get_tree().get_nodes_in_group(&"exit_rite"):
			r.set("locked", false)
		var found := get_tree().get_first_node_in_group(&"exit_rite")
		if found == null:
			_dev_note("No Exit Rite in this scene")
	)
	_dev_button(rite, "Teleport to rite", "Moved to the Exit Rite", func() -> void:
		var r := get_tree().get_first_node_in_group(&"exit_rite") as Node2D
		var p := get_tree().get_first_node_in_group(&"player") as Node2D
		if r != null and p != null:
			p.global_position = r.global_position
	)

	_dev_heading(page, "DIAGNOSTICS")
	var diagnostics := _dev_row(page)
	_dev_button(diagnostics, "Collision fixture", "Spawned the collision fixture", func() -> void:
		if tools != null:
			tools.call("spawn_collision_fixture"))
	_dev_button(diagnostics, "Force set notice", "Forced a set-breakpoint notification", func() -> void:
		if tools != null:
			tools.call("force_breakpoint_notification"))
	_dev_button(diagnostics, "Toggle stress", "Toggled the projectile stress test", func() -> void:
		if Global != null:
			Global.set("debug_projectile_stress_test", not bool(Global.get("debug_projectile_stress_test")))
	)
