extends Node2D
class_name FlowFieldNav

const STEPS: PackedVector2Array = [
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1),
]

@export var cell_size_px: int = 64

# With your ~1200px “relevance” distances, 40–64 is plenty.
@export var radius_cells: int = 48

# Rate-limit rebuild starts (still only rebuilds when player cell / nav revision changes).
@export var rebuild_interval: float = 0.25

# Only request rebuild if player moved at least this many cells (Chebyshev distance).
@export var rebuild_cell_step: int = 2

# Incremental build budget
@export var max_expansions_per_frame: int = 2500
@export var max_ms_per_frame: float = 1.5

# Makes flow prefer corridor centers instead of wall-hugging.
@export var prefer_open_cells: bool = true

@export var player_group: StringName = &"player"
@export var chunk_manager_group: StringName = &"chunk_manager"

var _cm: ChunkManager = null
var _player: Node2D = null

var _origin_cell: Vector2i = Vector2i.ZERO
var _last_nav_revision: int = -1

# local grid buffers (square around origin)
var _w: int = 0
var _r: int = 0
var _grid_size: int = 0

# stamp technique so we don't clear arrays
var _stamp_id: int = 1
var _stamp: PackedInt32Array = PackedInt32Array()
var _dist: PackedInt32Array = PackedInt32Array()
var _dirx: PackedInt32Array = PackedInt32Array()
var _diry: PackedInt32Array = PackedInt32Array()

# BFS queue (preallocated)
var _queue: PackedInt32Array = PackedInt32Array()
var _q_head: int = 0
var _q_tail: int = 0
var _building: bool = false

# rebuild requests
var _time_accum: float = 0.0
var _pending: bool = true
var _pending_cell: Vector2i = Vector2i.ZERO
var _pending_rev: int = -1
var _last_request_cell: Vector2i = Vector2i(999999, 999999)

# lazy walkability + penalty caches (per rebuild stamp)
var _walk_stamp_id: int = 1
var _walk_stamp: PackedInt32Array = PackedInt32Array()
var _walkable: PackedInt32Array = PackedInt32Array() # 0/1

var _pen_stamp_id: int = 1
var _pen_stamp: PackedInt32Array = PackedInt32Array()
var _penalty: PackedInt32Array = PackedInt32Array() # 0..8 (higher = closer to walls)
var _candidate_steps: PackedInt32Array = PackedInt32Array()
var _candidate_penalties: PackedInt32Array = PackedInt32Array()

var _debug_requested := 0
var _debug_started := 0
var _debug_completed := 0
var _debug_superseded := 0
var _debug_cells_total := 0
var _debug_build_cpu_us := 0
var _debug_current_cells := 0
var _debug_current_cpu_us := 0
var _debug_last_cells := 0
var _debug_last_cpu_us := 0
var _debug_last_request_reason: StringName = &""
var _debug_last_completed_reason: StringName = &""
var _debug_current_reason: StringName = &""
var _debug_player_moved := false
var _has_requested := false


func _ready() -> void:
	add_to_group(&"flow_field_nav")
	_ensure_buffers()
	_time_accum = rebuild_interval


func _process(delta: float) -> void:
	_acquire_refs()
	if _cm == null or _player == null:
		return

	_ensure_buffers()

	var pc: Vector2i = world_to_cell(_player.global_position)
	var rev: int = _cm.get_nav_revision()

	_request_rebuild_if_needed(pc, rev)

	_time_accum += delta

	if _pending and not _building and _time_accum >= rebuild_interval:
		_time_accum = 0.0
		_start_rebuild(_pending_cell, _pending_rev)
		_pending = false

	if _building:
		_step_build()


func _acquire_refs() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(player_group) as Node2D

	if _cm == null or not is_instance_valid(_cm):
		_cm = get_tree().get_first_node_in_group(chunk_manager_group) as ChunkManager


func _ensure_buffers() -> void:
	var new_r: int = maxi(1, radius_cells)
	var new_w: int = new_r * 2 + 1
	var new_size: int = new_w * new_w

	if new_size == _grid_size:
		return

	_r = new_r
	_w = new_w
	_grid_size = new_size

	_stamp.resize(_grid_size)
	_dist.resize(_grid_size)
	_dirx.resize(_grid_size)
	_diry.resize(_grid_size)
	_queue.resize(_grid_size)

	_walk_stamp.resize(_grid_size)
	_walkable.resize(_grid_size)

	_pen_stamp.resize(_grid_size)
	_penalty.resize(_grid_size)
	_candidate_steps.resize(STEPS.size())
	_candidate_penalties.resize(STEPS.size())

	_building = false
	_pending = true


