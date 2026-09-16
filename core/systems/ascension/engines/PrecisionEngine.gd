extends AscensionEngine
class_name PrecisionEngine
## Precision: Read and Weak Points, piercing, bounces and returns, Deadshot
## and JUDGEMENT.
##
## Read is a per-target counter of weighted Ranged Core hits (Proc Power);
## three expose a Weak Point for 3 s; the next Ranged Core hit consumes it
## for +1D through the outgoing-damage hook. One hit never both exposes and
## consumes. Projectile behaviours (pierce ramp, bounce, seeking, the
## end-of-flight report) live in ProjectileSimulationManager and are set on
## the native hit profile here. Beams and lines are segment queries.

const EFFECTS: Dictionary = {
	"PR01": &"read", "PR02": &"far_shot", "PR03": &"penetrator", "PR04": &"second_read",
	"PR05": &"held_breath", "PR06": &"bank_shot", "PR07": &"return_shot", "PR08": &"overpenetrate",
	"PR09": &"split_line", "PR10": &"dead_center", "PR11": &"crossing_fire", "PR12": &"long_game",
	"PRQ": &"deadshot", "PRQ1": &"twin_shot", "PRQ2": &"quick_draw", "PRQ3": &"wallbang",
	"PRQ4": &"fan", "PRQ5": &"recalculate", "PRQ6": &"last_round", "PRF1": &"deadeye",
	"PRF2": &"smart_rounds", "PRK1": &"one_bullet", "PRK2": &"cross_eyed", "PRA": &"nothing_wasted",
	"PRC": &"firing_squad", "PRE1": &"kill_line", "PRE2": &"smart_grid", "PRS1": &"shot_speed",
	"PRS2": &"q_damage", "PRV": &"judgement", "PRV1": &"auto_plot", "PRV2": &"back_and_forth",
	"PRV3": &"one_line",
}
const WEAK_POINT_SECONDS := 3.0
const READ_TO_EXPOSE := 3.0
const AIM_SECONDS := 0.8
const DEADSHOT_SLOW := 0.35
const DEADSHOT_AIM_SECONDS := 0.6
const JUDGEMENT_SLOW := 0.2
const JUDGEMENT_SECONDS := 1.5

var _clock: float = 0.0
var _read: Dictionary = {}              # handle -> weighted Read
var _far_shot_done: Dictionary = {}
var _exposed_at_hit: Dictionary = {}    # handle -> exposed when the damage hook ran
var _consumed_at: Dictionary = {}       # handle -> clock of the last consumption
var _exposed_until: Dictionary = {}     # handle -> clock when the Weak Point closes
var _second_read: Dictionary = {}       # projectile id -> handle that consumed
var _charged_pids: Dictionary = {}
var _trajectories: Dictionary = {}      # handle -> Array of {pid, dir, t}
var _crossing_at: Dictionary = {}
var _since_native: float = 99.0
var _aim_spent_volley: int = -1
var _witness_aim_cast: int = -1
var _volley: int = 0
var _spare_rounds: int = 0
var _spare_origin: Vector2 = Vector2.ZERO
var _cross_side: float = 1.0
var _miss_watch: Dictionary = {}        # {core, origin, target, deadline}
var _miss_used_input: int = -1
var _edge_returned: Dictionary = {}     # projectile id -> true
var _cast_crossed: Dictionary = {}      # cast -> {handle: true}
var _cast_consumed: Dictionary = {}     # cast -> int
var _squad_recovery: float = 0.0
var _sweep: Dictionary = {}             # One Bullet's Firing Squad sweep
# Deadshot
var _aiming: bool = false
var _aim_real: float = 0.0
var _deadshot_cast: int = 0
var _deadshot_kills: int = 0
var _delayed_lines: Array = []          # {delay, from, to, damage, tags, radius}
var _kill_line_misses: int = 0
var _kill_line_done: Dictionary = {}
var _guns: Array = []                   # Smart Grid {at, left, tick, shots}
# JUDGEMENT
var judgement_left: float = 0.0
var _judgement_lines: Array = []        # [from, to]
var _judgement_tell: float = -1.0
var _sweep_left: float = 0.0
var _sweep_tick: float = 0.0
var _sweep_hits: Dictionary = {}
var _sweep_reverse: float = 0.0
var _sweep_damage: float = 0.0
var _judgement_cast: int = 0
var _segment_scratch: Array[int] = []
var _segment_ts := PackedFloat32Array()

var counters: Dictionary = {"exposed": 0, "consumed": 0, "far_shots": 0, "second_reads": 0, "aims": 0, "returns": 0, "bursts": 0, "splits": 0, "dead_centers": 0, "crossings": 0, "spares": 0, "edge_returns": 0, "misses_returned": 0, "deadshots": 0, "lines": 0, "recalculates": 0, "executions": 0, "kill_lines": 0, "squads": 0, "squad_lines": 0, "grid_lines": 0, "judgements": 0, "judgement_lines": 0, "sweep_ticks": 0}


func discipline() -> String:
	return "PR"


func D() -> float:
	return runner.native_damage_for("ranged")


# ---------------------------------------------------------------- Weak Points

func is_exposed(handle: int) -> bool:
	return runner.has_status(handle, "weak_point")


