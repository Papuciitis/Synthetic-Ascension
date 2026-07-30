@tool
extends Resource
class_name SegmentThemeData

@export var id: StringName = &""
@export var label: String = ""

@export_group("District Identity")
@export var district_family: StringName = &"service_courtyards"
@export_enum("grass", "dirt", "urban", "mud") var base_terrain: String = "grass"
@export_enum("grass", "dirt", "urban", "mud") var exploration_terrain: String = "grass"
@export_range(1, 4, 1) var landmark_count: int = 2

@export_group("World Gen (ChunkManager)")
@export var weight_empty: float = 0.50
@export var weight_building: float = 0.30
@export var weight_ruins: float = 0.20

@export var district_lane_width_cells: int = 12
@export var district_plaza_size_cells: int = 16
@export var district_gap_chance: float = 0.10
@export var district_window_chance: float = 0.12

@export var donjon_strength: float = 0.50
@export var donjon_room_attempts: int = 18
@export var donjon_fill_wall_chance: float = 0.50
@export var donjon_ca_steps: int = 4

@export_group("Macro Layout (DistrictPlan)")
@export var goal_dist_offset: int = 0
@export var ortho_limit: int = 3
@export var ortho_guard_bonus: int = 0
@export var waypoint_chance: float = 0.80
@export var meander_chance: float = 0.22

@export var branch_count_min: int = 1
@export var branch_count_max: int = 2
@export var max_branch_len: int = 2

@export var loop_budget_min: int = 0
@export var loop_budget_max: int = 1

@export_group("Exploration Web")
@export var exploration_branch_count_min: int = 2
@export var exploration_branch_count_max: int = 4
@export var exploration_branch_len_min: int = 2
@export var exploration_branch_len_max: int = 4
@export_range(0.0, 1.0, 0.01) var exploration_turn_chance: float = 0.35
@export_range(0.0, 1.0, 0.01) var exploration_reconnect_chance: float = 0.40
@export var exploration_band_bonus: int = 3

@export_group("Special Beats")
@export var has_miniboss_arena: bool = false
@export var has_boss_arena: bool = false
@export_enum("EXIT_RITE", "MINIBOSS_GATE", "BOSS_GATE") var end_mode: String = "EXIT_RITE"
@export var arena_branch_len: int = 2

static func blend(a: SegmentThemeData, b: SegmentThemeData, t: float) -> SegmentThemeData:
	var out := SegmentThemeData.new()
	t = clampf(t, 0.0, 1.0)

	out.district_family = a.district_family if t < 0.5 else b.district_family
	out.base_terrain = a.base_terrain if t < 0.5 else b.base_terrain
	out.exploration_terrain = a.exploration_terrain if t < 0.5 else b.exploration_terrain
	out.landmark_count = int(round(lerpf(float(a.landmark_count), float(b.landmark_count), t)))

	out.weight_empty = lerpf(a.weight_empty, b.weight_empty, t)
	out.weight_building = lerpf(a.weight_building, b.weight_building, t)
	out.weight_ruins = lerpf(a.weight_ruins, b.weight_ruins, t)

	out.district_lane_width_cells = int(round(lerpf(float(a.district_lane_width_cells), float(b.district_lane_width_cells), t)))
	out.district_plaza_size_cells = int(round(lerpf(float(a.district_plaza_size_cells), float(b.district_plaza_size_cells), t)))
	out.district_gap_chance = lerpf(a.district_gap_chance, b.district_gap_chance, t)
	out.district_window_chance = lerpf(a.district_window_chance, b.district_window_chance, t)

	out.donjon_strength = lerpf(a.donjon_strength, b.donjon_strength, t)
	out.donjon_room_attempts = int(round(lerpf(float(a.donjon_room_attempts), float(b.donjon_room_attempts), t)))
	out.donjon_fill_wall_chance = lerpf(a.donjon_fill_wall_chance, b.donjon_fill_wall_chance, t)
	out.donjon_ca_steps = int(round(lerpf(float(a.donjon_ca_steps), float(b.donjon_ca_steps), t)))

	out.goal_dist_offset = int(round(lerpf(float(a.goal_dist_offset), float(b.goal_dist_offset), t)))
	out.ortho_limit = int(round(lerpf(float(a.ortho_limit), float(b.ortho_limit), t)))
	out.ortho_guard_bonus = int(round(lerpf(float(a.ortho_guard_bonus), float(b.ortho_guard_bonus), t)))
	out.waypoint_chance = lerpf(a.waypoint_chance, b.waypoint_chance, t)
	out.meander_chance = lerpf(a.meander_chance, b.meander_chance, t)

	out.branch_count_min = int(round(lerpf(float(a.branch_count_min), float(b.branch_count_min), t)))
	out.branch_count_max = int(round(lerpf(float(a.branch_count_max), float(b.branch_count_max), t)))
	out.max_branch_len = int(round(lerpf(float(a.max_branch_len), float(b.max_branch_len), t)))
	out.loop_budget_min = int(round(lerpf(float(a.loop_budget_min), float(b.loop_budget_min), t)))
	out.loop_budget_max = int(round(lerpf(float(a.loop_budget_max), float(b.loop_budget_max), t)))

	out.exploration_branch_count_min = int(round(lerpf(float(a.exploration_branch_count_min), float(b.exploration_branch_count_min), t)))
	out.exploration_branch_count_max = int(round(lerpf(float(a.exploration_branch_count_max), float(b.exploration_branch_count_max), t)))
	out.exploration_branch_len_min = int(round(lerpf(float(a.exploration_branch_len_min), float(b.exploration_branch_len_min), t)))
	out.exploration_branch_len_max = int(round(lerpf(float(a.exploration_branch_len_max), float(b.exploration_branch_len_max), t)))
	out.exploration_turn_chance = lerpf(a.exploration_turn_chance, b.exploration_turn_chance, t)
	out.exploration_reconnect_chance = lerpf(a.exploration_reconnect_chance, b.exploration_reconnect_chance, t)
	out.exploration_band_bonus = int(round(lerpf(float(a.exploration_band_bonus), float(b.exploration_band_bonus), t)))
	out.arena_branch_len = int(round(lerpf(float(a.arena_branch_len), float(b.arena_branch_len), t)))

	out.has_miniboss_arena = false
	out.has_boss_arena = false
	out.end_mode = "EXIT_RITE"
	return out

func apply_to_chunk_manager(cm: ChunkManager) -> void:
	if cm == null:
		return
	cm.weight_empty = weight_empty
	cm.weight_building = weight_building
	cm.weight_ruins = weight_ruins

	cm.district_lane_width_cells = district_lane_width_cells
	cm.district_plaza_size_cells = district_plaza_size_cells
	cm.district_gap_chance = district_gap_chance
	cm.district_window_chance = district_window_chance

	cm.donjon_strength = donjon_strength
	cm.donjon_room_attempts = donjon_room_attempts
	cm.donjon_fill_wall_chance = donjon_fill_wall_chance
	cm.donjon_ca_steps = donjon_ca_steps
	cm.set_fallback_terrain(StringName(exploration_terrain))
