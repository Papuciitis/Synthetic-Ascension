extends RefCounted
class_name SegmentThemePicker

# Area 1 uses progression-aware theme pools. Layouts remain procedural, but the city
# now changes identity as Bren moves away from the institution.

static func get_theme(segment: int, attempt_world_seed: int) -> SegmentThemeData:
	segment = maxi(1, segment)
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(attempt_world_seed, segment) ^ 0x5EEDBEEF

	match segment:
		2:
			return _theme_service_courtyards()
		3:
			return _theme_checkpoint_lanes()
		4:
			return _pick_theme(rng, [_theme_collapsed_ward(), _theme_civilian_cutthrough()])
		5:
			return _theme_inner_district_gate()
		6:
			return _pick_theme(rng, [_theme_industrial_cutthrough(), _theme_ruined_services()])
		7:
			return _pick_theme(rng, [_theme_underpass_veins(), _theme_canal_services()])
		8:
			return _pick_theme(rng, [_theme_rail_yard(), _theme_military_staging()])
		9:
			return _pick_theme(rng, [_theme_outer_wall(), _theme_siege_services()])
		10:
			return _theme_gate_district()
		_:
			return _theme_service_courtyards()

static func _pick_theme(rng: RandomNumberGenerator, options: Array) -> SegmentThemeData:
	if options.is_empty():
		return _theme_service_courtyards()
	var picked := options[rng.randi_range(0, options.size() - 1)] as SegmentThemeData
	return picked if picked != null else _theme_service_courtyards()

static func _base(id_value: StringName, label_value: String, family: StringName) -> SegmentThemeData:
	var t := SegmentThemeData.new()
	t.id = id_value
	t.label = label_value
	t.district_family = family
	return t

static func _theme_service_courtyards() -> SegmentThemeData:
	var t := _base(&"service_courtyards", "Service Courtyards", &"service_courtyards")
	t.base_terrain = "grass"
	t.exploration_terrain = "grass"
	t.landmark_count = 2
	t.weight_empty = 0.68
	t.weight_building = 0.22
	t.weight_ruins = 0.10
	t.district_lane_width_cells = 14
	t.district_plaza_size_cells = 18
	t.district_gap_chance = 0.16
	t.district_window_chance = 0.14
	t.donjon_strength = 0.28
	t.donjon_room_attempts = 16
	t.donjon_fill_wall_chance = 0.50
	t.donjon_ca_steps = 3
	t.goal_dist_offset = -1
	t.ortho_limit = 4
	t.ortho_guard_bonus = 2
	t.waypoint_chance = 0.95
	t.meander_chance = 0.32
	t.branch_count_min = 3
	t.branch_count_max = 4
	t.max_branch_len = 3
	t.loop_budget_min = 1
	t.loop_budget_max = 2
	t.exploration_branch_count_min = 3
	t.exploration_branch_count_max = 5
	t.exploration_branch_len_min = 2
	t.exploration_branch_len_max = 4
	t.exploration_turn_chance = 0.42
	t.exploration_reconnect_chance = 0.48
	t.exploration_band_bonus = 4
	return t

static func _theme_checkpoint_lanes() -> SegmentThemeData:
	var t := _base(&"checkpoint_lanes", "Checkpoint Lanes", &"checkpoint_lanes")
	t.base_terrain = "dirt"
	t.exploration_terrain = "grass"
	t.landmark_count = 2
	t.weight_empty = 0.34
	t.weight_building = 0.46
	t.weight_ruins = 0.20
	t.district_lane_width_cells = 11
	t.district_plaza_size_cells = 17
	t.district_gap_chance = 0.07
	t.district_window_chance = 0.11
	t.donjon_strength = 0.66
	t.donjon_room_attempts = 24
	t.donjon_fill_wall_chance = 0.48
	t.donjon_ca_steps = 4
	t.goal_dist_offset = 0
	t.ortho_limit = 3
	t.ortho_guard_bonus = 2
	t.waypoint_chance = 0.88
	t.meander_chance = 0.20
	t.branch_count_min = 2
	t.branch_count_max = 3
	t.max_branch_len = 2
	t.loop_budget_min = 1
	t.loop_budget_max = 2
	t.exploration_branch_count_min = 2
	t.exploration_branch_count_max = 4
	t.exploration_branch_len_min = 2
	t.exploration_branch_len_max = 3
	t.exploration_turn_chance = 0.30
	t.exploration_reconnect_chance = 0.52
	t.exploration_band_bonus = 3
	return t

