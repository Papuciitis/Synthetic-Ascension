extends Node
## Renders the Ascension tree screen to PNGs (needs a display, not --headless):
## the opening unfurl, an owned lattice with an equipped Q, hover, a purchase
## burst, a close zoom, the purchase confirmation (plain and Gate) and the V5
## tree. A throwaway attempt with no current save, so nothing is written to the
## player's slots.
## Run: <godot> --path . res://tools/dev/AscensionShotProbe.tscn -- --out=/abs/dir
##        [--only=open|owned|hover|burst|zoom|confirm|v5|perf] [--reduced]
## `perf` prints frame timings (vsync off) idle, while panning and while the
## opening plays, instead of shots; it runs only when asked for.

var _out := "/tmp"
var _only := ""
var _reduced := false
var _was_reduced: Variant = false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
		elif arg == "--reduced":
			_reduced = true
	DirAccess.make_dir_recursive_absolute(_out)
	SaveManager.current_save = null
	Global.debug_disable_autosave = true
	_was_reduced = SettingsManager.get_value(&"accessibility", &"reduced_motion", false)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", _reduced, false)
	if not Global.attempt_active:
		Global.start_new_attempt()
	Global.transaction_followers(6000 - Global.followers, &"dev_grant", {}, false, false)
	await _wait(0.3)
	var suffix := "_reduced" if _reduced else ""
	if _want("open"):
		var screen := await _open("v4")
		await _wait(0.12)
		await _shot("open_early" + suffix)
		await _wait(0.3)
		await _shot("open_mid" + suffix)
		await _wait(1.4)
		await _shot("open" + suffix)
		await _close(screen)
	if _want("glide"):
		# Nothing bought: after the unfurl the camera glides into the core.
		var fresh := await _open("v4")
		for when in [1.5, 2.3, 3.6]:
			await _wait(when - (0.0 if when == 1.5 else (1.5 if when == 2.3 else 2.3)))
			await _shot("glide_core_%d" % int(when * 10.0) + suffix)
		await _close(fresh)
		# With a path bought: it glides to the furthest, biggest owned node.
		Global.transaction_followers(200000 - Global.followers, &"dev_grant", {}, false, false)
		var again := await _open("v4")
		var gv: Control = again.get("view")
		var owned_ids: Array = []
		for id in ["EX01", "EX03", "EX02", "EX04", "EX05", "EX06", "EX07", "EX08", "EX09", "EX10", "EXQ", "EXK1", "EXF2", "EX11", "EX12"]:
			if bool(Global.ascension_buy(id)["ok"]):
				owned_ids.append(id)
		again.call("_refresh_all")
		gv.call("fit")
		gv.call("replay_opening")
		print("GLIDE owned=", owned_ids, " target=", gv.call("_glide_target"))
		for when in [1.5, 2.3, 3.6]:
			await _wait(when - (0.0 if when == 1.5 else (1.5 if when == 2.3 else 2.3)))
			await _shot("glide_node_%d" % int(when * 10.0) + suffix)
		var tgt: Array = gv.call("_glide_target")
		print("GLIDE end zoom=", gv.get("zoom"), " target_on_screen=", gv.call("world_to_screen", tgt[0]), " origin=", gv.call("_origin"))
		await _close(again)
	if _want("owned") or _want("hover") or _want("burst") or _want("zoom") or _want("confirm"):
		var screen := await _open("v4")
		for id in ["EX01", "EX03", "EX02", "EX04", "EXQ", "EXQ1"]:
			Global.ascension_buy(id)
		Global.ascension_ledger().equip("q", "EXQ")
		screen.call("_refresh_all")
		await _wait(1.8)
		if _want("owned"):
			await _shot("owned" + suffix)
		var view: Control = screen.get("view")
		if _want("hover"):
			var at: Vector2 = view.call("world_to_screen", _layout_position(view, "EX05")) + view.get_global_rect().position
			_move_mouse(at)
			await _wait(0.5)
			await _shot("hover" + suffix)
			_move_mouse(Vector2(40, 40))
			await _wait(0.2)
		if _want("burst"):
			screen.call("_buy", "EX05", "")
			await _wait(0.08)
			await _shot("burst_0" + suffix)
			await _wait(0.22)
			await _shot("burst_1" + suffix)
			await _wait(0.5)
			await _shot("burst_2" + suffix)
			await _wait(1.0)
		if _want("zoom"):
			view.set("zoom", 1.25)
			view.call("focus_on", "EXQ")
			await _wait(0.6)
			await _shot("zoom" + suffix)
			# A pan inside the slide range: the static layers move, the live
			# ones redraw; both must still line up.
			view.set("offset", Vector2(view.get("offset")) + Vector2(220.0, -120.0))
			await _wait(0.3)
			await _shot("zoom_pan" + suffix)
			view.call("fit")
			await _wait(0.2)
		if _want("confirm"):
			screen.call("_on_activated", "EX06")
			await _wait(0.5)
			await _shot("confirm" + suffix)
			var dialog: Window = screen.get("_confirm")
			if dialog != null:
				dialog.hide()
			screen.set("_pending_purchase", "")
			screen.call("_on_activated", "G1")
			await _wait(0.5)
			await _shot("confirm_gate" + suffix)
			if dialog != null:
				dialog.hide()
			screen.set("_pending_purchase", "")
			var trigger: Button = screen.get("_trigger_button")
			var trigger_row: Control = screen.get("_trigger_row")
			if trigger != null and trigger_row != null:
				trigger.visible = true
				trigger_row.visible = true
				# Let the Follower toast from the purchases clear first.
				await _wait(4.0)
				await _shot("footer_trigger" + suffix)
		await _close(screen)
	if _want("v5"):
		var screen := await _open("v5_ranged", "ranged")
		for id in ["BR01", "BR02", "BR03", "BR04"]:
			Global.ascension_buy(id)
		screen.call("_refresh_all")
		await _wait(1.8)
		await _shot("v5" + suffix)
		await _close(screen)
	if _only == "perf":
		await _perf()
	SettingsManager.set_value(&"accessibility", &"reduced_motion", _was_reduced, false)
	Global.attempt_ascension = {}
	print("AscensionShotProbe: done -> ", _out)
	get_tree().quit(0)


