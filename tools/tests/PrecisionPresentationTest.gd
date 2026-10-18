extends Node
const PLAYER := preload("res://core/actors/player/player.tscn")
var _passes := 0
var _failures := 0

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	Global.selected_style_id = "ranged"
	Global.attempt_ascension = AscensionLedger.fresh_state("ranged")
	var ledger := Global.ascension_ledger()
	ledger.note_segment_completed(9)
	for id in ["PRQ", "PRV", "PRQ1", "PRQ3", "PRQ4"]:
		ledger.record_purchase(id, 100)
	var player := PLAYER.instantiate() as Node2D
	add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	var runner := player.get_node("AscensionRunner") as AscensionRunner
	runner.set_process(false)
	var engine := runner.engine_of_discipline("PR") as PrecisionEngine
	_check(engine != null, "real Precision engine builds")
	if engine == null:
		get_tree().quit(1)
		return
	runner.aim_override = player.global_position + Vector2(400, 0)
	var before := player.transform
	var hp := float(player.get("hp"))
	engine.activate_q("PRQ")
	var state := engine.presentation_state()
	var lanes: Array = state.get("aim", [])
	_check(lanes.size() == 10, "Twin Fan preview shows every accepted beam")
	var widths_exact := true
	for lane: Array in lanes:
		widths_exact = widths_exact and is_equal_approx(float(lane[2]), AscensionRunner.R / 12.0)
	_check(widths_exact, "Wallbang preview uses its actual narrower hit radius")
	var painter := runner.get_node_or_null("PrecisionPresentation")
	_check(painter != null, "one painter is attached to the real runner")
	engine.release_q("PRQ")
	_check(not engine.q_active("PRQ") and Engine.time_scale == 1.0, "release preserves the existing hold and slow lifecycle")
	for index in range(70):
		engine._present_line(Vector2.ZERO, Vector2(600, 0), 12.0, index % 2 == 0)
	_check(painter.get("_releases").size() == 18, "burst and proc releases have fixed capacity")
	_check(player.transform == before and float(player.get("hp")) == hp, "presentation does not move or charge health from the player")
	get_tree().paused = true
	_check(not painter.can_process(), "presentation pauses with the encounter")
	get_tree().paused = false
	painter.call("_process", 0.5)
	_check(painter.get("_releases").is_empty(), "the last released lane expires")
	engine.activate_v("PRV")
	engine.place_line(Vector2.RIGHT)
	state = engine.presentation_state()
	var plots: Array = state.get("plots", [])
	_check(plots.size() == 1 and is_equal_approx(float(plots[0][2]), AscensionRunner.R * 0.5), "Judgment plots match the real wide line radius")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	SettingsManager.set_value(&"accessibility", &"combat_flash", &"off", false)
	painter.call("_process", 0.0)
	_check(not painter.get("_state").is_empty(), "Reduced Motion and flashes off retain essential aiming geometry")
	get_tree().paused = true
	RunEvents.player_life_event.emit(player, &"death")
	_check(painter.get("_state").is_empty() and painter.get("_releases").is_empty(), "death clears presentation even when the tree already paused")
	get_tree().paused = false
	player.set("is_dead", true)
	painter.call("_process", 0.0)
	_check(painter.get("_state").is_empty() and painter.get("_releases").is_empty(), "death wipes held and released visual state")
	player.set("is_dead", false)
	Global.attempt_ascension = AscensionLedger.fresh_state("ranged")
	runner.refresh()
	painter.call("_process", 0.0)
	_check(painter.is_queued_for_deletion(), "a replaced engine cannot leave a stale painter")
	Engine.time_scale = 1.0
	player.queue_free()
	await get_tree().process_frame
	print("PrecisionPresentationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
