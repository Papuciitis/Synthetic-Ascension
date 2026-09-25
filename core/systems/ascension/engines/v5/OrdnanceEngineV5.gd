extends OrdnanceEngine
class_name OrdnanceEngineV5
## Ranged V5 Ordnance (handoff 2026-09-25, spec §4): Grenadier replaces
## Caltrops, Sticky Follow-Up replaces Mine Toss, Running Barrage lobs
## grenades, Bandolier stores spares, Designate taps fire and holds place,
## and Big One counts only true Shells. Mines stay genuine objects for the
## hybrid producers (MR6, MR9, RM7, Q Proximity).

const GRENADE_FLIGHT := 0.35
const GRENADE_ATTACH_FUSE := 0.40
const GRENADE_GROUND_FUSE := 0.80
const GRENADE_D := 1.3
const GRENADE_PP := 0.5
const GRENADE_AIM_SEEK := 3.0 * AscensionRunner.R
const GRENADE_THROW_CLAMP := 2.0 * AscensionRunner.L
const STICKY_BONUS_D := 0.8
const RUN_RATE := 0.50
const RUN_BANK := 2.0 * AscensionRunner.L
const HOLD_CLASSIFY := 0.35
const TAP_TRACK_SECONDS := 0.6
const THUNDER_WINDOW := 8.0
const THUNDER_WINDOW_BLASTS := 24

## Grenade dicts: {pos, from, dest, victim, t, state (flight/attached/
## grounded), fuse, root, seq, guided, bonus, id}
var grenades: Array = []
var _grenade_serial: int = 0
var _grenadier_credits: float = 0.0
var _bandolier_credits: float = 0.0
var spare_grenades: int = 0
var _run_credit: float = 0.0
var _run_cooldown: float = 0.0
var _sticky_volley: int = -1
var _grenade_fuse_volley: int = -1
var _blast_window: Array[float] = []
var _q_hold_time: float = -1.0
var _tracked_sequences: Array = []


# ------------------------------------------------------------ V4 hooks off

## Grenadier drops no dash Mines; MR6/MR9/RM7/ORQ4 stay real Mine producers.
func _dash_mine_enabled() -> bool:
	return false


## Mine Toss's projectile push is gone; OR05 is Sticky Follow-Up now.
func _mine_toss_enabled() -> bool:
	return false


## Bandolier does not raise the ordinary Mine cap and replaced Coordinates
## fire nothing; the V4 Mine cap survives for genuine Mine producers.
func mine_cap() -> int:
	return 12


func _magazine_replaces_with_shell() -> bool:
	return false


func _fuse_threshold() -> float:
	return [4.0, 3.0, 2.0][clampi(rank("OR01"), 1, 3) - 1]


func _scan_shell_count() -> int:
	return [3, 4, 5][clampi(rank("OR11"), 1, 3) - 1]


func _big_one_interval() -> int:
	return [7, 6, 5][clampi(rank("OR12"), 1, 3) - 1]


func _fracture_arm_interval() -> int:
	return 3 if rank("OR08") <= 1 else 2


func _shrapnel_count() -> int:
	return 5 if rank("OR08") >= 3 else 3


## Chain Reaction V5: any resolved blast (a Shell's impact included) may
## detonate armed Mines, traps, attached and grounded grenades whose radii
## touch. Falling Shells never chain mid-air. Each object leaves the armed
## graph before its own blast resolves.
func _maybe_chain(at: Vector2, radius: float, seq: int, _is_shell: bool) -> void:
	if not has("OR06"):
		return
	_chain_reaction(at, radius, seq)
	var touched: Array = []
	for grenade in grenades:
		var state := String(grenade["state"])
		if state == "flight":
			continue
		if (grenade["pos"] as Vector2).distance_to(at) <= radius:
			touched.append(grenade)
	for grenade in touched:
		grenades.erase(grenade)
		counters["chain"] = int(counters["chain"]) + 1
		grenade["seq"] = seq
		_resolve_grenade_blast(grenade)


## Running Barrage V5: rank-based real travel lobs grenades at the enemy
## nearest the aim region; the V4 Shell-behind-the-player rule is gone.
## Distance handling is in _track_travel below; this hook is neutralized.
func _walking_trigger() -> void:
	pass


