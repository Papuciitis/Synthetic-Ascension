extends AscensionEngine
class_name InvocationEngine
## Invocation: Sigils, Growth, Echoes, Consecrate, Choir and THE HOST.
##
## Sigil: radius R, life 8 s, one 0.6D pulse per second at Proc Power 0.4,
## base capacity three. Growth 0-5 per Sigil (+0.15D, +8% radius each).
## Echo: a saved Core strike (0.6D, Proc Power 0.4) released toward current
## enemies when its Sigil expires. Pulses resolve in the engine (so Chain
## Pulse and Choir know how many distinct enemies they hit) and are drawn
## through the runner; Echo releases use the runner's strike geometry.

const EFFECTS: Dictionary = {
	"IN01": &"leave_a_sigil", "IN02": &"stretch_sigil", "IN03": &"endure", "IN04": &"congregation",
	"IN05": &"fed_by_death", "IN06": &"echo_shrine", "IN07": &"warm_circle", "IN08": &"off_beat",
	"IN09": &"detonate_sigil", "IN10": &"chain_pulse", "IN11": &"copy_rune", "IN12": &"home_rune",
	"INQ": &"consecrate", "INQ1": &"great_sigil", "INQ2": &"open_the_vault", "INQ3": &"wandering_sigil",
	"INQ4": &"swarm", "INQ5": &"consume", "INQ6": &"resonance", "INF1": &"roaming_sigils",
	"INF2": &"split_sigils", "INK1": &"inherit_the_word", "INK2": &"blood_rune", "INA": &"echo_chamber",
	"INC": &"choir", "INE1": &"mobile_choir", "INE2": &"sigil_web", "INS1": &"sigil_life",
	"INS2": &"sigil_size", "INV": &"the_host", "INV1": &"full_choir", "INV2": &"march", "INV3": &"one_voice",
}
const SIGIL_LIFE := 8.0
const PULSE_INTERVAL := 1.0
const PULSE_D := 0.6
const PULSE_PP := 0.4
const ECHO_D := 0.6
const ECHO_PP := 0.4
const GROWTH_MAX := 5.0
const BASE_CAPACITY := 3

var _clock: float = 0.0
var sigils: Array = []                  # see _make_sigil
var _serial: int = 0
var _hits: float = 0.0                  # weighted Magic Core hits toward Leave a Sigil
var _placed_volley: int = -1
var _volley: int = 0
var _echo_volley: int = -1
var _offbeat_volley: Dictionary = {}    # sigil id -> volley
var _travel: float = 0.0
var _stretch_armed: bool = false
var _warm_cooldown: float = 0.0
var _warm_pending: bool = false
var _growth_bank: float = 0.0
var _chain_recovery: float = 0.0
var _choir_recovery: float = 0.0
var _pair_cooldowns: Dictionary = {}    # "a:b" -> clock
var _consume_queue: Array = []          # {at, pulses, tick, echoes}
var _last_strike: Dictionary = {}       # {core, origin, target}
var host_left: float = 0.0
var _host_copies: Array = []
var _host_stored: Array = []
var _one_voice: Dictionary = {}
var _band: Dictionary = {}              # Mobile Choir {left, members}
var _web_left: float = 0.0
var _lines_fx: Array = []

var counters: Dictionary = {"placed": 0, "pulses": 0, "pulse_hits": 0, "echoes_stored": 0, "echoes_released": 0, "growth": 0.0, "detonations": 0, "chain_pulses": 0, "children": 0, "stretches": 0, "endure_seconds": 0.0, "warm_circles": 0, "home_touches": 0, "consecrates": 0, "resonance_lines": 0, "consumed": 0, "choirs": 0, "choir_detonations": 0, "blood_sigils": 0, "hosts": 0, "host_copies": 0, "band_waves": 0, "web_edges": 0, "one_voice_pulses": 0}


func discipline() -> String:
	return "IN"


func D() -> float:
	return runner.native_damage_for("magic")


func has_sigils() -> bool:
	return has("IN01") or has("IN02") or has("INQ")


# ---------------------------------------------------------------- sigils

func capacity() -> int:
	var cap := BASE_CAPACITY
	if has("IN04"):
		# Each connected parent beyond the first adds a slot, up to three.
		var connected := 0
		for sigil in _parents():
			for other in _parents():
				if other != sigil and _touching(sigil, other):
					connected += 1
					break
		cap += mini(3, maxi(0, connected - 1))
	return cap


func _parents() -> Array:
	return sigils.filter(func(s): return int(s["parent"]) == 0 and not bool(s["copy"]))


func _slots_used() -> int:
	var used := 0
	for sigil in sigils:
		if not bool(sigil["copy"]):
			used += int(sigil["slots"])
	return used


func sigil_radius(sigil: Dictionary) -> float:
	var radius := float(sigil["radius"]) * (1.0 + 0.08 * float(sigil["growth"]))
	if has("INS2"):
		var r := float(rank("INS2"))
		radius *= 1.0 + 0.8 * r / (r + 105.0)
	if has("INF1") and int(sigil["parent"]) == 0:
		radius *= 0.75
	return radius


func sigil_damage(sigil: Dictionary) -> float:
	var damage := float(sigil["damage"]) * D() + 0.15 * D() * float(sigil["growth"])
	if has("INS1"):
		damage *= 1.0 + 0.005 * sqrt(float(rank("INS1")))
	if bool(sigil["copy"]):
		damage *= 0.5
	return damage