func expose(handle: int) -> void:
	if not runner.enemy_alive(handle):
		return
	runner.status_of(handle)["weak_point"] = _clock + WEAK_POINT_SECONDS
	_exposed_until[handle] = _clock + WEAK_POINT_SECONDS
	counters["exposed"] = int(counters["exposed"]) + 1


func _consume(handle: int, hit: Dictionary) -> void:
	runner.clear_status(handle, "weak_point")
	_exposed_until.erase(handle)
	_consumed_at[handle] = _clock
	counters["consumed"] = int(counters["consumed"]) + 1
	runner.add_action_charge(2.0)
	var cast := AscensionTags.value_of(hit["tags"], "cast")
	if not cast.is_empty():
		_cast_consumed[cast] = int(_cast_consumed.get(cast, 0)) + 1
		if has("PRC") and int(_cast_consumed[cast]) >= 6:
			_firing_squad(cast)
	if has("PR04") and int(hit["projectile_id"]) != 0:
		_second_read[int(hit["projectile_id"])] = handle


func _is_ranged_core(hit: Dictionary) -> bool:
	return hit["core"] == "ranged" and AscensionTags.has_flag(hit["tags"], "core_strike")


# ---------------------------------------------------------------- tick

func tick(delta: float) -> void:
	_clock += delta
	_since_native += delta
	if _squad_recovery > 0.0:
		_squad_recovery = maxf(0.0, _squad_recovery - delta)
	for key in _read.keys():
		if not runner.enemy_alive(int(key)):
			_read.erase(key)
	for key in _exposed_until.keys():
		if _clock >= float(_exposed_until[key]):
			_exposed_until.erase(key)
			runner.clear_status(int(key), "weak_point")
	_tick_delayed_lines(delta)
	_tick_miss_watch()
	_tick_guns(delta)
	_tick_sweep(delta)
	_tick_judgement(delta)
	_tick_squad_sweep(delta)
	if _aiming:
		_aim_real += delta / maxf(Engine.time_scale, 0.001)
		if _aim_real >= DEADSHOT_AIM_SECONDS:
			_fire_deadshot()
	# Weak Points expire on their own clock.
	for key in _exposed_at_hit.keys():
		if not runner.enemy_alive(int(key)):
			_exposed_at_hit.erase(key)


# ---------------------------------------------------------------- native profile

func decorate_native_profile(profile: HitProfileAdapter) -> void:
	var tags: PackedStringArray = AscensionTags.with_flag(profile.get_meta("asc_tags", PackedStringArray()), "core_strike")
	profile.set_meta("asc_tags", tags)
	var pp := 1.0
	if has("PR03"):
		profile.pierce += 2
		profile.pierce_ramp = 0.2 * D()
		profile.pierce_ramp_cap = 1.0 * D()
	if has("PRS1"):
		var r := float(rank("PRS1"))
		var gain := 1.0 + 0.8 * r / (r + 80.0)
		profile.speed *= gain
		profile.max_range *= gain
	if has("PRK1"):
		profile.damage *= 3.0
		pp = 1.25
	if has("PRK2"):
		profile.direction_offset_degrees = 20.0 * _cross_side
		_cross_side = -_cross_side
		profile.bounces = 3
		profile.bounce_scale = 1.5
	elif has("PR06"):
		profile.bounces = 1
		profile.bounce_scale = 0.75
		profile.bounce_proc_power = 0.7
	if has("PRF2"):
		profile.damage *= 0.8
		var target := _nearest_exposed(runner.player_position(), 3.0 * AscensionRunner.L)
		if target != 0:
			profile.seek_handle = target
			profile.seek_turn_degrees = 30.0
	if has("PR05") and _since_native >= AIM_SECONDS and _aim_spent_volley != _volley + 1:
		profile.damage += D()
		pp = maxf(pp, 1.25)
		_aim_spent_volley = _volley + 1
		counters["aims"] = int(counters["aims"]) + 1
	if has("PRF1") and _aim_crosses_exposed(runner.player_position(), runner.aim_target()):
		profile.damage += D()
		profile.pierce += 1
	if pp != 1.0:
		for i in range(tags.size()):
			if tags[i].begins_with("pp:"):
				tags[i] = "pp:%.3f" % pp
		profile.set_meta("asc_tags", tags)


func _nearest_exposed(origin: Vector2, radius: float) -> int:
	var best := 0
	var best_d := INF
	for handle in runner.enemies_in_radius(origin, radius):
		if not is_exposed(handle):
			continue
		var d := origin.distance_squared_to(runner.enemy_position(handle))
		if d < best_d:
			best_d = d
			best = handle
	return best


## The aim line passes through the central half of an exposed target.
func _aim_crosses_exposed(origin: Vector2, aim: Vector2) -> bool:
	var dir := (aim - origin).normalized()
	if dir == Vector2.ZERO:
		return false
	var count := EnemyCombat.enemies_on_segment(origin, origin + dir * 3.0 * AscensionRunner.L, 1.0, 0, _segment_scratch, _segment_ts)
	for i in range(count):
		var handle: int = _segment_scratch[i]
		if is_exposed(handle):
			var centre := runner.enemy_position(handle)
			var t := clampf((centre - origin).dot(dir), 0.0, INF)
			if centre.distance_to(origin + dir * t) <= 5.0:
				return true
	return false


