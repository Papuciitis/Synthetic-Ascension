extends BarrageEngine
class_name BarrageEngineV5
## Ranged V5 Barrage (handoff 2026-09-25, spec §3): Spin Up replaces baseline
## Heat, Hot Core makes Heat an optional purchase, and the machine-gun path
## (Fifth Shot, Fragmentation, Crossfire, Kill Throttle, Vent Volley, Reserve
## Feed) works with no Heat bar, no Jam and no cooling chore.
##
## The V4 parent supplies fragments, generated rounds, Suppression, Overload
## volleys and Heat Beam / Bullet Hell; this engine replaces the resource
## model, counters and Q around them. V4's Heat/Jam handlers are neutralized
## by overriding every path that reached them.

# ---- Spin Up (BR01) ----
const SPIN_TABLE: Array = [
	# [stage time 1..3, rate bonus 1..3]
	[[0.40, 1.20, 2.40], [0.15, 0.35, 0.60]],
	[[0.35, 1.00, 2.00], [0.15, 0.40, 0.70]],
	[[0.30, 0.80, 1.60], [0.20, 0.45, 0.80]],
]
const SPIN_PAUSE_HOLD := 0.35
const SPIN_DECAY_AFTER := 0.75
const SPIN_DECAY_STEP := 0.5

# ---- Hot Core (BR03) ----
const V5_HEAT_PER_INPUT := 8.0
const V5_HEAT_PER_WITNESS := 4.0
const V5_HEAT_BURST_EXTRA := 4.0
const MELTDOWN_SECONDS := 2.0
const MELTDOWN_REST := 40.0
const MELTDOWN_LOCKOUT := 3.0
const AURA_TICK := 0.25
## [threshold, side rounds, aura radius in R, aura D/s]
const HOT_TIERS: Array = [[50.0, 1, 0.5, 0.12], [75.0, 2, 1.0, 0.22]]
const MELTDOWN_TIER: Array = [3, 2.0, 0.35]
const OVERCLOCK_TIERS: Array = [[100.0, 3, 2.0, 0.35], [150.0, 4, 2.5, 0.50]]
const OVERCLOCK_VENT_AT := 180.0
const V5_SIDE_ROUND_D := 0.35
const V5_SIDE_ROUND_PP := 0.25

# ---- Burst (BRQ) ----
const BURST_ROUND_D := 0.45
const BURST_ROUND_PP := 0.35
const BURST_FAN_PP := 0.7
const BELT_FED_EXTEND := 0.10

var _spin_streak: float = 0.0
var _spin_last_input: float = -999.0
var _spin_drops_done: int = 0
var _spin_stage_shown: int = 0
var _strike_credit: float = 0.0          # weighted Core-strike bank (Fifth Shot)
var _crossfire_credit: float = 0.0
var _fifth_package: int = 0
var _meltdown_left: float = 0.0
var _meltdown_lockout_left: float = 0.0
var _meltdown_volley_done: bool = false
var _aura_tick_left: float = 0.0
var _hot_rounds_strikes: int = 0
var _hot_rounds_armed: bool = false
var _hot_volley_first_done: int = -1
var _reserve_credit: float = 0.0
var _reserve_release_inputs: int = 0
var _vent_inputs: int = 0
var _throttle_kills: int = 0
var _overdrive_left: float = 0.0
var _burst_inputs: int = 0
var _controlled_vent_cd: float = 0.0
var _stage3_inputs: Array[float] = []
var _rico_serial: int = 0
var _rico_visited: Dictionary = {}       # rico cast id -> {handle: true}
var _tier_crossed: Dictionary = {}       # threshold -> banked this cycle (BR11)
var _foreign_stage: int = 0
var _foreign_last_witness: float = -999.0
var _foreign_witness_count: int = 0
var _foreign_burst_parity: int = 0
var _burst_fragment_kills: int = 0


func refresh(active_ids: Dictionary) -> void:
	active = active_ids
	heat_cap = 200.0 * runner.keystone_bonus() if has("BRK1") else 100.0
	heat = minf(heat, heat_cap)


# ------------------------------------------------------------ ownership

## Only Hot Core owns Heat. Without BR03 there is no bar, aura, Meltdown or
## cooling loop anywhere in the discipline.
func claims_heat() -> bool:
	return has("BR03")


func _rank_row(id: String, cap: int) -> int:
	return clampi(rank(id), 1, cap) - 1


# ------------------------------------------------------------ Spin Up

func spin_stage() -> int:
	if not has("BR01") or runner.native_core != "ranged":
		return 0
	var times: Array = SPIN_TABLE[_rank_row("BR01", 3)][0]
	var stage := 0
	for threshold in times:
		if _spin_streak >= float(threshold):
			stage += 1
	return stage


func spin_bonus() -> float:
	var stage := spin_stage()
	if stage <= 0:
		return 0.0
	return float(SPIN_TABLE[_rank_row("BR01", 3)][1][stage - 1])


func _spin_note_input() -> void:
	if not has("BR01") or runner.native_core != "ranged":
		return
	var gap := _clock - _spin_last_input
	if gap <= SPIN_PAUSE_HOLD and gap > 0.0:
		_spin_streak += gap
	_spin_last_input = _clock
	_spin_drops_done = 0
	_note_spin_stage()


