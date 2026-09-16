extends AscensionEngine
class_name BarrageEngine
## Barrage: Heat, extra rounds, seeking fragments, ricochets, the Jam as an
## attack, Burst, Overload and SUPPRESSION.
##
## Vocabulary (V4): D = native hit damage, R = 80, L = 240. Heat 0-100: a
## native Ranged input adds 8; at 50/75 Heat firing rate +15%/+30% and one/two
## 0.4D side rounds per input; at 100 the weapon Jams for 1.2 s then rests at
## 20; after 0.35 s without firing it cools 25/s. Fragments are simulated here
## (the managed projectile pool is straight-line) and drawn by the runner.
##
## Review corrections applied: foreign Core strikes count as firing (F2);
## SUPPRESSION mirrors any Ranged Core strike; Hot Blood feeds Heat from
## Melee and Magic strikes; fragments seek the lowest-HP enemy in reach.

const HEAT_PER_INPUT := 8.0
const HEAT_PER_WITNESS := 4.0
const HEAT_PER_FOREIGN := 5.0
const HEAT_IDLE_BEFORE_COOL := 0.35
const HEAT_COOL_PER_SECOND := 25.0
const HEAT_JAM_SECONDS := 1.2
const HEAT_AFTER_JAM := 20.0
const TIERS_BASE: Array = [[50.0, 0.15, 1], [75.0, 0.30, 2]]
const TIERS_OVERCLOCK: Array = [[50.0, 0.15, 1], [75.0, 0.30, 2], [100.0, 0.45, 3], [150.0, 0.60, 4]]
const SIDE_ROUND_D := 0.4
const SIDE_ROUND_PP := 0.35
const FRAGMENT_SPEED := 520.0
const FRAGMENT_LIFE := 2.0
const FRAGMENT_SEEK_RANGE := 240.0
const FRAGMENT_HIT_PAD := 6.0
## Reacquisitions per frame. A fragment whose target died keeps flying on its
## last heading and retries next frame when the budget is spent; with a
## 2 s life and 520 px/s it loses nothing but a few frames of steering. The
## 2026-09-15 audit measured unbounded reacquisition at 50-150 ms per frame.
const FRAGMENT_RETARGETS_PER_FRAME := 48
const BULLET_SPEED := 900.0
const BULLET_RANGE := 520.0

var heat: float = 0.0
var heat_cap: float = 100.0
var _idle: float = 99.0
var jam_left: float = 0.0
var _jams_recent: Array[float] = []
var _vents_recent: Array[float] = []
var _clock: float = 0.0
var _tier: int = 0
var _tier_armed: Dictionary = {}     # tier threshold -> re-armed (Bigger Magazine)
var stored_rounds: int = 0
var _strikes: int = 0                # Core strike activations (Fifth Shot / Crossfire counters)
var _fifth_armed: bool = false
var _crossfire_angle: float = 0.0
var _volley: int = 0
var _hot_rounds_volley: int = -1
var _cool_head_shot: bool = false
var _quadrants_used: Dictionary = {}
var _quadrant_anchor: Vector2 = Vector2.ZERO
var _patches: Array = []            # [position, time_left]
var fragments: Array = []           # {pos, vel, target, damage, life, pp, bounces, root, gen}
var _pending_fragments: Array = []
var _fragment_cost: Dictionary = {"fragment_usec": 0, "retargets": 0, "retargets_deferred": 0, "fragments_live": 0, "fragments_pending": 0}

var burst_left: float = 0.0
var burst_total: float = 0.0
var _burst_scale: float = 1.0
var _burst_pp: float = 1.0
# Heat Beam (BRE1): Burst as a swept piercing beam.
var beam_left: float = 0.0
var _beam_tick: float = 0.0
var _beam_from: Vector2 = Vector2.ZERO
var _beam_to: Vector2 = Vector2.ZERO
var stationary_beam_left: float = 0.0
var _stationary_from: Vector2 = Vector2.ZERO
var _stationary_to: Vector2 = Vector2.ZERO
var _stationary_tick: float = 0.0
var _segment_scratch: Array[int] = []
var _segment_ts := PackedFloat32Array()
var _burst_extended: float = 0.0
var _burst_points: int = 0
var _burst_point_timer: float = 0.0
var _burst_kills: Dictionary = {}

var overload_ready_at: float = -INF
var _overload_volleys_left: int = 0
var _overload_timer: float = 0.0
var overload_recovery_left: float = 0.0
var _emergency_vent_left: float = 0.0

var suppression_left: float = 0.0
var _suppression_shots: int = 0
var _suppression_timer: float = 0.0
var _suppression_angle: float = 0.0
var _native_block_left: float = 0.0

var counters: Dictionary = {"side_rounds": 0, "fifth_shots": 0, "crossfire": 0, "hot_rounds": 0, "fragments": 0, "fragment_hits": 0, "ricochets": 0, "jams": 0, "loose_rounds": 0, "stored_fired": 0, "bursts": 0, "burst_rounds": 0, "overloads": 0, "overload_rounds": 0, "suppression_rounds": 0, "coolant": 0, "patches": 0, "hot_blood_rounds": 0}