func haste_multiplier(core: String) -> float:
	return 0.5 if (core == "ranged" and has("PRK1")) else 1.0


func q_damage_multiplier() -> float:
	return 1.0 + 0.01 * sqrt(float(rank("PRS2"))) if has("PRS2") else 1.0


# ---------------------------------------------------------------- native fire

func on_native_fire(style: String, origin: Vector2, target: Vector2, _power: float, _haste: float) -> void:
	_volley += 1
	var aim_ready := has("PR05") and _since_native >= AIM_SECONDS
	var refunded := false
	if style == "ranged":
		if has("PR10") and _aim_crosses_exposed(origin, target):
			runner.q_cooldown_left = maxf(0.0, runner.q_cooldown_left - 0.25)
			counters["dead_centers"] = int(counters["dead_centers"]) + 1
			refunded = true
		if has("PR12") and _spare_rounds > 0:
			var dir := (target - _spare_origin).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			for i in range(_spare_rounds):
				runner.spawn_bullet(_spare_origin, dir.rotated(deg_to_rad(-6.0 + 6.0 * float(i))), 0.8 * D(), AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "PR12", "spare", 1, 0.5, PackedStringArray(["core_strike", "spare"])))
			counters["spares"] = int(counters["spares"]) + _spare_rounds
			_spare_rounds = 0
	_since_native = (AIM_SECONDS * 0.5) if (refunded and aim_ready) else 0.0
	if has("PRA") and _miss_used_input != _volley:
		_miss_watch = {"core": style, "origin": origin, "target": target, "deadline": _clock + 0.35, "input": _volley}


func on_witness_strike(core: String, _origin: Vector2, _target: Vector2) -> void:
	if core == "ranged" and has("PR05") and _since_native >= AIM_SECONDS:
		_since_native = 0.0
		_witness_aim_cast = runner.witness_strikes
		counters["aims"] = int(counters["aims"]) + 1


func on_player_damage_resolved(_source: Node, _raw: float, _applied: float, _kind: StringName) -> void:
	_since_native = 0.0


# ---------------------------------------------------------------- hits

func modify_outgoing_damage(preview: Dictionary, raw: float) -> float:
	var handle := int(preview["handle"])
	var damage := raw
	var tags: PackedStringArray = preview["tags"]
	if preview["core"] == "ranged" and bool(preview["core_strike"]):
		if is_exposed(handle) and (has("PR01") or has("PR02")):
			damage += D()
			_exposed_at_hit[handle] = true
		if _witness_aim_cast >= 0 and AscensionTags.has_flag(tags, "witness") and AscensionTags.value_of(tags, "cast") == "witness:%d" % _witness_aim_cast:
			damage += D()
			_witness_aim_cast = -1
	if AscensionTags.value_of(tags, "root") == "PRQ" and has("PRQ6") and (runner.is_elite(handle) or runner.is_boss(handle)):
		var max_hp := runner.enemy_max_hp(handle)
		if max_hp > 0.0 and runner.enemy_hp(handle) / max_hp < 0.25:
			damage += D()
	return damage


func on_hit(hit: Dictionary) -> void:
	var handle := int(hit["handle"])
	var pid := int(hit["projectile_id"])
	if hit["core"] == "ranged" and pid != 0:
		_note_trajectory(hit)
		if has("PR03") and int(hit["crossed"]) + 1 >= 3 and not _charged_pids.has(pid):
			_charged_pids[pid] = true
			runner.add_action_charge(1.0)
		var cast := AscensionTags.value_of(hit["tags"], "cast")
		if has("PRC") and not cast.is_empty():
			var seen: Dictionary = _cast_crossed.get(cast, {})
			seen[handle] = true
			_cast_crossed[cast] = seen
			if seen.size() >= 12:
				_firing_squad(cast)
		if has("PR04") and _second_read.has(pid) and int(_second_read[pid]) != handle:
			_second_read.erase(pid)
			expose(handle)
			counters["second_reads"] = int(counters["second_reads"]) + 1
	if _is_ranged_core(hit):
		if _exposed_at_hit.has(handle):
			_exposed_at_hit.erase(handle)
			_consume(handle, hit)
		else:
			var exposed_now := false
			if has("PR02") and not _far_shot_done.has(handle) and runner.player_position().distance_to(hit["position"]) > 2.0 * AscensionRunner.R:
				_far_shot_done[handle] = true
				expose(handle)
				counters["far_shots"] = int(counters["far_shots"]) + 1
				exposed_now = true
			if has("PR01") and not exposed_now and not is_exposed(handle):
				_read[handle] = float(_read.get(handle, 0.0)) + float(hit["pp"])
				if float(_read[handle]) >= READ_TO_EXPOSE:
					_read[handle] = float(_read[handle]) - READ_TO_EXPOSE
					expose(handle)
	if hit["root"] == "PRQ" and has("PRQ6") and bool(hit["is_normal"]) and not bool(hit["lethal"]) and float(hit["fraction_after"]) < 0.25:
		runner.damage_enemy(handle, float(hit["after"]) + 1.0, AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "PRQ6", "execute", int(hit["gen"]) + 1, 0.0, PackedStringArray(["execute"])))
		counters["executions"] = int(counters["executions"]) + 1
	if hit["family"] == AscensionTags.FAMILY_NATIVE and not _miss_watch.is_empty() and int(_miss_watch["input"]) == _volley:
		_miss_watch = {}


