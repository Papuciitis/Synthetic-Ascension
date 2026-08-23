extends Node2D
class_name Level1Builder

# Emitted after a milestone is processed; the opening controller awaits this
# to sequence the admissions-wing beats.
signal milestone_reached(id: StringName)

## Deterministic, authored Segment 1 layout.
##
## The route deliberately bends through five readable spaces:
## experimental laboratory -> archive wing -> containment courtyard ->
## service district -> outer gate plaza. Progression seals keep the Exit Rite
## physically unavailable until the relevant story beats are complete.

@export var cell_size_px: int = 64

@export_group("Scenes")
@export var cover_full_scene: PackedScene
@export var cover_window_scene: PackedScene
@export var cover_half_lab_scene: PackedScene
@export var fence_block_scene: PackedScene
@export var waypoint_scene: PackedScene
@export var wardstone_scene: PackedScene
@export var exit_rite_scene: PackedScene
@export var indoor_volume_scene: PackedScene = preload("res://scenes/world/volumes/IndoorVolume.tscn")

@export_group("Resonance — secondary sources")
@export_range(0.0, 1.0, 0.01) var resonance: float = 0.0
@export var resonance_per_sec: float = 0.00025
@export var resonance_per_kill: float = 0.002
@export var resonance_per_elite_kill: float = 0.008
@export var resonance_per_item_rarity: float = 0.0015
@export var resonance_ui_push_every: float = 0.15

@export_group("Resonance — authored milestones")
@export var resonance_synthesis: float = 0.10
@export var resonance_first_confrontation: float = 0.12
@export var resonance_wardstone_1: float = 0.17
@export var resonance_assistant_commitment: float = 0.12
@export var resonance_security_clear: float = 0.12
@export var resonance_wardstone_2: float = 0.17
@export var resonance_final_checkpoint: float = 0.13
@export var security_kills_required: int = 5

const _TEX_TILE_PX: int = 1024
const _TEX_STONE := preload("res://assets/world/ground/ground_stone_tiles_01.png")
const _TEX_COBBLE := preload("res://assets/world/ground/ground_cobble_01.png")
const _TEX_DIRT_PATH := preload("res://assets/world/ground/ground_dirt_path_01.png")
const _TEX_VEG_BUSH := preload("res://assets/world/vegetation/veg_bush_cluster_01.png")
const _TEX_VEG_OVER := preload("res://assets/world/vegetation/veg_overgrowth_island_01.png")
const _TEX_VEG_TREE := preload("res://assets/world/vegetation/veg_dead_tree_01.png")
const _MILESTONE_AREA := preload("res://core/systems/world/Level1MilestoneArea.gd")

# The public wing beats before the incident (story pass beats 1-2). All
# three are record-only: no resonance, no cards from the builder - the
# opening controller presents them during the full prologue.
const M_ADMITTED: StringName = &"admitted"
const M_WARD_FLICKER: StringName = &"ward_flicker"
const M_LAB_DOOR: StringName = &"lab_door"

const M_SYNTHESIS: StringName = &"synthesis"
const M_FIRST_CONFRONTATION: StringName = &"first_confrontation"
const M_WARDSTONE_1: StringName = &"wardstone_1"
const M_ASSISTANT: StringName = &"assistant_commitment"
const M_EVIDENCE: StringName = &"evidence_store"
const M_SECURITY_STARTED: StringName = &"security_started"
const M_SECURITY_CLEARED: StringName = &"security_cleared"
const M_WARDSTONE_2: StringName = &"wardstone_2"
const M_FINAL_CHECKPOINT: StringName = &"final_checkpoint"
const M_FINAL_PLAZA: StringName = &"final_plaza"

const B_ARCHIVE_EXIT: StringName = &"archive_exit"
const B_COURTYARD_SERVICE: StringName = &"courtyard_service"
const B_OUTER_APPROACH: StringName = &"outer_approach"

const FACILITY_TL := Vector2i(-20, -4)
const FACILITY_SIZE := Vector2i(42, 35)
# Public admissions wing south of the facility: reception, registry gallery,
# the "normal institution" the run opens inside before anything goes wrong.
const ADMISSIONS_RECT := Rect2i(Vector2i(-2, 31), Vector2i(24, 15))
const COURTYARD_RECT := Rect2i(Vector2i(-18, -23), Vector2i(37, 19))
const SERVICE_RECT := Rect2i(Vector2i(19, -35), Vector2i(35, 30))
const APPROACH_RECT := Rect2i(Vector2i(12, -60), Vector2i(43, 25))
const CLOSED_WAREHOUSE_RECT := Rect2i(Vector2i(30, -56), Vector2i(15, 17))

var _cm: ChunkManager = null
var _geo: Node2D = null
var _spawner: EnemySpawner = null
var _exit_rite: ExitRite = null
var _wardstone_1: Wardstone = null
var _wardstone_2: Wardstone = null

var _wall_kind: Dictionary = {}
var _fence_cells: Dictionary = {}
var _half_cells: Dictionary = {}
var _wall_nodes: Dictionary = {}
var _fence_nodes: Dictionary = {}
var _barrier_cells: Dictionary = {}
var _barrier_open: Dictionary = {}
var _connections_refresh_queued: bool = false
var _milestone_areas: Dictionary = {}
var _building_interiors: Array[Dictionary] = []
var _playable_regions: Array[Rect2i] = []
var _spawn_exclusions: Array[Rect2i] = []

var _start_cell := Vector2i(15, 25)
# Full-prologue runs open at the street entrance of the admissions wing;
# short/skip veterans keep starting beside the apparatus corridor.
var _entrance_cell := Vector2i(9, 43)
var _wardstone_1_cell := Vector2i(-11, 0)
var _wardstone_2_cell := Vector2i(43, -28)
var _gate_cell := Vector2i(20, -50)
var _res_ui_tick: float = 0.0
var _security_kills: int = 0
var _opening_sequence_active: bool = false

# Tracked secondaries (the three service-district rooms).
@export var resonance_secondary: float = 0.02
var _secondaries: Array[Dictionary] = []
var _secondary_completed: Dictionary = {}
var _active_secondary_id: int = -1
var _secondary_feedback_token: int = 0
var _secondary_tick: float = 0.0
var _last_checklist_key: String = ""


func _ready() -> void:
	# Child _ready() runs before game.gd can remove this node for later segments.
	# Stay completely inert so direct developer launches into Segment 2+ are safe.
	if Global != null and int(Global.attempt_segment) != 1:
		set_process(false)
		return
	# The playable opening owns progression messaging until it hands control
	# back. Set this before the first objective update to prevent a one-frame
	# synthesis/escape popup during scene construction.
	_opening_sequence_active = Global != null and not Global.attempt_opening_completed
	add_to_group(&"segment_spawn_filter")
	set_process(true)

	_cm = get_tree().get_first_node_in_group(&"chunk_manager") as ChunkManager
	_spawner = get_tree().get_first_node_in_group(&"enemy_spawner") as EnemySpawner
	if _cm != null and is_instance_valid(_cm):
		# Segment 1 is authored and keeps the explicit tile-conversion path. Streamed
		# procedural segments leave it disabled to avoid expanding regions into cells.
		_cm.tiled_world_rendering = true
		_cm.clear_manual_blocks()

	_geo = Node2D.new()
	_geo.name = "Level1_Geometry"
	add_child(_geo)
	if _cm != null and is_instance_valid(_cm) and _cm.tiled_world_rendering:
		_cm.call("_prepare_chunk_rendering", _geo, Vector2i.ZERO)

	_plan_level()
	_build_ground_stamps()
	_spawn_planned_geometry()
	_apply_connections()
	_tile_authored_geometry()
	_register_manual_blocks()
	_spawn_indoor_volumes()
	_place_wardstones_and_gate()
	_place_story_areas()
	_place_waypoints()
	_restore_segment_state()
	_move_player_to_start()
	_connect_run_events()
	_refresh_progression_seals()
	_update_objective()
	_update_gate_lock()
	# The chunk-streaming rearchitecture made streaming start explicit, but
	# only SegmentProcBuilder was updated. Without streamed chunk records,
	# is_cell_walkable() is false everywhere in Segment 1, which silently
	# killed ambient ring spawns AND flow-field walkability. Generation stays
	# disabled (game.gd), so streamed chunks are empty records + fallback
	# ground outside the authored footprint.
	if _cm != null and is_instance_valid(_cm) and _cm.has_method("start_streaming"):
		var player := get_tree().get_first_node_in_group(&"player") as Node2D
		var stream_center := player.global_position if player != null else _cell_to_world(_start_cell)
		_cm.start_streaming(stream_center)