func discipline() -> String:
	return "BR"


func refresh(active_ids: Dictionary) -> void:
	super.refresh(active_ids)
	heat_cap = 200.0 * runner.keystone_bonus() if has("BRK1") else 100.0
	heat = minf(heat, heat_cap)


## Projectile Life sink: friendly projectiles and fragments live longer.
func projectile_life_multiplier() -> float:
	if not has("BRS2"):
		return 1.0
	var r := float(rank("BRS2"))
	return 1.0 + 0.5 * r / (r + 100.0)


func claims_heat() -> bool:
	for id in ["BR01", "BR03", "BR04", "BR07", "BR08", "BR11", "BRQ", "BRA"]:
		if has(id):
			return true
	return false


func _tiers() -> Array:
	if not has("BRK1"):
		return TIERS_BASE
	var bonus := runner.keystone_bonus()
	if bonus == 1.0:
		return TIERS_OVERCLOCK
	# Commitment: the keystone's beneficial numbers grow 25% (counts round down).
	return [[50.0, 0.15, 1], [75.0, 0.30, 2], [100.0, 0.45 * bonus, int(3.0 * bonus)], [150.0, 0.60 * bonus, int(4.0 * bonus)]]


func tier_index() -> int:
	var index := 0
	for tier in _tiers():
		if heat >= float(tier[0]):
			index += 1
	return index


func tier_rate_bonus() -> float:
	var index := tier_index()
	return float(_tiers()[index - 1][1]) if index > 0 else 0.0


func tier_side_rounds() -> int:
	var index := tier_index()
	return int(_tiers()[index - 1][2]) if index > 0 else 0


func D() -> float:
	return runner.native_damage()


func jammed() -> bool:
	return jam_left > 0.0 or _emergency_vent_left > 0.0


# ---------------------------------------------------------------- tick

func tick(delta: float) -> void:
	_clock += delta
	_idle += delta
	if jam_left > 0.0:
		jam_left = maxf(0.0, jam_left - delta)
		runner.block_native_fire(jam_left)
		if jam_left <= 0.0:
			# The weapon rests at 20 and only starts cooling after the usual pause.
			heat = HEAT_AFTER_JAM
			_idle = 0.0
			_tier = tier_index()
	if _emergency_vent_left > 0.0:
		_emergency_vent_left = maxf(0.0, _emergency_vent_left - delta)
		runner.block_native_fire(_emergency_vent_left)
		if _emergency_vent_left <= 0.0:
			heat = 40.0
			_idle = 0.0
			_tier = tier_index()
	if _native_block_left > 0.0:
		_native_block_left = maxf(0.0, _native_block_left - delta)
		runner.block_native_fire(_native_block_left)
	if claims_heat() and not jammed() and suppression_left <= 0.0 and _idle >= HEAT_IDLE_BEFORE_COOL and heat > 0.0:
		_cool_head_check()
		heat = maxf(0.0, heat - HEAT_COOL_PER_SECOND * delta)
		_note_tier_change()
	_tick_patches(delta)
	_tick_burst(delta)
	_tick_overload(delta)
	_tick_suppression(delta)
	_tick_fragments(delta)
	if overload_recovery_left > 0.0:
		overload_recovery_left = maxf(0.0, overload_recovery_left - delta)
	if has("BRK2") and not jammed() and burst_left <= 0.0 and not Input.is_action_pressed(&"attack"):
		runner.fire_native(runner.aim_target())


# ---------------------------------------------------------------- Heat

func add_heat(amount: float, from_input: bool = true) -> void:
	if not claims_heat():
		return
	if suppression_left > 0.0 or jammed():
		return
	if has("BRS1"):
		var r := float(rank("BRS1"))
		amount *= 1.0 - 0.30 * r / (r + 75.0)
	if burst_left > 0.0:
		amount *= 2.0
	if from_input:
		_idle = 0.0
	var before := heat
	heat = minf(heat_cap, heat + amount)
	_note_tier_change()
	if has("BR11"):
		for threshold in [50.0, 75.0]:
			if before < threshold and heat >= threshold and not _tier_armed.get(threshold, false):
				_tier_armed[threshold] = true
				stored_rounds = mini(12, stored_rounds + 3)
	if has("BRK1"):
		if heat >= 180.0 and _emergency_vent_left <= 0.0:
			_emergency_vent()
	elif heat >= 100.0:
		_jam()


func _note_tier_change() -> void:
	var now := tier_index()
	if now != _tier:
		if now > _tier:
			runner.add_action_charge(1.0)
			if BattleText != null:
				BattleText.popup(runner.player_position(), "HEAT %d" % int(heat), Color(1.0, 0.6, 0.2, 1.0), 1.1)
		_tier = now
	if has("BR11"):
		for threshold in [50.0, 75.0]:
			if heat < threshold:
				_tier_armed[threshold] = false