func _track_travel(delta: float) -> void:
	super._track_travel(delta)
	if _run_cooldown > 0.0:
		_run_cooldown = maxf(0.0, _run_cooldown - delta)
	if not has("OR09"):
		return
	# Real travel only: super advanced _travel_credit from travel_this_frame,
	# which excludes enemy-forced displacement (the runner tracks the body's
	# own movement; forced moves go through move_enemy_to on enemies, and
	# player knockback is not credited as travel here).
	_run_credit = minf(_run_credit + runner.travel_this_frame, RUN_BANK)
	var need := _run_distance()
	if _run_credit >= need and _run_cooldown <= 0.0:
		_run_credit -= need
		_run_cooldown = RUN_RATE
		counters["walking"] = int(counters["walking"]) + 1
		_launch_grenades(2 if rank("OR09") >= 3 else 1, "OR09")


func _run_distance() -> float:
	return 0.75 * AscensionRunner.L if rank("OR09") == 2 else AscensionRunner.L


# ------------------------------------------------------------ credits

func _grenadier_threshold() -> float:
	return [4.0, 3.0, 3.0, 2.0][clampi(rank("OR02"), 1, 4) - 1]


func _grenades_per_launch() -> int:
	return 2 if rank("OR02") >= 3 else 1


func _bandolier_threshold() -> float:
	return [6.0, 5.0, 4.0][clampi(rank("OR10"), 1, 3) - 1]


func _bandolier_cap() -> int:
	return [3, 5, 7][clampi(rank("OR10"), 1, 3) - 1]


## One credit per real native input, 0.6 per real Witness shot, 0 for
## generated payloads. At most one grouped launch per actual activation.
func _add_activation_credit(weight: float) -> void:
	if has("OR02"):
		_grenadier_credits += weight
		var threshold := _grenadier_threshold()
		if _grenadier_credits >= threshold:
			_grenadier_credits -= threshold
			# Bank overflow, never emit twice for one activation.
			_grenadier_credits = minf(_grenadier_credits, threshold)
			_launch_grenades(_grenades_per_launch(), "OR02")
	if has("OR10") and (has("OR02") or has("OR09")):
		_bandolier_credits += weight
		var store := _bandolier_threshold()
		if _bandolier_credits >= store:
			_bandolier_credits -= store
			if spare_grenades < _bandolier_cap():
				spare_grenades += 1
				counters["bandolier_stored"] = int(counters.get("bandolier_stored", 0)) + 1


func on_native_fire(style: String, origin: Vector2, target: Vector2, power: float, haste: float) -> void:
	super.on_native_fire(style, origin, target, power, haste)
	if style == "ranged":
		_add_activation_credit(1.0)


func on_witness_strike(core: String, _origin: Vector2, _target: Vector2) -> void:
	if core == "ranged":
		_add_activation_credit(0.6)


# ------------------------------------------------------------ grenades

func _launch_grenades(count: int, root: String) -> void:
	_seq_serial += 1
	var seq := _seq_serial
	# Bandolier: at most one stored spare joins an actual producer launch.
	if spare_grenades > 0 and has("OR10"):
		spare_grenades -= 1
		count += 1
		counters["bandolier_spent"] = int(counters.get("bandolier_spent", 0)) + 1
	var aim := runner.aim_target()
	var chosen: Array[int] = []
	for i in range(count):
		var victim := _pick_grenade_target(aim, chosen)
		if victim != 0:
			chosen.append(victim)
		var dest := runner.enemy_position(victim) if victim != 0 else _clamped_throw(aim)
		if victim == 0 and not chosen.is_empty():
			dest += Vector2.from_angle(runner.rng().randf_range(0.0, TAU)) * AscensionRunner.R * 0.5
		_grenade_serial += 1
		grenades.append({
			"id": _grenade_serial, "pos": runner.player_position(), "from": runner.player_position(),
			"dest": dest, "victim": victim, "t": 0.0, "state": "flight",
			"fuse": 0.0, "root": root, "seq": seq, "bonus": 0.0,
			"guided": has("ORF2") and victim != 0 and victim == _guided and _clock < _guided_until,
		})
		counters["grenades"] = int(counters.get("grenades", 0)) + 1


