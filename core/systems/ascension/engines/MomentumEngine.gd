extends AscensionEngine
class_name MomentumEngine
## Momentum: the Manifestation layer's Momentum pool, dashes that cut, strikes
## that repeat, Lunge and BLINK.
##
## The pool is the existing one (V4: "claims the existing Momentum pool"),
## read as 0-100 from the state's 0-1 fraction; its travel producer and
## still-bleed are the existing ones. Dashes add 15 (a V4 producer the
## existing pool lacks). No Brakes keeps Momentum above 100 in an overflow
## the engine owns. Interpretations: L is the design's 240 for ranges,
## while dash-shaped effects use the player's real dash geometry (160 px).

const EFFECTS: Dictionary = {
	"MO01": &"stride", "MO02": &"passing_blade", "MO03": &"kill_reset", "MO04": &"afterimage",
	"MO05": &"turn", "MO06": &"ram", "MO07": &"running_cut", "MO08": &"slipstream",
	"MO09": &"long_step", "MO10": &"shock_front", "MO11": &"trail", "MO12": &"thousand_cuts",
	"MOQ": &"lunge", "MOQ1": &"rebound", "MOQ2": &"wake", "MOQ3": &"shadow_step", "MOQ4": &"fork",
	"MOQ5": &"carry", "MOQ6": &"long_lunge", "MOF1": &"keep_moving", "MOF2": &"burnout",
	"MOK1": &"never_stop", "MOK2": &"no_brakes", "MOA": &"moving_fire", "MOC": &"blade_storm",
	"MOE1": &"endless_lunge", "MOE2": &"crash_run", "MOS1": &"run_speed", "MOS2": &"slash_width",
	"MOV": &"blink", "MOV1": &"all_of_them", "MOV2": &"back_again", "MOV3": &"dont_blink",
}
const DASH_MOMENTUM := 15.0
const PRIME_SECONDS := 3.0
const AFTERIMAGE_DELAY := 0.3
const CLAIMERS: Array[String] = ["MO01", "MO02", "MO04", "MO05", "MO08", "MO09", "MO11", "MO12", "MOK1", "MOK2", "MOA"]

var _clock: float = 0.0
var _overflow: float = 0.0             # No Brakes: Momentum above 100
var _volley: int = 0
var _strikes: int = 0
var _heading: Vector2 = Vector2.ZERO
var _turn_credit: float = 0.0
var _turn_armed: bool = false
var _travel_since_input: float = 0.0
var _combat_travel: float = 0.0
var _moving_kills: int = 0
var _lane: Dictionary = {}              # {from, to, life}
var _strips: Array = []                 # {from, to, life, tick, damage, root}
var _delayed: Array = []                # {delay, kind, at, dir, damage, tags, arc, radius}
var _afterimage_times: Array[float] = []
var _last_crossed: Array[int] = []
var _cutters: Array = []                # {target, cuts, tick, dir}
var _storm_recovery: float = 0.0
var _extra_dash_ready: bool = true
var _extra_dash_timer: float = 0.0
var _skid_left: float = 0.0
var _long_step_used: float = 0.0
var _extending: bool = false
var _moving_fire_volley: int = -1
var _carry_restored: bool = false
var _carry_store_accum: float = 0.0
# Lunge
var _lunge_active: bool = false
var _lunge_cast: int = 0
var _lunge_scale: float = 1.0
var _lunge_pp: float = 1.0
var _lunge_burnout: float = 0.0
var _lunge_carried: Array[int] = []
var _rebound_left: float = 0.0
var _rebound_used: bool = false
var _return_count: int = 0
var _endless_left: float = 0.0
var _endless_visited: Dictionary = {}
var _crash_spent: float = 0.0
# BLINK
var blink_left: float = 0.0
var _blink_tick: float = 0.0
var _blink_visited: Dictionary = {}     # handle -> clock of last visit
var _blink_landings: Array = []
var _blink_first: bool = true
var _retrace: Array = []
var _retrace_tick: float = 0.0

var counters: Dictionary = {"strips": 0, "primes": 0, "prime_consumed": 0, "afterimages": 0, "turns": 0, "rams": 0, "running_cuts": 0, "slipstreams": 0, "shock_fronts": 0, "trails": 0, "thousand_cuts": 0, "lunges": 0, "lunge_strikes": 0, "rebounds": 0, "forks": 0, "carries": 0, "blade_storms": 0, "cutter_cuts": 0, "kill_resets": 0, "long_steps": 0, "skids": 0, "blinks": 0, "landings": 0, "ghosts": 0, "retraces": 0, "endless_returns": 0, "crash_fronts": 0}