func _exit_tree() -> void:
	if RunEvents == null:
		return
	var killed_cb := Callable(self, "_on_enemy_defeated")
	if RunEvents.enemy_defeated.is_connected(killed_cb):
		RunEvents.enemy_defeated.disconnect(killed_cb)
	var pickup_cb := Callable(self, "_on_pickup_to_equip")
	if RunEvents.pickup_fly_to_equip.is_connected(pickup_cb):
		RunEvents.pickup_fly_to_equip.disconnect(pickup_cb)


# -----------------------------------------------------------------------------
# Authored layout planning
# -----------------------------------------------------------------------------

func _plan_level() -> void:
	_wall_kind.clear()
	_fence_cells.clear()
	_half_cells.clear()
	_barrier_cells.clear()
	_barrier_open.clear()
	_building_interiors.clear()
	_playable_regions.clear()
	_spawn_exclusions.clear()

	_playable_regions.append(Rect2i(FACILITY_TL + Vector2i(1, 1), FACILITY_SIZE - Vector2i(2, 2)))
	_playable_regions.append(ADMISSIONS_RECT)
	_playable_regions.append(COURTYARD_RECT)
	_playable_regions.append(SERVICE_RECT)
	_playable_regions.append(APPROACH_RECT)
	_spawn_exclusions.append(CLOSED_WAREHOUSE_RECT)

	_plan_facility()
	_plan_admissions_wing()
	_plan_containment_courtyard()
	_plan_service_district()
	_plan_outer_approach()
	_plan_cover_and_landmarks()


func _plan_facility() -> void:
	var x0 := FACILITY_TL.x
	var y0 := FACILITY_TL.y
	var x1 := x0 + FACILITY_SIZE.x - 1
	var y1 := y0 + FACILITY_SIZE.y - 1

	# Exterior shell. The archive exit is a four-cell doorway, initially sealed.
	for x in range(x0, x1 + 1):
		if x < -8 or x > -5:
			_add_wall_cell(Vector2i(x, y0), _facility_window(Vector2i(x, y0)))
		# The lab door: the only connection to the public admissions wing.
		if x < 14 or x > 16:
			_add_wall_cell(Vector2i(x, y1), false)
	for y in range(y0, y1 + 1):
		_add_wall_cell(Vector2i(x0, y), _facility_window(Vector2i(x0, y)))
		_add_wall_cell(Vector2i(x1, y), _facility_window(Vector2i(x1, y)))

	# Experimental level and storage wing.
	_add_wall_line(Vector2i(x0 + 1, 14), Vector2i(x1 - 1, 14), [
		Vector2i(-14, 14), Vector2i(-13, 14), Vector2i(-12, 14), Vector2i(-11, 14),
		Vector2i(8, 14), Vector2i(9, 14), Vector2i(10, 14), Vector2i(11, 14), Vector2i(12, 14),
	], true)
	_add_wall_line(Vector2i(4, 15), Vector2i(4, y1 - 1), [
		Vector2i(4, 20), Vector2i(4, 21), Vector2i(4, 22), Vector2i(4, 23),
	], false)

	# Research and archive wing. Two cross-connected halves make this a wing,
	# not a single hall, while keeping crowd-sized doorways.
	_add_wall_line(Vector2i(-3, y0 + 1), Vector2i(-3, 13), [
		Vector2i(-3, 3), Vector2i(-3, 4), Vector2i(-3, 5), Vector2i(-3, 6),
	], false)
	_add_wall_line(Vector2i(x0 + 1, 5), Vector2i(-4, 5), [
		Vector2i(-13, 5), Vector2i(-12, 5), Vector2i(-11, 5), Vector2i(-10, 5),
	], true)
	_add_wall_line(Vector2i(-2, 5), Vector2i(x1 - 1, 5), [
		Vector2i(9, 5), Vector2i(10, 5), Vector2i(11, 5), Vector2i(12, 5),
	], true)

	# Landmark alcove around the first Wardstone, open to the south and east.
	_add_wall_line(Vector2i(-17, -2), Vector2i(-14, -2), [], false)
	_add_wall_line(Vector2i(-17, -2), Vector2i(-17, 2), [], false)

	_register_building_rect(FACILITY_TL, FACILITY_SIZE, false)
	_define_barrier(B_ARCHIVE_EXIT, [
		Vector2i(-8, -4), Vector2i(-7, -4), Vector2i(-6, -4), Vector2i(-5, -4),
	])


func _plan_admissions_wing() -> void:
	var x0 := ADMISSIONS_RECT.position.x
	var y0 := ADMISSIONS_RECT.position.y
	var x1 := ADMISSIONS_RECT.end.x - 1
	var y1 := ADMISSIONS_RECT.end.y - 1

	# Perimeter. North side is the facility's own south wall (lab door cut
	# there); the street entrance is a three-cell gap in the south wall.
	for x in range(x0, x1 + 1):
		if x < 8 or x > 10:
			_add_wall_cell(Vector2i(x, y1), false)
	for y in range(y0, y1):
		_add_wall_cell(Vector2i(x0, y), _facility_window(Vector2i(x0, y)))
		_add_wall_cell(Vector2i(x1, y), _facility_window(Vector2i(x1, y)))

	# Reception (south half) and registry gallery (north half), split by a
	# divider that funnels traffic toward the lab door.
	for x in range(x0 + 1, x1):
		if x < 13 or x > 16:
			_add_wall_cell(Vector2i(x, 37), false)

	# The night desk, notice boards and waiting benches: institutional
	# normalcy as furniture.
	for x in range(5, 10):
		_add_half_cell(Vector2i(x, 40))
	for c in [
		Vector2i(x0 + 1, 33), Vector2i(x0 + 1, 35),
		Vector2i(x1 - 1, 33), Vector2i(x1 - 1, 35),
		Vector2i(2, 43), Vector2i(15, 43), Vector2i(18, 34),
	]:
		_add_half_cell(c)


func _plan_containment_courtyard() -> void:
	var x0 := COURTYARD_RECT.position.x
	var y0 := COURTYARD_RECT.position.y
	var x1 := COURTYARD_RECT.end.x - 1
	var y1 := COURTYARD_RECT.end.y - 1

	for x in range(x0, x1 + 1):
		if x < -8 or x > -5:
			_add_fence_cell(Vector2i(x, y1))
		_add_fence_cell(Vector2i(x, y0))
	for y in range(y0 + 1, y1):
		_add_fence_cell(Vector2i(x0, y))
		if y < -16 or y > -12:
			_add_fence_cell(Vector2i(x1, y))

	# Two broad cover islands split sightlines without turning the courtyard into lanes.
	_fill_rect_walls(Vector2i(-14, -19), Vector2i(5, 4))
	_fill_rect_walls(Vector2i(7, -12), Vector2i(5, 4))
	_define_barrier(B_COURTYARD_SERVICE, [
		Vector2i(18, -16), Vector2i(18, -15), Vector2i(18, -14),
		Vector2i(18, -13), Vector2i(18, -12),
	])


