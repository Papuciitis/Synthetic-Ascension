class_name EliteModifiers
extends RefCounted

## Roadmap §9 "Elite legibility" / plan §2.7. At high threat the elite chance
## saturates and "if everything is elite, nothing is elite": the flat HP/speed
## bump stops meaning anything. From `ascension` on, an elite also IS one of
## five strongly readable things, each with a tell on the body, a one-line
## teach on first sight per run, and a rule the player can answer.
##
## Every number here is a first guess - the playtest tunes them. Selection is
## by segment phase (count per phase below); archetypes exclude ids through
## EnemySpec.elite_modifiers_allowed / _denied, and an archetype that already
## splits never receives SPLITTING (one implementation, not two).

const ARMOURED := &"armoured"
const VAMPIRIC := &"vampiric"
const SHIELDED := &"shielded"
const SPLITTING := &"splitting"
const FAST := &"fast"
const ALL: Array[StringName] = [ARMOURED, VAMPIRIC, SHIELDED, SPLITTING, FAST]

# Bits mirror the ids so the actor's physics step pays one int test, not an
# Array search, to know whether a modifier needs a tick.
const BIT_ARMOURED := 1 << 0
const BIT_VAMPIRIC := 1 << 1
const BIT_SHIELDED := 1 << 2
const BIT_SPLITTING := 1 << 3
const BIT_FAST := 1 << 4

# ARMOURED: every hit loses this fraction of the elite's max HP, flat, so a
# pellet under the plate bounces and a heavy blow gets through.
const ARMOUR_FLAT_FRACTION := 0.04
# VAMPIRIC: every DRAIN_EVERY seconds the elite takes DRAIN_FRACTION of max HP
# from up to DRAIN_TARGETS non-elite allies within DRAIN_RADIUS and heals the
# sum. Never lethal - an ally is left at DRAIN_FLOOR_HP.
const VAMPIRIC_DRAIN_EVERY := 1.5
const VAMPIRIC_DRAIN_RADIUS := 140.0
const VAMPIRIC_DRAIN_TARGETS := 3
const VAMPIRIC_DRAIN_FRACTION := 0.10
const VAMPIRIC_DRAIN_FLOOR_HP := 1.0
# SHIELDED: non-elite enemies within SHIELD_RADIUS of the bearer take
# (1 - SHIELD_ALLY_DAMAGE_REDUCTION) of every hit.
const SHIELD_RADIUS := 180.0
const SHIELD_ALLY_DAMAGE_REDUCTION := 0.5
# SPLITTING: on death, SPLIT_COUNT non-elite copies at SPLIT_CHILD_HP_FRACTION
# of the archetype's base HP and SPLIT_CHILD_SCALE of its size.
const SPLIT_COUNT := 3
const SPLIT_CHILD_HP_FRACTION := 0.35
const SPLIT_CHILD_SCALE := 0.7
# FAST: on top of the archetype's elite multipliers.
const FAST_SPEED_MULT := 1.5
const FAST_HP_MULT := 0.7

# How many distinct modifiers a phase-picked elite carries. Recon and
# disturbance keep today's plain elite so the first one the player meets is
# still "the big one", not "the armoured one".
const PHASE_MODIFIER_COUNT := {
	&"recon": 0,
	&"disturbance": 0,
	&"ascension": 1,
	&"collapse": 2,
}

# Seconds the first-sight teach stays on the tutorial-tip channel.
const TEACH_SECONDS := 4.0

const _LABELS := {
	ARMOURED: "ARMOURED",
	VAMPIRIC: "VAMPIRIC",
	SHIELDED: "SHIELDED",
	SPLITTING: "SPLITTING",
	FAST: "FAST",
}

const _TEACH := {
	ARMOURED: "ARMOURED - small hits bounce, heavy hits get through",
	VAMPIRIC: "VAMPIRIC - feeds on the enemies around it; cut it off from the pack",
	SHIELDED: "SHIELDED - break the shield-bearer first",
	SPLITTING: "SPLITTING - kill it away from the crowd",
	FAST: "FAST - it closes before you can kite; keep moving",
}