func _jam() -> void:
	counters["jams"] = int(counters["jams"]) + 1
	runner.add_action_charge(2.0)
	jam_left = HEAT_JAM_SECONDS
	runner.block_native_fire(jam_left)
	_jams_recent.append(_clock)
	if BattleText != null:
		BattleText.popup(runner.player_position(), "JAM", Color(1.0, 0.3, 0.2, 1.0), 1.4)
	var rounds := 12 if (has("BR08") or has("BRF2")) else 0
	var backfire := has("BRF2")
	if backfire:
		rounds *= 2
		runner.pay_health(0.05 * float(runner.player().get("hp")), &"backfire")
	if rounds > 0:
		_radial_volley(runner.player_position(), rounds, 0.6 * D(), 0.4, "BR08", "loose")
		counters["loose_rounds"] = int(counters["loose_rounds"]) + rounds
	if stored_rounds > 0:
		_radial_volley(runner.player_position(), stored_rounds, 0.7 * D(), 0.4, "BR11", "stored")
		counters["stored_fired"] = int(counters["stored_fired"]) + stored_rounds
		stored_rounds = 0
	if has("BRC"):
		if backfire:
			_overload()
		elif not has("BRF1") and not has("BRK1") and _recent_count(_jams_recent, 10.0) >= 3:
			_overload()


func _emergency_vent() -> void:
	_emergency_vent_left = 1.2
	runner.block_native_fire(_emergency_vent_left)
	if BattleText != null:
		BattleText.popup(runner.player_position(), "VENT", Color(1.0, 0.5, 0.2, 1.0), 1.3)
	if has("BRC"):
		_overload()


## Cool Head: stopping fire in the 65-80 band vents to 20 and arms a +1D shot.
func _cool_head_check() -> void:
	if not has("BRF1") or _idle < HEAT_IDLE_BEFORE_COOL or _idle > HEAT_IDLE_BEFORE_COOL + 0.05:
		return
	if heat >= 65.0 and heat <= 80.0:
		_vent(20.0)
		_cool_head_shot = true
		_vents_recent.append(_clock)
		if has("BRC") and _recent_count(_vents_recent, 10.0) >= 3:
			_vents_recent.clear()
			_overload()


## A deliberate vent (Cool Head, Burst completion): stored rounds fire at aim.
func _vent(to: float) -> void:
	runner.add_action_charge(2.0)
	heat = minf(heat, to)
	_note_tier_change()
	if stored_rounds > 0:
		_fan_volley(runner.player_position(), runner.aim_target(), stored_rounds, 0.7 * D(), 0.4, "BR11", "stored", 40.0)
		counters["stored_fired"] = int(counters["stored_fired"]) + stored_rounds
		stored_rounds = 0


func _recent_count(times: Array[float], window: float) -> int:
	while not times.is_empty() and _clock - times[0] > window:
		times.remove_at(0)
	return times.size()


# ---------------------------------------------------------------- native strikes

func witness_tags(core: String) -> PackedStringArray:
	if core != "ranged":
		return PackedStringArray()
	return PackedStringArray(["volley:%d" % (_volley + 1)])


## A Witness Shot heats the weapon (4) and advances the strike counters at
## full weight (review F12).
func on_witness_strike(core: String, origin: Vector2, target: Vector2) -> void:
	if core != "ranged":
		return
	_volley += 1
	add_heat(HEAT_PER_WITNESS)
	var dir := (target - origin).normalized()
	_core_strike(origin, dir if dir != Vector2.ZERO else Vector2.RIGHT, 1.0)


## Kill Feed (MR2): a fragment execution grants one extra fragment (Ranged).
func extra_fragment(position: Vector2, victim: int) -> void:
	_spawn_fragment(position, 0.6 * D(), 0.4, 1 if has("BR10") else 0, "MR2", 2, victim)


func decorate_native_profile(profile: HitProfileAdapter) -> void:
	var tags: PackedStringArray = profile.get_meta(AscensionTags.META_KEY, PackedStringArray())
	tags.append("volley:%d" % (_volley + 1))
	tags = AscensionTags.with_flag(tags, "core_strike")
	if _cool_head_shot:
		profile.damage += D()
		_cool_head_shot = false
	profile.set_meta(AscensionTags.META_KEY, tags)


func on_native_fire(style: String, origin: Vector2, target: Vector2, _power: float, _haste: float) -> void:
	_volley += 1
	var dir := (target - origin).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	if style == "ranged":
		add_heat(HEAT_PER_INPUT)
		_core_strike(origin, dir, 1.0)
		if suppression_left > 0.0 and not has("BRV2"):
			_suppression_mirror(target)
		if burst_left > 0.0 and has("BRQ4") and not has("BRE2"):
			var perp := Vector2(-dir.y, dir.x)
			for side in [-1.0, 1.0]:
				_fire(origin + perp * side * 40.0, dir, 0.5 * D(), 0.35, "BRQ4", "bullet", 1, PackedStringArray(["core_strike"]))
	elif has("BRA"):
		# Hot Blood: Melee and Magic Core strikes heat the weapon too.
		add_heat(HEAT_PER_FOREIGN)
		_core_strike(origin, dir, 1.0)
		var rounds := tier_side_rounds()
		for i in range(rounds):
			if style == "melee":
				runner.spawn_slash(origin + dir * 10.0, dir, SIDE_ROUND_D * D(), AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "BRA", "slash", 1, SIDE_ROUND_PP))
			else:
				runner.spawn_impact(target, SIDE_ROUND_D * D(), AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "BRA", "impact", 1, SIDE_ROUND_PP))
			counters["hot_blood_rounds"] = int(counters["hot_blood_rounds"]) + 1