static func _theme_collapsed_ward() -> SegmentThemeData:
	var t := _base(&"collapsed_ward", "Collapsed Ward", &"collapsed_ward")
	t.base_terrain = "grass"
	t.exploration_terrain = "grass"
	t.landmark_count = 3
	t.weight_empty = 0.48
	t.weight_building = 0.18
	t.weight_ruins = 0.34
	t.district_lane_width_cells = 12
	t.district_plaza_size_cells = 18
	t.district_gap_chance = 0.20
	t.district_window_chance = 0.08
	t.donjon_strength = 0.48
	t.donjon_room_attempts = 20
	t.goal_dist_offset = 0
	t.ortho_limit = 4
	t.ortho_guard_bonus = 2
	t.waypoint_chance = 0.92
	t.meander_chance = 0.34
	t.branch_count_min = 3
	t.branch_count_max = 5
	t.max_branch_len = 3
	t.loop_budget_min = 1
	t.loop_budget_max = 3
	t.exploration_branch_count_min = 3
	t.exploration_branch_count_max = 5
	t.exploration_branch_len_min = 2
	t.exploration_branch_len_max = 4
	t.exploration_turn_chance = 0.48
	t.exploration_reconnect_chance = 0.48
	t.exploration_band_bonus = 4
	return t

static func _theme_civilian_cutthrough() -> SegmentThemeData:
	var t := _base(&"civilian_cutthrough", "Civilian Cut-through", &"civilian_cutthrough")
	t.base_terrain = "grass"
	t.exploration_terrain = "dirt"
	t.landmark_count = 2
	t.weight_empty = 0.42
	t.weight_building = 0.38
	t.weight_ruins = 0.20
	t.district_lane_width_cells = 11
	t.district_plaza_size_cells = 17
	t.district_gap_chance = 0.14
	t.district_window_chance = 0.18
	t.donjon_strength = 0.58
	t.donjon_room_attempts = 25
	t.goal_dist_offset = 0
	t.ortho_limit = 4
	t.ortho_guard_bonus = 2
	t.waypoint_chance = 0.92
	t.meander_chance = 0.30
	t.branch_count_min = 3
	t.branch_count_max = 4
	t.max_branch_len = 3
	t.loop_budget_min = 1
	t.loop_budget_max = 2
	t.exploration_branch_count_min = 3
	t.exploration_branch_count_max = 5
	t.exploration_branch_len_min = 2
	t.exploration_branch_len_max = 4
	t.exploration_turn_chance = 0.44
	t.exploration_reconnect_chance = 0.55
	t.exploration_band_bonus = 4
	return t

static func _theme_inner_district_gate() -> SegmentThemeData:
	var t := _base(&"inner_district_gate", "Inner District Gate", &"inner_district_gate")
	t.base_terrain = "dirt"
	t.exploration_terrain = "grass"
	t.landmark_count = 2
	t.weight_empty = 0.28
	t.weight_building = 0.48
	t.weight_ruins = 0.24
	t.district_lane_width_cells = 12
	t.district_plaza_size_cells = 20
	t.district_gap_chance = 0.06
	t.district_window_chance = 0.10
	t.donjon_strength = 0.72
	t.donjon_room_attempts = 26
	t.goal_dist_offset = 1
	t.ortho_limit = 3
	t.ortho_guard_bonus = 2
	t.waypoint_chance = 0.90
	t.meander_chance = 0.20
	t.branch_count_min = 2
	t.branch_count_max = 4
	t.max_branch_len = 3
	t.loop_budget_min = 1
	t.loop_budget_max = 2
	t.exploration_branch_count_min = 2
	t.exploration_branch_count_max = 4
	t.exploration_branch_len_min = 2
	t.exploration_branch_len_max = 4
	t.exploration_turn_chance = 0.34
	t.exploration_reconnect_chance = 0.48
	t.exploration_band_bonus = 4
	t.has_miniboss_arena = true
	t.end_mode = "MINIBOSS_GATE"
	return t