func _request_rebuild_if_needed(player_cell: Vector2i, nav_revision: int) -> void:
	if not _has_requested:
		_request_rebuild(player_cell, nav_revision, &"initial", false)
		return

	var dx: int = absi(player_cell.x - _last_request_cell.x)
	var dy: int = absi(player_cell.y - _last_request_cell.y)
	var cheb: int = maxi(dx, dy)

	if nav_revision != _last_nav_revision:
		if _pending and _pending_rev == nav_revision:
			if cheb >= maxi(1, rebuild_cell_step):
				_request_rebuild(player_cell, nav_revision, &"player_moved", true)
			return
		if _building:
			_building = false
			_debug_superseded += 1
		_request_rebuild(player_cell, nav_revision, &"nav_revision", false)
		return

	if cheb >= maxi(1, rebuild_cell_step):
		_request_rebuild(player_cell, nav_revision, &"player_moved", true)


func _request_rebuild(player_cell: Vector2i, nav_revision: int, reason: StringName, player_moved: bool) -> void:
	# Player movement updates the one pending destination without throwing away
	# the work already completed for the active field. Nav-revision invalidation
	# is handled explicitly by _request_rebuild_if_needed().
	_has_requested = true
	_pending = true
	_pending_cell = player_cell
	_pending_rev = nav_revision
	_last_request_cell = player_cell
	_debug_requested += 1
	_debug_last_request_reason = reason
	_debug_current_reason = reason
	_debug_player_moved = player_moved
	if PerformanceFlightRecorder != null:
		PerformanceFlightRecorder.record_counter_event(&"navigation", &"flow_requested", 1, {
			"reason": String(reason),
			"revision": nav_revision,
		})


func _start_rebuild(player_cell: Vector2i, nav_revision: int) -> void:
	if _cm == null:
		return

	_origin_cell = player_cell
	_last_nav_revision = nav_revision

	_stamp_id += 1
	if _stamp_id >= 2000000000:
		for i in range(_grid_size):
			_stamp[i] = 0
		_stamp_id = 1

	# new cache stamps for this rebuild
	_walk_stamp_id += 1
	if _walk_stamp_id >= 2000000000:
		for i in range(_grid_size):
			_walk_stamp[i] = 0
		_walk_stamp_id = 1

	_pen_stamp_id += 1
	if _pen_stamp_id >= 2000000000:
		for i in range(_grid_size):
			_pen_stamp[i] = 0
		_pen_stamp_id = 1

	_q_head = 0
	_q_tail = 0

	# origin local index
	var ox: int = _r
	var oy: int = _r
	var oidx: int = ox + oy * _w

	_stamp[oidx] = _stamp_id
	_dist[oidx] = 0
	_dirx[oidx] = 0
	_diry[oidx] = 0

	_queue[_q_tail] = oidx
	_q_tail += 1

	_building = true
	_debug_started += 1
	_debug_current_cells = 0
	_debug_current_cpu_us = 0
	if PerformanceFlightRecorder != null:
		PerformanceFlightRecorder.record_event(&"navigation", &"flow_started", {
			"revision": nav_revision,
			"reason": String(_debug_current_reason),
		})


