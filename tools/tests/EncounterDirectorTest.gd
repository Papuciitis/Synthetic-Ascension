extends Node

# Roadmap Phase 2.4: authored encounter beats scheduled on top of continuous
# pressure. Pins composition, placement, cadence, gating and lifecycle with a
# fake spawner; which beats stop autopilot is the human's playtest.

const DirectorScript = preload("res://core/systems/encounters/EncounterDirector.gd")
const BeatsScript = preload("res://core/systems/encounters/EncounterBeats.gd")

class FakePlayer:
	extends Node2D
	var velocity := Vector2.RIGHT * 120.0

class FakeSpawner:
	extends Node
	var calls: Array[Dictionary] = []
	var blocked := Rect2()
	var tutorial := false
	var members: Array[Node] = []

	func is_tutorial_stage() -> bool:
		return tutorial

	func is_beat_position_valid(pos: Vector2) -> bool:
		return not blocked.has_point(pos)

	func spawn_beat_member(scene_path: String, pos: Vector2, elite: bool) -> Node:
		calls.append({"scene": scene_path, "pos": pos, "elite": elite})
		var node := Node2D.new()
		node.position = pos
		add_child(node)
		members.append(node)
		return node

var _passes := 0
var _failures := 0
var _started: Array = []
var _ended: Array = []


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _make(phase: StringName, unsealed: bool = false) -> Array:
	var spawner := FakeSpawner.new()
	add_child(spawner)
	var player := FakePlayer.new()
	player.position = Vector2(1000.0, 1000.0)
	add_child(player)
	var director := DirectorScript.new()
	director.set_physics_process(false)
	director.phase_provider = func() -> StringName: return phase
	director.unsealed_provider = func() -> bool: return unsealed
	director.first_beat_delay = 45.0
	director.interval_min = 60.0
	director.interval_max = 90.0
	add_child(director)
	director.setup(spawner, player, 4242)
	director.beat_started.connect(func(id: StringName, _label: String, _members: int) -> void: _started.append(id))
	director.beat_ended.connect(func(id: StringName) -> void: _ended.append(id))
	return [director, spawner, player]


func _free_members(spawner: FakeSpawner) -> void:
	for member in spawner.members:
		if is_instance_valid(member):
			member.queue_free()
	spawner.members.clear()