func discipline() -> String:
	return "MO"


func claimed_nouns() -> Array[StringName]:
	for id in CLAIMERS:
		if has(id):
			return [&"momentum"]
	return []


func refresh(active_ids: Dictionary) -> void:
	super.refresh(active_ids)
	if has("MOF1") and not _carry_restored:
		# Keep Moving: Momentum is retained between segments.
		_carry_restored = true
		var carried := float(runner.ledger.state.get("momentum_carry", 0.0))
		if carried > 0.0 and momentum() <= 0.0:
			add_momentum(carried)


func D() -> float:
	return runner.native_damage()


# ---------------------------------------------------------------- the pool

func _state() -> Object:
	return runner.manifestation_state()


func momentum_cap() -> float:
	return 150.0 if has("MOK2") else 100.0


func momentum() -> float:
	var state := _state()
	if state == null:
		return 0.0
	return float(state.get("momentum")) * 100.0 + _overflow


func add_momentum(points: float) -> void:
	var state := _state()
	if state == null or points <= 0.0:
		return
	var base := float(state.get("momentum")) * 100.0
	var room := 100.0 - base
	if points <= room:
		state.call("add_momentum", points / 100.0)
		return
	if room > 0.0:
		state.call("add_momentum", room / 100.0)
	if has("MOK2"):
		_overflow = minf(50.0, _overflow + (points - room))


func spend_momentum(points: float) -> float:
	var state := _state()
	if state == null or points <= 0.0:
		return 0.0
	var spent := 0.0
	if _overflow > 0.0:
		var from_overflow := minf(_overflow, points)
		_overflow -= from_overflow
		spent += from_overflow
	var base := float(state.get("momentum")) * 100.0
	var remaining := minf(base, points - spent)
	if remaining > 0.0:
		state.set("momentum", maxf(0.0, (base - remaining) / 100.0))
		spent += remaining
	return spent


func spend_all_momentum() -> float:
	return spend_momentum(momentum())


func hold_decay(seconds: float) -> void:
	var state := _state()
	if state != null:
		state.set("momentum_hold_seconds", maxf(float(state.get("momentum_hold_seconds")), seconds))


## Burnout: a full pool gives +150% damage and +50% area, linearly from zero.
func _burnout_fraction() -> float:
	return clampf(momentum() / 100.0, 0.0, 1.0) if has("MOF2") else 0.0


# ---------------------------------------------------------------- tick

func tick(delta: float) -> void:
	_clock += delta
	_track_heading()
	_tick_lane(delta)
	_tick_strips(delta)
	_tick_delayed(delta)
	_tick_cutters(delta)
	_tick_lunge(delta)
	_tick_blink(delta)
	if _storm_recovery > 0.0:
		_storm_recovery = maxf(0.0, _storm_recovery - delta)
	if _rebound_left > 0.0:
		_rebound_left = maxf(0.0, _rebound_left - delta)
	if _endless_left > 0.0:
		_endless_left = maxf(0.0, _endless_left - delta)
		if _endless_left <= 0.0:
			_end_endless_chain()
	if _skid_left > 0.0:
		_skid_left = maxf(0.0, _skid_left - delta)
		_check_skid_wall()
	if not _extra_dash_ready:
		_extra_dash_timer -= delta
		if _extra_dash_timer <= 0.0:
			_extra_dash_ready = true
	while _afterimage_times.size() > 0 and _clock - _afterimage_times[0] > 4.0:
		_afterimage_times.remove_at(0)
	if has("MOF1"):
		_carry_store_accum += delta
		if _carry_store_accum >= 0.5:
			_carry_store_accum = 0.0
			runner.ledger.state["momentum_carry"] = momentum()
	# Action charge: +1 per L of voluntary travel in combat.
	if runner.is_player_moving() and not runner.is_dash_active() and runner.nearest_enemy(runner.player_position(), 2.0 * AscensionRunner.L) != 0:
		_combat_travel += runner.travel_this_frame
		while _combat_travel >= AscensionRunner.L:
			_combat_travel -= AscensionRunner.L
			runner.add_action_charge(1.0)