## One Core strike activation: side rounds, Fifth Shot and Crossfire counters.
func _core_strike(origin: Vector2, dir: Vector2, coefficient: float) -> void:
	var rounds := tier_side_rounds()
	if rounds > 0 and claims_heat():
		for i in range(rounds):
			var spread := deg_to_rad(8.0) * (float(i) - float(rounds - 1) * 0.5)
			_fire(origin, dir.rotated(spread), SIDE_ROUND_D * D(), SIDE_ROUND_PP, "BR01", "side", 1)
			counters["side_rounds"] = int(counters["side_rounds"]) + 1
	if has("BR02"):
		if _fifth_armed:
			_fifth_armed = false
			for spread in [-0.12, 0.12]:
				_fire(origin, dir.rotated(spread), 0.6 * D(), 0.5, "BR02", "bullet", 1)
			counters["fifth_shots"] = int(counters["fifth_shots"]) + 1
	_strikes += 1 if coefficient >= 1.0 else 0
	if has("BR02") and _strikes % 5 == 0 and _strikes > 0:
		_fifth_armed = true
	if has("BR06") and _strikes % 3 == 0 and _strikes > 0:
		_crossfire_shot(0.8 * D(), 0.5, "BR06")


func _crossfire_shot(damage: float, pp: float, root: String) -> void:
	_crossfire_angle += deg_to_rad(137.5)
	var from := runner.camera_edge_point(_crossfire_angle)
	var to := runner.aim_target()
	_fire(from, (to - from).normalized(), damage, pp, root, "crossfire", 1, PackedStringArray(), {"max_range": 1600.0})
	counters["crossfire"] = int(counters["crossfire"]) + 1


# ---------------------------------------------------------------- hits and kills

func on_hit(hit: Dictionary) -> void:
	if hit["core"] != "ranged":
		return
	var tags: PackedStringArray = hit["tags"]
	var core_strike := AscensionTags.has_flag(tags, "core_strike")
	var handle := int(hit["handle"])
	# Hot Rounds: the first Core projectile impact of a volley above 50 Heat.
	if has("BR04") and core_strike and heat > 50.0 and hit["path"] == "bullet":
		var volley := int(AscensionTags.value_of(tags, "volley"))
		if volley != _hot_rounds_volley:
			_hot_rounds_volley = volley
			_hot_rounds(hit["position"])
	# Ricochet: a Core projectile bounces once to a different enemy within 2R.
	if core_strike and hit["path"] == "bullet" and (has("BR09") or (has("BRQ3") and hit["root"] == "BRQ")):
		_ricochet(hit, handle)
	# Cluster Rounds: a ricochet impact throws two non-bouncing fragments.
	if has("BR12") and hit["path"] == "ricochet":
		for _i in range(2):
			_spawn_fragment(hit["position"], 0.5 * D(), 0.3, 0, "BR12", int(hit["gen"]) + 1, handle)


func _hot_rounds(position: Vector2) -> void:
	counters["hot_rounds"] = int(counters["hot_rounds"]) + 1
	var radius := AscensionRunner.R * 0.5
	runner.spawn_impact(position, 0.5 * D(), AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "BR04", "impact", 1, 0.0), radius)
	var tick_damage := 0.2 * D() * 0.5
	for victim in runner.enemies_in_radius(position, radius):
		EnemyStatus.apply_burn(victim, 1, 3.0, 0.5, tick_damage, runner.player())


func _ricochet(hit: Dictionary, victim: int) -> void:
	if int(hit["gen"]) >= 1 and hit["root"] != "BRQ":
		return
	var next := runner.nearest_enemy(hit["position"], 2.0 * AscensionRunner.R, victim)
	if next == 0 or not runner.enemy_alive(next):
		return
	var hit_position: Vector2 = hit["position"]
	var dir: Vector2 = (runner.enemy_position(next) - hit_position).normalized()
	var damage := 0.7 * float(hit["applied"] if hit["applied"] > 0.0 else D())
	_fire(hit["position"], dir, maxf(damage, 0.7 * D() * 0.5), 0.6, "BR09", "ricochet", int(hit["gen"]) + 1)
	counters["ricochets"] = int(counters["ricochets"]) + 1


