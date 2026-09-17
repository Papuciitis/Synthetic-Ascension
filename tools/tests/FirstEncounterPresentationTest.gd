extends SceneTree

class EnemyFixture:
	extends Node2D
	var spec: EnemySpec


class PauseHandoffFixture:
	extends Node
	var requested := false
	var adopted := false

	func adopt_pause_handoff() -> bool:
		if not requested:
			return false
		adopted = true
		return true

var _passes := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	paused = false
	var scene := load("res://ui/overlays/FirstEncounterOverlay.tscn") as PackedScene
	_check(scene != null, "first-encounter overlay scene loads")
	if scene == null:
		_finish()
		return
	var overlay_source := FileAccess.get_file_as_string("res://ui/overlays/FirstEncounterOverlay.gd")
	var controller_source := FileAccess.get_file_as_string("res://ui/controllers/TutorialModalController.gd")
	_check(
		"func _target_is_live(target: Variant)" in overlay_source,
		"overlay liveness guard accepts a freed-object variant before narrowing its type"
	)
	_check(
		"func _target_is_live(target: Variant)" in controller_source,
		"queued encounter liveness guard accepts a freed-object variant before narrowing its type"
	)

	var target := Node2D.new()
	target.position = Vector2(420, 340)
	root.add_child(target)
	var overlay := scene.instantiate()
	root.add_child(overlay)
	await process_frame

	var dismissed := [false]
	overlay.dismissed.connect(func() -> void: dismissed[0] = true)
	overlay.call("present", {
		"name": "Containment Officer",
		"quote": "A full lore line that belongs in the archive.",
		"role": "Melee pursuer",
		"behaviour": "Repeated contact damage.",
		"expect": "Dangerous in a crowd.",
		"counter": "Keep moving and divide the group.",
	}, target, null, "Health: Low  •  Speed: Medium  •  Range: Contact  •  Threat: Basic")
	overlay.call("_update_geometry")

	_check(paused, "the recognition beat acquires a short freeze")
	_check(not _contains_button(overlay), "the recognition beat has no Continue button")
	var compact_text := _collect_label_text(overlay)
	_check("Melee pursuer" in compact_text, "compact encounter text preserves the enemy role")
	_check("Keep moving and divide the group." in compact_text, "compact encounter text preserves the actionable counter")
	_check(not "Repeated contact damage." in compact_text, "behaviour prose stays out of the live callout")
	var encounter_card := overlay.get("_card") as PanelContainer
	_check(
		encounter_card != null and encounter_card.size.y <= 240.0,
		"the live encounter card stays compact enough for crowded combat (size=%s min=%s)" % [
			str(encounter_card.size if encounter_card != null else Vector2.ZERO),
			str(encounter_card.get_combined_minimum_size() if encounter_card != null else Vector2.ZERO),
		]
	)

	var first_target_point: Vector2 = overlay.call("debug_target_screen_point")
	overlay.call("_process", 0.81)
	_check(not paused, "the recognition beat resumes automatically after 0.8 seconds")
	target.position = Vector2(520, 390)
	overlay.call("_process", 0.1)
	var moved_target_point: Vector2 = overlay.call("debug_target_screen_point")
	_check(moved_target_point.distance_to(first_target_point) > 20.0, "the ritual tether follows the represented enemy")
	target.set_meta(&"__in_pool", true)
	target.process_mode = Node.PROCESS_MODE_DISABLED
	target.position = Vector2(80, 80)
	overlay.call("_process", 0.1)
	var pooled_target_point: Vector2 = overlay.call("debug_target_screen_point")
	_check(
		pooled_target_point.is_equal_approx(moved_target_point),
		"a pooled enemy leaves the tether at its last live position"
	)
	target.remove_meta(&"__in_pool")
	target.process_mode = Node.PROCESS_MODE_INHERIT

	overlay.call("_process", 5.0)
	_check(bool(dismissed[0]), "the recognition card retracts without player input")
	if is_instance_valid(overlay):
		overlay.queue_free()
	await process_frame

	var doomed_target := Node2D.new()
	doomed_target.position = Vector2(610, 410)
	root.add_child(doomed_target)
	var freed_target_overlay := scene.instantiate()
	root.add_child(freed_target_overlay)
	freed_target_overlay.call(
		"present",
		{"name": "Freed Target", "role": "Test", "counter": "Retain the last endpoint."},
		doomed_target,
		null,
		"Threat: Basic"
	)
	freed_target_overlay.call("_update_geometry")
	var endpoint_before_free: Vector2 = freed_target_overlay.call("debug_target_screen_point")
	doomed_target.free()
	freed_target_overlay.call("_process", 0.1)
	_check(
		(freed_target_overlay.call("debug_target_screen_point") as Vector2).is_equal_approx(endpoint_before_free),
		"a freed encounter target preserves the last readable tether endpoint"
	)
	freed_target_overlay.call("_process", 6.0)
	freed_target_overlay.queue_free()
	paused = false
	await process_frame

	paused = true
	var paused_overlay := scene.instantiate()
	root.add_child(paused_overlay)
	paused_overlay.call("present", {"name": "Already Paused", "role": "Test", "counter": "Remain paused."}, target, null, "Threat: Basic")
	paused_overlay.call("_process", 6.0)
	_check(paused, "an encounter never unpauses a pause state it did not acquire")
	paused = false
	paused_overlay.queue_free()
	await process_frame

	var handoff_owner := PauseHandoffFixture.new()
	handoff_owner.add_to_group(&"pause_handoff_owner")
	root.add_child(handoff_owner)
	var handoff_overlay := scene.instantiate()
	root.add_child(handoff_overlay)
	handoff_overlay.call("present", {"name": "Pause Handoff", "role": "Test", "counter": "Remain paused."}, target, null, "Threat: Basic")
	handoff_owner.requested = true
	handoff_overlay.call("_process", 0.81)
	_check(paused and handoff_owner.adopted, "an arriving pause owner adopts the encounter freeze without a one-frame resume")
	paused = false
	handoff_overlay.call("_process", 6.0)
	if is_instance_valid(handoff_overlay):
		handoff_overlay.queue_free()
	handoff_owner.queue_free()
	await process_frame

	await _verify_controller_routes_enemy_cards(target)
	await _verify_controller_teardown_during_enemy_card(target)
	target.queue_free()
	await process_frame
	_finish()


