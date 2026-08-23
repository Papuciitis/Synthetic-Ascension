extends Node

# Rendered-pixels probe for the batched enemy visuals: runs the REAL game in a
# window (needs a display — headless's dummy renderer cannot cull or draw),
# spawns a horde, then teleports the player progressively far from spawn and
# saves a screenshot at each stop. Verifies the emit_changed()/culling-rect fix:
# batches must stay visible wherever the camera roams, not just near the world
# origin. Screenshots land in ROAM_SHOT_DIR (env) or user://roam_shots.

class Driver:
	extends Node

	const STOPS: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(3000, 0),
		Vector2(7000, 4000),
		Vector2(-9000, -5000),
		Vector2(18000, 12000),
	]

	var _phase := 0
	var _elapsed := 0.0
	var _wall := 0.0
	var _stop_index := 0
	var _start_pos := Vector2.ZERO
	var _shot_dir := ""
	var _busy := false

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_shot_dir = OS.get_environment("ROAM_SHOT_DIR")
		if _shot_dir.is_empty():
			_shot_dir = ProjectSettings.globalize_path("user://roam_shots")
		DirAccess.make_dir_recursive_absolute(_shot_dir)
		Global.start_new_attempt()
		Global.attempt_segment = 2
		Global.debug_dev_segment = false
		Global.debug_dev_mode = true
		Global.debug_player_god_mode = true
		_phase = 1
		Global.goto_game()

	func _process(delta: float) -> void:
		if _phase < 1:
			return
		_dismiss_tutorial_cards()
		if _busy:
			return
		_wall += delta
		if get_tree().paused:
			if _wall >= 2.0:
				_dismiss_blocking_ui()
			return
		_elapsed += delta
		if _phase == 1 and _elapsed >= 5.0:
			_phase = 2
			_busy = true
			_spawn_horde()
		elif _phase == 2 and _elapsed >= 9.0:
			_phase = 3
			_busy = true
			_visit_stops()

	func _spawn_horde() -> void:
		var spawner := get_tree().get_first_node_in_group(&"enemy_spawner")
		var filter := get_node_or_null("/root/DebugEnemySpawnFilter")
		if spawner == null or filter == null:
			push_error("FAIL: spawner or spawn filter missing")
			_finish(1)
			return
		filter.set("cap_mode", 2) # UNLIMITED
		spawner.call("debug_force_spawn", 120)
		_busy = false

	func _visit_stops() -> void:
		var player := get_tree().get_first_node_in_group(&"player") as Node2D
		if player == null:
			push_error("FAIL: no player node")
			_finish(1)
			return
		_start_pos = player.global_position
		for i in range(STOPS.size()):
			_stop_index = i
			var target := _start_pos + STOPS[i]
			player.global_position = target
			_drag_enemies_to(target)
			await get_tree().create_timer(2.0).timeout
			await RenderingServer.frame_post_draw
			_report_and_shoot(i, target)
		_finish(0)

	func _drag_enemies_to(center: Vector2) -> void:
		# Teleport through EnemyWorld records, not just nodes: node moves
		# alone leave stale record positions behind, and the representation
		# policy/proxy sim act on the records. Materialized actors get their
		# node moved too (the node is authoritative until demotion).
		var world := get_node_or_null("/root/EnemyWorld")
		if world == null:
			return
		var handles: Array[int] = []
		world.call("active_handles", handles)
		var moved := 0
		for handle in handles:
			var angle := TAU * float(moved) / 40.0
			var target: Vector2 = center + Vector2.RIGHT.rotated(angle) * (180.0 + 12.0 * (moved % 5))
			world.call("set_position", handle, target)
			world.call("reset_interpolation", handle)
			var actor := world.call("actor_for_handle", handle) as Node2D
			if actor != null and is_instance_valid(actor):
				actor.global_position = target
			moved += 1
			if moved >= 40:
				break
		print("ROAM dragged %d enemies to %s" % [moved, center])

	func _report_and_shoot(index: int, target: Vector2) -> void:
		var proxy_root := get_tree().get_first_node_in_group(&"enemy_proxy_root")
		if proxy_root != null:
			var renderer: Node = proxy_root.get("renderer")
			if renderer != null:
				print("ROAM stop=%d pos=%s actors=%s visible=%s batches=%s" % [
					index, target,
					renderer.call("registered_actor_count"),
					renderer.call("visible_count"),
					renderer.call("batch_count"),
				])
				for child in renderer.get_children():
					var mm := child as MultiMeshInstance2D
					if mm != null and mm.multimesh != null:
						print("ROAM   batch %s vis=%d inst=%d visible=%s" % [
							mm.name, mm.multimesh.visible_instance_count,
							mm.multimesh.instance_count, mm.visible,
						])
		var img := get_viewport().get_texture().get_image()
		var path := _shot_dir.path_join("stop_%d.png" % index)
		var err := img.save_png(path)
		print("ROAM screenshot stop=%d -> %s (err=%d)" % [index, path, err])

	func _dismiss_tutorial_cards() -> void:
		# First-encounter dossier cards dim the whole screen; a screenshot
		# probe needs the world unobstructed, so dismiss them as they appear.
		for node in get_tree().root.find_children("*", "", true, false):
			var script: Script = node.get_script() as Script
			if script != null and script.resource_path.ends_with("TutorialCardOverlay.gd"):
				node.call("_dismiss")

	func _dismiss_blocking_ui() -> void:
		var scene := get_tree().current_scene
		var ui := scene.get_node_or_null("UI") if scene != null else null
		if ui != null:
			for child in ui.get_children():
				if child.has_method("open_choose_3"):
					child.queue_free()
		get_tree().paused = false

	func _finish(code: int) -> void:
		print("RoamVisibilityProbe: done, %d stops captured" % STOPS.size())
		get_tree().quit(code)


func _ready() -> void:
	var driver := Driver.new()
	get_tree().root.add_child.call_deferred(driver)
