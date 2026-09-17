extends Node

# Boots the game headless at a chosen segment, keeps a population alive, and
# prints a node census every 15 s so a slow build-up of nodes names itself.
# The 2026-09-15 00:01 capture sat at 5,400 nodes with 24 enemies in segment
# 5; this is the tool to find out what they were.
#
# Run: <godot> --headless --path . res://tools/tests/NodeCensusProbe.tscn
# Env: CENSUS_SEGMENT (default 5), CENSUS_SECONDS (default 75), CENSUS_POP (default 60),
#      CENSUS_KILLS_PER_SEC (default 8: the probe kills enemies so drops, death
#      effects and pickups exercise their lifetimes), CENSUS_ROUTE (a route name
#      from the dev loader, so tree chains run too)

class Driver:
	extends Node

	var _phase := 0
	var _elapsed := 0.0
	var _wall := 0.0
	var _next_census := 0.0
	var _spawner: Node = null
	var _filter: Node = null
	var _topup_left := 0.0
	var _seconds := 75.0
	var _population := 60
	var _first_total := 0
	var _last_total := 0
	var _kills_per_sec := 8.0
	var _kill_accum := 0.0
	var _route := ""

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		var segment := OS.get_environment("CENSUS_SEGMENT").strip_edges()
		var seconds := OS.get_environment("CENSUS_SECONDS").strip_edges()
		var population := OS.get_environment("CENSUS_POP").strip_edges()
		if seconds.is_valid_float():
			_seconds = float(seconds)
		if population.is_valid_int():
			_population = int(population)
		var kills := OS.get_environment("CENSUS_KILLS_PER_SEC").strip_edges()
		if kills.is_valid_float():
			_kills_per_sec = float(kills)
		_route = OS.get_environment("CENSUS_ROUTE").strip_edges()
		Global.start_new_attempt()
		Global.attempt_segment = int(segment) if segment.is_valid_int() else 5
		if Global.attempt_segment > 1:
			Global.attempt_opening_completed = true
			Global.attempt_opening_phase = 10
		Global.debug_dev_segment = false
		Global.debug_dev_mode = true
		Global.debug_player_god_mode = true
		_phase = 1
		Global.goto_game()

	func _dismiss_blocking_ui() -> void:
		var scene := get_tree().current_scene
		var ui := scene.get_node_or_null("UI") if scene != null else null
		if ui != null:
			for child in ui.get_children():
				if child.has_method("open_choose_3"):
					child.queue_free()
		get_tree().paused = false

	func _census(label: String) -> void:
		var census := NodeCensus.count(get_tree().root)
		var total := int(census["total"])
		if _first_total == 0:
			_first_total = total
		_last_total = total
		print("[census %s t=%.0fs] %s" % [label, _elapsed, NodeCensus.report(get_tree().root, 14)])

	func _process(delta: float) -> void:
		if _phase < 1:
			return
		_wall += delta
		if get_tree().paused:
			if _wall >= 2.0:
				_dismiss_blocking_ui()
			return
		_elapsed += delta
		if _phase == 1 and _elapsed >= 3.0:
			_phase = 2
			_spawner = get_tree().get_first_node_in_group(&"enemy_spawner")
			_filter = get_node_or_null("/root/DebugEnemySpawnFilter")
			if _filter != null:
				_filter.set("cap_mode", 1)
				_filter.set("custom_total_cap", _population)
			if not _route.is_empty():
				var tools := get_node_or_null("/root/DevSetCollisionTools")
				if tools != null:
					print("[census] route: ", tools.call("apply_ascension_route", _route, true))
			_census("start")
			_next_census = _elapsed + 15.0
			return
		if _phase != 2:
			return
		_topup_left -= delta
		if _topup_left <= 0.0 and _spawner != null:
			_topup_left = 0.5
			var alive := int(_spawner.call("_alive_total"))
			var queued := int(_spawner.get("_force_spawn_queue"))
			var deficit: int = _population - alive - queued
			if deficit > 0:
				_spawner.call("debug_force_spawn", deficit)
		_kill_accum += delta * _kills_per_sec
		if _kill_accum >= 1.0:
			var player := get_tree().get_first_node_in_group(&"player")
			var handles: Array[int] = []
			EnemyWorld.active_handles(handles)
			var index := 0
			while _kill_accum >= 1.0 and index < handles.size():
				var handle := handles[index]
				index += 1
				if EnemyWorld.is_dying(handle):
					continue
				_kill_accum -= 1.0
				var runner := player.get_node_or_null("AscensionRunner") if player != null else null
				if runner != null and not _route.is_empty():
					# A native Core strike, so the loaded route's chains run.
					var core := String(runner.get("native_core"))
					var tags := AscensionTags.native(core, {"melee": "slash", "ranged": "bullet", "magic": "impact"}[core])
					tags = AscensionTags.with_flag(tags, "core_strike")
					tags = AscensionTags.with_flag(tags, "execute_enabled")
					tags.append("cast:native:%d" % int(_elapsed * 10.0))
					runner.call("damage_enemy", handle, 9999.0, tags)
				else:
					EnemyCombat.apply_damage(handle, 9999.0, 1, player)
			if index >= handles.size():
				_kill_accum = 0.0
		if _elapsed >= _next_census:
			_next_census = _elapsed + 15.0
			_census("hold")
		if _elapsed >= _seconds:
			_phase = 3
			_census("end")
			print("NodeCensusProbe: nodes %d -> %d over %.0f s at population %d" % [_first_total, _last_total, _elapsed, _population])
			Global.debug_player_god_mode = false
			if _filter != null:
				_filter.set("cap_mode", 0)
			get_tree().quit(0)


func _ready() -> void:
	var driver := Driver.new()
	driver.name = "NodeCensusDriver"
	get_tree().root.call_deferred("add_child", driver)