func _spin_decay(_delta: float) -> void:
	if not has("BR01") or _spin_streak <= 0.0:
		return
	var gap := _clock - _spin_last_input
	var grace := SPIN_DECAY_AFTER
	# Controlled Fire: stage 3 persists an extra 1.5 s before stage loss.
	if has("BRF1") and spin_stage() >= 3:
		grace += 1.5
	if gap <= grace:
		return
	# One stage per 0.5 s past the grace window; the grace itself never
	# counts toward the drop cadence.
	var drops_wanted := int((gap - grace) / SPIN_DECAY_STEP)
	while _spin_drops_done < drops_wanted and _spin_streak > 0.0:
		_spin_drops_done += 1
		var stage := spin_stage()
		var times: Array = SPIN_TABLE[_rank_row("BR01", 3)][0]
		_spin_streak = float(times[stage - 2]) if stage >= 2 else 0.0
	_note_spin_stage()


func _note_spin_stage() -> void:
	var stage := spin_stage()
	if stage == _spin_stage_shown:
		return
	if stage > _spin_stage_shown and BattleText != null:
		BattleText.popup(runner.player_position(), "SPIN %d" % stage, Color(0.55, 0.85, 1.0, 1.0), 1.0)
	_spin_stage_shown = stage
	if stage > 0:
		runner.add_action_charge(0.5)


## Spin Up is a sustained bonus under the shot-rate cap. Burst's x2 is the
## explicit post-cap window; it never applies here (finding A resolution).
func haste_multiplier(core: String) -> float:
	if core != "ranged":
		return 1.0
	return 1.0 + spin_bonus()


func post_cap_haste_multiplier() -> float:
	return 2.0 if burst_left > 0.0 and runner.native_core == "ranged" else 1.0


# ------------------------------------------------------------ Heat V5

## +8 per native input (+4 more during Burst), +4 per Witness shot, +5 for
## BRA strikes; nothing else generates Heat. No Burst doubling of gains.
func add_heat(amount: float, from_input: bool = true) -> void:
	if not claims_heat():
		return
	if suppression_left > 0.0:
		return
	if has("BRS1"):
		var r := float(rank("BRS1"))
		amount *= 1.0 - 0.30 * r / (r + 75.0)
	if from_input:
		_idle = 0.0
	if _meltdown_left > 0.0 and not has("BRK1"):
		return  # locked at 100; extra Heat is discarded, never banked
	var before := heat
	var ceiling := heat_cap
	if _meltdown_lockout_left > 0.0:
		ceiling = minf(ceiling, 99.0)
	heat = minf(ceiling, heat + amount)
	_note_tier_change_v5(before)
	if has("BRK1"):
		if heat >= OVERCLOCK_VENT_AT and _emergency_vent_left <= 0.0:
			_overclock_vent()
	elif heat >= 100.0 and _meltdown_left <= 0.0 and _meltdown_lockout_left <= 0.0:
		_begin_meltdown()


func _note_tier_change_v5(before: float) -> void:
	# Reserve Feed synergy: the first crossing of 50 and of 75 in each Heat
	# cycle banks +1 stored round; re-arms only after cooling below the tier.
	if has("BR11"):
		for threshold in [50.0, 75.0]:
			if before < threshold and heat >= threshold and not bool(_tier_crossed.get(threshold, false)):
				_tier_crossed[threshold] = true
				stored_rounds = mini(_reserve_cap(), stored_rounds + 1)
			elif heat < threshold:
				_tier_crossed[threshold] = false
	var now := tier_index()
	if now != _tier:
		if now > _tier:
			runner.add_action_charge(1.0)
			if BattleText != null:
				BattleText.popup(runner.player_position(), "HEAT %d" % int(heat), Color(1.0, 0.6, 0.2, 1.0), 1.1)
		_tier = now


func _tiers() -> Array:
	return OVERCLOCK_TIERS if has("BRK1") else HOT_TIERS


func tier_index() -> int:
	if not claims_heat():
		return 0
	var index := 0
	for tier in _tiers():
		if heat >= float(tier[0]):
			index += 1
	return index


func tier_side_rounds() -> int:
	if not claims_heat():
		return 0
	if _meltdown_left > 0.0 and not has("BRK1"):
		return int(MELTDOWN_TIER[0])
	var index := tier_index()
	return int(_tiers()[index - 1][1]) if index > 0 else 0


## [radius in world units, damage per second]; [0, 0] when no aura is active.
func aura_state() -> Array:
	if not claims_heat():
		return [0.0, 0.0]
	var radius_r := 0.0
	var dps_d := 0.0
	if _meltdown_left > 0.0 and not has("BRK1"):
		radius_r = float(MELTDOWN_TIER[1])
		dps_d = float(MELTDOWN_TIER[2])
	else:
		var index := tier_index()
		if index > 0:
			radius_r = float(_tiers()[index - 1][2])
			dps_d = float(_tiers()[index - 1][3])
	if dps_d <= 0.0:
		return [0.0, 0.0]
	if has("BRF2") and _meltdown_left > 0.0:
		dps_d *= 2.0
	return [radius_r * AscensionRunner.R, dps_d * D()]


func _begin_meltdown() -> void:
	_meltdown_left = MELTDOWN_SECONDS
	_meltdown_volley_done = false
	heat = 100.0
	counters["meltdowns"] = int(counters.get("meltdowns", 0)) + 1
	runner.add_action_charge(2.0)
	if BattleText != null:
		BattleText.popup(runner.player_position(), "MELTDOWN", Color(1.0, 0.35, 0.1, 1.0), 1.5)
	# Thermal Fury: Vent Volley fires twice its radial count at the
	# transition (once per Meltdown), or a built-in 8-round release.
	if has("BRF2") and not _meltdown_volley_done:
		_meltdown_volley_done = true
		if has("BR08"):
			_radial_volley(runner.player_position(), _vent_round_count() * 2, 0.6 * D(), 0.3, "BRF2", "loose")
		else:
			_radial_volley(runner.player_position(), 8, 0.6 * D(), 0.3, "BRF2", "loose")