## Nearest living enemy within 3R of the aim point; Guidance prefers the
## tagged elite/boss; grenades in one volley prefer different targets.
func _pick_grenade_target(aim: Vector2, taken: Array[int]) -> int:
	if has("ORF2") and _guided != 0 and _clock < _guided_until and runner.enemy_alive(_guided) and not taken.has(_guided):
		return _guided
	var best := 0
	var best_d := INF
	var fallback := 0
	var fallback_d := INF
	for handle in runner.enemies_in_radius(aim, GRENADE_AIM_SEEK):
		if not runner.enemy_alive(handle):
			continue
		var d := aim.distance_squared_to(runner.enemy_position(handle))
		if not taken.has(handle) and d < best_d:
			best_d = d
			best = handle
		if d < fallback_d:
			fallback_d = d
			fallback = handle
	return best if best != 0 else fallback


func _clamped_throw(aim: Vector2) -> Vector2:
	var origin := runner.player_position()
	return origin + (aim - origin).limit_length(GRENADE_THROW_CLAMP)


func tick(delta: float) -> void:
	# ORQ5 tap tracking: the sequence's impact region follows the aim for
	# its first 0.6 s, then fixes.
	for entry in _tracked_sequences.duplicate():
		if not _sequences.has(entry["seq_ref"]):
			_tracked_sequences.erase(entry)
			continue
		if _clock >= float(entry["until"]):
			_tracked_sequences.erase(entry)
			continue
		(entry["seq_ref"] as Dictionary)["at"] = runner.aim_target()
	super.tick(delta)
	_tick_grenades(delta)
	while not _blast_window.is_empty() and _clock - _blast_window[0] > THUNDER_WINDOW:
		_blast_window.remove_at(0)


func _tick_grenades(delta: float) -> void:
	if grenades.is_empty():
		return
	var invocation: InvocationEngine = runner.engine_of_discipline("IN") as InvocationEngine if has("RM7") else null
	for i in range(grenades.size() - 1, -1, -1):
		if i >= grenades.size():
			# A chain detonation inside this loop erased other grenades.
			continue
		var grenade: Dictionary = grenades[i]
		match String(grenade["state"]):
			"flight":
				grenade["t"] = float(grenade["t"]) + delta
				var victim := int(grenade["victim"])
				if victim != 0 and runner.enemy_alive(victim):
					grenade["dest"] = runner.enemy_position(victim)
				elif victim != 0:
					grenade["victim"] = 0
				var progress: float = clampf(float(grenade["t"]) / GRENADE_FLIGHT, 0.0, 1.0)
				grenade["pos"] = (grenade["from"] as Vector2).lerp(grenade["dest"], progress)
				# Rune Bomb: a travelling grenade crossing a friendly Sigil
				# becomes one genuine Sigil-attached Mine (never both).
				if invocation != null and _convert_at_sigil(grenade, invocation):
					grenades.erase(grenade)
					continue
				if progress >= 1.0:
					victim = int(grenade["victim"])
					if victim != 0 and runner.enemy_alive(victim):
						grenade["state"] = "attached"
						grenade["fuse"] = GRENADE_ATTACH_FUSE
						counters["grenades_attached"] = int(counters.get("grenades_attached", 0)) + 1
					else:
						grenade["state"] = "grounded"
						grenade["fuse"] = GRENADE_GROUND_FUSE
						counters["grenades_grounded"] = int(counters.get("grenades_grounded", 0)) + 1
			"attached":
				var victim := int(grenade["victim"])
				if runner.enemy_alive(victim):
					grenade["pos"] = runner.enemy_position(victim)
				else:
					# Target loss: the grenade drops where the victim fell,
					# keeping its remaining fuse (implementation default).
					grenade["state"] = "grounded"
					grenade["victim"] = 0
					grenade["fuse"] = maxf(float(grenade["fuse"]), 0.10)
					continue
				grenade["fuse"] = float(grenade["fuse"]) - delta
				if float(grenade["fuse"]) <= 0.0:
					grenades.erase(grenade)
					_resolve_grenade_blast(grenade)
			"grounded":
				grenade["fuse"] = float(grenade["fuse"]) - delta
				if float(grenade["fuse"]) <= 0.0:
					grenades.erase(grenade)
					_resolve_grenade_blast(grenade)