func _track_heading() -> void:
	if not runner.is_player_moving():
		return
	var at := runner.player_position()
	var step := runner.travel_this_frame
	var previous: Vector2 = runner._last_player_position
	var heading := (at - previous).normalized() if step > 0.5 else _heading
	if heading == Vector2.ZERO:
		return
	_travel_since_input += step
	if _heading != Vector2.ZERO and heading.dot(_heading) <= 0.0:
		# A turn of at least 90 degrees.
		if has("MO05") and _turn_credit >= AscensionRunner.L:
			_turn_armed = true
			_turn_credit = 0.0
		if has("MOK2") and _skid_left <= 0.0:
			_skid_left = 0.25
			counters["skids"] = int(counters["skids"]) + 1
	_turn_credit += step
	_heading = heading


func _check_skid_wall() -> void:
	var player := runner.player()
	if player != null and player.has_method("is_on_wall") and bool(player.call("is_on_wall")):
		_skid_left = 0.0
		spend_momentum(30.0)
		player.call("take_damage", 0.05 * runner.player_max_hp(), null)


# ---------------------------------------------------------------- dashes

func on_player_dashed(_from: Vector2, _direction: Vector2) -> void:
	if _extending:
		_extending = false
		return
	add_momentum(DASH_MOMENTUM)
	_long_step_used = 0.0
	if has("MOK1"):
		if momentum() >= 50.0:
			runner.refund_dash_recovery(0.4)
		if _extra_dash_ready:
			# Never Stop: a second charge, available again after a full recovery.
			_extra_dash_ready = false
			_extra_dash_timer = 1.6
			runner.refund_dash_recovery(1.6)


func on_dash_ended(from: Vector2, to: Vector2, direction: Vector2) -> void:
	var crossed: Array[int] = []
	if has("MO02") or has("MOQ") and _lunge_active:
		crossed = _dash_strip(from, to, direction)
	if crossed.size() >= 2:
		runner.add_action_charge(1.0)
	if has("MO10") and crossed.size() >= 8:
		_shock_front(to, direction, 2.0 * D(), 0.35, "MO10")
	if has("MO11") and momentum() >= 75.0:
		_strips.append({"from": from, "to": to, "life": 1.5, "tick": 0.0, "damage": 0.4 * D(), "root": "MO11", "pp": 0.0})
		counters["trails"] = int(counters["trails"]) + 1
	if has("MO06"):
		_ram(crossed, to, direction)
	if _lunge_active:
		_finish_lunge(from, to, direction, crossed)
	elif has("MO09") and _long_step_used < 2.0 * AscensionRunner.L and Input.is_action_pressed(&"dash") and momentum() >= 40.0:
		# Long Step: keep going without invulnerability, 40 Momentum per L.
		spend_momentum(40.0)
		_long_step_used += AscensionRunner.L
		counters["long_steps"] = int(counters["long_steps"]) + 1
		_extending = true
		if runner.dash_toward(direction, AscensionRunner.L, false, float(runner.player().get("_dash").get("cooldown_left"))):
			runner.player().set("invulnerable_time", 0.0)
		_extending = false


## Passing Blade along the dash path; primes victims; remembers who was crossed.
func _dash_strip(from: Vector2, to: Vector2, direction: Vector2) -> Array[int]:
	var out: Array[int] = []
	var ts := PackedFloat32Array()
	var count := EnemyCombat.enemies_on_segment(from, to, AscensionRunner.R * 0.25, 0, out, ts)
	var crossed: Array[int] = []
	for i in range(count):
		crossed.append(out[i])
	if not has("MO02"):
		return crossed
	counters["strips"] = int(counters["strips"]) + 1
	var tags := AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "MO02", "strip", 1, 0.6)
	tags.append("cast:dash:%d" % int(counters["strips"]))
	for handle in crossed:
		runner.damage_enemy(handle, 0.6 * D(), tags)
		if runner.enemy_alive(handle):
			runner.status_of(handle)["prime"] = _clock + PRIME_SECONDS
			counters["primes"] = int(counters["primes"]) + 1
	_last_crossed = crossed.duplicate()
	while _last_crossed.size() > 3:
		_last_crossed.pop_front()
	return crossed


func _ram(crossed: Array[int], endpoint: Vector2, direction: Vector2) -> void:
	for handle in crossed:
		if not runner.enemy_alive(handle) or not runner.has_status(handle, "prime"):
			continue
		if runner.is_boss(handle):
			# Bosses take 0.5D stagger instead of being carried.
			runner.damage_enemy(handle, 0.5 * D(), AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "MO06", "ram", 1, 0.5))
			EnemyCombat.apply_stun(handle, 0.25)
			continue
		var carried_to := endpoint + direction * 12.0
		if runner.is_elite(handle):
			carried_to = runner.enemy_position(handle) + direction * AscensionRunner.R * 0.5
		runner.move_enemy_to(handle, carried_to)
		counters["rams"] = int(counters["rams"]) + 1
		var struck := runner.nearest_enemy(carried_to, AscensionRunner.R, handle)
		var tags := AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "MO06", "ram", 1, 0.5)
		runner.damage_enemy(handle, 0.8 * D(), tags)
		if struck != 0:
			runner.damage_enemy(struck, 0.8 * D(), tags)
		return


