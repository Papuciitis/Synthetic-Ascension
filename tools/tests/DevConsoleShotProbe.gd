extends Node

## Opens the developer console, walks its Tests sub-tabs and screenshots each,
## then presses every pair shortcut and checks it lights its pair.
##
## The Tests tab is built in code from catalogs, so it has no scene file to
## eyeball - the only way to see whether it still lays out sensibly after a rule
## is added is to render it. Shots land in DEV_SHOT_DIR (env) or
## user://dev_shots.
##
## The screenshots need a display; the pair-shortcut checks do not, and they
## exist nowhere else in the suite. The capture used to await
## RenderingServer.frame_post_draw unconditionally, which never fires headless,
## so a headless run hung there and _verify_pair_shortcut never ran at all -
## under the documented sweep command (--quit-after 3000) that is a green run
## that checked nothing, because the frame budget expires long before the 110 s
## watchdog.

var _dir: String = ""


var _is_worker: bool = false


func _can_capture() -> bool:
	return DisplayServer.get_name() != "headless"


func _ready() -> void:
	if _is_worker:
		# Never hang a run: if anything below stalls, bail loudly.
		get_tree().create_timer(110.0).timeout.connect(func() -> void:
			push_error("DevConsoleShotProbe timed out")
			get_tree().quit(1)
		)
		_run.call_deferred()
		return
	_dir = OS.get_environment("DEV_SHOT_DIR")
	if _dir.is_empty():
		_dir = ProjectSettings.globalize_path("user://dev_shots")
	DirAccess.make_dir_recursive_absolute(_dir)
	# The work has to outlive the scene change that goto_game() performs, so it
	# runs on a node parented to the tree root rather than on this scene.
	var worker := Node.new()
	worker.name = "DevConsoleShotWorker"
	worker.process_mode = Node.PROCESS_MODE_ALWAYS
	worker.set_script(get_script())
	worker.set("_dir", _dir)
	worker.set("_is_worker", true)
	get_tree().root.add_child.call_deferred(worker)


func _run() -> void:
	# Get into an actual run first. Half these controls act on the player and
	# the run inventory, so screenshotting them against the menu would prove
	# only that the labels render.
	Global.start_new_attempt()
	Global.attempt_segment = 1
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.debug_dev_segment = false
	Global.debug_dev_mode = true
	Global.debug_player_god_mode = true
	Global.goto_game()
	for _wait in range(240):
		await get_tree().process_frame
		if get_tree().get_first_node_in_group(&"player") != null:
			break
	var console: Control = (load("res://ui/widgets/PerformanceOverlay.tscn") as PackedScene).instantiate() as Control
	get_tree().root.add_child(console)
	await get_tree().process_frame
	console.visible = true
	console.size = Vector2(1120, 760)
	console.position = Vector2(60, 60)

	var tabs := console.get_node_or_null("Margin/Root/Tabs") as TabContainer
	var tests_index := -1
	for i in range(tabs.get_tab_count()):
		if tabs.get_tab_title(i) == "Tests":
			tests_index = i
	if tests_index < 0:
		push_error("no Tests tab")
		get_tree().quit(1)
		return
	tabs.current_tab = tests_index

	var inner := console.get_node_or_null("Margin/Root/Tabs/Tests/DevRoot/TestTabs") as TabContainer
	if inner == null:
		# Named container, one child per page - if this fails the tab did not build.
		push_error("Tests tab did not build its sub-tabs")
		get_tree().quit(1)
		return

	_check(inner.get_tab_count() > 0, "the Tests tab built sub-tabs to walk (%d)" % inner.get_tab_count())
	var captured := 0
	for i in range(inner.get_tab_count()):
		inner.current_tab = i
		for _f in range(3):
			await get_tree().process_frame
		if not _can_capture():
			continue
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/dev_%s.png" % [_dir, inner.get_tab_title(i).to_lower()]
		var err := image.save_png(path)
		print("DEV shot %s -> %s (err=%d)" % [inner.get_tab_title(i), path, err])
		_check(err == OK, "the %s sub-tab was captured (err=%d)" % [inner.get_tab_title(i), err])
		captured += 1

	if _can_capture():
		_check(
			captured == inner.get_tab_count(),
			"every sub-tab was captured (%d of %d)" % [captured, inner.get_tab_count()]
		)
	else:
		print("DEV headless: no display, %d sub-tab screenshots skipped" % inner.get_tab_count())
	print("DevConsoleShotProbe: %d sub-tabs captured" % captured)
	_verify_pair_shortcut()
	print("DevConsoleShotProbe: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


var _failures: int = 0
var _passes: int = 0


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("  ok: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)


## A button that renders is not a button that works. The pair shortcuts are the
## whole reason this tab exists - ten authored payoffs that the ordinary roll
## reaches only through a specific and uncommon loadout.
func _verify_pair_shortcut() -> void:
	var tools := get_node_or_null("/root/DevSetCollisionTools")
	var player := get_tree().get_first_node_in_group(&"player")
	if tools == null or player == null:
		_check(false, "dev service and player both present")
		return
	var runner := player.get_node_or_null("ManifestationRunner")
	if runner == null:
		_check(false, "player carries a ManifestationRunner")
		return
	tools.call("clear_manifestations")
	var ids: Array = ManifestationPairCatalog.all_ids()
	_check(ids.size() == 10, "every noun pair is authored (%d)" % ids.size())
	var lit: int = 0
	for pair_id in ids:
		tools.call("clear_manifestations")
		var placed: int = int(tools.call("grant_pair", pair_id))
		var active: int = int(runner.call("active_pair_count"))
		if active > 0:
			lit += 1
		else:
			print("  pair '%s' placed %d rules, lit %d" % [String(pair_id), placed, active])
	_check(lit == ids.size(), "every pair shortcut actually lights its pair (%d/%d)" % [lit, ids.size()])
	tools.call("clear_manifestations")