func _convert_at_sigil(grenade: Dictionary, invocation: InvocationEngine) -> bool:
	for sigil in invocation.sigils:
		if int(sigil.get("mines", 0)) >= 3:
			continue
		var sigil_at: Vector2 = sigil["at"]
		var sigil_radius := invocation.sigil_radius(sigil)
		if sigil_at.distance_to(grenade["pos"]) <= sigil_radius:
			var rim := sigil_at + (grenade["pos"] as Vector2 - sigil_at).normalized() * sigil_radius * 0.9
			var mine := drop_mine(rim, MINE_D, "RM7", int(grenade["seq"]))
			mine["sigil"] = int(sigil["id"])
			sigil["mines"] = int(sigil.get("mines", 0)) + 1
			counters["rune_bombs"] = int(counters.get("rune_bombs", 0)) + 1
			return true
	return false


## One detonation per explosive: the caller has already removed it from the
## armed list. Splash is evaluated at the actual detonation position.
func _resolve_grenade_blast(grenade: Dictionary) -> void:
	if bool(grenade.get("detonated", false)):
		return
	grenade["detonated"] = true
	counters["grenade_blasts"] = int(counters.get("grenade_blasts", 0)) + 1
	var damage := (GRENADE_D * D() + float(grenade["bonus"]))
	if bool(grenade.get("guided", false)) and int(grenade["victim"]) == _guided:
		damage *= 1.3
	_blast_with_path(grenade["pos"], damage, AscensionRunner.R, String(grenade["root"]), GRENADE_PP, PackedStringArray(), int(grenade["seq"]), "grenade")


## The V4 _blast with an explicit payload path ("grenade"), so telemetry,
## OR04 and Chain Reaction see the correct silhouette class.
func _blast_with_path(at: Vector2, damage: float, radius: float, root: String, pp: float, flags: PackedStringArray, seq: int, path: String) -> void:
	_blast_serial += 1
	var tags := AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, root, path, 1, pp, flags)
	tags.append("flag:auto")
	tags.append("cast:blast:%d" % _blast_serial)
	var scaled_radius := radius * _blast_radius_scale()
	_blasts[_blast_serial] = {"at": at, "radius": scaled_radius, "hits": 0, "seq": seq, "shell": false, "automatic": true, "root": root, "kills": 0}
	_note_owned_blast(root)
	_seq_blasts[seq] = int(_seq_blasts.get(seq, 0)) + 1
	if has("ORC") and int(_seq_blasts[seq]) >= 12 and _thunder_recovery <= 0.0:
		_rolling_thunder()
	runner.spawn_impact(at, damage * _blast_damage_scale(false, true), tags, scaled_radius)
	if has("ORK2") and runner.player_position().distance_to(at) <= scaled_radius and _clock - _self_hit_at >= 0.25:
		_self_hit_at = _clock
		counters["self_hits"] = int(counters["self_hits"]) + 1
		runner.player().call("_take_damage", 0.03 * runner.player_max_hp(), null, &"self_damage")
	_maybe_chain(at, scaled_radius, seq, false)
	if _blasts.size() > 64:
		_blasts.erase(_blasts.keys()[0])


## Rolling Thunder's second route: 24 distinct owned ordinary-OR blast
## activations across a rolling 8 s window; ORC/ORV output never counts.
func _note_owned_blast(root: String) -> void:
	if not has("ORC") or root == "ORC" or root == "ORV":
		return
	_blast_window.append(_clock)
	if _blast_window.size() >= THUNDER_WINDOW_BLASTS and _thunder_recovery <= 0.0:
		_blast_window.clear()
		_rolling_thunder()


# ------------------------------------------------------------ hits