func _note_trajectory(hit: Dictionary) -> void:
	var handle := int(hit["handle"])
	var dir: Vector2 = hit["direction"]
	var pid := int(hit["projectile_id"])
	var list: Array = _trajectories.get(handle, [])
	var crossed := false
	for entry in list:
		if _clock - float(entry["t"]) <= 0.5 and int(entry["pid"]) != pid and absf((entry["dir"] as Vector2).angle_to(dir)) > deg_to_rad(10.0):
			crossed = true
	list.append({"pid": pid, "dir": dir, "t": _clock})
	while list.size() > 6:
		list.pop_front()
	_trajectories[handle] = list
	if has("PR11") and crossed and _clock - float(_crossing_at.get(handle, -INF)) >= 1.0 and runner.enemy_alive(handle):
		_crossing_at[handle] = _clock
		counters["crossings"] = int(counters["crossings"]) + 1
		runner.damage_enemy(handle, D(), AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "PR11", "crossing", int(hit["gen"]) + 1, 0.4))


func on_kill(hit: Dictionary, _context: RefCounted) -> void:
	var handle := int(hit["handle"])
	if hit["core"] == "ranged" and int(hit["projectile_id"]) != 0:
		var exposed_victim := is_exposed(handle) or _clock - float(_consumed_at.get(handle, -INF)) < 0.05
		if has("PR09") and int(hit["crossed"]) >= 1 and exposed_victim:
			_split_line(hit)
		if has("PR12") and hit["root"] == "PR07" and hit["path"] == "return" and _spare_rounds < 3:
			_spare_rounds += 1
			_spare_origin = hit["position"]
	_exposed_at_hit.erase(handle)
	_consumed_at.erase(handle)
	_read.erase(handle)
	_trajectories.erase(handle)
	if hit["root"] == "PRQ" or hit["root"] == "PRE1":
		_deadshot_kill(hit)


func _split_line(hit: Dictionary) -> void:
	counters["splits"] = int(counters["splits"]) + 1
	var dir: Vector2 = hit["direction"]
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	for angle in [-20.0, 20.0]:
		runner.spawn_bullet(hit["position"], dir.rotated(deg_to_rad(angle)), 0.7 * D(), AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "PR09", "split", int(hit["gen"]) + 1, 0.4, PackedStringArray(["core_strike", "split"])), {"pierce": 1})


# ---------------------------------------------------------------- projectile ends

func on_projectile_ended(info: Dictionary) -> void:
	var tags: PackedStringArray = info["tags"]
	if AscensionTags.value_of(tags, "core") != "ranged" or not AscensionTags.has_flag(tags, "core_strike"):
		return
	var reason: StringName = info["reason"]
	var crossed := int(info["crossed"])
	var is_return := AscensionTags.has_flag(tags, "return") or AscensionTags.has_flag(tags, "edge_return")
	if (reason == &"range" or reason == &"pierce") and not is_return:
		if has("PR07"):
			_return_shot(info)
			return
		elif has("PR08") and int(info["pierce_left"]) > 0:
			counters["bursts"] = int(counters["bursts"]) + 1
			runner.spawn_impact(info["position"], D(), AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "PR08", "burst", 1, 0.5), AscensionRunner.R * 0.5)
	if crossed == 0 and not is_return and (reason == &"range" or reason == &"world" or reason == &"life"):
		var pid := int(info["id"])
		if has("PRA") and not _miss_watch.is_empty() and int(_miss_watch["input"]) == _volley and AscensionTags.value_of(tags, "family") == AscensionTags.FAMILY_NATIVE:
			_miss_watch = {}
			_miss_used_input = _volley
			counters["misses_returned"] = int(counters["misses_returned"]) + 1
			_retrace(info, "PRA", 0.5, 1.0)
		elif has("PRF2") and not _edge_returned.has(pid):
			_edge_returned[pid] = true
			counters["edge_returns"] = int(counters["edge_returns"]) + 1
			var dir: Vector2 = info["direction"]
			var edge := runner.camera_edge_point(dir.angle())
			runner.spawn_bullet(edge, -dir, float(info["damage"]), _retag(tags, "PRF2", "edge_return", 0.5), {"pierce": 2, "max_range": edge.distance_to(runner.player_position()) + AscensionRunner.L})


func _retag(tags: PackedStringArray, root: String, path: String, pp: float) -> PackedStringArray:
	var parsed := AscensionTags.parse(tags)
	var flags: PackedStringArray = parsed["flags"]
	if not flags.has(path):
		flags.append(path)
	var out := AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, root, path, int(parsed["gen"]) + 1, pp, flags)
	var cast := AscensionTags.value_of(tags, "cast")
	if not cast.is_empty():
		out.append("cast:" + cast)
	return out