# The tell on the body. Steel, blood, a ward, a seam, a streak.
const _TINTS := {
	ARMOURED: Color(0.72, 0.78, 0.86, 1.0),
	VAMPIRIC: Color(1.0, 0.22, 0.28, 1.0),
	SHIELDED: Color(0.45, 0.85, 1.0, 1.0),
	SPLITTING: Color(0.75, 1.0, 0.45, 1.0),
	FAST: Color(1.0, 0.95, 0.55, 1.0),
}

const _BITS := {
	ARMOURED: BIT_ARMOURED,
	VAMPIRIC: BIT_VAMPIRIC,
	SHIELDED: BIT_SHIELDED,
	SPLITTING: BIT_SPLITTING,
	FAST: BIT_FAST,
}



static func is_known(id: StringName) -> bool:
	return _LABELS.has(id)


static func bit_for(id: StringName) -> int:
	return int(_BITS.get(id, 0))


static func label(id: StringName) -> String:
	return String(_LABELS.get(id, String(id).to_upper()))


static func teach_line(id: StringName) -> String:
	return String(_TEACH.get(id, label(id)))


static func tint(id: StringName) -> Color:
	return _TINTS.get(id, Color.WHITE) as Color


static func count_for_phase(phase: StringName) -> int:
	return int(PHASE_MODIFIER_COUNT.get(phase, 0))


## The ids a phase-picked elite may carry: none before ascension, all five after.
static func unlocked_for_phase(phase: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if count_for_phase(phase) > 0:
		out.assign(ALL)
	return out


## The ids this archetype may carry: the spec's allow-list (empty = all) minus
## its deny-list, and never SPLITTING on an archetype that already splits.
static func eligible_for_spec(spec: EnemySpec) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in ALL:
		if spec != null:
			if not spec.elite_modifiers_allowed.is_empty() and not spec.elite_modifiers_allowed.has(id):
				continue
			if spec.elite_modifiers_denied.has(id):
				continue
			if id == SPLITTING and (spec.ai == EnemySpec.AI.SPLITTER or spec.elite_ai_override == EnemySpec.AI.SPLITTER):
				continue
		out.append(id)
	return out


## Keeps only the ids this archetype may carry, in the order given, once each.
static func filter_for_spec(ids: Array[StringName], spec: EnemySpec) -> Array[StringName]:
	var eligible := eligible_for_spec(spec)
	var out: Array[StringName] = []
	for id in ids:
		if eligible.has(id) and not out.has(id):
			out.append(id)
	return out


## Distinct random picks for a phase; the count is the phase's, capped by what
## the archetype allows. `rng` defaults to the run RNG.
static func pick_for_phase(phase: StringName, spec: EnemySpec, rng: RandomNumberGenerator = null) -> Array[StringName]:
	var out: Array[StringName] = []
	var wanted := count_for_phase(phase)
	if wanted <= 0:
		return out
	var pool := eligible_for_spec(spec)
	var source := rng if rng != null else Global._rng
	while out.size() < wanted and not pool.is_empty():
		var index := source.randi_range(0, pool.size() - 1)
		out.append(pool[index])
		pool.remove_at(index)
	return out


## One tooltip line: what the current phase does to elites.
static func phase_summary_line(phase: StringName) -> String:
	var count := count_for_phase(phase)
	if count <= 0:
		return "Elite modifiers: none yet - unlock at ASCENSION"
	var names: PackedStringArray = []
	for id in unlocked_for_phase(phase):
		names.append(label(id))
	return "Elite modifiers: %d per elite - %s" % [count, " · ".join(names)]


## The run keeps the memory (Global.teach_once): the spawner is re-created per
## segment and a per-spawner reset repeated every lesson each segment.
static func reset_teaching() -> void:
	Global.reset_teaching()


## True exactly once per run per id: the caller shows the teach line then.
static func consume_teach(id: StringName) -> bool:
	if not is_known(id):
		return false
	return Global.teach_once(_teach_key(id))


static func was_taught(id: StringName) -> bool:
	return Global.was_taught(_teach_key(id))


static func _teach_key(id: StringName) -> StringName:
	return StringName("elite_modifier/" + String(id))


static func release_static_caches() -> void:
	pass  # nothing RID-backed or per-process lives here any more
