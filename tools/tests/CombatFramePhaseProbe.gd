extends Node

## Where a rendered frame goes in a crowded Ranged V5 fight, and what starts
## physics catch-up. Boots the real game, loads Barrage + Precision + Ordnance
## nodes (three engines, as in the 2026-10-01 captures), holds a population
## that does not die to the build (health pinned high) and kills a fixed
## number per second through the native strike path, so the crowd, the kill
## rate and the hit volume are the same in every run. It fires the native
## weapon at the nearest enemy every frame and casts Q every 3 s. Every frame
## it reads the flight recorder's own sample, so the numbers are the ones a
## capture would carry:
##   wall            real spacing between samples
##   physics         summed physics ticks of the frame, and how many ran
##   process         script _process callbacks (frame_phases.process)
##   deferred        tweens, timers, deferred calls, queued frees
##   render_present  draw + buffer swap, including any vsync wait (windowed)
##   ascension       the tree's tick, split per engine
##   projectiles     the projectile simulation step
##   process split   the process phase by subtree: every autoload and every
##                   child of the game scene (marker nodes between siblings
##                   stamp the clock; nodes added during the run, enemies and
##                   pickups and effects, fall in the last bucket)
##   tick split      what the frame's physics ticks were made of: enemies'
##                   full-tier steps, the scheduler's mid/far steps, every
##                   other physics callback, and the physics server's step
## It prints medians / p95 / p99 / max, the catch-up chains and what the frame
## before a chain looked like, the slowest frames with their split, and
## writes the same as JSON.
##
## Run: <godot> [--headless] --path . res://tools/tests/CombatFramePhaseProbe.tscn
## Env: PHASE_SEGMENT (8), PHASE_POP (100), PHASE_SECONDS (45), PHASE_SEED
##      (world seed, 20261001), PHASE_NODES (comma list replacing the default
##      purchases; "heavy" loads the 21-node stress build), PHASE_KILLS_PER_SEC
##      (1.5, the captures' rate in crowded segment 7-9 frames), PHASE_MORTAL
##      (0; 1 lets the build kill freely), PHASE_FIRE (1), PHASE_CAST (1),
##      PHASE_BALANCE (1: the BalanceRecorder on, as in play), PHASE_OUT
##      (json path; default user://combat_frame_phase.json), PHASE_ROWS (path:
##      also write every frame's row, one JSON object per line),
##      PHASE_FRAME_DELAY_MS (0: sleep each frame to stand in for a slow
##      render when headless), PHASE_NODE_TRACE (0; 1 names every burst of
##      20 or more nodes added in one frame, the probe's own forced enemy
##      spawns aside: what it was, how often, and the tree's tick on those
##      frames), PHASE_DRAW_TRACE (0; 1 times every scripted CanvasItem's
##      redraw, the bulk of the "deferred" phase, by script), PHASE_CAPTURE
##      (a directory: the recorder captures and writes incidents there as it
##      does in play, so its own work is part of the frame; never point it at
##      real captures), PHASE_MAX_PHYSICS_STEPS (the project's 4: how many
##      physics ticks one frame may run to catch up).

## The nodes the 2026-10-01 session is known to have owned (its purchase and
## catastrophe events: Fifth Shot, Cluster Rounds, Overload, Read, Impact
## Fuse) plus the neighbours the purchase rule needs to reach them.
const DEFAULT_NODES: Array[String] = [
	"BR01", "BR02", "BR04", "BR08", "BR05", "BR06", "BRC", "BR12", "BRQ",
	"PR01",
	"OR02", "OR01",
]
## A late-run stress build: every chain and fragment source at once.
const HEAVY_NODES: Array[String] = [
	"BR01", "BR02", "BR03", "BR04", "BR08", "BR05", "BRQ", "BRF2", "BRC", "BR12",
	"PR01", "PR02", "PR03", "PR07",
	"OR02", "OR01", "OR04", "OR08", "OR05", "OR06", "OR09", "OR11",
]