func _step_build() -> void:
	if _cm == null:
		_building = false
		return

	var start_us: int = Time.get_ticks_usec()
	var processed: int = 0
	var max_us: int = int(max_ms_per_frame * 1000.0)

	while _q_head < _q_tail:
		if processed >= max_expansions_per_frame:
			break
		if max_us > 0 and (Time.get_ticks_usec() - start_us) >= max_us:
			break

		var cur_idx: int = _queue[_q_head]
		_q_head += 1
		processed += 1

		var cur_dist: int = _dist[cur_idx]
		if cur_dist >= _r:
			continue

		var cx: int = cur_idx % _w
		var cy: int = int(cur_idx / float(_w))

		_expand_neighbors(cx, cy, cur_dist)

	var elapsed_us := Time.get_ticks_usec() - start_us
	_debug_current_cells += processed
	_debug_current_cpu_us += elapsed_us
	_debug_cells_total += processed
	_debug_build_cpu_us += elapsed_us
	if _q_head >= _q_tail:
		_building = false
		_debug_completed += 1
		_debug_last_cells = _debug_current_cells
		_debug_last_cpu_us = _debug_current_cpu_us
		_debug_last_completed_reason = _debug_current_reason
		if PerformanceFlightRecorder != null:
			PerformanceFlightRecorder.record_event(&"navigation", &"flow_completed", {
				"revision": _last_nav_revision,
				"reason": String(_debug_current_reason),
				"cells": _debug_last_cells,
				"cpu_usec": _debug_last_cpu_us,
			})


func _expand_neighbors(cx: int, cy: int, parent_dist: int) -> void:
	# 8-neighbor steps
	var candidate_count := 0

	# We’ll order them by "penalty" (more walls nearby = worse),
	# which helps avoid hugging corners/doorframes.
	# Small N=8 insertion sort.
	var step_index := 0
	while step_index < STEPS.size():
		var s := STEPS[step_index]
		var sx := int(s.x)
		var sy := int(s.y)
		var nx: int = cx + sx
		var ny: int = cy + sy
		if not _in_bounds(nx, ny):
			step_index += 1
			continue

		# prevent diagonal corner-cutting
		if sx != 0 and sy != 0:
			if not _is_walkable(cx + sx, cy) or not _is_walkable(cx, cy + sy):
				step_index += 1
				continue

		if not _is_walkable(nx, ny):
			step_index += 1
			continue

		var p: int = (_cell_penalty(nx, ny) if prefer_open_cells else 0)

		# insert sorted by penalty ascending
		var insert_at := candidate_count
		while insert_at > 0 and p < _candidate_penalties[insert_at - 1]:
			_candidate_penalties[insert_at] = _candidate_penalties[insert_at - 1]
			_candidate_steps[insert_at] = _candidate_steps[insert_at - 1]
			insert_at -= 1
		_candidate_penalties[insert_at] = p
		_candidate_steps[insert_at] = step_index
		candidate_count += 1
		step_index += 1

	var candidate_index := 0
	while candidate_index < candidate_count:
		var s := STEPS[_candidate_steps[candidate_index]]
		var sx := int(s.x)
		var sy := int(s.y)
		var nx: int = cx + sx
		var ny: int = cy + sy
		_visit(nx, ny, parent_dist, -sx, -sy)
		candidate_index += 1


func _visit(nx: int, ny: int, parent_dist: int, dir_to_origin_x: int, dir_to_origin_y: int) -> void:
	var nidx: int = nx + ny * _w
	if _stamp[nidx] == _stamp_id:
		return

	_stamp[nidx] = _stamp_id
	_dist[nidx] = parent_dist + 1
	_dirx[nidx] = dir_to_origin_x
	_diry[nidx] = dir_to_origin_y

	_queue[_q_tail] = nidx
	_q_tail += 1


func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < _w and y < _w


func _is_walkable(lx: int, ly: int) -> bool:
	if not _in_bounds(lx, ly):
		return false

	var idx: int = lx + ly * _w
	if _walk_stamp[idx] == _walk_stamp_id:
		return _walkable[idx] != 0

	_walk_stamp[idx] = _walk_stamp_id

	var gx: int = _origin_cell.x + (lx - _r)
	var gy: int = _origin_cell.y + (ly - _r)
	var ok: bool = _cm.is_cell_walkable(Vector2i(gx, gy))

	_walkable[idx] = 1 if ok else 0
	return ok


func _cell_penalty(lx: int, ly: int) -> int:
	# penalty = how many neighbors are blocked (0..8)
	# higher => closer to walls => less preferred
	if not _in_bounds(lx, ly):
		return 99

	var idx: int = lx + ly * _w
	if _pen_stamp[idx] == _pen_stamp_id:
		return int(_penalty[idx])

	_pen_stamp[idx] = _pen_stamp_id

	if not _is_walkable(lx, ly):
		_penalty[idx] = 99
		return 99

	var count: int = 0
	var oy := -1
	while oy <= 1:
		var ox := -1
		while ox <= 1:
			if ox == 0 and oy == 0:
				ox += 1
				continue
			if not _is_walkable(lx + ox, ly + oy):
				count += 1
			ox += 1
		oy += 1

	_penalty[idx] = count
	return count