func _life() -> float:
	return SIGIL_LIFE + (0.25 * sqrt(float(rank("INS1"))) if has("INS1") else 0.0)


func _make_sigil(at: Vector2, kind: String = "plain") -> Dictionary:
	_serial += 1
	var sigil := {
		"id": _serial, "at": at, "radius": AscensionRunner.R, "damage": PULSE_D, "pp": PULSE_PP,
		"life": _life(), "pulse": PULSE_INTERVAL, "growth": 0.0, "echoes": [], "echo_slots": 3 if has("INF2") or has("IN06") else (1 if has("IN07") else 0),
		"parent": 0, "child": 0, "children": [], "slots": 1, "copy": false, "blood": false, "grown": false,
		"detonated_path": false, "next_echo_bonus": 0.0, "stretch": Vector2.ZERO, "kind": kind,
		"created": _clock, "follow_cursor": false, "home": false, "pulsed": 0, "detonated_choir": false,
	}
	match kind:
		"great":
			sigil["radius"] = 2.0 * AscensionRunner.R
			sigil["damage"] = 1.5
			sigil["echo_slots"] = 6
			sigil["slots"] = 2
		"swarm":
			sigil["radius"] = 0.7 * AscensionRunner.R
			sigil["damage"] = 0.4
			sigil["pp"] = 0.3
		"child":
			sigil["radius"] = 0.5 * AscensionRunner.R
			sigil["damage"] = 0.5 * PULSE_D
			sigil["echo_slots"] = 1
			sigil["life"] = 6.0
		"blank":
			sigil["damage"] = 0.0
	return sigil


## Places a parent Sigil, replacing the oldest at capacity.
func place_sigil(at: Vector2, kind: String = "plain", growth: float = 0.0) -> Dictionary:
	var sigil := _make_sigil(at, kind)
	sigil["growth"] = growth
	while _slots_used() + int(sigil["slots"]) > capacity():
		var oldest := _oldest_parent()
		if oldest.is_empty():
			break
		_destroy(oldest, true)
	sigils.append(sigil)
	counters["placed"] = int(counters["placed"]) + 1
	if has("IN12"):
		for other in sigils:
			other["home"] = false
		sigil["home"] = true
	return sigil


func _oldest_parent() -> Dictionary:
	var oldest: Dictionary = {}
	for sigil in sigils:
		if int(sigil["parent"]) == 0 and not bool(sigil["copy"]) and (oldest.is_empty() or float(sigil["created"]) < float(oldest["created"])):
			oldest = sigil
	return oldest


## Removes a Sigil. Replacement detonates (Detonate Sigil) and releases
## Echoes; natural expiry only releases Echoes.
func _destroy(sigil: Dictionary, replaced: bool) -> void:
	if not sigils.has(sigil):
		return
	sigils.erase(sigil)
	if replaced and has("IN09"):
		_detonate(sigil, true)
	_release_echoes(sigil)
	if replaced and has("INF2"):
		for child_id in sigil["children"]:
			var child := _find(int(child_id))
			if not child.is_empty():
				_impact(child, D(), "INF2", 0.5)
				sigils.erase(child)
	for child_id in sigil["children"]:
		var child := _find(int(child_id))
		if not child.is_empty():
			child["parent"] = 0


func _find(id: int) -> Dictionary:
	for sigil in sigils:
		if int(sigil["id"]) == id:
			return sigil
	return {}


func _touching(a: Dictionary, b: Dictionary) -> bool:
	return (a["at"] as Vector2).distance_to(b["at"]) <= sigil_radius(a) + sigil_radius(b)


func _containing(point: Vector2) -> Array:
	var out: Array = []
	for sigil in sigils:
		if (sigil["at"] as Vector2).distance_to(point) <= sigil_radius(sigil):
			out.append(sigil)
	return out


func player_inside() -> Array:
	return _containing(runner.player_position())


# ---------------------------------------------------------------- pulses

func _impact(sigil: Dictionary, damage: float, root: String, pp: float, flags: PackedStringArray = PackedStringArray(), radius: float = -1.0) -> int:
	var at: Vector2 = sigil["at"]
	var r := sigil_radius(sigil) if radius < 0.0 else radius
	var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, root, "pulse", 1, pp, flags)
	tags.append("cast:sigil:%d" % int(sigil["id"]))
	var hits := 0
	for handle in runner.enemies_in_radius(at, r):
		runner.damage_enemy(handle, damage, tags)
		hits += 1
	runner.note_impact_fx(at, r)
	return hits