func _shock_front(at: Vector2, direction: Vector2, damage: float, pp: float, root: String) -> void:
	counters["shock_fronts"] = int(counters["shock_fronts"]) + 1
	var perp := Vector2(-direction.y, direction.x)
	for side in [-1.0, 1.0]:
		var tags := AscensionTags.make("melee", AscensionTags.FAMILY_TREE, root, "wave", 1, pp)
		runner.spawn_slash(at, perp * side, damage, tags, 90.0, 3.0 * AscensionRunner.R)


# ---------------------------------------------------------------- strikes and hits

func decorate_native_slash(slash: Node) -> void:
	if _turn_armed:
		slash.set_meta("mo_turn", true)


func arc_multiplier() -> float:
	var mul := 1.0
	if has("MO01"):
		var m := momentum()
		if m >= 100.0:
			mul *= 1.4
		elif m >= 50.0:
			mul *= 1.2
	if has("MOS2"):
		var r := float(rank("MOS2"))
		mul *= 1.0 + 0.6 * r / (r + 80.0)
	return mul


func on_native_fire(style: String, origin: Vector2, target: Vector2, _power: float, _haste: float) -> void:
	_volley += 1
	var dir := (target - origin).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	if style != "melee":
		if has("MOA") and runner.is_player_moving():
			add_momentum(8.0)
			if momentum() >= 20.0:
				spend_momentum(20.0)
				_moving_fire_volley = _volley
		return
	_strikes += 1
	if has("MO07") and _travel_since_input >= AscensionRunner.L:
		runner.scale_native_recovery(0.6)
		counters["running_cuts"] = int(counters["running_cuts"]) + 1
	_travel_since_input = 0.0
	if has("MO05") and _turn_armed:
		_turn_armed = false
		counters["turns"] = int(counters["turns"]) + 1
		var burn := _burnout_fraction()
		var damage := 0.5 * D() * (1.0 + 1.5 * burn)
		var radius := 2.0 * AscensionRunner.R * (1.0 + 0.5 * burn)
		if has("MOF2"):
			spend_all_momentum()
		for angle in [-45.0, 45.0]:
			runner.spawn_slash(origin, dir.rotated(deg_to_rad(angle)), damage, AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "MO05", "cross", 1, 0.5), 60.0, radius)
	if has("MO04") and momentum() >= 60.0:
		_queue_afterimage(origin, dir, 0.6 * D(), 0.5, "MO04")
	if has("MO12") and momentum() >= 75.0 and _strikes % 3 == 0:
		for handle in _last_crossed:
			var at := runner.enemy_position(handle) if runner.enemy_alive(handle) else origin
			_queue_afterimage(at, dir, 0.5 * D(), 0.5, "MO12")
		if not _last_crossed.is_empty():
			counters["thousand_cuts"] = int(counters["thousand_cuts"]) + 1


func _queue_afterimage(at: Vector2, dir: Vector2, damage: float, pp: float, root: String, repeats: int = 1, spacing: float = 0.0) -> void:
	for i in range(repeats):
		_delayed.append({"delay": AFTERIMAGE_DELAY + spacing * float(i), "kind": "slash", "at": at, "dir": dir, "damage": damage, "tags": AscensionTags.make("melee", AscensionTags.FAMILY_TREE, root, "afterimage", 1, pp), "arc": 145.0, "radius": 62.0})
	counters["afterimages"] = int(counters["afterimages"]) + 1
	_afterimage_times.append(_clock)
	if has("MOC") and _storm_recovery <= 0.0 and _afterimage_times.size() >= 6:
		_blade_storm()


func _tick_delayed(delta: float) -> void:
	if _delayed.is_empty():
		return
	var due: Array = []
	for entry in _delayed:
		entry["delay"] = float(entry["delay"]) - delta
		if float(entry["delay"]) <= 0.0:
			due.append(entry)
	for entry in due:
		_delayed.erase(entry)
		runner.spawn_slash(entry["at"], entry["dir"], float(entry["damage"]), entry["tags"], float(entry["arc"]), float(entry["radius"]))


