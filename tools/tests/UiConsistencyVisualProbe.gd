extends Node

var _dir := ""


class ManifestationRunnerFixture:
	extends Node

	func get_active_summaries() -> Array[Dictionary]:
		return [{
			"slot": Inventory.SLOT_RING,
			"name": "Overtime Gospel",
			"rule": "Once the Exit Rite is ready, every 24 seconds you stay grants escalating Power.",
			"tags": [&"momentum", &"faith"],
		}]

	func get_active_pairs() -> Array[Dictionary]:
		return [{
			"name": "Death Rattle",
			"nouns": [&"ward", &"cadence"],
			"rule": "A spent ward completes the current cadence and seals the next wound.",
		}]

	func get_noun_counts() -> Dictionary:
		return {&"momentum": 2, &"faith": 2, &"cadence": 1}

	func get_meters() -> Array[Dictionary]:
		return [{"noun": &"cadence", "label": "CADENCE", "text": "1.9s"}]


class PlayerFixture:
	extends Node
	var hp := 137.0
	var max_hp := 137.0
	var armor := 1.0
	var speed := 222.0
	var power := 0.8493
	var haste := 0.69
	var luck := 1.19
	var stats: Variant = null
	var last_burden: BurdenSnapshot = null


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_dir = OS.get_environment("UI_CONSISTENCY_SHOT_DIR")
	if _dir.is_empty():
		_dir = ProjectSettings.globalize_path("user://ui_consistency_shots")
	DirAccess.make_dir_recursive_absolute(_dir)
	for resolution in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		if DisplayServer.get_name() != "headless":
			DisplayServer.window_set_size(resolution)
		await get_tree().process_frame
		await get_tree().process_frame
		var suffix := "%dx%d" % [resolution.x, resolution.y]
		await _capture_run_sheet_pages(suffix)
		await _capture_follower_notice(suffix)
		await _capture_scene("res://ui/screens/HubShop.tscn", "exchange-%s.png" % suffix)
	get_tree().quit(0)


func _capture_scene(path: String, file_name: String) -> void:
	var scene := load(path) as PackedScene
	var node := scene.instantiate()
	get_tree().root.add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture(file_name)
	node.queue_free()
	await get_tree().process_frame


func _capture_run_sheet_pages(suffix: String) -> void:
	var field := ColorRect.new()
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.color = Color(0.075, 0.07, 0.06, 1.0)
	get_tree().root.add_child(field)
	var scene := load("res://ui/widgets/RunSheetHUD.tscn") as PackedScene
	var run_sheet := scene.instantiate() as RunSheetHUD
	run_sheet.position = Vector2(24.0, 24.0)
	run_sheet.size = Vector2(430.0, 540.0)
	get_tree().root.add_child(run_sheet)
	var player := PlayerFixture.new()
	var runner := ManifestationRunnerFixture.new()
	runner.name = "ManifestationRunner"
	player.add_child(runner)
	get_tree().root.add_child(player)
	var saved_discoveries: Array[StringName] = Global.discovered_enemy_ids.duplicate()
	Global.discovered_enemy_ids.assign([
		&"enemy_grunt", &"enemy_runner", &"enemy_orbiter", &"enemy_spitter",
		&"enemy_sniper", &"enemy_charger", &"enemy_bomber", &"enemy_leech",
	])
	run_sheet.refresh(player, Inventory.new())
	var page_names := ["profile", "sets", "manifestations", "observations"]
	for page_index in range(page_names.size()):
		run_sheet.select_page(page_index)
		await get_tree().process_frame
		await _capture("run-sheet-%s-%s.png" % [page_names[page_index], suffix])
	Global.discovered_enemy_ids.assign(saved_discoveries)
	player.queue_free()
	run_sheet.queue_free()
	field.queue_free()
	await get_tree().process_frame


func _capture_follower_notice(suffix: String) -> void:
	var field := ColorRect.new()
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.color = Color(0.075, 0.07, 0.06, 1.0)
	get_tree().root.add_child(field)
	var script := load("res://ui/controllers/FollowerFeedbackUI.gd") as Script
	var feedback := script.new() as CanvasLayer
	get_tree().root.add_child(feedback)
	await get_tree().process_frame
	feedback.call("_on_transaction", 100, 2, 102, &"combat_influence", {}, true, true)
	feedback.call("_process", 0.91)
	await get_tree().process_frame
	await _capture("witness-notice-%s.png" % suffix)
	feedback.queue_free()
	field.queue_free()
	await get_tree().process_frame


func _capture_blocking_record() -> void:
	var overlay_scene := load("res://ui/screens/TutorialCardOverlay.tscn") as PackedScene
	var overlay := overlay_scene.instantiate()
	get_tree().root.add_child(overlay)
	await get_tree().process_frame
	overlay.call(
		"present",
		"RESONANT VESSEL",
		"The institution has recorded a stable correspondence between the vessel and the district lattice.\n\nContinue only when the containment geometry is understood.",
		"PATTERN RECORD",
		null,
		-1
	)
	overlay.call("_complete_reveal")
	await get_tree().process_frame
	await _capture("blocking_record.png")
	overlay.queue_free()
	await get_tree().process_frame


func _capture_first_encounter() -> void:
	var field := ColorRect.new()
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.color = Color(0.10, 0.085, 0.065, 1)
	get_tree().root.add_child(field)
	var target := Sprite2D.new()
	target.texture = load("res://icon.svg") as Texture2D
	target.position = Vector2(910, 610)
	target.scale = Vector2(0.34, 0.34)
	get_tree().root.add_child(target)
	var overlay_scene := load("res://ui/overlays/FirstEncounterOverlay.tscn") as PackedScene
	var overlay := overlay_scene.instantiate()
	get_tree().root.add_child(overlay)
	await get_tree().process_frame
	overlay.call("present", {
		"name": "Containment Officer",
		"role": "Melee pursuer",
		"counter": "Keep moving and use doors or cover to divide the group.",
	}, target, target.texture, "Health: Low  •  Speed: Medium  •  Range: Contact  •  Threat: Basic")
	overlay.call("_process", 0.81)
	await get_tree().process_frame
	await _capture("first_encounter.png")
	overlay.queue_free()
	target.queue_free()
	field.queue_free()
	await get_tree().process_frame


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	var path := "%s/%s" % [_dir, file_name]
	print("UI consistency shot -> %s (err=%d)" % [path, image.save_png(path)])