func _plan_service_district() -> void:
	var x0 := SERVICE_RECT.position.x
	var y0 := SERVICE_RECT.position.y
	var x1 := SERVICE_RECT.end.x - 1
	var y1 := SERVICE_RECT.end.y - 1

	for x in range(x0, x1 + 1):
		if x < 47 or x > 51:
			_add_fence_cell(Vector2i(x, y0))
		_add_fence_cell(Vector2i(x, y1))
	for y in range(y0 + 1, y1):
		if y < -16 or y > -12:
			_add_fence_cell(Vector2i(x0, y))
		_add_fence_cell(Vector2i(x1, y))

	# The three service rooms are tracked secondaries (SEGMENT1_REBUILD's
	# "detours"): guaranteed single-item payout so a searched room never
	# reads as empty, announced on approach, completed on claim.

	# Loading office: optional records/loot room, entered from the yard.
	_rect_perimeter_with_bottom_door(Vector2i(23, -32), Vector2i(10, 10), 27, 28)
	_register_building_rect(Vector2i(23, -32), Vector2i(10, 10), true, {
		"small_loot_chance": 1.0,
		"secondary": true,
		"sec_title": "SECONDARY • LOADING OFFICE",
		"sec_detail": "Manifest records and unshipped stock. Containment has not swept it.",
	})

	# Service warehouse: optional detour with a wide western loading door.
	# The "controlled security encounter": entering starts a small interior
	# fight; the reward releases when it is cleared.
	_rect_perimeter_with_left_door(Vector2i(38, -24), Vector2i(12, 13), -20, -17)
	_register_building_rect(Vector2i(38, -24), Vector2i(12, 13), true, {
		"small_loot_chance": 1.0,
		"local_encounter_enabled": true,
		"local_encounter_count": 4,
		"secondary": true,
		"sec_title": "SECONDARY • SERVICE WAREHOUSE",
		"sec_detail": "Sealed stock behind a security detail. Clear the interior to claim it.",
	})

	# Maintenance kiosk and checkpoint cover give the combat arena landmarks.
	_rect_perimeter_with_bottom_door(Vector2i(25, -12), Vector2i(8, 5), 28, 29)
	_register_building_rect(Vector2i(25, -12), Vector2i(8, 5), true, {
		"small_loot_chance": 1.0,
		"secondary": true,
		"sec_title": "SECONDARY • MAINTENANCE KIOSK",
		"sec_detail": "Tool lockers and ward spares. A quick detour.",
	})
	_fill_rect_walls(Vector2i(21, -22), Vector2i(4, 5))
	_fill_rect_walls(Vector2i(32, -29), Vector2i(4, 4))

	_define_barrier(B_OUTER_APPROACH, [
		Vector2i(47, -35), Vector2i(48, -35), Vector2i(49, -35),
		Vector2i(50, -35), Vector2i(51, -35),
	])


func _plan_outer_approach() -> void:
	var x0 := APPROACH_RECT.position.x
	var y0 := APPROACH_RECT.position.y
	var x1 := APPROACH_RECT.end.x - 1
	var y1 := APPROACH_RECT.end.y - 1

	for x in range(x0, x1 + 1):
		_add_fence_cell(Vector2i(x, y0))
		if x < 47 or x > 51:
			_add_fence_cell(Vector2i(x, y1))
	for y in range(y0 + 1, y1):
		_add_fence_cell(Vector2i(x0, y))
		_add_fence_cell(Vector2i(x1, y))

	# A sealed institutional warehouse blocks all sightlines from the service
	# entrance. The player must round it before the Exit Rite can be seen.
	_rect_perimeter_walls(CLOSED_WAREHOUSE_RECT.position, CLOSED_WAREHOUSE_RECT.size)

	# The gate plaza is a distinct stone destination with a broad eastern door.
	var plaza_tl := Vector2i(13, -57)
	var plaza_size := Vector2i(15, 14)
	var px1 := plaza_tl.x + plaza_size.x - 1
	var py1 := plaza_tl.y + plaza_size.y - 1
	for x in range(plaza_tl.x, px1 + 1):
		_add_wall_cell(Vector2i(x, plaza_tl.y), false)
		_add_wall_cell(Vector2i(x, py1), false)
	for y in range(plaza_tl.y + 1, py1):
		if y < -52 or y > -48:
			_add_wall_cell(Vector2i(px1, y), false)


func _plan_cover_and_landmarks() -> void:
	# Experimental benches frame the synthesis array.
	for x in range(8, 18):
		if x != 12 and x != 13:
			_add_half_cell(Vector2i(x, 19))
	for x in range(8, 18):
		if x != 10 and x != 16:
			_add_half_cell(Vector2i(x, 24))

	# Archive shelves and storage crates leave three-cell crowd lanes.
	for y in range(7, 13, 2):
		_add_half_cell(Vector2i(-16, y))
		_add_half_cell(Vector2i(-8, y))
	_add_half_cell(Vector2i(-15, 21))
	_add_half_cell(Vector2i(-10, 24))
	_add_half_cell(Vector2i(-5, 27))

	# Courtyard and service cover.
	for c in [
		Vector2i(-5, -18), Vector2i(2, -9), Vector2i(13, -19),
		Vector2i(23, -13), Vector2i(29, -19), Vector2i(35, -8),
		Vector2i(42, -31), Vector2i(49, -27), Vector2i(47, -42),
		Vector2i(22, -39), Vector2i(25, -55),
	]:
		_add_half_cell(c)

	_place_deco(_TEX_VEG_OVER, Vector2i(-15, -8), 0.12, 0.62, -60)
	_place_deco(_TEX_VEG_BUSH, Vector2i(14, -21), 0.10, 0.72, -60)
	_place_deco(_TEX_VEG_TREE, Vector2i(21, -31), 0.10, 0.68, -60)
	_place_deco(_TEX_VEG_OVER, Vector2i(52, -39), 0.12, 0.66, -60)
	_place_deco(_TEX_VEG_TREE, Vector2i(16, -58), 0.10, 0.62, -60)


# -----------------------------------------------------------------------------
# Ground coverage
# -----------------------------------------------------------------------------

func _build_ground_stamps() -> void:
	# The player-centred base floor remains underneath this entire area. These
	# few regional stamps establish stage identity without thousands of tiles.
	_stamp_ground(FACILITY_TL, FACILITY_SIZE, _TEX_STONE, 0.96, 0.56)
	_stamp_ground(FACILITY_TL + Vector2i(1, 1), FACILITY_SIZE - Vector2i(2, 2), _TEX_STONE, 0.98, 0.48)
	# Admissions wing: brighter public stone than the research floor.
	_stamp_ground(ADMISSIONS_RECT.position, ADMISSIONS_RECT.size, _TEX_STONE, 0.97, 0.66)
	_stamp_ground(COURTYARD_RECT.position, COURTYARD_RECT.size, _TEX_COBBLE, 0.90, 0.64)
	_stamp_ground(Vector2i(19, -23), Vector2i(35, 18), _TEX_DIRT_PATH, 0.72, 0.68)
	_stamp_ground(Vector2i(20, -35), Vector2i(34, 12), _TEX_COBBLE, 0.78, 0.61)
	_stamp_ground(Vector2i(46, -59), Vector2i(8, 24), _TEX_DIRT_PATH, 0.76, 0.68)
	_stamp_ground(Vector2i(27, -59), Vector2i(27, 6), _TEX_DIRT_PATH, 0.76, 0.68)
	_stamp_ground(Vector2i(13, -57), Vector2i(15, 14), _TEX_STONE, 0.96, 0.58)
	_stamp_ground(Vector2i(15, -55), Vector2i(11, 10), _TEX_COBBLE, 0.58, 0.63)


func _stamp_ground(cell_tl: Vector2i, size: Vector2i, tex: Texture2D, alpha: float, brightness: float) -> void:
	if tex == null or size.x <= 0 or size.y <= 0:
		return
	if _cm != null and is_instance_valid(_cm) and _cm.tiled_world_rendering:
		_cm.paint_tiled_rect(
			_geo, &"floor", Rect2i(cell_tl, size), tex, _TEX_TILE_PX, -95,
			Color(brightness, brightness, brightness, alpha)
		)
		return
	var spr := Sprite2D.new()
	spr.name = "Stamp_%d_%d" % [cell_tl.x, cell_tl.y]
	spr.z_index = -95
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	spr.region_enabled = true
	var rng := RandomNumberGenerator.new()
	rng.seed = int((cell_tl.x * 73856093) ^ (cell_tl.y * 19349663) ^ 0xA1B2C3D)
	var ox := float(rng.randi_range(0, _TEX_TILE_PX - 1))
	var oy := float(rng.randi_range(0, _TEX_TILE_PX - 1))
	spr.region_rect = Rect2(ox, oy, float(_TEX_TILE_PX * size.x), float(_TEX_TILE_PX * size.y))
	var scale_factor := float(cell_size_px) / float(_TEX_TILE_PX)
	spr.scale = Vector2(scale_factor, scale_factor)
	spr.modulate = Color(brightness, brightness, brightness, alpha)
	spr.position = _cell_rect_center(cell_tl, size)
	_geo.add_child(spr)


# -----------------------------------------------------------------------------
# Geometry creation and navigation registration
# -----------------------------------------------------------------------------

