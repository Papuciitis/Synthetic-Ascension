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
	_pause_game.toggled.connect(_set_game_paused)
	_header.gui_input.connect(_on_header_input)
	_connect_test_tools()
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
		+ "ENEMIES %d  near/mid/far %d/%d/%d   BULLETS %d (%4.2f ms)\n"
		+ "FLOW %s  rebuilds %d  last %4.2f ms"
	) % [
		float(snapshot.get("fps", 0.0)),
		float(snapshot.get("process_ms", 0.0)),
		float(snapshot.get("physics_ms", 0.0)),
		int(snapshot.get("indexed_enemies", 0)),
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


func _connect_test_tools() -> void:
	var tools := get_node_or_null("/root/DevSetCollisionTools")
	if tools == null:
		return
	var base := "Margin/Root/Tabs/Tests/Scroll/Content/"
	for row_name in ["Conduit", "Gravemarch", "Lattice"]:
		var set_id := StringName(row_name.to_lower())
		for pair in [["Two", 2], ["Four", 4], ["Six", 6]]:
			get_node(base + row_name + "/" + pair[0]).pressed.connect(
				func() -> void: tools.call("grant_set", set_id, pair[1])
			)
	get_node(base + "CombatActions/ClearGear").pressed.connect(func() -> void: tools.call("clear_sets"))
	get_node(base + "CombatActions/Prime").pressed.connect(func() -> void: tools.call("prime_conduit"))
	get_node(base + "CombatActions/FillBank").pressed.connect(func() -> void: tools.call("fill_gravemarch_bank"))
	get_node(base + "CombatActions/Marks").pressed.connect(func() -> void: tools.call("place_lattice_marks"))
	get_node(base + "CombatActions/ClearState").pressed.connect(func() -> void: tools.call("clear_combat_state"))
	get_node(base + "TestActions/Notice").pressed.connect(func() -> void: tools.call("force_breakpoint_notification"))
	get_node(base + "TestActions/Collision").pressed.connect(func() -> void: tools.call("spawn_collision_fixture"))
	for pair in [["Full", "full"], ["Short", "short"], ["Skip", "skip"]]:
		get_node(base + "OpeningModes/" + pair[0]).pressed.connect(
			func() -> void: tools.call("restart_opening", pair[1])
		)
	get_node(base + "OpeningModes/Replay").pressed.connect(func() -> void: tools.call("set_next_run_full_replay"))
	get_node(base + "OpeningModes/Reset").pressed.connect(func() -> void: tools.call("reset_opening_history"))
	get_node(base + "OpeningModes/Legacy").pressed.connect(func() -> void: tools.call("simulate_legacy_opening_save"))
	for pair in [["Synthesis", 3], ["Target", 4], ["Construct", 5], ["Officer", 6], ["Death", 7], ["Bren", 8]]:
		get_node(base + "OpeningPhases/" + pair[0]).pressed.connect(
			func() -> void: tools.call("restart_opening", "full", pair[1])
		)
	for response in ["Analytical", "Decisive", "Protective", "Withdrawn"]:
		get_node(base + "Responses/" + response).pressed.connect(
			func() -> void: tools.call("restart_opening", "full", 2, response.to_lower())
		)
	for pair in [["Two", 2], ["Five", 5], ["Ten", 10]]:
		get_node(base + "Segments/" + pair[0]).pressed.connect(
			func() -> void: tools.call("jump_to_segment", pair[1])
		)
