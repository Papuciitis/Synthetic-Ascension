extends Node
class_name ThreatDirectorSingleton

signal threat_changed(threat: float)
signal multipliers_changed(
	enemy_hp_mul: float,
	enemy_damage_mul: float,
	enemy_speed_mul: float,
	spawn_interval_mul: float,
	elite_bonus: float
)

# ============================================================
# Threat 2.1 (Carry + Heat + Overtime + light Dominance)
#
# Targets (tuning intent):
# - Gate unseals around ~3 minutes on average (handled by Level1Builder resonance pacing).
# - Segment feel bands (tutorial):
#     0-60% manageable hard, 60-90% GOD, 90-100% LEAVE, 100%+ OT = FIND OUT
# - Segment feel bands (segments 2+):
#     0-20% GOD, 20-70% challenge, 70-90% GOD, 90-100% LEAVE, 100%+ OT = FIND OUT
# - Overtime should NOT spike instantly when the gate unseals.
#   (Kill buffer + gentle early slope; still infinite scaling if you keep farming.)
# - Overtime escalation order: ELITES -> DAMAGE -> SPAWN.
# - Dominance is a LIGHT modifier (smoothed kill-rate), not the main driver.
# ============================================================

# -----------------------------
# Segment baseline (Carry)
# -----------------------------
@export var carry_per_segment: float = 0.14 # baseline difficulty per segment beyond 1 (gentle but noticeable)

# -----------------------------
# Heat curves (0..1 input -> 0..1 output)
# Piecewise values so you can tune quickly without Curve resources.
# -----------------------------
# Segment 1 (tutorial): 0-60 hard manageable, 60-90 GOD, 90-100 leave
@export var tut_heat_at_0: float = 0.30
@export var tut_heat_at_60: float = 0.85
@export var tut_heat_at_90: float = 0.35
@export var tut_heat_at_100: float = 1.00

# Segments 2+: 0-20 GOD, 20-70 challenge, 70-90 GOD, 90-100 leave
@export var heat_at_0: float = 0.06
@export var heat_at_20: float = 0.10
@export var heat_at_70: float = 0.85
@export var heat_at_90: float = 0.35
@export var heat_at_100: float = 1.00

# -----------------------------
# Dominance (light modifier)
# -----------------------------
@export var dominance_window_sec: float = 8.0
@export var dominance_target_kps: float = 2.3
@export var dominance_gain: float = 0.05   # how much KPS above target affects multiplier
@export var dominance_min_mul: float = 0.92
@export var dominance_max_mul: float = 1.08
@export var dominance_apply_after_resonance: float = 0.30 # don’t "cheat" early

# -----------------------------
# Overtime (after gate unsealed)
# -----------------------------
@export var gate_unseal_resonance: float = 0.999

# Overtime grows from time + kills after unseal.
# - time part is intentionally small (procedural gate distance)
# - kill part is intentionally large (punishes farming)
## Belief earned after the gate opens decays on this curve. The floor matters:
## a kill that pays nothing reads as a bug, and the point is a declining
## return, not a wall.
@export var REWARD_DECAY_POWER: float = 0.6
@export var REWARD_DECAY_FLOOR: float = 0.35

@export var overtime_time_rate: float = 0.008    # per second
@export var overtime_kill_rate: float = 0.035    # per kill AFTER buffer
@export var overtime_kill_buffer: int = 55       # prevents instant spike right at unseal

# staged escalation thresholds (overtime meter)
@export var ot_elite_start: float = 0.00
@export var ot_elite_tau: float = 1.8            # larger = slower saturation

@export var ot_damage_start: float = 1.60
@export var ot_damage_pow: float = 1.22
@export var ot_damage_scale: float = 0.34        # unbounded; tune for “must leave ~60s if farming”

@export var ot_spawn_start: float = 5.00         # SPAWN is last
@export var ot_spawn_pow: float = 1.15
@export var ot_spawn_scale: float = 0.30         # unbounded; mostly limited by spawner floors/caps

@export var ot_hp_start: float = 2.00
@export var ot_hp_pow: float = 1.10
@export var ot_hp_scale: float = 0.22            # unbounded; slows down camping/farming

# Evac pressure (HUD countdown)
# Pressure rises slowly with time, faster with kills (after buffer).
# When pressure reaches 1.0, we display EVAC NOW.
@export var evac_target_sec: float = 60.0
@export var evac_time_base_sec: float = 95.0
@export var evac_kill_weight: float = 0.004

# -----------------------------
# Mapping (Carry/Heat/OT -> multipliers)
# -----------------------------
@export var hp_from_carry: float = 0.22
@export var hp_from_heat: float = 0.85
@export var hp_mul_cap: float = 30.0   # “practically infinite”, prevents accidental overflow

