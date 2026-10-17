extends Node

# The main boss's health bar carries its phase marks (65% / 30%): each dims
# once its phase has begun and flashes as it is passed. The Segment 5
# teaching fight has none, and another boss's phase never reaches the bar.
const BAR := preload("res://ui/widgets/BossBarHUD.tscn")
const MAGE := preload("res://scenes/world/bosses/BossArcanist.tscn")
const BossPhases := preload("res://scenes/world/bosses/BossPhases.gd")
var _passes := 0
var _failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _test_phase_rule() -> void:
	_check(BossPhases.marks_for_tier(0).is_empty(), "the teaching tier has no phase marks")
	_check(BossPhases.marks_for_tier(1) == BossPhases.S10_MARKS, "the main tier marks 65% and 30%")
	_check(BossPhases.phase_for(0.66) == 0 and BossPhases.phase_for(0.65) == 1 and BossPhases.phase_for(0.31) == 1, "phase 2 begins at 65%")
	_check(BossPhases.phase_for(0.30) == 2 and BossPhases.phase_for(0.0) == 2, "phase 3 begins at 30%")


func _run() -> void:
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://boss_phase_bar_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	Global.debug_disable_autosave = true
	_test_phase_rule()

	var hud := Control.new()
	hud.size = Vector2(1280, 720)
	add_child(hud)
	var bar := BAR.instantiate() as BossBarHUD
	bar.name = "BossBarHUD"
	hud.add_child(bar)
	var controller := HudBossController.new()
	controller.boss_bar_path = NodePath("../BossBarHUD")
	hud.add_child(controller)
	var front := bar.get_node("Panel/HBox/VBox/HpBar/HpFrame")
	var behind := bar.get_node("Panel/HBox/VBox/HpBar/HpTrack")

	var world := Node2D.new()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	var boss := MAGE.instantiate() as EnemyActor
	var other := MAGE.instantiate() as EnemyActor
	for actor in [boss, other]:
		world.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.get_node("BossBrain").set_process(false)
		actor.get_node("BossBrain").set_physics_process(false)

	RunEvents.boss_spawned.emit(boss, 1, null, "Arcanist")
	_check(bar.visible and front.call("phase_marks") == BossPhases.S10_MARKS and int(front.call("phase_reached")) == 0, "the main boss's bar shows both marks, none spent")
	_check(not behind.has_method("phase_marks") or (behind.call("phase_marks") as Array).is_empty(), "the marks are drawn once, on the front ornament")
	await get_tree().process_frame
	RunEvents.boss_phase_changed.emit(other, 2)
	_check(int(front.call("phase_reached")) == 0, "another boss's phase never reaches this bar")
	RunEvents.boss_phase_changed.emit(boss, 1)
	_check(int(front.call("phase_reached")) == 1, "phase 2 spends the 65% mark")
	_check(float(front.get("_mark_flash")) > 0.0 and front.is_processing(), "the passed mark flashes")
	await get_tree().process_frame
	RunEvents.boss_phase_changed.emit(boss, 0)
	_check(int(front.call("phase_reached")) == 1, "a spent mark stays spent")
	RunEvents.boss_phase_changed.emit(boss, 2)
	_check(int(front.call("phase_reached")) == 2, "phase 3 spends the 30% mark")
	var waited := 0
	while front.is_processing() and waited < 120:
		await get_tree().process_frame
		waited += 1
	_check(not front.is_processing() and is_zero_approx(float(front.get("_mark_flash"))), "the flash settles and the ornament stops processing")

	RunEvents.boss_cleared.emit(boss, 1)
	_check(not bar.visible, "the bar leaves with its boss")
	RunEvents.boss_spawned.emit(other, 0, null, "Teaching")
	_check(bar.visible and (front.call("phase_marks") as Array).is_empty() and int(front.call("phase_reached")) == 0, "the teaching fight's bar has no marks")
	RunEvents.boss_phase_changed.emit(other, 1)
	_check(int(front.call("phase_reached")) == 0, "a bar without marks has no phase to spend")
	await get_tree().process_frame

	RunEvents.boss_cleared.emit(other, 0)
	get_tree().current_scene = self
	world.queue_free()
	hud.queue_free()
	await get_tree().process_frame
	print("BossPhaseBarTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