## Return Shot: back along the last leg for 60%, each victim once.
func _return_shot(info: Dictionary) -> void:
	counters["returns"] = int(counters["returns"]) + 1
	var path: PackedVector2Array = info["path"]
	var position: Vector2 = info["position"]
	var leg_start: Vector2 = path[path.size() - 1] if path.size() > 0 else runner.player_position()
	var dir := (leg_start - position).normalized()
	if dir == Vector2.ZERO:
		dir = -(info["direction"] as Vector2)
	var travelled := position.distance_to(leg_start)
	for i in range(1, path.size()):
		travelled += path[i].distance_to(path[i - 1])
	var damage := float(info["damage"]) * (0.9 if has("PRK2") else 0.6)
	var overrides := {"pierce": int(info["crossed"]) + 2, "max_range": maxf(travelled, AscensionRunner.R)}
	if has("PR08"):
		var unused := mini(int(info["pierce_left"]), 5)
		damage += 0.2 * D() * float(unused)
		overrides["collision_radius"] = 6.0 + AscensionRunner.R * 0.25 * float(mini(unused, 4))
	runner.spawn_bullet(position, dir, damage, _retag(info["tags"], "PR07", "return", 0.5), overrides)


func _retrace(info: Dictionary, root: String, pp: float, scale: float) -> void:
	var position: Vector2 = info["position"]
	var origin: Vector2 = info["origin"]
	var dir := (origin - position).normalized()
	if dir == Vector2.ZERO:
		dir = -(info["direction"] as Vector2)
	runner.spawn_bullet(position, dir, float(info["damage"]) * scale, _retag(info["tags"], root, "retrace", pp), {"pierce": 2, "max_range": maxf(position.distance_to(origin), AscensionRunner.R)})


func _tick_miss_watch() -> void:
	if _miss_watch.is_empty() or _clock < float(_miss_watch["deadline"]):
		return
	var watch := _miss_watch
	_miss_watch = {}
	if watch["core"] == "ranged":
		return  # the projectile report decides
	_miss_used_input = int(watch["input"])
	counters["misses_returned"] = int(counters["misses_returned"]) + 1
	var origin: Vector2 = watch["origin"]
	var target: Vector2 = watch["target"]
	if watch["core"] == "melee":
		var back := (origin - target).normalized()
		runner.spawn_slash(target, back if back != Vector2.ZERO else Vector2.LEFT, 0.8 * D(), AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "PRA", "wave", 1, 0.5), 120.0, AscensionRunner.R)
	else:
		runner.spawn_impact(target, runner.native_damage_for("magic"), AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "PRA", "impact", 1, 0.5), AscensionRunner.R * 0.5)


# ---------------------------------------------------------------- lines

## Every enemy on the segment takes `damage` once.
func _line(from: Vector2, to: Vector2, damage: float, tags: PackedStringArray, radius: float, once: Dictionary = {}) -> int:
	var count := EnemyCombat.enemies_on_segment(from, to, radius, 0, _segment_scratch, _segment_ts)
	var hits := 0
	var victims: Array[int] = []
	for i in range(count):
		victims.append(_segment_scratch[i])
	for handle in victims:
		if once.has(handle):
			continue
		once[handle] = true
		runner.damage_enemy(handle, damage, tags)
		hits += 1
	counters["lines"] = int(counters["lines"]) + 1
	runner.note_line_fx(from, to, radius)
	return hits


func _far_edge(from: Vector2, dir: Vector2) -> Vector2:
	var rect := runner.camera_rect()
	var reach := rect.size.length()
	return from + dir * reach


func _tick_delayed_lines(delta: float) -> void:
	if _delayed_lines.is_empty():
		return
	var due: Array = []
	for entry in _delayed_lines:
		entry["delay"] = float(entry["delay"]) - delta
		if float(entry["delay"]) <= 0.0:
			due.append(entry)
	for entry in due:
		_delayed_lines.erase(entry)
		_line(entry["from"], entry["to"], float(entry["damage"]), entry["tags"], float(entry["radius"]))


# ---------------------------------------------------------------- Deadshot (Q)

func q_is_hold(id: String) -> bool:
	return id == "PRQ" and not has("PRQ2") and not runner.automatic_cast and not runner.reaction_cast


func q_active(id: String) -> bool:
	return id == "PRQ" and _aiming


func activate_q(id: String) -> Dictionary:
	if id != "PRQ":
		return {"ok": false, "message": "NOT PRECISION", "cooldown": 0.0}
	_deadshot_cast += 1
	_deadshot_kills = 0
	_kill_line_misses = 0
	_kill_line_done.clear()
	counters["deadshots"] = int(counters["deadshots"]) + 1
	if has("PRQ2") or runner.automatic_cast or runner.reaction_cast:
		_fire_deadshot()
		return {"ok": true, "message": "DEADSHOT", "cooldown": 5.0 if has("PRQ2") else 8.0}
	_aiming = true
	_aim_real = 0.0
	runner.set_time_slow(DEADSHOT_SLOW, DEADSHOT_AIM_SECONDS)
	return {"ok": true, "message": "AIMING", "cooldown": 0.0}


func hold_q(_id: String, _delta: float) -> void:
	pass


func release_q(id: String) -> Dictionary:
	if id != "PRQ":
		return {"ok": false, "message": "", "cooldown": 0.0}
	if _aiming:
		_fire_deadshot()
	return {"ok": true, "message": "DEADSHOT", "cooldown": 8.0}


