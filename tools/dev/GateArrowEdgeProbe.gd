extends "res://tools/dev/HudShotProbe.gd"
## Points the objective edge arrow at every edge and corner of a real segment
## (needs a display, not --headless) and records, per direction, the arrow's
## and the distance label's global rects against the viewport and the HUD
## panels the label must stay clear of. Screenshots the named directions,
## then sweeps round the end of the ability plates and prints the largest
## one-frame step the arrow takes there. Then the same with the bag open (Run
## Sheet), with a boss bar and a tutorial tip, and with the evac warning, and
## a 3 px target jitter right at the plate corner (the arrow must hold still).
## The HudShotProbe harness: a throwaway attempt, nothing saved.
##   <godot> --path . res://tools/dev/GateArrowEdgeProbe.tscn -- --out=/abs/dir [--segment=2] [--seed=n]

const PANELS := ["TopLeft", "BagUI", "BossBarHUD", "ActiveAbilityHud_Q", "ActiveAbilityHud_R", "ActiveAbilityHud_V", "GateOverlay/ContextStack", "RunSheetHUD", "GateOverlay/TutorialTip", "EvacOverlay/EvacWarning"]


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
	Global.followers = 1240
	_seed_augments()
	_seed_items()
	Global.goto_game()
	var player: Node2D = null
	for _i in range(900):
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group(&"player") as Node2D
		if player != null:
			break
	if player == null:
		push_error("GateArrowEdgeProbe: no player")
		get_tree().quit(1)
		return
	await _settle(120)
	var hud := _find_hud()
	if hud == null:
		push_error("GateArrowEdgeProbe: no HUD")
		get_tree().quit(1)
		return
	_seed_abilities(player)
	var spawner := get_tree().get_first_node_in_group(&"enemy_spawner")
	if spawner != null and spawner.has_method("suspend_spawning"):
		spawner.call("suspend_spawning", 9999.0)
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if enemy is Node and is_instance_valid(enemy):
			(enemy as Node).queue_free()
	await _settle(30)

	var gate := hud.get_node_or_null("GateOverlayController")
	var arrow := hud.get_node_or_null("GateOverlay/GateArrow") as Control
	if gate == null or arrow == null:
		push_error("GateArrowEdgeProbe: no gate arrow")
		get_tree().quit(1)
		return
	var cam := get_viewport().get_camera_2d()
	var vp := get_viewport().get_visible_rect()
	var half := vp.size * 0.5
	# An opening tip would move the arrow on the top edge; the tip gets its own pass.
	(hud.get_node("GateOverlay/TutorialTip") as Control).visible = false
	# Named shots: the four edges, the four true corners, and in-betweens.
	var dirs := [
		["down", Vector2(0, 1)], ["up", Vector2(0, -1)], ["left", Vector2(-1, 0)], ["right", Vector2(1, 0)],
		["corner_tl", Vector2(-half.x, -half.y)], ["corner_tr", Vector2(half.x, -half.y)],
		["corner_bl", Vector2(-half.x, half.y)], ["corner_br", Vector2(half.x, half.y)],
		["down_left_60", Vector2.from_angle(deg_to_rad(120.0))], ["down_right_70", Vector2.from_angle(deg_to_rad(70.0))],
		["up_left_20", Vector2.from_angle(deg_to_rad(-160.0))], ["up_right_35", Vector2.from_angle(deg_to_rad(-35.0))],
	]
	for deg in range(0, 360, 10):
		dirs.append(["sweep_%03d" % deg, Vector2.from_angle(deg_to_rad(float(deg)))])
	var failures := 0
	for entry in dirs:
		var shot_name := String(entry[0])
		var dir := (entry[1] as Vector2).normalized()
		Global.objective_target_pos = cam.get_screen_center_position() + dir * 5000.0
		await _wait(0.4)
		var label := gate.get("_gate_distance_label") as Label
		var report := _measure_arrow(hud, arrow, label, vp)
		if String(report["problems"]) != "" or report.has("arrow_over"):
			failures += 1
		print("GateArrowEdgeProbe %s %s" % [shot_name, JSON.stringify(report)])
		if not shot_name.begins_with("sweep_"):
			await _shot("arrow_" + shot_name)
	print("GateArrowEdgeProbe: %d of %d directions with problems -> %s" % [failures, dirs.size(), _out])

	# Rounding the left end of the ability plates, a quarter degree a frame:
	# the largest step the arrow takes in one frame.
	var step_max := 0.0
	var last := Vector2.INF
	for i in range(80):
		var deg := 150.0 - float(i) * 0.25
		Global.objective_target_pos = cam.get_screen_center_position() + Vector2.from_angle(deg_to_rad(deg)) * 5000.0
		await get_tree().process_frame
		var c := arrow.get_global_rect().get_center()
		if last != Vector2.INF:
			step_max = maxf(step_max, c.distance_to(last))
		last = c
	print("GateArrowEdgeProbe hop 150->130 deg: largest one-frame step %.1f px" % step_max)

	# A 3 px side-to-side jitter of the target right where the ray rounds the
	# Q plate's corner, 1200 px out: the pin must not flip every frame.
	var inner := Rect2(Vector2(26, 26), vp.size - Vector2(52, 52))
	var rects: Array[Rect2] = []
	for path in PANELS:
		var panel := hud.get_node_or_null(path) as Control
		rects.append(panel.get_global_rect() if panel != null and panel.is_visible_in_tree() else Rect2())
	var corner_deg := 0.0
	var biggest := 0.0
	var prev := Vector2.INF
	for i in range(2000):
		var deg := 120.0 + float(i) * 0.02
		var pin: Vector2 = gate.call("edge_pin", half, Vector2.from_angle(deg_to_rad(deg)), inner, rects, arrow.size.x * 0.5 + 8.0)
		if prev != Vector2.INF and pin.distance_to(prev) > biggest:
			biggest = pin.distance_to(prev)
			corner_deg = deg
		prev = pin
	# Settled on the plate side, then on the edge side, before the jitter.
	for side in [-2.0, 2.0]:
		Global.objective_target_pos = cam.get_screen_center_position() + Vector2.from_angle(deg_to_rad(corner_deg + side)) * 1200.0
		await _wait(0.3)
		var base := Vector2.from_angle(deg_to_rad(corner_deg - 0.01))
		var perp := Vector2(-base.y, base.x)
		var worst := 0.0
		var at := Vector2.INF
		for f in range(70):
			Global.objective_target_pos = cam.get_screen_center_position() + base * 1200.0 + perp * (3.0 if f % 2 == 0 else -3.0)
			await get_tree().process_frame
			var c := arrow.get_global_rect().get_center()
			if f >= 10 and at != Vector2.INF:
				worst = maxf(worst, c.distance_to(at))
			at = c
		print("GateArrowEdgeProbe jitter at the %.2f deg corner (pin jump %.0f px), settled from %+.0f deg: largest one-frame step %.1f px, resting at %s" % [corner_deg, biggest, side, worst, at])

	# The bag open: the Run Sheet down the left side.
	var bag_ctl := hud.get_node_or_null("BagController")
	if bag_ctl != null and bag_ctl.has_method("toggle_bag_open"):
		bag_ctl.call("toggle_bag_open")
		await _wait(0.5)
		await _scene_pass(hud, gate, arrow, vp, "manage", [150, 160, 170, 180, 190, 200, 210], [170, 180, 190])
		bag_ctl.call("toggle_bag_open")
		await _wait(0.3)
	# A boss bar with a tutorial tip under it.
	var bar := hud.get_node_or_null("BossBarHUD")
	var tips := hud.get_node_or_null("TutorialTipController")
	if bar != null and tips != null:
		bar.call("show_boss", "The Warden of Ash", null, 3400.0, 4800.0)
		tips.call("_show_now", "2 optional signals detected in this district.")
		await _wait(0.3)
		await _scene_pass(hud, gate, arrow, vp, "bosstip", [235, 245, 255, 270, 285, 295, 305], [245, 270])
		tips.call("_hide_now")
		bar.call("hide_boss")
		await _wait(0.3)
	# The evac countdown.
	var warn := hud.get_node_or_null("EvacOverlay/EvacWarning") as Label
	if warn != null:
		warn.text = "GATE UNSEALED  •  EVAC IN 42s"
		warn.modulate.a = 1.0
		warn.visible = true
		await _wait(0.2)
		await _scene_pass(hud, gate, arrow, vp, "evac", [250, 260, 270, 280, 290], [270])
		warn.visible = false
	get_tree().quit(0)


