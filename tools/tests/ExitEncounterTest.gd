extends Node

# The exit encounter lifecycle (plan 2026-09-17 §6.1; playtest finding 4):
# pressure suppression follows the ENCOUNTER, not circle occupancy. A dodge
# across the channel edge keeps ambient spawning suppressed; only a real
# 8-second disengage beyond the release radius (alive), completion, or scene
# cleanup releases it. Recovery after death holds it. The group observed by
# ThreatDirector/EncounterDirector ("exit_rite_channeling") follows the
# controller through the real ExitRite.
#
# Run: <godot> --headless --path . res://tools/tests/ExitEncounterTest.tscn

const EXIT_RITE_SCENE: PackedScene = preload("res://scenes/world/gates/ExitRite.tscn")

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


func _run() -> void:
	# ---------------- The pure state machine.
	var c := ExitEncounterController.new()
	_check(c.state() == c.STATE_INACTIVE and not c.is_active(), "an untouched encounter is inactive")
	c.update_state(true, 2000.0, true, 0.1)
	_check(not c.is_active(), "distance alone outside the entry radius arms nothing")
	c.update_state(true, 1100.0, true, 0.1)
	_check(c.state() == c.STATE_APPROACH, "entering 1200 px of an eligible rite begins the encounter")

	# The finding itself: channel-edge exits and dodges never release it.
	c.set_channeling(true)
	_check(c.state() == c.STATE_CHANNEL, "real channel membership is the channel state")
	c.set_channeling(false)
	_check(c.state() == c.STATE_APPROACH and c.is_active(), "a channel-edge exit drops to approach, never to inactive")
	for _i in range(20):
		c.update_state(true, 1500.0, true, 0.35)   # 7 s of dodging inside release radius
	_check(c.is_active(), "dodging inside the release radius keeps the encounter live")
	c.update_state(true, 1900.0, true, 7.5)
	c.update_state(true, 1700.0, true, 0.1)        # back inside before 8 s
	c.update_state(true, 1900.0, true, 7.5)
	_check(c.is_active(), "re-entry resets the disengage clock — 7.5 s twice is not 8 s once")
	c.update_state(true, 1900.0, true, 0.6)
	_check(c.state() == c.STATE_INACTIVE, "8 continuous living seconds beyond 1800 px disengages")

	# Death never counts toward disengaging, and recovery holds the encounter.
	c.update_state(true, 1000.0, true, 0.1)
	c.update_state(true, 2000.0, false, 30.0)
	_check(c.is_active(), "a dead player cannot run out the disengage clock")
	c.begin_recovery()
	_check(c.state() == c.STATE_RECOVERY, "death at the gate enters recovery")
	c.update_state(true, 5000.0, true, 9.0)
	_check(c.state() == c.STATE_RECOVERY, "recovery holds for its full window wherever reconstruction lands")
	c.update_state(true, 5000.0, true, 2.0)
	_check(c.state() == c.STATE_APPROACH, "after recovery the encounter resumes where it stood")

	# Completion is terminal until cleanup.
	c.complete()
	_check(c.state() == c.STATE_COMPLETED and not c.is_active(), "completion ends the encounter")
	c.update_state(true, 100.0, true, 0.1)
	c.set_channeling(true)
	_check(c.state() == c.STATE_COMPLETED, "a completed rite never re-arms pressure")

	# Relocking releases a live encounter.
	var relock := ExitEncounterController.new()
	relock.update_state(true, 500.0, true, 0.1)
	relock.update_state(false, 500.0, true, 0.1)
	_check(relock.state() == relock.STATE_INACTIVE, "a resealed rite has no encounter to keep alive")

	# ---------------- Through the real rite and the observed group.
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	var rite := EXIT_RITE_SCENE.instantiate() as ExitRite
	add_child(rite)
	rite.global_position = Vector2.ZERO
	await get_tree().process_frame
	rite.set_revealed(true)
	rite.set_locked(false)
	player.global_position = Vector2(800, 0)
	rite._feed_encounter(0.1)
	_check(rite.is_in_group(&"exit_rite_channeling"), "an approach within 1200 px suppresses ambient pressure")
	rite._on_body_entered(player)
	rite._on_body_exited(player)
	_check(rite.is_in_group(&"exit_rite_channeling"), "the dodge that restarted hordes in playtest no longer releases the group")
	player.global_position = Vector2(1900, 0)
	rite._feed_encounter(8.2)
	_check(not rite.is_in_group(&"exit_rite_channeling"), "a real 8 s disengage releases the group")
	player.global_position = Vector2(600, 0)
	rite._feed_encounter(0.1)
	_check(rite.is_in_group(&"exit_rite_channeling"), "coming back re-arms the encounter")
	rite.set_locked(true)
	_check(not rite.is_in_group(&"exit_rite_channeling"), "resealing the rite releases the group immediately")
	rite.queue_free()
	player.queue_free()
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group(&"exit_rite_channeling").is_empty(), "scene cleanup leaves no channeling members behind")

	print("ExitEncounterTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
