extends AscensionEngine
class_name OrdnanceEngine
## Ordnance: Shells, Mines, Coordinates and the blasts that call each other.
##
## Shell: 1.5D in R after a 0.6 s tell, Proc Power 0.5. Mine: 1.5D in R,
## arms in 0.35 s, lasts 8 s, twelve at most. Coordinates: three. Every
## blast is an impact queued on the runner with a "cast:blast:N" tag; the
## engine keeps the blast's centre and radius so hits can be pulled,
## fractured, counted and self-damaged after the fact. Placed objects are
## engine data drawn by the runner.

const EFFECTS: Dictionary = {
	"OR01": &"impact_fuse", "OR02": &"caltrops", "OR03": &"short_fuse", "OR04": &"secondary_blast",
	"OR05": &"mine_toss", "OR06": &"chain_reaction", "OR07": &"blast_pull", "OR08": &"fracture",
	"OR09": &"walking_barrage", "OR10": &"magazine", "OR11": &"saturation_scan", "OR12": &"big_one",
	"ORQ": &"designate", "ORQ1": &"saturation", "ORQ2": &"homing", "ORQ3": &"cascade",
	"ORQ4": &"proximity", "ORQ5": &"walking_target", "ORQ6": &"all_coordinates", "ORQ7": &"fire_again",
	"ORF1": &"carpet_fire", "ORF2": &"guidance", "ORK1": &"spotter", "ORK2": &"danger_close",
	"ORA": &"fuse", "ORC": &"rolling_thunder", "ORE1": &"carpet_bomb", "ORE2": &"bunker_buster",
	"ORS1": &"blast_damage", "ORS2": &"blast_radius", "ORV": &"fire_mission", "ORV1": &"no_safe_ground",
	"ORV2": &"firewalk", "ORV3": &"second_salvo",
}
const SHELL_TELL := 0.6
const SHELL_D := 1.5
const SHELL_PP := 0.5
const MINE_ARM := 0.35
const MINE_LIFE := 8.0
const MINE_D := 1.5
const MINE_CONTACT := 22.0
const CELL := 80.0

var _clock: float = 0.0
var shells: Array = []                  # {at, left, damage, radius, pp, root, flags, follow, seq, big, trap}
var mines: Array = []                   # {at, arm, life, damage, radius, root, seq, trap, pushed_by, travelled}
var coordinates: Array = []             # {at, dormant, offset, follow, allowance, drop_tick}
var _blasts: Dictionary = {}            # cast id -> {at, radius, hits, seq, durable_damage, kind}
var _blast_serial: int = 0
var _seq_serial: int = 0
var _seq_blasts: Dictionary = {}        # seq -> blast count (Rolling Thunder)
var _seq_kills: Dictionary = {}         # seq -> {handle: true} (Cascade)
var _seq_cascade: Dictionary = {}       # coordinate cast -> additions
var _fuse: float = 0.0
var _fuse_shell_volley: int = -1
var _volley: int = 0
var _short_fuse_volley: int = -1
var _secondary_done: Dictionary = {}
var _blasts_on: Dictionary = {}         # handle -> {cast: direction}
var _recent_blast_dirs: Dictionary = {} # handle -> Array of Vector2
var _travel_credit: float = 0.0
var _walk_cooldown: float = 0.0
var _scan_travel: float = 0.0
var _scan_armed: bool = true
var _shell_count: int = 0
var _big_one_bonus: int = 0
var _recent_cells: Dictionary = {}      # cell -> clock
var _blast_kill_times: Array[float] = []
var _guided: int = 0
var _guided_until: float = -INF
var _auto_shells: int = 0
var _beacons: Dictionary = {}           # handle -> {until, tick}
var _self_hit_at: float = -INF
var _durable_bank: float = 0.0
var _thunder_recovery: float = 0.0
var _lanes: Array = []                  # {from, to, shots, tick}
var _sequences: Array = []              # {at, left, shells, tick, root, follow, radius, damage, seq, coord}
var _q_hold: float = 0.0
var _hold_placed: int = -1
var _fire_pending_at_release: bool = false
var _dormant_wait: bool = false
var _mission_tell: float = -1.0
var _mission_left: float = 0.0
var _mission_shells: int = 0
var _mission_tick: float = 0.0
var _mission_scale: float = 1.0
var _mission_cast: int = 0
var _salvo_delay: float = -1.0
var _cell_use: Dictionary = {}
var _heading: Vector2 = Vector2.RIGHT
var _stop_timer: float = 0.0
var _mission_gaps: bool = false

var counters: Dictionary = {"shells": 0, "big_ones": 0, "mines": 0, "mine_blasts": 0, "chain": 0, "fuse_shells": 0, "short_fuses": 0, "redirects": 0, "secondary": 0, "tosses": 0, "pulls": 0, "fractures": 0, "shrapnel": 0, "walking": 0, "scans": 0, "coordinates": 0, "designates": 0, "cascades": 0, "traps": 0, "carpet_extra": 0, "suppressed": 0, "beacons": 0, "beacon_shells": 0, "self_hits": 0, "fuse_q": 0, "thunder": 0, "lane_shells": 0, "carpet_drops": 0, "busters": 0, "missions": 0, "mission_shells": 0, "salvos": 0}


func discipline() -> String:
	return "OR"


func D() -> float:
	return runner.native_damage_for("ranged")


func mine_cap() -> int:
	return 18 if has("OR10") else 12


func _blast_damage_scale(is_shell: bool, automatic: bool, target: int = 0) -> float:
	var scale := 1.0
	if has("ORS1"):
		scale *= 1.0 + 0.01 * sqrt(float(rank("ORS1")))
	if has("ORK2"):
		scale *= 1.25
	if is_shell and has("ORK1") and not _beacons.has(target):
		scale *= 0.85
	if is_shell and has("ORF1"):
		scale *= 0.85
	if automatic and has("ORF2") and target != 0 and target == _guided and _clock < _guided_until:
		scale *= 1.5
	return scale


