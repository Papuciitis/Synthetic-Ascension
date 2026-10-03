extends Node

# The objective edge arrow's distance ("78m") sat below the arrow, so with the
# target below the screen it was drawn under the bottom edge, and on the other
# edges it landed on the top-left panel or the backpack. Pins the placement:
# for every edge, corner and the angles between, the arrow stays off the HUD
# panels and the distance is upright, inside the viewport, off the round
# plate, off the panels, and on the arrow's inward side. Then drives the real
# controller over GateOverlay.tscn: the target straight below, a jitter right
# at an ability plate's corner (the pin must not flip every frame), and a
# panel that shows, moves and hides under a settled arrow.
#
# Run: <godot> --headless --path . res://tools/tests/GateArrowEdgeTest.tscn

const ControllerScript = preload("res://ui/controllers/HudGateOverlayController.gd")
const GATE_OVERLAY_SCENE: PackedScene = preload("res://ui/overlays/GateOverlay.tscn")

const VIEW := Vector2(1920.0, 1080.0)
const MARGIN := 26.0
const ARROW_RADIUS := 34.0
const LABEL_SIZE := Vector2(46.0, 22.0)

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _run() -> void:
	_test_ray_entry()
	_test_placement("bare screen", [])
	# The combat HUD's edge panels at 1920x1080: top-left panel, backpack,
	# objective stack, the three ability plates.
	_test_placement("combat HUD", [
		Rect2(12, 12, 360, 400),
		Rect2(1694, 10, 216, 88),
		Rect2(1482, 104, 420, 52),
		Rect2(528, 974, 280, 84),
		Rect2(820, 974, 280, 84),
		Rect2(1112, 974, 280, 84),
	])
	# Bag open: the backpack grid and the Run Sheet under the top-left panel.
	_test_placement("bag open", [
		Rect2(12, 12, 378, 408),
		Rect2(1694, 8, 218, 302),
		Rect2(12, 428, 432, 462),
		Rect2(528, 974, 280, 84),
		Rect2(820, 974, 280, 84),
		Rect2(1112, 974, 280, 84),
	])
	# A boss fight with a tutorial tip under the boss bar.
	_test_placement("boss and tip", [
		Rect2(12, 12, 378, 408),
		Rect2(1694, 8, 218, 91),
		Rect2(670, 14, 580, 74),
		Rect2(670, 88, 580, 52),
		Rect2(1482, 104, 420, 52),
		Rect2(528, 974, 280, 84),
		Rect2(820, 974, 280, 84),
		Rect2(1112, 974, 280, 84),
	])
	# The evac countdown across the top centre.
	_test_placement("evac", [
		Rect2(12, 12, 378, 408),
		Rect2(1694, 8, 218, 91),
		Rect2(720, 14, 480, 45),
		Rect2(1482, 104, 420, 52),
		Rect2(528, 974, 280, 84),
		Rect2(820, 974, 280, 84),
		Rect2(1112, 974, 280, 84),
	])
	await _test_controller_target_below()

	print("GateArrowEdgeTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_ray_entry() -> void:
	var box := Rect2(100, 100, 50, 50)
	_check(is_equal_approx(ControllerScript.ray_entry(Vector2(0, 125), Vector2.RIGHT, box), 100.0), "a ray enters a box at its near face")
	_check(ControllerScript.ray_entry(Vector2(0, 125), Vector2.LEFT, box) == INF, "a box behind the ray is no hit")
	_check(ControllerScript.ray_entry(Vector2(0, 20), Vector2.RIGHT, box) == INF, "a ray passing beside a box is no hit")
	_check(ControllerScript.ray_entry(Vector2(120, 120), Vector2.RIGHT, box) == INF, "a ray starting inside a box ignores it")


func _test_placement(label: String, panels: Array) -> void:
	var keep_clear: Array[Rect2] = []
	for panel in panels:
		keep_clear.append(panel as Rect2)
	var center := VIEW * 0.5
	var inner := Rect2(Vector2(MARGIN, MARGIN), VIEW - Vector2(MARGIN, MARGIN) * 2.0)
	var view := Rect2(Vector2.ZERO, VIEW).grow(-4.0)
	var clearance := ARROW_RADIUS + ControllerScript.KEEP_CLEAR_GAP

	var named := {
		"down": Vector2(0, 1), "up": Vector2(0, -1), "left": Vector2(-1, 0), "right": Vector2(1, 0),
		"top-left corner": -center, "top-right corner": Vector2(center.x, -center.y),
		"bottom-left corner": Vector2(-center.x, center.y), "bottom-right corner": center,
	}
	var dirs := {}
	for key in named:
		dirs[key] = (named[key] as Vector2).normalized()
	for deg in range(0, 360, 5):
		dirs["%d deg" % deg] = Vector2.from_angle(deg_to_rad(float(deg)))

	var problems: PackedStringArray = []
	for key in dirs:
		var dir: Vector2 = dirs[key]
		var arrow: Vector2 = ControllerScript.edge_pin(center, dir, inner, keep_clear, clearance)
		var top_left: Vector2 = ControllerScript.distance_label_position(arrow, dir, ARROW_RADIUS, LABEL_SIZE, view, ControllerScript.LABEL_GAP)
		var box := Rect2(top_left, LABEL_SIZE)
		var why: PackedStringArray = []
		if not inner.grow(0.5).has_point(arrow):
			why.append("arrow off its edge track")
		if not Rect2(Vector2.ZERO, VIEW).encloses(box):
			why.append("label leaves the viewport")
		if arrow.clamp(box.position, box.end).distance_to(arrow) < ARROW_RADIUS:
			why.append("label on the plate")
		if (box.get_center() - arrow).dot(dir) >= 0.0:
			why.append("label not on the inward side")
		for panel in keep_clear:
			if panel.intersects(box):
				why.append("label under a panel")
			if arrow.clamp(panel.position, panel.end).distance_to(arrow) < ARROW_RADIUS:
				why.append("arrow on a panel")
		if not why.is_empty():
			problems.append("%s: %s" % [key, ", ".join(why)])
		if named.has(key):
			_check(why.is_empty(), "%s, %s: the distance reads beside the arrow (%s)" % [label, key, ", ".join(why)])
	_check(problems.is_empty(), "%s: every 5 degrees the arrow and its distance stay readable (%s)" % [label, "; ".join(problems)])

	# The reported case: the target straight below puts the distance above the arrow.
	var down_arrow: Vector2 = ControllerScript.edge_pin(center, Vector2.DOWN, inner, keep_clear, clearance)
	var down_label: Vector2 = ControllerScript.distance_label_position(down_arrow, Vector2.DOWN, ARROW_RADIUS, LABEL_SIZE, view, ControllerScript.LABEL_GAP)
	_check(
		down_label.y + LABEL_SIZE.y <= down_arrow.y - ARROW_RADIUS,
		"%s: target below, the distance sits above the arrow (label bottom %.0f, plate top %.0f)" % [label, down_label.y + LABEL_SIZE.y, down_arrow.y - ARROW_RADIUS]
	)


## The real controller over the real overlay, inside a CanvasLayer like the
## HUD, with a fixture ability plate at the bottom centre.
func _test_controller_target_below() -> void:
	var saved_objective: Vector2 = Global.objective_target_pos
	var saved_gate: Vector2 = Global.exit_gate_pos
	Global.objective_target_pos = Vector2.INF
	Global.exit_gate_pos = Vector2.INF

	var cam := Camera2D.new()
	add_child(cam)
	cam.make_current()
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)

	var layer := CanvasLayer.new()
	add_child(layer)
	var host := Control.new()
	host.size = get_viewport().get_visible_rect().size
	layer.add_child(host)
	var plate := Control.new()
	plate.name = "ActiveAbilityHud_R"
	plate.position = Vector2(host.size.x * 0.5 - 140.0, host.size.y - 106.0)
	plate.size = Vector2(280.0, 84.0)
	host.add_child(plate)
	var plate_q := Control.new()
	plate_q.name = "ActiveAbilityHud_Q"
	plate_q.position = Vector2(host.size.x * 0.5 - 432.0, host.size.y - 106.0)
	plate_q.size = Vector2(280.0, 84.0)
	host.add_child(plate_q)
	var overlay := GATE_OVERLAY_SCENE.instantiate() as Control
	overlay.name = "GateOverlay"
	host.add_child(overlay)
	var controller: Node = ControllerScript.new()
	var keep_clear: Array = controller.get("keep_clear_paths")
	for path in [NodePath("../ActiveAbilityHud_R"), NodePath("../RunSheetHUD"), NodePath("../GateOverlay/TutorialTip"), NodePath("../EvacOverlay/EvacWarning")]:
		_check(keep_clear.has(path), "the arrow keeps clear of %s by default" % path)
	controller.set("gate_overlay_path", NodePath("../GateOverlay"))
	controller.set("gate_arrow_path", NodePath("../GateOverlay/GateArrow"))
	controller.set("gate_arrow_tex_path", NodePath("../GateOverlay/GateArrow/Center/ArrowTex"))
	host.add_child(controller)
	await _frames(3)

	Global.objective_target_pos = Vector2(0.0, 5000.0)
	await _frames(4)
	var view := get_viewport().get_visible_rect()
	var arrow := overlay.get_node("GateArrow") as Control
	var distance := controller.get("_gate_distance_label") as Label
	_check(arrow.visible, "with the target below, the arrow shows")
	_check(distance != null and distance.is_visible_in_tree(), "and so does its distance")
	if distance != null:
		var box := distance.get_global_transform() * Rect2(Vector2.ZERO, distance.size)
		var arrow_rect := arrow.get_global_rect()
		_check(distance.text == "78m", "the distance reads in metres (%s)" % distance.text)
		_check(view.encloses(box), "the distance is inside the viewport (%s in %s)" % [box, view])
		_check(box.end.y <= arrow_rect.position.y, "the distance sits above the arrow (%s vs %s)" % [box, arrow_rect])
		_check(is_zero_approx(distance.get_global_transform().get_rotation()), "the distance is upright")
		_check(not box.intersects(plate.get_global_rect()), "the distance is off the ability plate")
		_check(not arrow_rect.intersects(plate.get_global_rect()), "the arrow stops above the ability plate (%s vs %s)" % [arrow_rect, plate.get_global_rect()])
		_check(distance.get_parent() == overlay, "the distance is the arrow's sibling, not laid out by its PanelContainer")

		# Walking less than a metre writes nothing; a metre more rewrites once.
		player.global_position = Vector2(0.0, 5.0)
		await _frames(2)
		_check(distance.text == "78m", "under a metre of walking leaves the text alone (%s)" % distance.text)
		player.global_position = Vector2(0.0, 70.0)
		await _frames(2)
		_check(distance.text == "77m", "a metre walked updates it (%s)" % distance.text)
		_check(is_equal_approx(distance.modulate.a, arrow.modulate.a), "the distance pulses with the arrow")
		player.global_position = Vector2.ZERO

		await _test_corner_jitter(controller, arrow, [plate_q.get_global_rect(), plate.get_global_rect()])
		await _test_panel_changes(controller, arrow, overlay.get_node("TutorialTip") as Control)

	Global.objective_target_pos = Vector2.INF
	await _frames(1)
	_check(not arrow.visible and (distance == null or not distance.visible), "clearing the target hides the arrow and its distance")

	layer.queue_free()
	player.queue_free()
	cam.queue_free()
	await _frames(1)
	Global.objective_target_pos = saved_objective
	Global.exit_gate_pos = saved_gate