## One pulse: an impact of the Sigil's radius (Roaming: a 2R cone toward
## the nearest enemy). Returns distinct enemies hit.
func pulse(sigil: Dictionary, chain: int = 0, v_rooted: bool = false) -> int:
	counters["pulses"] = int(counters["pulses"]) + 1
	sigil["pulsed"] = int(sigil["pulsed"]) + 1
	var flags := PackedStringArray()
	if has("INK1"):
		flags.append("core_strike")
	if v_rooted or host_left > 0.0:
		flags.append("v")
	var pp := float(sigil["pp"]) * (0.5 if bool(sigil["copy"]) else 1.0)
	if bool(sigil["copy"]):
		pp = 0.2
	var damage := sigil_damage(sigil)
	var hits := 0
	if has("INF1") and int(sigil["parent"]) == 0 and not bool(sigil["copy"]):
		var nearest := runner.nearest_enemy(sigil["at"], 3.0 * AscensionRunner.R)
		var dir := ((runner.enemy_position(nearest) - (sigil["at"] as Vector2)).normalized() if nearest != 0 else Vector2.RIGHT)
		var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "IN01", "pulse", 1, pp, flags)
		tags.append("cast:sigil:%d" % int(sigil["id"]))
		var out: Array[int] = []
		var ts := PackedFloat32Array()
		hits = EnemyCombat.enemies_on_segment(sigil["at"], (sigil["at"] as Vector2) + dir * 2.0 * AscensionRunner.R, sigil_radius(sigil) * 0.5, 0, out, ts)
		for i in range(hits):
			runner.damage_enemy(out[i], damage, tags)
		runner.note_line_fx(sigil["at"], (sigil["at"] as Vector2) + dir * 2.0 * AscensionRunner.R, sigil_radius(sigil) * 0.5)
	else:
		hits = _impact(sigil, damage, "IN01", pp, flags)
	counters["pulse_hits"] = int(counters["pulse_hits"]) + hits
	sigil["stretch"] = Vector2.ZERO
	if has("IN10") and hits >= 6:
		_chain_pulse(sigil, chain)
	if has("INE2") and _web_left > 0.0:
		_web_travel(sigil, chain)
	if not _band.is_empty() and (_band["members"] as Array).has(int(sigil["id"])):
		_band_wave(sigil)
	return hits


func _chain_pulse(sigil: Dictionary, chain: int) -> void:
	if chain == 0:
		_serial += 1
		chain = _serial
		sigil["chain"] = chain
	if has("INC") and _choir_recovery <= 0.0 and _grown_count() >= 3:
		_choir(false)
		return
	var nearest: Dictionary = {}
	var best := INF
	for other in sigils:
		if other == sigil or int(other.get("chain", 0)) == chain:
			continue
		if int(other["parent"]) != 0 and not has("INF2"):
			continue
		var d := (sigil["at"] as Vector2).distance_squared_to(other["at"])
		if d < best:
			best = d
			nearest = other
	if nearest.is_empty():
		return
	nearest["chain"] = chain
	nearest["pulse"] = PULSE_INTERVAL
	counters["chain_pulses"] = int(counters["chain_pulses"]) + 1
	pulse(nearest, chain)


func _grown_count() -> int:
	var count := 0
	for sigil in sigils:
		if bool(sigil["grown"]) and not bool(sigil["copy"]):
			count += 1
	return count


func _detonate(sigil: Dictionary, destroyed: bool) -> void:
	counters["detonations"] = int(counters["detonations"]) + 1
	var damage := 1.5 * D() + 0.3 * D() * float(sigil["growth"])
	_impact(sigil, damage, "IN09", 0.5)
	if not destroyed:
		sigil["growth"] = maxf(0.0, float(sigil["growth"]) - 3.0)
		sigil["detonated_path"] = true
	_release_echoes(sigil)


# ---------------------------------------------------------------- echoes

func _store_echo(sigil: Dictionary, echo: Dictionary) -> bool:
	if int(sigil["echo_slots"]) <= 0:
		return false
	var echoes: Array = sigil["echoes"]
	if echoes.size() >= int(sigil["echo_slots"]):
		var oldest: Dictionary = echoes.pop_front()
		_release_echo(sigil, oldest)
	if float(sigil["next_echo_bonus"]) > 0.0:
		echo["damage"] = float(echo["damage"]) + float(sigil["next_echo_bonus"])
		sigil["next_echo_bonus"] = 0.0
	echoes.append(echo)
	counters["echoes_stored"] = int(counters["echoes_stored"]) + 1
	return true


func _release_echoes(sigil: Dictionary) -> void:
	var echoes: Array = sigil["echoes"]
	sigil["echoes"] = []
	for echo in echoes:
		_release_echo(sigil, echo)


func _release_echo(sigil: Dictionary, echo: Dictionary) -> void:
	counters["echoes_released"] = int(counters["echoes_released"]) + 1
	var at: Vector2 = sigil["at"]
	var target := runner.nearest_enemy(at, 2.0 * AscensionRunner.L)
	var aim := runner.enemy_position(target) if target != 0 else (at + (echo["target"] as Vector2) - (echo["origin"] as Vector2))
	var flags := PackedStringArray()
	if host_left > 0.0:
		flags.append("v")
	var tags := AscensionTags.make(String(echo["core"]), AscensionTags.FAMILY_TREE, String(echo.get("root", "IN06")), "echo", 2, float(echo["pp"]), flags)
	tags.append("cast:sigil:%d" % int(sigil["id"]))
	runner._emit_strike(String(echo["core"]), at, aim, float(echo["damage"]), tags)
	if target != 0:
		runner.add_action_charge(1.0)


func _new_echo(core: String, origin: Vector2, target: Vector2, damage: float, pp: float, root: String = "IN06") -> Dictionary:
	return {"core": core, "origin": origin, "target": target, "damage": damage, "pp": pp, "root": root}


# ---------------------------------------------------------------- growth