func on_kill(hit: Dictionary, _context: RefCounted) -> void:
	var handle := int(hit["handle"])
	var position: Vector2 = hit["position"]
	# Wildfire (RM5): a Burn kill rolls 25% for three burning fragments.
	if has("RM5") and hit["family"] == "status" and EnemyStatus.has_status(handle, &"burn"):
		if runner.roll(&"wildfire", 0.25, 1.0):
			counters["wildfires"] = int(counters.get("wildfires", 0)) + 1
			for _i in range(3):
				_spawn_fragment(position, 0.5 * D(), 0.4, 0, "RM5", int(hit["gen"]) + 1, handle, true)
	if hit["core"] != "ranged":
		return
	if has("BR05"):
		var bounces := 1 if has("BR10") else 0
		var cast := AscensionTags.value_of(hit["tags"], "cast")
		if cast.is_empty():
			cast = "seed:%d" % handle
		for _i in range(2):
			_spawn_fragment(position, 0.6 * D(), 0.4, bounces, "BR05", int(hit["gen"]) + 1, handle, false, cast)
	if has("BR03"):
		_patches.append([position, 2.0])
		counters["patches"] = int(counters["patches"]) + 1
	if has("BR07"):
		_coolant(position)
	if burst_left > 0.0 and has("BRQ7") and not _burst_kills.has(handle) and not AscensionTags.has_flag(hit["tags"], "v"):
		_burst_kills[handle] = true
		if _burst_extended < 2.0:
			var extra := minf(0.08, 2.0 - _burst_extended)
			_burst_extended += extra
			burst_left += extra
			burst_total += extra


func _coolant(position: Vector2) -> void:
	var player_pos := runner.player_position()
	if _quadrant_anchor.distance_to(player_pos) >= AscensionRunner.L:
		_quadrant_anchor = player_pos
		_quadrants_used.clear()
	var rel := position - player_pos
	var quadrant := (0 if rel.x >= 0.0 else 1) + (0 if rel.y >= 0.0 else 2)
	if _quadrants_used.has(quadrant):
		return
	_quadrants_used[quadrant] = true
	heat = maxf(0.0, heat - 10.0)
	_note_tier_change()
	counters["coolant"] = int(counters["coolant"]) + 1


func _tick_patches(delta: float) -> void:
	if _patches.is_empty():
		return
	var player_pos := runner.player_position()
	for i in range(_patches.size() - 1, -1, -1):
		var patch: Array = _patches[i]
		patch[1] = float(patch[1]) - delta
		if float(patch[1]) <= 0.0:
			_patches.remove_at(i)
		elif (patch[0] as Vector2).distance_to(player_pos) <= 36.0:
			heat = maxf(0.0, heat - 15.0)
			_note_tier_change()
			_patches.remove_at(i)


# ---------------------------------------------------------------- fragments

func _spawn_fragment(position: Vector2, damage: float, pp: float, bounces: int, root: String, generation: int, exclude: int, burning: bool = false, cast: String = "") -> void:
	var target := runner.lowest_hp_enemy_in_radius(position, FRAGMENT_SEEK_RANGE, exclude)
	var angle := runner.rng().randf_range(0.0, TAU)
	_pending_fragments.append({
		"burning": burning,
		"cast": cast,
		"life_scale": projectile_life_multiplier(),
		"pos": position,
		"vel": Vector2.from_angle(angle) * FRAGMENT_SPEED,
		"target": target,
		"damage": damage,
		"life": FRAGMENT_LIFE * projectile_life_multiplier(),
		"pp": pp,
		"bounces": bounces,
		"root": root,
		"gen": generation,
		"last": exclude,
		"suppression": suppression_left > 0.0,
	})
	counters["fragments"] = int(counters["fragments"]) + 1


func _tick_fragments(delta: float) -> void:
	var started := Time.get_ticks_usec()
	_fragment_cost["retargets"] = 0
	_fragment_cost["retargets_deferred"] = 0
	_fragment_cost["fragments_pending"] = _pending_fragments.size()
	if not _pending_fragments.is_empty():
		fragments.append_array(_pending_fragments)
		_pending_fragments.clear()
	_fragment_cost["fragments_live"] = fragments.size()
	if fragments.is_empty():
		_fragment_cost["fragment_usec"] = Time.get_ticks_usec() - started
		return
	var retargets_left := FRAGMENT_RETARGETS_PER_FRAME
	for i in range(fragments.size() - 1, -1, -1):
		var fragment: Dictionary = fragments[i]
		fragment["life"] = float(fragment["life"]) - delta
		if float(fragment["life"]) <= 0.0:
			fragments.remove_at(i)
			continue
		var target := int(fragment["target"])
		if not runner.enemy_alive(target):
			if retargets_left > 0:
				retargets_left -= 1
				_fragment_cost["retargets"] = int(_fragment_cost["retargets"]) + 1
				target = runner.lowest_hp_enemy_in_radius(fragment["pos"], FRAGMENT_SEEK_RANGE, int(fragment["last"]))
				fragment["target"] = target
			else:
				_fragment_cost["retargets_deferred"] = int(_fragment_cost["retargets_deferred"]) + 1
				target = 0
		var pos: Vector2 = fragment["pos"]
		var vel: Vector2 = fragment["vel"]
		if target != 0:
			var to_target := runner.enemy_position(target) - pos
			var desired := to_target.normalized() * FRAGMENT_SPEED
			vel = vel.lerp(desired, clampf(delta * 10.0, 0.0, 1.0))
			var reach := EnemyWorld.get_collision_radius(target) + FRAGMENT_HIT_PAD
			if to_target.length() <= maxf(reach, FRAGMENT_SPEED * delta):
				_fragment_hit(fragment, target)
				if int(fragment["bounces"]) <= 0:
					fragments.remove_at(i)
					continue
				fragment["bounces"] = int(fragment["bounces"]) - 1
				fragment["damage"] = float(fragment["damage"]) * 0.7
				fragment["pp"] = 0.3
				fragment["last"] = target
				fragment["target"] = runner.nearest_enemy(runner.enemy_position(target), 2.0 * AscensionRunner.R, target)
				fragment["pos"] = runner.enemy_position(target)
				continue
		fragment["vel"] = vel
		fragment["pos"] = pos + vel * delta
	_fragment_cost["fragment_usec"] = Time.get_ticks_usec() - started