func _end_meltdown() -> void:
	_meltdown_left = 0.0
	heat = MELTDOWN_REST
	_meltdown_lockout_left = MELTDOWN_LOCKOUT
	_idle = 0.0
	_tier = tier_index()
	if has("BRF2"):
		runner.pay_health(0.05 * float(runner.player().get("hp")), &"thermal_fury")
	if has("BRC"):
		_overload()


func _overclock_vent() -> void:
	counters["emergency_vents"] = int(counters.get("emergency_vents", 0)) + 1
	_radial_volley(runner.player_position(), 16, 0.6 * D(), 0.3, "BRK1", "loose")
	_emergency_vent_left = 0.60
	runner.block_native_fire(_emergency_vent_left)
	_meltdown_lockout_left = MELTDOWN_LOCKOUT
	runner.note_union_trigger("jam")
	if BattleText != null:
		BattleText.popup(runner.player_position(), "VENT", Color(1.0, 0.5, 0.2, 1.0), 1.3)
	if has("BRC"):
		_overload()


func damage_taken_multiplier() -> float:
	return 1.25 if has("BRK1") and heat > 100.0 else 1.0


# ------------------------------------------------------------ tick

func tick(delta: float) -> void:
	_clock += delta
	_idle += delta
	if _controlled_vent_cd > 0.0:
		_controlled_vent_cd = maxf(0.0, _controlled_vent_cd - delta)
	if _meltdown_lockout_left > 0.0:
		_meltdown_lockout_left = maxf(0.0, _meltdown_lockout_left - delta)
	_spin_decay(delta)
	if _overdrive_left > 0.0:
		_overdrive_left = maxf(0.0, _overdrive_left - delta)
	if _emergency_vent_left > 0.0:
		_emergency_vent_left = maxf(0.0, _emergency_vent_left - delta)
		runner.block_native_fire(_emergency_vent_left)
		if _emergency_vent_left <= 0.0:
			heat = MELTDOWN_REST
			_idle = 0.0
			_tier = tier_index()
	if jam_left > 0.0:
		# Only Bullet Hell's Evolution-specific shutdown reaches this in V5.
		jam_left = maxf(0.0, jam_left - delta)
		runner.block_native_fire(jam_left)
	if _native_block_left > 0.0:
		_native_block_left = maxf(0.0, _native_block_left - delta)
		runner.block_native_fire(_native_block_left)
	# Ordinary Meltdown: a 2 s locked window, then rest at 40.
	if _meltdown_left > 0.0 and not has("BRK1"):
		_meltdown_left = maxf(0.0, _meltdown_left - delta)
		if _meltdown_left <= 0.0:
			_end_meltdown()
	# Cooling: 25/s after 0.35 s without a qualifying input. Overclock cools
	# even inside sustained Meltdown; the ordinary 2 s window never cools.
	if claims_heat() and suppression_left <= 0.0 and _idle >= HEAT_IDLE_BEFORE_COOL and heat > 0.0:
		if _meltdown_left <= 0.0 or has("BRK1"):
			_controlled_fire_vent_check()
			heat = maxf(0.0, heat - HEAT_COOL_PER_SECOND * delta)
			_note_tier_change_v5(heat)
	_tick_aura(delta)
	_tick_burst(delta)
	_tick_overload(delta)
	_tick_suppression(delta)
	_tick_fragments(delta)
	if overload_recovery_left > 0.0:
		overload_recovery_left = maxf(0.0, overload_recovery_left - delta)
	while not _stage3_inputs.is_empty() and _clock - _stage3_inputs[0] > 8.0:
		_stage3_inputs.remove_at(0)
	if has("BRK2") and _emergency_vent_left <= 0.0 and jam_left <= 0.0 and burst_left <= 0.0 and not Input.is_action_pressed(&"attack"):
		runner.fire_native(runner.aim_target())


## The world-space radiant aura: damage every 0.25 s to enemies inside the
## displayed radius, Proc Power 0, never blast-tagged, never side-rounding.
func _tick_aura(delta: float) -> void:
	var state := aura_state()
	var radius := float(state[0])
	if radius <= 0.0:
		return
	_aura_tick_left -= delta
	if _aura_tick_left > 0.0:
		return
	_aura_tick_left = AURA_TICK
	var tick_damage := float(state[1]) * AURA_TICK
	var tags := AscensionTags.make("ranged", "status", "BR03", "radiant", 1, 0.0)
	for victim in runner.enemies_in_radius(runner.player_position(), radius):
		runner.damage_enemy(victim, tick_damage, tags)
	counters["aura_ticks"] = int(counters.get("aura_ticks", 0)) + 1


## Controlled Fire's optional vent: ceasing fire >= 0.35 s at 70-90 Heat
## vents to 40 and arms the next attack with +0.5D, once per 3 s.
func _controlled_fire_vent_check() -> void:
	if not has("BRF1") or not claims_heat() or _controlled_vent_cd > 0.0:
		return
	if _idle < HEAT_IDLE_BEFORE_COOL or _idle > HEAT_IDLE_BEFORE_COOL + 0.05:
		return
	if heat >= 70.0 and heat <= 90.0:
		heat = 40.0
		_tier = tier_index()
		_controlled_vent_cd = 3.0
		_cool_head_shot = true   # V4's armed +D hook; V5 arms +0.5D below
		_controlled_shot_half = true
		_vents_recent.append(_clock)
		counters["controlled_vents"] = int(counters.get("controlled_vents", 0)) + 1
		runner.note_union_trigger("jam")
		if has("BRC") and _recent_count(_vents_recent, 10.0) >= 3:
			_vents_recent.clear()
			_overload()