@export var dmg_from_carry: float = 0.12
@export var dmg_from_heat: float = 0.08     # keep modest pre-unseal
@export var dmg_mul_cap: float = 30.0

@export var spd_from_carry: float = 0.06
@export var spd_from_heat: float = 0.04
@export var spd_mul_cap: float = 2.0

# Spawn interval multiplier: >1 slows spawns, <1 speeds spawns (spawner multiplies wait_time by this).
# We keep baseline slightly faster so minute 0 isn’t a snooze.
@export var spawn_mul_at_heat0: float = 0.95
@export var spawn_mul_at_heat1: float = 0.55
@export var spawn_mul_min: float = 0.12
@export var spawn_mul_max: float = 1.10

# Elites: spawner adds this on top of its own global + entry chance.
@export var elite_bonus_from_heat: float = 0.08
@export var elite_bonus_from_overtime: float = 0.65
@export var elite_bonus_cap: float = 0.95

# Loot rarity bonus (additive integer, applied in EnemyDrops).
# Early: low, Late + OT: better (risk/reward).
@export var loot_bonus_from_segment: float = 0.25  # per segment beyond 1
@export var loot_bonus_from_heat: float = 1.20     # at heat=1
@export var loot_bonus_from_overtime: float = 2.50 # scales with log(1+ot)
@export var loot_bonus_cap: float = 6.0

# -----------------------------
# Outputs (consumed by other systems)
# -----------------------------
var threat: float = 0.0
var enemy_hp_mul: float = 1.0
var enemy_damage_mul: float = 1.0
var enemy_speed_mul: float = 1.0
var spawn_interval_mul: float = 1.0
var elite_bonus: float = 0.0

# Extra outputs (UI / loot / debugging)
var resonance: float = 0.0
var carry: float = 0.0
var heat: float = 0.0
var overtime: float = 0.0
var dominance_kps: float = 0.0
var dominance_mul: float = 1.0
var gate_unsealed: bool = false
var loot_rarity_bonus: int = 0
var segment_phase: StringName = &"recon"

var unseal_time_sec: float = 0.0
var kills_since_unseal: int = 0
var evac_pressure: float = 0.0
var evac_remaining_sec: float = 0.0

# internals
var _tick: float = 0.0
var _last_segment: int = 0
var _kills_ts: Array[float] = []
var _unseal_time: float = 0.0
var _kills_since_unseal: int = 0

func _ready() -> void:
	set_process(true)
	_last_segment = maxi(1, Global.attempt_segment)
	_hook_signals()
	_recompute(true)

func _process(delta: float) -> void:
	_tick += delta
	if _tick < 0.20:
		return
	var step := _tick
	_tick = 0.0

	# Segment changes don’t have a signal, so we poll lightly.
	var seg := maxi(1, Global.attempt_segment)
	if seg != _last_segment:
		_on_segment_changed(seg)

	if gate_unsealed:
		_unseal_time += step
		overtime = _compute_overtime()

	_update_dominance()
	_update_evac()
	_recompute()

func _hook_signals() -> void:
	if RunEvents != null:
		var cb_r := Callable(self, "_on_resonance_changed")
		if RunEvents.has_signal("resonance_changed") and not RunEvents.resonance_changed.is_connected(cb_r):
			RunEvents.resonance_changed.connect(cb_r)

		var cb_k := Callable(self, "_on_enemy_defeated")
		if RunEvents.has_signal("enemy_defeated") and not RunEvents.enemy_defeated.is_connected(cb_k):
			RunEvents.enemy_defeated.connect(cb_k)

func reset_run_state() -> void:
	# Fresh attempt in the SAME segment (death/restart): the segment poll in
	# _process never fires because attempt_segment did not change, which used
	# to carry overtime/elites/evac into the new run.
	_on_segment_changed(maxi(1, Global.attempt_segment))

func _on_segment_changed(new_seg: int) -> void:
	_last_segment = new_seg
	# Fresh segment -> drop the hands.
	resonance = 0.0
	heat = 0.0
	overtime = 0.0
	gate_unsealed = false
	_unseal_time = 0.0
	_kills_since_unseal = 0
	_kills_ts.clear()
	dominance_kps = 0.0
	dominance_mul = 1.0
	evac_pressure = 0.0
	evac_remaining_sec = 0.0
	segment_phase = &"recon"
	_recompute(true)

func set_segment_phase(next_phase: StringName) -> void:
	var clean_phase: StringName = next_phase
	if clean_phase != &"recon" and clean_phase != &"disturbance" and clean_phase != &"ascension" and clean_phase != &"collapse":
		clean_phase = &"recon"
	if segment_phase == clean_phase:
		return
	segment_phase = clean_phase
	_recompute(true)