func modify_outgoing_damage(preview: Dictionary, raw: float) -> float:
	var handle := int(preview["handle"])
	var damage := raw
	if has("MO02") and bool(preview["core_strike"]) and preview["core"] == "melee" and runner.has_status(handle, "prime"):
		damage += 0.5 * D()
	if _moving_fire_volley == _volley and preview["family"] == AscensionTags.FAMILY_NATIVE and preview["core"] != "melee":
		damage += 0.5 * D()
		_moving_fire_volley = -1
	return damage


func on_hit(hit: Dictionary) -> void:
	var handle := int(hit["handle"])
	if hit["core"] == "melee" and AscensionTags.has_flag(hit["tags"], "core_strike") and runner.has_status(handle, "prime"):
		runner.clear_status(handle, "prime")
		counters["prime_consumed"] = int(counters["prime_consumed"]) + 1
	if hit["root"] == "MOQ" and hit["path"] == "lunge" and has("MOQ4") and (bool(hit["is_elite"]) or bool(hit["is_boss"])):
		_fork(hit)


func on_kill(hit: Dictionary, _context: RefCounted) -> void:
	if hit["core"] != "melee":
		return
	if has("MO03"):
		if runner.refund_dash_recovery_budgeted(0.15) > 0.0:
			counters["kill_resets"] = int(counters["kill_resets"]) + 1
	if has("MOF1"):
		hold_decay(3.0)
	if has("MO08") and runner.is_player_moving():
		_moving_kills += 1
		if _moving_kills >= 3:
			_moving_kills = 0
			hold_decay(2.0)
			var at := runner.player_position()
			_lane = {"from": at - _heading * 2.0 * AscensionRunner.R, "to": at, "life": 4.0}
			counters["slipstreams"] = int(counters["slipstreams"]) + 1
	if hit["path"] == "lunge" or hit["path"] == "strip" or hit["root"] == "MOQ2":
		_lunge_kill(hit)


# ---------------------------------------------------------------- lane, strips, cutters

func _tick_lane(delta: float) -> void:
	if _lane.is_empty():
		return
	_lane["life"] = float(_lane["life"]) - delta
	if float(_lane["life"]) <= 0.0:
		_lane = {}


func _in_lane() -> bool:
	if _lane.is_empty():
		return false
	var at := runner.player_position()
	var from: Vector2 = _lane["from"]
	var to: Vector2 = _lane["to"]
	var seg := to - from
	if seg.length_squared() < 1.0:
		return at.distance_to(to) <= AscensionRunner.R
	var t := clampf((at - from).dot(seg) / seg.length_squared(), 0.0, 1.0)
	return at.distance_to(from + seg * t) <= AscensionRunner.R


func _tick_strips(delta: float) -> void:
	if _strips.is_empty():
		return
	var out: Array[int] = []
	var ts := PackedFloat32Array()
	for i in range(_strips.size() - 1, -1, -1):
		var strip: Dictionary = _strips[i]
		strip["life"] = float(strip["life"]) - delta
		if float(strip["life"]) <= 0.0:
			_strips.remove_at(i)
			continue
		strip["tick"] = float(strip["tick"]) + delta
		if float(strip["tick"]) < 0.5:
			continue
		strip["tick"] = 0.0
		var count := EnemyCombat.enemies_on_segment(strip["from"], strip["to"], AscensionRunner.R * 0.25, 0, out, ts)
		var tags := AscensionTags.make("melee", AscensionTags.FAMILY_TREE, String(strip["root"]), "trail", 1, float(strip["pp"]))
		for j in range(count):
			runner.damage_enemy(out[j], float(strip["damage"]), tags)


func _blade_storm() -> void:
	counters["blade_storms"] = int(counters["blade_storms"]) + 1
	_storm_recovery = 8.0
	_afterimage_times.clear()
	runner.note_catastrophe("MOC")
	var used: Dictionary = {}
	var origin := runner.player_position()
	for handle in runner.enemies_in_radius(origin, 4.0 * AscensionRunner.L):
		if _cutters.size() >= 6:
			break
		if used.has(handle):
			continue
		used[handle] = true
		_cutters.append({"target": handle, "cuts": 4, "tick": 0.0, "dir": Vector2.from_angle(runner.rng().randf_range(0.0, TAU))})
	if BattleText != null:
		BattleText.popup(origin, "BLADE STORM", Color(0.9, 0.9, 1.0, 1.0), 1.6)