func _fragment_hit(fragment: Dictionary, target: int) -> void:
	counters["fragment_hits"] = int(counters["fragment_hits"]) + 1
	var flags := PackedStringArray()
	if bool(fragment["suppression"]):
		flags.append("v")
	var tags := AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, String(fragment["root"]), "fragment", int(fragment["gen"]), float(fragment["pp"]), flags)
	if not String(fragment.get("cast", "")).is_empty():
		tags.append("cast:" + String(fragment["cast"]))
	if bool(fragment.get("burning", false)):
		EnemyStatus.apply_burn(target, 1, 3.0, 0.5, 0.2 * D() * 0.5, runner.player())
	runner.damage_enemy(target, float(fragment["damage"]), tags)
	if has("BRE2") and burst_left > 0.0 and int(fragment["bounces"]) > 0:
		_burst_points = mini(12, _burst_points + 1) if (int(counters["fragment_hits"]) % 3 == 0) else _burst_points


func collect_draw_points(out: Array) -> void:
	collect_beam_points(out)
	for fragment in fragments:
		out.append([fragment["pos"], 3.5, Color(1.0, 0.75, 0.3, 0.95)])
	for patch in _patches:
		out.append([patch[0], 14.0, Color(0.4, 0.8, 1.0, 0.25)])


# ---------------------------------------------------------------- generated rounds

func _fire(origin: Vector2, dir: Vector2, damage: float, pp: float, root: String, path: String, generation: int, flags: PackedStringArray = PackedStringArray(), overrides: Dictionary = {}) -> void:
	if suppression_left > 0.0 and not flags.has("v"):
		flags = flags.duplicate()
		flags.append("v")
	var tags := AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, root, path, generation, pp, flags)
	var options := {"speed": BULLET_SPEED, "max_range": BULLET_RANGE}
	options.merge(overrides, true)
	runner.spawn_bullet(origin, dir, damage, tags, options)


func _radial_volley(origin: Vector2, count: int, damage: float, pp: float, root: String, path: String) -> void:
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		_fire(origin, Vector2.from_angle(angle), damage, pp, root, path, 1)


func _fan_volley(origin: Vector2, target: Vector2, count: int, damage: float, pp: float, root: String, path: String, fan_degrees: float) -> void:
	var dir := (target - origin).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	for i in range(count):
		var t := (float(i) / float(maxi(count - 1, 1))) - 0.5
		_fire(origin, dir.rotated(deg_to_rad(fan_degrees) * t), damage, pp, root, path, 1)


# ---------------------------------------------------------------- Burst (Q)

func activate_q(id: String) -> Dictionary:
	if id != "BRQ":
		return {"ok": false, "message": "NOT BARRAGE", "cooldown": 0.0}
	if jammed():
		return {"ok": false, "message": "JAMMED", "cooldown": 0.0}
	if burst_left > 0.0 or beam_left > 0.0:
		return _cancel_burst()
	burst_total = 3.0 if has("BRQ1") else 2.0
	_burst_scale = runner.q_scale()
	_burst_pp = runner.q_proc_scale()
	if has("BRE1"):
		# Heat Beam: the Burst is a swept piercing beam instead of a firing-rate window.
		beam_left = burst_total
		_beam_tick = 0.0
		counters["bursts"] = int(counters["bursts"]) + 1
		return {"ok": true, "message": "HEAT BEAM", "cooldown": 8.0}
	burst_left = burst_total
	_burst_extended = 0.0
	_burst_kills.clear()
	_burst_points = 3 if has("BRE2") else 0
	_burst_point_timer = 0.0
	counters["bursts"] = int(counters["bursts"]) + 1
	return {"ok": true, "message": "BURST", "cooldown": 8.0}


func q_active(id: String) -> bool:
	return id == "BRQ" and (burst_left > 0.0 or beam_left > 0.0)


