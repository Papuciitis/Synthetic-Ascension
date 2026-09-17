extends Node

# Probe for the batched enemy visuals: runs the REAL game, spawns a horde, then
# teleports the player progressively far from spawn and reports the renderer's
# batch state at each stop, saving a screenshot too when there is a display.
# Guards the emit_changed()/culling-rect fix in two halves, at every stop:
# the dragged horde must reach the multimeshes, AND every live batch must emit
# the multimesh `changed` signal, which is the notification MultiMeshInstance2D
# turns into the queue_redraw() that recomputes the culling rect - the rect
# that used to stay stale-empty once the camera left the world origin.
# Screenshots land in ROAM_SHOT_DIR (env) or user://roam_shots.
#
# What a headless run cannot see: the culling rect itself, or a pixel. There is
# no rasterizer, so the change signal is the last observable link in that chain
# and is what the headless assertions pin; a windowed run's screenshots remain
# the only thing that shows the horde actually drawn.
#
# The screenshots need a display; the batch bookkeeping does not, and that is
# the thing this probe exists to observe. It used to await
# RenderingServer.frame_post_draw at every stop - which never fires headless -
# so a headless run got one stop in, hung, and was killed at exit 0 having
# checked nothing; and even with a display it called _finish(0) unconditionally.

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
	var _passes := 0
	var _failures := 0
	var _reported := 0
	var _captured := 0

	## Enemies dragged to each stop by _drag_enemies_to; every one of them must
	## be published into the renderer's batches at that stop. This is the
	## "reaches the batch" half of the roam check - the culling-rect half is
	## the per-stop `changed` assertion in _report_and_shoot.
	const DRAGGED_PER_STOP: int = 40

	## Batch MultiMesh instance id -> `changed` emissions since the current stop
	## began, zeroed by _watch_batches at the top of each stop. MultiMesh emits
	## `changed` only from emit_changed(): assigning buffer, instance_count or
	## visible_instance_count does not (checked against 4.7), so this counts the
	## renderer's emit_changed() calls and nothing else.
	var _batch_changes: Dictionary = {}

	func _check(condition: bool, message: String) -> void:
		if condition:
			_passes += 1
			print("PASS: ", message)
		else:
			_failures += 1
			push_error("FAIL: " + message)

	func _can_capture() -> bool:
		return DisplayServer.get_name() != "headless"

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
		_check(spawner != null and filter != null, "the run has a spawner and a spawn filter")
		if spawner == null or filter == null:
			_finish(1)
			return
		filter.set("cap_mode", 2) # UNLIMITED
		spawner.call("debug_force_spawn", 120)
		_busy = false

	func _visit_stops() -> void:
		var player := get_tree().get_first_node_in_group(&"player") as Node2D
		_check(player != null, "the run has a player to roam with")
		if player == null:
			_finish(1)
			return
		_start_pos = player.global_position
		for i in range(STOPS.size()):
			_stop_index = i
			var target := _start_pos + STOPS[i]
			player.global_position = target
			_drag_enemies_to(target)
			_watch_batches()
			await get_tree().create_timer(2.0).timeout
			if _can_capture():
				await RenderingServer.frame_post_draw
			_report_and_shoot(i, target)
		_check(
			_reported == STOPS.size(),
			"every stop reported its batch state (%d of %d)" % [_reported, STOPS.size()]
		)
		if _can_capture():
			_check(
				_captured == STOPS.size(),
				"every stop was captured (%d of %d)" % [_captured, STOPS.size()]
			)
		else:
			print("ROAM headless: no display, %d screenshots skipped" % STOPS.size())
		_finish(1 if _failures > 0 else 0)

	func _on_batch_changed(mesh_id: int) -> void:
		_batch_changes[mesh_id] = int(_batch_changes.get(mesh_id, 0)) + 1

	func _watch_batches() -> void:
		# Subscribe to every batch multimesh's `changed` (once each) and zero the
		# counters, so the stop about to be reported counts only its own
		# emissions. A batch first seen mid-stop stays uncounted until the next
		# stop rather than reading as a batch that never emitted.
		var proxy_root := get_tree().get_first_node_in_group(&"enemy_proxy_root")
		if proxy_root == null:
			return
		var renderer: Node = proxy_root.get("renderer")
		if renderer == null:
			return
		for child in renderer.get_children():
			var mm := child as MultiMeshInstance2D
			if mm == null or mm.multimesh == null:
				continue
			var mesh_id := mm.multimesh.get_instance_id()
			if not _batch_changes.has(mesh_id):
				mm.multimesh.changed.connect(_on_batch_changed.bind(mesh_id))
			_batch_changes[mesh_id] = 0

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
		_check(proxy_root != null, "stop=%d has a proxy root to report on" % index)
		if proxy_root == null:
			return
		var renderer: Node = proxy_root.get("renderer")
		_check(renderer != null, "stop=%d has a proxy renderer" % index)
		if renderer == null:
			return
		var visible_instances := int(renderer.call("visible_count"))
		print("ROAM stop=%d pos=%s actors=%s visible=%d batches=%s" % [
			index, target,
			renderer.call("registered_actor_count"),
			visible_instances,
			renderer.call("batch_count"),
		])
		var batched: int = 0
		# Batches watched since the top of this stop that currently carry
		# instances, and how many of those emitted `changed` while it ran.
		var live_batches: int = 0
		var signalled_batches: int = 0
		for child in renderer.get_children():
			var mm := child as MultiMeshInstance2D
			if mm != null and mm.multimesh != null:
				batched += mm.multimesh.visible_instance_count
				var changes := int(_batch_changes.get(mm.multimesh.get_instance_id(), -1))
				print("ROAM   batch %s vis=%d inst=%d visible=%s changed=%d" % [
					mm.name, mm.multimesh.visible_instance_count,
					mm.multimesh.instance_count, mm.visible, changes,
				])
				if changes >= 0 and mm.multimesh.visible_instance_count > 0:
					live_batches += 1
					if changes > 0:
						signalled_batches += 1
		# Half one of the roam regression: the dragged horde must reach the
		# batches at every stop, not only the one at the world origin.
		_check(
			visible_instances >= DRAGGED_PER_STOP,
			"stop=%d keeps the dragged horde batched (%d visible, expected >= %d)"
				% [index, visible_instances, DRAGGED_PER_STOP]
		)
		_check(
			batched >= DRAGGED_PER_STOP,
			"stop=%d publishes them into the multimeshes (%d instances)" % [index, batched]
		)
		# Half two, and the one the fix is actually made of: filling a multimesh
		# is not the same as the canvas item knowing it was filled.
		# MultiMeshInstance2D recomputes its culling rect only when the multimesh
		# emits `changed`; without that emission the item keeps the rect it had
		# while empty and the batch is culled away as soon as the camera leaves
		# the world origin. Every batch still holding instances was republished
		# during this stop - publish() hides any batch it skips - so every one
		# of them must have emitted.
		_check(
			live_batches > 0 and signalled_batches == live_batches,
			"stop=%d refreshed every live batch's culling rect (%d of %d emitted changed)"
				% [index, signalled_batches, live_batches]
		)
		_reported += 1
		if not _can_capture():
			return
		var img := get_viewport().get_texture().get_image()
		var path := _shot_dir.path_join("stop_%d.png" % index)
		var err := img.save_png(path)
		print("ROAM screenshot stop=%d -> %s (err=%d)" % [index, path, err])
		_check(err == OK, "stop=%d screenshot was written (err=%d)" % [index, err])
		_captured += 1

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
		print("RoamVisibilityProbe: %d passed, %d failed, %d stops reported, %d captured" % [
			_passes, _failures, _reported, _captured,
		])
		get_tree().quit(code)


func _ready() -> void:
	var driver := Driver.new()
	get_tree().root.add_child.call_deferred(driver)