func _tick_cutters(delta: float) -> void:
	if _cutters.is_empty():
		return
	var out: Array[int] = []
	var ts := PackedFloat32Array()
	for i in range(_cutters.size() - 1, -1, -1):
		var cutter: Dictionary = _cutters[i]
		cutter["tick"] = float(cutter["tick"]) + delta
		if float(cutter["tick"]) < 0.75:
			continue
		cutter["tick"] = 0.0
		var target := int(cutter["target"])
		if not runner.enemy_alive(target):
			target = runner.nearest_enemy(runner.player_position(), 4.0 * AscensionRunner.L)
			cutter["target"] = target
		if target == 0:
			_cutters.remove_at(i)
			continue
		var centre := runner.enemy_position(target)
		var dir: Vector2 = (cutter["dir"] as Vector2).rotated(deg_to_rad(45.0))
		cutter["dir"] = dir
		var count := EnemyCombat.enemies_on_segment(centre - dir * AscensionRunner.R, centre + dir * AscensionRunner.R, 10.0, 0, out, ts)
		var tags := AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "MOC", "cut", 2, 0.35)
		for j in range(count):
			runner.damage_enemy(out[j], D(), tags)
		counters["cutter_cuts"] = int(counters["cutter_cuts"]) + 1
		cutter["cuts"] = int(cutter["cuts"]) - 1
		if int(cutter["cuts"]) <= 0:
			_cutters.remove_at(i)


# ---------------------------------------------------------------- Lunge (Q)

func q_active(id: String) -> bool:
	return id == "MOQ" and _lunge_active


func activate_q(id: String) -> Dictionary:
	if id != "MOQ":
		return {"ok": false, "message": "NOT MOMENTUM", "cooldown": 0.0}
	if _lunge_active:
		return {"ok": false, "message": "LUNGING", "cooldown": 0.0}
	var free := false
	if _rebound_left > 0.0 and not _rebound_used:
		_rebound_used = true
		_rebound_left = 0.0
		free = true
		counters["rebounds"] = int(counters["rebounds"]) + 1
	elif _endless_left > 0.0:
		free = true
		counters["endless_returns"] = int(counters["endless_returns"]) + 1
	var origin := runner.player_position()
	var aim := runner.auto_aim_for("MOQ") if runner.automatic_cast else runner.aim_target()
	var dir := (aim - origin).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var reach := (3.0 if has("MOQ6") else 1.5) * AscensionRunner.L
	_lunge_scale = runner.q_scale()
	_lunge_pp = runner.q_proc_scale()
	_lunge_burnout = _burnout_fraction()
	_crash_spent = 0.0
	if has("MOE2"):
		_crash_spent = spend_all_momentum()
		reach = 4.0 * AscensionRunner.L
	elif has("MOF2"):
		spend_all_momentum()
	var travel := minf(reach, maxf(origin.distance_to(aim), AscensionRunner.R))
	if not runner.dash_toward(dir, travel, false, 0.0):
		return {"ok": false, "message": "CANNOT DASH", "cooldown": 0.0}
	_lunge_active = true
	if not free:
		_lunge_cast += 1
		_return_count = 0
		_endless_visited.clear()
	_lunge_carried.clear()
	counters["lunges"] = int(counters["lunges"]) + 1
	if has("MOQ3"):
		_queue_afterimage(origin, dir, 0.8 * D() * _lunge_scale, 0.5 * _lunge_pp, "MOQ3", 2, 0.3)
	return {"ok": true, "message": "LUNGE", "cooldown": 0.0 if free else 5.0}


func _tick_lunge(_delta: float) -> void:
	pass