func _on_resonance_changed(v: float) -> void:
	resonance = clampf(v, 0.0, 1.0)

	if (not gate_unsealed) and resonance >= gate_unseal_resonance:
		gate_unsealed = true
		_unseal_time = 0.0
		_kills_since_unseal = 0
		overtime = 0.0
		_update_evac()

	_recompute()

func _on_enemy_defeated(_context: RefCounted) -> void:
	var now := Time.get_ticks_msec() * 0.001
	_kills_ts.append(now)

	if gate_unsealed:
		_kills_since_unseal += 1

	# recompute soon (don’t wait for the poll)
	_recompute()

func _update_dominance() -> void:
	var win := maxf(0.5, dominance_window_sec)
	var now := Time.get_ticks_msec() * 0.001

	# drop old timestamps
	while _kills_ts.size() > 0 and (now - float(_kills_ts[0])) > win:
		_kills_ts.pop_front()

	dominance_kps = float(_kills_ts.size()) / win

	# Light modifier. Only kicks in once you’re a bit into the segment.
	if resonance < dominance_apply_after_resonance:
		dominance_mul = 1.0
		return

	var diff := dominance_kps - dominance_target_kps
	var m := 1.0 + diff * dominance_gain
	dominance_mul = clampf(m, dominance_min_mul, dominance_max_mul)

func _heat_from_resonance(seg: int, r: float) -> float:
	r = clampf(r, 0.0, 1.0)
	if seg <= 1:
		# 0..0.6
		if r <= 0.60:
			return lerpf(tut_heat_at_0, tut_heat_at_60, r / 0.60)
		# 0.6..0.9
		if r <= 0.90:
			return lerpf(tut_heat_at_60, tut_heat_at_90, (r - 0.60) / 0.30)
		# 0.9..1.0
		return lerpf(tut_heat_at_90, tut_heat_at_100, (r - 0.90) / 0.10)

	# segments 2+
	if r <= 0.20:
		return lerpf(heat_at_0, heat_at_20, r / 0.20)
	if r <= 0.70:
		return lerpf(heat_at_20, heat_at_70, (r - 0.20) / 0.50)
	if r <= 0.90:
		return lerpf(heat_at_70, heat_at_90, (r - 0.70) / 0.20)
	return lerpf(heat_at_90, heat_at_100, (r - 0.90) / 0.10)

func _compute_overtime() -> float:
	# Overtime should punish farming more than running.
	# Small time component (ambient pressure), large kill component after a buffer.
	var t_part := _unseal_time * overtime_time_rate
	var k_excess := maxi(0, _kills_since_unseal - overtime_kill_buffer)
	var k_part := float(k_excess) * overtime_kill_rate * dominance_mul
	return t_part + k_part

## How much a kill is worth right now, as a fraction of its base reward.
##
## This is the other half of Overtime, and without it greed was strictly
## correct: staying after the gate opened made the world more dangerous but paid
## exactly as well as it had a minute earlier, so the only reason to leave was
## fear. Risk of Rain 2 solves the same problem by letting costs scale faster
## than income - the purchasing power of a minute declines monotonically and
## farming is never forbidden, it just quietly stops paying. This is that idea
## in the shape this game already has.
##
## Deliberately 1.0 until the gate unseals. Punishing a player for exploring or
## reading before they could even leave would be punishing them for playing the
## game the design doc asks for.
func overtime_reward_multiplier() -> float:
	if not gate_unsealed:
		return 1.0
	return maxf(REWARD_DECAY_FLOOR, 1.0 / pow(1.0 + maxf(0.0, overtime), REWARD_DECAY_POWER))


func add_overtime_pressure(extra_seconds: float) -> void:
	# Public lever for greed mechanics (Overtime Gospel): a rule that pays the
	# player for refusing to leave must also make the refusing cost more.
	# Expressed in seconds of unseal time because that is the only accumulator
	# _compute_overtime() reads that is not the kill counter.
	if extra_seconds <= 0.0 or not gate_unsealed:
		return
	_unseal_time += extra_seconds
	overtime = _compute_overtime()
	_recompute()


func _update_evac() -> void:
	unseal_time_sec = _unseal_time
	kills_since_unseal = _kills_since_unseal

	if not gate_unsealed:
		evac_pressure = 0.0
		evac_remaining_sec = 0.0
		return

	var k_excess := maxi(0, _kills_since_unseal - overtime_kill_buffer)
	var p_time := _unseal_time / maxf(1.0, evac_time_base_sec)
	var p_kill := float(k_excess) * evac_kill_weight
	evac_pressure = clampf(p_time + p_kill, 0.0, 2.0)

	var p := minf(evac_pressure, 1.0)
	evac_remaining_sec = maxf(0.0, (1.0 - p) * evac_target_sec)