func _deadshot_line_from(origin: Vector2, aim: Vector2) -> Array:
	var dir := (aim - origin).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	if runner.automatic_cast or runner.reaction_cast:
		dir = _densest_direction_through(aim)
	return [origin, dir]


## The direction through `point` (from the player) crossing the most enemies.
func _densest_direction_through(point: Vector2) -> Vector2:
	var origin := runner.player_position()
	var base := (point - origin).normalized()
	if base == Vector2.ZERO:
		base = Vector2.RIGHT
	var best := base
	var best_count := -1
	for i in range(8):
		var dir := base.rotated(deg_to_rad(-35.0 + 10.0 * float(i)))
		var count := EnemyCombat.enemies_on_segment(origin, _far_edge(origin, dir), AscensionRunner.R / 6.0, 0, _segment_scratch, _segment_ts)
		if count > best_count:
			best_count = count
			best = dir
	return best


func _fire_deadshot() -> void:
	_aiming = false
	runner.end_time_slow()
	var origin := runner.player_position()
	var aim := runner.auto_aim_for("PRQ") if runner.automatic_cast else runner.aim_target()
	var line := _deadshot_line_from(origin, aim)
	var dir: Vector2 = line[1]
	var damage := (3.0 if has("PRQ2") else 4.0) * D() * runner.q_scale()
	var radius := AscensionRunner.R / 6.0
	if has("PRQ3"):
		radius *= 0.5
	var pp := 1.0 * runner.q_proc_scale()
	if has("PRQ1"):
		damage *= 0.65 if has("PRQ2") else 0.625
	var perp := Vector2(-dir.y, dir.x)
	var origins: Array = [origin]
	if has("PRQ1"):
		if has("PRQ2"):
			_delayed_lines.append({"delay": 0.15, "from": origin + perp * AscensionRunner.R, "to": _far_edge(origin + perp * AscensionRunner.R, dir), "damage": damage, "tags": _deadshot_tags(pp, 1), "radius": radius, "twin": true})
		else:
			origins.append(origin + perp * AscensionRunner.R)
	for start in origins:
		_beam(start, dir, damage, radius, pp)


func _deadshot_tags(pp: float, gen: int = 1) -> PackedStringArray:
	var tags := AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "PRQ", "beam", gen, pp)
	tags.append("cast:deadshot:%d" % _deadshot_cast)
	return tags


func _beam(start: Vector2, dir: Vector2, damage: float, radius: float, pp: float) -> void:
	var to := _far_edge(start, dir)
	if has("PRQ3"):
		damage += 0.5 * D() * float(mini(4, _obstructions(start, to)))
	if has("PRQ4"):
		var perp := Vector2(-dir.y, dir.x)
		for i in range(-2, 3):
			var offset := perp * (AscensionRunner.R / 3.0) * float(i)
			_line(start + offset, to + offset, damage * 0.35, _deadshot_tags(0.3 * runner.q_proc_scale()), radius)
	else:
		_line(start, to, damage, _deadshot_tags(pp), radius)
	if has("PRE2"):
		_smart_grid()


func _obstructions(from: Vector2, to: Vector2) -> int:
	var count := 0
	var at := from
	var dir := (to - from).normalized()
	var remaining := from.distance_to(to)
	var guard := 0
	while remaining > 0.0 and guard < 16:
		guard += 1
		var t := runner.terrain_hit_t(at, at + dir * remaining, 2.0)
		if t < 0.0:
			break
		count += 1
		var advance := t * remaining + 24.0
		at += dir * advance
		remaining -= advance
	return count


func _deadshot_kill(hit: Dictionary) -> void:
	var handle := int(hit["handle"])
	_deadshot_kills += 1
	if has("PRQ5") and hit["root"] == "PRQ" and _deadshot_kills <= 3 and not AscensionTags.has_flag(hit["tags"], "recalculated"):
		counters["recalculates"] = int(counters["recalculates"]) + 1
		var aim := runner.aim_target()
		var dir := (aim - (hit["position"] as Vector2)).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		var tags := AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "PRQ5", "beam", int(hit["gen"]) + 1, 0.5, PackedStringArray(["recalculated"]))
		tags.append("cast:deadshot:%d" % _deadshot_cast)
		_line(hit["position"], _far_edge(hit["position"], dir), 1.5 * D(), tags, AscensionRunner.R / 6.0)
	if has("PRE1") and not _kill_line_done.has(handle):
		_kill_line_done[handle] = true
		_kill_line_misses = 0
		counters["kill_lines"] = int(counters["kill_lines"]) + 1
		var aim := runner.aim_target()
		var dir := (aim - (hit["position"] as Vector2)).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		var tags := AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "PRE1", "beam", int(hit["gen"]) + 1, 0.5)
		tags.append("cast:deadshot:%d" % _deadshot_cast)
		var before := int(counters["kill_lines"])
		var hits := _line(hit["position"], _far_edge(hit["position"], dir), 2.0 * D(), tags, AscensionRunner.R / 6.0)
		if hits == 0 or int(counters["kill_lines"]) == before:
			_kill_line_misses += 1


func _smart_grid() -> void:
	_guns.clear()
	for i in range(4):
		var angle := TAU * float(i) / 4.0 + PI / 4.0
		_guns.append({"at": runner.camera_edge_point(angle), "left": 2.0, "tick": 0.5, "shots": 4})


