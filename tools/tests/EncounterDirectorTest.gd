extends Node

# Roadmap Phase 2.4: authored encounter beats scheduled on top of continuous
# pressure. Pins composition, placement, cadence, gating and lifecycle with a
# fake spawner; which beats stop autopilot is the human's playtest.

const DirectorScript = preload("res://core/systems/encounters/EncounterDirector.gd")
const BeatsScript = preload("res://core/systems/encounters/EncounterBeats.gd")

class FakePlayer:
	extends Node2D
	var velocity := Vector2.RIGHT * 120.0

class FakeMember:
	extends Node2D
	var modifiers: Array[StringName] = []

	func apply_elite_modifiers(ids: Array[StringName]) -> void:
		modifiers = ids.duplicate()

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
		var node := FakeMember.new()
		node.position = pos
		add_child(node)
		members.append(node)
		return node

var _passes := 0
var _failures := 0
var _started: Array = []
var _ended: Array = []
var _tips: Array[String] = []


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
	if not RunEvents.tutorial_tip.is_connected(_on_tip):
		RunEvents.tutorial_tip.connect(_on_tip)
	return [director, spawner, player]


func _on_tip(text: String, _duration: float) -> void:
	_tips.append(text)


func _reset(director: Node, spawner: FakeSpawner) -> void:
	_free_members(spawner)
	for ritual in get_tree().get_nodes_in_group(&"ritual_interference"):
		ritual.call("expire", &"test_reset")
	await get_tree().process_frame
	director.set("_active", {})
	director.set("_cooldowns", {})
	director.set("_last_beat_id", &"")
	spawner.calls.clear()
	_started.clear()
	_ended.clear()


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

	# --- 2.7: a phase escalation announces itself and fires a newly unlocked beat soon ---
	_free_members(spawner)
	await get_tree().process_frame
	director.set("_cooldowns", {})
	director.set("_active", {})
	_started.clear()
	director.phase_provider = func() -> StringName: return &"disturbance"
	director.tick(0.1)
	director.set("_next_beat_in", 300.0)
	var escalations_before := int(director.get_debug_counters()["escalations"])
	director.phase_provider = func() -> StringName: return &"ascension"
	director.tick(0.1)
	_check(int(director.get_debug_counters()["escalations"]) == escalations_before + 1, "a phase escalation is counted")
	_check(float(director.get_debug_counters()["next_beat_in"]) <= 10.0, "the next beat is pulled forward to within the escalation delay (%.1f)" % float(director.get_debug_counters()["next_beat_in"]))
	director.tick(10.5)
	_check(_started.size() == 1 and (_started[0] == &"bomber_carpet" or _started[0] == &"leech_ring"), "the escalation beat is one the new phase unlocked (%s)" % [_started])

	# --- 2.8: channelling the Exit Rite draws the specialist response ---
	_free_members(spawner)
	await get_tree().process_frame
	director.set("_active", {})
	director.set("_cooldowns", {})
	_started.clear()
	spawner.calls.clear()
	director.call("_on_rite_channel_changed", true)
	_check(_started.size() == 2 and _started.has(&"sniper_crossfire") and _started.has(&"charger_wedge"), "the rite draws a crossfire and a wedge (%s)" % [_started])
	director.call("_on_rite_channel_changed", true)
	_check(_started.size() == 2, "the specialist response is sent once per run")

	# --- placement failure: blocked ground skips members, aborts sparse beats ---
	spawner.calls.clear()
	spawner.blocked = Rect2(Vector2(-100000.0, -100000.0), Vector2(200000.0, 200000.0))
	var aborted: Dictionary = director.try_spawn_beat(&"shield_wall")
	_check(aborted.is_empty(), "a beat with no valid ground aborts")
	_check(int(director.get_debug_counters()["aborted"]) >= 1 and spawner.calls.is_empty(), "nothing is spawned for an aborted beat")
	spawner.blocked = Rect2()

	# --- §9: the hunter carries fast + vampiric; any member that can take a
	# beat's modifiers gets them, deferred behind the spawner's make_elite ---
	await _reset(director, spawner)
	var hunter := BeatsScript.find(&"hunter")
	var hunter_mods: Array = hunter.get("modifiers", [])
	_check(hunter_mods.size() == 2 and hunter_mods[0] == &"fast" and hunter_mods[1] == &"vampiric", "the hunter is composed with fast + vampiric (%s)" % [hunter_mods])
	var hunt: Dictionary = director.try_spawn_beat(&"hunter")
	_check(not hunt.is_empty() and spawner.members.size() == 1 and (spawner.members[0] as FakeMember).modifiers.is_empty(), "the modifiers are not applied synchronously (before the deferred promotion)")
	await get_tree().process_frame
	var hunter_member: FakeMember = spawner.members[0] as FakeMember if spawner.members.size() == 1 else null
	_check(hunter_member != null and hunter_member.modifiers.size() == 2 and hunter_member.modifiers[0] == &"fast" and hunter_member.modifiers[1] == &"vampiric", "the hunter member receives the entry's modifiers (%s)" % [hunter_member.modifiers if hunter_member != null else []])
	await _reset(director, spawner)
	director.try_spawn_beat(&"charger_wedge")
	await get_tree().process_frame
	var stray_mods := false
	for member in spawner.members:
		if not (member as FakeMember).modifiers.is_empty():
			stray_mods = true
	_check(spawner.members.size() == 6 and not stray_mods, "a beat without modifiers passes none")

	# --- 2.7: ritual interference exists only while the district collapses ---
	await _reset(director, spawner)
	var ritual_beat := BeatsScript.find(&"ritual_interference")
	_check(not ritual_beat.is_empty() and ritual_beat["min_phase"] == &"collapse" and BeatsScript.is_ritual(ritual_beat), "the ritual beat exists, is a ritual, and waits for collapse")
	var ascension_ids: Array = []
	for beat in BeatsScript.eligible(&"ascension"):
		ascension_ids.append(beat["id"])
	_check(not ascension_ids.has(&"ritual_interference"), "…and is not eligible in ascension")
	director.phase_provider = func() -> StringName: return &"ascension"
	_check(director.try_spawn_beat(&"ritual_interference").is_empty(), "an authored ritual is refused outside collapse")
	director.phase_provider = func() -> StringName: return &"collapse"
	director.unsealed_provider = func() -> bool: return true
	_check(director.try_spawn_beat(&"ritual_interference").is_empty(), "…and once the rite has unsealed")
	director.unsealed_provider = func() -> bool: return false
	_check(get_tree().get_nodes_in_group(&"ritual_interference").is_empty() and spawner.calls.is_empty() and _started.is_empty(), "the refused rituals placed and announced nothing")
	var announced_before := int(director.get_debug_counters()["announced"])
	var placed: Dictionary = director.try_spawn_beat(&"ritual_interference")
	var rituals := get_tree().get_nodes_in_group(&"ritual_interference")
	_check(not placed.is_empty() and rituals.size() == 1, "in collapse the ritual is placed (%d node)" % rituals.size())
	_check(spawner.calls.is_empty(), "the ritual spawns no enemies of its own")
	if rituals.size() == 1:
		var ritual := rituals[0] as Node2D
		var rel := ritual.global_position - player.position
		_check(is_equal_approx(rel.length(), float(ritual_beat["distance"])) and rel.normalized().dot(player.velocity.normalized()) > 0.99, "the ritual sits ahead of travel at its distance (%.0f)" % rel.length())
		_check(ritual.get("_spawner") == spawner, "the ritual is handed the spawner for its revenants")
	_check(_started.size() == 1 and _started[0] == &"ritual_interference", "the ritual reports beat_started once")
	_check(int(director.get_debug_counters()["announced"]) == announced_before + 1, "…and is announced once")
	var ritual_tips := _tips.filter(func(t: String) -> bool: return t.contains("sigil"))
	_check(ritual_tips.size() == 1, "the first ritual of the run teaches the rule once (%d)" % ritual_tips.size())
	_check(director.active_beats().has(&"ritual_interference") and not director.can_schedule(), "the ritual is the active beat: nothing else schedules meanwhile")
	if rituals.size() == 1:
		rituals[0].call("expire", &"duration")
	await get_tree().process_frame
	_check(_ended.size() == 1 and _ended[0] == &"ritual_interference", "the ritual's expiry ends the beat")
	_check((director.get("_cooldowns") as Dictionary).has(&"ritual_interference") and director.active_beats().is_empty(), "…and leaves the ritual on cooldown like any beat")
	director.set("_cooldowns", {})
	director.set("_last_beat_id", &"")
	var second: Dictionary = director.try_spawn_beat(&"ritual_interference")
	ritual_tips = _tips.filter(func(t: String) -> bool: return t.contains("sigil"))
	_check(not second.is_empty() and _started.size() == 2 and ritual_tips.size() == 1, "a second ritual is announced but does not teach again")
	# Blocked ground aborts a ritual like any beat, and places no node.
	await _reset(director, spawner)
	spawner.blocked = Rect2(Vector2(-100000.0, -100000.0), Vector2(200000.0, 200000.0))
	_check(director.try_spawn_beat(&"ritual_interference").is_empty() and get_tree().get_nodes_in_group(&"ritual_interference").is_empty(), "a ritual with no valid ground aborts and places nothing")
	spawner.blocked = Rect2()
	await _reset(director, spawner)

	print("EncounterDirectorTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