func _blast_radius_scale() -> float:
	var scale := 1.0
	if has("ORS2"):
		var r := float(rank("ORS2"))
		scale *= 1.0 + 0.7 * r / (r + 95.0)
	if has("ORK2"):
		scale *= 1.4
	return scale


# ---------------------------------------------------------------- shells

## Calls a Shell: lands after the tell as a blast. `automatic` shells obey
## Carpet Fire and Guidance; a manual Designate sequence does not.
func call_shell(at: Vector2, damage_d: float = SHELL_D, root: String = "OR01", pp: float = SHELL_PP, flags: PackedStringArray = PackedStringArray(), automatic: bool = true, seq: int = 0, follow: int = 0, big_allowed: bool = true) -> Dictionary:
	if automatic and has("ORF2"):
		if _guided != 0 and _clock < _guided_until and runner.enemy_alive(_guided):
			follow = _guided
			at = runner.enemy_position(_guided)
		_auto_shells += 1
		if _auto_shells % 2 == 0:
			counters["suppressed"] = int(counters["suppressed"]) + 1
			return {}
	if automatic and has("ORF1"):
		at = _carpet_cell(at)
	var big := false
	if big_allowed and has("OR12") and not flags.has("beacon"):
		_shell_count += 1 + _big_one_bonus
		_big_one_bonus = 0
		if _shell_count % 7 == 0:
			big = true
	if seq == 0:
		_seq_serial += 1
		seq = _seq_serial
	var shell := {
		"at": at, "left": 0.9 if big else SHELL_TELL, "damage": (4.0 if big else damage_d) * D(),
		"radius": (2.0 if big else 1.0) * AscensionRunner.R, "pp": 1.0 if big else pp, "root": root,
		"flags": flags, "follow": follow, "seq": seq, "big": big, "automatic": automatic, "bonus": 0.0,
	}
	if big and has("RM9"):
		# Meteor: 6D in 2R after 1 s, with a Well pulling at the landing.
		shell["damage"] = 6.0 * D()
		shell["left"] = 1.0
		var dominion := runner.engine_of_discipline("DO") as DominionEngine
		if dominion != null:
			dominion.place_well(at, "meteor", false, 0.0, 1.0)
		counters["meteors"] = int(counters.get("meteors", 0)) + 1
	shells.append(shell)
	counters["shells"] = int(counters["shells"]) + 1
	if big:
		counters["big_ones"] = int(counters["big_ones"]) + 1
	return shell


## Carpet Fire: automatic Shells prefer occupied cells not used recently.
func _carpet_cell(at: Vector2) -> Vector2:
	var cell := Vector2i(int(floor(at.x / CELL)), int(floor(at.y / CELL)))
	if _clock - float(_recent_cells.get(cell, -INF)) > 2.0:
		_recent_cells[cell] = _clock
		return at
	for handle in runner.enemies_in_radius(at, 2.0 * AscensionRunner.R):
		var pos := runner.enemy_position(handle)
		var other := Vector2i(int(floor(pos.x / CELL)), int(floor(pos.y / CELL)))
		if other != cell and _clock - float(_recent_cells.get(other, -INF)) > 2.0:
			_recent_cells[other] = _clock
			return pos
	_recent_cells[cell] = _clock
	return at


func _tick_shells(delta: float) -> void:
	if shells.is_empty():
		return
	var landing: Array = []
	for shell in shells:
		var follow := int(shell["follow"])
		if follow != 0 and float(shell["left"]) > 0.15:
			if runner.enemy_alive(follow):
				shell["at"] = runner.enemy_position(follow)
			else:
				shell["follow"] = 0
		shell["left"] = float(shell["left"]) - delta
		if float(shell["left"]) <= 0.0:
			landing.append(shell)
	for shell in landing:
		shells.erase(shell)
		if has("ORQ4") and bool(shell.get("trap", false)):
			_drop_trap(shell)
		else:
			var flags: PackedStringArray = shell["flags"]
			if float(shell.get("bonus", 0.0)) > 0.0 and not flags.has("time_bomb"):
				flags = flags.duplicate()
				flags.append("time_bomb")
			_blast(shell["at"], float(shell["damage"]) + float(shell.get("bonus", 0.0)), float(shell["radius"]), String(shell["root"]), float(shell["pp"]), flags, int(shell["seq"]), true, bool(shell["automatic"]))


## Resolves a blast through the runner's queue; remembers its geometry.
func _blast(at: Vector2, damage: float, radius: float, root: String, pp: float, flags: PackedStringArray, seq: int, is_shell: bool, automatic: bool) -> void:
	_blast_serial += 1
	var tags := AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, root, "shell" if is_shell else "mine", 1, pp, flags)
	if automatic and not tags.has("flag:auto"):
		tags.append("flag:auto")
	tags.append("cast:blast:%d" % _blast_serial)
	var scaled_radius := radius * _blast_radius_scale()
	_blasts[_blast_serial] = {"at": at, "radius": scaled_radius, "hits": 0, "seq": seq, "shell": is_shell, "automatic": automatic, "root": root, "kills": 0}
	_seq_blasts[seq] = int(_seq_blasts.get(seq, 0)) + 1
	if has("ORC") and int(_seq_blasts[seq]) >= 12 and _thunder_recovery <= 0.0:
		_rolling_thunder()
	runner.spawn_impact(at, damage * _blast_damage_scale(is_shell, automatic), tags, scaled_radius)
	if has("ORK2") and runner.player_position().distance_to(at) <= scaled_radius and _clock - _self_hit_at >= 0.25:
		_self_hit_at = _clock
		counters["self_hits"] = int(counters["self_hits"]) + 1
		runner.player().call("take_damage", 0.03 * runner.player_max_hp(), null)
	if has("OR06") and not is_shell:
		_chain_reaction(at, scaled_radius, seq)
	if _blasts.size() > 64:
		_blasts.erase(_blasts.keys()[0])