func _run() -> void:
	# --- catalog shape ---
	_check(BeatsScript.CATALOG.size() >= 5 and BeatsScript.CATALOG.size() <= 8, "five to eight authored beats exist (%d)" % BeatsScript.CATALOG.size())
	var ids: Dictionary = {}
	for beat in BeatsScript.CATALOG:
		ids[beat["id"]] = true
		_check(not (beat["members"] as Array).is_empty(), "%s has members" % beat["id"])
	_check(ids.size() == BeatsScript.CATALOG.size(), "beat ids are unique")
	_check(BeatsScript.eligible(&"recon").is_empty(), "no beat is eligible during recon")
	_check(BeatsScript.eligible(&"disturbance").size() < BeatsScript.CATALOG.size(), "some beats wait for ascension")
	_check(BeatsScript.eligible(&"collapse").size() == BeatsScript.CATALOG.size(), "every beat is eligible by collapse")

	# --- cadence: nothing before the first delay, one beat after ---
	var made := _make(&"disturbance")
	var director: Variant = made[0]
	var spawner: FakeSpawner = made[1]
	var player: FakePlayer = made[2]
	director.tick(44.0)
	_check(spawner.calls.is_empty(), "no beat before the first delay")
	director.tick(2.0)
	_check(_started.size() == 1, "the first beat fires after the delay (%d)" % _started.size())
	var first_id: StringName = _started[0] if not _started.is_empty() else &""
	var first_beat := BeatsScript.find(first_id)
	_check(spawner.calls.size() == (first_beat.get("members", []) as Array).size(), "every member of %s is spawned (%d)" % [first_id, spawner.calls.size()])
	_check(int(director.get_debug_counters()["active"]) == 1, "the beat is tracked as active")

	# --- placement: members sit near the anchor at the beat's distance ---
	var mode: StringName = first_beat.get("mode", &"ahead")
	var farthest := 0.0
	var nearest := INF
	for call in spawner.calls:
		var d := (call["pos"] as Vector2).distance_to(player.position)
		farthest = maxf(farthest, d)
		nearest = minf(nearest, d)
	var distance := float(first_beat.get("distance", 0.0))
	_check(nearest >= distance * 0.5 and farthest <= distance * 1.6, "%s (%s) is placed around its distance %.0f (nearest %.0f, farthest %.0f)" % [first_id, mode, distance, nearest, farthest])
	if mode == &"ahead":
		var ahead_ok := true
		for call in spawner.calls:
			if ((call["pos"] as Vector2) - player.position).dot(player.velocity.normalized()) <= 0.0:
				ahead_ok = false
		_check(ahead_ok, "an 'ahead' beat is placed along the player's travel")
	elif mode == &"flank":
		var flank_ok := true
		for call in spawner.calls:
			var rel := (call["pos"] as Vector2) - player.position
			if absf(rel.normalized().dot(player.velocity.normalized())) > 0.6:
				flank_ok = false
		_check(flank_ok, "a 'flank' beat sits to the side of travel")

	# --- max_concurrent: no new beat while one is alive ---
	director.tick(200.0)
	_check(_started.size() == 1, "no second beat while the first is alive")
	_free_members(spawner)
	await get_tree().process_frame
	_check(_ended.size() == 1 and _ended[0] == first_id, "the beat ends when its members are gone")
	_check(int(director.get_debug_counters()["active"]) == 0, "and is no longer active")

	# --- never the same beat twice in a row; cooldowns respected ---
	spawner.calls.clear()
	spawner.members.clear()
	director.tick(5.0)
	_check(_started.size() == 2 and _started[1] != first_id, "the next beat differs from the last (%s then %s)" % [first_id, _started[1] if _started.size() > 1 else &"none"])
	var repeat: Dictionary = director.try_spawn_beat(first_id)
	_check(not repeat.is_empty(), "an explicit (authored) spawn bypasses the cooldown")

	# --- gating: tutorial, unsealed rite, recon ---
	_free_members(spawner)
	await get_tree().process_frame
	_started.clear()
	spawner.tutorial = true
	director.tick(500.0)
	_check(_started.is_empty(), "no beats during a tutorial stage")
	spawner.tutorial = false
	director.unsealed_provider = func() -> bool: return true
	director.tick(500.0)
	_check(_started.is_empty(), "no beats once the Exit Rite has unsealed")
	director.unsealed_provider = func() -> bool: return false
	director.phase_provider = func() -> StringName: return &"recon"
	director.tick(500.0)
	_check(_started.is_empty(), "no beats during recon")

	# --- ascension-only beats stay out of disturbance ---
	director.phase_provider = func() -> StringName: return &"disturbance"
	var seen: Dictionary = {}
	for i in range(30):
		var result: Dictionary = director.try_spawn_beat()
		if result.is_empty():
			continue
		seen[result["id"]] = true
		_free_members(spawner)
		await get_tree().process_frame
		director.set("_cooldowns", {})
	_check(not seen.has(&"leech_ring") and not seen.has(&"bomber_carpet"), "ascension beats never fire during disturbance (%s)" % [seen.keys()])
	_check(seen.size() >= 3, "random scheduling covers several beats (%d)" % seen.size())

	# --- placement failure: blocked ground skips members, aborts sparse beats ---
	spawner.calls.clear()
	spawner.blocked = Rect2(Vector2(-100000.0, -100000.0), Vector2(200000.0, 200000.0))
	var aborted: Dictionary = director.try_spawn_beat(&"shield_wall")
	_check(aborted.is_empty(), "a beat with no valid ground aborts")
	_check(int(director.get_debug_counters()["aborted"]) >= 1 and spawner.calls.is_empty(), "nothing is spawned for an aborted beat")
	spawner.blocked = Rect2()

	print("EncounterDirectorTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
