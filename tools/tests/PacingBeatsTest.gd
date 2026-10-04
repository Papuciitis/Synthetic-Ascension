extends Node

# 2026-10-04 design audit (docs/audits/2026-10-04-game-design-audit.md §2):
# the pacing rules added on top of the encounter beats and the spawner.
#   - consecutive beats ask different KINDS of question (least recently asked
#     kind first) instead of popping the catalogue in order;
#   - a beat's arrival holds ambient spawning for a moment, and answering it
#     buys a relax window (Left 4 Dead's build-up / peak / relax);
#   - an in-combat power threshold is answered with the rematch ring;
#   - a blocked formation tries the other flank before it gives up;
#   - ambient spawns respect the phase gate and the per-segment introductions,
#     a lull really stretches the interval, and re-announcing segment 1's
#     current stage no longer restarts its spawn clock.
#
# Run: <godot> --headless --path . res://tools/tests/PacingBeatsTest.tscn

const DirectorScript = preload("res://core/systems/encounters/EncounterDirector.gd")
const BeatsScript = preload("res://core/systems/encounters/EncounterBeats.gd")
const TABLE := preload("res://data/enemies/spawn/SpawnTable_Default.tres")

class FakePlayer:
	extends Node2D
	var velocity := Vector2.RIGHT * 120.0

class FakeSpawner:
	extends Node
	var members: Array[Node] = []
	var suspends: Array[float] = []
	var lulls: Array[Vector2] = []
	var blocked_side := 0.0 # > 0 blocks every position right of blocked_x
	var blocked_x := 0.0

	func is_tutorial_stage() -> bool:
		return false

	func is_beat_position_valid(pos: Vector2) -> bool:
		return not (blocked_side > 0.0 and pos.y > blocked_x)

	func set_rite_pressure_active(_active: bool) -> void:
		pass

	func suspend_spawning(seconds: float) -> void:
		suspends.append(seconds)

	func set_ambient_lull(seconds: float, interval_mul: float) -> void:
		lulls.append(Vector2(seconds, interval_mul))

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


func _make(phase: StringName) -> Array:
	var spawner := FakeSpawner.new()
	add_child(spawner)
	var player := FakePlayer.new()
	player.position = Vector2(1000.0, 1000.0)
	add_child(player)
	var director := DirectorScript.new()
	director.set_physics_process(false)
	director.phase_provider = func() -> StringName: return phase
	director.unsealed_provider = func() -> bool: return false
	add_child(director)
	director.setup(spawner, player, 777)
	director.beat_started.connect(func(id: StringName, _label: String, _members: int) -> void: _started.append(id))
	return [director, spawner, player]


func _clear_members(spawner: FakeSpawner) -> void:
	for member in spawner.members:
		if is_instance_valid(member):
			member.queue_free()
	spawner.members.clear()


