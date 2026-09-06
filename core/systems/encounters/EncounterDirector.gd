extends Node
class_name EncounterDirector

## Schedules authored encounter beats on top of the ThreatDirector's continuous
## pressure (roadmap §8, Phase 2.4). Pressure is not drama: every 60-90 s from
## the "disturbance" phase on, one readable problem - a charger wedge, a
## shield wall, a crossfire - is placed relative to the player's travel and
## announced once, so the player stops autopiloting.
##
## Rules: never during a tutorial stage, never once the Exit Rite has unsealed
## (the rite owns that time), never the same beat twice in a row, at most
## `max_concurrent` beats alive. Members are spawned through the spawner's
## beat API, which protects them from culling and counts them as specials, and
## receive any elite modifiers the beat entry names (§9). The ritual beat
## (§8.1, 2.7) places a RitualInterference world node the same way and only
## while the district collapses.

signal beat_started(id: StringName, label: String, members: int)
signal beat_ended(id: StringName)

const BeatsScript = preload("res://core/systems/encounters/EncounterBeats.gd")
const RitualScript = preload("res://core/systems/world/RitualInterference.gd")

@export var enabled := true
@export_range(5.0, 300.0, 1.0) var first_beat_delay := 45.0
@export_range(5.0, 600.0, 1.0) var interval_min := 60.0
@export_range(5.0, 600.0, 1.0) var interval_max := 90.0
@export_range(1, 4, 1) var max_concurrent := 1
## A beat aborts if fewer than this fraction of its members find valid ground.
@export_range(0.1, 1.0, 0.05) var min_placed_fraction := 0.5

## Seams for tests: phase / unsealed / tutorial come from the live autoloads
## unless a provider is set. phase_provider() -> StringName,
## unsealed_provider() -> bool.
var phase_provider: Callable = Callable()
var unsealed_provider: Callable = Callable()

var _spawner: Node = null
var _player: Node2D = null
var _rng := RandomNumberGenerator.new()
var _next_beat_in := 0.0
var _last_beat_id: StringName = &""
var _cooldowns: Dictionary = {}
var _active: Dictionary = {}
var _last_phase: StringName = &""
var _unlocked_pending: Array[StringName] = []
var _specialists_sent := false
var _rite_channel_active := false
var _rite_response_left := 0.0
var _rite_response_cursor := 0
var _counters := {
	"scheduled": 0,
	"aborted": 0,
	"members_spawned": 0,
	"members_skipped": 0,
	"escalations": 0,
	"specialist_responses": 0,
	"announced": 0,
}
## Beats sent the moment the Exit Rite is channelled (roadmap 2.8): the world
## answers departure with a crossfire on the route and a wedge on the flank.
@export var rite_specialist_beats: Array[StringName] = [&"rite_sniper_crossfire", &"charger_wedge"]
## A cleared formation can return during the twenty-second channel, one at a
## time. Active ids cannot duplicate, which caps the authored ranged and
## movement pressure even when a high-damage build clears it instantly.
@export_range(2.0, 20.0, 0.5) var rite_response_interval := 7.0
## Seconds within which a newly unlocked beat fires after a phase escalation.
@export_range(1.0, 60.0, 1.0) var escalation_beat_delay := 10.0


func _ready() -> void:
	add_to_group(&"encounter_director")
	var director := get_node_or_null("/root/ThreatDirector")
	if director != null and director.has_signal("rite_channel_changed"):
		director.connect("rite_channel_changed", _on_rite_channel_changed)


func _exit_tree() -> void:
	if _rite_channel_active and _spawner != null and is_instance_valid(_spawner) and _spawner.has_method("set_rite_pressure_active"):
		_spawner.call("set_rite_pressure_active", false)


func setup(spawner: Node, player: Node2D, seed_value: int = 0) -> void:
	_spawner = spawner
	_player = player
	_last_phase = _phase()
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	_next_beat_in = first_beat_delay


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	for id in _cooldowns.keys():
		_cooldowns[id] = float(_cooldowns[id]) - delta
		if float(_cooldowns[id]) <= 0.0:
			_cooldowns.erase(id)
	if not enabled or _spawner == null or not is_instance_valid(_spawner):
		return
	if _player == null or not is_instance_valid(_player):
		return
	if _rite_channel_active:
		_tick_rite_response(delta)
		return
	_check_escalation()
	_next_beat_in -= delta
	if _next_beat_in > 0.0:
		return
	if not can_schedule():
		# Re-check soon; conditions (phase, tutorial, rite) change over time.
		_next_beat_in = 5.0
		return
	var result := try_spawn_beat()
	_next_beat_in = _rng.randf_range(interval_min, interval_max) if not result.is_empty() else 5.0


func can_schedule() -> bool:
	if _active.size() >= max_concurrent:
		return false
	if _is_tutorial_stage() or _is_unsealed():
		return false
	return not _candidates().is_empty()