static func _theme_industrial_cutthrough() -> SegmentThemeData:
	var t := _base(&"industrial_cutthrough", "Industrial Cut-through", &"industrial_cutthrough")
	t.base_terrain = "dirt"
	t.exploration_terrain = "dirt"
	t.landmark_count = 3
	t.weight_empty = 0.34
	t.weight_building = 0.48
	t.weight_ruins = 0.18
	t.district_lane_width_cells = 13
	t.district_plaza_size_cells = 19
	t.district_gap_chance = 0.08
	t.district_window_chance = 0.08
	t.donjon_strength = 0.66
	t.donjon_room_attempts = 24
	t.goal_dist_offset = 1
	t.ortho_limit = 4
	t.ortho_guard_bonus = 2
	t.waypoint_chance = 0.90
	t.meander_chance = 0.24
	t.branch_count_min = 3
	t.branch_count_max = 4
	t.max_branch_len = 3
	t.loop_budget_min = 1
	t.loop_budget_max = 2
	t.exploration_branch_count_min = 3
	t.exploration_branch_count_max = 5
	t.exploration_branch_len_min = 2
	t.exploration_branch_len_max = 4
	t.exploration_turn_chance = 0.36
	t.exploration_reconnect_chance = 0.48
	t.exploration_band_bonus = 4
	return t

static func _theme_ruined_services() -> SegmentThemeData:
	var t := _theme_industrial_cutthrough()
	t.id = &"ruined_services"
	t.label = "Ruined Service District"
	t.district_family = &"ruined_services"
	t.base_terrain = "grass"
	t.exploration_terrain = "dirt"
	t.weight_empty = 0.44
	t.weight_building = 0.24
	t.weight_ruins = 0.32
	t.district_gap_chance = 0.18
	t.donjon_strength = 0.50
	t.meander_chance = 0.32
	return t

static func _theme_underpass_veins() -> SegmentThemeData:
	var t := _base(&"underpass_veins", "Underpass Veins", &"underpass_veins")
	t.base_terrain = "dirt"
	t.exploration_terrain = "mud"
	t.landmark_count = 2
	t.weight_empty = 0.24
	t.weight_building = 0.50
	t.weight_ruins = 0.26
	t.district_lane_width_cells = 10
	t.district_plaza_size_cells = 16
	t.district_gap_chance = 0.06
	t.district_window_chance = 0.05
	t.donjon_strength = 0.78
	t.donjon_room_attempts = 28
	t.goal_dist_offset = 1
	t.ortho_limit = 4
	t.ortho_guard_bonus = 3
	t.waypoint_chance = 0.92
	t.meander_chance = 0.36
	t.branch_count_min = 3
	t.branch_count_max = 5
	t.max_branch_len = 4
	t.loop_budget_min = 2
	t.loop_budget_max = 3
	t.exploration_branch_count_min = 3
	t.exploration_branch_count_max = 5
	t.exploration_branch_len_min = 2
	t.exploration_branch_len_max = 5
	t.exploration_turn_chance = 0.50
	t.exploration_reconnect_chance = 0.62
	t.exploration_band_bonus = 5
	return t

static func _theme_canal_services() -> SegmentThemeData:
	var t := _theme_underpass_veins()
	t.id = &"canal_services"
	t.label = "Canal Service Routes"
	t.district_family = &"canal_services"
	t.base_terrain = "grass"
	t.exploration_terrain = "mud"
	t.weight_empty = 0.42
	t.weight_building = 0.36
	t.weight_ruins = 0.22
	t.district_lane_width_cells = 13
	t.donjon_strength = 0.58
	t.meander_chance = 0.42
	return t

static func _theme_rail_yard() -> SegmentThemeData:
	var t := _base(&"rail_yard", "Rail Yard Expanse", &"rail_yard")
	t.base_terrain = "dirt"
	t.exploration_terrain = "grass"
	t.landmark_count = 3
	t.weight_empty = 0.54
	t.weight_building = 0.30
	t.weight_ruins = 0.16
	t.district_lane_width_cells = 16
	t.district_plaza_size_cells = 21
	t.district_gap_chance = 0.10
	t.district_window_chance = 0.06
	t.donjon_strength = 0.42
	t.donjon_room_attempts = 18
	t.goal_dist_offset = 2
	t.ortho_limit = 5
	t.ortho_guard_bonus = 3
	t.waypoint_chance = 0.94
	t.meander_chance = 0.24
	t.branch_count_min = 3
	t.branch_count_max = 5
	t.max_branch_len = 4
	t.loop_budget_min = 1
	t.loop_budget_max = 3
	t.exploration_branch_count_min = 4
	t.exploration_branch_count_max = 6
	t.exploration_branch_len_min = 2
	t.exploration_branch_len_max = 5
	t.exploration_turn_chance = 0.34
	t.exploration_reconnect_chance = 0.55
	t.exploration_band_bonus = 5
	return t