# ---------------------------------------------------------------- mines

func drop_mine(at: Vector2, damage_d: float = MINE_D, root: String = "OR02", seq: int = 0, trap: bool = false, life: float = MINE_LIFE, arm: float = MINE_ARM) -> Dictionary:
	var cap := 24 if trap else mine_cap()
	var same_kind: Array = mines.filter(func(m): return bool(m["trap"]) == trap)
	if same_kind.size() >= cap:
		var oldest: Dictionary = same_kind[0]
		mines.erase(oldest)
		_explode_mine(oldest, 1.0 if (has("OR10") or trap) else 0.5)
	if seq == 0:
		_seq_serial += 1
		seq = _seq_serial
	var mine := {"at": at, "arm": arm, "life": life, "damage": damage_d * D(), "radius": AscensionRunner.R, "root": root, "seq": seq, "trap": trap, "pushed_by": 0, "travelled": 0.0}
	mines.append(mine)
	counters["traps" if trap else "mines"] = int(counters["traps" if trap else "mines"]) + 1
	return mine


func _drop_trap(shell: Dictionary) -> void:
	drop_mine(shell["at"], float(shell["damage"]) / maxf(D(), 0.001), String(shell["root"]), int(shell["seq"]), true, 3.0, 0.0)


func _explode_mine(mine: Dictionary, scale: float = 1.0) -> void:
	counters["mine_blasts"] = int(counters["mine_blasts"]) + 1
	_blast(mine["at"], float(mine["damage"]) * scale, float(mine["radius"]), String(mine["root"]), SHELL_PP, PackedStringArray(), int(mine["seq"]), false, false)
	if has("RM7") and int(mine.get("sigil", 0)) != 0 and not _rune_guard:
		# Rune Bomb: the attached Sigil detonates once with its Mine.
		var invocation := runner.engine_of_discipline("IN") as InvocationEngine
		if invocation != null:
			var sigil := invocation._find(int(mine["sigil"]))
			if not sigil.is_empty():
				_rune_guard = true
				invocation._detonate(sigil, false)
				_rune_guard = false


var _rune_guard: bool = false


## Rune Bomb: every Mine attached to `sigil_id` explodes (called by a Sigil detonation).
func explode_attached(sigil_id: int) -> void:
	if _rune_guard:
		return
	_rune_guard = true
	for mine in mines.duplicate():
		if int(mine.get("sigil", 0)) == sigil_id:
			mines.erase(mine)
			_explode_mine(mine)
	_rune_guard = false


func _tick_rune_bombs() -> void:
	if not has("RM7"):
		return
	var invocation := runner.engine_of_discipline("IN") as InvocationEngine
	if invocation == null:
		return
	for mine in mines:
		if float(mine["arm"]) > 0.0 or int(mine.get("sigil", 0)) != 0:
			continue
		for sigil in invocation.sigils:
			if int(sigil.get("mines", 0)) >= 3:
				continue
			if (sigil["at"] as Vector2).distance_to(mine["at"]) <= invocation.sigil_radius(sigil):
				mine["sigil"] = int(sigil["id"])
				sigil["mines"] = int(sigil.get("mines", 0)) + 1
				counters["rune_bombs"] = int(counters.get("rune_bombs", 0)) + 1
				break


func _chain_reaction(at: Vector2, radius: float, seq: int) -> void:
	var touched: Array = []
	for mine in mines:
		if float(mine["arm"]) <= 0.0 and (mine["at"] as Vector2).distance_to(at) <= radius:
			touched.append(mine)
	for mine in touched:
		mines.erase(mine)
	for mine in touched:
		counters["chain"] = int(counters["chain"]) + 1
		mine["seq"] = seq
		_explode_mine(mine)


func _tick_mines(delta: float) -> void:
	if mines.is_empty():
		return
	var aim_dir := (runner.aim_target() - runner.player_position()).normalized()
	var bullets: Array = []
	if has("OR05"):
		for mine in mines:
			if float(mine["arm"]) > 0.0:
				ProjectileManager.player_projectiles_in_radius(mine["at"], 14.0, bullets)
				break
	for i in range(mines.size() - 1, -1, -1):
		var mine: Dictionary = mines[i]
		mine["life"] = float(mine["life"]) - delta
		if float(mine["arm"]) > 0.0:
			mine["arm"] = float(mine["arm"]) - delta
			if has("OR05") and int(mine["pushed_by"]) == 0:
				var near: Array = []
				ProjectileManager.player_projectiles_in_radius(mine["at"], 14.0, near)
				if not near.is_empty():
					var push := aim_dir if aim_dir != Vector2.ZERO else (near[0]["velocity"] as Vector2).normalized()
					mine["pushed_by"] = int(near[0]["id"])
					mine["at"] = (mine["at"] as Vector2) + push * AscensionRunner.R
					mine["travelled"] = AscensionRunner.R
					mine["damage"] = float(mine["damage"]) + 0.5 * D()
					mine["arm"] = 0.0
					counters["tosses"] = int(counters["tosses"]) + 1
			continue
		if float(mine["life"]) <= 0.0:
			mines.remove_at(i)
			if bool(mine["trap"]):
				_explode_mine(mine)
			continue
		if runner.nearest_enemy(mine["at"], MINE_CONTACT) != 0:
			mines.remove_at(i)
			_explode_mine(mine)


# ---------------------------------------------------------------- tick