func _verify_controller_routes_enemy_cards(_target: Node2D) -> void:
	var global := root.get_node("Global")
	var events := root.get_node("RunEvents")
	var discoveries: Array = global.get("discovered_enemy_ids") as Array
	var previous_discoveries: Array = discoveries.duplicate()
	var previous_force: bool = bool(global.get("debug_force_enemy_introductions"))
	global.set("debug_force_enemy_introductions", true)
	discoveries.erase(&"enemy_runner")

	var host := Node.new()
	root.add_child(host)
	current_scene = host
	var controller_script := load("res://ui/controllers/TutorialModalController.gd") as Script
	var controller: Node = controller_script.new()
	host.add_child(controller)
	var expired_enemy := EnemyFixture.new()
	host.add_child(expired_enemy)
	var expired_enemy_variant: Variant = expired_enemy
	expired_enemy.free()
	_check(
		not bool(controller.call("_target_is_live", expired_enemy_variant)),
		"the queued encounter controller rejects a target freed before presentation"
	)
	var enemy := EnemyFixture.new()
	enemy.spec = EnemySpec.new()
	enemy.spec.id = &"enemy_runner"
	enemy.spec.display_name = "Runner"
	enemy.position = Vector2(500, 320)
	host.add_child(enemy)
	enemy.set_meta(&"__in_pool", true)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	_check(not bool(controller.call("_target_is_live", enemy)), "the controller rejects pooled encounter targets")
	enemy.remove_meta(&"__in_pool")
	enemy.process_mode = Node.PROCESS_MODE_INHERIT

	var blocking_states: Array[bool] = []
	var modal_cb := func(open: bool) -> void: blocking_states.append(open)
	events.connect(&"tutorial_modal_state_changed", modal_cb)
	controller.call("_on_enemy_encountered", enemy)
	await process_frame
	var routed_overlay := host.get_node_or_null("FirstEncounterOverlay")
	_check(routed_overlay != null, "enemy discovery routes to the tethered recognition overlay")
	_check(host.get_node_or_null("TutorialCardOverlay") == null, "enemy discovery bypasses the blocking tutorial overlay")
	_check(blocking_states.is_empty(), "enemy recognition does not advertise a blocking modal state")
	if routed_overlay != null:
		routed_overlay.call("_process", 0.81)
		routed_overlay.call("_process", 5.0)
	await process_frame
	_check(bool(global.call("is_enemy_discovered", &"enemy_runner")), "completed recognition archives the archetype")

	events.disconnect(&"tutorial_modal_state_changed", modal_cb)
	host.queue_free()
	current_scene = null
	discoveries.assign(previous_discoveries)
	global.set("debug_force_enemy_introductions", previous_force)
	await process_frame


func _verify_controller_teardown_during_enemy_card(_target: Node2D) -> void:
	var global := root.get_node("Global")
	var discoveries: Array = global.get("discovered_enemy_ids") as Array
	var previous_discoveries: Array = discoveries.duplicate()
	var previous_force: bool = bool(global.get("debug_force_enemy_introductions"))
	global.set("debug_force_enemy_introductions", true)
	discoveries.erase(&"enemy_runner")

	var host := Node.new()
	root.add_child(host)
	current_scene = host
	var controller_script := load("res://ui/controllers/TutorialModalController.gd") as Script
	var controller: Node = controller_script.new()
	host.add_child(controller)
	var enemy := EnemyFixture.new()
	enemy.spec = EnemySpec.new()
	enemy.spec.id = &"enemy_runner"
	enemy.spec.display_name = "Runner"
	host.add_child(enemy)

	controller.call("_on_enemy_encountered", enemy)
	await process_frame
	_check(
		host.get_node_or_null("FirstEncounterOverlay") != null,
		"teardown regression starts with an active enemy dossier"
	)
	host.remove_child(controller)
	await process_frame
	_check(
		not controller.is_inside_tree(),
		"removing a controller during an enemy dossier completes without a tree access error"
	)

	controller.free()
	host.queue_free()
	current_scene = null
	discoveries.assign(previous_discoveries)
	global.set("debug_force_enemy_introductions", previous_force)
	await process_frame


func _contains_button(node: Node) -> bool:
	if node is Button:
		return true
	for child in node.get_children():
		if _contains_button(child):
			return true
	return false


func _collect_label_text(node: Node) -> String:
	var parts := PackedStringArray()
	if node is Label:
		parts.append((node as Label).text)
	for child in node.get_children():
		parts.append(_collect_label_text(child))
	return "\n".join(parts)


func _finish() -> void:
	print("FirstEncounterPresentationTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