var _controlled_shot_half: bool = false


func decorate_native_profile(profile: HitProfileAdapter) -> void:
	var tags: PackedStringArray = profile.get_meta(AscensionTags.META_KEY, PackedStringArray())
	tags.append("volley:%d" % (_volley + 1))
	tags = AscensionTags.with_flag(tags, "core_strike")
	if _cool_head_shot:
		profile.damage += (0.5 * D()) if _controlled_shot_half else D()
		_cool_head_shot = false
		_controlled_shot_half = false
	if has("BRF1") and spin_stage() >= 3:
		profile.speed *= 1.25
	profile.set_meta(AscensionTags.META_KEY, tags)


# ------------------------------------------------------------ native strikes

func on_native_fire(style: String, origin: Vector2, target: Vector2, _power: float, _haste: float) -> void:
	_volley += 1
	var dir := (target - origin).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	if style == "ranged":
		_spin_note_input()
		add_heat(V5_HEAT_PER_INPUT + (V5_HEAT_BURST_EXTRA if burst_left > 0.0 else 0.0))
		if spin_stage() >= 3:
			_stage3_inputs.append(_clock)
			if has("BRC") and _stage3_inputs.size() >= 20 and overload_recovery_left <= 0.0:
				_stage3_inputs.clear()
				counters["overload_spinup"] = int(counters.get("overload_spinup", 0)) + 1
				_overload()
		_core_strike_v5(origin, dir, 1.0)
		_side_rounds_for_input(origin, dir)
		_vent_volley_input(origin)
		_reserve_input(origin, dir)
		if burst_left > 0.0:
			_burst_inputs += 1
			_fire(origin, dir, BURST_ROUND_D * D(), BURST_ROUND_PP, "BRQ", "burst_round", 1)
		if suppression_left > 0.0 and not has("BRV2"):
			_suppression_mirror(target)
		if burst_left > 0.0 and has("BRQ4") and not has("BRE2"):
			var perp := Vector2(-dir.y, dir.x)
			for side in [-1.0, 1.0]:
				_fire(origin + perp * side * 40.0, dir, 0.5 * D(), 0.35, "BRQ4", "bullet", 1, PackedStringArray(["core_strike"]))
	else:
		# Foreign Burst: every second real native attack during the window
		# emits one 0.45D Ranged side shot; never a native input.
		if burst_left > 0.0 and runner.native_core != "ranged":
			_foreign_burst_parity += 1
			if _foreign_burst_parity % 2 == 0:
				_fire(origin, dir, BURST_ROUND_D * D(), BURST_ROUND_PP, "BRQ", "burst_round", 1)
		if has("BRA"):
			add_heat(HEAT_PER_FOREIGN)
			var rounds := tier_side_rounds()
			for i in range(rounds):
				if style == "melee":
					runner.spawn_slash(origin + dir * 10.0, dir, 0.4 * D(), AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "BRA", "slash", 1, V5_SIDE_ROUND_PP))
				else:
					runner.spawn_impact(target, 0.4 * D(), AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "BRA", "impact", 1, V5_SIDE_ROUND_PP))
				counters["hot_blood_rounds"] = int(counters["hot_blood_rounds"]) + 1


## Hot Core side rounds plus Kill Throttle's Overdrive round.
func _side_rounds_for_input(origin: Vector2, dir: Vector2) -> void:
	var rounds := tier_side_rounds()
	for i in range(rounds):
		var spread := deg_to_rad(8.0) * (float(i) - float(rounds - 1) * 0.5)
		_fire(origin, dir.rotated(spread), V5_SIDE_ROUND_D * D(), V5_SIDE_ROUND_PP, "BR03", "side", 1)
		counters["side_rounds"] = int(counters["side_rounds"]) + 1
	if _overdrive_left > 0.0:
		_fire(origin, dir.rotated(deg_to_rad(6.0)), 0.4 * D(), 0.25, "BR07", "side", 1)
		counters["overdrive_rounds"] = int(counters.get("overdrive_rounds", 0)) + 1


## Weighted Core-strike credit with banking: one activation contributes its
## coefficient once; thresholds spend whole credits (spec §1.3).
func _core_strike_v5(origin: Vector2, dir: Vector2, coefficient: float) -> void:
	# Fifth Shot: release an armed package on this eligible attack first.
	if has("BR02") and _fifth_package > 0:
		var package := _fifth_package
		_fifth_package = 0
		for i in range(package):
			var spread := 0.24 * (float(i) - float(package - 1) * 0.5) / maxf(float(package - 1) * 0.5, 1.0)
			_fire(origin, dir.rotated(spread), 0.6 * D(), 0.5, "BR02", "bullet", 1)
		counters["fifth_shots"] = int(counters["fifth_shots"]) + 1
	_strike_credit += coefficient
	_crossfire_credit += coefficient
	if has("BR02"):
		var interval: int = [5, 5, 4, 3][_rank_row("BR02", 4)]
		var rounds: int = [2, 3, 3, 4][_rank_row("BR02", 4)]
		if _strike_credit >= float(interval):
			_strike_credit -= float(interval)
			# Merge a package armed before the pending one launched, capped
			# at twice the currently selected rank's size.
			_fifth_package = mini(_fifth_package + rounds, rounds * 2)
	if has("BR06"):
		var cross_interval: int = [3, 3, 2][_rank_row("BR06", 3)]
		var shots := 1 if rank("BR06") <= 1 else 2
		var damage: float = [0.8, 0.7, 0.65][_rank_row("BR06", 3)]
		if _crossfire_credit >= float(cross_interval):
			_crossfire_credit -= float(cross_interval)
			for i in range(shots):
				_crossfire_shot(damage * D(), 0.5, "BR06")