class Driver:
	extends Node

	const SPINUP_SEC := 6.0

	var nodes: Array[String] = []
	var _phase := 0
	var _elapsed := 0.0
	var _wall := 0.0
	var _seconds := 45.0
	var _population := 100
	var _fire := true
	var _kills_per_sec := 1.5
	var _kill_accum := 0.0
	var _mortal := false
	var _kills := 0
	var _cast := true
	var _out := "user://combat_frame_phase.json"
	var _frame_delay_ms := 0
	var _spawner: Node = null
	var _filter: Node = null
	var _topup_left := 0.0
	var _q_timer := 0.0
	var _rows: Array[Dictionary] = []
	var _bought: Array[String] = []
	var _refused: Array[String] = []
	var _last_t_usec := 0
	var _tick_first_usec := 0
	var _frame_calls_usec := 0
	var _frame_slowest_tick_usec := 0
	var _node_trace := false
	var _added_this_frame: Array[Node] = []
	var _bursts: Dictionary = {}
	var _frame_kill_usec := 0
	var _split_last_usec := 0
	var _split_last_label := ""
	var _split_frame: Dictionary = {}
	var _split_rows: Dictionary = {}
	var _draw_trace := false
	var _draw_last_usec := 0
	var _draw_last_label := ""
	var _draw_usec: Dictionary = {}
	var _draw_calls: Dictionary = {}
	var _slow_kills: Array = []


	## Stamps the clock between two sibling subtrees: the time since the
	## previous marker belongs to whatever sits between them.
	class SplitMarker:
		extends Node
		var probe: Node
		var label := ""
		func _process(_delta: float) -> void:
			probe.call("_on_split_marker", label)


	## First (kind 0) and last (kind 1) physics callback of every tick.
	class PhysicsMarker:
		extends Node
		var probe: Node
		var kind := 0
		func _physics_process(_delta: float) -> void:
			probe.call("_on_physics_marker", kind)


	class Tail:
		extends Node
		var probe: Node
		var delay_ms := 0
		func _init() -> void:
			process_mode = Node.PROCESS_MODE_ALWAYS
			process_priority = 2147483646
		func _process(_delta: float) -> void:
			# Closes the process split's last bucket before anything else.
			probe.call("_on_split_marker", "")
			if delay_ms > 0:
				OS.delay_msec(delay_ms)


	func _env(key: String, fallback: String) -> String:
		var value := OS.get_environment(key).strip_edges()
		return value if not value.is_empty() else fallback


	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_seconds = float(_env("PHASE_SECONDS", str(_seconds)))
		_population = int(_env("PHASE_POP", str(_population)))
		_fire = _env("PHASE_FIRE", "1") != "0"
		_kills_per_sec = float(_env("PHASE_KILLS_PER_SEC", str(_kills_per_sec)))
		_mortal = _env("PHASE_MORTAL", "0") == "1"
		_cast = _env("PHASE_CAST", "1") != "0"
		_out = _env("PHASE_OUT", _out)
		_frame_delay_ms = int(_env("PHASE_FRAME_DELAY_MS", "0"))
		var custom := _env("PHASE_NODES", "")
		if custom == "heavy":
			nodes = HEAVY_NODES.duplicate()
		elif not custom.is_empty():
			nodes.clear()
			for part in custom.split(","):
				if not part.strip_edges().is_empty():
					nodes.append(part.strip_edges())
		var recorder := get_node_or_null("/root/PerformanceFlightRecorder")
		if recorder != null:
			var capture_dir := _env("PHASE_CAPTURE", "")
			recorder.set("write_reports", not capture_dir.is_empty())
			recorder.set("automatic_capture", not capture_dir.is_empty())
			if not capture_dir.is_empty():
				recorder.set("report_directory", capture_dir)
			recorder.call("set_enabled", true)
		var max_steps := _env("PHASE_MAX_PHYSICS_STEPS", "")
		if max_steps.is_valid_int():
			Engine.max_physics_steps_per_frame = int(max_steps)
		var balance := get_node_or_null("/root/BalanceRecorder")
		if balance != null and _env("PHASE_BALANCE", "1") == "1":
			balance.set("record_headless", true)
			balance.call("set_enabled", false)
			balance.call("set_enabled", true)
		Global.selected_style_id = &"ranged"
		Global.start_new_attempt()
		Global.attempt_world_seed = int(_env("PHASE_SEED", "20261001"))
		Global.attempt_segment = int(_env("PHASE_SEGMENT", "8"))
		Global.attempt_opening_completed = true
		Global.attempt_opening_phase = 10
		Global.debug_dev_segment = false
		Global.debug_dev_mode = true
		Global.debug_player_god_mode = true
		Global.debug_projectile_stress_test = false
		# Headless has no display to pace it: hold 60 frames a second so a
		# frame runs one physics tick, as it does behind vsync in play.
		if DisplayServer.get_name() == "headless":
			Engine.max_fps = int(_env("PHASE_MAX_FPS", "60"))
		EnemyActor.debug_physics_timing = true
		EnemyCombatService.debug_timing = true
		for key in EnemyCombatService.debug_usec:
			EnemyCombatService.debug_usec[key] = 0
		_node_trace = _env("PHASE_NODE_TRACE", "0") == "1"
		_draw_trace = _env("PHASE_DRAW_TRACE", "0") == "1"
		if _draw_trace:
			get_tree().node_added.connect(_watch_draw)
		if _node_trace:
			get_tree().node_added.connect(func(node: Node) -> void: _added_this_frame.append(node))
		for kind in [0, 1]:
			var marker := PhysicsMarker.new()
			marker.probe = self
			marker.kind = kind
			marker.process_mode = Node.PROCESS_MODE_ALWAYS
			marker.process_physics_priority = -1_000_000_000 if kind == 0 else 1_000_000_000
			get_tree().root.call_deferred("add_child", marker)
		var tail := Tail.new()
		tail.probe = self
		tail.delay_ms = _frame_delay_ms
		get_tree().root.call_deferred("add_child", tail)
		_phase = 1
		Global.goto_game()


	## CanvasItem.draw fires just before the item's _draw: the time to the
	## next draw signal, or to the next thing this probe sees (a physics or
	## process marker, the frame's draw start), is charged to that _draw. The
	## last redraw of a batch therefore reads a little high.
	func _watch_draw(node: Node) -> void:
		if node is CanvasItem and node.get_script() != null:
			var label := ((node.get_script() as Script).resource_path.get_file())
			(node as CanvasItem).draw.connect(_on_item_draw.bind(label))


	func _watch_draw_tree(node: Node) -> void:
		_watch_draw(node)
		for child in node.get_children():
			_watch_draw_tree(child)


	func _on_item_draw(label: String) -> void:
		var now := Time.get_ticks_usec()
		_close_draw(now)
		_draw_last_usec = now
		_draw_last_label = label
		_draw_calls[label] = int(_draw_calls.get(label, 0)) + 1


	func _close_draw(now: int) -> void:
		if _draw_last_usec > 0 and not _draw_last_label.is_empty():
			_draw_usec[_draw_last_label] = int(_draw_usec.get(_draw_last_label, 0)) + (now - _draw_last_usec)
		_draw_last_usec = 0
		_draw_last_label = ""


	## One marker before every child of `parent`, labelled with that child.
	func _add_split_markers(parent: Node, prefix: String) -> void:
		for child in parent.get_children():
			if child is SplitMarker:
				continue
			var marker := SplitMarker.new()
			marker.probe = self
			marker.label = prefix + String(child.name)
			marker.process_mode = Node.PROCESS_MODE_ALWAYS
			parent.add_child(marker)
			parent.move_child(marker, child.get_index())
		var last := SplitMarker.new()
		last.probe = self
		last.label = prefix + "(added during the run)"
		last.process_mode = Node.PROCESS_MODE_ALWAYS
		parent.add_child(last)


	func _on_split_marker(label: String) -> void:
		var now := Time.get_ticks_usec()
		_close_draw(now)
		if _split_last_usec > 0 and not _split_last_label.is_empty():
			_split_frame[_split_last_label] = int(_split_frame.get(_split_last_label, 0)) + (now - _split_last_usec)
		_split_last_usec = now
		_split_last_label = label


	## Names this frame's burst of added nodes by its outermost new nodes.
	func _note_burst(asc_tick_ms: float) -> void:
		var added := {}
		for node in _added_this_frame:
			if is_instance_valid(node):
				added[node] = true
		# The probe's own top-up spawns twelve enemies a frame: not a finding.
		for node in added.keys():
			var owner_node: Node = node
			while owner_node != null:
				if owner_node is EnemyActor:
					added.erase(node)
					break
				owner_node = owner_node.get_parent()
		if added.size() < 20:
			return
		var roots := {}
		for node in added:
			var parent: Node = (node as Node).get_parent()
			if parent != null and added.has(parent):
				continue
			var script: Script = (node as Node).get_script() as Script
			var label := "%s %s under %s" % [(node as Node).get_class(), (script.resource_path.get_file() if script != null else ((node as Node).scene_file_path.get_file() if not (node as Node).scene_file_path.is_empty() else "-")), (String(parent.name) if parent != null else "?")]
			roots[label] = int(roots.get(label, 0)) + 1
		var parts: Array = roots.keys()
		parts.sort()
		var signature := ""
		for label in parts:
			signature += "%dx %s; " % [roots[label], label]
		var entry: Dictionary = _bursts.get(signature, {"count": 0, "nodes": 0, "asc_max": 0.0, "asc_sum": 0.0})
		entry["count"] = int(entry["count"]) + 1
		entry["nodes"] = added.size()
		entry["asc_max"] = maxf(float(entry["asc_max"]), asc_tick_ms)
		entry["asc_sum"] = float(entry["asc_sum"]) + asc_tick_ms
		_bursts[signature] = entry


	func _on_physics_marker(kind: int) -> void:
		var now := Time.get_ticks_usec()
		_close_draw(now)
		if kind == 0:
			_tick_first_usec = now
		elif _tick_first_usec > 0:
			_frame_calls_usec += now - _tick_first_usec
			_frame_slowest_tick_usec = maxi(_frame_slowest_tick_usec, now - _tick_first_usec)


	func _buy_nodes() -> void:
		Global.attempt_ascension = AscensionLedger.fresh_state("ranged", "v5_ranged")
		var ledger := Global.ascension_ledger()
		ledger.note_segment_completed(9)
		Global.transaction_followers(2_000_000, &"dev_grant", {"source": "combat frame phase probe"}, false, false)
		for id in nodes:
			var verdict: Dictionary = Global.ascension_buy(id, "")
			if bool(verdict.get("ok", false)):
				_bought.append(id)
			else:
				_refused.append("%s (%s)" % [id, verdict.get("reason", "?")])
		if _bought.has("BRQ"):
			ledger.equip("q", "BRQ")
		var tools := get_node_or_null("/root/DevSetCollisionTools")
		if tools != null and tools.has_method("_refresh_player_loadout"):
			tools.call("_refresh_player_loadout")
		print("CombatFramePhaseProbe: bought %s%s" % [", ".join(_bought), ("" if _refused.is_empty() else " | refused " + "; ".join(_refused))])


	func _process(delta: float) -> void:
		if _phase < 1:
			return
		_wall += delta
		if get_tree().paused:
			if _wall >= 2.0:
				var scene := get_tree().current_scene
				var ui := scene.get_node_or_null("UI") if scene != null else null
				if ui != null:
					for child in ui.get_children():
						if child.has_method("open_choose_3"):
							child.queue_free()
				get_tree().paused = false
			return
		_elapsed += delta
		if _phase == 1 and _elapsed >= 3.0:
			_phase = 2
			_elapsed = 0.0
			_spawner = get_tree().get_first_node_in_group(&"enemy_spawner")
			_filter = get_node_or_null("/root/DebugEnemySpawnFilter")
			if _spawner == null or _filter == null:
				push_error("CombatFramePhaseProbe: missing spawner or filter")
				get_tree().quit(1)
				return
			_filter.set("cap_mode", 1)
			_filter.set("custom_total_cap", _population)
			_buy_nodes()
			if _draw_trace:
				_watch_draw_tree(get_tree().root)
				RenderingServer.frame_pre_draw.connect(func() -> void: _close_draw(Time.get_ticks_usec()))
			if _env("PHASE_PROCESS_SPLIT", "1") == "1":
				var split_player := get_tree().get_first_node_in_group(&"player")
				if split_player != null:
					_add_split_markers(split_player, "Game/Player/")
				_add_split_markers(get_tree().current_scene, "Game/")
				_add_split_markers(get_tree().root, "")
			RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
			return
		if _phase != 2:
			return
		_topup_left -= delta
		if _topup_left <= 0.0:
			_topup_left = 0.5
			var deficit: int = _population - int(_spawner.call("_alive_total")) - int(_spawner.get("_force_spawn_queue"))
			if deficit > 0:
				_spawner.call("debug_force_spawn", deficit)
			if not _mortal:
				_pin_health()
		var player := get_tree().get_first_node_in_group(&"player") as Node2D
		var runner: Node = player.get_node_or_null("AscensionRunner") if player != null else null
		if runner != null and _kills_per_sec > 0.0:
			_kill_accum += delta * _kills_per_sec
			if _kill_accum >= 1.0:
				_scripted_kills(player, runner)
		if player != null and _fire:
			var handle := int(EnemyCombat.nearest_enemy(player.global_position, 900.0, 0))
			if handle != 0:
				player.call("_fire_weapon", EnemyWorld.get_position(handle))
		if runner != null and _cast:
			_q_timer += delta
			if _q_timer >= 3.0:
				_q_timer = 0.0
				runner.set("q_cooldown_left", 0.0)
				runner.call("activate_q")
		if _elapsed >= SPINUP_SEC:
			_sample(runner)
		if _elapsed >= SPINUP_SEC + _seconds:
			_phase = 3
			_report()
			Global.debug_player_god_mode = false
			_filter.set("cap_mode", 0)
			get_tree().quit(0)


	func _pin_health() -> void:
		var handles: Array[int] = []
		EnemyWorld.active_handles(handles)
		for handle in handles:
			if EnemyWorld.get_max_health(handle) < 1.0e8:
				EnemyCombat.configure_health(handle, 1.0e9, true)


	## Kills through the native strike path, like AscensionBuildProbe: the
	## tree sees a weapon fire and a lethal Core strike, so on-kill rules run.
	func _scripted_kills(player: Node2D, runner: Node) -> void:
		var handles: Array[int] = []
		EnemyWorld.active_handles(handles)
		var index := 0
		while _kill_accum >= 1.0 and index < handles.size():
			var handle := handles[index]
			index += 1
			if EnemyWorld.is_dying(handle):
				continue
			_kill_accum -= 1.0
			var tags := AscensionTags.native("ranged", "bullet")
			tags = AscensionTags.with_flag(tags, "core_strike")
			tags.append("cast:native:%d" % int(_elapsed * 10.0))
			RunEvents.weapon_fired.emit(player, &"ranged", player.global_position, EnemyWorld.get_position(handle), 1.0, 1.0)
			var actor: Node = EnemyWorld.actor_for_handle(handle)
			var victim := "%s%s" % [(actor.scene_file_path.get_file().get_basename() if actor != null else "proxy"), (" elite" if actor != null and bool(actor.get("is_elite")) else "")]
			var added_before := _added_this_frame.size()
			var kill_started := Time.get_ticks_usec()
			runner.call("damage_enemy", handle, 4.0e9, tags)
			var kill_usec := Time.get_ticks_usec() - kill_started
			_frame_kill_usec += kill_usec
			# A scripted kill is one synchronous call: everything the death
			# does (payout, drops, effects, the tree's on-kill rules) is in it.
			if kill_usec >= 5000:
				var made: PackedStringArray = []
				for node in _added_this_frame.slice(added_before):
					if is_instance_valid(node):
						var script: Script = node.get_script() as Script
						made.append(script.resource_path.get_file() if script != null else node.get_class())
				_slow_kills.append({"t": _elapsed, "ms": float(kill_usec) / 1000.0, "victim": victim, "added": ", ".join(made)})
			_kills += 1
		if index >= handles.size():
			_kill_accum = 0.0


	func _sample(_runner: Node) -> void:
		var recorder := get_node_or_null("/root/PerformanceFlightRecorder")
		if recorder == null:
			return
		var history: Array = recorder.get("_history")
		if history.is_empty():
			return
		var sample: Dictionary = history[-1]
		var t_usec := int(sample.get("t_usec", 0))
		if t_usec == _last_t_usec:
			return
		_last_t_usec = t_usec
		var phases: Dictionary = sample.get("frame_phases", {})
		var ascension: Dictionary = sample.get("ascension", {})
		var manager := get_node_or_null("/root/ProjectileManager")
		var viewport_rid := get_viewport().get_viewport_rid()
		var proxy_root := get_tree().get_first_node_in_group(&"enemy_proxy_root")
		var proxy_renderer: Node = proxy_root.get("renderer") if proxy_root != null else null
		var row := {
			"t": float(sample.get("elapsed_sec", 0.0)),
			"wall": float(sample.get("wall_ms", 0.0)),
			"ticks": int(sample.get("physics_ticks", 0)),
			"physics": float(sample.get("physics_frame_ms", 0.0)),
			"step": float(sample.get("physics_step_ms", 0.0)),
			"delta": float(sample.get("delta_ms", 0.0)),
			"pressure": int((sample.get("enemy_scheduler", {}) as Dictionary).get("pressure_level", 0)),
			"full": int(sample.get("sim_full", 0)),
			"physics_enabled": int(sample.get("sim_physics_enabled", 0)),
			"kills": _kills,
			"kill_ms": float(_frame_kill_usec) / 1000.0,
			# The frame's physics ticks, split (ms): every script callback,
			# enemies' full-tier steps, scheduler-run mid/far steps, the
			# rest of the callbacks, and what is left for the server.
			"tick_calls": float(_frame_calls_usec) / 1000.0,
			"tick_full": float(EnemyActor.debug_full_step_usec) / 1000.0,
			"tick_sched": float(EnemyActor.debug_scheduled_step_usec) / 1000.0,
			"tick_other": maxf(0.0, float(_frame_calls_usec - EnemyActor.debug_full_step_usec - EnemyActor.debug_scheduled_step_usec) / 1000.0),
			"tick_server": maxf(0.0, float(sample.get("physics_frame_ms", 0.0)) - float(_frame_calls_usec) / 1000.0),
			"tick_slowest": float(_frame_slowest_tick_usec) / 1000.0,
			"full_steps": EnemyActor.debug_full_step_calls,
			"sched_steps": EnemyActor.debug_scheduled_step_calls,
			"collision_pairs": int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)),
			"process": float(phases.get("process", -1.0)),
			"deferred": float(phases.get("deferred", -1.0)),
			"render_present": float(phases.get("render_present", -1.0)),
			"asc_tick": float(int(ascension.get("tick_usec", 0))) / 1000.0,
			"asc_flush": float(int(ascension.get("flush_usec", 0))) / 1000.0,
			"asc_hit": float(int(ascension.get("hit_usec", 0))) / 1000.0,
			"engine_usec": ascension.get("engine_usec", {}),
			"frag_ms": float(int((ascension.get("BR", {}) as Dictionary).get("fragment_usec", 0))) / 1000.0,
			"frag_live": int((ascension.get("BR", {}) as Dictionary).get("fragments_live", 0)),
			"frag_retarget_ms": float(int((ascension.get("BR", {}) as Dictionary).get("retarget_usec", 0))) / 1000.0,
			"frag_hit_ms": float(int((ascension.get("BR", {}) as Dictionary).get("hit_usec", 0))) / 1000.0,
			"frag_hits": int((ascension.get("BR", {}) as Dictionary).get("hits", 0)),
			"frag_retargets": int((ascension.get("BR", {}) as Dictionary).get("retargets", 0)),
			"bullets": int(ascension.get("bullets", 0)),
			"damage_calls": int(ascension.get("damage_calls", 0)),
			"queries": int(ascension.get("queries", 0)),
			"projectiles": int(manager.call("active_count")) if manager != null else 0,
			"projectile_ms": float((manager.call("get_debug_counters") as Dictionary).get("physics_ms", 0.0)) if manager != null else 0.0,
			"sampling": float(int(sample.get("sampling_overhead_usec", 0))) / 1000.0,
			# The batched enemy renderer's buffer build (actors and proxies).
			"enemy_draw_build": float(int(proxy_renderer.call("last_upload_usec"))) / 1000.0 if proxy_renderer != null else 0.0,
			"materialized": get_tree().get_nodes_in_group(&"enemies").size(),
			"logical": int(EnemyWorld.call("get_debug_counters").get("logical", 0)),
			"nodes": int(sample.get("nodes", 0)),
			"draw_calls": int(sample.get("draw_calls", 0)),
			"render_cpu": RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid),
			"render_gpu": RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid),
		}
		_rows.append(row)
		_frame_kill_usec = 0
		# The split covers the previous frame's process phase (markers ran
		# after this driver); the tail of the last bucket ends at FrameTail.
		for label in _split_frame:
			if not _split_rows.has(label):
				_split_rows[label] = []
			(_split_rows[label] as Array).append(float(_split_frame[label]) / 1000.0)
		_split_frame.clear()
		if _node_trace:
			if _added_this_frame.size() >= 20:
				_note_burst(float(row["asc_tick"]))
			_added_this_frame.clear()
		_frame_calls_usec = 0
		_frame_slowest_tick_usec = 0
		EnemyActor.debug_full_step_usec = 0
		EnemyActor.debug_full_step_calls = 0
		EnemyActor.debug_scheduled_step_usec = 0
		EnemyActor.debug_scheduled_step_calls = 0


	func _pct(values: Array, fraction: float) -> float:
		if values.is_empty():
			return 0.0
		var ordered := values.duplicate()
		ordered.sort()
		return float(ordered[clampi(int(ceil(fraction * ordered.size())) - 1, 0, ordered.size() - 1)])


	func _column(key: String) -> Array:
		var out: Array = []
		for row in _rows:
			var value := float(row[key])
			if value >= 0.0:
				out.append(value)
		return out


	func _stat(key: String) -> Dictionary:
		var values := _column(key)
		return {"n": values.size(), "p50": snappedf(_pct(values, 0.5), 0.01), "p95": snappedf(_pct(values, 0.95), 0.01), "p99": snappedf(_pct(values, 0.99), 0.01), "max": snappedf(_pct(values, 1.0), 0.01)}


	func _report() -> void:
		var report := {
			"probe": "CombatFramePhaseProbe",
			"build": BuildInfo.describe(int(Global.attempt_world_seed)),
			"segment": Global.attempt_segment,
			"population": _population,
			"seconds": _seconds,
			"kills": _kills,
			"kills_per_sec_target": _kills_per_sec,
			"mortal": _mortal,
			"headless": DisplayServer.get_name() == "headless",
			"frame_delay_ms": _frame_delay_ms,
			"cpu": OS.get_processor_name(),
			"gpu": RenderingServer.get_video_adapter_name() if DisplayServer.get_name() != "headless" else "",
			"vsync": DisplayServer.window_get_vsync_mode() if DisplayServer.get_name() != "headless" else -1,
			"max_physics_steps_per_frame": Engine.max_physics_steps_per_frame,
			"capture": not _env("PHASE_CAPTURE", "").is_empty(),
			"bought": _bought,
			"refused": _refused,
			"frames": _rows.size(),
			"stats": {},
		}
		print("CombatFramePhaseProbe: %d frames, segment %d, population %d, %s" % [_rows.size(), Global.attempt_segment, _population, ("headless" if report["headless"] else "windowed (%s)" % report["gpu"])])
		for key in ["wall", "kill_ms", "physics", "tick_slowest", "tick_calls", "tick_full", "tick_sched", "tick_other", "tick_server", "collision_pairs", "process", "deferred", "render_present", "asc_tick", "frag_ms", "frag_retarget_ms", "frag_hit_ms", "frag_hits", "frag_live", "frag_retargets", "asc_flush", "asc_hit", "projectile_ms", "enemy_draw_build", "sampling", "render_cpu", "render_gpu", "projectiles", "materialized", "logical", "nodes", "draw_calls", "bullets", "damage_calls", "queries"]:
			var stat := _stat(key)
			report["stats"][key] = stat
			print("  %-15s p50 %8.2f  p95 %8.2f  p99 %8.2f  max %8.2f  (n=%d)" % [key, stat["p50"], stat["p95"], stat["p99"], stat["max"], stat["n"]])
		# Per-engine tick cost.
		var engines := {}
		for row in _rows:
			var split: Dictionary = row["engine_usec"]
			for code in split:
				if not engines.has(code):
					engines[code] = []
				(engines[code] as Array).append(float(split[code]) / 1000.0)
		report["engines"] = {}
		for code in engines:
			var values: Array = engines[code]
			var stat := {"p50": snappedf(_pct(values, 0.5), 0.001), "p95": snappedf(_pct(values, 0.95), 0.001), "p99": snappedf(_pct(values, 0.99), 0.001), "max": snappedf(_pct(values, 1.0), 0.001)}
			report["engines"][code] = stat
			print("  engine %-8s p50 %8.3f  p95 %8.3f  p99 %8.3f  max %8.3f ms" % [code, stat["p50"], stat["p95"], stat["p99"], stat["max"]])
		# Hitch counts and tick distribution.
		var over := {"28": 0, "33": 0, "50": 0, "100": 0}
		var ticks := {}
		for row in _rows:
			for threshold in over:
				if float(row["wall"]) > float(threshold):
					over[threshold] = int(over[threshold]) + 1
			ticks[int(row["ticks"])] = int(ticks.get(int(row["ticks"]), 0)) + 1
		report["over_ms"] = over
		report["ticks_per_frame"] = ticks
		print("  frames over 28/33/50/100 ms: %d / %d / %d / %d   ticks per frame %s" % [over["28"], over["33"], over["50"], over["100"], str(ticks)])
		# Game speed: physics time simulated per second of wall time (1.0 =
		# real time; below it the cap on ticks per frame is dropping time).
		var wall_total := 0.0
		var tick_total := 0
		var recorder_busy := 0
		for row in _rows:
			wall_total += float(row["wall"])
			tick_total += int(row["ticks"])
			if float(row["sampling"]) >= 1.0:
				recorder_busy += 1
		var game_speed := (float(tick_total) * 1000.0 / float(Engine.physics_ticks_per_second)) / maxf(1.0, wall_total)
		report["game_speed"] = snappedf(game_speed, 0.001)
		report["recorder_busy_frames"] = recorder_busy
		print("  game speed %.3f (simulated / real time), mean frame %.2f ms; frames with 1 ms or more of recorder work: %d" % [game_speed, wall_total / float(maxi(1, _rows.size())), recorder_busy])
		# Catch-up chains: runs of frames with two or more ticks, and the
		# frame before each run (what started it).
		var chains: Array = []
		var before: Array = []
		var run := 0
		for i in range(_rows.size()):
			if int(_rows[i]["ticks"]) >= 2:
				if run == 0 and i > 0:
					before.append(_rows[i - 1])
				run += 1
			elif run > 0:
				chains.append(run)
				run = 0
		if run > 0:
			chains.append(run)
		var chain_frames := 0
		var long_frames := 0
		for length in chains:
			chain_frames += int(length)
			if int(length) >= 3:
				long_frames += int(length)
		var starters := {"wall": [], "physics": [], "process": [], "deferred": [], "render_present": [], "asc_tick": [], "projectile_ms": []}
		for row in before:
			for key in starters:
				if float(row[key]) >= 0.0:
					(starters[key] as Array).append(float(row[key]))
		var starter_stats := {}
		for key in starters:
			starter_stats[key] = {"p50": snappedf(_pct(starters[key], 0.5), 0.01), "p95": snappedf(_pct(starters[key], 0.95), 0.01)}
		report["catchup"] = {"chains": chains.size(), "frames": chain_frames, "frames_in_chains_of_3_plus": long_frames, "longest": (chains.max() if not chains.is_empty() else 0), "frame_before_chain": starter_stats}
		print("  catch-up: %d chains, %d frames (%d in chains of 3+), longest %d" % [chains.size(), chain_frames, long_frames, report["catchup"]["longest"]])
		print("  frame before a chain (p50/p95): " + ", ".join(starter_stats.keys().map(func(key: String) -> String: return "%s %.1f/%.1f" % [key, starter_stats[key]["p50"], starter_stats[key]["p95"]])))
		# The slowest frames, with their split.
		var order := range(_rows.size())
		order.sort_custom(func(a: int, b: int) -> bool: return float(_rows[a]["wall"]) > float(_rows[b]["wall"]))
		report["slowest"] = []
		for i in order.slice(0, mini(8, order.size())):
			var row: Dictionary = _rows[i]
			report["slowest"].append(row)
			print("  slow frame t=%.2f wall %.1f | ticks %d physics %.1f | process %.1f deferred %.1f render %.1f | asc %.1f %s proj %.1f | enemies %d proj %d nodes %d" % [row["t"], row["wall"], row["ticks"], row["physics"], row["process"], row["deferred"], row["render_present"], row["asc_tick"], str(row["engine_usec"]), row["projectile_ms"], row["materialized"], row["projectiles"], row["nodes"]])
		# The process phase by subtree, largest mean first.
		if not _split_rows.is_empty():
			var labels: Array = _split_rows.keys()
			var means := {}
			for label in labels:
				var total := 0.0
				for value in _split_rows[label]:
					total += float(value)
				means[label] = total / float(maxi(1, _rows.size()))
			labels.sort_custom(func(a: String, b: String) -> bool: return float(means[a]) > float(means[b]))
			report["process_split"] = {}
			for label in labels.slice(0, mini(18, labels.size())):
				var values: Array = _split_rows[label]
				report["process_split"][label] = {"mean": snappedf(means[label], 0.001), "p50": snappedf(_pct(values, 0.5), 0.001), "p95": snappedf(_pct(values, 0.95), 0.001), "max": snappedf(_pct(values, 1.0), 0.01)}
				print("  process %-34s mean %6.3f  p50 %6.3f  p95 %6.3f  max %7.2f ms" % [label, means[label], _pct(values, 0.5), _pct(values, 0.95), _pct(values, 1.0)])
		# Scripted redraws, largest total first (ms per frame, calls per frame).
		if _draw_trace and not _rows.is_empty():
			var scripts: Array = _draw_usec.keys()
			scripts.sort_custom(func(a: String, b: String) -> bool: return int(_draw_usec[a]) > int(_draw_usec[b]))
			report["draw_trace"] = {}
			for label in scripts.slice(0, mini(12, scripts.size())):
				var per_frame := float(_draw_usec[label]) / 1000.0 / float(_rows.size())
				var calls_per_frame := float(_draw_calls.get(label, 0)) / float(_rows.size())
				report["draw_trace"][label] = {"ms_per_frame": snappedf(per_frame, 0.001), "calls_per_frame": snappedf(calls_per_frame, 0.01)}
				print("  redraw %-34s %6.3f ms/frame  %6.2f calls/frame" % [label, per_frame, calls_per_frame])
		# The hit pipeline's own split (EnemyCombatService.debug_timing), over
		# the whole run including spin-up: ms in total and per hit / per death.
		var combat: Dictionary = EnemyCombatService.debug_usec
		var hit_count := maxi(1, int(combat.get("hits", 0)))
		var death_count := maxi(1, int(combat.get("deaths", 0)))
		report["hit_pipeline"] = combat.duplicate()
		print("  hit pipeline: %d hits, %d deaths | enemy_damaged listeners %.1f ms (%.1f us/hit) | BattleText %.1f ms (%.1f us/hit) | hit_landed listeners %.1f ms (%.1f us/hit) | death %.1f ms (%.2f ms/death, of which enemy_defeated listeners %.2f ms/death)" % [
			int(combat.get("hits", 0)), int(combat.get("deaths", 0)),
			float(combat["damaged_emit"]) / 1000.0, float(combat["damaged_emit"]) / hit_count,
			float(combat["battletext"]) / 1000.0, float(combat["battletext"]) / hit_count,
			float(combat["hit_landed"]) / 1000.0, float(combat["hit_landed"]) / hit_count,
			float(combat["death"]) / 1000.0, float(combat["death"]) / 1000.0 / death_count,
			float(combat.get("death_listeners", 0)) / 1000.0 / death_count])
		# The tree's slowest ticks, with the engine split and what they asked for.
		var by_tick := range(_rows.size())
		by_tick.sort_custom(func(a: int, b: int) -> bool: return float(_rows[a]["asc_tick"]) > float(_rows[b]["asc_tick"]))
		report["slowest_ticks"] = []
		for i in by_tick.slice(0, mini(6, by_tick.size())):
			var row: Dictionary = _rows[i]
			report["slowest_ticks"].append(row)
			print("  slow tick t=%.2f %.2f ms %s | fragments %.2f ms (%d live; %d retargets %.2f ms; %d hits %.2f ms) | bullets %d damage calls %d queries %d | hits %.2f ms flush %.2f ms | enemies %d projectiles %d" % [row["t"], row["asc_tick"], str(row["engine_usec"]), row["frag_ms"], row["frag_live"], row["frag_retargets"], row["frag_retarget_ms"], row["frag_hits"], row["frag_hit_ms"], row["bullets"], row["damage_calls"], row["queries"], row["asc_hit"], row["asc_flush"], row["materialized"], row["projectiles"]])
		_slow_kills.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["ms"]) > float(b["ms"]))
		report["slow_kills"] = _slow_kills
		print("  scripted kills: %d, of which %d took 5 ms or more" % [_kills, _slow_kills.size()])
		for entry in _slow_kills.slice(0, mini(10, _slow_kills.size())):
			print("    kill t=%.2f %.1f ms  %s  added: %s" % [entry["t"], entry["ms"], entry["victim"], String(entry["added"]).left(260)])
		if _node_trace:
			var signatures: Array = _bursts.keys()
			signatures.sort_custom(func(a: String, b: String) -> bool: return int(_bursts[a]["count"]) > int(_bursts[b]["count"]))
			for signature in signatures.slice(0, mini(12, signatures.size())):
				var entry: Dictionary = _bursts[signature]
				print("  node burst x%d (%d nodes, tree tick avg %.2f max %.2f ms): %s" % [entry["count"], entry["nodes"], float(entry["asc_sum"]) / float(entry["count"]), entry["asc_max"], String(signature).left(300)])
			report["node_bursts"] = _bursts
		var file := FileAccess.open(_out, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
			print("CombatFramePhaseProbe: report ", ProjectSettings.globalize_path(_out))
		var rows_path := _env("PHASE_ROWS", "")
		if not rows_path.is_empty():
			var rows_file := FileAccess.open(rows_path, FileAccess.WRITE)
			if rows_file != null:
				for row in _rows:
					rows_file.store_line(JSON.stringify(row))
				rows_file.close()


func _ready() -> void:
	# Ambient population only, as in EnemyHordeBenchmark: authored beats add
	# protected specials on their own clock and would skew a held population.
	if Global != null and "debug_encounter_beats" in Global:
		Global.set("debug_encounter_beats", false)
	# The game scene replaces this one; the driver lives on the root.
	var driver := Driver.new()
	driver.name = "CombatFramePhaseDriver"
	driver.nodes = DEFAULT_NODES.duplicate()
	get_tree().root.call_deferred("add_child", driver)