func tick(delta: float) -> void:
	_clock += delta
	if _walk_cooldown > 0.0:
		_walk_cooldown = maxf(0.0, _walk_cooldown - delta)
	if _thunder_recovery > 0.0:
		_thunder_recovery = maxf(0.0, _thunder_recovery - delta)
	while not _blast_kill_times.is_empty() and _clock - _blast_kill_times[0] > 1.0:
		_blast_kill_times.remove_at(0)
	_track_travel(delta)
	_tick_shells(delta)
	_tick_mines(delta)
	_tick_rune_bombs()
	_tick_sequences(delta)
	_tick_coordinates(delta)
	_tick_beacons(delta)
	_tick_lanes(delta)
	_tick_mission(delta)
	if has("ORQ7") and _dormant_wait and runner.q_cooldown_left <= 0.0:
		_dormant_wait = false
		for coord in coordinates:
			coord["dormant"] = false


func _track_travel(delta: float) -> void:
	var step := runner.travel_this_frame
	if step > 0.5:
		_heading = (runner.player_position() - runner._last_player_position).normalized() if runner._last_player_position != Vector2.INF else _heading
		_stop_timer = 0.0
	else:
		_stop_timer += delta
	_scan_travel += step
	if has("OR09"):
		_travel_credit += step
		if _travel_credit >= AscensionRunner.L and _walk_cooldown <= 0.0:
			_travel_credit = 0.0
			_walk_cooldown = 0.5
			counters["walking"] = int(counters["walking"]) + 1
			call_shell(runner.player_position() - _heading * AscensionRunner.R, SHELL_D, "OR09")


# ---------------------------------------------------------------- hits and kills

func on_native_fire(_style: String, _origin: Vector2, _target: Vector2, _power: float, _haste: float) -> void:
	_volley += 1


## Native shots are Ranged Core strikes for Impact Fuse and Guidance.
func decorate_native_profile(profile: HitProfileAdapter) -> void:
	profile.set_meta("asc_tags", AscensionTags.with_flag(profile.get_meta("asc_tags", PackedStringArray()), "core_strike"))


func on_player_dashed(from: Vector2, _direction: Vector2) -> void:
	if has("OR02"):
		drop_mine(from)


func modify_outgoing_damage(preview: Dictionary, raw: float) -> float:
	var tags: PackedStringArray = preview["tags"]
	if has("ORF2") and AscensionTags.has_flag(tags, "auto") and int(preview["handle"]) == _guided and _clock < _guided_until:
		return raw * 1.5
	return raw


func on_hit(hit: Dictionary) -> void:
	var handle := int(hit["handle"])
	var tags: PackedStringArray = hit["tags"]
	var core_strike := AscensionTags.has_flag(tags, "core_strike")
	if hit["core"] == "ranged" and core_strike:
		if has("OR01"):
			_fuse += float(hit["pp"])
			if _fuse >= 4.0 - 0.0005 and _fuse_shell_volley != _volley:
				_fuse -= 4.0
				_fuse_shell_volley = _volley
				counters["fuse_shells"] = int(counters["fuse_shells"]) + 1
				call_shell(hit["position"], SHELL_D, "OR01")
		if has("ORF2") and (bool(hit["is_elite"]) or bool(hit["is_boss"])):
			_guided = handle
			_guided_until = _clock + 4.0
	if core_strike and has("OR03") and _short_fuse_volley != _volley:
		for shell in shells:
			if (shell["at"] as Vector2).distance_to(hit["position"]) <= float(shell["radius"]):
				shell["left"] = float(shell["left"]) - 0.15
				_short_fuse_volley = _volley
				counters["short_fuses"] = int(counters["short_fuses"]) + 1
				break
	var cast := AscensionTags.value_of(tags, "cast")
	if cast.begins_with("blast:"):
		_on_blast_hit(int(cast.substr(6)), hit)


func _on_blast_hit(blast_id: int, hit: Dictionary) -> void:
	var handle := int(hit["handle"])
	var blast: Dictionary = _blasts.get(blast_id, {})
	if blast.is_empty():
		return
	if has("RM8") and AscensionTags.has_flag(hit["tags"], "time_bomb") and not bool(hit["lethal"]):
		var distortion := runner.engine_of_discipline("DT") as DistortionEngine
		if distortion != null:
			distortion.mature_oldest(handle)
	blast["hits"] = int(blast["hits"]) + 1
	if int(blast["hits"]) == 2 and bool(blast["shell"]):
		runner.add_action_charge(1.0)
	if bool(hit["is_elite"]) or bool(hit["is_boss"]):
		_durable_bank += float(hit["applied"])
		while _durable_bank >= 2.0 * D():
			_durable_bank -= 2.0 * D()
			runner.add_action_charge(1.0)
	var centre: Vector2 = blast["at"]
	var radius := float(blast["radius"])
	var at: Vector2 = hit["position"]
	# Distinct blasts on this target: Fracture and Spotter.
	var seen: Dictionary = _blasts_on.get(handle, {})
	if not seen.has(blast_id):
		var incoming := (at - centre).normalized()
		if incoming == Vector2.ZERO:
			incoming = Vector2.RIGHT
		seen[blast_id] = incoming
		_blasts_on[handle] = seen
		if has("OR08") and runner.enemy_alive(handle):
			if runner.has_status(handle, "fracture"):
				runner.clear_status(handle, "fracture")
				_shrapnel(handle, at, seen)
			elif seen.size() % 3 == 0:
				runner.status_of(handle)["fracture"] = 30
				counters["fractures"] = int(counters["fractures"]) + 1
		if has("ORK1") and (bool(hit["is_elite"]) or bool(hit["is_boss"])) and runner.enemy_alive(handle) and String(blast["root"]) != "ORK1":
			if _beacons.has(handle):
				_beacons[handle]["until"] = _clock + 5.0
			elif seen.size() >= 3 and _beacons.size() < 3:
				_beacons[handle] = {"until": _clock + 5.0, "tick": 0.0}
				counters["beacons"] = int(counters["beacons"]) + 1
	# Blast Pull: the outer half pulls normals R/2 toward the centre.
	if has("OR07") and not bool(hit["lethal"]) and at.distance_to(centre) > radius * 0.5:
		var toward := (centre - at).normalized()
		if bool(hit["is_boss"]):
			runner.damage_enemy(handle, 0.25 * D(), AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "OR07", "stagger", 2, 0.0))
			EnemyCombat.apply_stun(handle, 0.2)
		else:
			var distance := AscensionRunner.R * (0.25 if bool(hit["is_elite"]) else 0.5)
			runner.move_enemy_to(handle, at + toward * minf(distance, at.distance_to(centre)))
			counters["pulls"] = int(counters["pulls"]) + 1


