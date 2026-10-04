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

## 2026-10-04 design audit (docs/audits/2026-10-04-game-design-audit.md §2):
## the only human capture unsealed 23,700 px from the gate, burned the
## 55-kill buffer in 4.6 s of walking and died 1,835 px short at Overtime 13
## - every recorded death (7/7, 13/13, 1/1) was in collapse. Overtime was
## punishing travel, not farming. The shape follows the user's plan
## (docs/superpowers/plans/2026-09-17-item-set-exit-balance.md §6.3): a time
## term that starts after a travel grace, a much smaller kill term, kills by
## authored formations and kills inside the exit encounter excluded, and
## clamped additions while the exit encounter is live. The rates sit between
## the plan's 0.008/0.004 and the audits' proposals, so camping after the
## grace still reaches Overtime 5 in about two minutes at 5 kills/s.
@export var overtime_time_rate: float = 0.012    # per second, after the travel grace
@export var overtime_kill_rate: float = 0.006    # per kill AFTER buffer
@export var overtime_kill_buffer: int = 55       # prevents instant spike right at unseal
## Travel grace: the time term starts once a player could have walked from
## where they stood at unseal to the rite, at this effective speed (combat
## included), clamped to [min, max]. No rite in the scene -> the minimum.
@export var overtime_grace_px_per_sec: float = 180.0
@export var overtime_grace_min_sec: float = 60.0
@export var overtime_grace_max_sec: float = 150.0
## While the exit encounter is live, Overtime's HP/damage ADDITIONS clamp
## here (plan §6.3); segment and heat terms still apply on top.
@export var exit_ot_hp_add_cap: float = 2.0
@export var exit_ot_damage_add_cap: float = 1.5

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
## Lowered with the kill term (2026-10-04): the countdown follows the travel
## grace and time, so a strong build is not told to leave by its own kills.
@export var evac_kill_weight: float = 0.0015

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
## Was 0.65: with the collapse phase add and the spawner's own ramp, 85% of
## collapse spawns were elite in the human capture (about 258 elites in one
## segment), so an elite stopped being an event. 2026-10-04 audit.
@export var elite_bonus_from_overtime: float = 0.30
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

# Exit Rite climax (roadmap 2.8): while the rite is being channelled the world
# resists departure - faster spawns, more elites. Polled from the
# exit_rite_channeling group; the EncounterDirector sends the specialist
# response on the rising edge.
signal rite_channel_changed(active: bool)
var rite_channel_active: bool = false
## Neutral since 2026-10-04 (plan 2026-09-17 §6.3: "stop stacking the old
## channel-only spawn multiplier and elite bonus on top of the new authored
## formation budgets"): ambient spawning is already suspended for the whole
## exit encounter and the specialists come from authored formations, so these
## only made the few spawns that still pass faster and eliter.
@export_range(0.2, 1.0, 0.05) var rite_spawn_factor: float = 1.0
@export_range(0.0, 0.5, 0.01) var rite_elite_add: float = 0.0

# Power contrast (roadmap 2.6 / §11): after the player crosses a visible power
# threshold, enemy HP/damage scaling holds still for a while so enemies that
# were dangerous simply die, before the next threat is introduced.
signal power_threshold_noted(id: StringName, label: String)
var power_contrast_active: bool = false
var power_thresholds_crossed: int = 0
@export_range(0.0, 120.0, 1.0) var power_contrast_lag_sec: float = 25.0
var _contrast_left: float = 0.0
var _contrast_hp_mul: float = 1.0
var _contrast_damage_mul: float = 1.0
var _thresholds_seen: Dictionary = {}
var evac_pressure: float = 0.0
var evac_remaining_sec: float = 0.0