func _tick_guns(delta: float) -> void:
	if _guns.is_empty():
		return
	for i in range(_guns.size() - 1, -1, -1):
		var gun: Dictionary = _guns[i]
		gun["left"] = float(gun["left"]) - delta
		gun["tick"] = float(gun["tick"]) + delta
		if float(gun["tick"]) >= 0.5 and int(gun["shots"]) > 0:
			gun["tick"] = 0.0
			gun["shots"] = int(gun["shots"]) - 1
			var at: Vector2 = gun["at"]
			var through := runner.aim_target()
			var exposed := _nearest_exposed(through, 2.0 * AscensionRunner.L)
			if exposed != 0:
				through = runner.enemy_position(exposed)
			var dir := (through - at).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			var tags := AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "PRE2", "beam", 2, 0.5)
			tags.append("cast:deadshot:%d" % _deadshot_cast)
			_line(at, _far_edge(at, dir), 1.5 * D(), tags, AscensionRunner.R / 6.0)
			counters["grid_lines"] = int(counters["grid_lines"]) + 1
		if float(gun["left"]) <= 0.0 or int(gun["shots"]) <= 0:
			_guns.remove_at(i)


func auto_target(_id: String) -> Vector2:
	return runner.aim_target()


# ---------------------------------------------------------------- Firing Squad

func _firing_squad(cast: String) -> void:
	if _squad_recovery > 0.0:
		return
	_squad_recovery = 8.0
	_cast_crossed.erase(cast)
	_cast_consumed.erase(cast)
	counters["squads"] = int(counters["squads"]) + 1
	runner.note_catastrophe("PRC")
	if has("PRK1"):
		_sweep = {"left": 0.8, "tick": 0.0, "hits": {}}
		return
	var rect := runner.camera_rect()
	var candidates := runner.enemies_in_radius(rect.get_center(), rect.size.length() * 0.5)
	var scored: Array = []
	for handle in candidates:
		scored.append([runner.enemies_in_radius(runner.enemy_position(handle), AscensionRunner.R).size(), handle])
	scored.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	var used: Dictionary = {}
	var guns := 0
	for entry in scored:
		if guns >= 6:
			break
		var handle := int(entry[1])
		var at := runner.enemy_position(handle)
		var angle := (at - rect.get_center()).angle() + PI + deg_to_rad(20.0 * float(guns) - 50.0)
		var from := runner.camera_edge_point(angle)
		var dir := (at - from).normalized()
		var tags := AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "PRC", "beam", 2, 0.35)
		tags.append("cast:squad:%d" % int(counters["squads"]))
		_line(from, _far_edge(from, dir), 2.0 * D(), tags, AscensionRunner.R / 6.0, used)
		counters["squad_lines"] = int(counters["squad_lines"]) + 1
		guns += 1
	if BattleText != null:
		BattleText.popup(runner.player_position(), "FIRING SQUAD", Color(1.0, 0.9, 0.6, 1.0), 1.6)


func _tick_squad_sweep(delta: float) -> void:
	if _sweep.is_empty():
		return
	_sweep["left"] = float(_sweep["left"]) - delta
	_sweep["tick"] = float(_sweep["tick"]) + delta
	if float(_sweep["tick"]) >= 0.2:
		_sweep["tick"] = 0.0
		var origin := runner.player_position()
		var dir := (runner.aim_target() - origin).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		var tags := AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "PRC", "sweep", 2, 0.35)
		tags.append("cast:squad:%d" % int(counters["squads"]))
		_line(origin, _far_edge(origin, dir), 8.0 * D(), tags, AscensionRunner.R / 6.0, _sweep["hits"])
		counters["squad_lines"] = int(counters["squad_lines"]) + 1
	if float(_sweep["left"]) <= 0.0:
		_sweep = {}


# ---------------------------------------------------------------- JUDGEMENT (V)

func activate_v(id: String) -> Dictionary:
	if id != "PRV":
		return {"ok": false, "message": "NOT PRECISION", "cooldown": 0.0}
	_judgement_cast += 1
	_judgement_lines.clear()
	counters["judgements"] = int(counters["judgements"]) + 1
	if has("PRV3"):
		_sweep_left = JUDGEMENT_SECONDS
		_sweep_tick = 0.0
		_sweep_hits.clear()
		_sweep_damage = 3.0 * D()
		_sweep_reverse = 0.0
		return {"ok": true, "message": "ONE LINE", "cooldown": 0.0}
	if has("PRV1"):
		_auto_plot()
		_judgement_tell = 0.4
		return {"ok": true, "message": "JUDGEMENT", "cooldown": 0.0}
	judgement_left = JUDGEMENT_SECONDS
	runner.set_time_slow(JUDGEMENT_SLOW, JUDGEMENT_SECONDS)
	return {"ok": true, "message": "PLOTTING", "cooldown": 0.0}


## A wide line across the screen through the player along `direction`.
func place_line(direction: Vector2) -> void:
	if _judgement_lines.size() >= 3:
		return
	var origin := runner.player_position()
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	_judgement_lines.append([_far_edge(origin, -dir), _far_edge(origin, dir)])