## One frame of the controller at 60 fps, without waiting for the tree.
func _step(controller: Node, arrow: Control) -> Vector2:
	controller.call("_update_gate_arrow", 1.0 / 60.0)
	return arrow.get_global_rect().get_center()


## Where the ray rounds the Q plate's outer corner the pin jumps ~190 px
## between the bottom edge and the plate top. A 3 px side-to-side jitter of
## the target right there, 1200 px out, used to flip it every frame and leave
## the arrow shaking 40 px a frame in mid-air.
func _test_corner_jitter(controller: Node, arrow: Control, plates: Array) -> void:
	var view := get_viewport().get_visible_rect().size
	var center := view * 0.5
	var inner := Rect2(Vector2(MARGIN, MARGIN), view - Vector2(MARGIN, MARGIN) * 2.0)
	var rects: Array[Rect2] = []
	for rect in plates:
		rects.append(rect as Rect2)
	var clearance := arrow.size.x * 0.5 + ControllerScript.KEEP_CLEAR_GAP
	var corner_deg := 0.0
	var biggest := 0.0
	var prev := Vector2.INF
	for i in range(3000):
		var deg := 120.0 + float(i) * 0.01
		var pin: Vector2 = ControllerScript.edge_pin(center, Vector2.from_angle(deg_to_rad(deg)), inner, rects, clearance)
		if prev != Vector2.INF and pin.distance_to(prev) > biggest:
			biggest = pin.distance_to(prev)
			corner_deg = deg
		prev = pin
	_check(biggest > 100.0, "the fixture plate has a corner where the pin jumps (%.0f px at %.2f deg)" % [biggest, corner_deg])
	# Settled on the plate side, then on the edge side, before the jitter.
	for side in [-2.0, 2.0]:
		Global.objective_target_pos = Vector2.from_angle(deg_to_rad(corner_deg + side)) * 1200.0
		for _f in range(30):
			_step(controller, arrow)
		var base := Vector2.from_angle(deg_to_rad(corner_deg - 0.005))
		var perp := Vector2(-base.y, base.x)
		var last := Vector2.INF
		var worst := 0.0
		for f in range(60):
			Global.objective_target_pos = base * 1200.0 + perp * (3.0 if f % 2 == 0 else -3.0)
			var at := _step(controller, arrow)
			if f >= 10 and last != Vector2.INF:
				worst = maxf(worst, at.distance_to(last))
			last = at
		_check(worst < 1.0, "a 3 px jitter at the plate corner, settled from %+.0f deg, leaves the arrow still (largest step %.1f px)" % [side, worst])
	# Turning steadily across the corner still takes it, gliding.
	var moved := false
	var top_step := 0.0
	Global.objective_target_pos = Vector2.from_angle(deg_to_rad(corner_deg + 2.0)) * 1200.0
	for _f in range(30):
		_step(controller, arrow)
	var before := _step(controller, arrow)
	var last2 := before
	for i in range(160):
		Global.objective_target_pos = Vector2.from_angle(deg_to_rad(corner_deg + 2.0 - float(i) * 0.025)) * 1200.0
		var at2 := _step(controller, arrow)
		top_step = maxf(top_step, at2.distance_to(last2))
		last2 = at2
	moved = last2.distance_to(before) > 100.0
	_check(moved and top_step <= ControllerScript.GLIDE_SPEED / 60.0 + 0.5, "a steady turn across the corner still moves the arrow there, gliding (moved %.0f px, largest step %.1f px)" % [last2.distance_to(before), top_step])