# internals
var _tick: float = 0.0
var _last_segment: int = 0
var _kills_ts: Array[float] = []
var _unseal_time: float = 0.0
var _kills_since_unseal: int = 0
## How much of _unseal_time came from add_overtime_pressure (Overtime
## Gospel). Injected seconds skip the travel grace: they are a price the rule
## pays for refusing to leave, not travel.
var _injected_seconds: float = 0.0
## Travel grace for this unseal, resolved from the player's distance to the
## rite the first time both exist after the unseal (see _travel_grace_seconds).
var _grace_sec: float = 0.0
var _grace_resolved: bool = false
## Collapse arrives over this many seconds instead of in one step: the human
## capture went from Overtime 0.9 to 5.7 and from ~14% to 85% elite spawns
## within 15 s of the unseal.
@export_range(0.0, 60.0, 1.0) var collapse_ramp_sec: float = 20.0
var _collapse_ramp_left: float = 0.0
## A threshold crossed outside combat (the Hub, a menu, the segment's opening
## seconds) waits for the next disturbance phase, where the hold can be felt.
var _contrast_pending: Array[Dictionary] = []

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
		if not _grace_resolved:
			_resolve_travel_grace()
		overtime = _compute_overtime()
	if _collapse_ramp_left > 0.0:
		_collapse_ramp_left = maxf(0.0, _collapse_ramp_left - step)

	if power_contrast_active:
		_contrast_left -= step
		if _contrast_left <= 0.0:
			power_contrast_active = false
	var tree := get_tree()
	if tree != null:
		var channeling := not tree.get_nodes_in_group(&"exit_rite_channeling").is_empty()
		if channeling != rite_channel_active:
			set_rite_channel_active(channeling)

	_update_dominance()
	_update_evac()
	_recompute()


func set_rite_channel_active(active: bool) -> void:
	if active == rite_channel_active:
		return
	rite_channel_active = active
	_recompute(true)
	rite_channel_changed.emit(active)


## A threshold arms the contrast window once per RUN; repeats are ignored.
##
## Until 2026-10-04 the seen-set was cleared at every segment change, so the
## same "3 Manifestations active" threshold re-fired at each segment's load -
## in the Hub or the opening seconds, where holding enemy scaling holds
## nothing (all three human-run firings were inert). Now the set lives for the
## attempt, and a threshold crossed outside combat waits for the next
## disturbance phase, where the hold - and the EncounterDirector's rematch
## formation listening to power_threshold_noted - can actually be seen.
func note_power_threshold(id: StringName, label: String = "") -> void:
	if id == StringName() or _thresholds_seen.has(id):
		return
	_thresholds_seen[id] = true
	power_thresholds_crossed += 1
	if not _in_live_combat():
		_contrast_pending.append({"id": id, "label": label})
		return
	_arm_power_contrast(id, label)


func _arm_power_contrast(id: StringName, label: String) -> void:
	_contrast_hp_mul = enemy_hp_mul
	_contrast_damage_mul = enemy_damage_mul
	power_contrast_active = power_contrast_lag_sec > 0.0
	_contrast_left = power_contrast_lag_sec
	power_threshold_noted.emit(id, label)
	_recompute(true)


## Live combat = a gameplay scene with a spawner, past the segment's quiet
## opening, and not inside the exit encounter (the rite owns that time).
func _in_live_combat() -> bool:
	if segment_phase == &"recon" or rite_channel_active:
		return false
	var tree := get_tree()
	return tree != null and tree.get_first_node_in_group(&"enemy_spawner") != null


func _release_pending_contrast() -> void:
	if _contrast_pending.is_empty() or not _in_live_combat():
		return
	# Several thresholds crossed in one Hub visit open ONE window, named for
	# the first; the rest were already counted when they were noted.
	var first: Dictionary = _contrast_pending[0]
	_contrast_pending.clear()
	_arm_power_contrast(StringName(first.get("id", &"")), String(first.get("label", "")))


## Seconds the contrast window has left; 0 once it has closed. The HUD reads
## this so the hold is visible while it lasts - the window itself stays
## _process's business.
func power_contrast_seconds_left() -> float:
	if not power_contrast_active:
		return 0.0
	return maxf(0.0, _contrast_left)

