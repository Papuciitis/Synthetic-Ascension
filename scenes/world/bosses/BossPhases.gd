extends RefCounted
## Main-boss phases (boss overhaul proposal, "Segment 10 phase structure"):
## one health bar, three behavioural phases changing near 65% and 30% health.
## Phases only advance: return healing never re-opens a phase, so its once-
## per-threshold arrivals (Runners, pylons) can never be farmed.

const S10_MARKS: Array[float] = [0.65, 0.30]


## Health-bar marks for a boss tier: the S5 teaching fight has no phases.
static func marks_for_tier(tier: int) -> Array[float]:
	var marks: Array[float] = []
	if tier >= 1:
		marks.assign(S10_MARKS)
	return marks


## 0 above the first mark, 1 below it, 2 below the second.
static func phase_for(ratio: float, marks: Array[float] = S10_MARKS) -> int:
	var phase := 0
	for mark in marks:
		if ratio <= mark:
			phase += 1
	return phase