func add_growth(sigil: Dictionary, amount: float, from_kill: bool = true) -> void:
	if amount <= 0.0 or bool(sigil["copy"]):
		return
	if has("INF1") and from_kill:
		amount *= 0.75
	var before := float(sigil["growth"])
	if before >= GROWTH_MAX:
		if has("IN09") and not bool(sigil["detonated_path"]):
			_detonate(sigil, false)
		return
	sigil["growth"] = minf(GROWTH_MAX, before + amount)
	sigil["grown"] = true
	counters["growth"] = float(counters["growth"]) + amount
	_growth_bank += amount
	while _growth_bank >= 1.0:
		_growth_bank -= 1.0
		runner.add_action_charge(1.0)
	if floor(float(sigil["growth"])) > floor(before):
		sigil["detonated_path"] = false
	if has("IN11") and float(sigil["growth"]) >= GROWTH_MAX and int(sigil["parent"]) == 0:
		_spawn_children(sigil)


func _spawn_children(parent: Dictionary) -> void:
	var wanted := 2 if has("INF2") else 1
	var living := 0
	for child_id in parent["children"]:
		if not _find(int(child_id)).is_empty():
			living += 1
	if living >= wanted:
		return
	var at: Vector2 = parent["at"]
	var cluster := runner.nearest_enemy(at, 3.0 * AscensionRunner.L)
	var dir := (runner.enemy_position(cluster) - at).normalized() if cluster != 0 else Vector2.RIGHT
	for i in range(wanted - living):
		if _slots_used() + 1 > capacity():
			break
		var child := _make_sigil(at + dir.rotated(deg_to_rad(30.0 * float(i))) * 1.5 * AscensionRunner.R, "child")
		child["parent"] = int(parent["id"])
		if has("INF2"):
			child["growth"] = float(parent["growth"])
		sigils.append(child)
		(parent["children"] as Array).append(int(child["id"]))
		counters["children"] = int(counters["children"]) + 1


func _kill_growth(position: Vector2, amount: float) -> void:
	var near: Array = []
	for sigil in sigils:
		if bool(sigil["copy"]):
			continue
		if (sigil["at"] as Vector2).distance_to(position) <= 1.5 * AscensionRunner.R:
			near.append(sigil)
	if near.is_empty():
		return
	if has("IN04"):
		# Touching Sigils share the award among their least-grown members.
		var least: Dictionary = near[0]
		for sigil in near:
			if float(sigil["growth"]) < float(least["growth"]):
				least = sigil
		add_growth(least, amount)
	else:
		for sigil in near:
			add_growth(sigil, amount)


# ---------------------------------------------------------------- tick

func tick(delta: float) -> void:
	_clock += delta
	if _warm_cooldown > 0.0:
		_warm_cooldown = maxf(0.0, _warm_cooldown - delta)
	if _choir_recovery > 0.0:
		_choir_recovery = maxf(0.0, _choir_recovery - delta)
	if _web_left > 0.0:
		_web_left = maxf(0.0, _web_left - delta)
	_travel += runner.travel_this_frame
	if has("IN02") and _travel >= AscensionRunner.L:
		_stretch_armed = true
	var player_pos := runner.player_position()
	var inside := _containing(player_pos)
	var speed_scale := 3.0 if host_left > 0.0 else 1.0
	for i in range(sigils.size() - 1, -1, -1):
		var sigil: Dictionary = sigils[i]
		_move_sigil(sigil, delta, player_pos)
		if has("IN03") and inside.has(sigil) and float(sigil["growth"]) > 0.0:
			sigil["growth"] = maxf(0.0, float(sigil["growth"]) - delta)
			counters["endure_seconds"] = float(counters["endure_seconds"]) + delta
		else:
			sigil["life"] = float(sigil["life"]) - delta
		sigil["pulse"] = float(sigil["pulse"]) - delta * speed_scale
		var guard := 0
		while float(sigil["pulse"]) <= 0.0 and guard < 6 and sigils.has(sigil):
			guard += 1
			sigil["pulse"] = float(sigil["pulse"]) + PULSE_INTERVAL
			sigil["chain"] = 0
			if float(sigil["damage"]) > 0.0 or float(sigil["growth"]) > 0.0:
				pulse(sigil)
		if float(sigil["life"]) <= 0.0:
			_expire(sigil)
	_tick_home_touches()
	_tick_consume(delta)
	_tick_host(delta)
	_tick_band(delta)


func _expire(sigil: Dictionary) -> void:
	sigils.erase(sigil)
	_release_echoes(sigil)
	for child_id in sigil["children"]:
		var child := _find(int(child_id))
		if not child.is_empty():
			child["parent"] = 0


func _move_sigil(sigil: Dictionary, delta: float, player_pos: Vector2) -> void:
	var at: Vector2 = sigil["at"]
	if host_left > 0.0 and has("INV2"):
		var cursor := runner.aim_target()
		var step := AscensionRunner.L * delta
		if bool(sigil["copy"]):
			sigil["at"] = at + (at - cursor).normalized() * step
		else:
			sigil["at"] = at.move_toward(cursor, step)
		return
	if bool(sigil["follow_cursor"]):
		var cursor := runner.aim_target()
		if cursor.distance_to(player_pos) > 3.0 * AscensionRunner.L:
			cursor = player_pos + (cursor - player_pos).normalized() * 3.0 * AscensionRunner.L
		sigil["at"] = at.move_toward(cursor, AscensionRunner.L * delta)
		return
	if bool(sigil["home"]) and has("IN12"):
		var speed := (0.25 if has("INF2") else 0.5) * AscensionRunner.L
		if at.distance_to(player_pos) > AscensionRunner.R:
			sigil["at"] = at.move_toward(player_pos, speed * delta)
		return
	if has("INF1") and int(sigil["parent"]) == 0 and not bool(sigil["copy"]):
		var nearest := runner.nearest_enemy(at, 3.0 * AscensionRunner.L)
		if nearest != 0:
			sigil["at"] = at.move_toward(runner.enemy_position(nearest), 0.7 * AscensionRunner.L * delta)