## Spawn a specific beat, or a random eligible one. Returns {} when nothing
## was placed. Deterministic under a seeded setup().
func try_spawn_beat(beat_id: StringName = &"") -> Dictionary:
	var beat: Dictionary = BeatsScript.find(beat_id) if beat_id != &"" else _pick_random()
	if beat.is_empty() or _player == null or _spawner == null:
		return {}
	# A ritual bends a local rule: only while the district collapses, and never
	# once the rite owns the run (2.7). Authored spawns bypass cooldowns, not this.
	var ritual := BeatsScript.is_ritual(beat)
	if ritual and (_phase() != &"collapse" or _is_unsealed()):
		return {}
	var travel := _travel_direction()
	var mode: StringName = beat["mode"]
	var anchor_dir := travel
	match mode:
		&"flank":
			anchor_dir = travel.orthogonal() * (1.0 if _rng.randf() < 0.5 else -1.0)
		&"off_route":
			anchor_dir = (-travel).rotated(_rng.randf_range(-0.6, 0.6))
	var basis_x := anchor_dir
	var basis_y := anchor_dir.orthogonal()
	var player_pos := _player.global_position
	var anchor := player_pos + anchor_dir * float(beat["distance"])
	var members: Array = beat["members"]
	var spawned: Array[Node] = []
	var skipped := 0
	for member_variant in members:
		var member := member_variant as Dictionary
		var offset := member["offset"] as Vector2
		var pos := (
			player_pos + offset if mode == &"around"
			else anchor + basis_x * offset.x + basis_y * offset.y
		)
		if _spawner.has_method("is_beat_position_valid") and not bool(_spawner.call("is_beat_position_valid", pos)):
			skipped += 1
			continue
		var node: Node = (
			_place_ritual(pos) if ritual
			else _spawner.call("spawn_beat_member", String(member["scene"]), pos, bool(member.get("elite", false))) as Node
		)
		if node == null:
			skipped += 1
			continue
		spawned.append(node)
	_counters["members_skipped"] = int(_counters["members_skipped"]) + skipped
	if spawned.is_empty() or float(spawned.size()) < float(members.size()) * min_placed_fraction:
		for node in spawned:
			if node.has_method("despawn"):
				node.call("despawn", &"beat_aborted")
			else:
				node.queue_free()
		_counters["aborted"] = int(_counters["aborted"]) + 1
		return {}
	var id: StringName = beat["id"]
	_counters["members_spawned"] = int(_counters["members_spawned"]) + spawned.size()
	_counters["scheduled"] = int(_counters["scheduled"]) + 1
	_last_beat_id = id
	_cooldowns[id] = float(beat["cooldown"])
	var record := {"id": id, "alive": spawned.size(), "label": beat["label"]}
	_active[id] = record
	for node in spawned:
		node.tree_exited.connect(_on_member_gone.bind(id), CONNECT_ONE_SHOT)
		_apply_beat_modifiers(node, beat)
	_announce(beat)
	_record(&"beat_started", id, spawned.size())
	beat_started.emit(id, String(beat["label"]), spawned.size())
	return record


func active_beats() -> Array:
	return _active.keys()


func last_beat_id() -> StringName:
	return _last_beat_id


func get_debug_counters() -> Dictionary:
	var out := _counters.duplicate()
	out["active"] = _active.size()
	out["next_beat_in"] = snappedf(_next_beat_in, 0.1)
	return out


# --- internals --------------------------------------------------------------

func _candidates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for beat in BeatsScript.eligible(_phase()):
		var id: StringName = beat["id"]
		if id == _last_beat_id or _cooldowns.has(id) or _active.has(id):
			continue
		out.append(beat)
	return out


func _pick_random() -> Dictionary:
	var candidates := _candidates()
	if candidates.is_empty():
		return {}
	# A phase escalation promised something new: prefer a freshly unlocked beat.
	while not _unlocked_pending.is_empty():
		var preferred: StringName = _unlocked_pending.pop_front()
		for beat in candidates:
			if beat["id"] == preferred:
				return beat
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


## Phase escalation (roadmap 2.7): say that the district changed, and follow
## it with one of the beats the new phase unlocked within escalation_beat_delay.
func _check_escalation() -> void:
	var phase := _phase()
	if phase == _last_phase:
		return
	var previous := _last_phase
	_last_phase = phase
	if BeatsScript.phase_rank(phase) <= BeatsScript.phase_rank(previous):
		return
	_unlocked_pending.clear()
	for beat in BeatsScript.eligible(phase):
		if BeatsScript.phase_rank(beat["min_phase"]) > BeatsScript.phase_rank(previous):
			_unlocked_pending.append(beat["id"])
	_counters["escalations"] = int(_counters["escalations"]) + 1
	if BattleText != null and _player != null and is_instance_valid(_player) and BattleText.has_method("popup"):
		BattleText.popup(_player.global_position, "THE DISTRICT SHIFTS — %s" % String(phase).to_upper(), Color(0.85, 0.42, 0.95, 1.0), 1.3)
	_record(&"escalation", phase, _unlocked_pending.size())
	if not _unlocked_pending.is_empty():
		_next_beat_in = minf(_next_beat_in, escalation_beat_delay)