func _shrapnel(handle: int, at: Vector2, seen: Dictionary) -> void:
	counters["shrapnel"] = int(counters["shrapnel"]) + 1
	var dirs: Array = seen.values()
	var fired := 0
	for i in range(dirs.size() - 1, -1, -1):
		if fired >= 3:
			break
		runner.spawn_bullet(at, dirs[i], 0.6 * D(), AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "OR08", "shrapnel", 2, 0.35))
		fired += 1
	while fired < 3:
		runner.spawn_bullet(at, Vector2.from_angle(runner.rng().randf_range(0.0, TAU)), 0.6 * D(), AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "OR08", "shrapnel", 2, 0.35))
		fired += 1


func on_kill(hit: Dictionary, _context: RefCounted) -> void:
	var handle := int(hit["handle"])
	_blasts_on.erase(handle)
	_beacons.erase(handle)
	if handle == _guided:
		_guided = 0
	var cast := AscensionTags.value_of(hit["tags"], "cast")
	if not cast.begins_with("blast:"):
		return
	var blast: Dictionary = _blasts.get(int(cast.substr(6)), {})
	if blast.is_empty():
		return
	blast["kills"] = int(blast["kills"]) + 1
	var seq := int(blast["seq"])
	_blast_kill_times.append(_clock)
	if has("OR04") and not _secondary_done.has(handle):
		_secondary_done[handle] = true
		counters["secondary"] = int(counters["secondary"]) + 1
		var secondary := call_shell(hit["position"], SHELL_D, "OR04", 0.5, PackedStringArray(), true, seq)
		if has("RM8") and not secondary.is_empty():
			# Time Bomb: the Shell collects the corpse's unpaid Debt and lands 0.5 s later.
			var distortion := runner.engine_of_discipline("DT") as DistortionEngine
			if distortion != null:
				var collected := distortion.collect_debt(handle)
				secondary["left"] = float(secondary["left"]) + 0.5
				secondary["bonus"] = 0.75 * collected
				counters["time_bombs"] = int(counters.get("time_bombs", 0)) + 1
	if has("OR03"):
		for shell in shells:
			if int(shell["follow"]) == handle or ((shell["at"] as Vector2).distance_to(hit["position"]) <= float(shell["radius"]) and not bool(shell.get("redirected", false))):
				var next := runner.nearest_enemy(hit["position"], 3.0 * AscensionRunner.R, handle)
				if next != 0:
					shell["at"] = runner.enemy_position(next)
					shell["follow"] = 0
					shell["redirected"] = true
					counters["redirects"] = int(counters["redirects"]) + 1
				break
	if has("OR11") and _scan_armed and _scan_travel >= AscensionRunner.R:
		_scan_travel = 0.0
		counters["scans"] = int(counters["scans"]) + 1
		var cell := _densest_point(hit["position"], 3.0 * AscensionRunner.R)
		_sequences.append({"at": cell, "shells": 3, "tick": 0.0, "root": "OR11", "damage": SHELL_D, "follow": 0, "radius": 0.0, "seq": seq, "coord": -1, "automatic": true, "pp": SHELL_PP})
	if has("ORF1") and _blast_kill_times.size() >= 3:
		_blast_kill_times.clear()
		counters["carpet_extra"] = int(counters["carpet_extra"]) + 1
		call_shell(_least_covered_point(), SHELL_D, "ORF1", 0.4)
	if has("ORQ3"):
		var coord_seq := int(blast.get("seq", 0))
		if _seq_cascade.has(coord_seq):
			var kills: Dictionary = _seq_kills.get(coord_seq, {})
			if not kills.has(handle) and int(_seq_cascade[coord_seq]) < 6:
				kills[handle] = true
				_seq_kills[coord_seq] = kills
				_seq_cascade[coord_seq] = int(_seq_cascade[coord_seq]) + 1
				counters["cascades"] = int(counters["cascades"]) + 1
				call_shell(hit["position"], SHELL_D, "ORQ3", SHELL_PP, PackedStringArray(), false, coord_seq)


func _densest_point(origin: Vector2, radius: float) -> Vector2:
	var best := origin
	var best_count := -1
	for handle in runner.enemies_in_radius(origin, radius):
		var at := runner.enemy_position(handle)
		var count := runner.enemies_in_radius(at, AscensionRunner.R * 0.5).size()
		if count > best_count:
			best_count = count
			best = at
	return best


func _least_covered_point() -> Vector2:
	var origin := runner.player_position()
	var best := origin
	var best_score := -INF
	for handle in runner.enemies_in_radius(origin, 3.0 * AscensionRunner.L):
		var at := runner.enemy_position(handle)
		var score := INF
		for blast in _blasts.values():
			score = minf(score, at.distance_to(blast["at"]))
		if score > best_score:
			best_score = score
			best = at
	return best


# ---------------------------------------------------------------- Beacons, lanes

