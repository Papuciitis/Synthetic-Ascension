extends Node

# The release beat after a completed Exit Rite (2026-10-04 design audit §2):
# ordinary enemies near the player dissolve, elites and far enemies stay,
# spawning stops, the player is protected and the clock is handed back.
#
# Run: <godot> --headless --path . res://tools/tests/EscapeReleaseTest.tscn

const ReleaseScript = preload("res://core/systems/world/EscapeRelease.gd")
const BeatsScript = preload("res://core/systems/encounters/EncounterBeats.gd")

class FakePlayer:
	extends Node2D
	var invulnerable_for := 0.0
	var is_dead := false

	func grant_invulnerability(seconds: float) -> void:
		invulnerable_for = maxf(invulnerable_for, seconds)

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


func _gone(node: Variant) -> bool:
	if node == null or not is_instance_valid(node):
		return true
	return (node as Node).is_queued_for_deletion() or bool((node as Node).get_meta("culled", false))


func _run() -> void:
	var player := FakePlayer.new()
	player.add_to_group(&"player")
	add_child(player)
	var spawner := EnemySpawner.new()
	add_child(spawner)
	await get_tree().process_frame
	spawner.set_process(false)

	var near: Array[Node] = []
	for i in range(3):
		near.append(spawner.spawn_beat_member(BeatsScript.GRUNT, Vector2(240.0 + 90.0 * i, 0.0)))
	var far := spawner.spawn_beat_member(BeatsScript.GRUNT, Vector2(2200.0, 0.0))
	var elite := spawner.spawn_beat_member(BeatsScript.GRUNT, Vector2(0.0, 300.0), true)
	for _frame in range(4):
		await get_tree().process_frame
	_check(near.all(func(n: Node) -> bool: return n != null and is_instance_valid(n)) and far != null and elite != null, "the fixture enemies exist")

	var release := ReleaseScript.new()
	add_child(release)
	var targets: Array[Dictionary] = release.collect_targets(player.global_position, ReleaseScript.RADIUS_PX)
	var target_nodes: Array = []
	for target in targets:
		if target.has("node"):
			target_nodes.append(target["node"])
	_check(near.all(func(n: Node) -> bool: return target_nodes.has(n)), "every ordinary enemy in reach is a target")
	_check(not target_nodes.has(far), "an enemy beyond the radius is not")
	_check(not target_nodes.has(elite), "an elite is not")
	var ordered := true
	for i in range(1, targets.size()):
		if float(targets[i]["d2"]) < float(targets[i - 1]["d2"]):
			ordered = false
	_check(ordered, "targets dissolve nearest-first")

	var started := Time.get_ticks_msec()
	await release.play(player)
	var took := float(Time.get_ticks_msec() - started) / 1000.0
	_check(took >= ReleaseScript.DURATION_SEC - 0.05 and took < ReleaseScript.DURATION_SEC + 1.0, "the beat lasts its real-time duration (%.2fs)" % took)
	_check(near.all(func(n: Variant) -> bool: return _gone(n)), "the ordinary enemies dissolved")
	_check(not _gone(far) and not _gone(elite), "the far enemy and the elite remain")
	_check(release.cleared_count() >= 3, "the release counts what it cleared (%d)" % release.cleared_count())
	_check(not spawner.spawning_enabled, "ambient spawning stopped for the escape")
	_check(player.invulnerable_for >= ReleaseScript.DURATION_SEC, "the player is untouchable for the whole beat (%.1fs)" % player.invulnerable_for)
	_check(is_equal_approx(Engine.time_scale, 1.0), "the clock is handed back at full speed")

	# A clock someone else slowed is left alone.
	var other := ReleaseScript.new()
	add_child(other)
	Engine.time_scale = 0.25
	other.play(player)
	await get_tree().process_frame
	_check(is_equal_approx(Engine.time_scale, 0.25), "a slower clock owned elsewhere is not overridden")
	other.queue_free()
	await get_tree().process_frame
	_check(is_equal_approx(Engine.time_scale, 0.25), "nor restored by a release freed mid-beat")
	Engine.time_scale = 1.0

	for node in [far, elite]:
		if is_instance_valid(node) and node.has_method("despawn"):
			node.call("despawn", &"test_cleanup")
	release.queue_free()
	spawner.queue_free()
	player.queue_free()
	await get_tree().process_frame
	print("EscapeReleaseTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
