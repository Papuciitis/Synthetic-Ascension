extends Node

## Hovering a Manifestation on the Run Sheet must show its full rule.
##
## The panel trims every rule to two lines, so without this the player has no
## way to read what a rule they are wearing does. Verifies the two things Godot
## actually requires (a non-IGNORE mouse filter and non-empty tooltip_text),
## renders the card itself, and then drives a real pointer hover.

var _passes: int = 0
var _failures: int = 0
var _dir: String = ""
var _is_worker: bool = false


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: %s" % message)


func _ready() -> void:
	if _is_worker:
		get_tree().create_timer(150.0).timeout.connect(func() -> void:
			push_error("ManifestationHoverProbe timed out")
			get_tree().quit(1)
		)
		_run.call_deferred()
		return
	_dir = OS.get_environment("HOVER_SHOT_DIR")
	if _dir.is_empty():
		_dir = ProjectSettings.globalize_path("user://hover_shots")
	DirAccess.make_dir_recursive_absolute(_dir)
	var worker := Node.new()
	worker.name = "ManifestationHoverWorker"
	worker.process_mode = Node.PROCESS_MODE_ALWAYS
	worker.set_script(get_script())
	worker.set("_dir", _dir)
	worker.set("_is_worker", true)
	get_tree().root.add_child.call_deferred(worker)


func _run() -> void:
	Global.start_new_attempt()
	Global.attempt_segment = 1
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.debug_dev_mode = true
	Global.debug_player_god_mode = true
	Global.goto_game()
	var player: Node2D = null
	for _wait in range(400):
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group(&"player") as Node2D
		if player != null:
			break
	if player == null:
		push_error("FAIL: no player")
		_finish()
		return
	_disable_modals(get_tree().root)
	get_tree().paused = false

	# Something to read.
	var tools := get_node_or_null("/root/DevSetCollisionTools")
	if tools != null:
		# grant_pair equips real gear AND stamps rules onto it;
		# roll_all_manifestations only stamps onto items already worn, so on a
		# fresh run it has nothing to write to.
		var placed: int = int(tools.call("grant_pair", ManifestationPairCatalog.all_ids()[0]))
		_check(placed > 0, "the probe managed to equip some rules (%d)" % placed)
	for _f in range(40):
		await get_tree().process_frame

	var hud := _find_hud(get_tree().root)
	var bag: Node = hud.get("bag_ctl") if hud != null else null
	_check(bag != null, "the run has a bag controller")
	if bag == null:
		_finish()
		return
	bag.call("toggle_bag_open")
	for _f in range(20):
		await get_tree().process_frame

	var boxes: Array[Node] = []
	_collect_boxes(get_tree().root, boxes)
	_check(not boxes.is_empty(), "the Run Sheet lists Manifestations (%d)" % boxes.size())
	if boxes.is_empty():
		_finish()
		return

	for node in boxes:
		var box := node as ManifestationInfoBox
		_check(
			box.mouse_filter != Control.MOUSE_FILTER_IGNORE,
			"'%s' can receive the pointer" % box.info_title
		)
		_check(
			box.tooltip_text.strip_edges() != "",
			"'%s' has tooltip text, without which Godot never asks for a card" % box.info_title
		)
		_check(box.info_body.strip_edges() != "", "'%s' carries a full rule" % box.info_title)

	# The card itself has to render, and it has to be WIDER than one line - the
	# whole point is that the default tooltip is an unwrapped strip.
	var sample: ManifestationInfoBox = boxes[0] as ManifestationInfoBox
	var card := sample._make_custom_tooltip("") as Control
	_check(card != null, "the hover card builds")
	if card != null:
		get_tree().root.add_child(card)
		card.position = Vector2(360, 220)
		for _f in range(6):
			await get_tree().process_frame
		_check(card.size.y > 40.0, "the card wraps to several lines (%.0f px tall)" % card.size.y)
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		print("HOVER card -> %s (err=%d)" % [
			"%s/hover_card.png" % _dir, image.save_png("%s/hover_card.png" % _dir)
		])
		card.queue_free()

	# And a real pointer hover, which is what a player actually does. Re-find
	# the box first: the panel rebuilds its children on a tick, so a reference
	# taken earlier may already be freed - which is the exact hazard the
	# pointer-is-reading guard exists to fix.
	boxes.clear()
	_collect_boxes(get_tree().root, boxes)
	if boxes.is_empty():
		_check(false, "the Run Sheet still lists Manifestations")
		_finish()
		return
	sample = boxes[0] as ManifestationInfoBox
	var target := sample.get_global_rect().get_center()
	Input.warp_mouse(target)
	for _f in range(120):
		await get_tree().process_frame
	_check(
		is_instance_valid(sample),
		"the entry under the pointer survives the panel's refresh tick"
	)
	await RenderingServer.frame_post_draw
	var hovered := get_viewport().get_texture().get_image()
	print("HOVER live at %s -> %s (err=%d)" % [
		str(target), "%s/hover_live.png" % _dir, hovered.save_png("%s/hover_live.png" % _dir)
	])

	_finish()


func _collect_boxes(node: Node, out: Array[Node]) -> void:
	if node is ManifestationInfoBox:
		out.append(node)
	for child in node.get_children():
		_collect_boxes(child, out)


func _find_hud(node: Node) -> Node:
	var script: Variant = node.get_script()
	if script != null and String(script.resource_path).ends_with("ui/screens/hud.gd"):
		return node
	for child in node.get_children():
		var found := _find_hud(child)
		if found != null:
			return found
	return null


func _disable_modals(node: Node) -> void:
	var script: Variant = node.get_script()
	if script != null and String(script.resource_path).ends_with("TutorialModalController.gd"):
		node.queue_free()
		return
	for child in node.get_children():
		_disable_modals(child)


func _finish() -> void:
	print("ManifestationHoverProbe: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