func on_hit(hit: Dictionary) -> void:
	super.on_hit(hit)
	var handle := int(hit["handle"])
	var core_strike: bool = hit["core"] == "ranged" and AscensionTags.has_flag(hit["tags"], "core_strike")
	if not core_strike:
		return
	# Sticky Follow-Up: one boosted detonation per initiating activation,
	# choosing the oldest attached grenade; further stickies keep timers.
	if has("OR05") and _sticky_volley != _volley:
		var oldest: Dictionary = {}
		for grenade in grenades:
			if String(grenade["state"]) == "attached" and int(grenade["victim"]) == handle:
				oldest = grenade
				break
		if not oldest.is_empty():
			_sticky_volley = _volley
			grenades.erase(oldest)
			oldest["bonus"] = float(oldest["bonus"]) + STICKY_BONUS_D * D()
			counters["stickies"] = int(counters.get("stickies", 0)) + 1
			_resolve_grenade_blast(oldest)
			return
	# Short Fuse extension: hitting a victim carrying an attached grenade
	# advances its fuse 0.15 s per qualified strike, floor 0.10 s.
	if has("OR03") and _grenade_fuse_volley != _volley:
		for grenade in grenades:
			if String(grenade["state"]) == "attached" and int(grenade["victim"]) == handle:
				grenade["fuse"] = maxf(0.10, float(grenade["fuse"]) - 0.15)
				_grenade_fuse_volley = _volley
				counters["short_fuses"] = int(counters["short_fuses"]) + 1
				break


## Every Shell/Mine blast also feeds the rolling ORC window.
func _blast(at: Vector2, damage: float, radius: float, root: String, pp: float, flags: PackedStringArray, seq: int, is_shell: bool, automatic: bool) -> void:
	_note_owned_blast(root)
	super._blast(at, damage, radius, root, pp, flags, seq, is_shell, automatic)


# ------------------------------------------------------------ Designate Q

## Tap fires immediately at the cursor; holding 0.35 s enters placement and
## commits on release. Nothing fires before the hold is classified. Presses
## reach the engine during the fire cooldown so placement stays available.
func q_press_during_cooldown(id: String) -> bool:
	return id == "ORQ" and not runner.automatic_cast and not runner.reaction_cast


func activate_q(id: String) -> Dictionary:
	if id != "ORQ":
		return {"ok": false, "message": "NOT ORDNANCE", "cooldown": 0.0}
	if runner.automatic_cast or runner.reaction_cast:
		# Automation taps at the densest point (instant Designate).
		if runner.q_cooldown_left > 0.0:
			return {"ok": false, "message": "COOLING", "cooldown": runner.q_cooldown_left}
		return _instant_designate(_densest_point(runner.player_position(), 3.0 * AscensionRunner.L))
	_q_hold_time = 0.0
	return {"ok": true, "message": "…", "cooldown": runner.q_cooldown_left}


func hold_q(_id: String, delta: float) -> void:
	if _q_hold_time >= 0.0:
		_q_hold_time += delta


func release_q(id: String) -> Dictionary:
	if id != "ORQ" or _q_hold_time < 0.0:
		return {"ok": false, "message": "", "cooldown": runner.q_cooldown_left}
	var held := _q_hold_time
	_q_hold_time = -1.0
	if held >= HOLD_CLASSIFY:
		# Placement: never consumes the fire cooldown; 0.25 s recovery.
		place_coordinate(runner.aim_target())
		return {"ok": true, "message": "COORDINATE", "cooldown": maxf(runner.q_cooldown_left, 0.25)}
	# Tap: fire a hovered Coordinate, else the instant sequence at the cursor.
	if runner.q_cooldown_left > 0.0:
		return {"ok": false, "message": "COOLING", "cooldown": runner.q_cooldown_left}
	var aim := runner.aim_target()
	var index := _coordinate_at(aim)
	if index >= 0 and not bool(coordinates[index]["dormant"]):
		return _fire_coordinates(index)
	return _instant_designate(aim)