func _auto_plot() -> void:
	var rect := runner.camera_rect()
	var origin := runner.player_position()
	var scored: Array = []
	for handle in runner.enemies_in_radius(rect.get_center(), rect.size.length() * 0.5):
		scored.append([runner.enemies_in_radius(runner.enemy_position(handle), AscensionRunner.R).size(), handle])
	scored.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	var chosen: Array[Vector2] = []
	for entry in scored:
		if chosen.size() >= 3:
			break
		var at := runner.enemy_position(int(entry[1]))
		var separate := true
		for other in chosen:
			if other.distance_to(at) < 2.0 * AscensionRunner.R:
				separate = false
		if separate:
			chosen.append(at)
	for at in chosen:
		place_line(at - origin)
	if _judgement_lines.is_empty():
		place_line(runner.aim_target() - origin)


func _tick_judgement(delta: float) -> void:
	if judgement_left > 0.0:
		judgement_left = maxf(0.0, judgement_left - delta / maxf(Engine.time_scale, 0.001))
		if Input.is_action_just_pressed(&"attack"):
			place_line(runner.aim_target() - runner.player_position())
		if _judgement_lines.size() >= 3 or judgement_left <= 0.0:
			judgement_left = 0.0
			runner.end_time_slow()
			if _judgement_lines.is_empty():
				place_line(runner.aim_target() - runner.player_position())
			_fire_judgement()
	if _judgement_tell >= 0.0:
		_judgement_tell -= delta
		if _judgement_tell <= 0.0:
			_judgement_tell = -1.0
			_fire_judgement()


func _judgement_tags(pp: float, root: String = "PRV") -> PackedStringArray:
	var tags := AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, root, "sweep", 1, pp, PackedStringArray(["v"]))
	tags.append("cast:judgement:%d" % _judgement_cast)
	return tags


func _fire_judgement() -> void:
	for line in _judgement_lines:
		_line(line[0], line[1], 5.0 * D(), _judgement_tags(0.3), AscensionRunner.R * 0.5)
		counters["judgement_lines"] = int(counters["judgement_lines"]) + 1
		if has("PRV2"):
			_delayed_lines.append({"delay": 0.5, "from": line[1], "to": line[0], "damage": 3.0 * D(), "tags": _judgement_tags(0.3, "PRV2"), "radius": AscensionRunner.R * 0.5})
	_judgement_lines.clear()
	runner.note_revelation_ended("PRV")


func _tick_sweep(delta: float) -> void:
	if _sweep_left <= 0.0 and _sweep_reverse <= 0.0:
		return
	var reverse := _sweep_left <= 0.0
	if reverse:
		_sweep_reverse = maxf(0.0, _sweep_reverse - delta)
	else:
		_sweep_left = maxf(0.0, _sweep_left - delta)
	_sweep_tick += delta
	if _sweep_tick >= 0.3:
		_sweep_tick = 0.0
		var origin := runner.player_position()
		var dir := (runner.aim_target() - origin).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		var count := EnemyCombat.enemies_on_segment(origin, _far_edge(origin, dir), AscensionRunner.R * 0.5, 0, _segment_scratch, _segment_ts)
		var victims: Array[int] = []
		for i in range(count):
			victims.append(_segment_scratch[i])
		for handle in victims:
			var hits := int(_sweep_hits.get(handle, 0))
			if hits >= 5:
				continue
			_sweep_hits[handle] = hits + 1
			runner.damage_enemy(handle, _sweep_damage * (0.5 if reverse else 1.0), _judgement_tags(0.3, "PRV2" if reverse else "PRV3"))
		counters["sweep_ticks"] = int(counters["sweep_ticks"]) + 1
		runner.note_line_fx(origin, _far_edge(origin, dir), AscensionRunner.R * 0.5)
	if not reverse and _sweep_left <= 0.0:
		if has("PRV2"):
			_sweep_reverse = 0.75
			_sweep_hits.clear()
		else:
			runner.note_revelation_ended("PRV")
	elif reverse and _sweep_reverse <= 0.0:
		runner.note_revelation_ended("PRV")


# ---------------------------------------------------------------- HUD

func hud_state(slot: String) -> Dictionary:
	var state := {}
	if slot == "q":
		if _aiming:
			state["combat_text"] = "AIMING"
		elif has("PR05") and _since_native >= AIM_SECONDS:
			state["combat_text"] = "AIM READY"
		elif _spare_rounds > 0:
			state["combat_text"] = "SPARE %d" % _spare_rounds
	elif slot == "v" and (judgement_left > 0.0 or _sweep_left > 0.0):
		state["combat_text"] = "LINES %d" % _judgement_lines.size() if judgement_left > 0.0 else "SWEEP"
	return state


func collect_draw_points(out: Array) -> void:
	for line in _judgement_lines:
		out.append([line[0], AscensionRunner.R, Color(1.0, 0.9, 0.5, 0.25), line[1]])
	for gun in _guns:
		out.append([gun["at"], 8.0, Color(1.0, 0.8, 0.4, 0.8)])


func describe() -> Dictionary:
	var out := counters.duplicate()
	out["aiming"] = _aiming
	out["spare_rounds"] = _spare_rounds
	out["judgement_left"] = judgement_left
	return out
