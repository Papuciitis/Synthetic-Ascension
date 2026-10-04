extends Node
class_name EncounterDirector

## Schedules authored encounter beats on top of the ThreatDirector's continuous
## pressure (roadmap §8, Phase 2.4). Pressure is not drama: every 45-70 s (40-55 s
## on the walk to an unsealed gate), one readable problem - a charger wedge, a
## shield wall, a crossfire - is placed relative to the player's travel and
## announced once, so the player stops autopiloting.
##
## Rules: never during a tutorial stage, never while the exit encounter is live
## (the rite owns that time), never the same beat twice in a row, the kind of
## question rotated (least recently asked kind first), at most `max_concurrent`
## beats alive. A beat's arrival holds ambient spawning for a moment so the
## formation reads; answering it buys a short relax window (Left 4 Dead's
## build-up / peak / relax, 2026-10-04 audit). Members are spawned through the
## spawner's beat API, which protects them from culling and counts them as
## specials, and receive any elite modifiers the beat entry names (§9). The
## ritual beat (§8.1, 2.7) places a RitualInterference world node the same way
## and only while the district collapses. A power threshold the Threat
## Director notes in combat answers with the "rematch" ring of old fodder.

signal beat_started(id: StringName, label: String, members: int)
signal beat_ended(id: StringName)

const BeatsScript = preload("res://core/systems/encounters/EncounterBeats.gd")
const RitualScript = preload("res://core/systems/world/RitualInterference.gd")

@export var enabled := true
## 2026-10-04 audit: at 60-90 s from the disturbance phase a segment got two
## beats (recon, 110-160 s, could never have one), always the same two. The
## Hunter is now recon-eligible and the cadence tighter; research reference:
## Vampire Survivors / HoloCure place a varied spike every 90-150 s, Left 4
## Dead relaxes 30-45 s between peaks.
@export_range(5.0, 300.0, 1.0) var first_beat_delay := 40.0
@export_range(5.0, 600.0, 1.0) var interval_min := 45.0
@export_range(5.0, 600.0, 1.0) var interval_max := 70.0
## Cadence on the walk to an unsealed gate (collapse, exit encounter not yet
## live): the world resists the route instead of only raising multipliers.
@export_range(5.0, 600.0, 1.0) var collapse_interval_min := 40.0
@export_range(5.0, 600.0, 1.0) var collapse_interval_max := 55.0
@export_range(1, 4, 1) var max_concurrent := 1
## Ambient spawning holds this long when a beat arrives, so it reads as a shape.
@export_range(0.0, 10.0, 0.5) var arrival_pause_sec := 3.0
## Answering a beat buys a relax window: ambient interval × lull_interval_mul.
@export_range(0.0, 60.0, 1.0) var lull_seconds := 12.0
@export_range(1.0, 4.0, 0.1) var lull_interval_mul := 2.0
## Seconds after an in-combat power threshold before the rematch ring arrives.
@export_range(0.0, 30.0, 0.5) var rematch_delay_sec := 5.0
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
## kind_tag -> the beat counter when it was last asked; kinds never asked
## are absent (they come first).
var _kind_last_used: Dictionary = {}
var _beat_counter := 0
var _rematch_in := 0.0
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
	if director != null and director.has_signal("power_threshold_noted"):
		director.connect("power_threshold_noted", _on_power_threshold_noted)


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
		_rematch_in = 0.0
		_tick_rite_response(delta)
		return
	if _rematch_in > 0.0:
		_rematch_in -= delta
		if _rematch_in <= 0.0:
			_rematch_in = 0.0
			if not _is_tutorial_stage():
				try_spawn_beat(&"rematch_ring")
	_check_escalation()
	_next_beat_in -= delta
	if _next_beat_in > 0.0:
		return
	if not can_schedule():
		# Re-check soon; conditions (phase, tutorial, rite) change over time.
		_next_beat_in = 5.0
		return
	var result := try_spawn_beat()
	_next_beat_in = _next_interval() if not result.is_empty() else 5.0


