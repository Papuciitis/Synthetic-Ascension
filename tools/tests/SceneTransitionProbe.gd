extends Node

## What a scene change costs, by step. The flight recorder sees a run -> hub
## or hub -> run change as one frame of 0.5-2 s with nothing attributed (the
## 2026-10-01 "1.10 s gap" was a run -> hub change); this probe makes the same
## changes by hand so each step has its own clock:
##   save      Global.save_current_profile(false), as the hub's _ready does
##   load      ResourceLoader.load of the scene file (cold the first time a
##             scene is asked for, cached afterwards while something holds it)
##   instance  PackedScene.instantiate()
##   ready     adding the scene to the tree: every _ready in it
##   free      freeing the scene it replaces
##   settle    the next two frames (deferred work the new scene queued)
## It goes game -> hub -> game -> hub, so every scene is timed cold and warm.
## In the last hub it also opens each service panel (trade post, Gear &
## Stash, the Ascension tree) and times the open: the same captures show a
## 200-640 ms frame that adds 1,500-2,000 nodes in the hub, 17 times.
##
## Run: <godot> [--headless] --path . res://tools/tests/SceneTransitionProbe.tscn
## Env: TRANSITION_SEGMENT (9), TRANSITION_OUT (json path; default
##      user://scene_transition.json)

class Driver:
	extends Node

	var _report: Array = []
	var _panels: Array = []
	var _current: Node = null


	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		call_deferred(&"_run")


	func _env(key: String, fallback: String) -> String:
		var value := OS.get_environment(key).strip_edges()
		return value if not value.is_empty() else fallback


	func _run() -> void:
		Global.selected_style_id = &"ranged"
		Global.start_new_attempt()
		Global.attempt_segment = int(_env("TRANSITION_SEGMENT", "9"))
		Global.attempt_opening_completed = true
		Global.attempt_opening_phase = 10
		Global.debug_dev_segment = false
		Global.debug_dev_mode = true
		Global.debug_player_god_mode = true
		if "debug_encounter_beats" in Global:
			Global.set("debug_encounter_beats", false)
		# The probe scene itself is the first "previous scene".
		_current = get_tree().current_scene
		for step in [["game", Global.PATH_GAME], ["hub", Global.PATH_HUB_WORLD], ["game", Global.PATH_GAME], ["hub", Global.PATH_HUB_WORLD]]:
			await _change(String(step[0]), String(step[1]))
			# Let the scene run a moment, as it does in play, before leaving it.
			for i in range(90):
				await get_tree().process_frame
			get_tree().paused = false
		await _open_panels()
		var out := _env("TRANSITION_OUT", "user://scene_transition.json")
		var file := FileAccess.open(out, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"probe": "SceneTransitionProbe", "build": BuildInfo.describe(), "headless": DisplayServer.get_name() == "headless", "cpu": OS.get_processor_name(), "changes": _report, "hub_panels": _panels}, "\t"))
			file.close()
		print("SceneTransitionProbe: report ", ProjectSettings.globalize_path(out))
		get_tree().quit(0)


	func _change(label: String, path: String) -> void:
		var row := {"to": label, "nodes_before": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))}
		var clock := Time.get_ticks_usec()
		Global.save_current_profile(false)
		row["save_ms"] = _lap(clock)
		clock = Time.get_ticks_usec()
		row["cached"] = ResourceLoader.has_cached(path)
		var packed := load(path) as PackedScene
		row["load_ms"] = _lap(clock)
		clock = Time.get_ticks_usec()
		var scene := packed.instantiate()
		row["instance_ms"] = _lap(clock)
		clock = Time.get_ticks_usec()
		var previous := _current
		if previous != null and is_instance_valid(previous):
			get_tree().root.remove_child(previous)
			previous.free()
		row["free_ms"] = _lap(clock)
		clock = Time.get_ticks_usec()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		row["ready_ms"] = _lap(clock)
		_current = scene
		clock = Time.get_ticks_usec()
		await get_tree().process_frame
		await get_tree().process_frame
		row["settle_ms"] = _lap(clock)
		row["nodes_after"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		row["total_ms"] = snappedf(float(row["save_ms"]) + float(row["load_ms"]) + float(row["instance_ms"]) + float(row["free_ms"]) + float(row["ready_ms"]) + float(row["settle_ms"]), 0.1)
		_report.append(row)
		print("SceneTransitionProbe: -> %-4s total %7.1f ms | save %6.1f | load %6.1f (%s) | instance %6.1f | free previous %6.1f | ready %6.1f | settle (2 frames) %6.1f | nodes %d -> %d" % [
			label, row["total_ms"], row["save_ms"], row["load_ms"], ("cached" if row["cached"] else "cold"), row["instance_ms"], row["free_ms"], row["ready_ms"], row["settle_ms"], row["nodes_before"], row["nodes_after"]])


	## Each hub service panel, opened the way its station opens it.
	func _open_panels() -> void:
		var hub := _current
		for method in ["_open_merchant", "_open_gear", "_open_ascension"]:
			if hub == null or not hub.has_method(method):
				continue
			for attempt in ["first", "again"]:
				var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
				var clock := Time.get_ticks_usec()
				hub.call(method)
				var open_ms := _lap(clock)
				clock = Time.get_ticks_usec()
				await get_tree().process_frame
				await get_tree().process_frame
				var settle_ms := _lap(clock)
				var nodes_after := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
				_panels.append({"panel": method.trim_prefix("_open_"), "attempt": attempt, "open_ms": open_ms, "settle_ms": settle_ms, "nodes_added": nodes_after - nodes_before})
				print("SceneTransitionProbe: hub panel %-9s (%s) open %6.1f ms | settle (2 frames) %6.1f | nodes +%d" % [method.trim_prefix("_open_"), attempt, open_ms, settle_ms, nodes_after - nodes_before])
				var panel: Variant = hub.get("_open_panel")
				if panel != null and is_instance_valid(panel):
					(panel as Node).queue_free()
				hub.set("_open_panel", null)
				hub.set("_gear_screen", null)
				get_tree().paused = false
				for i in range(4):
					await get_tree().process_frame


	func _lap(started: int) -> float:
		return snappedf(float(Time.get_ticks_usec() - started) / 1000.0, 0.1)


func _ready() -> void:
	# The scenes replace this one; the driver lives on the root.
	var driver := Driver.new()
	driver.name = "SceneTransitionDriver"
	get_tree().root.call_deferred("add_child", driver)