func witness_tags(core: String) -> PackedStringArray:
	if core != "ranged":
		return PackedStringArray()
	return PackedStringArray(["volley:%d" % (_volley + 1)])


func on_witness_strike(core: String, origin: Vector2, target: Vector2) -> void:
	if core != "ranged":
		return
	_volley += 1
	add_heat(V5_HEAT_PER_WITNESS)
	var dir := (target - origin).normalized()
	_core_strike_v5(origin, dir if dir != Vector2.ZERO else Vector2.RIGHT, 1.0)
	# Foreign Spin Up: real Witness shots chain stages 1..3 within 4 s.
	if runner.native_core != "ranged" and has("BR01"):
		if _clock - _foreign_last_witness > 4.0:
			_foreign_stage = 0
		_foreign_last_witness = _clock
		_foreign_stage = mini(3, _foreign_stage + 1)
		_foreign_witness_count += 1
		# Foreign Reserve Feed: 0.6 credit per Witness shot; every 4th real
		# Witness shot releases up to six stored rounds toward aim.
		if has("BR11"):
			_reserve_credit += 0.6
			_reserve_store_check()
			if _foreign_witness_count % 4 == 0 and stored_rounds > 0:
				var fired := mini(6, stored_rounds)
				stored_rounds -= fired
				_fan_volley(runner.player_position(), runner.aim_target(), fired, 0.7 * D(), 0.3, "BR11", "stored", 40.0)
				counters["stored_fired"] = int(counters["stored_fired"]) + fired
		if _overdrive_left > 0.0 and has("BR07"):
			_fire(origin, dir, 0.4 * D(), 0.25, "BR07", "side", 1)
			counters["overdrive_rounds"] = int(counters.get("overdrive_rounds", 0)) + 1


## Foreign Spin Up's flat bonus lands on the actual qualifying Witness shot
## before its damage is fixed (pre-mitigation damage hook; finding F).
func modify_outgoing_damage(preview: Dictionary, raw: float) -> float:
	if runner.native_core == "ranged" or _foreign_stage <= 0 or not has("BR01"):
		return raw
	var tags: PackedStringArray = preview["tags"]
	if preview["core"] == "ranged" and AscensionTags.has_flag(tags, "witness"):
		var per_stage: Array = [[0.1, 0.2, 0.3], [0.15, 0.30, 0.45], [0.20, 0.40, 0.60]][_rank_row("BR01", 3)]
		return raw + float(per_stage[_foreign_stage - 1]) * D()
	return raw


# ------------------------------------------------------------ Vent Volley / Reserve Feed

func _vent_round_count() -> int:
	return 12 if rank("BR08") >= 2 else 8


func _vent_volley_input(origin: Vector2) -> void:
	if not has("BR08"):
		return
	_vent_inputs += 1
	var interval := 10 if rank("BR08") >= 2 else 12
	if _vent_inputs % interval == 0:
		_auto_vent_volley(origin, false)


## The automatic radial release; a Q completion passes with_heat_vent=true.
func _auto_vent_volley(origin: Vector2, with_heat_vent: bool) -> void:
	var rounds := _vent_round_count()
	var extra := 0
	if with_heat_vent and claims_heat():
		var spent := maxf(0.0, heat - 40.0)
		heat = minf(heat, 40.0)
		_tier = tier_index()
		extra = mini(6, int(spent / 10.0))
	# Reserve rounds merge into this volley instead of a second fan.
	var merged := 0
	if has("BR11") and stored_rounds > 0:
		merged = mini(6, stored_rounds)
		stored_rounds -= merged
		counters["stored_fired"] = int(counters["stored_fired"]) + merged
	_radial_volley(origin, rounds, 0.6 * D(), 0.3, "BR08", "loose")
	if merged > 0:
		_radial_volley(origin, merged, 0.7 * D(), 0.3, "BR11", "stored")
	if extra > 0:
		_radial_volley(origin, extra, 0.4 * D(), 0.3, "BR08", "loose")
	counters["loose_rounds"] = int(counters["loose_rounds"]) + rounds + extra
	_last_vent_input = _vent_inputs
	runner.note_union_trigger("jam")


var _last_vent_input: int = -1


func _reserve_cap() -> int:
	return [12, 18, 24][_rank_row("BR11", 3)]


func _reserve_input(origin: Vector2, dir: Vector2) -> void:
	if not has("BR11"):
		return
	_reserve_credit += 1.0
	_reserve_store_check()
	_reserve_release_inputs += 1
	if _reserve_release_inputs % 12 == 0 and stored_rounds > 0:
		# If this same input fired the Vent Volley, the stored rounds were
		# already consumed into that radial release.
		if _last_vent_input == _vent_inputs and _vent_inputs > 0:
			return
		var fired := mini(6, stored_rounds)
		stored_rounds -= fired
		_fan_volley(origin, origin + dir * 100.0, fired, 0.7 * D(), 0.3, "BR11", "stored", 30.0)
		counters["stored_fired"] = int(counters["stored_fired"]) + fired


func _reserve_store_check() -> void:
	var per: int = [6, 6, 5][_rank_row("BR11", 3)]
	var gain: int = [2, 3, 4][_rank_row("BR11", 3)]
	while _reserve_credit >= float(per):
		_reserve_credit -= float(per)
		if has("BRF1") and spin_stage() >= 3:
			gain += 1
		stored_rounds = mini(_reserve_cap(), stored_rounds + gain)


# ------------------------------------------------------------ hits and kills