func _run() -> void:
	var previous_segment: int = Global.attempt_segment
	Global.attempt_segment = 4
	await _director_checks()
	await _spawner_checks()
	_elite_scaling_checks()
	Global.attempt_segment = previous_segment
	await get_tree().process_frame
	print("PacingBeatsTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _director_checks() -> void:
	var made := _make(&"collapse")
	var director: Variant = made[0]
	var spawner: FakeSpawner = made[1]

	# --- kind rotation: twelve scheduled beats, no kind twice in a row and
	# every kind asked before any is asked a third time ---
	var kinds: Array[StringName] = []
	var counts: Dictionary = {}
	for i in range(12):
		var result: Dictionary = director.try_spawn_beat()
		if result.is_empty():
			continue
		var kind := BeatsScript.kind_of(BeatsScript.find(result["id"]))
		kinds.append(kind)
		counts[kind] = int(counts.get(kind, 0)) + 1
		_clear_members(spawner)
		await get_tree().process_frame
		director.set("_cooldowns", {})
	var repeats := 0
	for i in range(1, kinds.size()):
		if kinds[i] == kinds[i - 1]:
			repeats += 1
	_check(kinds.size() >= 10, "the director keeps finding beats (%d)" % kinds.size())
	_check(repeats == 0, "no kind is asked twice in a row (%s)" % [kinds])
	var max_count := 0
	for kind in counts:
		max_count = maxi(max_count, int(counts[kind]))
	_check(max_count <= 2, "every kind is asked before any is asked a third time (%s)" % [counts])
	_check(not counts.has(&"rematch"), "the rematch ring never enters the random draw")

	# --- arrival pause and relax window ---
	spawner.suspends.clear()
	spawner.lulls.clear()
	var beat: Dictionary = director.try_spawn_beat(&"shield_wall")
	_check(not beat.is_empty(), "an explicit beat spawns")
	_check(spawner.suspends.size() == 1 and is_equal_approx(spawner.suspends[0], float(director.get("arrival_pause_sec"))), "its arrival holds ambient spawning for %.1f s (%s)" % [float(director.get("arrival_pause_sec")), spawner.suspends])
	_check(spawner.lulls.is_empty(), "no relax window while the formation stands")
	_clear_members(spawner)
	await get_tree().process_frame
	_check(spawner.lulls.size() == 1 and is_equal_approx(spawner.lulls[0].x, float(director.get("lull_seconds"))) and is_equal_approx(spawner.lulls[0].y, float(director.get("lull_interval_mul"))), "answering it buys the relax window (%s)" % [spawner.lulls])

	# --- the rematch ring after an in-combat power threshold ---
	_started.clear()
	director.set("_next_beat_in", 500.0)
	director.call("_on_power_threshold_noted", &"three_manifestations", "3 Manifestations active")
	director.tick(float(director.get("rematch_delay_sec")) * 0.5)
	_check(not _started.has(&"rematch_ring"), "the rematch waits a moment")
	director.tick(float(director.get("rematch_delay_sec")))
	_check(_started.has(&"rematch_ring"), "then the old patrols ring the player")
	var ring: Dictionary = BeatsScript.find(&"rematch_ring")
	_check((ring.get("members", []) as Array).size() >= 12, "the ring is a crowd of old fodder (%d)" % (ring.get("members", []) as Array).size())
	_clear_members(spawner)
	await get_tree().process_frame
	director.set("_rite_channel_active", true)
	_started.clear()
	director.call("_on_power_threshold_noted", &"five_manifestations", "")
	director.set("_rite_response_left", 100.0)
	director.tick(30.0)
	_check(not _started.has(&"rematch_ring"), "never inside the exit encounter")
	director.set("_rite_channel_active", false)

	# --- placement fallback: the travel flank on the right is walled off ---
	_clear_members(spawner)
	await get_tree().process_frame
	director.set("_active", {})
	var player: FakePlayer = made[2]
	player.velocity = Vector2.RIGHT * 120.0
	spawner.blocked_side = 1.0
	spawner.blocked_x = player.position.y + 100.0
	var placed := 0
	for i in range(8):
		var wedge: Dictionary = director.try_spawn_beat(&"charger_wedge")
		if not wedge.is_empty():
			placed += 1
		_clear_members(spawner)
		await get_tree().process_frame
		director.set("_active", {})
	_check(placed == 8, "a wedge whose drawn flank is blocked forms on the other flank (%d/8)" % placed)
	spawner.blocked_side = 0.0

	director.queue_free()
	spawner.queue_free()
	(made[2] as Node).queue_free()
	await get_tree().process_frame


func _spawner_checks() -> void:
	var spawner := EnemySpawner.new()
	spawner.spawning_enabled = false
	spawner.spawn_table = TABLE
	add_child(spawner)
	await get_tree().process_frame
	spawner.set_process(false)

	var director := ThreatDirector
	var previous_phase: StringName = director.segment_phase
	var late_ids := [&"enemy_sniper", &"enemy_warden", &"enemy_lurker", &"enemy_summoner", &"enemy_chanter", &"enemy_siphon", &"enemy_herald", &"enemy_splitter"]

	# --- recon: only the ungated fodder ---
	Global.attempt_segment = 2
	director.segment_phase = &"recon"
	var recon_ids := _picked_ids(spawner, 900.0)
	_check(recon_ids.size() > 0 and recon_ids.all(func(id: StringName) -> bool: return id == &"enemy_grunt" or id == &"enemy_runner"), "recon spawns only grunts and runners even late in a segment (%s)" % [recon_ids])

	# --- segment 2 collapse: the full phase roster minus later introductions ---
	director.segment_phase = &"collapse"
	var seg2_ids := _picked_ids(spawner, 900.0)
	var leaked: Array = []
	for id in seg2_ids:
		if late_ids.has(id):
			leaked.append(id)
	_check(leaked.is_empty(), "segment 2 never spawns the archetypes introduced later (%s)" % [leaked])
	_check(seg2_ids.size() >= 6, "segment 2 collapse still mixes several archetypes (%s)" % [seg2_ids])

	# --- segment 5 collapse: everyone ---
	Global.attempt_segment = 5
	var seg5_ids := _picked_ids(spawner, 900.0)
	_check(seg5_ids.has(&"enemy_herald") or seg5_ids.has(&"enemy_splitter"), "segment 5 introduces the Herald and the Splitter (%s)" % [seg5_ids])
	_check(seg5_ids.has(&"enemy_sniper") or seg5_ids.has(&"enemy_warden") or seg5_ids.has(&"enemy_lurker"), "and keeps segment 3's arrivals (%s)" % [seg5_ids])
	director.segment_phase = previous_phase

	# --- the relax window ---
	_check(is_zero_approx(spawner.ambient_lull_left()), "no lull by default")
	spawner.set_ambient_lull(12.0, 2.0)
	_check(is_equal_approx(spawner.ambient_lull_left(), 12.0), "a lull opens")
	spawner.set_ambient_lull(4.0, 1.5)
	_check(is_equal_approx(spawner.ambient_lull_left(), 12.0), "a weaker request never shortens it")
	spawner._process(13.0)
	_check(is_zero_approx(spawner.ambient_lull_left()), "and it closes on time")

	# --- segment 1: the same stage again is not a new stage ---
	spawner.set_segment1_stage(Segment1SpawnProfile.Stage.OUTER_APPROACH)
	spawner._process(2.0)
	var pause_before := float(spawner.get("_spawn_pause_left"))
	spawner.set_segment1_stage(Segment1SpawnProfile.Stage.OUTER_APPROACH)
	_check(is_equal_approx(float(spawner.get("_spawn_pause_left")), pause_before), "re-announcing the current stage does not restart its grace pause (%.2f)" % float(spawner.get("_spawn_pause_left")))
	spawner.set_segment1_stage(Segment1SpawnProfile.Stage.OUTER_APPROACH, 4.0)
	_check(is_equal_approx(float(spawner.get("_spawn_pause_left")), 4.0), "an explicit grace override still applies")
	spawner.queue_free()
	await get_tree().process_frame


func _picked_ids(spawner: EnemySpawner, seconds: float) -> Array[StringName]:
	var out: Array[StringName] = []
	for i in range(400):
		var entry: EnemySpawnEntry = spawner.call("_pick_enabled_entry", seconds)
		if entry == null:
			continue
		var id: StringName = spawner.call("_enemy_id_for_scene", entry.enemy_scene)
		if not out.has(id):
			out.append(id)
	return out


## Fodder stays paper; elites grow with the segment (Vampire Survivors'
## asymmetry), capped.
func _elite_scaling_checks() -> void:
	_check(is_equal_approx(EliteModifiers.segment_hp_factor(1), 1.0) and is_equal_approx(EliteModifiers.segment_hp_factor(2), 1.0), "elites start at their authored health")
	_check(is_equal_approx(EliteModifiers.segment_hp_factor(5), 1.45), "segment 5 elites carry +45%% health (%.2f)" % EliteModifiers.segment_hp_factor(5))
	_check(is_equal_approx(EliteModifiers.segment_hp_factor(30), EliteModifiers.ELITE_HP_SEGMENT_CAP), "and the growth is capped (%.2f)" % EliteModifiers.segment_hp_factor(30))