func _next_interval() -> float:
	if _is_unsealed() or _phase() == &"collapse":
		return _rng.randf_range(collapse_interval_min, collapse_interval_max)
	return _rng.randf_range(interval_min, interval_max)


## The exit encounter (rite channel) is handled before this is asked: tick()
## routes that time to the rite response. An unsealed gate alone no longer
## blocks beats - the walk to it is where the world should resist (2026-10-04).
func can_schedule() -> bool:
	if _active.size() >= max_concurrent:
		return false
	if _is_tutorial_stage() or _rite_channel_active:
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
	var members: Array = beat["members"]
	var needed := ceili(float(members.size()) * min_placed_fraction)
	var plan := _plan_positions(beat, anchor_dir)
	if _count_valid(plan) < needed and mode != &"around":
		# Placement fallback (2026-10-04 pacing audit, bug d: segment 1's
		# guaranteed wedge placed 0/3 in a narrow street): try the other flank,
		# or the route turned a quarter, before giving the beat up.
		var alt_dir := -anchor_dir if mode == &"flank" else anchor_dir.rotated(PI * 0.5 * (1.0 if _rng.randf() < 0.5 else -1.0))
		var alt_plan := _plan_positions(beat, alt_dir)
		if _count_valid(alt_plan) > _count_valid(plan):
			plan = alt_plan
	var spawned: Array[Node] = []
	var skipped := 0
	for i in range(members.size()):
		var member := members[i] as Dictionary
		var pos: Vector2 = plan[i]
		if pos == Vector2.INF:
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
		_record(&"beat_aborted", beat["id"], spawned.size(), {"skipped": skipped, "wanted": members.size()})
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
	_kind_last_used[BeatsScript.kind_of(beat)] = _beat_counter
	_beat_counter += 1
	# Let the shape read before the horde fills around it (the rite already
	# suspends ambient spawning, so its specialists skip this).
	if not _rite_channel_active and arrival_pause_sec > 0.0 and _spawner.has_method("suspend_spawning"):
		_spawner.call("suspend_spawning", arrival_pause_sec)
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
	var unsealed := _is_unsealed()
	for beat in BeatsScript.eligible(_phase(), _segment()):
		var id: StringName = beat["id"]
		if id == _last_beat_id or _cooldowns.has(id) or _active.has(id):
			continue
		# try_spawn_beat refuses a ritual once the gate is unsealed; do not
		# spend a pick on it.
		if unsealed and BeatsScript.is_ritual(beat):
			continue
		out.append(beat)
	return out


## A phase escalation promised something new, so a freshly unlocked beat goes
## first - but in random order, and among candidates the least recently asked
## KIND wins (ties random). The old pop-in-catalogue-order made every segment
## 2 open with charger_wedge_small then warden_line (2026-10-04 audit).
func _pick_random() -> Dictionary:
	var candidates := _candidates()
	if candidates.is_empty():
		return {}
	var pending: Array[Dictionary] = []
	for beat in candidates:
		if _unlocked_pending.has(beat["id"]):
			pending.append(beat)
	var chosen := _least_recent_kind(pending if not pending.is_empty() else candidates)
	_unlocked_pending.erase(chosen["id"])
	return chosen


func _least_recent_kind(pool: Array[Dictionary]) -> Dictionary:
	var best: Array[Dictionary] = []
	var best_stamp := 2147483647
	for beat in pool:
		var stamp := int(_kind_last_used.get(BeatsScript.kind_of(beat), -1))
		if stamp < best_stamp:
			best_stamp = stamp
			best = [beat]
		elif stamp == best_stamp:
			best.append(beat)
	return best[_rng.randi_range(0, best.size() - 1)]