func _hook_signals() -> void:
	if RunEvents != null:
		if RunEvents.has_signal("power_threshold_crossed") and not RunEvents.power_threshold_crossed.is_connected(note_power_threshold):
			RunEvents.power_threshold_crossed.connect(note_power_threshold)
		var cb_r := Callable(self, "_on_resonance_changed")
		if RunEvents.has_signal("resonance_changed") and not RunEvents.resonance_changed.is_connected(cb_r):
			RunEvents.resonance_changed.connect(cb_r)

		var cb_k := Callable(self, "_on_enemy_defeated")
		if RunEvents.has_signal("enemy_defeated") and not RunEvents.enemy_defeated.is_connected(cb_k):
			RunEvents.enemy_defeated.connect(cb_k)
	# Attempt boundaries (new attempt, failed attempt) end the run-scoped
	# memory: the power thresholds already seen and any pending contrast.
	if Global != null and Global.has_signal("balance_attempt_boundary"):
		var cb_a := Callable(self, "_on_attempt_boundary")
		if not Global.balance_attempt_boundary.is_connected(cb_a):
			Global.balance_attempt_boundary.connect(cb_a)

func _on_attempt_boundary(_reason: StringName) -> void:
	_thresholds_seen.clear()
	_contrast_pending.clear()
	power_thresholds_crossed = 0

func reset_run_state() -> void:
	# Fresh attempt in the SAME segment (death/restart): the segment poll in
	# _process never fires because attempt_segment did not change, which used
	# to carry overtime/elites/evac into the new run.
	_on_attempt_boundary(&"reset_run_state")
	_on_segment_changed(maxi(1, Global.attempt_segment))

func _on_segment_changed(new_seg: int) -> void:
	_last_segment = new_seg
	# Fresh segment -> drop the hands.
	resonance = 0.0
	heat = 0.0
	overtime = 0.0
	gate_unsealed = false
	rite_channel_active = false
	# The contrast window itself ends with the segment; the thresholds already
	# seen (and any still pending) belong to the run - see note_power_threshold.
	power_contrast_active = false
	_contrast_left = 0.0
	_unseal_time = 0.0
	_injected_seconds = 0.0
	_grace_sec = 0.0
	_grace_resolved = false
	_collapse_ramp_left = 0.0
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
	var previous := segment_phase
	segment_phase = clean_phase
	if clean_phase == &"collapse" and previous != &"collapse":
		_collapse_ramp_left = collapse_ramp_sec
	_recompute(true)
	if clean_phase == &"disturbance" or clean_phase == &"ascension":
		_release_pending_contrast()

func _on_resonance_changed(v: float) -> void:
	resonance = clampf(v, 0.0, 1.0)

	if (not gate_unsealed) and resonance >= gate_unseal_resonance:
		gate_unsealed = true
		_unseal_time = 0.0
		_injected_seconds = 0.0
		_kills_since_unseal = 0
		_grace_sec = overtime_grace_min_sec
		_grace_resolved = false
		_resolve_travel_grace()
		overtime = 0.0
		_update_evac()

	_recompute()

func _on_enemy_defeated(context: RefCounted) -> void:
	var now := Time.get_ticks_msec() * 0.001
	_kills_ts.append(now)

	if gate_unsealed and _kill_counts_toward_overtime(context):
		_kills_since_unseal += 1

	# recompute soon (don’t wait for the poll)
	_recompute()


## Plan §6.3: kills of authored formations (beats and the rite's specialist
## responses, both spawned with special_spawn_kind &"beat") and every kill
## while the exit encounter is live do not advance Overtime - answering the
## world's response is not farming it.
func _kill_counts_toward_overtime(context: RefCounted) -> bool:
	if rite_channel_active:
		return false
	if context == null:
		return true
	var metadata: Variant = context.get("metadata")
	if metadata is Dictionary:
		return StringName((metadata as Dictionary).get("special_spawn_kind", &"")) != &"beat"
	return true