## A panel that shows, moves and hides under a settled arrow is picked up
## although its rect is no longer read every frame.
func _test_panel_changes(controller: Node, arrow: Control, tip: Control) -> void:
	Global.objective_target_pos = Vector2(0.0, -5000.0)
	for _f in range(20):
		_step(controller, arrow)
	var top := arrow.get_global_rect()
	_check(top.position.y < 30.0, "target above, the arrow sits on the top edge (%s)" % top)
	tip.visible = true
	await _frames(2)
	for _f in range(20):
		_step(controller, arrow)
	var tip_rect := tip.get_global_rect()
	var below := arrow.get_global_rect()
	_check(tip_rect.has_area() and not below.intersects(tip_rect) and below.position.y > tip_rect.end.y, "a tutorial tip showing pushes the arrow below it (%s vs %s)" % [below, tip_rect])
	tip.position.y += 60.0
	await _frames(2)
	for _f in range(20):
		_step(controller, arrow)
	var lower := arrow.get_global_rect()
	_check(lower.position.y > tip.get_global_rect().end.y and lower.position.y > below.position.y + 50.0, "the tip moving down takes the arrow with it (%s vs %s)" % [lower, tip.get_global_rect()])
	tip.position.y -= 60.0
	tip.visible = false
	await _frames(2)
	for _f in range(20):
		_step(controller, arrow)
	_check(arrow.get_global_rect().position.y < 30.0, "the tip hiding lets the arrow back to the top edge (%s)" % arrow.get_global_rect())