func _spawn_planned_geometry() -> void:
	_wall_nodes.clear()
	_fence_nodes.clear()
	for key in _wall_kind.keys():
		var cell: Vector2i = key
		var scene: PackedScene = cover_window_scene if int(_wall_kind[cell]) == 1 else cover_full_scene
		if scene == null:
			continue
		var node := scene.instantiate() as Node2D
		if node == null:
			continue
		node.global_position = _cell_to_world(cell)
		node.set_meta(&"_tile_repeat_visual", true)
		_geo.add_child(node)
		_wall_nodes[cell] = node

	for key in _fence_cells.keys():
		var cell: Vector2i = key
		if fence_block_scene == null:
			break
		var node := fence_block_scene.instantiate() as Node2D
		if node == null:
			continue
		node.global_position = _cell_to_world(cell)
		node.set_meta(&"_tile_repeat_visual", true)
		_geo.add_child(node)
		_fence_nodes[cell] = node

	if cover_half_lab_scene != null:
		for key in _half_cells.keys():
			var cell: Vector2i = key
			var node := cover_half_lab_scene.instantiate() as Node2D
			if node == null:
				continue
			node.global_position = _cell_to_world(cell)
			node.set_meta(&"_tile_repeat_visual", true)
			_geo.add_child(node)


func _apply_connections() -> void:
	for key in _wall_nodes.keys():
		var cell: Vector2i = key
		var node: Node = _wall_nodes.get(cell) as Node
		if node == null or not is_instance_valid(node):
			continue
		var mask := 0
		if _wall_kind.has(cell + Vector2i.UP): mask |= 1
		if _wall_kind.has(cell + Vector2i.RIGHT): mask |= 2
		if _wall_kind.has(cell + Vector2i.DOWN): mask |= 4
		if _wall_kind.has(cell + Vector2i.LEFT): mask |= 8
		if node.get("connections_mask") != null and int(node.get("connections_mask")) != mask:
			node.set("connections_mask", mask)

	for key in _fence_nodes.keys():
		var cell: Vector2i = key
		var node: Node = _fence_nodes.get(cell) as Node
		if node == null or not is_instance_valid(node):
			continue
		var mask := 0
		if _fence_cells.has(cell + Vector2i.UP): mask |= 1
		if _fence_cells.has(cell + Vector2i.RIGHT): mask |= 2
		if _fence_cells.has(cell + Vector2i.DOWN): mask |= 4
		if _fence_cells.has(cell + Vector2i.LEFT): mask |= 8
		if node.get("connections_mask") != null and int(node.get("connections_mask")) != mask:
			node.set("connections_mask", mask)


func _tile_authored_geometry() -> void:
	if _cm == null or not is_instance_valid(_cm) or _geo == null:
		return
	if not _cm.tiled_world_rendering:
		return
	_cm.call("_prepare_chunk_rendering", _geo, Vector2i.ZERO)
	_cm.call("_tile_repeated_visuals", _geo)


func _queue_connections_refresh() -> void:
	if _connections_refresh_queued:
		return
	_connections_refresh_queued = true
	call_deferred("_flush_connections_refresh")


func _flush_connections_refresh() -> void:
	_connections_refresh_queued = false
	if not is_inside_tree():
		return
	_apply_connections()
	_repaint_authored_connections()


func _repaint_authored_connections() -> void:
	if _cm == null or not is_instance_valid(_cm) or _geo == null or not _cm.tiled_world_rendering:
		return
	for key in _wall_nodes.keys():
		var cell: Vector2i = key
		var node := _wall_nodes.get(cell) as Node
		if node != null and is_instance_valid(node):
			_cm.repaint_repeated_visual(_geo, cell, node)
	for key in _fence_nodes.keys():
		var cell: Vector2i = key
		var node := _fence_nodes.get(cell) as Node
		if node != null and is_instance_valid(node):
			_cm.repaint_repeated_visual(_geo, cell, node)


func _register_manual_blocks() -> void:
	if _cm == null or not is_instance_valid(_cm):
		return
	for key in _wall_kind.keys():
		_cm.register_manual_block_cell(key)
	for key in _fence_cells.keys():
		_cm.register_manual_block_cell(key)
	for key in _half_cells.keys():
		_cm.register_manual_block_cell(key)


func _spawn_indoor_volumes() -> void:
	if indoor_volume_scene == null:
		return
	var building_id := 1101
	for entry in _building_interiors:
		var rect: Rect2i = entry["rect"]
		var volume := indoor_volume_scene.instantiate() as IndoorVolume
		if volume == null:
			continue
		_geo.add_child(volume)
		volume.exploration_loot_enabled = bool(entry["loot"])
		# The facility interior is the playfield, not a reward room: ambient
		# containment pressure must spawn inside it. Reward rooms (loot=true)
		# keep the default exclusion so their encounters own the interior.
		volume.ambient_spawn_excluded = bool(entry["loot"])
		var cfg: Dictionary = (entry.get("cfg", {}) as Dictionary).duplicate()
		var is_secondary := bool(cfg.get("secondary", false))
		cfg.erase("secondary")
		var sec_title := String(cfg.get("sec_title", ""))
		var sec_detail := String(cfg.get("sec_detail", ""))
		cfg.erase("sec_title")
		cfg.erase("sec_detail")
		if is_secondary:
			cfg["secondary_objective_id"] = building_id
			_secondaries.append({
				"id": building_id,
				"world": Rect2(
					Vector2(rect.position) * float(cell_size_px),
					Vector2(rect.size) * float(cell_size_px)
				).get_center(),
				"title": sec_title,
				"detail": sec_detail,
			})
		volume.configure(rect.position, rect.size, cell_size_px, building_id, cfg)
		building_id += 1


# -----------------------------------------------------------------------------
# Authored objectives and progression
# -----------------------------------------------------------------------------

func _place_wardstones_and_gate() -> void:
	if wardstone_scene != null:
		_wardstone_1 = wardstone_scene.instantiate() as Wardstone
		if _wardstone_1 != null:
			_wardstone_1.name = "ArchiveWardstone"
			_wardstone_1.narrative_index = 1
			_wardstone_1.global_position = _cell_to_world(_wardstone_1_cell)
			add_child(_wardstone_1)
			_wardstone_1.activated.connect(_on_wardstone_activated.bind(1))

		_wardstone_2 = wardstone_scene.instantiate() as Wardstone
		if _wardstone_2 != null:
			_wardstone_2.name = "ServiceWardstone"
			_wardstone_2.narrative_index = 2
			_wardstone_2.global_position = _cell_to_world(_wardstone_2_cell)
			add_child(_wardstone_2)
			_wardstone_2.activated.connect(_on_wardstone_activated.bind(2))

	if exit_rite_scene != null:
		_exit_rite = exit_rite_scene.instantiate() as ExitRite
		if _exit_rite != null:
			_exit_rite.name = "OuterExitRite"
			_exit_rite.narrative_mode = true
			_exit_rite.hide_location_while_locked = true
			_exit_rite.global_position = _cell_to_world(_gate_cell)
			add_child(_exit_rite)
			_exit_rite.cleared.connect(_on_gate_cleared)


func _place_story_areas() -> void:
	# Admissions-wing beats (normalcy, wrongness, handoff to the prologue).
	_make_milestone_area(M_ADMITTED, Vector2i(9, 41), Vector2i(7, 3), false)
	_make_milestone_area(M_WARD_FLICKER, Vector2i(15, 34), Vector2i(7, 4), false)
	_make_milestone_area(M_LAB_DOOR, Vector2i(15, 30), Vector2i(5, 3), false)
	_make_milestone_area(M_SYNTHESIS, Vector2i(12, 21), Vector2i(5, 5), true)
	# Full-height threshold strips make the two story beats unavoidable while
	# preserving freedom inside each combat space.
	_make_milestone_area(M_ASSISTANT, Vector2i(4, -14), Vector2i(5, 17), false)
	# The first build choice fires on the mandatory route into the service
	# district, before the security fight; the kiosk beside it is the
	# fiction anchor (evidence store 3-B) and stays a loot secondary.
	_make_milestone_area(M_EVIDENCE, Vector2i(25, -20), Vector2i(3, 27), false)
	_make_milestone_area(M_SECURITY_STARTED, Vector2i(34, -20), Vector2i(5, 27), false)
	_make_milestone_area(M_FINAL_PLAZA, Vector2i(26, -50), Vector2i(7, 11), false)


func _make_milestone_area(id: StringName, center_cell: Vector2i, size_cells: Vector2i, marker: bool) -> void:
	var area := _MILESTONE_AREA.new() as Level1MilestoneArea
	area.name = "Milestone_%s" % String(id)
	add_child(area)
	area.configure(id, _cell_to_world(center_cell), Vector2(size_cells * cell_size_px), marker)
	area.reached.connect(_on_milestone_reached)
	_milestone_areas[id] = area


