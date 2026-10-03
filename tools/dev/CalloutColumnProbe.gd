extends Node
## Screenshots BattleText callout columns over a real segment (needs a
## display, not --headless): Manifestation callouts fired at the player a few
## frames apart (mid-burst, end of burst, after), the same-frame case, a ten
## line burst against the column cap, a burst while the player runs, a world
## column on the ground with player damage numbers beside the player's, and
## the Reduced Motion push. Each shot is saved whole and as a crop around the
## player. A throwaway attempt with no current save; the player is
## invulnerable and the spawner is held so the shots stay comparable.
##   <godot> --path . res://tools/dev/CalloutColumnProbe.tscn -- --out=/abs/dir [--segment=2] [--seed=n] [--only=still,frame,cap,run,world,reduced]

const CROP := Vector2i(720, 520)

var _out := "/tmp"
var _segment := 2
var _seed := 424242
var _only := ""
var _is_worker := false
var _player: Node2D = null
var _fx: ManifestationEffect = null


func _ready() -> void:
	if _is_worker:
		get_tree().create_timer(300.0, true, false, true).timeout.connect(func() -> void:
			push_error("CalloutColumnProbe timed out")
			get_tree().quit(1)
		)
		_run.call_deferred()
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--segment="):
			_segment = int(arg.trim_prefix("--segment="))
		elif arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(_out)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(1784, 1004))
	# Must outlive goto_game()'s scene change.
	var worker := Node.new()
	worker.name = "CalloutColumnWorker"
	worker.process_mode = Node.PROCESS_MODE_ALWAYS
	worker.set_script(get_script())
	for key in ["_out", "_segment", "_seed", "_only"]:
		worker.set(key, get(key))
	worker.set("_is_worker", true)
	get_tree().root.add_child.call_deferred(worker)


func _want(shot_name: String) -> bool:
	return _only == "" or shot_name in _only.split(",")


## Wall-clock waits, frame by frame: a screenshot can stall one frame for
## seconds, and a timer would spend that whole stall at once.
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	await get_tree().process_frame
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out, shot_name]
	image.save_png(path)
	# The crop: the player's screen point, scaled from the logical viewport to
	# the rendered image.
	var ratio := Vector2(image.get_size()) / get_viewport().get_visible_rect().size
	var at := (_player.get_global_transform_with_canvas().origin * ratio) if _player != null else Vector2(image.get_size()) * 0.5
	var corner := Vector2i(at) - Vector2i(CROP.x / 2, CROP.y * 3 / 4)
	corner = corner.clamp(Vector2i.ZERO, image.get_size() - CROP)
	image.get_region(Rect2i(corner, CROP)).save_png("%s/%s_crop.png" % [_out, shot_name])
	print("CalloutColumnProbe -> ", path)


## The rule lines a busy kill can trip, through ManifestationEffect.popup -
## the path the Manifestations use - so the real call is what gets drawn.
const LINES := [
	["COMPOSED", Color(0.55, 0.85, 1.0, 1.0), 1.15],
	["TITHE - SECOND SHOT", Color(1.0, 0.84, 0.3, 1.0), 1.25],
	["RED MIST", Color(0.9, 0.1, 0.1, 1.0), 1.6],
	["LUCKY", Color(1.0, 0.84, 0.25, 1.0), 1.2],
	["HEAT 3", Color(1.0, 0.6, 0.2, 1.0), 1.1],
	["SCAR +2 ARMOUR", Color(0.85, 0.7, 0.6, 1.0), 1.15],
	["VENT", Color(1.0, 0.5, 0.2, 1.0), 1.3],
	["EVADED", Color(0.5, 0.9, 1.0, 1.0), 1.1],
	["FIRING SQUAD", Color(1.0, 0.9, 0.6, 1.0), 1.6],
	["second breakfast", Color(0.95, 0.85, 0.55, 0.95), 1.1],
]


func _say(index: int) -> void:
	var line: Array = LINES[index % LINES.size()]
	_fx.popup(String(line[0]), line[1], float(line[2]))