func _tick_beacons(delta: float) -> void:
	if _beacons.is_empty():
		return
	for handle in _beacons.keys():
		var beacon: Dictionary = _beacons[handle]
		if _clock >= float(beacon["until"]) or not runner.enemy_alive(int(handle)):
			_beacons.erase(handle)
			continue
		beacon["tick"] = float(beacon["tick"]) + delta
		if float(beacon["tick"]) >= 0.8:
			beacon["tick"] = 0.0
			counters["beacon_shells"] = int(counters["beacon_shells"]) + 1
			call_shell(runner.enemy_position(int(handle)), 1.0, "ORK1", SHELL_PP, PackedStringArray(["beacon"]), false, 0, int(handle), false)


func _rolling_thunder() -> void:
	_thunder_recovery = 8.0
	counters["thunder"] = int(counters["thunder"]) + 1
	runner.note_catastrophe("ORC")
	var rect := runner.camera_rect()
	for i in range(6):
		var y := rect.position.y + rect.size.y * (float(i) + 0.5) / 6.0
		_lanes.append({"from": Vector2(rect.position.x, y), "to": Vector2(rect.end.x, y), "shots": 4, "tick": 0.0})
	for mine in mines.duplicate():
		if float(mine["arm"]) <= 0.0:
			for lane in _lanes:
				var y := (lane["from"] as Vector2).y
				if absf((mine["at"] as Vector2).y - y) <= AscensionRunner.R * 0.5:
					mines.erase(mine)
					_explode_mine(mine)
					break
	if BattleText != null:
		BattleText.popup(runner.player_position(), "ROLLING THUNDER", Color(1.0, 0.7, 0.4, 1.0), 1.6)


func _tick_lanes(delta: float) -> void:
	if _lanes.is_empty():
		return
	for i in range(_lanes.size() - 1, -1, -1):
		var lane: Dictionary = _lanes[i]
		lane["tick"] = float(lane["tick"]) + delta
		if float(lane["tick"]) >= 0.25 and int(lane["shots"]) > 0:
			lane["tick"] = 0.0
			lane["shots"] = int(lane["shots"]) - 1
			var t := (4.0 - float(lane["shots"]) - 0.5) / 4.0
			var at: Vector2 = (lane["from"] as Vector2).lerp(lane["to"], t)
			counters["lane_shells"] = int(counters["lane_shells"]) + 1
			call_shell(at, 2.0, "ORC", 0.3, PackedStringArray(), false, 0, 0, false)
		if int(lane["shots"]) <= 0:
			_lanes.remove_at(i)


# ---------------------------------------------------------------- Designate (Q)

func q_is_hold(id: String) -> bool:
	return id == "ORQ" and not runner.automatic_cast and not runner.reaction_cast


func _coordinate_at(point: Vector2) -> int:
	for i in range(coordinates.size()):
		if (coordinates[i]["at"] as Vector2).distance_to(point) <= AscensionRunner.R * 0.5:
			return i
	return -1


func place_coordinate(at: Vector2) -> int:
	if coordinates.size() >= 3:
		var oldest: Dictionary = coordinates.pop_front()
		if has("OR10"):
			call_shell(oldest["at"], SHELL_D, "OR10", SHELL_PP, PackedStringArray(), false)
	var offset := Vector2.ZERO
	if has("ORQ5"):
		offset = at - runner.player_position()
		if offset.length() > AscensionRunner.L:
			offset = offset.normalized() * AscensionRunner.L
	coordinates.append({"at": at, "dormant": false, "offset": offset, "follow": has("ORQ5"), "allowance": 10, "drop_tick": 0.0, "carpet": 0.0})
	counters["coordinates"] = int(counters["coordinates"]) + 1
	return coordinates.size() - 1


func activate_q(id: String) -> Dictionary:
	if id != "ORQ":
		return {"ok": false, "message": "NOT ORDNANCE", "cooldown": 0.0}
	_q_hold = 0.0
	_hold_placed = -1
	var aim := runner.aim_target()
	if runner.automatic_cast or runner.reaction_cast:
		if coordinates.is_empty():
			var dense := _densest_point(runner.player_position(), 3.0 * AscensionRunner.L)
			place_coordinate(dense)
		return _fire_coordinates(0)
	var index := _coordinate_at(aim)
	if index >= 0 and not bool(coordinates[index]["dormant"]):
		return _fire_coordinates(index)
	_hold_placed = place_coordinate(aim)
	return {"ok": true, "message": "COORDINATE", "cooldown": 0.25}


func hold_q(_id: String, delta: float) -> void:
	if _hold_placed < 0:
		return
	_q_hold += delta
	if _q_hold >= 0.35:
		var index := _hold_placed
		_hold_placed = -1
		var verdict := _fire_coordinates(index)
		runner.q_cooldown_left = float(verdict.get("cooldown", 7.0))
		runner.q_cooldown_max = runner.q_cooldown_left


func release_q(_id: String) -> Dictionary:
	_hold_placed = -1
	return {"ok": true, "message": "", "cooldown": runner.q_cooldown_left}