func _finish_lunge(from: Vector2, to: Vector2, direction: Vector2, crossed: Array[int]) -> void:
	_lunge_active = false
	counters["lunge_strikes"] = int(counters["lunge_strikes"]) + 1
	var damage := (3.0 if has("MOE2") else 2.0) * D() * _lunge_scale
	var radius := (0.75 if has("MOQ6") else 1.0) * AscensionRunner.R * runner.q_area_scale()
	if has("MOF2") or has("MOE2"):
		damage *= 1.0 + 1.5 * _lunge_burnout
		radius *= 1.0 + 0.5 * _lunge_burnout
	if has("MOE1") and _return_count > 0:
		damage = maxf(0.5 * D(), damage * pow(0.9, _return_count))
	var flags := PackedStringArray(["core_strike"])
	var tags := AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "MOQ", "lunge", 1, 1.0 * _lunge_pp, flags)
	tags.append("cast:lunge:%d" % _lunge_cast)
	# Carry: one normal (Crash Run: up to twenty) rides to the endpoint.
	if has("MOQ5") or has("MOE2"):
		var limit := 20 if has("MOE2") else 1
		for handle in crossed:
			if _lunge_carried.size() >= limit:
				break
			if runner.enemy_alive(handle) and runner.is_normal(handle):
				runner.move_enemy_to(handle, to + direction * 16.0)
				_lunge_carried.append(handle)
				counters["carries"] = int(counters["carries"]) + 1
	runner.spawn_slash(to, direction, damage, tags, 180.0, radius)
	if has("MOQ2"):
		_strips.append({"from": from, "to": to, "life": 2.0, "tick": 0.0, "damage": 0.6 * D(), "root": "MOQ2", "pp": 0.0})
	if has("MOE2"):
		var fronts := mini(4, int(_crash_spent / 25.0))
		for _i in range(fronts):
			_shock_front(to, direction, D(), 0.35, "MOE2")
			counters["crash_fronts"] = int(counters["crash_fronts"]) + 1


func _fork(hit: Dictionary) -> void:
	counters["forks"] = int(counters["forks"]) + 1
	var at: Vector2 = hit["position"]
	var dir := (at - runner.player_position()).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	for angle in [-35.0, 35.0]:
		runner.spawn_slash(at, dir.rotated(deg_to_rad(angle)), D(), AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "MOQ4", "wave", 2, 0.5), 40.0, 3.0 * AscensionRunner.R)


func _lunge_kill(hit: Dictionary) -> void:
	var handle := int(hit["handle"])
	if has("MOQ1") and not _rebound_used and _rebound_left <= 0.0 and not has("MOE1"):
		_rebound_left = 2.0
	if has("MOE1") and not _endless_visited.has(handle):
		_endless_visited[handle] = true
		_return_count += 1
		_endless_left = 2.0


func _end_endless_chain() -> void:
	if _return_count >= 6 and _storm_recovery <= 0.0:
		_blade_storm()
	_return_count = 0
	_rebound_used = false


func auto_target(_id: String) -> Vector2:
	var origin := runner.player_position()
	var aim := runner.aim_target()
	var out: Array[int] = []
	var ts := PackedFloat32Array()
	if EnemyCombat.enemies_on_segment(origin, origin + (aim - origin).normalized() * 1.5 * AscensionRunner.L, AscensionRunner.R * 0.5, 0, out, ts) > 0:
		return aim
	return runner.nearest_enemy_position(1.5 * AscensionRunner.L)


# ---------------------------------------------------------------- BLINK (V)

func activate_v(id: String) -> Dictionary:
	if id != "MOV":
		return {"ok": false, "message": "NOT MOMENTUM", "cooldown": 0.0}
	blink_left = 4.0
	_blink_tick = 0.0
	_blink_visited.clear()
	_blink_landings.clear()
	_blink_first = true
	counters["blinks"] = int(counters["blinks"]) + 1
	return {"ok": true, "message": "BLINK", "cooldown": 0.0}


func _tick_blink(delta: float) -> void:
	if blink_left > 0.0:
		blink_left = maxf(0.0, blink_left - delta)
		_blink_tick += delta
		if _blink_tick >= 0.15 and (Input.is_action_pressed(&"attack") or runner.automatic_cast or Engine.is_editor_hint() or blink_forced):
			_blink_tick = 0.0
			_blink_land()
		if blink_left <= 0.0:
			runner.note_revelation_ended("MOV")
			if has("MOV2") and not _blink_landings.is_empty():
				_retrace = _blink_landings.duplicate()
				_retrace.reverse()
				_retrace = _retrace.slice(0, 12)
				_retrace_tick = 0.0
				return
	if not _retrace.is_empty():
		_retrace_tick += delta
		if _retrace_tick >= 0.1:
			_retrace_tick = 0.0
			var at: Vector2 = _retrace.pop_front()
			runner.teleport_player(at)
			runner.spawn_slash(at, _heading if _heading != Vector2.ZERO else Vector2.RIGHT, D(), AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "MOV2", "lunge", 2, 0.6, PackedStringArray(["v"])), 180.0, AscensionRunner.R)
			counters["retraces"] = int(counters["retraces"]) + 1


## Tests drive BLINK landings without holding the attack key.
var blink_forced: bool = false