func _scene_pass(hud: Control, gate: Node, arrow: Control, vp: Rect2, tag: String, degrees: Array, shots: Array) -> void:
	var cam := get_viewport().get_camera_2d()
	var failures := 0
	for deg in degrees:
		Global.objective_target_pos = cam.get_screen_center_position() + Vector2.from_angle(deg_to_rad(float(deg))) * 5000.0
		await _wait(0.35)
		var report := _measure_arrow(hud, arrow, gate.get("_gate_distance_label") as Label, vp)
		if String(report["problems"]) != "" or report.has("arrow_over"):
			failures += 1
		print("GateArrowEdgeProbe %s_%03d %s" % [tag, deg, JSON.stringify(report)])
		if deg in shots:
			await _shot("arrow_%s_%03d" % [tag, deg])
	print("GateArrowEdgeProbe %s: %d of %d directions with problems" % [tag, failures, degrees.size()])


func _measure_arrow(hud: Control, arrow: Control, label: Label, vp: Rect2) -> Dictionary:
	var out := {
		"arrow": _rect_text(arrow.get_global_rect()) if arrow.is_visible_in_tree() else "hidden",
		"label": "none",
		"text": "",
		"problems": "",
	}
	var problems: PackedStringArray = []
	if not arrow.is_visible_in_tree():
		problems.append("arrow hidden")
	if label == null or not is_instance_valid(label) or not label.is_visible_in_tree():
		problems.append("no visible label")
		out["problems"] = ", ".join(problems)
		return out
	# The label's drawn box: its rect through its global transform.
	var xf := label.get_global_transform()
	var box := xf * Rect2(Vector2.ZERO, label.size)
	out["label"] = _rect_text(box)
	out["text"] = label.text
	out["rotation"] = snappedf(rad_to_deg(xf.get_rotation()), 0.1)
	if absf(xf.get_rotation()) > 0.01:
		problems.append("label rotated")
	if not vp.encloses(box):
		problems.append("label leaves the viewport")
	# The plate is round: the label's nearest point must clear its radius.
	var arrow_rect := arrow.get_global_rect()
	var plate_center := arrow_rect.get_center()
	var nearest := plate_center.clamp(box.position, box.end)
	out["plate_gap"] = snappedf(nearest.distance_to(plate_center) - arrow_rect.size.x * 0.5, 0.1)
	if nearest.distance_to(plate_center) < arrow_rect.size.x * 0.5:
		problems.append("label on the arrow plate")
	for path in PANELS:
		var panel := hud.get_node_or_null(path) as Control
		if panel == null or not panel.is_visible_in_tree():
			continue
		var panel_rect := panel.get_global_rect()
		if panel_rect.has_point(vp.get_center()):
			continue
		if box.intersects(panel_rect):
			problems.append("label under %s" % path)
		if arrow.is_visible_in_tree() and arrow_rect.intersects(panel_rect):
			out["arrow_over"] = String(out.get("arrow_over", "")) + path + " "
	out["problems"] = ", ".join(problems)
	return out


func _rect_text(r: Rect2) -> String:
	return "(%d,%d %dx%d)" % [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)]