## The travel grace for this unseal: how long walking from here to the rite
## takes at overtime_grace_px_per_sec, clamped. Resolved once, the first tick
## both the player and a rite exist (the rite's node position is read
## directly - Global.exit_gate_pos hides it while the gate is still locked).
## Without a rite the grace stays at the minimum.
func _resolve_travel_grace() -> void:
	if _grace_resolved:
		return
	var tree := get_tree()
	var rite: Node2D = tree.get_first_node_in_group(&"exit_rite") as Node2D if tree != null else null
	var player: Node2D = tree.get_first_node_in_group(&"player") as Node2D if tree != null else null
	if rite != null and player != null:
		var distance := rite.global_position.distance_to(player.global_position)
		_grace_sec = clampf(distance / maxf(1.0, overtime_grace_px_per_sec), overtime_grace_min_sec, overtime_grace_max_sec)
		_grace_resolved = true
	elif _unseal_time >= 2.0:
		_grace_sec = overtime_grace_min_sec
		_grace_resolved = true


## Seconds of travel grace left (0 once the time term is running).
func travel_grace_left() -> float:
	if not gate_unsealed:
		return 0.0
	return maxf(0.0, _grace_sec - maxf(0.0, _unseal_time - _injected_seconds))

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
	# Overtime punishes staying, not travelling: a time term that starts after
	# the travel grace, plus a small kill term past a buffer (see the export
	# block for the 2026-10-04 evidence).
	return overtime_time_part() + overtime_kill_part()


## Seconds the time term counts: elapsed unseal time beyond the travel grace,
## plus every injected second in full.
func overtime_seconds() -> float:
	var elapsed := maxf(0.0, _unseal_time - _injected_seconds)
	return maxf(0.0, elapsed - _grace_sec) + _injected_seconds


func overtime_time_part() -> float:
	return overtime_seconds() * overtime_time_rate if gate_unsealed else 0.0


func overtime_kill_part() -> float:
	if not gate_unsealed:
		return 0.0
	var k_excess := maxi(0, _kills_since_unseal - overtime_kill_buffer)
	return float(k_excess) * overtime_kill_rate * dominance_mul

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
	var decayed := maxf(REWARD_DECAY_FLOOR, 1.0 / pow(1.0 + maxf(0.0, overtime), REWARD_DECAY_POWER))
	# Something in the loadout may argue that staying IS the correct play. See
	# belief_defiance.
	return lerpf(decayed, 1.0, clampf(belief_defiance, 0.0, 1.0))


## How much of Overtime's belief decay is currently being refused, 0..1.
##
## Written by whatever preaches that refusing evacuation is holy - Overtime
## Gospel today. This exists so that rule can be paid in STRUCTURE rather than
## in a number: its reward used to be +150% Power, easily the largest figure in
## the Manifestation layer and a plain stat wearing a risk decision. Refusing
## the decay instead makes it the one loadout that can genuinely farm Overtime,
## which is an archetype rather than a multiplier - and it is self-limiting,
## because the same rule is pouring Threat onto the curve to get it.
var belief_defiance: float = 0.0


func add_overtime_pressure(extra_seconds: float, contributor: String = "") -> void:
	# Public lever for greed mechanics (Overtime Gospel): a rule that pays the
	# player for refusing to leave must also make the refusing cost more.
	# Expressed in seconds of unseal time because that is the only accumulator
	# _compute_overtime() reads that is not the kill counter.
	if extra_seconds <= 0.0 or not gate_unsealed:
		return
	_unseal_time += extra_seconds
	_injected_seconds += extra_seconds
	overtime = _compute_overtime()
	_recompute()
	if RunEvents != null and RunEvents.overtime_pressure_injected.has_connections():
		RunEvents.overtime_pressure_injected.emit(contributor, extra_seconds, _unseal_time, overtime)