func _tick_home_touches() -> void:
	if not has("IN12"):
		return
	for sigil in sigils:
		if not bool(sigil["home"]):
			continue
		for other in sigils:
			if other == sigil or not _touching(sigil, other):
				continue
			var key := "%d:%d" % [mini(int(sigil["id"]), int(other["id"])), maxi(int(sigil["id"]), int(other["id"]))]
			if _clock - float(_pair_cooldowns.get(key, -INF)) < 1.0:
				continue
			_pair_cooldowns[key] = _clock
			counters["home_touches"] = int(counters["home_touches"]) + 1
			pulse(sigil)
			pulse(other)
			_exchange_echo(sigil, other)


func _exchange_echo(a: Dictionary, b: Dictionary) -> void:
	var from := a if (a["echoes"] as Array).size() >= (b["echoes"] as Array).size() else b
	var to := b if from == a else a
	if (from["echoes"] as Array).is_empty() or (to["echoes"] as Array).size() >= int(to["echo_slots"]):
		return
	(to["echoes"] as Array).append((from["echoes"] as Array).pop_back())


# ---------------------------------------------------------------- native strikes

func decorate_native_impact(impact: Node) -> void:
	impact.set_meta(AscensionTags.META_KEY, AscensionTags.with_flag(impact.get_meta(AscensionTags.META_KEY, PackedStringArray()), "core_strike"))


func modify_outgoing_damage(preview: Dictionary, raw: float) -> float:
	if has("INK1") and preview["core"] == "magic" and preview["family"] == AscensionTags.FAMILY_NATIVE:
		return raw * 0.75
	return raw


func on_native_fire(style: String, origin: Vector2, target: Vector2, _power: float, _haste: float) -> void:
	_volley += 1
	_last_strike = {"core": style, "origin": origin, "target": target}
	var inside := player_inside()
	if style == "magic":
		if has("INK2") and _placed_volley != _volley and runner.player_hp() > 0.25 * runner.player_max_hp():
			runner.pay_health(0.03 * runner.player_hp(), &"blood_rune")
			var sigil := place_sigil(target, "plain", 2.0)
			sigil["blood"] = true
			sigil["grown"] = true
			_placed_volley = _volley
			counters["blood_sigils"] = int(counters["blood_sigils"]) + 1
		if has("IN02") and _stretch_armed:
			_stretch_armed = false
			_travel = 0.0
			if sigils.is_empty():
				place_sigil(target)
				_placed_volley = _volley
			else:
				var nearest := _nearest_sigil(target)
				var toward := (target - (nearest["at"] as Vector2)).limit_length(AscensionRunner.R)
				nearest["stretch"] = toward
				nearest["at"] = (nearest["at"] as Vector2) + toward
				counters["stretches"] = int(counters["stretches"]) + 1
				for other in sigils:
					if other != nearest and _touching(nearest, other):
						_exchange_echo(nearest, other)
						break
		if has("IN08"):
			for sigil in _containing(target):
				if int(_offbeat_volley.get(int(sigil["id"]), -1)) == _volley:
					continue
				_offbeat_volley[int(sigil["id"])] = _volley
				var distance := (sigil["at"] as Vector2).distance_to(target)
				var radius := sigil_radius(sigil)
				if distance >= radius * 2.0 / 3.0:
					sigil["pulse"] = maxf(0.0, float(sigil["pulse"]) - 0.4)
				elif distance <= radius / 3.0:
					sigil["pulse"] = minf(2.0, float(sigil["pulse"]) + 0.2)
					sigil["next_echo_bonus"] = 0.4 * D()
	# Echo Shrine (Magic) / Echo Chamber (any Core): store one Echo per activation.
	if (has("IN06") or has("IN07")) and _echo_volley != _volley and not inside.is_empty():
		var foreign := style != "magic"
		if not foreign or has("INA"):
			var least: Dictionary = inside[0]
			for sigil in inside:
				if (sigil["echoes"] as Array).size() < (least["echoes"] as Array).size():
					least = sigil
			var echo := _new_echo(style, origin, target, ECHO_D * D(), ECHO_PP) if not foreign else _new_echo(style, origin, target, 0.6 * runner.native_damage_for(style), 0.4, "INA")
			if _store_echo(least, echo):
				_echo_volley = _volley


