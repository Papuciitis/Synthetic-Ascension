extends Node

## Renders the Run Sheet's four pages, the witness notice and the Exchange at
## two resolutions and saves a screenshot of each, so the layouts can be
## eyeballed side by side. Shots land in UI_CONSISTENCY_SHOT_DIR (env) or
## user://ui_consistency_shots.
##
## The screenshots need a display; building the fixtures does not, and every
## capture asserts that the widget it is about to photograph actually built
## something. The probe used to await RenderingServer.frame_post_draw in
## _capture, which never fires headless, so a headless run printed nothing at
## all and was killed at exit 0 - and even with a display it had no assertions
## and called quit(0) unconditionally.

## Captures a windowed run must produce: four Run Sheet pages, the witness
## notice and the Exchange, at each of the two resolutions.
const EXPECTED_CAPTURES: int = 12

## RunSheetHUD's page controls under $Archive/BodyMargin/Pages, in the order
## select_page() indexes them. Each page assertion reads its own control.
const PAGE_NODE_NAMES: Array[String] = [
	"ProfileScroll", "SetsScroll", "ManifestationsScroll", "ObservationsScroll",
]

var _dir := ""
var _passes := 0
var _failures := 0
var _captured := 0


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _can_capture() -> bool:
	return DisplayServer.get_name() != "headless"


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
	if _can_capture():
		_check(
			_captured == EXPECTED_CAPTURES,
			"every screen was captured (%d of %d)" % [_captured, EXPECTED_CAPTURES]
		)
	else:
		print("UI consistency headless: no display, %d screenshots skipped" % EXPECTED_CAPTURES)
	print("UiConsistencyVisualProbe: %d passed, %d failed, %d captured" % [
		_passes, _failures, _captured,
	])
	get_tree().quit(1 if _failures > 0 else 0)


func _capture_scene(path: String, file_name: String) -> void:
	var scene := load(path) as PackedScene
	_check(scene != null, "%s loads" % path.get_file())
	if scene == null:
		return
	var node := scene.instantiate()
	get_tree().root.add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(
		_collect_label_text(node).strip_edges() != "",
		"%s renders text to photograph" % path.get_file()
	)
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
		# Read the page control itself, not the whole RunSheetHUD: the four
		# page-selector buttons at $Archive/Index/* keep their "◆  PROFILE" /
		# "◇  SETS" text whatever page is showing, so a check over the whole
		# subtree passed even with every page hidden - the empty-panel
		# photograph these checks exist to distinguish.
		var page := run_sheet.get_node_or_null(
			"Archive/BodyMargin/Pages/%s" % PAGE_NODE_NAMES[page_index]
		) as Control
		_check(
			page != null and page.is_visible_in_tree(),
			"the Run Sheet's %s page is the one on screen (%s)" % [
				page_names[page_index], suffix,
			]
		)
		_check(
			page != null and _collect_label_text(page).strip_edges() != "",
			"the Run Sheet's %s page renders text to photograph (%s)" % [
				page_names[page_index], suffix,
			]
		)
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
	_check(
		_collect_label_text(feedback).strip_edges() != "",
		"the witness notice renders text to photograph (%s)" % suffix
	)
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
	if not _can_capture():
		return
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	var path := "%s/%s" % [_dir, file_name]
	var err := image.save_png(path)
	print("UI consistency shot -> %s (err=%d)" % [path, err])
	_check(err == OK, "%s was written (err=%d)" % [file_name, err])
	_captured += 1


func _collect_label_text(node: Node) -> String:
	# A hidden branch is not in the photograph, so it must not satisfy a
	# "renders text to photograph" check; recursion stops there the way
	# drawing does.
	if node is CanvasItem and not (node as CanvasItem).visible:
		return ""
	if node is CanvasLayer and not (node as CanvasLayer).visible:
		return ""
	var parts := PackedStringArray()
	if node is Label:
		parts.append((node as Label).text)
	elif node is RichTextLabel:
		parts.append((node as RichTextLabel).get_parsed_text())
	elif node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		parts.append(_collect_label_text(child))
	return "".join(parts)