func on_hit(hit: Dictionary) -> void:
	if hit["core"] != "ranged":
		return
	var tags: PackedStringArray = hit["tags"]
	var core_strike := AscensionTags.has_flag(tags, "core_strike")
	var handle := int(hit["handle"])
	if has("RM4") and hit["path"] == "crossfire" and AscensionTags.has_flag(tags, "rune") and not _rune_pids.has(int(hit["projectile_id"])):
		_rune_pids[int(hit["projectile_id"])] = true
		var invocation := runner.engine_of_discipline("IN") as InvocationEngine
		if invocation != null:
			invocation.place_sigil(hit["position"], "rune")
			counters["bullet_runes"] = int(counters.get("bullet_runes", 0)) + 1
	# Hot Rounds V5: the unheated third-strike burn and the heated volley
	# behaviours, all through the named strongest-refresh burn.
	if has("BR04") and core_strike and hit["path"] == "bullet":
		_hot_rounds_v5(hit, handle)
	# Ricochet with rank 2's second different-enemy bounce.
	if core_strike and hit["path"] == "bullet" and (has("BR09") or (has("BRQ3") and hit["root"] == "BRQ")):
		_ricochet_v5(hit, handle, 1)
	elif has("BR09") and rank("BR09") >= 2 and hit["path"] == "ricochet":
		_ricochet_v5(hit, handle, 2)
	# Cluster Rounds ranks.
	if has("BR12") and hit["path"] == "ricochet":
		var shard_count := 3 if rank("BR12") >= 2 else 2
		var shard_d := 0.45 if rank("BR12") >= 2 else 0.5
		for _i in range(shard_count):
			_spawn_fragment(hit["position"], shard_d * D(), 0.3, 0, "BR12", int(hit["gen"]) + 1, handle)


func _hot_rounds_burn_values() -> Array:
	return [[0.15, 2.0], [0.20, 2.5], [0.30, 3.0]][_rank_row("BR04", 3)]


func _hot_rounds_tags() -> PackedStringArray:
	return AscensionTags.make("ranged", "status", "BR04", "burn", 1, 0.0, PackedStringArray(["hot_rounds"]))


func _apply_hot_rounds_burn(handle: int) -> void:
	var values := _hot_rounds_burn_values()
	EnemyStatus.apply_named_burn(handle, &"hot_rounds", float(values[1]), 0.5, float(values[0]) * D(), runner.player(), _hot_rounds_tags())


func _hot_rounds_v5(hit: Dictionary, handle: int) -> void:
	var volley := int(AscensionTags.value_of(hit["tags"], "volley"))
	var heated := claims_heat() and heat >= 50.0
	if heated:
		if volley != _hot_volley_first_done:
			_hot_volley_first_done = volley
			counters["hot_rounds"] = int(counters["hot_rounds"]) + 1
			var radius := AscensionRunner.R * 0.5
			runner.spawn_impact(hit["position"], 0.5 * D(), AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "BR04", "impact", 1, 0.30), radius)
			for victim in runner.enemies_in_radius(hit["position"], radius):
				_apply_hot_rounds_burn(victim)
		elif heat >= 75.0:
			_apply_hot_rounds_burn(handle)
		return
	# Unheated mode: the first impact from every 3rd eligible strike burns.
	if volley != _hot_volley_first_done:
		_hot_volley_first_done = volley
		_hot_rounds_strikes += 1
		if _hot_rounds_strikes % 3 == 0:
			counters["hot_rounds"] = int(counters["hot_rounds"]) + 1
			_apply_hot_rounds_burn(handle)


func _ricochet_v5(hit: Dictionary, victim: int, bounce_number: int) -> void:
	var cast := ""
	var exclude: Dictionary = {}
	if bounce_number == 1:
		if int(hit["gen"]) >= 1 and hit["root"] != "BRQ":
			return
		_rico_serial += 1
		cast = "rico:%d" % _rico_serial
		_rico_visited[cast] = {victim: true}
		if _rico_visited.size() > 128:
			_rico_visited.clear()
			_rico_visited[cast] = {victim: true}
		exclude = _rico_visited[cast]
	else:
		cast = AscensionTags.value_of(hit["tags"], "cast")
		if not cast.begins_with("rico:") or not _rico_visited.has(cast):
			return
		exclude = _rico_visited[cast]
		if exclude.size() >= 3:
			return
		exclude[victim] = true
	var next := _nearest_excluding(hit["position"], 2.0 * AscensionRunner.R, exclude)
	if next == 0:
		return
	exclude[next] = true
	var hit_position: Vector2 = hit["position"]
	var dir: Vector2 = (runner.enemy_position(next) - hit_position).normalized()
	var damage := 0.7 * float(hit["applied"] if float(hit["applied"]) > 0.0 else D())
	var pp := 0.6 if bounce_number == 1 else 0.4
	var tags_flags := PackedStringArray()
	var options := {"speed": BULLET_SPEED, "max_range": BULLET_RANGE}
	var tags := AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "BR09", "ricochet", int(hit["gen"]) + 1, pp, tags_flags)
	tags.append("cast:" + cast)
	runner.spawn_bullet(hit["position"], dir, maxf(damage, 0.7 * D() * 0.5), tags, options)
	counters["ricochets"] = int(counters["ricochets"]) + 1


func _nearest_excluding(at: Vector2, radius: float, exclude: Dictionary) -> int:
	var best := 0
	var best_d := INF
	for handle in runner.enemies_in_radius(at, radius):
		if exclude.has(handle) or not runner.enemy_alive(handle):
			continue
		var d := at.distance_squared_to(runner.enemy_position(handle))
		if d < best_d:
			best_d = d
			best = handle
	return best