func _recompute(force_emit: bool = false) -> void:
	var seg := maxi(1, Global.attempt_segment)

	# Carry: gentle baseline by segment
	carry = float(seg - 1) * carry_per_segment

	# Heat: resonance curve, lightly modified by dominance
	heat = _heat_from_resonance(seg, resonance)
	heat = clampf(heat * dominance_mul, 0.0, 1.0)
	var phase_spawn_factor: float = 1.0
	var phase_elite_add: float = 0.0
	match segment_phase:
		&"recon":
			heat *= 0.72
			phase_spawn_factor = 1.15
		&"disturbance":
			heat = maxf(heat, 0.32)
			phase_spawn_factor = 0.78
			phase_elite_add = 0.03
		&"ascension":
			heat = maxf(heat, 0.48)
			phase_spawn_factor = 0.68
			phase_elite_add = 0.05
		&"collapse":
			heat = maxf(heat, 0.85)
			phase_spawn_factor = 0.55
			phase_elite_add = 0.12

	# Overtime scaling (after gate unsealed). UNBOUNDED.
	var ot := overtime if gate_unsealed else 0.0

	# Stage order: ELITES -> DAMAGE -> SPAWN
	var ot_elite_add: float = 0.0
	if ot > ot_elite_start:
		ot_elite_add = (1.0 - exp(-(ot - ot_elite_start) / maxf(0.001, ot_elite_tau))) * elite_bonus_from_overtime

	var ot_dmg_add: float = 0.0
	if ot > ot_damage_start:
		var d := ot - ot_damage_start
		ot_dmg_add = pow(d, ot_damage_pow) * ot_damage_scale

	var ot_spawn_more: float = 0.0
	if ot > ot_spawn_start:
		var s := ot - ot_spawn_start
		ot_spawn_more = pow(s, ot_spawn_pow) * ot_spawn_scale

	var ot_hp_add: float = 0.0
	if ot > ot_hp_start:
		var h := ot - ot_hp_start
		ot_hp_add = pow(h, ot_hp_pow) * ot_hp_scale

	# Multipliers (caps are very high: this is meant to scale "forever" in practice)
	var new_hp := 1.0 + carry * hp_from_carry + heat * hp_from_heat + ot_hp_add
	new_hp = clampf(new_hp, 1.0, hp_mul_cap)

	var new_dmg := 1.0 + carry * dmg_from_carry + heat * dmg_from_heat + ot_dmg_add
	new_dmg = clampf(new_dmg, 1.0, dmg_mul_cap)

	var new_spd := 1.0 + carry * spd_from_carry + heat * spd_from_heat
	new_spd = clampf(new_spd, 1.0, spd_mul_cap)

	# Spawn interval multiplier from heat + unbounded overtime spawn pressure.
	# Smaller = faster spawns (Spawner multiplies its wait_time by this).
	var base_spawn := lerpf(spawn_mul_at_heat0, spawn_mul_at_heat1, heat)
	var new_spawn := (base_spawn * phase_spawn_factor) / (1.0 + ot_spawn_more)
	new_spawn = clampf(new_spawn, spawn_mul_min, spawn_mul_max)

	# Elite bonus: from heat + overtime (stage 1)
	var new_elite := heat * elite_bonus_from_heat + ot_elite_add + phase_elite_add
	new_elite = clampf(new_elite, 0.0, elite_bonus_cap)

	# Loot rarity bonus: segment + heat + overtime (log so it stays readable)
	var loot_f := float(seg - 1) * loot_bonus_from_segment + heat * loot_bonus_from_heat + log(1.0 + ot) * loot_bonus_from_overtime
	loot_f = clampf(loot_f, 0.0, loot_bonus_cap)
	loot_rarity_bonus = int(floor(loot_f))

	# Threat value for HUD: keep readable and avoid spikes.
	var new_threat := carry * 22.0 + heat * 55.0 + log(1.0 + ot) * 35.0
	new_threat = maxf(0.0, new_threat)

	var changed: bool = force_emit \
		or absf(new_threat - threat) > 0.01 \
		or absf(new_hp - enemy_hp_mul) > 0.001 \
		or absf(new_dmg - enemy_damage_mul) > 0.001 \
		or absf(new_spd - enemy_speed_mul) > 0.001 \
		or absf(new_spawn - spawn_interval_mul) > 0.001 \
		or absf(new_elite - elite_bonus) > 0.001

	threat = new_threat
	enemy_hp_mul = new_hp
	enemy_damage_mul = new_dmg
	enemy_speed_mul = new_spd
	spawn_interval_mul = new_spawn
	elite_bonus = new_elite

	if changed:
		threat_changed.emit(threat)
		multipliers_changed.emit(enemy_hp_mul, enemy_damage_mul, enemy_speed_mul, spawn_interval_mul, elite_bonus)