func _nearest_sigil(point: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for sigil in sigils:
		var d := (sigil["at"] as Vector2).distance_squared_to(point)
		if d < best_d:
			best_d = d
			best = sigil
	return best


func on_hit(hit: Dictionary) -> void:
	var tags: PackedStringArray = hit["tags"]
	if hit["core"] != "magic" or not AscensionTags.has_flag(tags, "core_strike"):
		return
	if hit["family"] == AscensionTags.FAMILY_TREE and not has("INK1"):
		return
	if hit["root"] == "IN01" and not has("INK1"):
		return
	if has("IN01"):
		_hits += float(hit["pp"])
		if _hits >= 4.0 - 0.0005 and _placed_volley != _volley:
			_hits -= 4.0
			_placed_volley = _volley
			place_sigil(hit["position"])


func on_kill(hit: Dictionary, _context: RefCounted) -> void:
	if not has("IN05"):
		return
	var generated: bool = hit["family"] == AscensionTags.FAMILY_TREE
	_kill_growth(hit["position"], 0.5 if generated else 1.0)


# ---------------------------------------------------------------- Warm Circle

func damage_taken_multiplier_for(_source: Node, _kind: StringName) -> float:
	if not has("IN07") or _warm_cooldown > 0.0:
		return 1.0
	for sigil in player_inside():
		if float(sigil["growth"]) >= 1.0:
			_warm_pending = true
			return 0.65
	return 1.0


func on_player_damage_resolved(_source: Node, _raw: float, _applied: float, _kind: StringName) -> void:
	if not _warm_pending:
		return
	_warm_pending = false
	for sigil in player_inside():
		if float(sigil["growth"]) >= 1.0:
			sigil["growth"] = float(sigil["growth"]) - 1.0
			_warm_cooldown = 2.0
			counters["warm_circles"] = int(counters["warm_circles"]) + 1
			var strike := _last_strike if not _last_strike.is_empty() else {"core": "magic", "origin": runner.player_position(), "target": runner.aim_target()}
			_store_echo(sigil, _new_echo(String(strike["core"]), strike["origin"], strike["target"], 0.8 * D(), ECHO_PP, "IN07"))
			return


func heal_multiplier() -> float:
	if has("INK2"):
		for sigil in sigils:
			if bool(sigil["blood"]):
				return 0.75
	return 1.0


# ---------------------------------------------------------------- Consecrate (Q)

func activate_q(id: String) -> Dictionary:
	if id != "INQ":
		return {"ok": false, "message": "NOT INVOCATION", "cooldown": 0.0}
	counters["consecrates"] = int(counters["consecrates"]) + 1
	var origin := runner.player_position()
	var at := runner.auto_aim_for("INQ") if runner.automatic_cast else runner.aim_target()
	if at.distance_to(origin) > 3.0 * AscensionRunner.L:
		at = origin + (at - origin).normalized() * 3.0 * AscensionRunner.L
	if has("INQ5"):
		_consume_network(at)
	var placed: Array = []
	if has("INQ4"):
		for i in range(3):
			placed.append(place_sigil(at + Vector2.from_angle(TAU * float(i) / 3.0 - PI / 2.0) * 0.8 * AscensionRunner.R, "swarm"))
	else:
		placed.append(place_sigil(at, "great" if has("INQ1") else "plain"))
	for sigil in placed:
		if has("INQ3") or (has("INF1") and not runner.automatic_cast):
			sigil["follow_cursor"] = true
	if has("INE1"):
		_band = {"left": 6.0, "members": placed.map(func(s): return int(s["id"])), "angle": 0.0}
	if has("INE2"):
		_web_left = 4.0
	var commanded: Array = sigils.duplicate()
	for sigil in commanded:
		if sigils.has(sigil):
			sigil["pulse"] = PULSE_INTERVAL
			pulse(sigil)
	if has("INQ6"):
		_resonance(commanded)
	if has("INQ2"):
		for sigil in commanded:
			if sigils.has(sigil):
				_release_echoes(sigil)
	return {"ok": true, "message": "CONSECRATE", "cooldown": 7.0}


func auto_target(_id: String) -> Vector2:
	var origin := runner.player_position()
	var best := origin + Vector2(AscensionRunner.R, 0)
	var best_count := -1
	for handle in runner.enemies_in_radius(origin, 3.0 * AscensionRunner.L):
		var at := runner.enemy_position(handle)
		var count := runner.enemies_in_radius(at, AscensionRunner.R).size()
		if count > best_count:
			best_count = count
			best = at
	return best


func _resonance(commanded: Array) -> void:
	var out: Array[int] = []
	var ts := PackedFloat32Array()
	for i in range(commanded.size()):
		for j in range(i + 1, commanded.size()):
			var a: Vector2 = commanded[i]["at"]
			var b: Vector2 = commanded[j]["at"]
			var count := EnemyCombat.enemies_on_segment(a, b, 12.0, 0, out, ts)
			var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "INQ6", "line", 2, 0.25)
			for k in range(count):
				runner.damage_enemy(out[k], 0.5 * D(), tags)
			runner.note_line_fx(a, b, 12.0)
			counters["resonance_lines"] = int(counters["resonance_lines"]) + 1


func _consume_network(at: Vector2) -> void:
	var old: Array = sigils.duplicate()
	for sigil in old:
		if bool(sigil["copy"]):
			continue
		var pulses := int(floor(float(sigil["life"]) / PULSE_INTERVAL))
		_consume_queue.append({"at": at, "pulses": pulses, "tick": 0.0, "interval": 1.0 / float(maxi(1, pulses)), "damage": sigil_damage(sigil), "radius": sigil_radius(sigil), "pp": float(sigil["pp"]), "echoes": sigil["echoes"], "id": int(sigil["id"])})
		sigil["echoes"] = []
		sigils.erase(sigil)
		counters["consumed"] = int(counters["consumed"]) + 1
		if has("IN09"):
			_detonate(sigil, true)