func _perf() -> void:
	var vsync := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var screen := await _open("v4")
	for id in ["EX01", "EX03", "EX02", "EX04", "EXQ", "EXQ1", "EX05", "EX06", "EX07"]:
		Global.ascension_buy(id)
	Global.ascension_ledger().equip("q", "EXQ")
	screen.call("_refresh_all")
	await _wait(2.0)
	var view: Control = screen.get("view")
	await _measure("idle (fit, owned lattice)", 240, func(_k: int) -> void: pass)
	await _measure("panning (lattice + nodes redraw every frame)", 240, func(k: int) -> void:
		view.set("offset", Vector2(sin(k * 0.05) * 160.0, cos(k * 0.04) * 90.0)))
	if OS.get_environment("ASC_PERF_SPLIT") == "1":
		for layer_name in ["Sky", "Lattice", "Glow", "Nodes", "Marks", "Overlay", "Sparks"]:
			var layer := view.get_node(layer_name) as CanvasItem
			layer.visible = false
			await _measure("idle without " + layer_name, 180, func(_k: int) -> void: pass)
			await _measure("panning without " + layer_name, 180, func(k: int) -> void:
				view.set("offset", Vector2(sin(k * 0.05) * 160.0, cos(k * 0.04) * 90.0)))
			layer.visible = true
	view.call("fit")
	var base_zoom: float = view.get("zoom")
	for pass_name in ["cold", "warm"]:
		view.call("fit")
		await _wait(0.3)
		await _measure("wheel-zooming in, %s font caches" % pass_name, 40, func(k: int) -> void:
			view.set("zoom", base_zoom * pow(1.045, float(k))))
	view.call("fit")
	view.set("zoom", 1.3)
	await _wait(0.3)
	await _measure("idle (zoom 1.3)", 240, func(_k: int) -> void: pass)
	view.call("fit")
	await _wait(0.3)
	view.call("replay_opening")
	await _measure("opening", 80, func(_k: int) -> void: pass)
	await _close(screen)
	DisplayServer.window_set_vsync_mode(vsync)


func _measure(label: String, frames: int, step: Callable) -> void:
	var deltas: Array[float] = []
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var viewport_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	var last := Time.get_ticks_usec()
	for k in range(frames):
		step.call(k)
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		deltas.append(float(now - last) / 1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid) + RenderingServer.get_frame_setup_time_cpu())
		last = now
	deltas.sort()
	gpu.sort()
	cpu.sort()
	var mean := 0.0
	for d in deltas:
		mean += d
	mean /= float(deltas.size())
	print("PERF %s: frame mean %.2f ms, p50 %.2f, p95 %.2f; render gpu p50 %.2f ms, render cpu p50 %.2f ms" % [
		label, mean, deltas[deltas.size() >> 1], deltas[int(deltas.size() * 0.95)], gpu[gpu.size() >> 1], cpu[cpu.size() >> 1]])


func _want(area: String) -> bool:
	return _only == "" or _only == area


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [_out, shot_name])
	print("shot ", shot_name, " ", image.get_size())


## Warps the pointer and delivers the motion the view listens for (a warp
## alone does not always reach GUI input).
func _move_mouse(at: Vector2) -> void:
	get_viewport().warp_mouse(at)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion, true)


func _layout_position(view: Control, id: String) -> Vector2:
	var layout: AscensionTreeLayout = view.get("layout")
	return layout.position_of(id) if layout != null else Vector2.ZERO


func _open(version: String, core: String = "melee") -> Node:
	Global.selected_style_id = core
	Global.attempt_ascension = AscensionLedger.fresh_state(core, version)
	var bg := ColorRect.new()
	bg.name = "ProbeBackdrop"
	bg.color = Color(0.09, 0.1, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var screen := (load("res://ui/screens/AscensionScreen.tscn") as PackedScene).instantiate()
	add_child(screen)
	screen.call("open", false)
	await get_tree().process_frame
	return screen


func _close(screen: Node) -> void:
	if is_instance_valid(screen):
		screen.queue_free()
	var bg := get_node_or_null("ProbeBackdrop")
	if bg != null:
		bg.queue_free()
	await _wait(0.3)