func _dir_at_cell(cell: Vector2i) -> Vector2:
	var dx: int = cell.x - _origin_cell.x
	var dy: int = cell.y - _origin_cell.y
	if absi(dx) > _r or absi(dy) > _r:
		return Vector2.ZERO

	var lx: int = dx + _r
	var ly: int = dy + _r
	var idx: int = lx + ly * _w

	if _stamp[idx] != _stamp_id:
		return Vector2.ZERO

	var sx: int = _dirx[idx]
	var sy: int = _diry[idx]
	if sx == 0 and sy == 0:
		return Vector2.ZERO

	# sx/sy are -1/0/1. Avoid per-sample normalize() in hot path.
	# Diagonals need 1/sqrt(2); cardinals already length 1.
	if sx != 0 and sy != 0:
		return Vector2(float(sx), float(sy)) * 0.7071067811865476
	return Vector2(float(sx), float(sy))


func sample_dir_smooth(world_pos: Vector2) -> Vector2:
	# 3x3 smoothing: best fix for doorway/corner scraping.
	var c: Vector2i = world_to_cell(world_pos)

	var sum: Vector2 = Vector2.ZERO
	var wsum: float = 0.0

	var oy := -1
	while oy <= 1:
		var ox := -1
		while ox <= 1:
			var d: Vector2 = _dir_at_cell(c + Vector2i(ox, oy))
			if d == Vector2.ZERO:
				ox += 1
				continue
			var w: float = 2.0 if (ox == 0 and oy == 0) else 1.0
			sum += d * w
			wsum += w
			ox += 1
		oy += 1

	if wsum > 0.0 and sum.length_squared() > 0.0001:
		return sum.normalized()

	# If smoothing can't find anything, return ZERO (not player dir).
	return Vector2.ZERO

func sample_dir(world_pos: Vector2) -> Vector2:
	# IMPORTANT:
	# If we don't have a stamped direction, return ZERO.
	# Do NOT fallback to direct-to-player here, because the horde brain
	# (EnemyHordeNav) does a smarter fallback (cost-probe + inertia).
	if _player == null or not is_instance_valid(_player):
		return Vector2.ZERO

	var cell: Vector2i = world_to_cell(world_pos)
	return _dir_at_cell(cell) # may be ZERO, and that's desired

func world_to_cell(p: Vector2) -> Vector2i:
	var cs: float = float(cell_size_px)
	return Vector2i(floori(p.x / cs), floori(p.y / cs))

func sample_cost(world_pos: Vector2) -> int:
	# Returns BFS distance in cells to the player-origin cell.
	# Lower is better. Large value means "unknown/outside field".
	var cell: Vector2i = world_to_cell(world_pos)

	var dx: int = cell.x - _origin_cell.x
	var dy: int = cell.y - _origin_cell.y
	if absi(dx) > _r or absi(dy) > _r:
		return 1_000_000_000

	var lx: int = dx + _r
	var ly: int = dy + _r
	var idx: int = lx + ly * _w

	if _stamp[idx] != _stamp_id:
		return 1_000_000_000

	return int(_dist[idx])


func get_debug_counters() -> Dictionary:
	return {
		"requested": _debug_requested,
		"started": _debug_started,
		"completed": _debug_completed,
		"superseded": _debug_superseded,
		"cells_total": _debug_cells_total,
		"cpu_us_total": _debug_build_cpu_us,
		"last_cells": _debug_last_cells,
		"last_cpu_us": _debug_last_cpu_us,
		"last_request_reason": _debug_last_request_reason,
		"last_completed_reason": _debug_last_completed_reason,
		"player_moved": _debug_player_moved,
		"last_revision": _last_nav_revision,
		"pending_revision": _pending_rev,
		"pending": _pending,
		"building": _building,
	}


func get_hot_loop_buffer_stats() -> Dictionary:
	return {
		"step_storage": &"packed",
		"step_count": STEPS.size(),
		"candidate_capacity": mini(_candidate_steps.size(), _candidate_penalties.size()),
	}
