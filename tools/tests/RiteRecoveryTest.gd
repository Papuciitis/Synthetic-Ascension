extends Node

# Plan 2026-09-17 §6.4 (reconstruction during the exit encounter), the two
# halves that live in the rite and the encounter director:
#   - after a death in the encounter the kept progress does not drain for up
#     to 10 s while the player returns; re-entering the channel ends the hold;
#   - a reconstruction blocks new local reinforcements for 5 s, and channel
#     waves asked for meanwhile arrive when the hold ends instead of vanishing.
# (The respawn point itself is RiteRespawnTest.)
#
# Run: <godot> --headless --path . res://tools/tests/RiteRecoveryTest.tscn

const EXIT_RITE_SCENE: PackedScene = preload("res://scenes/world/gates/ExitRite.tscn")
const DirectorScript = preload("res://core/systems/encounters/EncounterDirector.gd")

class FakePlayer:
	extends Node2D
	var velocity := Vector2.RIGHT * 120.0
	var is_dead := false

class FakeSpawner:
	extends Node
	var members: Array[Node] = []

	func is_tutorial_stage() -> bool:
		return false

	func is_beat_position_valid(_pos: Vector2) -> bool:
		return true

	func set_rite_pressure_active(_active: bool) -> void:
		pass

	func spawn_beat_member(_scene_path: String, pos: Vector2, _elite: bool) -> Node:
		var node := Node2D.new()
		node.position = pos
		add_child(node)
		members.append(node)
		return node

var _passes := 0
var _failures := 0
var _started: Array[StringName] = []


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
	await _rite_checks()
	await _director_checks()
	print("RiteRecoveryTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _rite_checks() -> void:
	var rite := EXIT_RITE_SCENE.instantiate() as ExitRite
	add_child(rite)
	await get_tree().process_frame
	rite.set_revealed(true)
	rite.set_locked(false)
	var half := rite.hold_time * 0.5

	# No encounter, no hold: an ordinary lapse drains.
	rite.set("_hold", half)
	rite.call("_on_player_life_event", null, &"death")
	_check(is_zero_approx(float(rite.get("_recovery_drain_hold"))), "a death away from a live encounter holds nothing")

	# A death inside the live encounter holds the kept progress.
	var encounter: ExitEncounterController = rite.get("_encounter")
	encounter.update_state(true, 100.0, true, 0.1)
	_check(encounter.is_active(), "the encounter is live near the rite")
	rite.call("_on_player_life_event", null, &"death")
	_check(is_equal_approx(float(rite.get("_recovery_drain_hold")), ExitRite.RECOVERY_DRAIN_HOLD_SECONDS), "a death in the encounter starts the drain hold")
	rite.call("_process", 3.0)
	_check(is_equal_approx(float(rite.get("_hold")), half), "the kept progress does not drain while the player returns")
	rite.call("_process", 8.0)
	rite.call("_process", 2.0)
	_check(float(rite.get("_hold")) < half, "after the hold the ordinary lapse drain resumes (%.2f < %.2f)" % [float(rite.get("_hold")), half])

	# Re-entering the channel ends the hold at once.
	rite.set("_hold", half)
	encounter.update_state(true, 100.0, true, 0.1)
	rite.call("_on_player_life_event", null, &"death")
	var walker := FakePlayer.new()
	walker.add_to_group(&"player")
	add_child(walker)
	rite.call("_on_body_entered", walker)
	_check(is_zero_approx(float(rite.get("_recovery_drain_hold"))), "re-entering the channel ends the hold")
	rite.call("_on_body_exited", walker)
	walker.queue_free()
	rite.queue_free()
	await get_tree().process_frame


func _director_checks() -> void:
	var spawner := FakeSpawner.new()
	add_child(spawner)
	var player := FakePlayer.new()
	player.position = Vector2(1000.0, 1000.0)
	add_child(player)
	var director := DirectorScript.new()
	director.set_physics_process(false)
	director.phase_provider = func() -> StringName: return &"collapse"
	director.unsealed_provider = func() -> bool: return true
	add_child(director)
	director.setup(spawner, player, 99)
	director.beat_started.connect(func(id: StringName, _label: String, _members: int) -> void: _started.append(id))
	director.call("_on_rite_channel_changed", true)
	for member in spawner.members:
		member.queue_free()
	spawner.members.clear()
	await get_tree().process_frame
	director.set("_active", {})
	_started.clear()

	director.call("_on_player_life_event", player, &"respawn")
	_check(not bool(director.call("request_rite_wave")), "a channel wave during the respawn hold is held, not sent")
	_check(not bool(director.call("request_rite_reinforcement")), "and no reinforcement is sent either")
	director.set("_rite_response_left", 100.0)
	director.tick(2.0)
	_check(_started.is_empty(), "nothing arrives inside the five seconds")
	director.tick(3.5)
	_check(_started.size() == 1, "the held wave arrives when the hold ends (%s)" % [_started])
	director.call("_on_rite_channel_changed", false)
	director.call("_on_player_life_event", player, &"respawn")
	_check(is_zero_approx(float(director.get("_reinforcement_hold_left"))), "a respawn outside the exit encounter holds nothing")
	director.queue_free()
	spawner.queue_free()
	player.queue_free()
	await get_tree().process_frame