func on_kill(hit: Dictionary, _context: RefCounted) -> void:
	var handle := int(hit["handle"])
	var position: Vector2 = hit["position"]
	# Wildfire: only a genuine named Hot Rounds Burn death qualifies.
	if has("RM5") and hit["family"] == "status" and AscensionTags.has_flag(hit.get("tags", PackedStringArray()), "hot_rounds"):
		if runner.roll(&"wildfire", 0.25, 1.0):
			counters["wildfires"] = int(counters.get("wildfires", 0)) + 1
			for _i in range(3):
				_spawn_fragment(position, 0.5 * D(), 0.4, 0, "RM5", int(hit["gen"]) + 1, handle, true)
	if hit["core"] != "ranged":
		return
	if has("BR05"):
		var group: int = [2, 3, 4, 5][_rank_row("BR05", 4)]
		var bounces := 1 if has("BR10") else 0
		var cast := AscensionTags.value_of(hit["tags"], "cast")
		if cast.is_empty():
			cast = "seed:%d" % handle
		for _i in range(group):
			_spawn_fragment(position, 0.6 * D(), 0.4, bounces, "BR05", int(hit["gen"]) + 1, handle, false, cast)
		if burst_left > 0.0 and hit["path"] == "fragment":
			_burst_fragment_kills += 1
	# Kill Throttle: distinct real kills at Spin Up stage >= 2.
	if has("BR07") and (spin_stage() >= 2 or (_foreign_stage >= 2 and runner.native_core != "ranged")):
		_throttle_kills += 1
		var need := 2 if rank("BR07") >= 2 else 3
		if _throttle_kills >= need:
			_throttle_kills = 0
			_overdrive_left = 2.5 if rank("BR07") >= 2 else 2.0
			counters["overdrives"] = int(counters.get("overdrives", 0)) + 1
			if BattleText != null:
				BattleText.popup(runner.player_position(), "OVERDRIVE", Color(0.6, 0.95, 1.0, 1.0), 1.0)
	if burst_left > 0.0 and has("BRQ7") and not _burst_kills.has(handle) and not AscensionTags.has_flag(hit["tags"], "v"):
		_burst_kills[handle] = true
		if _burst_extended < 2.0:
			var extra := minf(BELT_FED_EXTEND, 2.0 - _burst_extended)
			_burst_extended += extra
			burst_left += extra
			burst_total += extra


# ------------------------------------------------------------ Burst (Q)

func activate_q(id: String) -> Dictionary:
	if id != "BRQ":
		return {"ok": false, "message": "NOT BARRAGE", "cooldown": 0.0}
	if _emergency_vent_left > 0.0 or jam_left > 0.0:
		return {"ok": false, "message": "VENTING", "cooldown": 0.0}
	if burst_left > 0.0 or beam_left > 0.0:
		return _cancel_burst_v5()
	burst_total = 3.0 if has("BRQ1") else 2.0
	_burst_scale = runner.q_scale()
	_burst_pp = runner.q_proc_scale()
	if has("BRE1"):
		beam_left = burst_total
		_beam_tick = 0.0
		counters["bursts"] = int(counters["bursts"]) + 1
		return {"ok": true, "message": "HEAT BEAM", "cooldown": 8.0}
	burst_left = burst_total
	_burst_extended = 0.0
	_burst_inputs = 0
	_burst_fragment_kills = 0
	_foreign_burst_parity = 0
	_burst_kills.clear()
	_burst_points = 3 if has("BRE2") else 0
	_burst_point_timer = 0.0
	counters["bursts"] = int(counters["bursts"]) + 1
	return {"ok": true, "message": "BURST", "cooldown": 8.0}


func _cancel_burst_v5() -> Dictionary:
	if beam_left > 0.0:
		beam_left = 0.0
		if claims_heat() and heat >= 65.0 and heat <= 80.0:
			stationary_beam_left = 1.0
			_stationary_from = _beam_from
			_stationary_to = _beam_to
			_stationary_tick = 0.0
		return {"ok": false, "message": "RELEASED", "cooldown": 0.0}
	var first_half := burst_left > burst_total * 0.5
	burst_left = 0.0
	_burst_points = 0
	if has("BRQ6") and first_half:
		if claims_heat():
			heat = maxf(0.0, heat - 30.0)
			_tier = tier_index()
		runner.q_cooldown_left = maxf(0.0, runner.q_cooldown_left * 0.5)
		return {"ok": false, "message": "STOPPED", "cooldown": 0.0}
	return {"ok": false, "message": "CANCELLED", "cooldown": 0.0}