func _tick_consume(delta: float) -> void:
	if _consume_queue.is_empty():
		return
	for i in range(_consume_queue.size() - 1, -1, -1):
		var entry: Dictionary = _consume_queue[i]
		entry["tick"] = float(entry["tick"]) + delta
		while int(entry["pulses"]) > 0 and float(entry["tick"]) >= float(entry["interval"]):
			entry["tick"] = float(entry["tick"]) - float(entry["interval"])
			entry["pulses"] = int(entry["pulses"]) - 1
			var ghost := {"id": int(entry["id"]), "at": entry["at"], "radius": float(entry["radius"]), "growth": 0.0}
			_impact({"id": int(entry["id"]), "at": entry["at"], "radius": float(entry["radius"]), "growth": 0.0, "copy": false}, float(entry["damage"]), "INQ5", float(entry["pp"]), PackedStringArray(), float(entry["radius"]))
			counters["pulses"] = int(counters["pulses"]) + 1
		if int(entry["pulses"]) <= 0:
			for echo in entry["echoes"]:
				_release_echo({"id": int(entry["id"]), "at": entry["at"]}, echo)
			_consume_queue.remove_at(i)


# ---------------------------------------------------------------- Choir, Web, Band

func _choir(bypass_recovery: bool) -> void:
	if not bypass_recovery:
		_choir_recovery = 8.0
	counters["choirs"] = int(counters["choirs"]) + 1
	runner.note_catastrophe("INC")
	var ordered: Array = sigils.duplicate()
	ordered.sort_custom(func(a, b): return float(a["created"]) < float(b["created"]))
	for sigil in ordered:
		sigil["detonated_choir"] = false
	var out: Array[int] = []
	var ts := PackedFloat32Array()
	for i in range(ordered.size()):
		var sigil: Dictionary = ordered[i]
		if not sigils.has(sigil):
			continue
		sigil["pulse"] = PULSE_INTERVAL
		pulse(sigil, -1, true)
		var echoes: Array = sigil["echoes"]
		if not echoes.is_empty():
			_release_echo(sigil, echoes.pop_front())
		if ordered.size() > 1:
			var next: Dictionary = ordered[(i + 1) % ordered.size()]
			var a: Vector2 = sigil["at"]
			var b: Vector2 = next["at"]
			var count := EnemyCombat.enemies_on_segment(a, b, 12.0, 0, out, ts)
			var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "INC", "line", 2, 0.4, PackedStringArray(["v"]) if host_left > 0.0 else PackedStringArray())
			var victims: Array[int] = []
			for k in range(count):
				victims.append(out[k])
			for handle in victims:
				runner.damage_enemy(handle, D(), tags)
				if has("INC") and not runner.enemy_alive(handle):
					_choir_line_kill(runner.enemy_position(handle))
			runner.note_line_fx(a, b, 12.0)
	if BattleText != null:
		BattleText.popup(runner.player_position(), "CHOIR", Color(0.8, 0.7, 1.0, 1.0), 1.6)


func _choir_line_kill(position: Vector2) -> void:
	var nearest: Dictionary = {}
	var best := INF
	for sigil in sigils:
		if bool(sigil["detonated_choir"]):
			continue
		var d := (sigil["at"] as Vector2).distance_squared_to(position)
		if d < best:
			best = d
			nearest = sigil
	if nearest.is_empty():
		return
	nearest["detonated_choir"] = true
	counters["choir_detonations"] = int(counters["choir_detonations"]) + 1
	_impact(nearest, 2.0 * D(), "INC", 0.4)


func _web_travel(sigil: Dictionary, chain: int) -> void:
	var others: Array = sigils.filter(func(s): return s != sigil)
	others.sort_custom(func(a, b): return (sigil["at"] as Vector2).distance_squared_to(a["at"]) < (sigil["at"] as Vector2).distance_squared_to(b["at"]))
	var out: Array[int] = []
	var ts := PackedFloat32Array()
	for i in range(mini(2, others.size())):
		var other: Dictionary = others[i]
		var key := "%d:%d:%d" % [chain, mini(int(sigil["id"]), int(other["id"])), maxi(int(sigil["id"]), int(other["id"]))]
		if chain != 0 and _pair_cooldowns.has(key):
			continue
		_pair_cooldowns[key] = _clock
		var count := EnemyCombat.enemies_on_segment(sigil["at"], other["at"], 12.0, 0, out, ts)
		var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "INE2", "line", 2, 0.4)
		for k in range(count):
			runner.damage_enemy(out[k], 0.5 * D(), tags)
		counters["web_edges"] = int(counters["web_edges"]) + 1
		runner.note_line_fx(sigil["at"], other["at"], 12.0)


func _tick_band(delta: float) -> void:
	if _band.is_empty():
		return
	_band["left"] = float(_band["left"]) - delta
	_band["angle"] = float(_band["angle"]) + delta
	var members: Array = _band["members"]
	var player_pos := runner.player_position()
	for i in range(members.size()):
		var sigil := _find(int(members[i]))
		if sigil.is_empty():
			continue
		sigil["follow_cursor"] = false
		sigil["at"] = player_pos + Vector2.from_angle(float(_band["angle"]) + TAU * float(i) / float(members.size())) * 1.2 * AscensionRunner.R
	if float(_band["left"]) <= 0.0:
		_band = {}