func _cancel_burst() -> Dictionary:
	if beam_left > 0.0:
		# Releasing the beam in the Cool Head band leaves a stationary beam.
		beam_left = 0.0
		if heat >= 65.0 and heat <= 80.0:
			stationary_beam_left = 1.0
			_stationary_from = _beam_from
			_stationary_to = _beam_to
			_stationary_tick = 0.0
		return {"ok": false, "message": "RELEASED", "cooldown": 0.0}
	var first_half := burst_left > burst_total * 0.5
	burst_left = 0.0
	_burst_points = 0
	if has("BRQ6") and first_half:
		heat = maxf(0.0, heat - 30.0)
		_note_tier_change()
		runner.q_cooldown_left = maxf(0.0, runner.q_cooldown_left * 0.5)
		return {"ok": false, "message": "STOPPED", "cooldown": 0.0}
	return {"ok": false, "message": "CANCELLED", "cooldown": 0.0}


func _tick_beam(delta: float) -> void:
	if beam_left > 0.0:
		beam_left = maxf(0.0, beam_left - delta)
		_beam_from = runner.player_position()
		_beam_to = _beam_from + (runner.aim_target() - _beam_from).normalized() * 5.0 * AscensionRunner.L
		_beam_tick += delta
		while _beam_tick >= 0.15:
			_beam_tick -= 0.15
			_beam_strike(_beam_from, _beam_to, 0.75 * D() * _burst_scale)
			add_heat(5.0, false)
	if stationary_beam_left > 0.0:
		stationary_beam_left = maxf(0.0, stationary_beam_left - delta)
		_stationary_tick += delta
		while _stationary_tick >= 0.15:
			_stationary_tick -= 0.15
			_beam_strike(_stationary_from, _stationary_to, 0.375 * D() * _burst_scale)


func _beam_strike(from: Vector2, to: Vector2, damage: float) -> void:
	var count := EnemyCombat.enemies_on_segment(from, to, 10.0, 0, _segment_scratch, _segment_ts)
	var flags := PackedStringArray(["core_strike"])
	if suppression_left > 0.0:
		flags.append("v")
	var tags := AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "BRQ", "beam", 1, 0.2 * _burst_pp, flags)
	for i in range(count):
		runner.damage_enemy(_segment_scratch[i], damage, tags)
	counters["beam_ticks"] = int(counters.get("beam_ticks", 0)) + 1


func _tick_burst(delta: float) -> void:
	_tick_beam(delta)
	if burst_left <= 0.0:
		return
	burst_left = maxf(0.0, burst_left - delta)
	if has("BRE2") and _burst_points > 0:
		_burst_point_timer += delta
		while _burst_point_timer >= 0.25:
			_burst_point_timer -= 0.25
			var aim := runner.aim_target()
			for i in range(_burst_points):
				var angle := _clock * 1.5 + TAU * float(i) / float(_burst_points)
				var from := runner.player_position() + Vector2.from_angle(angle) * 48.0
				_fire(from, (aim - from).normalized(), 0.5 * D() * _burst_scale, 0.7 * _burst_pp, "BRQ", "bullet", 1, PackedStringArray(["core_strike"]))
				counters["burst_rounds"] = int(counters["burst_rounds"]) + 1
	if burst_left <= 0.0:
		_complete_burst()


func _complete_burst() -> void:
	var origin := runner.player_position()
	var aim := runner.aim_target()
	var heat_snapshot := heat
	var extra := 0
	if has("BRQ5"):
		extra = int(heat_snapshot / 5.0)
	if has("BRE2"):
		var per_point := 4
		var rounds := _burst_points * per_point + extra
		_radial_volley(origin, rounds, 0.5 * D(), 0.3, "BRQ", "bullet")
		counters["burst_rounds"] = int(counters["burst_rounds"]) + rounds
		_burst_points = 0
		jam_left = 1.5
		runner.block_native_fire(jam_left)
		heat = HEAT_AFTER_JAM
	else:
		_fan_volley(origin, aim, 12, 0.6 * D() * _burst_scale, 0.7 * _burst_pp, "BRQ", "bullet", 50.0)
		counters["burst_rounds"] = int(counters["burst_rounds"]) + 12
		if extra > 0:
			_radial_volley(origin, extra, 0.5 * D(), 0.3, "BRQ5", "bullet")
			counters["burst_rounds"] = int(counters["burst_rounds"]) + extra
		_vent(20.0)
	if has("BRQ2"):
		runner.spawn_impact(origin, 2.0 * D(), AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "BRQ2", "impact", 1, 0.3), 2.0 * AscensionRunner.R)
		for victim in runner.enemies_in_radius(origin, 2.0 * AscensionRunner.R):
			EnemyStatus.apply_burn(victim, 1, 3.0, 0.5, 0.1 * D(), runner.player())
		heat = 0.0
		_note_tier_change()


# ---------------------------------------------------------------- Overload

func _overload() -> void:
	if overload_recovery_left > 0.0 or _overload_volleys_left > 0:
		return
	counters["overloads"] = int(counters["overloads"]) + 1
	_overload_volleys_left = 4
	_overload_timer = 0.0
	overload_recovery_left = 8.0
	runner.note_catastrophe("BRC")
	if BattleText != null:
		BattleText.popup(runner.player_position(), "OVERLOAD", Color(1.0, 0.4, 0.1, 1.0), 1.6)