func _restore_segment_state() -> void:
	resonance = clampf(float(Global.attempt_segment1_resonance) if Global != null else resonance, 0.0, 1.0)
	# The assistant is the first actual follower in this chapter. Preserve larger
	# recovered/dev balances, but do not display the legacy starting one early.
	if Global != null and int(Global.followers) <= 1:
		Global.set_followers(1 if _has_milestone(M_ASSISTANT) else 0)
	for id in _milestone_areas.keys():
		if _has_milestone(id):
			(_milestone_areas[id] as Level1MilestoneArea).mark_completed()
	if _has_milestone(M_WARDSTONE_1) and _wardstone_1 != null:
		_wardstone_1.restore_active()
	if _has_milestone(M_WARDSTONE_2) and _wardstone_2 != null:
		_wardstone_2.restore_active()
	# Quit during the evidence offer: the area will not refire, but the
	# choice is still owed. Re-present it once the scene settles.
	if _has_milestone(M_EVIDENCE) and Global != null and Global.pending_augment_pick:
		call_deferred("_begin_evidence_choice")
	_apply_restored_spawn_stage()


func _connect_run_events() -> void:
	if RunEvents == null:
		return
	var killed_cb := Callable(self, "_on_enemy_defeated")
	if not RunEvents.enemy_defeated.is_connected(killed_cb):
		RunEvents.enemy_defeated.connect(killed_cb)
	var pickup_cb := Callable(self, "_on_pickup_to_equip")
	if not RunEvents.pickup_fly_to_equip.is_connected(pickup_cb):
		RunEvents.pickup_fly_to_equip.connect(pickup_cb)
	if RunEvents.has_signal("secondary_objective_completed"):
		var secondary_cb := Callable(self, "_on_secondary_completed")
		if not RunEvents.secondary_objective_completed.is_connected(secondary_cb):
			RunEvents.secondary_objective_completed.connect(secondary_cb)


func _on_milestone_reached(id: StringName) -> void:
	# The playable prologue owns these beats while active. Its controller grants
	# the same durable milestones after the player performs the authored action.
	if _opening_sequence_active and id in [M_SYNTHESIS, M_ASSISTANT]:
		return
	match id:
		M_ADMITTED, M_WARD_FLICKER, M_LAB_DOOR:
			_record_milestone(id)
		M_EVIDENCE:
			if _record_milestone(M_EVIDENCE):
				_begin_evidence_choice()
		M_SYNTHESIS:
			if _grant_milestone(M_SYNTHESIS, resonance_synthesis):
				_blocking_card(
					&"segment1_synthesis",
					"SYNTHESIS STABLE",
					"%s\n\n%s\n\n%s" % [Segment1Text.SYNTHESIS_STABLE, Segment1Text.SYNTHESIS_RESULT, Segment1Text.CONTAINMENT_NOTICE]
				)
				_set_spawn_stage(Segment1SpawnProfile.Stage.INITIAL_CONTAINMENT)
		M_ASSISTANT:
			if _grant_milestone(M_ASSISTANT, resonance_assistant_commitment):
				if Global != null:
					Global.transaction_followers(maxi(0, 1 - int(Global.followers)), &"assistant_commitment", {}, false, false)
				_tip(Segment1Text.ASSISTANT_COMMITMENT, 5.5)
				_blocking_card(
					&"followers_first",
					"FOLLOWERS",
					"People committed to preserving and spreading the Pattern.\n\nTheir belief can secure supplies and reconstruct you after death.\n\nSpending or losing Followers weakens the movement.\n\n%s" % Segment1Text.RESONANCE_INTRO
				)
				_set_spawn_stage(Segment1SpawnProfile.Stage.COURTYARD)
		M_SECURITY_STARTED:
			if _record_milestone(M_SECURITY_STARTED):
				_security_kills = 0
				_tip(Segment1Text.SECURITY_START, 3.5)
				_set_spawn_stage(Segment1SpawnProfile.Stage.SERVICE)
				if _spawner != null:
					_spawner.queue_authored_wave(3, 0.8, 2.25)
		M_FINAL_PLAZA:
			if _record_milestone(M_FINAL_PLAZA):
				# Arrived: the arrow's job is done.
				if Global != null:
					Global.objective_target_pos = Vector2.INF
				# Milestones provide 93%; ordinary play normally supplies the rest.
				# This arrival top-up is the anti-wait safety net, not a passive timer.
				if resonance < 1.0:
					_add_resonance(1.0 - resonance, true)
				_tip(Segment1Text.RITE_LOGIC, 5.0)
				_tip(Segment1Text.GATE_UNSEALED, 3.5)
				_set_spawn_stage(Segment1SpawnProfile.Stage.EXIT_RITE)
	_refresh_progression_seals()
	_update_objective()
	_update_gate_lock()
	milestone_reached.emit(id)


func _on_wardstone_activated(_stone: Wardstone, index: int) -> void:
	if index == 1:
		_grant_milestone(M_WARDSTONE_1, resonance_wardstone_1)
		_set_spawn_stage(Segment1SpawnProfile.Stage.ARCHIVE)
	elif index == 2:
		_grant_milestone(M_WARDSTONE_2, resonance_wardstone_2)
	_refresh_progression_seals()
	_update_objective()
	_update_gate_lock()


func _on_enemy_defeated(context: RefCounted) -> void:
	if context == null:
		return
	var metadata := context.get("metadata") as Dictionary
	if bool(metadata.get("opening_scripted", false)):
		return
	var is_elite := bool(context.get("is_elite"))
	_add_resonance(resonance_per_elite_kill if is_elite else resonance_per_kill, false)

	if _has_milestone(M_SYNTHESIS) and not _has_milestone(M_FIRST_CONFRONTATION):
		if _grant_milestone(M_FIRST_CONFRONTATION, resonance_first_confrontation):
			_tip(Segment1Text.FIRST_LETHAL, 4.0)
			_set_spawn_stage(Segment1SpawnProfile.Stage.ARCHIVE)

	if _has_milestone(M_SECURITY_STARTED) and not _has_milestone(M_SECURITY_CLEARED):
		_security_kills += 1
		if _security_kills >= maxi(1, security_kills_required):
			if _grant_milestone(M_SECURITY_CLEARED, resonance_security_clear):
				_tip(Segment1Text.SECURITY_CLEAR, 3.5)
		else:
			_emit_objective(
				Segment1Text.OBJECTIVE_SECURITY_TITLE,
				"Containment officers remaining: %d" % (maxi(1, security_kills_required) - _security_kills)
			)

	_refresh_progression_seals()
	_update_objective()
	_update_gate_lock()


func _on_pickup_to_equip(_start: Vector2, _slot: int, inst: ItemInstance, _upgraded: bool) -> void:
	if inst == null:
		return
	_add_resonance(float(inst.rarity) * resonance_per_item_rarity, false)
	_update_gate_lock()


# Beat 7: the first build choice, staged as looting the institution's own
# evidence store. Card first, then the augment offer; veterans who already
# own augments get flavor only (their pick never pends).
func _begin_evidence_choice() -> void:
	if Global == null or not Global.pending_augment_pick:
		_tip(Segment1Text.EVIDENCE_EMPTY_TIP, 4.5)
		return
	var modal := get_tree().get_first_node_in_group(&"tutorial_modal_controller")
	if modal != null and modal.has_method("present_card_and_wait"):
		await modal.call(
			"present_card_and_wait",
			Segment1Text.EVIDENCE_TITLE, Segment1Text.EVIDENCE_BODY, "EVIDENCE STORE 3-B"
		)
	var game := get_tree().current_scene
	if game != null and game.has_method("present_augment_pick_and_wait"):
		await game.call("present_augment_pick_and_wait")


func _on_secondary_completed(objective_id: int) -> void:
	if objective_id <= 0 or _secondary_completed.has(objective_id):
		return
	var entry := _find_secondary(objective_id)
	if entry.is_empty():
		return
	_secondary_completed[objective_id] = true
	_add_resonance(resonance_secondary, true)
	if _active_secondary_id == objective_id:
		_active_secondary_id = -1
	_secondary_feedback_token += 1
	var feedback_token := _secondary_feedback_token
	if RunEvents != null and RunEvents.has_signal("secondary_objective_changed"):
		RunEvents.secondary_objective_changed.emit("✓ SECONDARY COMPLETE", String(entry.get("detail", "")))
	_clear_secondary_after_delay(feedback_token)