## The default Grenadier experience: an ordinary 4-Shell Designate sequence
## at the point, no Coordinate consumed or required. ORQ1/2/3/4/5 apply.
func _instant_designate(at: Vector2) -> Dictionary:
	counters["designates"] = int(counters["designates"]) + 1
	_seq_serial += 1
	var seq := _seq_serial
	_seq_cascade[seq] = 0
	var sequence: Dictionary
	if has("ORQ2"):
		var chosen := runner.nearest_enemy(at, 2.0 * AscensionRunner.L)
		sequence = {"at": at, "shells": 3, "tick": 0.0, "root": "ORQ", "damage": 2.5, "follow": chosen, "radius": 0.0, "seq": seq, "coord": -1, "automatic": false, "pp": SHELL_PP}
	elif has("ORQ1"):
		sequence = {"at": at, "shells": 7, "tick": 0.0, "root": "ORQ", "damage": SHELL_D, "follow": 0, "radius": 3.0 * AscensionRunner.R, "seq": seq, "coord": -1, "automatic": false, "pp": SHELL_PP}
	else:
		sequence = {"at": at, "shells": 4, "tick": 0.0, "root": "ORQ", "damage": SHELL_D, "follow": 0, "radius": 0.0, "seq": seq, "coord": -1, "automatic": false, "pp": SHELL_PP}
	_sequences.append(sequence)
	if has("ORQ5"):
		_tracked_sequences.append({"seq_ref": sequence, "until": _clock + TAP_TRACK_SECONDS})
	if has("ORA") and has("OR12"):
		# Instant Designate is a Shell-producing Q, exactly once per cast.
		_big_one_bonus += 1
	return {"ok": true, "message": "DESIGNATE", "cooldown": 7.0}


# ------------------------------------------------------------ HUD / debug

func hud_state(slot: String) -> Dictionary:
	var state := {}
	if slot == "q":
		var live := coordinates.filter(func(c): return not bool(c["dormant"])).size()
		state["resource_value"] = float(live)
		state["resource_max"] = 3.0
		var parts := PackedStringArray(["COORD %d/3" % live])
		if has("OR02") or has("OR09"):
			parts.append("NADE %d" % grenades.size())
		if has("OR10"):
			parts.append("SPARE %d/%d" % [spare_grenades, _bandolier_cap()])
		if mines.size() > 0:
			parts.append("MINES %d" % mines.size())
		state["combat_text"] = "  ".join(parts)
	elif slot == "v" and (_mission_tell >= 0.0 or _mission_left > 0.0):
		state["combat_text"] = "FIRE MISSION"
	return state


## Distinct silhouettes (spec §4.6): grenades travel as round charges, Mines
## sit as spiked discs, falling Shells telegraph as pressure reticles over
## their true blast circle. Textures fall back to the V4 circles when absent.
func collect_draw_points(out: Array) -> void:
	for mine in mines:
		var armed := float(mine["arm"]) <= 0.0
		runner.note_texture_point(mine["at"], 12.0 if armed else 9.0, Color(1.0, 1.0, 1.0, 1.0 if armed else 0.55), "mine_body")
	for coord in coordinates:
		out.append([coord["at"], 14.0, Color(1.0, 0.9, 0.5, 0.3 if bool(coord["dormant"]) else 0.7)])
	for shell in shells:
		var footprint := float(shell["radius"]) * _blast_radius_scale()
		out.append([shell["at"], footprint, Color(1.0, 0.5, 0.3, 0.25)])
		var urgency: float = clampf(1.0 - float(shell["left"]) / SHELL_TELL, 0.3, 1.0)
		runner.note_texture_point(shell["at"], footprint * 0.5, Color(1.0, 1.0, 1.0, urgency), "shell_marker")
	for lane in _lanes:
		out.append([lane["from"], 2.0, Color(1.0, 0.7, 0.4, 0.4), lane["to"]])
	for grenade in grenades:
		var tint := Color(1.0, 1.0, 1.0, 1.0)
		match String(grenade["state"]):
			"attached":
				tint = Color(1.4, 1.1, 0.6, 1.0)
			"grounded":
				tint = Color(1.3, 0.9, 0.6, 1.0)
		runner.note_texture_point(grenade["pos"], 8.0, tint, "grenade_body")


func describe() -> Dictionary:
	var out := super.describe()
	out["v5"] = true
	out["grenades_live"] = grenades.size()
	out["spare_grenades"] = spare_grenades
	out["grenadier_credits"] = _grenadier_credits
	return out