## Member positions for `beat` anchored along `anchor_dir`: each valid
## position, nudged to nearby valid ground when the authored spot is blocked,
## or Vector2.INF when nothing near it is.
func _plan_positions(beat: Dictionary, anchor_dir: Vector2) -> Array:
	var mode: StringName = beat["mode"]
	var basis_x := anchor_dir
	var basis_y := anchor_dir.orthogonal()
	var player_pos := _player.global_position
	var anchor := player_pos + anchor_dir * float(beat["distance"])
	var out: Array = []
	for member_variant in beat["members"]:
		var offset := (member_variant as Dictionary)["offset"] as Vector2
		var pos := (
			player_pos + offset if mode == &"around"
			else anchor + basis_x * offset.x + basis_y * offset.y
		)
		out.append(pos if _position_valid(pos) else _nudge_to_valid(pos, player_pos))
	return out


const NUDGE_RADII: Array[float] = [48.0, 96.0, 144.0]
## A nudged member never lands closer than this to the player.
const NUDGE_MIN_PLAYER_DISTANCE := 240.0


func _nudge_to_valid(pos: Vector2, player_pos: Vector2) -> Vector2:
	for radius in NUDGE_RADII:
		for k in range(8):
			var candidate := pos + Vector2.RIGHT.rotated(TAU * float(k) / 8.0) * radius
			if candidate.distance_to(player_pos) < NUDGE_MIN_PLAYER_DISTANCE:
				continue
			if _position_valid(candidate):
				return candidate
	return Vector2.INF


func _position_valid(pos: Vector2) -> bool:
	if _spawner == null or not _spawner.has_method("is_beat_position_valid"):
		return true
	return bool(_spawner.call("is_beat_position_valid", pos))


static func _count_valid(plan: Array) -> int:
	var count := 0
	for pos in plan:
		if pos != Vector2.INF:
			count += 1
	return count


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
	for beat in BeatsScript.eligible(phase, _segment()):
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
	_record(&"specialist_response", &"initial", rite_specialist_beats.size())
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
		_record(&"specialist_response", _last_beat_id, 1)
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
		# The peak was answered: relax before the next build-up.
		if not _rite_channel_active and lull_seconds > 0.0 and _spawner != null and is_instance_valid(_spawner) \
		and _spawner.has_method("set_ambient_lull"):
			_spawner.call("set_ambient_lull", lull_seconds, lull_interval_mul)


## In-combat power thresholds only (the Threat Director defers the rest to
## the next disturbance phase): answer with the rematch ring shortly after.
func _on_power_threshold_noted(_id: StringName, _label: String) -> void:
	if not enabled or _rite_channel_active:
		return
	_rematch_in = maxf(0.01, rematch_delay_sec)


func _announce(beat: Dictionary) -> void:
	_counters["announced"] = int(_counters["announced"]) + 1
	if BattleText != null and _player != null and BattleText.has_method("popup"):
		BattleText.popup(_player.global_position, String(beat.get("announce", beat["label"])), Color(1.0, 0.55, 0.35, 1.0), 1.25)


func _record(event: StringName, id: StringName, members: int, extra: Dictionary = {}) -> void:
	if PerformanceFlightRecorder != null and bool(PerformanceFlightRecorder.get("enabled")):
		PerformanceFlightRecorder.record_event(&"encounter", event, {"beat": String(id), "members": members})
	if RunEvents != null and RunEvents.encounter_event.has_connections():
		var data := {"beat": String(id), "members": members, "rite": _rite_channel_active}
		data.merge(extra)
		RunEvents.encounter_event.emit(event, data)


## Observation only (balance recorder): the formations alive right now, by
## beat id with the director's own member counts, and its counters.
func balance_snapshot() -> Dictionary:
	var beats := {}
	for id in _active:
		beats[String(id)] = int((_active[id] as Dictionary).get("alive", 0))
	return {"active_beats": beats, "counters": _counters.duplicate(), "rite_channel_active": _rite_channel_active,
		"rite_response_left": _rite_response_left, "next_beat_in": _next_beat_in}


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


func _segment() -> int:
	return int(Global.attempt_segment) if Global != null else 0


func _is_tutorial_stage() -> bool:
	if _spawner == null or not is_instance_valid(_spawner):
		return false
	if _spawner.has_method("is_tutorial_stage"):
		return bool(_spawner.call("is_tutorial_stage"))
	return false
