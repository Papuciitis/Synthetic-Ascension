extends Node

# Rendered-pixels probe for the Segment 1 story pass: runs the REAL game in a
# window, skips the scripted opening, and screenshots each new/reworked space
# (admissions wing, lab corridor, evidence route, overlook + city backdrop,
# gate plaza). Screenshots land in STORY_SHOT_DIR (env) or user://story_shots.
# Run: <godot> --path . res://tools/tests/Segment1StoryProbe.tscn  (needs a display)

class Driver:
	extends Node

	# name, cell (Level1 64px cells)
	const STOPS: Array = [
		["admissions_wing", Vector2i(9, 41)],
		["lab_corridor", Vector2i(15, 25)],
		["evidence_route", Vector2i(28, -10)],
		["overlook_city_reveal", Vector2i(49, -45)],
		["gate_plaza", Vector2i(20, -50)],
	]

	var _phase := 0
	var _elapsed := 0.0
	var _wall := 0.0
	var _shot_dir := ""
	var _busy := false

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_shot_dir = OS.get_environment("STORY_SHOT_DIR")
		if _shot_dir.is_empty():
			_shot_dir = ProjectSettings.globalize_path("user://story_shots")
		DirAccess.make_dir_recursive_absolute(_shot_dir)
		Global.start_new_attempt()
		Global.attempt_segment = 1
		Global.attempt_opening_completed = true
		Global.attempt_opening_phase = 10
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
		if _phase == 1 and _elapsed >= 4.0:
			_phase = 2
			_busy = true
			_visit_stops()

	func _visit_stops() -> void:
		var player := get_tree().get_first_node_in_group(&"player") as Node2D
		if player == null:
			push_error("FAIL: no player node")
			_finish(1)
			return
		for stop_variant in STOPS:
			var stop_name: String = stop_variant[0]
			var cell: Vector2i = stop_variant[1]
			var target := Vector2(cell.x * 64 + 32, cell.y * 64 + 32)
			player.global_position = target
			await get_tree().create_timer(2.5, true, false, true).timeout
			_dismiss_tutorial_cards()
			if get_tree().paused:
				_dismiss_blocking_ui()
			await get_tree().create_timer(0.5, true, false, true).timeout
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var path := _shot_dir.path_join("%s.png" % stop_name)
			var err := img.save_png(path)
			print("STORY shot %s at %s -> %s (err=%d)" % [stop_name, target, path, err])
		_finish(0)

	func _dismiss_tutorial_cards() -> void:
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
		print("Segment1StoryProbe: done, %d stops captured" % STOPS.size())
		get_tree().quit(code)


func _ready() -> void:
	var driver := Driver.new()
	get_tree().root.add_child.call_deferred(driver)