func _clear_secondary_after_delay(feedback_token: int) -> void:
	await get_tree().create_timer(2.4).timeout
	if feedback_token != _secondary_feedback_token:
		return
	_clear_secondary_ui()


func _clear_secondary_ui() -> void:
	_secondary_feedback_token += 1
	if RunEvents != null and RunEvents.has_signal("secondary_objective_changed"):
		RunEvents.secondary_objective_changed.emit("", "")


func _find_secondary(objective_id: int) -> Dictionary:
	for entry in _secondaries:
		if int(entry.get("id", 0)) == objective_id:
			return entry
	return {}


func _update_secondary_announcement() -> void:
	if _opening_sequence_active or _secondaries.is_empty():
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	var nearby_id := -1
	var nearby_entry: Dictionary = {}
	var best_distance_sq := 600.0 * 600.0
	for entry in _secondaries:
		var objective_id := int(entry.get("id", 0))
		if _secondary_completed.has(objective_id):
			continue
		# A room whose loot was claimed in an earlier session has nothing
		# left to offer; do not advertise it after Continue.
		if Global != null and Global.has_claimed_loot(objective_id):
			continue
		var distance_sq := player.global_position.distance_squared_to(entry.get("world", Vector2.INF) as Vector2)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			nearby_id = objective_id
			nearby_entry = entry
	if nearby_id == _active_secondary_id:
		return
	_active_secondary_id = nearby_id
	_secondary_feedback_token += 1
	if nearby_id == -1:
		_clear_secondary_ui()
		return
	if RunEvents != null and RunEvents.has_signal("secondary_objective_changed"):
		RunEvents.secondary_objective_changed.emit(String(nearby_entry.get("title", "")), String(nearby_entry.get("detail", "")))


func _refresh_progression_seals() -> void:
	if _has_milestone(M_WARDSTONE_1):
		_open_barrier(B_ARCHIVE_EXIT)
	if _has_milestone(M_WARDSTONE_1) and _has_milestone(M_FIRST_CONFRONTATION) and _has_milestone(M_ASSISTANT):
		_open_barrier(B_COURTYARD_SERVICE)
	if _has_milestone(M_WARDSTONE_2) and _has_milestone(M_SECURITY_CLEARED):
		if not _has_milestone(M_FINAL_CHECKPOINT):
			if _grant_milestone(M_FINAL_CHECKPOINT, resonance_final_checkpoint):
				_tip(Segment1Text.CHECKPOINT_DISABLED, 4.0)
				# Late-segment guidance: from here the player should know
				# WHERE they're escaping to, not wander the campus.
				if Global != null:
					Global.objective_target_pos = _cell_to_world(_gate_cell)
		_open_barrier(B_OUTER_APPROACH)
		_set_spawn_stage(Segment1SpawnProfile.Stage.OUTER_APPROACH)


func _open_barrier(id: StringName) -> void:
	if bool(_barrier_open.get(id, false)):
		return
	_barrier_open[id] = true
	var cells: Array = _barrier_cells.get(id, [])
	for value in cells:
		var cell: Vector2i = value
		_wall_kind.erase(cell)
		var node := _wall_nodes.get(cell) as Node
		if node != null and is_instance_valid(node):
			node.queue_free()
		if _cm != null and is_instance_valid(_cm) and _geo != null:
			_cm.erase_repeated_visual(_geo, cell)
		_wall_nodes.erase(cell)
		if _cm != null and is_instance_valid(_cm):
			_cm.unregister_manual_block_cell(cell)
	# Milestones originate in Area2D.body_entered. Rebuilding live collision
	# shapes during that callback runs while PhysicsServer2D is flushing queries.
	_queue_connections_refresh()


func _update_objective() -> void:
	if not _has_milestone(M_SYNTHESIS):
		_emit_objective(Segment1Text.OBJECTIVE_SYNTHESIS_TITLE, Segment1Text.OBJECTIVE_SYNTHESIS_DETAIL)
	elif not _has_milestone(M_WARDSTONE_1):
		_emit_objective(Segment1Text.OBJECTIVE_ESCAPE_TITLE, Segment1Text.OBJECTIVE_ESCAPE_DETAIL)
	elif not _has_milestone(M_ASSISTANT) or not _has_milestone(M_FIRST_CONFRONTATION):
		_emit_objective(Segment1Text.OBJECTIVE_COURTYARD_TITLE, Segment1Text.OBJECTIVE_COURTYARD_DETAIL)
	elif not _has_milestone(M_SECURITY_STARTED):
		_emit_objective(Segment1Text.OBJECTIVE_SERVICE_TITLE, Segment1Text.OBJECTIVE_SERVICE_DETAIL)
	elif not _has_milestone(M_SECURITY_CLEARED):
		_emit_objective(
			Segment1Text.OBJECTIVE_SECURITY_TITLE,
			"Containment officers remaining: %d" % maxi(0, maxi(1, security_kills_required) - _security_kills)
		)
	elif not _has_milestone(M_WARDSTONE_2):
		_emit_objective(Segment1Text.OBJECTIVE_WARDSTONE_2_TITLE, Segment1Text.OBJECTIVE_WARDSTONE_2_DETAIL)
	elif not _has_milestone(M_FINAL_CHECKPOINT):
		_emit_objective(Segment1Text.OBJECTIVE_CHECKPOINT_TITLE, Segment1Text.OBJECTIVE_CHECKPOINT_DETAIL)
	elif not _has_milestone(M_FINAL_PLAZA):
		_emit_objective(Segment1Text.OBJECTIVE_GATE_TITLE, Segment1Text.OBJECTIVE_GATE_DETAIL)
	else:
		_emit_objective(Segment1Text.OBJECTIVE_RITE_TITLE, Segment1Text.OBJECTIVE_RITE_DETAIL)


func _emit_objective(title: String, detail: String) -> void:
	if RunEvents != null:
		if _opening_sequence_active:
			RunEvents.objective_changed.emit("", "")
		else:
			RunEvents.objective_changed.emit(title, detail)


func _grant_milestone(id: StringName, amount: float) -> bool:
	if not _record_milestone(id):
		return false
	_add_resonance(amount, true)
	return true


func _record_milestone(id: StringName) -> bool:
	if Global == null:
		return false
	return Global.record_segment1_milestone(id)


func _has_milestone(id: StringName) -> bool:
	return Global != null and Global.has_segment1_milestone(id)


func _add_resonance(amount: float, persist_now: bool) -> void:
	resonance = clampf(resonance + amount, 0.0, 1.0)
	if Global != null:
		Global.attempt_segment1_resonance = resonance
		if persist_now:
			Global.set_segment1_resonance(resonance)
	_push_resonance_ui()


func _set_spawning_enabled(value: bool) -> void:
	if _spawner == null or not is_instance_valid(_spawner):
		_spawner = get_tree().get_first_node_in_group(&"enemy_spawner") as EnemySpawner
	if _spawner != null:
		_spawner.set_spawning_enabled(value)

## Playable-opening bridge. These methods deliberately reuse the established
## Segment 1 milestone and spawn-stage machinery instead of maintaining a
## second progression model.
func get_opening_anchors() -> Dictionary:
	return {
		"start": _cell_to_world(_start_cell),
		"apparatus": _cell_to_world(Vector2i(12, 21)),
		"calibration": _cell_to_world(Vector2i(16, 21)),
		"construct": _cell_to_world(Vector2i(9, 21)),
		"officer": _cell_to_world(Vector2i(16, 18)),
		"records": _cell_to_world(Vector2i(8, 17)),
		"entrance": _cell_to_world(_entrance_cell),
		"desk": _cell_to_world(Vector2i(7, 39)),
	}

func begin_opening_sequence() -> void:
	_opening_sequence_active = true
	_emit_objective("", "")
	_set_spawn_stage(Segment1SpawnProfile.Stage.BEFORE_SYNTHESIS)
	_set_spawning_enabled(false)
	# A scene reload may have restored a post-synthesis stage for a fraction of a
	# frame. Remove only ambient enemies; scripted opening actors are recreated by
	# the controller from the saved phase.
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if enemy != null and not enemy.has_meta(&"opening_scripted"):
			enemy.queue_free()