func _on_rite_channel_changed(active: bool) -> void:
	if active == _rite_channel_active:
		return
	_rite_channel_active = active
	_rite_response_left = rite_response_interval
	if _spawner != null and is_instance_valid(_spawner) and _spawner.has_method("set_rite_pressure_active"):
		_spawner.call("set_rite_pressure_active", active)
	if not active or _specialists_sent or not enabled:
		return
	_specialists_sent = true
	_counters["specialist_responses"] = int(_counters["specialist_responses"]) + 1
	for id in rite_specialist_beats:
		try_spawn_beat(id)


func _tick_rite_response(delta: float) -> void:
	_rite_response_left -= delta
	if _rite_response_left > 0.0:
		return
	_rite_response_left = rite_response_interval
	request_rite_reinforcement()


func request_rite_reinforcement() -> bool:
	if not _rite_channel_active or not enabled:
		return false
	var spawned := _spawn_next_rite_specialist()
	if spawned:
		_counters["specialist_responses"] = int(_counters["specialist_responses"]) + 1
	return spawned


func _spawn_next_rite_specialist() -> bool:
	if rite_specialist_beats.is_empty():
		return false
	for offset in range(rite_specialist_beats.size()):
		var index := (_rite_response_cursor + offset) % rite_specialist_beats.size()
		var id := rite_specialist_beats[index]
		if _active.has(id):
			continue
		_rite_response_cursor = (index + 1) % rite_specialist_beats.size()
		if not try_spawn_beat(id).is_empty():
			return true
	return false


## The ritual beat's one member is a world node, not an enemy: it takes the
## place the spawner would have given a formation and is handed the spawner
## for its revenants. The first of a run also teaches the rule.
func _place_ritual(pos: Vector2) -> Node:
	var host: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	if host == null:
		return null
	var ritual := RitualScript.new() as Node2D
	ritual.name = "RitualInterference"
	host.add_child(ritual)
	ritual.global_position = pos
	# The director is re-created per segment; the run remembers the lesson.
	ritual.call("setup", _spawner, Global.teach_once(&"ritual_interference"))
	return ritual


## Elite modifiers named on the beat entry (§9; the hunter is fast + vampiric).
## Deferred like the spawner's make_elite so they land on the promoted elite
## rather than on a base enemy the promotion then reshapes. Guarded: the enemy
## API is another branch's until it lands.
func _apply_beat_modifiers(node: Node, beat: Dictionary) -> void:
	var listed: Array = beat.get("modifiers", [])
	if listed.is_empty() or not node.has_method("apply_elite_modifiers"):
		return
	var ids: Array[StringName] = []
	var names := PackedStringArray()
	for modifier in listed:
		ids.append(StringName(modifier))
		names.append(String(modifier))
	node.call_deferred("apply_elite_modifiers", ids)
	if PerformanceFlightRecorder != null and bool(PerformanceFlightRecorder.get("enabled")):
		PerformanceFlightRecorder.record_counter_event(&"encounter", &"beat_modifiers_applied", 1, {
			"beat": String(beat["id"]),
			"modifiers": ",".join(names),
		})


func _travel_direction() -> Vector2:
	var velocity: Variant = _player.get("velocity")
	if velocity is Vector2 and (velocity as Vector2).length_squared() > 1.0:
		return (velocity as Vector2).normalized()
	var facing: Variant = _player.get("facing")
	if facing is Vector2 and (facing as Vector2) != Vector2.ZERO:
		return (facing as Vector2).normalized()
	return Vector2.RIGHT.rotated(_rng.randf() * TAU)


func _on_member_gone(id: StringName) -> void:
	if not _active.has(id):
		return
	var record: Dictionary = _active[id]
	record["alive"] = int(record["alive"]) - 1
	if int(record["alive"]) <= 0:
		_active.erase(id)
		_record(&"beat_ended", id, 0)
		beat_ended.emit(id)


func _announce(beat: Dictionary) -> void:
	_counters["announced"] = int(_counters["announced"]) + 1
	if BattleText != null and _player != null and BattleText.has_method("popup"):
		BattleText.popup(_player.global_position, String(beat.get("announce", beat["label"])), Color(1.0, 0.55, 0.35, 1.0), 1.25)


func _record(event: StringName, id: StringName, members: int) -> void:
	if PerformanceFlightRecorder != null and bool(PerformanceFlightRecorder.get("enabled")):
		PerformanceFlightRecorder.record_event(&"encounter", event, {"beat": String(id), "members": members})


func _phase() -> StringName:
	if phase_provider.is_valid():
		return phase_provider.call()
	var director := get_node_or_null("/root/ThreatDirector")
	return StringName(director.get("segment_phase")) if director != null else &"recon"


func _is_unsealed() -> bool:
	if unsealed_provider.is_valid():
		return bool(unsealed_provider.call())
	var director := get_node_or_null("/root/ThreatDirector")
	return director != null and bool(director.get("gate_unsealed"))


func _is_tutorial_stage() -> bool:
	if _spawner == null or not is_instance_valid(_spawner):
		return false
	if _spawner.has_method("is_tutorial_stage"):
		return bool(_spawner.call("is_tutorial_stage"))
	return false