func _band_wave(sigil: Dictionary) -> void:
	var members: Array = _band["members"]
	var index := members.find(int(sigil["id"]))
	var next := _find(int(members[(index + 1) % members.size()]))
	if next.is_empty() or next == sigil:
		return
	var dir := ((next["at"] as Vector2) - (sigil["at"] as Vector2)).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	counters["band_waves"] = int(counters["band_waves"]) + 1
	runner.spawn_slash(sigil["at"], dir, 0.8 * D(), AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "INE1", "wave", 2, 0.4), 60.0, 2.0 * AscensionRunner.R)


# ---------------------------------------------------------------- THE HOST (V)

func activate_v(id: String) -> Dictionary:
	if id != "INV":
		return {"ok": false, "message": "NOT INVOCATION", "cooldown": 0.0}
	counters["hosts"] = int(counters["hosts"]) + 1
	var parents := _parents()
	if parents.size() < 3:
		var rect := runner.camera_rect()
		for i in range(3 - parents.size()):
			var x := rect.position.x + rect.size.x * (float(i) + 0.5) / 3.0
			var at := Vector2(x, rect.get_center().y)
			var nearest := runner.nearest_enemy(at, rect.size.x / 3.0)
			if nearest != 0:
				at = runner.enemy_position(nearest)
			var blank := _make_sigil(at, "blank")
			blank["copy"] = true
			blank["temp"] = true
			blank["damage"] = PULSE_D
			sigils.append(blank)
	host_left = 6.0
	if has("INV3"):
		_host_stored = sigils.duplicate()
		var combined := 0.0
		for sigil in _host_stored:
			combined += sigil_damage(sigil)
		sigils.clear()
		_one_voice = {"tick": 0.0, "damage": maxf(3.0 * D(), 0.6 * combined)}
	else:
		for sigil in sigils.duplicate():
			if bool(sigil.get("temp", false)):
				continue
			var copy: Dictionary = sigil.duplicate(true)
			_serial += 1
			copy["id"] = _serial
			copy["copy"] = true
			copy["children"] = []
			copy["echoes"] = []
			copy["at"] = (sigil["at"] as Vector2) + Vector2(AscensionRunner.R, 0)
			sigils.append(copy)
			_host_copies.append(int(copy["id"]))
			counters["host_copies"] = int(counters["host_copies"]) + 1
	if has("INV1"):
		_choir(true)
	return {"ok": true, "message": "THE HOST", "cooldown": 0.0}


func _tick_host(delta: float) -> void:
	if host_left <= 0.0:
		return
	host_left = maxf(0.0, host_left - delta)
	if not _one_voice.is_empty():
		_one_voice["tick"] = float(_one_voice["tick"]) + delta
		if float(_one_voice["tick"]) >= 1.0 or host_left <= 0.0:
			_one_voice["tick"] = 0.0
			var rect := runner.camera_rect()
			var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "INV3", "pulse", 1, 1.0, PackedStringArray(["v"]))
			for handle in runner.enemies_in_radius(rect.get_center(), rect.size.length() * 0.5):
				runner.damage_enemy(handle, float(_one_voice["damage"]), tags)
			runner.note_impact_fx(rect.get_center(), rect.size.length() * 0.5)
			counters["one_voice_pulses"] = int(counters["one_voice_pulses"]) + 1
	if host_left <= 0.0:
		_end_host()


func _end_host() -> void:
	if not _one_voice.is_empty():
		# Originals return first so the final pulse's Echo release sees them.
		for sigil in _host_stored:
			sigils.append(sigil)
			_release_echoes(sigil)
		_host_stored.clear()
		_one_voice = {}
	if has("INV1"):
		_choir(true)
	for id in _host_copies:
		var copy := _find(id)
		if not copy.is_empty():
			_release_echoes(copy)
			sigils.erase(copy)
	_host_copies.clear()
	for sigil in sigils.duplicate():
		if bool(sigil.get("temp", false)):
			_release_echoes(sigil)
			sigils.erase(sigil)
	runner.note_revelation_ended("INV")


# ---------------------------------------------------------------- HUD

func hud_state(slot: String) -> Dictionary:
	var state := {}
	if slot == "q":
		state["resource_value"] = float(_slots_used())
		state["resource_max"] = float(capacity())
		var echoes := 0
		for sigil in sigils:
			echoes += (sigil["echoes"] as Array).size()
		state["combat_text"] = "SIGILS %d/%d  ECHO %d" % [_slots_used(), capacity(), echoes]
	elif slot == "v" and host_left > 0.0:
		state["combat_text"] = "THE HOST %.1fs" % host_left
	return state


func collect_draw_points(out: Array) -> void:
	for sigil in sigils:
		var alpha := 0.35 if not bool(sigil["copy"]) else 0.2
		out.append([sigil["at"], sigil_radius(sigil), Color(0.7, 0.6, 1.0, alpha)])
		if float(sigil["growth"]) > 0.0 or not (sigil["echoes"] as Array).is_empty():
			out.append([sigil["at"], 3.0, Color(0.9, 0.85, 1.0, 0.9), "G%d E%d" % [int(sigil["growth"]), (sigil["echoes"] as Array).size()]])


func describe() -> Dictionary:
	var out := counters.duplicate()
	out["sigils"] = sigils.size()
	out["capacity"] = capacity()
	out["host_left"] = host_left
	return out