func opening_complete_synthesis() -> void:
	_grant_milestone(M_SYNTHESIS, resonance_synthesis)
	_mark_milestone_area_completed(M_SYNTHESIS)
	_update_objective()

func opening_complete_officer() -> void:
	if _grant_milestone(M_FIRST_CONFRONTATION, resonance_first_confrontation):
		Global.attempt_opening_officer_completed = true
	elif Global != null:
		Global.attempt_opening_officer_completed = true
	_update_objective()

func opening_complete_bren() -> void:
	if _grant_milestone(M_ASSISTANT, resonance_assistant_commitment):
		Global.attempt_opening_bren_committed = true
	elif Global != null:
		Global.attempt_opening_bren_committed = true
	_mark_milestone_area_completed(M_ASSISTANT)
	if Global != null:
		Global.transaction_followers(maxi(0, 1 - int(Global.followers)), &"bren_first_follower", {}, false, false)
	_refresh_progression_seals()
	_update_objective()

func opening_complete_short_or_skip() -> void:
	opening_complete_synthesis()
	opening_complete_officer()
	opening_complete_bren()

func finish_opening_sequence() -> void:
	_opening_sequence_active = false
	if _has_milestone(M_FIRST_CONFRONTATION):
		if _spawner == null or not is_instance_valid(_spawner):
			_spawner = get_tree().get_first_node_in_group(&"enemy_spawner") as EnemySpawner
		if _spawner != null:
			_spawner.set_segment1_stage(Segment1SpawnProfile.Stage.ARCHIVE, 4.5)
			_spawner.suspend_spawning(4.5)
	else:
		_set_spawn_stage(Segment1SpawnProfile.Stage.BEFORE_SYNTHESIS)
	_refresh_progression_seals()
	_update_objective()
	_update_gate_lock()

func _mark_milestone_area_completed(id: StringName) -> void:
	var area := _milestone_areas.get(id, null) as Level1MilestoneArea
	if area != null and is_instance_valid(area):
		area.mark_completed()

# Spawn stages are the segment's authored pressure tiers; the ThreatDirector
# phase must track them or the whole segment sits in the recon damp
# (heat x0.72, spawns x1.15) and the authored 100% heat peak is unreachable.
const STAGE_PHASE := {
	Segment1SpawnProfile.Stage.COURTYARD: &"disturbance",
	Segment1SpawnProfile.Stage.SERVICE: &"disturbance",
	Segment1SpawnProfile.Stage.OUTER_APPROACH: &"ascension",
	Segment1SpawnProfile.Stage.EXIT_RITE: &"collapse",
}

func _set_spawn_stage(stage: int) -> void:
	if _spawner == null or not is_instance_valid(_spawner):
		_spawner = get_tree().get_first_node_in_group(&"enemy_spawner") as EnemySpawner
	if _spawner != null:
		_spawner.set_segment1_stage(stage)
	var phase: StringName = STAGE_PHASE.get(stage, &"recon")
	var director := get_node_or_null("/root/ThreatDirector")
	if director != null and director.has_method("set_segment_phase"):
		director.call("set_segment_phase", phase)

func _apply_restored_spawn_stage() -> void:
	var stage := Segment1SpawnProfile.Stage.BEFORE_SYNTHESIS
	if _has_milestone(M_FINAL_PLAZA):
		stage = Segment1SpawnProfile.Stage.EXIT_RITE
	elif _has_milestone(M_FINAL_CHECKPOINT) or _has_milestone(M_WARDSTONE_2):
		stage = Segment1SpawnProfile.Stage.OUTER_APPROACH
	elif _has_milestone(M_SECURITY_STARTED):
		stage = Segment1SpawnProfile.Stage.SERVICE
	elif _has_milestone(M_ASSISTANT):
		stage = Segment1SpawnProfile.Stage.COURTYARD
	elif _has_milestone(M_FIRST_CONFRONTATION) or _has_milestone(M_WARDSTONE_1):
		stage = Segment1SpawnProfile.Stage.ARCHIVE
	elif _has_milestone(M_SYNTHESIS):
		stage = Segment1SpawnProfile.Stage.INITIAL_CONTAINMENT
	_set_spawn_stage(stage)

func _blocking_card(card_id: StringName, title: String, body: String) -> void:
	if RunEvents != null and RunEvents.has_signal("blocking_info_requested"):
		RunEvents.blocking_info_requested.emit(card_id, title, body)


func _tip(message: String, seconds: float) -> void:
	if RunEvents != null:
		RunEvents.tutorial_tip.emit(message, seconds)


# -----------------------------------------------------------------------------
# Gate, save safety, spawning and ticking
# -----------------------------------------------------------------------------

func _move_player_to_start() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	var spawn_here := _cell_to_world(_start_cell)
	if _opening_wants_entrance_start():
		spawn_here = _cell_to_world(_entrance_cell)
	if Global != null and Global.attempt_checkpoint_pos != Vector2.INF:
		if _is_valid_checkpoint(Global.attempt_checkpoint_pos):
			spawn_here = Global.attempt_checkpoint_pos
		elif _has_milestone(M_WARDSTONE_2):
			spawn_here = _cell_to_world(_wardstone_2_cell)
		elif _has_milestone(M_WARDSTONE_1):
			spawn_here = _cell_to_world(_wardstone_1_cell)
	if player.has_method("set_checkpoint"):
		player.call("set_checkpoint", spawn_here, true)
	else:
		player.global_position = spawn_here


# OpeningSequenceController.Phase.ADMISSION; kept as a plain int so the
# builder does not preload the controller script.
const OPENING_PHASE_ADMISSION := 2

func _opening_wants_entrance_start() -> bool:
	if Global == null or Global.attempt_opening_completed:
		return false
	if String(Global.attempt_opening_mode) != "full":
		return false
	return int(Global.attempt_opening_phase) <= OPENING_PHASE_ADMISSION


func _is_valid_checkpoint(world_pos: Vector2) -> bool:
	if not is_finite(world_pos.x) or not is_finite(world_pos.y):
		return false
	var cell := Vector2i(floori(world_pos.x / float(cell_size_px)), floori(world_pos.y / float(cell_size_px)))
	var in_playable_region := false
	for rect in _playable_regions:
		if rect.has_point(cell):
			in_playable_region = true
			break
	if not in_playable_region or _is_spawn_excluded(cell):
		return false
	return _cm == null or not is_instance_valid(_cm) or _cm.is_cell_walkable(cell)


func is_spawn_position_allowed(world_pos: Vector2) -> bool:
	var cell := Vector2i(floori(world_pos.x / float(cell_size_px)), floori(world_pos.y / float(cell_size_px)))
	if not _spawn_stage_is_open(cell) or _is_spawn_excluded(cell):
		return false
	return _cm == null or not is_instance_valid(_cm) or _cm.is_cell_walkable(cell)


func _spawn_stage_is_open(cell: Vector2i) -> bool:
	var facility := Rect2i(FACILITY_TL + Vector2i.ONE, FACILITY_SIZE - Vector2i(2, 2))
	if facility.has_point(cell):
		return true
	if COURTYARD_RECT.has_point(cell):
		return bool(_barrier_open.get(B_ARCHIVE_EXIT, false))
	if SERVICE_RECT.has_point(cell):
		return bool(_barrier_open.get(B_COURTYARD_SERVICE, false))
	if APPROACH_RECT.has_point(cell):
		return bool(_barrier_open.get(B_OUTER_APPROACH, false))
	return false


func _is_spawn_excluded(cell: Vector2i) -> bool:
	for rect in _spawn_exclusions:
		if rect.has_point(cell):
			return true
	return false


func _process(delta: float) -> void:
	if resonance < 1.0 and _has_milestone(M_SYNTHESIS):
		resonance = clampf(resonance + resonance_per_sec * delta, 0.0, 1.0)
		if Global != null:
			Global.attempt_segment1_resonance = resonance
	_res_ui_tick += delta
	if _res_ui_tick >= resonance_ui_push_every:
		_res_ui_tick = 0.0
		_update_gate_lock()
	_secondary_tick += delta
	if _secondary_tick >= 0.35:
		_secondary_tick = 0.0
		_update_secondary_announcement()


func _update_gate_lock() -> void:
	if _exit_rite == null:
		return
	var should_lock := resonance < 0.999 or not _has_milestone(M_FINAL_PLAZA)
	var was_locked := _exit_rite.locked
	_exit_rite.set_locked(should_lock)
	if was_locked and not should_lock:
		if Global != null:
			Global.tip_shown_gate_unsealed = true
	_push_resonance_ui()
	_push_gate_checklist(should_lock)