func _tick_overload(delta: float) -> void:
	if _overload_volleys_left <= 0:
		return
	_overload_timer -= delta
	# A long frame still delivers every volley it covers, 0.15 s apart.
	while _overload_timer <= 0.0 and _overload_volleys_left > 0:
		_overload_timer += 0.15
		_overload_volleys_left -= 1
		_radial_volley(runner.player_position(), 12, 0.8 * D(), 0.4, "BRC", "bullet")
		counters["overload_rounds"] = int(counters["overload_rounds"]) + 12
		if has("BR06"):
			_crossfire_shot(0.8 * D(), 0.4, "BRC")


# ---------------------------------------------------------------- SUPPRESSION (V)

func activate_v(id: String) -> Dictionary:
	if id != "BRV":
		return {"ok": false, "message": "NOT BARRAGE", "cooldown": 0.0}
	suppression_left = 5.0
	_suppression_shots = 0
	_suppression_timer = 0.0
	_suppression_angle = runner.rng().randf_range(0.0, TAU)
	return {"ok": true, "message": "SUPPRESSION", "cooldown": 0.0}


func _gun_count() -> int:
	return 6 if has("BRV1") else 3


func _suppression_mirror(target: Vector2) -> void:
	var guns := _gun_count()
	var damage := (0.6 if has("BRV1") else 0.8) * D()
	for i in range(guns):
		var angle := _suppression_angle + TAU * float(i) / float(guns)
		var from := runner.camera_edge_point(angle)
		_fire(from, (target - from).normalized(), damage, 0.4, "BRV", "bullet", 1, PackedStringArray(["v"]), {"max_range": 1600.0})
		_suppression_shots += 1
		counters["suppression_rounds"] = int(counters["suppression_rounds"]) + 1


func _tick_suppression(delta: float) -> void:
	if suppression_left <= 0.0:
		return
	suppression_left = maxf(0.0, suppression_left - delta)
	_suppression_angle += delta * 0.6
	if has("BRV2"):
		_suppression_timer += delta
		while _suppression_timer >= 0.25:
			_suppression_timer -= 0.25
			_suppression_mirror(runner.aim_target())
	if suppression_left <= 0.0:
		runner.note_revelation_ended("BRV")
	if suppression_left <= 0.0 and has("BRV3"):
		var rounds := mini(60, _suppression_shots / 4)
		if rounds > 0:
			_radial_volley(runner.player_position(), rounds, D(), 0.4, "BRV3", "bullet")
		_native_block_left = 1.5
		runner.block_native_fire(_native_block_left)
		if has("BRC") and overload_recovery_left <= 0.0:
			_overload()


# ---------------------------------------------------------------- multipliers and HUD

func haste_multiplier(core: String) -> float:
	if not claims_heat():
		return 1.0
	if core != "ranged" and not has("BRA"):
		return 1.0
	var rate := 1.0 + tier_rate_bonus()
	if burst_left > 0.0:
		rate *= 2.0
	return rate


func collect_beam_points(out: Array) -> void:
	if beam_left > 0.0:
		out.append([_beam_from, 6.0, Color(1.0, 0.55, 0.2, 0.85), _beam_to])
	if stationary_beam_left > 0.0:
		out.append([_stationary_from, 4.0, Color(1.0, 0.7, 0.3, 0.6), _stationary_to])


func move_speed_multiplier() -> float:
	var mul := 1.0
	if burst_left > 0.0 and has("BRQ1"):
		mul *= 0.75
	if has("BRK2") and heat > 75.0 and _idle < HEAT_IDLE_BEFORE_COOL:
		mul *= 0.8
	return mul


func damage_taken_multiplier() -> float:
	return 1.25 if has("BRK1") and heat > 100.0 else 1.0


func hud_state(slot: String) -> Dictionary:
	var state := {}
	if slot == "q":
		state["resource_value"] = heat
		state["resource_max"] = heat_cap
		if jammed():
			state["combat_text"] = "JAM"
		elif beam_left > 0.0:
			state["combat_text"] = "BEAM %.1fs" % beam_left
		elif burst_left > 0.0:
			state["combat_text"] = "BURST %.1fs" % burst_left
		else:
			state["combat_text"] = "HEAT %d" % int(heat) + (" T%d" % tier_index() if tier_index() > 0 else "")
	elif slot == "v" and suppression_left > 0.0:
		state["combat_text"] = "SUPPRESSION %.1fs" % suppression_left
	return state


func frame_cost() -> Dictionary:
	return _fragment_cost


func describe() -> Dictionary:
	var out := counters.duplicate()
	out["heat"] = heat
	out["tier"] = tier_index()
	out["jammed"] = jammed()
	out["fragments_live"] = fragments.size()
	out["stored_rounds"] = stored_rounds
	out["burst_left"] = burst_left
	out["suppression_left"] = suppression_left
	return out
