extends RefCounted
class_name SegmentThemePicker

# Two base modes:
# - EXPLORE: wide lanes, open plazas, higher drift + branches
# - ESCAPE: tighter lanes, denser cover, straighter push outward
#
# Segments:
# - 2: EXPLORE (fixed)
# - 3: ESCAPE (fixed)
# - 4/6/7/8/9: random blend per attempt (deterministic from seed)
# - 5: random blend + guaranteed MINIBOSS ARENA you must find (branch pocket)
# - 10: ESCAPE + BOSS (capstone)

static func get_theme(segment: int, attempt_world_seed: int) -> SegmentThemeData:
	segment = maxi(1, segment)

	# Deterministic per attempt+segment.
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(attempt_world_seed, segment) ^ 0x5EEDBEEF

	var explore := _theme_explore()
	var escape := _theme_escape()

	# Fixed identity beats
	if segment == 2:
		explore.id = &"explore"
		explore.label = "Explore"
		return explore

	if segment == 3:
		escape.id = &"escape"
		escape.label = "Escape"
		return escape

	# Random blend for others (deterministic per attempt)
	var t: float = rng.randf() # 0..1 (explore..escape)
	if segment == 10:
		t = 1.0

	var mixed := SegmentThemeData.blend(explore, escape, t)
	mixed.id = &"mix"
	mixed.label = "Mix " + str(snapped(t, 0.01))

	# Segment 5: guaranteed miniboss arena pocket (required to clear the segment).
	if segment == 5:
		mixed.has_miniboss_arena = true
		mixed.label += " + Miniboss"

	# Segments 6-10: rare optional miniboss pocket somewhere off-route.
	# Keep deterministic: same attempt seed => same result.
	if segment >= 6 and segment <= 9:
		if rng.randf() < 0.12:
			mixed.has_miniboss_arena = true
			mixed.label += " + Rare Miniboss"
	elif segment == 10:
		if rng.randf() < 0.08:
			mixed.has_miniboss_arena = true
			mixed.label += " + Rare Miniboss"

	# Segment 10: boss capstone
	if segment == 10:
		mixed.has_boss_arena = true
		mixed.end_mode = "BOSS_GATE"
		mixed.label = "Boss"

	return mixed

static func _theme_explore() -> SegmentThemeData:
	var t := SegmentThemeData.new()
	t.id = &"explore"
	t.label = "Explore"

	# ChunkManager feel (mirrors your old segment-2 tuning)
	t.weight_empty = 0.88
	t.weight_building = 0.08
	t.weight_ruins = 0.04
	t.district_lane_width_cells = 14
	t.district_plaza_size_cells = 20
	t.district_gap_chance = 0.16
	t.district_window_chance = 0.14
	t.donjon_strength = 0.15
	t.donjon_room_attempts = 14
	t.donjon_fill_wall_chance = 0.52
	t.donjon_ca_steps = 3

	# DistrictPlan (macro)
	t.goal_dist_offset = -1
	t.ortho_limit = 4
	t.ortho_guard_bonus = 1
	t.waypoint_chance = 0.95
	t.meander_chance = 0.30
	t.branch_count_min = 2
	t.branch_count_max = 3
	t.max_branch_len = 2
	t.loop_budget_min = 1
	t.loop_budget_max = 2
	t.arena_branch_len = 2
	return t

static func _theme_escape() -> SegmentThemeData:
	var t := SegmentThemeData.new()
	t.id = &"escape"
	t.label = "Escape"

	# ChunkManager feel (mirrors your old segment-3 tuning)
	t.weight_empty = 0.45
	t.weight_building = 0.35
	t.weight_ruins = 0.20
	t.district_lane_width_cells = 10
	t.district_plaza_size_cells = 16
	t.district_gap_chance = 0.06
	t.district_window_chance = 0.10
	t.donjon_strength = 0.78
	t.donjon_room_attempts = 26
	t.donjon_fill_wall_chance = 0.48
	t.donjon_ca_steps = 4

	# DistrictPlan (macro)
	t.goal_dist_offset = 1
	t.ortho_limit = 2
	t.ortho_guard_bonus = 0
	t.waypoint_chance = 0.80
	t.meander_chance = 0.16
	t.branch_count_min = 1
	t.branch_count_max = 2
	t.max_branch_len = 1
	t.loop_budget_min = 0
	t.loop_budget_max = 1
	t.arena_branch_len = 2
	return t

static func _mix_seed(a: int, b: int) -> int:
	var h: int = int((a ^ (b * 0x9E3779B9)) & 0x7FFFFFFF)
	h = int((h * 1103515245 + 12345) & 0x7FFFFFFF)
	return h