static func _theme_military_staging() -> SegmentThemeData:
	var t := _theme_rail_yard()
	t.id = &"military_staging"
	t.label = "Military Staging Ground"
	t.district_family = &"military_staging"
	t.weight_empty = 0.30
	t.weight_building = 0.50
	t.weight_ruins = 0.20
	t.district_lane_width_cells = 13
	t.donjon_strength = 0.62
	t.meander_chance = 0.20
	t.exploration_branch_count_max = 5
	return t

static func _theme_outer_wall() -> SegmentThemeData:
	var t := _base(&"outer_wall", "Outer Wall Approaches", &"outer_wall")
	t.base_terrain = "grass"
	t.exploration_terrain = "grass"
	t.landmark_count = 3
	t.weight_empty = 0.40
	t.weight_building = 0.40
	t.weight_ruins = 0.20
	t.district_lane_width_cells = 13
	t.district_plaza_size_cells = 20
	t.district_gap_chance = 0.08
	t.district_window_chance = 0.08
	t.donjon_strength = 0.62
	t.donjon_room_attempts = 24
	t.goal_dist_offset = 2
	t.ortho_limit = 5
	t.ortho_guard_bonus = 3
	t.waypoint_chance = 0.94
	t.meander_chance = 0.26
	t.branch_count_min = 3
	t.branch_count_max = 5
	t.max_branch_len = 4
	t.loop_budget_min = 2
	t.loop_budget_max = 3
	t.exploration_branch_count_min = 4
	t.exploration_branch_count_max = 6
	t.exploration_branch_len_min = 2
	t.exploration_branch_len_max = 5
	t.exploration_turn_chance = 0.40
	t.exploration_reconnect_chance = 0.58
	t.exploration_band_bonus = 5
	return t

static func _theme_siege_services() -> SegmentThemeData:
	var t := _theme_outer_wall()
	t.id = &"siege_services"
	t.label = "Siege Service District"
	t.district_family = &"siege_services"
	t.base_terrain = "dirt"
	t.exploration_terrain = "grass"
	t.weight_empty = 0.28
	t.weight_building = 0.46
	t.weight_ruins = 0.26
	t.donjon_strength = 0.70
	t.meander_chance = 0.22
	return t

static func _theme_gate_district() -> SegmentThemeData:
	var t := _base(&"gate_district", "Gate District", &"gate_district")
	t.base_terrain = "dirt"
	t.exploration_terrain = "grass"
	t.landmark_count = 3
	t.weight_empty = 0.20
	t.weight_building = 0.56
	t.weight_ruins = 0.24
	t.district_lane_width_cells = 14
	t.district_plaza_size_cells = 22
	t.district_gap_chance = 0.04
	t.district_window_chance = 0.08
	t.donjon_strength = 0.78
	t.donjon_room_attempts = 28
	t.goal_dist_offset = 3
	t.ortho_limit = 5
	t.ortho_guard_bonus = 3
	t.waypoint_chance = 0.96
	t.meander_chance = 0.22
	t.branch_count_min = 3
	t.branch_count_max = 5
	t.max_branch_len = 4
	t.loop_budget_min = 2
	t.loop_budget_max = 3
	t.exploration_branch_count_min = 3
	t.exploration_branch_count_max = 5
	t.exploration_branch_len_min = 2
	t.exploration_branch_len_max = 4
	t.exploration_turn_chance = 0.34
	t.exploration_reconnect_chance = 0.54
	t.exploration_band_bonus = 5
	t.has_boss_arena = true
	t.end_mode = "BOSS_GATE"
	return t

static func _mix_seed(a: int, b: int) -> int:
	var h: int = int((a ^ (b * 0x9E3779B9)) & 0x7FFFFFFF)
	h = int((h * 1103515245 + 12345) & 0x7FFFFFFF)
	return h