## Observation only (balance recorder): the pressure the director is applying
## and the components it came from, computed with the same terms
## _compute_overtime() and _recompute() use. Reads nothing that ticks.
func balance_snapshot() -> Dictionary:
	var k_excess := maxi(0, _kills_since_unseal - overtime_kill_buffer)
	var ot := overtime if gate_unsealed else 0.0
	var raw_hp := 1.0 + carry * hp_from_carry + heat * hp_from_heat
	return {
		"threat": threat, "heat": heat, "carry": carry, "resonance": resonance, "overtime": ot,
		"segment_phase": String(segment_phase), "gate_unsealed": gate_unsealed,
		"rite_channel_active": rite_channel_active, "power_contrast_active": power_contrast_active,
		"power_contrast_left": power_contrast_seconds_left(), "belief_defiance": belief_defiance,
		"unseal_seconds": _unseal_time, "elapsed_unseal_seconds": _unseal_time - _injected_seconds,
		"injected_seconds": _injected_seconds, "kills_since_unseal": _kills_since_unseal, "kill_excess": k_excess,
		"travel_grace_seconds": _grace_sec if gate_unsealed else 0.0, "travel_grace_left": travel_grace_left(),
		"overtime_seconds": overtime_seconds() if gate_unsealed else 0.0,
		"overtime_time_part": overtime_time_part(),
		"overtime_kill_part": overtime_kill_part(),
		"dominance_kps": dominance_kps, "dominance_mul": dominance_mul,
		"enemy_hp_mul": enemy_hp_mul, "enemy_damage_mul": enemy_damage_mul, "enemy_speed_mul": enemy_speed_mul,
		"spawn_interval_mul": spawn_interval_mul, "elite_bonus": elite_bonus,
		"hp_mul_at_cap": enemy_hp_mul >= hp_mul_cap - 0.000001, "damage_mul_at_cap": enemy_damage_mul >= dmg_mul_cap - 0.000001,
		"hp_mul_contrast_held": power_contrast_active and enemy_hp_mul < raw_hp - 0.000001,
		"evac_pressure": evac_pressure, "evac_remaining_sec": evac_remaining_sec,
		"reward_multiplier": overtime_reward_multiplier(),
	}