func _push_gate_checklist(gate_locked: bool) -> void:
	if RunEvents == null or not RunEvents.has_signal("gate_checklist_changed"):
		return
	if _opening_sequence_active:
		if _last_checklist_key != "opening":
			_last_checklist_key = "opening"
			RunEvents.gate_checklist_changed.emit(&"locked", [], "")
		return
	var percent := int(round(clampf(resonance, 0.0, 1.0) * 100.0))
	var resonance_complete := resonance >= 0.999
	var state: StringName = &"locked"
	if not gate_locked:
		state = &"ready"
	elif _has_milestone(M_FINAL_CHECKPOINT):
		# LOCATED: the HUD arrow points at the Rite from the final checkpoint on.
		state = &"located"

	var items: Array = [
		{"id": &"wardstone_1", "label": "Archive Wardstone rewritten", "done": _has_milestone(M_WARDSTONE_1)},
		{"id": &"wardstone_2", "label": "Service Wardstone rewritten", "done": _has_milestone(M_WARDSTONE_2)},
		{"id": &"checkpoint", "label": "Outer checkpoint disabled", "done": _has_milestone(M_FINAL_CHECKPOINT)},
		{"id": &"resonance", "label": "Resonance 100%% (%d%%)" % percent, "done": resonance_complete},
		{"id": &"plaza", "label": "Reach the outer Rite", "done": _has_milestone(M_FINAL_PLAZA)},
	]

	var hint := ""
	if not _has_milestone(M_WARDSTONE_1):
		hint = "Next: rewrite the archive Wardstone"
	elif not _has_milestone(M_WARDSTONE_2):
		hint = "Next: rewrite the service-district Wardstone"
	elif not _has_milestone(M_FINAL_CHECKPOINT):
		hint = "Next: both Wardstones can interrupt the outer checkpoint"
	elif not _has_milestone(M_FINAL_PLAZA):
		hint = "Follow the marker to the outer Rite"
	elif not resonance_complete:
		hint = "Build resonance • kills and loot feed the Pattern"
	else:
		hint = "Stand in the sigil • hold the channel"

	# Emit only on real change; this runs on the 0.15s resonance UI tick.
	var key := "%s|%d|%s" % [state, percent, str(items.map(func(item: Dictionary) -> bool: return bool(item["done"])))]
	if key == _last_checklist_key:
		return
	_last_checklist_key = key
	RunEvents.gate_checklist_changed.emit(state, items, hint)


func _push_resonance_ui() -> void:
	if RunEvents != null:
		# Resonance may mathematically fill a few seconds early on a slow first run,
		# but the Rite is not a valid objective until the authored plaza threshold.
		var displayed := resonance
		if not _has_milestone(M_FINAL_PLAZA):
			displayed = minf(displayed, 0.998)
		RunEvents.resonance_changed.emit(displayed)


func _on_gate_cleared(_rite: ExitRite) -> void:
	var game := get_tree().current_scene
	if game != null and game.has_method("complete_segment"):
		var segment: int = Global.attempt_segment if Global != null else 1
		game.call_deferred("complete_segment", segment)
	elif game != null and game.has_method("end_run"):
		game.call_deferred("end_run")


# -----------------------------------------------------------------------------
# Small deterministic geometry helpers
# -----------------------------------------------------------------------------

func _define_barrier(id: StringName, cells: Array[Vector2i]) -> void:
	_barrier_cells[id] = cells
	_barrier_open[id] = false
	for cell in cells:
		_add_wall_cell(cell, false)


func _facility_window(cell: Vector2i) -> bool:
	if cell.y == FACILITY_TL.y:
		return cell.x in [-16, -15, 12, 13, 17, 18]
	if cell.x == FACILITY_TL.x or cell.x == FACILITY_TL.x + FACILITY_SIZE.x - 1:
		return cell.y in [1, 2, 9, 10, 18, 19, 25, 26]
	return false


func _add_wall_line(start: Vector2i, finish: Vector2i, gaps: Array[Vector2i], windows: bool) -> void:
	var delta := finish - start
	var steps := maxi(absi(delta.x), absi(delta.y))
	var direction := Vector2i(signi(delta.x), signi(delta.y))
	for index in range(steps + 1):
		var cell := start + direction * index
		if gaps.has(cell):
			continue
		_add_wall_cell(cell, windows and index % 4 in [1, 2])


func _rect_perimeter_walls(top_left: Vector2i, size: Vector2i) -> void:
	_rect_perimeter_with_doors(top_left, size, [], [], [])


func _fill_rect_walls(top_left: Vector2i, size: Vector2i) -> void:
	for y in range(top_left.y, top_left.y + size.y):
		for x in range(top_left.x, top_left.x + size.x):
			_add_wall_cell(Vector2i(x, y), false)


func _rect_perimeter_with_bottom_door(top_left: Vector2i, size: Vector2i, door_x_a: int, door_x_b: int) -> void:
	_rect_perimeter_with_doors(top_left, size, [door_x_a, door_x_b], [], [])


func _rect_perimeter_with_left_door(top_left: Vector2i, size: Vector2i, door_y_a: int, door_y_b: int) -> void:
	var left_door_ys: Array[int] = []
	for y in range(door_y_a, door_y_b + 1):
		left_door_ys.append(y)
	_rect_perimeter_with_doors(top_left, size, [], left_door_ys, [])


func _rect_perimeter_with_doors(top_left: Vector2i, size: Vector2i, bottom_door_xs: Array, left_door_ys: Array, right_door_ys: Array) -> void:
	if size.x <= 1 or size.y <= 1:
		return
	var x1 := top_left.x + size.x - 1
	var y1 := top_left.y + size.y - 1
	for x in range(top_left.x, x1 + 1):
		_add_wall_cell(Vector2i(x, top_left.y), false)
		if not bottom_door_xs.has(x):
			_add_wall_cell(Vector2i(x, y1), false)
	for y in range(top_left.y + 1, y1):
		if not left_door_ys.has(y):
			_add_wall_cell(Vector2i(top_left.x, y), false)
		if not right_door_ys.has(y):
			_add_wall_cell(Vector2i(x1, y), false)


func _register_building_rect(top_left: Vector2i, size: Vector2i, loot: bool, cfg: Dictionary = {}) -> void:
	if size.x <= 2 or size.y <= 2:
		return
	_building_interiors.append({
		"rect": Rect2i(top_left + Vector2i.ONE, size - Vector2i(2, 2)),
		"loot": loot,
		"cfg": cfg,
	})


func _place_waypoints() -> void:
	if waypoint_scene == null:
		return
	for cell in [
		Vector2i(10, 13), Vector2i(-11, 4), Vector2i(-6, -8),
		Vector2i(15, -14), Vector2i(25, -16), Vector2i(42, -29),
		Vector2i(49, -39), Vector2i(48, -57), Vector2i(27, -50),
	]:
		var waypoint := waypoint_scene.instantiate() as Node2D
		if waypoint == null:
			continue
		waypoint.global_position = _cell_to_world(cell)
		_geo.add_child(waypoint)


func _add_wall_cell(cell: Vector2i, make_window: bool) -> void:
	_wall_kind[cell] = 1 if make_window else 0


func _add_fence_cell(cell: Vector2i) -> void:
	_fence_cells[cell] = true


func _add_half_cell(cell: Vector2i) -> void:
	_half_cells[cell] = true


func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * cell_size_px + cell_size_px * 0.5, cell.y * cell_size_px + cell_size_px * 0.5)


func _cell_rect_center(cell_tl: Vector2i, size: Vector2i) -> Vector2:
	return Vector2(cell_tl * cell_size_px) + Vector2(size * cell_size_px) * 0.5


func _place_deco(tex: Texture2D, cell: Vector2i, deco_scale: float, alpha: float, z: int) -> void:
	if tex == null:
		return
	if _cm != null and is_instance_valid(_cm) and _cm.tiled_world_rendering:
		_cm.paint_tiled_texture(
			_geo, &"deco", cell, tex, z, 0, false, false,
			Color(1, 1, 1, alpha)
		)
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2(deco_scale, deco_scale)
	sprite.modulate = Color(1, 1, 1, alpha)
	sprite.z_index = z
	sprite.position = _cell_to_world(cell)
	_geo.add_child(sprite)