func _run() -> void:
	SaveManager.current_save = null
	Global.start_new_attempt()
	Global.attempt_segment = _segment
	Global.attempt_world_seed = _seed
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.pending_augment_pick = false
	Global.tip_shown_intro_move = true
	Global.debug_encounter_beats = false
	Global.debug_player_god_mode = true
	Global.goto_game()
	for _i in range(900):
		await get_tree().process_frame
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
		if _player != null:
			break
	if _player == null:
		push_error("CalloutColumnProbe: no player")
		get_tree().quit(1)
		return
	await _settle(120)
	var spawner := get_tree().get_first_node_in_group(&"enemy_spawner")
	if spawner != null and spawner.has_method("suspend_spawning"):
		spawner.call("suspend_spawning", 9999.0)
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if enemy is Node and is_instance_valid(enemy):
			(enemy as Node).queue_free()
	_fx = ManifestationEffect.new()
	_fx.name = "CalloutProbeRule"
	_fx.player = _player
	add_child(_fx)
	await _settle(30)
	BattleText.clear()

	if _want("still"):
		# Six rules a few frames apart while standing still.
		for k in range(6):
			_say(k)
			await _wait(0.05)
			if k == 2:
				await _shot("still_mid_burst")
		await _shot("still_end_of_burst")
		await _wait(0.35)
		await _shot("still_after")
		await _wait(1.2)

	if _want("frame"):
		# Four rules off one kill, all in the same frame.
		for k in range(4):
			_say(k + 3)
		await _wait(0.15)
		await _shot("same_frame")
		await _wait(1.2)

	if _want("cap"):
		for k in range(10):
			_say(k)
			await _wait(0.02)
		await _shot("cap_burst")
		await _wait(0.3)
		await _shot("cap_after")
		await _wait(1.2)

	if _want("run"):
		Input.action_press(&"move_right")
		await _wait(0.4)
		for k in range(5):
			_say(k + 1)
			await _wait(0.08)
			if k == 2:
				await _shot("run_mid_burst")
		await _shot("run_end_of_burst")
		Input.action_release(&"move_right")
		Input.action_press(&"move_down")
		await _wait(0.3)
		await _shot("run_turned")
		Input.action_release(&"move_down")
		await _wait(1.2)

	if _want("world"):
		# A world column off to one side (a shield-bearer blocking, a leech)
		# while the player's column runs, with player damage numbers.
		var ground := _player.global_position + Vector2(260.0, 40.0)
		for k in range(4):
			BattleText.popup(ground, "BLOCKED" if k < 3 else "SIPHONED 4", Color(0.7, 0.85, 1.0, 0.9) if k < 3 else Color(0.7, 0.55, 1.0, 0.95), 0.8 if k < 3 else 0.9)
			_say(k)
			BattleText.player_damage(_player.global_position, 11.0 + k * 7.0)
			await _wait(0.07)
		await _shot("world_and_player")
		await _wait(1.2)

	if _want("reduced"):
		SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
		for k in range(5):
			_say(k)
			await _wait(0.05)
		await _shot("reduced_motion")
		SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
		await _wait(1.2)

	print("CalloutColumnProbe: done -> ", _out)
	get_tree().quit(0)


func _settle(frames: int) -> void:
	for _f in range(frames):
		await get_tree().process_frame
		if get_tree().paused:
			_unblock()


func _unblock() -> void:
	_strip(get_tree().root)
	get_tree().paused = false


func _strip(node: Node) -> void:
	var script: Variant = node.get_script()
	if script != null:
		var path := String(script.resource_path)
		if path.ends_with("TutorialModalController.gd"):
			node.queue_free()
			return
		if path.ends_with("TutorialCardOverlay.gd") and node.has_method("_dismiss"):
			node.call("_dismiss")
	if node.has_method("open_choose_3"):
		node.queue_free()
		return
	var button := node as Button
	if button != null and button.visible and button.text.strip_edges().to_lower() == "continue":
		button.emit_signal("pressed")
	for child in node.get_children():
		_strip(child)
