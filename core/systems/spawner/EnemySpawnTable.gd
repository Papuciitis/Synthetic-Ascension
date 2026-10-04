@tool
extends Resource
class_name EnemySpawnTable

@export var entries: Array[EnemySpawnEntry] = []
@export var max_alive_total: int = 180

const PHASE_ORDER: Array[StringName] = [&"recon", &"disturbance", &"ascension", &"collapse"]


## How much sooner a later segment reaches its full roster: start times
## shrink by 8% per segment past the first, to 35% at segment 9 and beyond
## (roster audit E2), so segment 8's opening minutes do not present the
## segment-1 roster with bigger numbers.
static func unlock_time_scale(segment: int) -> float:
	return maxf(0.35, 1.0 - 0.08 * float(maxi(0, segment - 1)))


static func phase_allows(entry_phase: StringName, phase: StringName) -> bool:
	if entry_phase == &"" or phase == &"":
		return true
	var needed := PHASE_ORDER.find(entry_phase)
	var current := PHASE_ORDER.find(phase)
	if needed < 0 or current < 0:
		return true
	return current >= needed


## Whether `e` may spawn now: active at the scaled time, its phase reached,
## its segment reached. The ONE gate every ambient pick goes through - the
## spawner's own picker used to check start time only, so neither the phase
## gating (roster audit E2) nor the per-segment unlock speed-up ever reached
## ambient spawns (2026-10-04 pacing audit, bug a).
static func entry_allowed(e: EnemySpawnEntry, t: float, phase: StringName = &"", unlock_scale: float = 1.0, segment: int = 0) -> bool:
	if e == null:
		return false
	var scaled_t := t / maxf(0.05, unlock_scale)
	return e.is_active(scaled_t) and phase_allows(e.min_phase, phase) and (segment <= 0 or e.allows_segment(segment))


## `t` is seconds since the spawner started; `phase` the Threat Director's
## segment phase (empty = ungated); `unlock_scale` shrinks every start time;
## `segment` gates entries introduced later (0 = ungated).
func pick(t: float, rng: RandomNumberGenerator, phase: StringName = &"", unlock_scale: float = 1.0, segment: int = 0) -> EnemySpawnEntry:
	var active: Array[EnemySpawnEntry] = []
	var total: float = 0.0

	for e in entries:
		if entry_allowed(e, t, phase, unlock_scale, segment):
			active.append(e)
			total += e.weight

	if active.is_empty() or total <= 0.0:
		return null

	var roll: float = rng.randf() * total
	var acc: float = 0.0
	for e in active:
		acc += e.weight
		if roll <= acc:
			return e

	return active[active.size() - 1]

func get_max_alive_total() -> int:
	return max_alive_total
