extends Node

# Real BattleText and EnemyWorld integration: retries cannot flood captions,
# stale generations cannot suppress a new target, and disabling callouts
# must not consume their next opportunity to appear.
const FEEDBACK_PATH := "res://core/combat/CombatStatusFeedback.gd"
const SpawnState := preload("res://core/systems/enemy_world/EnemySpawnState.gd")

class Actor:
	extends Node2D
	var dead := false

var _passes := 0
var _failures := 0
var _feedback: Script


func _ready() -> void:
	call_deferred(&"_run")


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _spawn() -> int:
	return EnemyWorld.create_enemy(SpawnState.new(&"feedback_test", "", Vector2(100.0, 100.0), 50.0, 0.0, 4.0, 0))


func _reset() -> void:
	_feedback.call("clear")
	BattleText.clear()
	BattleText.set_process(false)


func _run() -> void:
	Global.debug_disable_autosave = true
	_check(ResourceLoader.exists(FEEDBACK_PATH), "implemented status applications have one bounded feedback gate")
	if ResourceLoader.exists(FEEDBACK_PATH):
		_feedback = load(FEEDBACK_PATH) as Script
	var previous: Variant = SettingsManager.get_value(&"accessibility", &"ability_callouts", true)
	SettingsManager.set_value(&"accessibility", &"ability_callouts", true, false)
	if _feedback != null:
		_test_cooldown_and_settings()
		_test_handles_and_actors()
		await _test_frame_budget()
		await _test_bounded_cache()
		_reset()
	EnemyWorld.clear_world()
	SettingsManager.set_value(&"accessibility", &"ability_callouts", previous, false)
	print("StatusFeedbackTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_cooldown_and_settings() -> void:
	_reset()
	_check(_feedback.call("notify_at", Vector2.ZERO, &"burn", 31), "first application produces a canonical status caption")
	_check(not _feedback.call("notify_at", Vector2.ZERO, &"burn", 31) and BattleText.get("_count") == 1, "reapplying the same target and status during cooldown produces no duplicate caption")
	_check(_feedback.call("notify_at", Vector2.ZERO, &"bleed", 31) and _feedback.call("notify_at", Vector2.ZERO, &"burn", 32), "different statuses and different targets retain independent feedback opportunities")
	# Age the real cooldown record directly; no test clock or callback enters
	# production, and the suite does not wait 1.5 seconds for every boundary.
	var targets: Dictionary = _feedback.get("_targets")
	targets[31][&"burn"] = Time.get_ticks_msec() - 1501
	_check(_feedback.call("notify_at", Vector2.ZERO, &"burn", 31), "a status may be announced again after the 1.5 second cooldown")
	_reset()
	_check(_feedback.call("notify_at", Vector2.ZERO, &"burn", 31), "clearing run feedback removes old target cooldowns")
	_reset()
	SettingsManager.set_value(&"accessibility", &"ability_callouts", false, false)
	_check(not _feedback.call("notify_at", Vector2.ZERO, &"stun", 55) and BattleText.get("_count") == 0, "disabled callouts remain silent")
	SettingsManager.set_value(&"accessibility", &"ability_callouts", true, false)
	_check(_feedback.call("notify_at", Vector2.ZERO, &"stun", 55), "an application while disabled cannot poison the cooldown after re-enabling")
	_check(not _feedback.call("notify_at", Vector2.ZERO, &"not_a_status", 55), "unknown status IDs cannot consume a caption")


func _test_handles_and_actors() -> void:
	_reset()
	_check(not _feedback.call("notify_handle", 0, &"slow"), "invalid handles produce no status feedback")
	var first := _spawn()
	_check(_feedback.call("notify_handle", first, &"slow"), "a live data-only enemy can announce a status")
	EnemyWorld.remove_enemy(first, &"feedback_test")
	var replacement := _spawn()
	_check(not _feedback.call("notify_handle", first, &"slow") and _feedback.call("notify_handle", replacement, &"slow"), "reused slots announce the new generation while stale handles stay silent")
	EnemyWorld.set_health(replacement, 0.0)
	EnemyWorld.try_begin_death(replacement)
	_check(not _feedback.call("notify_handle", replacement, &"burn"), "a dying record never produces a new status caption")
	var actor := Actor.new()
	add_child(actor)
	_check(_feedback.call("notify_actor", actor, &"warded"), "an actor outside EnemyWorld can announce a status")
	_check(not _feedback.call("notify_at", Vector2.ZERO, &"warded", -int(actor.get_instance_id())), "legacy actor feedback uses the negative instance ID target namespace")
	actor.dead = true
	_check(not _feedback.call("notify_actor", actor, &"haste"), "dead actors stay silent")
	actor.dead = false
	var bound := _spawn()
	EnemyWorld.bind_actor(bound, actor)
	_check(_feedback.call("notify_actor", actor, &"haste") and not _feedback.call("notify_handle", bound, &"haste"), "actor and handle paths share the authoritative target cooldown when bound")
	actor.queue_free()
	_check(not _feedback.call("notify_actor", actor, &"fading"), "an actor queued for deletion cannot produce feedback")


func _test_frame_budget() -> void:
	_reset()
	var accepted := 0
	for target in range(12):
		accepted += int(_feedback.call("notify_at", Vector2.ZERO, &"burn", 100 + target))
	_check(accepted == 8 and BattleText.get("_count") == 8, "a burst is capped at eight new status captions in one process frame")
	# The first process_frame signal can precede the engine's first counter
	# increment when this suite starts from a deferred _ready callback.
	var frame := Engine.get_process_frames()
	while Engine.get_process_frames() == frame:
		await get_tree().process_frame
	_check(_feedback.call("notify_at", Vector2.ZERO, &"burn", 108), "the next process frame restores the budget without consuming deferred target cooldowns")


func _test_bounded_cache() -> void:
	_reset()
	for target in range(520):
		if target > 0 and target % 8 == 0:
			await get_tree().process_frame
		_feedback.call("notify_at", Vector2.ZERO, &"burn", 1000 + target)
	var targets: Dictionary = _feedback.get("_targets")
	_check(targets.size() <= 512, "sustained target churn keeps cooldown storage bounded at 512 targets")
	# Expired records should not crowd out useful entries indefinitely.
	for target: int in targets:
		for id: StringName in targets[target]:
			targets[target][id] = Time.get_ticks_msec() - 1501
	await get_tree().process_frame
	_check(_feedback.call("notify_at", Vector2.ZERO, &"stun", 9000) and targets.size() < 512, "expired target cooldowns are pruned on new applications")