## Normal completion, in the specified order: snapshot -> base fan -> Ammo
## Dump -> Reserve merge -> Vent Volley release -> Vented nova -> one Heat
## vent -> recovery (spec §3.4).
func _complete_burst() -> void:
	var origin := runner.player_position()
	var aim := runner.aim_target()
	var heat_snapshot := heat
	var inputs_snapshot := _burst_inputs
	if has("BRE2"):
		var per_point := 4
		var rounds := _burst_points * per_point
		_radial_volley(origin, rounds, 0.5 * D(), 0.3, "BRQ", "bullet")
		counters["burst_rounds"] = int(counters["burst_rounds"]) + rounds
		_burst_points = 0
		# Bullet Hell's authored ending stays an Evolution-specific shutdown.
		jam_left = 1.5
		runner.block_native_fire(jam_left)
		heat = minf(heat, MELTDOWN_REST)
	else:
		# Base fan: 12 Q-generated Core-strike rounds at Proc Power 0.7; the
		# whole completion is one activation and banks 0.7 strike credit.
		_fan_volley_flagged(origin, aim, 12, 0.6 * D() * _burst_scale, BURST_FAN_PP * _burst_pp, "BRQ", "bullet", 50.0, PackedStringArray(["core_strike"]))
		counters["burst_rounds"] = int(counters["burst_rounds"]) + 12
		_strike_credit += 0.7
		_crossfire_credit += 0.7
		# Ammo Dump: earned during this Q, plus a Heat snapshot bonus.
		if has("BRQ5"):
			var earned := mini(12, int(float(inputs_snapshot) / 4.0))
			if claims_heat():
				earned += mini(5, int(heat_snapshot / 20.0))
			if earned > 0:
				_radial_volley(origin, earned, 0.5 * D(), 0.3, "BRQ5", "bullet")
				counters["burst_rounds"] = int(counters["burst_rounds"]) + earned
		# Reserve Feed: the completion consumes every stored round, cap 24.
		if has("BR11") and stored_rounds > 0:
			var fired := mini(24, stored_rounds)
			stored_rounds -= fired
			_fan_volley(origin, aim, fired, 0.7 * D(), 0.3, "BR11", "stored", 45.0)
			counters["stored_fired"] = int(counters["stored_fired"]) + fired
		# Vent Volley's Q-completion release (and its Heat vent, once).
		if has("BR08"):
			_auto_vent_volley(origin, claims_heat())
		# Vented nova.
		if has("BRQ2"):
			var nova_d := (2.0 if claims_heat() else 1.0) * D()
			var nova_r := (2.0 if claims_heat() else 1.0) * AscensionRunner.R
			runner.spawn_impact(origin, nova_d, AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "BRQ2", "impact", 1, 0.3), nova_r)
			for victim in runner.enemies_in_radius(origin, nova_r):
				EnemyStatus.apply_burn(victim, 1, 2.0, 0.5, 0.2 * D() * 0.5, runner.player())
			if claims_heat() and not has("BR08"):
				heat = minf(heat, 40.0)
				_tier = tier_index()
	# Foreign Overload route: a completed Burst with six real fragment kills
	# during its window.
	if runner.native_core != "ranged" and has("BRC") and _burst_fragment_kills >= 6 and overload_recovery_left <= 0.0:
		_overload()


## _fan_volley with explicit flags (the base keeps its signature for V4).
func _fan_volley_flagged(origin: Vector2, target: Vector2, count: int, damage: float, pp: float, root: String, path: String, fan_degrees: float, flags: PackedStringArray) -> void:
	var dir := (target - origin).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	for i in range(count):
		var t := (float(i) / float(maxi(count - 1, 1))) - 0.5
		_fire(origin, dir.rotated(deg_to_rad(fan_degrees) * t), damage, pp, root, path, 1, flags)


# ------------------------------------------------------------ movement / HUD

func move_speed_multiplier() -> float:
	var mul := 1.0
	if burst_left > 0.0 and has("BRQ1"):
		mul *= 0.9
	if has("BRK2"):
		if claims_heat() and heat >= 100.0:
			mul *= 0.8
		elif spin_stage() >= 3:
			mul *= 0.9
	return mul


func collect_draw_points(out: Array) -> void:
	collect_beam_points(out)
	for fragment in fragments:
		out.append([fragment["pos"], 3.5, Color(1.0, 0.75, 0.3, 0.95)])
	# The radiant aura's true damaging radius, always world-accurate.
	var state := aura_state()
	if float(state[0]) > 0.0:
		var intensity: float = clampf(float(state[1]) / (0.5 * D()), 0.2, 1.0)
		out.append([runner.player_position(), float(state[0]), Color(1.0, 0.45, 0.15, 0.10 + 0.25 * intensity)])


func hud_state(slot: String) -> Dictionary:
	var state := {}
	if slot == "q":
		var parts := PackedStringArray()
		if has("BR01") and runner.native_core == "ranged":
			parts.append("SPIN %d" % spin_stage())
		elif has("BR01") and _foreign_stage > 0:
			parts.append("W-SPIN %d" % _foreign_stage)
		if claims_heat():
			state["resource_value"] = heat
			state["resource_max"] = heat_cap
			if _meltdown_left > 0.0:
				parts.append("MELTDOWN %.1fs" % _meltdown_left)
			else:
				parts.append("HEAT %d" % int(heat))
		if _overdrive_left > 0.0:
			parts.append("OVERDRIVE")
		if stored_rounds > 0:
			parts.append("STORE %d" % stored_rounds)
		if beam_left > 0.0:
			parts.append("BEAM %.1fs" % beam_left)
		elif burst_left > 0.0:
			parts.append("BURST %.1fs" % burst_left)
		state["combat_text"] = "  ".join(parts)
	elif slot == "v" and suppression_left > 0.0:
		state["combat_text"] = "SUPPRESSION %.1fs" % suppression_left
	return state


## SUPPRESSION V5: Final Salvo's recovery is 0.60 s, not a 1.5 s lockout.
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
		var rounds := mini(60, floori(float(_suppression_shots) / 4.0))
		if rounds > 0:
			_radial_volley(runner.player_position(), rounds, D(), 0.4, "BRV3", "bullet")
		_native_block_left = 0.60
		runner.block_native_fire(_native_block_left)
		if has("BRC") and overload_recovery_left <= 0.0:
			_overload()


func describe() -> Dictionary:
	var out := super.describe()
	out["v5"] = true
	out["spin_stage"] = spin_stage()
	out["spin_streak"] = _spin_streak
	out["meltdown_left"] = _meltdown_left
	out["overdrive_left"] = _overdrive_left
	out["foreign_stage"] = _foreign_stage
	return out