func _update_evac() -> void:
	unseal_time_sec = _unseal_time
	kills_since_unseal = _kills_since_unseal

	if not gate_unsealed:
		evac_pressure = 0.0
		evac_remaining_sec = 0.0
		return

	# The countdown is honest since 2026-10-04: EVAC IN N is the real seconds
	# of travel grace left (the old value ran 60 -> 0 over 95 s and fell
	# faster with kills, so it measured nothing a player could plan around).
	# Pressure climbs to 1 across the grace (the HUD vignette deepens as it
	# runs out), then past 1 with Overtime time and excess kills.
	var k_excess := maxi(0, _kills_since_unseal - overtime_kill_buffer)
	var p_kill := float(k_excess) * evac_kill_weight
	var grace_left := travel_grace_left()
	if grace_left > 0.0:
		var elapsed := maxf(0.0, _unseal_time - _injected_seconds)
		evac_pressure = clampf(elapsed / maxf(1.0, _grace_sec) + p_kill, 0.0, 2.0)
	else:
		evac_pressure = clampf(1.0 + overtime_seconds() / maxf(1.0, evac_time_base_sec) + p_kill, 0.0, 2.0)
	evac_remaining_sec = grace_left

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
			# Ramp in from the ascension values over collapse_ramp_sec rather
			# than stepping (2026-10-04 audit: the step plus Overtime made the
			# unseal a cliff). The elite add now grows with the segment
			# (0.06 at segment 2, 0.12 from segment 8) instead of a flat 0.12.
			var ramp := 1.0 - (_collapse_ramp_left / collapse_ramp_sec) if collapse_ramp_sec > 0.0 else 1.0
			heat = maxf(heat, lerpf(0.48, 0.85, ramp))
			phase_spawn_factor = lerpf(0.68, 0.55, ramp)
			phase_elite_add = lerpf(0.05, minf(0.12, 0.04 + 0.01 * float(seg)), ramp)
	if rite_channel_active:
		phase_spawn_factor *= rite_spawn_factor
		phase_elite_add += rite_elite_add

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

	# Plan §6.3: while the exit encounter is live the ADDITIONS clamp; the
	# accumulated Overtime is untouched, so leaving the encounter restores the
	# ordinary evaluation without resetting history.
	if rite_channel_active:
		ot_hp_add = minf(ot_hp_add, exit_ot_hp_add_cap)
		ot_dmg_add = minf(ot_dmg_add, exit_ot_damage_add_cap)

	# Doctrine Threat is authoritative pressure, not merely a HUD surcharge.
	# Multiplication bends both segment carry and live heat; Witness debt is
	# denominated in the same units as the HUD's 55-points-per-heat term.
	var doctrine_pressure := apply_doctrine_pressure(carry, heat)
	var pressure_carry: float = doctrine_pressure.x
	var pressure_heat: float = doctrine_pressure.y

	# Multipliers (caps are very high: this is meant to scale "forever" in practice)
	var new_hp := 1.0 + pressure_carry * hp_from_carry + pressure_heat * hp_from_heat + ot_hp_add
	new_hp = clampf(new_hp, 1.0, hp_mul_cap)

	var new_dmg := 1.0 + pressure_carry * dmg_from_carry + pressure_heat * dmg_from_heat + ot_dmg_add
	new_dmg = clampf(new_dmg, 1.0, dmg_mul_cap)
	if power_contrast_active:
		# Hold the line: the player just got stronger, let it show.
		new_hp = minf(new_hp, _contrast_hp_mul)
		new_dmg = minf(new_dmg, _contrast_damage_mul)

	var new_spd := 1.0 + pressure_carry * spd_from_carry + pressure_heat * spd_from_heat
	new_spd = clampf(new_spd, 1.0, spd_mul_cap)

	# Spawn interval multiplier from heat + unbounded overtime spawn pressure.
	# Smaller = faster spawns (Spawner multiplies its wait_time by this).
	var base_spawn := lerpf(spawn_mul_at_heat0, spawn_mul_at_heat1, pressure_heat)
	var new_spawn := (base_spawn * phase_spawn_factor) / (1.0 + ot_spawn_more)
	new_spawn = clampf(new_spawn, spawn_mul_min, spawn_mul_max)

	# Elite bonus: from heat + overtime (stage 1)
	var new_elite := pressure_heat * elite_bonus_from_heat + ot_elite_add + phase_elite_add
	new_elite = clampf(new_elite, 0.0, elite_bonus_cap)

	# Loot rarity bonus: segment + heat + overtime (log so it stays readable)
	var loot_f := float(seg - 1) * loot_bonus_from_segment + pressure_heat * loot_bonus_from_heat + log(1.0 + ot) * loot_bonus_from_overtime
	loot_f = clampf(loot_f, 0.0, loot_bonus_cap)
	loot_rarity_bonus = int(floor(loot_f))

	# Threat value for HUD: keep readable and avoid spikes.
	var new_threat := apply_doctrine_threat(carry * 22.0 + heat * 55.0 + log(1.0 + ot) * 35.0)

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

func apply_doctrine_threat(base_threat: float) -> float:
	var multiplier := 1.0
	var debt := 0.0
	if Global != null:
		multiplier = float(Global.get_doctrine_rule(&"threat_gain_mul", 1.0))
		debt = float(Global.attempt_doctrine_threat_debt)
	return maxf(0.0, base_threat * multiplier + debt)

func apply_doctrine_pressure(base_carry: float, base_heat: float) -> Vector2:
	var multiplier := 1.0
	var debt := 0.0
	if Global != null:
		multiplier = maxf(0.0, float(Global.get_doctrine_rule(&"threat_gain_mul", 1.0)))
		debt = maxf(0.0, float(Global.attempt_doctrine_threat_debt))
	return Vector2(
		maxf(0.0, base_carry * multiplier),
		maxf(0.0, base_heat * multiplier + debt / 55.0)
	)