func _blink_target() -> int:
	var rect := runner.camera_rect()
	var aim := runner.aim_target()
	var best := 0
	var best_score := INF
	for handle in runner.enemies_in_radius(rect.get_center(), rect.size.length() * 0.5):
		if not rect.has_point(runner.enemy_position(handle)):
			continue
		var visited: float = float(_blink_visited.get(handle, -INF))
		if runner.is_normal(handle):
			if visited != -INF:
				continue
		elif _clock - visited < 0.5:
			continue
		var score := aim.distance_to(runner.enemy_position(handle))
		if score < best_score:
			best_score = score
			best = handle
	return best


func _blink_land() -> void:
	var target := _blink_target()
	if target == 0:
		return
	var at := runner.enemy_position(target)
	var dir := (at - runner.player_position()).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var landing := at - dir * 20.0
	runner.teleport_player(landing)
	_blink_visited[target] = _clock
	_blink_landings.append(landing)
	counters["landings"] = int(counters["landings"]) + 1
	if _blink_first or not has("MOV3"):
		runner.player().call("grant_invulnerability", 0.1)
	_blink_first = false
	var tags := AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "MOV", "lunge", 1, 0.6, PackedStringArray(["core_strike", "v"]))
	tags.append("cast:blink:%d" % int(counters["blinks"]))
	runner.spawn_slash(landing, dir, 2.0 * D(), tags, 180.0, AscensionRunner.R)
	if has("MOV3"):
		_delayed.append({"delay": 0.3, "kind": "slash", "at": landing, "dir": dir, "damage": 0.8 * D(), "tags": AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "MOV3", "afterimage", 2, 0.5, PackedStringArray(["v"])), "arc": 145.0, "radius": 62.0})
		_delayed.append({"delay": 0.6, "kind": "slash", "at": landing, "dir": dir, "damage": 0.8 * D(), "tags": AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "MOV3", "afterimage", 2, 0.5, PackedStringArray(["v"])), "arc": 145.0, "radius": 62.0})
	if has("MOV1"):
		var ghost := 0
		for handle in runner.enemies_in_radius(landing, 2.0 * AscensionRunner.L, target):
			if runner.is_normal(handle) and not _blink_visited.has(handle):
				ghost = handle
				break
		if ghost != 0:
			_blink_visited[ghost] = _clock
			counters["ghosts"] = int(counters["ghosts"]) + 1
			runner.spawn_impact(runner.enemy_position(ghost), D(), AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "MOV1", "ghost", 2, 0.4, PackedStringArray(["v"])), 40.0)


# ---------------------------------------------------------------- multipliers and HUD

func move_speed_multiplier() -> float:
	var mul := 1.0
	if has("MOS1"):
		var r := float(rank("MOS1"))
		mul *= 1.0 + 0.45 * r / (r + 60.0)
	if has("MO08") and _in_lane():
		mul *= 1.2
	if has("MOK2") and momentum() > 100.0:
		mul *= 1.0 + 0.35 * clampf((momentum() - 100.0) / 50.0, 0.0, 1.0)
	return mul


func haste_multiplier(core: String) -> float:
	if core != "melee":
		return 1.0
	var mul := 1.0
	if has("MOK1") and momentum() <= 0.0:
		mul /= 1.4
	if has("MOK2") and momentum() > 100.0:
		mul *= 1.0 + 0.35 * clampf((momentum() - 100.0) / 50.0, 0.0, 1.0)
	return mul


func hud_state(slot: String) -> Dictionary:
	var state := {}
	if slot == "q":
		state["resource_value"] = momentum()
		state["resource_max"] = momentum_cap()
		state["combat_text"] = "MOMENTUM %d" % int(momentum())
		if _rebound_left > 0.0:
			state["combat_text"] = "REBOUND %.1fs" % _rebound_left
		elif _endless_left > 0.0:
			state["combat_text"] = "RETURN %d" % _return_count
	elif slot == "v" and blink_left > 0.0:
		state["combat_text"] = "BLINK %.1fs" % blink_left
	return state


func collect_draw_points(out: Array) -> void:
	for strip in _strips:
		out.append([strip["from"], 3.0, Color(0.9, 0.3, 0.3, 0.5), strip["to"]])
	if not _lane.is_empty():
		out.append([_lane["from"], 10.0, Color(0.5, 0.9, 1.0, 0.25), _lane["to"]])


func describe() -> Dictionary:
	var out := counters.duplicate()
	out["momentum"] = momentum()
	out["turn_armed"] = _turn_armed
	out["blink_left"] = blink_left
	out["cutters"] = _cutters.size()
	return out