func _fire_coordinates(index: int) -> Dictionary:
	if coordinates.is_empty():
		return {"ok": false, "message": "NO COORDINATE", "cooldown": 0.0}
	counters["designates"] = int(counters["designates"]) + 1
	_seq_serial += 1
	var seq := _seq_serial
	var order: Array = [index]
	if has("ORQ6"):
		order = range(coordinates.size())
	var delay := 0.0
	var fired: Array = []
	for i in order:
		var coord: Dictionary = coordinates[i]
		if bool(coord["dormant"]):
			continue
		_seq_cascade[seq] = 0
		fired.append(coord)
		if has("ORE2"):
			var durable := _nearest_durable(coord["at"])
			_sequences.append({"at": coord["at"], "shells": 1, "tick": -delay - 1.0, "root": "ORE2", "damage": 8.0, "follow": durable, "radius": 0.0, "seq": seq, "coord": i, "automatic": false, "pp": 1.0, "big_radius": true})
			counters["busters"] = int(counters["busters"]) + 1
		elif has("ORE1"):
			coord["carpet"] = 3.0
			coord["allowance"] = 10
			coord["seq"] = seq
		elif has("ORQ2"):
			var chosen := runner.nearest_enemy(coord["at"], 2.0 * AscensionRunner.L)
			_sequences.append({"at": coord["at"], "shells": 3, "tick": -delay, "root": "ORQ", "damage": 2.5, "follow": chosen, "radius": 0.0, "seq": seq, "coord": i, "automatic": false, "pp": SHELL_PP})
		elif has("ORQ1"):
			_sequences.append({"at": coord["at"], "shells": 7, "tick": -delay, "root": "ORQ", "damage": SHELL_D, "follow": 0, "radius": 3.0 * AscensionRunner.R, "seq": seq, "coord": i, "automatic": false, "pp": SHELL_PP})
		else:
			_sequences.append({"at": coord["at"], "shells": 4, "tick": -delay, "root": "ORQ", "damage": SHELL_D, "follow": 0, "radius": 0.0, "seq": seq, "coord": i, "automatic": false, "pp": SHELL_PP})
		delay += 0.2
	for coord in fired:
		if has("ORE1"):
			continue
		if has("ORQ7"):
			coord["dormant"] = true
			_dormant_wait = true
		else:
			coordinates.erase(coord)
	if has("ORA") and has("OR12"):
		_big_one_bonus += 1
	return {"ok": true, "message": "DESIGNATE", "cooldown": 7.0}


func _nearest_durable(at: Vector2) -> int:
	var best := 0
	var best_d := INF
	for handle in runner.enemies_in_radius(at, 3.0 * AscensionRunner.L):
		if runner.is_elite(handle) or runner.is_boss(handle):
			var d := at.distance_squared_to(runner.enemy_position(handle))
			if d < best_d:
				best_d = d
				best = handle
	return best


func _tick_sequences(delta: float) -> void:
	if _sequences.is_empty():
		return
	for i in range(_sequences.size() - 1, -1, -1):
		var sequence: Dictionary = _sequences[i]
		sequence["tick"] = float(sequence["tick"]) + delta
		if float(sequence["tick"]) < 0.2:
			continue
		sequence["tick"] = 0.0
		sequence["shells"] = int(sequence["shells"]) - 1
		var at: Vector2 = sequence["at"]
		var coord_index := int(sequence["coord"])
		if coord_index >= 0 and coord_index < coordinates.size() and bool(coordinates[coord_index].get("follow", false)):
			at = coordinates[coord_index]["at"]
		if float(sequence["radius"]) > 0.0:
			at += Vector2.from_angle(runner.rng().randf_range(0.0, TAU)) * runner.rng().randf_range(0.0, float(sequence["radius"]))
		var follow := int(sequence["follow"])
		if follow != 0 and runner.enemy_alive(follow):
			at = runner.enemy_position(follow)
		var shell := call_shell(at, float(sequence["damage"]), String(sequence["root"]), float(sequence["pp"]), PackedStringArray(), bool(sequence["automatic"]), int(sequence["seq"]), follow if float(sequence["damage"]) >= 2.5 else 0, String(sequence["root"]) != "ORE2")
		if not shell.is_empty():
			if bool(sequence.get("big_radius", false)):
				shell["radius"] = 2.0 * AscensionRunner.R
				shell["left"] = 0.2
			if has("ORQ4") and String(sequence["root"]) == "ORQ":
				shell["trap"] = true
		if int(sequence["shells"]) <= 0:
			_sequences.remove_at(i)


func _tick_coordinates(delta: float) -> void:
	if coordinates.is_empty():
		return
	var player_pos := runner.player_position()
	for coord in coordinates:
		if bool(coord.get("follow", false)):
			coord["at"] = player_pos + (coord["offset"] as Vector2)
		if float(coord.get("carpet", 0.0)) > 0.0:
			coord["carpet"] = float(coord["carpet"]) - delta
			coord["at"] = player_pos - _heading * AscensionRunner.R
			coord["drop_tick"] = float(coord["drop_tick"]) + delta
			if _stop_timer >= 0.3 and int(coord["allowance"]) > 0:
				for _i in range(int(coord["allowance"])):
					call_shell(player_pos - _heading * AscensionRunner.R * runner.rng().randf_range(0.5, 2.0), SHELL_D, "ORE1", SHELL_PP, PackedStringArray(), false, int(coord.get("seq", 0)))
					counters["carpet_drops"] = int(counters["carpet_drops"]) + 1
				coord["allowance"] = 0
				coord["carpet"] = 0.0
			elif float(coord["drop_tick"]) >= 0.3 and int(coord["allowance"]) > 0:
				coord["drop_tick"] = 0.0
				coord["allowance"] = int(coord["allowance"]) - 1
				counters["carpet_drops"] = int(counters["carpet_drops"]) + 1
				call_shell(coord["at"], SHELL_D, "ORE1", SHELL_PP, PackedStringArray(), false, int(coord.get("seq", 0)))
			if float(coord["carpet"]) <= 0.0:
				coord["dormant"] = has("ORQ7")
				if not has("ORQ7"):
					coord["remove"] = true
	for i in range(coordinates.size() - 1, -1, -1):
		if bool(coordinates[i].get("remove", false)):
			coordinates.remove_at(i)


func q_active(id: String) -> bool:
	return id == "ORQ" and not _sequences.is_empty()


func auto_target(_id: String) -> Vector2:
	if not coordinates.is_empty():
		return coordinates[0]["at"]
	return _densest_point(runner.player_position(), 3.0 * AscensionRunner.L)


## Fuse (axiom): a Q that makes no Shells leaves one at its endpoint.
func on_q_activated(id: String, verdict: Dictionary) -> void:
	if not has("ORA") or not bool(verdict.get("ok", false)) or id == "ORQ":
		return
	var origin := runner.player_position()
	var aim := runner.aim_target()
	var endpoint := origin + (aim - origin).limit_length(AscensionRunner.L)
	counters["fuse_q"] = int(counters["fuse_q"]) + 1
	call_shell(endpoint, SHELL_D, "ORA", SHELL_PP, PackedStringArray(), false)


# ---------------------------------------------------------------- FIRE MISSION (V)

func activate_v(id: String) -> Dictionary:
	if id != "ORV":
		return {"ok": false, "message": "NOT ORDNANCE", "cooldown": 0.0}
	_mission_cast += 1
	_mission_tell = 1.0
	_mission_scale = 1.0
	counters["missions"] = int(counters["missions"]) + 1
	return {"ok": true, "message": "FIRE MISSION", "cooldown": 0.0}


func _tick_mission(delta: float) -> void:
	if _mission_tell >= 0.0:
		_mission_tell -= delta
		if _mission_tell <= 0.0:
			_mission_tell = -1.0
			_mission_left = 1.0
			_mission_shells = 48 if has("ORV1") else 24
			_mission_tick = 0.0
	if _mission_left > 0.0:
		_mission_left = maxf(0.0, _mission_left - delta)
		_mission_tick += delta
		var per := 1.0 / float(48 if has("ORV1") else 24)
		while _mission_tick >= per and _mission_shells > 0:
			_mission_tick -= per
			_mission_shells -= 1
			_mission_shell()
		if _mission_left <= 0.0:
			if has("ORV3") and _mission_scale >= 1.0:
				_salvo_delay = 2.0
			else:
				runner.note_revelation_ended("ORV")
	if _salvo_delay >= 0.0:
		_salvo_delay -= delta
		if _salvo_delay <= 0.0:
			_salvo_delay = -1.0
			_mission_scale = 0.6
			_mission_left = 1.0
			_mission_shells = 48 if has("ORV1") else 24
			_mission_tick = 0.0
			counters["salvos"] = int(counters["salvos"]) + 1


func _mission_shell() -> void:
	var rect := runner.camera_rect()
	var at := Vector2.ZERO
	var enemies := runner.enemies_in_radius(rect.get_center(), rect.size.length() * 0.5)
	var occupied: Dictionary = {}
	for handle in enemies:
		var pos := runner.enemy_position(handle)
		if rect.has_point(pos):
			occupied[Vector2i(int(floor(pos.x / CELL)), int(floor(pos.y / CELL)))] = pos
	var picked := false
	if not occupied.is_empty():
		# Spread across groups before repeating a cell.
		var least := INF
		for cell in occupied.keys():
			var uses := int(_cell_use.get(cell, 0))
			if uses < least:
				least = uses
				at = occupied[cell]
				picked = true
		for cell in occupied.keys():
			if occupied[cell] == at:
				_cell_use[cell] = int(_cell_use.get(cell, 0)) + 1
	if has("ORV1") and (not picked or runner.rng().randf() < 0.5):
		at = rect.position + Vector2(runner.rng().randf() * rect.size.x, runner.rng().randf() * rect.size.y)
		picked = true
	if not picked:
		at = runner.player_position() + Vector2.from_angle(runner.rng().randf_range(0.0, TAU)) * 2.0 * AscensionRunner.R
	if has("ORV2"):
		var ahead := runner.player_position() + _heading * 1.5 * AscensionRunner.R
		if at.distance_to(ahead) <= 1.5 * AscensionRunner.R or (at - runner.player_position()).dot(_heading) > 0.0 and at.distance_to(runner.player_position()) < 3.0 * AscensionRunner.R:
			at = runner.player_position() - _heading * runner.rng().randf_range(1.0, 3.0) * AscensionRunner.R
	counters["mission_shells"] = int(counters["mission_shells"]) + 1
	var shell := call_shell(at, 3.0 * _mission_scale, "ORV", 0.25, PackedStringArray(["v"]), false, -_mission_cast, 0, false)
	if not shell.is_empty():
		shell["left"] = 0.2


# ---------------------------------------------------------------- HUD

func hud_state(slot: String) -> Dictionary:
	var state := {}
	if slot == "q":
		var live := coordinates.filter(func(c): return not bool(c["dormant"])).size()
		state["resource_value"] = float(live)
		state["resource_max"] = 3.0
		state["combat_text"] = "COORD %d/3  MINES %d" % [live, mines.size()] if has("OR02") else "COORD %d/3" % live
	elif slot == "v" and (_mission_tell >= 0.0 or _mission_left > 0.0):
		state["combat_text"] = "FIRE MISSION"
	return state


func collect_draw_points(out: Array) -> void:
	for mine in mines:
		out.append([mine["at"], 6.0 if float(mine["arm"]) <= 0.0 else 4.0, Color(1.0, 0.6, 0.3, 0.9 if float(mine["arm"]) <= 0.0 else 0.5)])
	for coord in coordinates:
		out.append([coord["at"], 14.0, Color(1.0, 0.9, 0.5, 0.3 if bool(coord["dormant"]) else 0.7)])
	for shell in shells:
		out.append([shell["at"], float(shell["radius"]) * _blast_radius_scale(), Color(1.0, 0.5, 0.3, 0.25)])
	for lane in _lanes:
		out.append([lane["from"], 2.0, Color(1.0, 0.7, 0.4, 0.4), lane["to"]])


func describe() -> Dictionary:
	var out := counters.duplicate()
	out["shells_pending"] = shells.size()
	out["mines_live"] = mines.size()
	out["coordinates"] = coordinates.size()
	return out
